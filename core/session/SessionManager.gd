extends Node
class_name SessionManager

# Manages the lifecycle of a training session, including simulation clock, event queue, rules, scenarios,
# domain models (sorter and loading docks), role management, zero-score mode, scoring, and feedback.

@warning_ignore("shadowed_global_identifier")
const SorterModel  = preload("res://core/domain/SorterModel.gd")
const LoadingModel = preload("res://core/domain/LoadingModel.gd")
const ScoreEngine  = preload("res://core/scoring/ScoreEngine.gd")

var sim_clock: SimClock
var event_queue: EventQueue
var rule_engine: RuleEngine
var scenario_loader: ScenarioLoader
var sorter_model: SorterModel
var loading_model: LoadingModel
var role_manager: RoleManager
var score_engine: ScoreEngine
var feedback_layer: FeedbackLayer = null
var zero_score_mode: bool = false

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
	# Instantiate role manager
	role_manager = RoleManager.new()
	add_child(role_manager)
	# Instantiate score engine
	score_engine = ScoreEngine.new()
	add_child(score_engine)
	# feedback_layer will be assigned externally (Main.gd)

func start_session() -> void:
	if session_active:
		return
	session_active = true
	session_start_time = sim_clock.current_time
	# Reset simulation time
	sim_clock.current_time = 0.0
	# Clear previous waste log
	rule_engine.waste_log.clear()
	# Reset sorter and loading model state
	sorter_model.set_available(true)
	loading_model.set_sorter_model(sorter_model)
	# Reset role to default (operator) at session start
	role_manager.set_role(WOTSConfig.Role.OPERATOR)
	zero_score_mode = false
	# Reset scoring
	score_engine.start_session()
	# Reset feedback layer
	if feedback_layer != null:
		feedback_layer.reset()
	# Load the default scenario and schedule its events
	scenario_loader.load_scenario("default", self, rule_engine)

func end_session() -> void:
	session_active = false
	# Record the final score if appropriate
	if score_engine != null:
		score_engine.end_session(self)
	# Notify feedback layer that the session has ended
	if feedback_layer != null:
		feedback_layer.notify_session_end(score_engine.current_score)
	# Future: trigger scoring, etc.

func schedule_event_in(delay: float, callback: Callable) -> void:
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(_delta_time: float, current_time: float) -> void:
	# Use underscore to avoid unused-parameter warnings
	if session_active:
		event_queue.process_events(current_time)

# -------------------------------------------------------------------
# Role and capability APIs

func set_role(role: int) -> void:
	role_manager.set_role(role)

func get_role() -> int:
	return role_manager.get_role()

func has_capability(capability: String) -> bool:
	return role_manager.has_capability(capability)

# -------------------------------------------------------------------
# Zero-score mode APIs

func set_zero_score_mode(enabled: bool) -> void:
	zero_score_mode = enabled

func is_zero_score_mode() -> bool:
	return zero_score_mode
