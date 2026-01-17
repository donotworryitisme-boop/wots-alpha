extends Node
class_name SessionManager

signal hint_updated(hint_text: String)

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

# Scaffolding tiers (8.3)
var scaffold_source: String = "scenario" # "scenario" or "role"
var scaffold_tier_scenario: int = 1      # 1..3
var scaffold_tier_active: int = 1        # resolved at load time (scenario or role)

# Dynamic pressure state
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

	sim_clock.current_time = 0.0
	rule_engine.waste_log.clear()

	sorter_model.set_available(true)
	loading_model.set_sorter_model(sorter_model)

	role_manager.set_role(WOTSConfig.Role.OPERATOR)

	zero_score_mode = false
	score_engine.start_session()

	if feedback_layer != null:
		feedback_layer.reset()

	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0

	# Load default scenario (knobs + scaffold tier resolved there)
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
# Scaffolding tiers (8.3)

func set_scaffolding(source: String, tier: int) -> void:
	scaffold_source = source
	scaffold_tier_scenario = clamp(tier, 1, 3)

	# Resolve active tier:
	# - scenario: use scaffold_tier_scenario
	# - role: derive from current role (guided for trainers, partial for captains, none for operators by default)
	if scaffold_source == "role":
		scaffold_tier_active = _tier_for_role(role_manager.get_role())
	else:
		scaffold_tier_active = scaffold_tier_scenario

func _tier_for_role(role: int) -> int:
	if role == WOTSConfig.Role.TRAINER:
		return 1
	if role == WOTSConfig.Role.CAPTAIN:
		return 2
	return 3

func publish_hint(hint_text: String) -> void:
	# No score impact; hints are purely guidance and must not reveal outcomes.
	hint_updated.emit(hint_text)

# -------------------------------------------------------------------
# Pressure APIs used by ScenarioLoader and Rule evaluation

func register_interrupt(related_rule_id: int, timestamp: float) -> void:
	interruptions_since_last_decision += 1
	last_interrupt_at = timestamp
	WOTSLogger.log_info("Interrupt: benign event before rule %s at %0.2fs" % [str(related_rule_id), timestamp])

	if feedback_layer != null:
		feedback_layer.handle_event(0, false, timestamp)

func register_info_reveal(revealed: Dictionary, timestamp: float) -> void:
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
	var ctx: Dictionary = {}
	ctx["rule_id"] = rule_id
	ctx["now"] = current_time

	# Time pressure
	ctx["time_slack"] = time_slack
	ctx["time_pressure"] = time_pressure
	ctx["decision_time"] = decision_time
	ctx["decision_window"] = decision_window
	ctx["deadline"] = decision_time

	# Interruptions
	ctx["interruptions"] = interruptions_since_last_decision
	ctx["last_interrupt_at"] = last_interrupt_at

	# Ambiguity
	ctx["ambiguous"] = bool(payload.get("ambiguous", false))
	ctx["withheld"] = payload.get("_withheld", {})

	var delay_seconds: float = float(payload.get("info_delay_seconds", 0.0))
	if delay_seconds > 0.0:
		ctx["info_available"] = false
		ctx["info_delay_seconds"] = delay_seconds
	else:
		ctx["info_available"] = true
		ctx["info_delay_seconds"] = 0.0

	# Scaffolding tier (8.3)
	ctx["scaffold_tier"] = scaffold_tier_active
	ctx["hint"] = _build_hint_for_tier(rule_id, payload, ctx, scaffold_tier_active)

	return ctx

func _build_hint_for_tier(rule_id: int, payload: Dictionary, ctx: Dictionary, tier: int) -> String:
	# Hints must not reveal outcomes. They are process reminders only.
	# Tier 1: guided, explicit reminder steps
	# Tier 2: partial reminder
	# Tier 3: no hints
	if tier >= 3:
		return ""

	var ambiguous: bool = bool(ctx.get("ambiguous", false))
	var intr: int = int(ctx.get("interruptions", 0))

	var base: String = ""
	match rule_id:
		1:
			base = "Stay on the standard placement sequence. Confirm location and stage before moving."
		2:
			base = "Scan workflow reminder: confirm scan requirement, then verify the pallet ID."
		_:
			base = "Follow the standard operating steps and confirm required fields before acting."

	# Tier 2: shorter, less explicit
	if tier == 2:
		base = base.split(".")[0] + "."

	# Add non-outcome, context-only note (still not revealing result)
	if ambiguous:
		base += " Info may be incomplete—double-check what you can confirm."
	if intr > 0:
		base += " Ignore non-critical noise and re-check your last confirmed step."

	return base

# -------------------------------------------------------------------
# Role and capability APIs

func set_role(role: int) -> void:
	role_manager.set_role(role)
	# If scaffolding is role-based, update active tier when role changes.
	if scaffold_source == "role":
		scaffold_tier_active = _tier_for_role(role_manager.get_role())

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
