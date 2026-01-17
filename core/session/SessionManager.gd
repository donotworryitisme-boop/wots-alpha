extends Node
class_name SessionManager

# Manages the lifecycle of a training session, including simulation clock, event queue, rules, and scenarios.

var sim_clock: SimClock
var event_queue: EventQueue
var rule_engine: RuleEngine
var scenario_loader: ScenarioLoader

var session_active: bool = false
var session_start_time: float = 0.0

func _ready() -> void:
	# Instantiate and add simulation clock
	sim_clock = SimClock.new()
	add_child(sim_clock)
	# Instantiate and add event queue
	event_queue = EventQueue.new()
	add_child(event_queue)
	# Connect clock tick to processing events
	sim_clock.connect("tick", Callable(self, "_on_tick"))
	# Instantiate rule engine and scenario loader
	rule_engine = RuleEngine.new()
	add_child(rule_engine)
	scenario_loader = ScenarioLoader.new()
	add_child(scenario_loader)

func start_session() -> void:
	if session_active:
		return
	session_active = true
	session_start_time = sim_clock.current_time
	# Reset clock time to zero for a new session
	sim_clock.current_time = 0.0
	# Clear any previous waste log
	rule_engine.waste_log.clear()
	# Load the default scenario and schedule its events
	scenario_loader.load_scenario("default", self, rule_engine)

func end_session() -> void:
	session_active = false
	# Could trigger session end events, scoring, etc., in later stages.

func schedule_event_in(delay: float, callback: Callable) -> void:
	# Convenience method to schedule events relative to the clock.
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(delta_time: float, current_time: float) -> void:
	if session_active:
		event_queue.process_events(current_time)
