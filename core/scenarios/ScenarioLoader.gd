extends Node
class_name ScenarioLoader

# Scenario schema (updated for Scaffolding Tiers 8.3 + Pressure Knobs 8.2):
# {
#   "events": [ ... ],
#   "knobs": { "time_pressure", "time_slack", "ambiguity_level", "interrupt_frequency" },
#   "scaffold_tier": 1|2|3,              # Tier 1 guided, Tier 2 partial, Tier 3 no hints
#   "scaffold_source": "scenario"|"role" # scenario-based or role-based selection
# }

var scenarios: Dictionary = {
	"default": {
		"events": [
			{
				"time": 2.0,
				"rule_id": 1,
				"decision_window": 3.0,
				"payload": {"dock": "B2B-01", "pallet_id": "P-1001", "scan_required": true}
			},
			{
				"time": 5.0,
				"rule_id": 2,
				"decision_window": 4.0,
				"payload": {"dock": "B2B-02", "pallet_id": "P-1002", "scan_required": true}
			}
		],
		"knobs": {
			"time_pressure": 0.0,
			"ambiguity_level": 0.0,
			"interrupt_frequency": 0.0
		},
		# Scaffolding tier defaults (scenario-based)
		"scaffold_tier": 1,
		"scaffold_source": "scenario"
	}
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func load_scenario(name: String, session: SessionManager, rule_engine: RuleEngine) -> void:
	if not scenarios.has(name):
		push_warning("Scenario not found: %s" % name)
		return

	rng.randomize()

	var scenario_data = scenarios[name]

	# Backward compatibility: allow array-only scenarios.
	var events: Array = []
	if scenario_data is Array:
		events = scenario_data
	else:
		events = scenario_data.get("events", [])

	# -----------------------------
	# Scaffolding tier selection (scenario-based or role-based)
	if scenario_data is Dictionary:
		var scaffold_source: String = str(scenario_data.get("scaffold_source", "scenario"))
		var scaffold_tier: int = int(scenario_data.get("scaffold_tier", 1))
		session.set_scaffolding(scaffold_source, scaffold_tier)
	else:
		session.set_scaffolding("scenario", 1)

	# -----------------------------
	# Apply pressure knobs (scenario-configurable)
	var knobs: Dictionary = {}
	if scenario_data is Dictionary:
		knobs = scenario_data.get("knobs", {})

	session.interrupt_frequency = float(knobs.get("interrupt_frequency", 0.0))
	session.ambiguity_level = float(knobs.get("ambiguity_level", 0.0))

	# Time pressure wins over time_slack if present.
	# time_pressure 0..1 -> time_slack 1..min_slack
	var min_slack: float = 0.25
	if knobs.has("time_pressure"):
		session.time_pressure = clamp(float(knobs.get("time_pressure", 0.0)), 0.0, 1.0)
		session.time_slack = lerp(1.0, min_slack, session.time_pressure)
	else:
		session.time_slack = max(float(knobs.get("time_slack", 1.0)), min_slack)
		session.time_pressure = clamp(1.0 - session.time_slack, 0.0, 1.0)

	# -----------------------------
	# Schedule scenario events.
	for ev in events:
		var base_time: float = float(ev.get("time", 0.0))
		var decision_time: float = base_time * session.time_slack

		var rule_id: int = int(ev.get("rule_id", -1))
		var payload: Dictionary = ev.get("payload", {}).duplicate(true)

		# Decision window used for interruptions that affect the decision context (not just UI).
		var decision_window: float = float(ev.get("decision_window", 3.0))
		decision_window = max(decision_window * session.time_slack, 0.5)

		# Ambiguity: missing/delayed info that affects decision context.
		_apply_ambiguity(session, payload, ev)

		# Schedule interruptions inside the decision window BEFORE the decision moment.
		_schedule_interruptions(session, decision_time, decision_window, rule_id)

		# Schedule the decision event itself.
		session.schedule_event_in(
			decision_time,
			Callable(self, "_trigger_rule").bind(rule_engine, session, rule_id, payload, decision_time, decision_window)
		)

func _apply_ambiguity(session: SessionManager, payload: Dictionary, ev: Dictionary) -> void:
	# - With probability ambiguity_level, withhold some payload keys and/or delay info availability.
	# - This is recorded into payload so RuleEngine sees it in decision context.
	if session.ambiguity_level <= 0.0:
		return
	if rng.randf() >= session.ambiguity_level:
		return

	payload["ambiguous"] = true

	# Which keys to withhold (scenario may specify per-event keys; otherwise choose a safe default set)
	var withhold_keys: Array = []
	var amb: Dictionary = ev.get("ambiguity", {})
	if amb is Dictionary and amb.has("withhold_keys"):
		withhold_keys = amb.get("withhold_keys", [])
	else:
		if payload.has("dock"):
			withhold_keys = ["dock"]

	# Withhold selected keys (missing info)
	var withheld: Dictionary = {}
	for k in withhold_keys:
		if payload.has(k):
			withheld[k] = payload[k]
			payload.erase(k)

	payload["_withheld"] = withheld

	# Delayed info (arrives after decision moment)
	var delay_seconds: float = rng.randf_range(0.75, 2.25) * session.time_slack
	payload["info_delay_seconds"] = delay_seconds
	payload["info_available_at_offset"] = delay_seconds

	if withheld.size() > 0:
		session.schedule_event_in(delay_seconds, Callable(self, "_reveal_info").bind(session, withheld))

func _schedule_interruptions(session: SessionManager, decision_time: float, decision_window: float, rule_id: int) -> void:
	# Interruptions are non-critical events during the decision window.
	# They affect decision context by incrementing session.interruptions_since_last_decision.
	if session.interrupt_frequency <= 0.0:
		return

	var count: int = int(floor(decision_window * session.interrupt_frequency))
	if count <= 0 and (decision_window * session.interrupt_frequency) >= 0.5:
		count = 1
	if count <= 0:
		return

	var window_start: float = max(decision_time - decision_window, 0.0)
	for i in range(count):
		var t: float = rng.randf_range(window_start, decision_time)
		session.schedule_event_in(t, Callable(self, "_trigger_interrupt").bind(session, rule_id))

func _trigger_interrupt(session: SessionManager, related_rule_id: int) -> void:
	session.register_interrupt(related_rule_id, session.sim_clock.current_time)

func _reveal_info(session: SessionManager, revealed: Dictionary) -> void:
	session.register_info_reveal(revealed, session.sim_clock.current_time)

func _trigger_rule(
	rule_engine: RuleEngine,
	session: SessionManager,
	rule_id: int,
	payload: Dictionary,
	decision_time: float,
	decision_window: float
) -> void:
	var current_time: float = session.sim_clock.current_time
	var decision_context: Dictionary = session.build_decision_context(rule_id, payload, current_time, decision_time, decision_window)

	# Scaffolding tiers: publish hint (if any) to UI. Hints do not reveal outcomes.
	session.publish_hint(str(decision_context.get("hint", "")))

	var produces_waste: bool = rule_engine.evaluate_event(rule_id, payload, decision_context, current_time)

	if session.score_engine != null:
		session.score_engine.apply_rule(rule_id, produces_waste)

	if session.feedback_layer != null:
		session.feedback_layer.handle_event(rule_id, produces_waste, current_time)

	# Clear hint after decision resolves (keeps hints tied to decision moments)
	session.publish_hint("")
	session.consume_interruptions()
