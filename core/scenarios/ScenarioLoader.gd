extends Node
class_name ScenarioLoader

# Loads scenario seeds and schedules events into a session.

# Example scenarios defined inline. Later these can be external files.
var scenarios: Dictionary = {
	"default": [
		{"time": 2.0, "rule_id": 1, "payload": {}},
		{"time": 5.0, "rule_id": 2, "payload": {}}
	]
}

func load_scenario(name: String, session: SessionManager, rule_engine: RuleEngine) -> void:
	if not scenarios.has(name):
		push_warning("Scenario not found: %s" % name)
		return
	for ev in scenarios[name]:
		var delay: float = ev.get("time", 0.0)
		var rule_id: int = ev.get("rule_id", -1)
		var payload: Dictionary = ev.get("payload", {})
		# Schedule an event relative to the session start. When it triggers, call the rule engine.
		session.schedule_event_in(delay, Callable(self, "_trigger_rule").bind(rule_engine, session, rule_id, payload))

func _trigger_rule(rule_engine: RuleEngine, session: SessionManager, rule_id: int, payload: Dictionary) -> void:
	var current_time: float = session.sim_clock.current_time
	rule_engine.evaluate_event(rule_id, payload, current_time)
