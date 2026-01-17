extends Node
class_name ScenarioLoader

# Loads scenario seeds, applies pressure knobs, and schedules events into a session.

var scenarios: Dictionary = {
	# Default scenario with pressure knobs and scaffold tier defined.
	"default": {
		"events": [
			{"time": 2.0, "rule_id": 1, "payload": {}},
			{"time": 5.0, "rule_id": 2, "payload": {}}
		],
		"knobs": {
			"interrupt_frequency": 0.05,  # Noise events per second of scenario duration
			"ambiguity_level": 0.0,       # Chance each event is marked ambiguous
			"time_slack": 1.0             # Multiply event times by this factor
		},
		"scaffold_tier": 1
	}
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func load_scenario(name: String, session: SessionManager, rule_engine: RuleEngine) -> void:
	# Ensure the scenario exists.
	if not scenarios.has(name):
		push_warning("Scenario not found: %s" % name)
		return

	var scenario_data = scenarios[name]
	# Support old array-only scenarios for backward compatibility
	var events: Array = []
	if scenario_data.has("events"):
		events = scenario_data["events"]
	else:
		events = scenario_data  # If scenario is an array, treat it directly
	# Pressure knobs
	var knobs: Dictionary = scenario_data.get("knobs", {})
	session.interrupt_frequency = float(knobs.get("interrupt_frequency", 0.0))
	session.ambiguity_level    = float(knobs.get("ambiguity_level",    0.0))
	session.time_slack         = float(knobs.get("time_slack",         1.0))
	# Compute total duration (after applying time_slack) to inform noise scheduling.
	var max_time: float = 0.0
	for ev in events:
		var scaled_time: float = float(ev.get("time", 0.0)) * session.time_slack
		if scaled_time > max_time:
			max_time = scaled_time

	# Schedule scenario events with scaled times and possible ambiguity.
	rng.randomize()
	for ev in events:
		var delay: float = float(ev.get("time", 0.0)) * session.time_slack
		var rule_id: int = int(ev.get("rule_id", -1))
		var payload: Dictionary = ev.get("payload", {}).duplicate()
		# Mark some events as ambiguous based on ambiguity_level.
		if session.ambiguity_level > 0.0 and rng.randf() < session.ambiguity_level:
			payload["ambiguous"] = true
		session.schedule_event_in(delay, Callable(self, "_trigger_rule").bind(rule_engine, session, rule_id, payload))

	# Schedule noise events according to interrupt_frequency.
	if session.interrupt_frequency > 0.0 and max_time > 0.0:
		var noise_count: int = int(max_time * session.interrupt_frequency)
		for i in range(noise_count):
			var noise_time: float = rng.randf_range(0.0, max_time)
			session.schedule_event_in(noise_time, Callable(self, "_trigger_noise").bind(session))

func _trigger_rule(rule_engine: RuleEngine, session: SessionManager, rule_id: int, payload: Dictionary) -> void:
	var current_time: float = session.sim_clock.current_time
	var produces_waste: bool = rule_engine.evaluate_event(rule_id, payload, current_time)
	# Update the score if a score engine exists
	if session.score_engine != null:
		session.score_engine.apply_rule(rule_id, produces_waste)
	# Notify the feedback layer of the event
	if session.feedback_layer != null:
		session.feedback_layer.handle_event(rule_id, produces_waste, current_time)

func _trigger_noise(session: SessionManager) -> void:
	# Noise events are benign (rule_id = 0, no waste). They add realism without penalty.
	var current_time: float = session.sim_clock.current_time
	if session.score_engine != null:
		session.score_engine.apply_rule(0, false)
	if session.feedback_layer != null:
		session.feedback_layer.handle_event(0, false, current_time)
