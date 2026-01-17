extends Node
class_name SessionManager

# Manages the lifecycle of a training session, including simulation clock, event queue, rules, scenarios,
# domain models, role management, zero-score mode, scoring, feedback, and pressure knobs.

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

# Pressure knob values (set by ScenarioLoader)
var interrupt_frequency: float = 0.0
var ambiguity_level: float = 0.0
var time_slack: float = 1.0
var time_pressure: float = 0.0

# Dynamic pressure state that affects decision context
var interruptions_since_last_decision: int = 0
var last_interrupt_at: float = -1.0

var session_active: bool = false
var session_start_time: float = 0.0

func _ready() -> void:
	sim_clock = SimClock.new()
	add_child(sim_clock)

	event_queue = EventQueue.new()
	add_child(event_queue)

	sim_clock.connect("tick", Callable(self, "_on_tick"))

	rule_engine = RuleEngine.new()
	add_child(rule_engine)

	scenario_loader = ScenarioLoader.new()
	add_child(scenario_loader)

	sorter_model = SorterModel.new()
	add_child(sorter_model)

	loading_model = LoadingModel.new()
	add_child(loading_model)
	loading_model.set_sorter_model(sorter_model)

	role_manager = RoleManager.new()
	add_child(role_manager)

	score_engine = ScoreEngine.new()
	add_child(score_engine)

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

	# Reset dynamic pressure state
	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0

	# Load the default scenario and schedule its events (pressure knobs are applied there)
	scenario_loader.load_scenario("default", self, rule_engine)

func end_session() -> void:
	session_active = false
	if score_engine != null:
		score_engine.end_session(self)

	if feedback_layer != null:
		feedback_layer.notify_session_end(score_engine.current_score)

func schedule_event_in(delay: float, callback: Callable) -> void:
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(_delta_time: float, current_time: float) -> void:
	if session_active:
		event_queue.process_events(current_time)

# -------------------------------------------------------------------
# Pressure APIs used by ScenarioLoader and Rule evaluation

func register_interrupt(related_rule_id: int, timestamp: float) -> void:
	# Inline behavior: interruptions are non-critical but they accumulate in decision context.
	interruptions_since_last_decision += 1
	last_interrupt_at = timestamp
	WOTSLogger.log_info("Interrupt: benign event before rule %s at %0.2fs" % [str(related_rule_id), timestamp])

	# Optional: surface a benign event to feedback layer (no scoring penalty).
	if feedback_layer != null:
		feedback_layer.handle_event(0, false, timestamp)

func register_info_reveal(revealed: Dictionary, timestamp: float) -> void:
	# Inline behavior: delayed info "arrives" later, showing ambiguity effects in the timeline.
	WOTSLogger.log_info("Info reveal at %0.2fs: %s" % [timestamp, str(revealed)])
	if feedback_layer != null:
		feedback_layer.handle_event(0, false, timestamp)

func consume_interruptions() -> void:
	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0

func build_decision_context(
	rule_id: int,
	payload: Dictionary,
	current_time: float,
	decision_time: float,
	decision_window: float
) -> Dictionary:
	# Decision context is what the "operator" effectively has available when making a decision.
	# Pressure affects this context (time pressure, ambiguity, interruptions) rather than only UI.
	var ctx: Dictionary = {}

	ctx["rule_id"] = rule_id
	ctx["now"] = current_time

	# Time pressure: slack maps into perceived urgency.
	ctx["time_slack"] = time_slack
	ctx["time_pressure"] = time_pressure

	# Deadline: under time pressure, less slack means less time to react.
	# This is contextual (used by rules/logic), not a UI timer.
	ctx["decision_time"] = decision_time
	ctx["decision_window"] = decision_window
	ctx["deadline"] = decision_time

	# Interruptions: count since last decision evaluation.
	ctx["interruptions"] = interruptions_since_last_decision
	ctx["last_interrupt_at"] = last_interrupt_at

	# Ambiguity: missing or delayed info
	ctx["ambiguous"] = bool(payload.get("ambiguous", false))
	ctx["withheld"] = payload.get("_withheld", {})

	# If info_delay_seconds is present, treat info as unavailable at decision time.
	var delay_seconds: float = float(payload.get("info_delay_seconds", 0.0))
	if delay_seconds > 0.0:
		ctx["info_available"] = false
		ctx["info_delay_seconds"] = delay_seconds
	else:
		ctx["info_available"] = true
		ctx["info_delay_seconds"] = 0.0

	return ctx

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
