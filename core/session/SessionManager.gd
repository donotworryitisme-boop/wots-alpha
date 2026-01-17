extends Node
class_name SessionManager

# Manages the lifecycle of a training session, including simulation clock, event queue, rules, scenarios,
# and domain models (sorter and loading docks).

const SorterModel    = preload("res://core/domain/SorterModel.gd")
const LoadingModel   = preload("res://core/domain/LoadingModel.gd")

var sim_clock: SimClock
var event_queue: EventQueue
var rule_engine: RuleEngine
var scenario_loader: ScenarioLoader
var sorter_model: SorterModel
var loading_model: LoadingModel

var session_active: bool = false
var session_start_time: float = 0.0

func _ready() -> void:
	# Instantiate simulation clock
	sim_clock = SimClock.new()
	add_child(sim_clock)
	# Instantiate event queue
	event_queue = EventQueue.new()
	add_child(event_queue)
	# Connect clock tick to event processing
	sim_clock.connect("tick", Callable(self, "_on_tick"))
	# Instantiate rule engine and scenario loader
	rule_engine = RuleEngine.new()
	add_child(rule_engine)
	scenario_loader = ScenarioLoader.new()
	add_child(scenario_loader)
	# Instantiate domain models
	sorter_model  = SorterModel.new()
	add_child(sorter_model)
	loading_model = LoadingModel.new()
	add_child(loading_model)
	loading_model.set_sorter_model(sorter_model)

func start_session() -> void:
	if session_active:
		return
	session_active = true
	session_start_time = sim_clock.current_time
	# Reset clock time to zero for a new session
	sim_clock.current_time = 0.0
	# Clear previous waste log
	rule_engine.waste_log.clear()
	# Reset sorter and loading model state
	sorter_model.set_available(true)
	loading_model.set_sorter_model(sorter_model)
	# Load the default scenario and schedule its events
	scenario_loader.load_scenario("default", self, rule_engine)

func end_session() -> void:
	session_active = false
	# Future: trigger scoring, etc.

func schedule_event_in(delay: float, callback: Callable) -> void:
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(delta_time: float, current_time: float) -> void:
	if session_active:
		event_queue.process_events(current_time)
