extends Node
class_name ScenarioLoader

# Loads scenario seeds, applies pressure knobs, and schedules events into a session.
#
# Scenario schema (updated for Pressure Knobs 8.2):
# {
#   "events": [
#     {
#       "time": 5.0,                 # base time (seconds) from session start
#       "rule_id": 1,                # rule to evaluate at decision moment
#       "payload": {...},            # domain info for the decision
#       "decision_window": 3.0,      # (optional) window (seconds) where interruptions can occur before decision
#       "ambiguity": {               # (optional) per-event ambiguity override
#         "withhold_keys": ["dock"]  # which payload keys may be withheld
#       }
#     }
#   ],
#   "knobs": {
#     "time_pressure": 0.0..1.0,        # higher = less slack (wins over time_slack if present)
#     "time_slack": 0.1..2.0,           # multiply event times by this factor (legacy support)
#     "ambiguity_level": 0.0..1.0,      # chance decision info is missing/delayed
#     "interrupt_frequency": 0.0..N     # interruptions per second of decision window
#   },
#   "scaffold_tier": 1
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
			"time_pressure": 0.0,         # 0 = normal slack, 1 = max pressure
			"ambiguity_level": 0.0,        # missing/delayed decision info
			"interrupt_frequency": 0.0     # interruptions during decision windows
		},
		"scaffold_tier": 1
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

	# Compute total duration (after applying time_slack) to inform any global scheduling.
	var max_time: float = 0.0
	for ev in events:
		var scaled_time: float = float(ev.get("time", 0.0)) * session.time_slack
		if scaled_time > max_time:
			max_time = scaled_time

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
		# We bind the decision_time and decision_window so the rule can see deadline/pressure context.
		session.schedule_event_in(
			decision_time,
			Callable(self, "_trigger_rule").bind(rule_engine, session, rule_id, payload, decision_time, decision_window)
		)

func _apply_ambiguity(session: SessionManager, payload: Dictionary, ev: Dictionary) -> void:
	# Inline behavior:
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
		# Default: withhold a location-like field if present.
		if payload.has("dock"):
			withhold_keys = ["dock"]

	# Withhold selected keys (missing info)
	var withheld: Dictionary = {}
	for k in withhold_keys:
		if payload.has(k):
			withheld[k] = payload[k]
			payload.erase(k)

	payload["_withheld"] = withheld

	# Delayed info (arrives after decision moment) — affects decision context.
	# Delay is scaled by time_slack to keep relative pacing.
	var delay_seconds: float = rng.randf_range(0.75, 2.25) * session.time_slack
	payload["info_delay_seconds"] = delay_seconds
	payload["info_available_at_offset"] = delay_seconds  # relative; SessionManager will interpret at decision time

	# Schedule an info-reveal "benign" event after delay that logs the reveal (no UI required).
	# This models "delayed info" in the simulation timeline.
	if withheld.size() > 0:
		session.schedule_event_in(delay_seconds, Callable(self, "_reveal_info").bind(session, withheld))

func _schedule_interruptions(session: SessionManager, decision_time: float, decision_window: float, rule_id: int) -> void:
	# Interruptions are non-critical events during the decision window.
	# They affect decision context by incrementing session.interruptions_since_last_decision.
	if session.interrupt_frequency <= 0.0:
		return

	# Expected count = freq * window length (rounded down but at least 1 if freq is significant).
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
	# Non-critical interruption (no scoring penalty).
	# It affects decision context by increasing interruption count prior to the decision evaluation.
	session.register_interrupt(related_rule_id, session.sim_clock.current_time)

func _reveal_info(session: SessionManager, revealed: Dictionary) -> void:
	# Delayed info arrives after a decision window. This affects realism and is loggable/debuggable.
	# No UI screens are introduced; feedback layer gets a benign event line.
	session.register_info_reveal(revealed, session.sim_clock.current_time)

func _trigger_rule(
	rule_engine: RuleEngine,
	session: SessionManager,
	rule_id: int,
	payload: Dictionary,
	decision_time: float,
	decision_window: float
) -> void:
	# Build decision context from session pressure knobs + dynamic interruptions + ambiguity.
	var current_time: float = session.sim_clock.current_time
	var decision_context: Dictionary = session.build_decision_context(rule_id, payload, current_time, decision_time, decision_window)

	# Evaluate rule using decision context (pressure affects decision context).
	var produces_waste: bool = rule_engine.evaluate_event(rule_id, payload, decision_context, current_time)

	# Update the score if a score engine exists.
	if session.score_engine != null:
		session.score_engine.apply_rule(rule_id, produces_waste)

	# Notify the feedback layer of the event.
	if session.feedback_layer != null:
		session.feedback_layer.handle_event(rule_id, produces_waste, current_time)

	# After a decision is evaluated, consume interruptions so they don't leak into the next decision.
	session.consume_interruptions()
