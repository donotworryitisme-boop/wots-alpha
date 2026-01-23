extends Node
class_name ScenarioLoader

# Execution 8.7 — Bay B2B Scenario Canon
# - 6 canonical scenarios with neutral descriptions (no difficulty labels shown).
# - Each scenario auto-ends after the last scheduled decision window so every run reaches debrief.

var scenarios: Dictionary = {
	"default": {
		"description": "Baseline flow for quick testing.",
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
		"scaffold_tier": 1,
		"scaffold_source": "scenario"
	},

	# Canonical 1
	"Late trailer check-in": {
		"description": "A planned load is delayed; you manage partial information and shifting timing.",
		"events": [
			{"time": 2.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2101", "scan_required": true}},
			{"time": 6.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2102", "scan_required": true, "status_note": "trailer not confirmed"}},
			{"time": 10.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2103", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.35, "ambiguity_level": 0.25, "interrupt_frequency": 0.25},
		"scaffold_tier": 2,
		"scaffold_source": "scenario"
	},

	# Canonical 2
	"Capacity mismatch": {
		"description": "Trailer capacity is uncertain; you balance loading pace vs. risk of rework.",
		"events": [
			{"time": 2.0, "rule_id": 1, "decision_window": 3.5, "payload": {"dock": "B2B-02", "pallet_id": "P-2201", "scan_required": true}},
			{"time": 5.0, "rule_id": 1, "decision_window": 3.5, "payload": {"dock": "B2B-02", "pallet_id": "P-2202", "scan_required": true, "capacity_hint": "unconfirmed"}},
			{"time": 8.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2203", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.25, "ambiguity_level": 0.35, "interrupt_frequency": 0.15},
		"scaffold_tier": 2,
		"scaffold_source": "scenario"
	},

	# Canonical 3
	"AS400 label mismatch": {
		"description": "System vs. physical label mismatch; you decide what to verify and when to escalate.",
		"events": [
			{"time": 2.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-03", "pallet_id": "P-2301", "scan_required": true, "label": "A-103", "system_label": "A-108"}},
			{"time": 6.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-03", "pallet_id": "P-2302", "scan_required": true, "label": "A-202", "system_label": "A-202"}},
			{"time": 10.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-03", "pallet_id": "P-2303", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.30, "ambiguity_level": 0.20, "interrupt_frequency": 0.20},
		"scaffold_tier": 2,
		"scaffold_source": "scenario"
	},

	# Canonical 4
	"RAQ reprioritization": {
		"description": "Priorities shift mid-run; you choose what info to consult before committing.",
		"events": [
			{"time": 2.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2401", "scan_required": true, "priority": "normal"}},
			{"time": 5.5, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2402", "scan_required": true, "priority": "updated"}},
			{"time": 9.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2403", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.20, "ambiguity_level": 0.30, "interrupt_frequency": 0.25},
		"scaffold_tier": 1,
		"scaffold_source": "scenario"
	},

	# Canonical 5
	"Two-dock contention": {
		"description": "Two docks compete for attention; interruptions increase while decisions stack.",
		"events": [
			{"time": 2.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2501", "scan_required": true}},
			{"time": 3.2, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2502", "scan_required": true}},
			{"time": 6.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-01", "pallet_id": "P-2503", "scan_required": true}},
			{"time": 7.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2504", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.35, "ambiguity_level": 0.20, "interrupt_frequency": 0.45},
		"scaffold_tier": 2,
		"scaffold_source": "scenario"
	},

	# Canonical 6
	"Phone triage": {
		"description": "Non-critical communication arrives during loading decisions; you choose what to ignore vs. verify.",
		"events": [
			{"time": 2.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2601", "scan_required": true}},
			{"time": 5.0, "rule_id": 2, "decision_window": 4.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2602", "scan_required": true}},
			{"time": 9.0, "rule_id": 1, "decision_window": 3.0, "payload": {"dock": "B2B-02", "pallet_id": "P-2603", "scan_required": true}}
		],
		"knobs": {"time_pressure": 0.25, "ambiguity_level": 0.25, "interrupt_frequency": 0.60},
		"scaffold_tier": 3,
		"scaffold_source": "scenario"
	}
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func get_scenario_names() -> Array[String]:
	var names: Array[String] = []
	for k in scenarios.keys():
		names.append(str(k))
	names.sort()
	return names

func get_scenario_description(name: String) -> String:
	if not scenarios.has(name):
		return ""
	return str(scenarios[name].get("description", ""))

func load_scenario(name: String, session: SessionManager, rule_engine: RuleEngine) -> void:
	if not scenarios.has(name):
		push_warning("Scenario not found: %s" % name)
		return

	rng.randomize()

	var scenario_data: Dictionary = scenarios[name]
	var events: Array = scenario_data.get("events", [])

	# Scaffolding tier selection
	var scaffold_source: String = str(scenario_data.get("scaffold_source", "scenario"))
	var scaffold_tier: int = int(scenario_data.get("scaffold_tier", 1))
	session.set_scaffolding(scaffold_source, scaffold_tier)

	# Pressure knobs
	var knobs: Dictionary = scenario_data.get("knobs", {})
	session.interrupt_frequency = float(knobs.get("interrupt_frequency", 0.0))
	session.ambiguity_level = float(knobs.get("ambiguity_level", 0.0))

	var min_slack: float = 0.25
	if knobs.has("time_pressure"):
		session.time_pressure = clamp(float(knobs.get("time_pressure", 0.0)), 0.0, 1.0)
		session.time_slack = lerp(1.0, min_slack, session.time_pressure)
	else:
		session.time_slack = max(float(knobs.get("time_slack", 1.0)), min_slack)
		session.time_pressure = clamp(1.0 - session.time_slack, 0.0, 1.0)

	# Neutral start assignment
	session.set_assignment("Bay B2B — session active")
	session.set_responsibility_window(true)

	# Schedule events and compute auto-end time
	var latest_end_time: float = 0.0

	for ev in events:
		var base_time: float = float(ev.get("time", 0.0))
		var decision_time: float = base_time * session.time_slack

		var rule_id: int = int(ev.get("rule_id", -1))
		var payload: Dictionary = ev.get("payload", {}).duplicate(true)

		var decision_window: float = float(ev.get("decision_window", 3.0))
		decision_window = max(decision_window * session.time_slack, 0.5)

		_apply_ambiguity(session, payload, ev)
		_schedule_interruptions(session, decision_time, decision_window, rule_id)

		# Track latest end moment (decision_time is when event fires; +window is the "decision period")
		latest_end_time = max(latest_end_time, decision_time + decision_window)

		session.schedule_event_in(
			decision_time,
			Callable(self, "_trigger_rule").bind(rule_engine, session, rule_id, payload, decision_time, decision_window)
		)

	# Auto-end so each scenario reaches debrief without requiring a manual click.
	# Small calm buffer so the last log line is visible before debrief.
	var auto_end_at: float = latest_end_time + 1.0
	session.schedule_event_in(auto_end_at, Callable(self, "_auto_end_session").bind(session))

func _auto_end_session(session: SessionManager) -> void:
	if session != null and session.session_active:
		session.end_session()

func _apply_ambiguity(session: SessionManager, payload: Dictionary, ev: Dictionary) -> void:
	if session.ambiguity_level <= 0.0:
		return
	if rng.randf() >= session.ambiguity_level:
		return

	payload["ambiguous"] = true

	var withhold_keys: Array = []
	var amb: Dictionary = ev.get("ambiguity", {})
	if amb is Dictionary and amb.has("withhold_keys"):
		withhold_keys = amb.get("withhold_keys", [])
	else:
		if payload.has("dock"):
			withhold_keys = ["dock"]

	var withheld: Dictionary = {}
	for k in withhold_keys:
		if payload.has(k):
			withheld[k] = payload[k]
			payload.erase(k)

	payload["_withheld"] = withheld

	var delay_seconds: float = rng.randf_range(0.75, 2.25) * session.time_slack
	payload["info_delay_seconds"] = delay_seconds
	payload["info_available_at_offset"] = delay_seconds

	if withheld.size() > 0:
		session.schedule_event_in(delay_seconds, Callable(self, "_reveal_info").bind(session, withheld))

func _schedule_interruptions(session: SessionManager, decision_time: float, decision_window: float, rule_id: int) -> void:
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

	# Neutral assignment update based on dock if available.
	var dock_text := "Unspecified"
	if payload.has("dock"):
		dock_text = str(payload.get("dock"))
	session.set_assignment("Loading — %s" % dock_text)
	session.set_responsibility_window(true)

	# Objective text for harness
	session.set_current_objective("Handle Rule %d (pallet %s)" % [rule_id, str(payload.get("pallet_id", "?"))])

	var decision_context: Dictionary = session.build_decision_context(rule_id, payload, current_time, decision_time, decision_window)
	session.publish_hint(str(decision_context.get("hint", "")))

	var produces_waste: bool = rule_engine.evaluate_event(rule_id, payload, decision_context, current_time)

	if session.score_engine != null:
		session.score_engine.apply_rule(rule_id, produces_waste)

	session.record_rule_result(rule_id, produces_waste, current_time)

	session.publish_hint("")
	session.consume_interruptions()
