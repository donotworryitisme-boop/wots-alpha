extends Node
class_name SessionManager

signal hint_updated(hint_text: String)
signal time_updated(total_time: float, loading_time: float)
signal situation_updated(objective_text: String)
signal session_ended(debrief_payload: Dictionary)
signal action_registered(one_line: String)

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

# Alpha-safe harness timeline (no UI FeedbackLayer instancing)
var timeline_lines: Array[String] = []

# Pressure knobs (8.2)
var interrupt_frequency: float = 0.0
var ambiguity_level: float = 0.0
var time_slack: float = 1.0
var time_pressure: float = 0.0

# Scaffolding tiers (8.3)
var scaffold_source: String = "scenario"
var scaffold_tier_scenario: int = 1
var scaffold_tier_active: int = 1

# Dynamic pressure state
var interruptions_since_last_decision: int = 0
var last_interrupt_at: float = -1.0

# Harness state
var session_active: bool = false
var current_objective: String = "(none)"
var loading_time_accum: float = 0.0

# Score safety (ScoreEngine expects this API)
var zero_score_mode: bool = false

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

func start_session_with_scenario(scenario_name: String) -> void:
	if session_active:
		return

	session_active = true
	sim_clock.current_time = 0.0

	# Reset
	rule_engine.waste_log.clear()
	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0
	current_objective = "(none)"
	loading_time_accum = 0.0
	zero_score_mode = false
	timeline_lines.clear()

	score_engine.start_session()

	publish_hint("")
	set_current_objective("(waiting for first event)")

	_add_timeline_line("%0.2fs: Session started — scenario: %s" % [sim_clock.current_time, scenario_name])

	# Load scenario and schedule its events (knobs + scaffolding applied there)
	scenario_loader.load_scenario(scenario_name, self, rule_engine)

func start_session() -> void:
	start_session_with_scenario("default")

func end_session() -> void:
	if not session_active:
		return

	session_active = false
	score_engine.end_session(self)

	_add_timeline_line("%0.2fs: Session ended" % sim_clock.current_time)

	# Build debrief payload with clearly separated sections
	var what_happened := ""
	what_happened += "[b]Final score:[/b] %d\n\n" % score_engine.current_score
	what_happened += "[b]Events[/b]\n"
	for line in timeline_lines:
		what_happened += "• " + line + "\n"

	var waste_count: int = rule_engine.waste_log.size()
	var why := ""
	# Keep this process-focused; do not reveal alternate outcomes.
	if waste_count > 0:
		why += "Some moments produced waste signals. Under pressure (time, ambiguity, interruptions), small misses stack up.\n"
		why += "Use the action buttons to slow down, clarify unknowns, and re-check priority steps.\n"
	else:
		why += "This run produced no waste signals. Consistent checking and clean handoffs reduce rework under pressure.\n"

	var payload := {
		"what_happened": what_happened,
		"why_it_mattered": why
	}

	session_ended.emit(payload)

func manual_decision(action: String) -> void:
	# Minimal “decision event” pushed into rule pipeline (generic, no outcome reveal).
	if not session_active:
		return

	var payload := {
		"action": action,
		"objective": current_objective
	}

	var ctx := {
		"scaffold_tier": scaffold_tier_active,
		"time_pressure": time_pressure,
		"interruptions": interruptions_since_last_decision
	}

	var t := sim_clock.current_time
	var produces_waste := rule_engine.evaluate_event(0, payload, ctx, t)
	score_engine.apply_rule(0, produces_waste)

	var one_line := "%0.2fs: Action registered: %s" % [t, action]
	action_registered.emit(one_line)

	_add_timeline_line("%0.2fs: Manual decision — %s" % [t, action])

func schedule_event_in(delay: float, callback: Callable) -> void:
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(_delta_time: float, current_time: float) -> void:
	if session_active:
		event_queue.process_events(current_time)
		time_updated.emit(sim_clock.current_time, loading_time_accum)

# --------------------------
# Scaffolding (8.3)

func set_scaffolding(source: String, tier: int) -> void:
	scaffold_source = source
	scaffold_tier_scenario = clamp(tier, 1, 3)

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
	hint_updated.emit(hint_text)

# --------------------------
# Objective / situation

func set_current_objective(text: String) -> void:
	current_objective = text
	situation_updated.emit(current_objective)

# --------------------------
# Timeline hooks used by ScenarioLoader

func record_rule_result(rule_id: int, produces_waste: bool, timestamp: float) -> void:
	var tag := "Good"
	if produces_waste:
		tag = "Waste"
	_add_timeline_line("%0.2fs: Rule %d — %s" % [timestamp, rule_id, tag])

# --------------------------
# Pressure APIs (8.2)

func register_interrupt(_related_rule_id: int, timestamp: float) -> void:
	interruptions_since_last_decision += 1
	last_interrupt_at = timestamp

	_add_timeline_line("%0.2fs: Interrupt (non-critical noise)" % timestamp)

func register_info_reveal(revealed: Dictionary, timestamp: float) -> void:
	_add_timeline_line("%0.2fs: Info reveal: %s" % [timestamp, str(revealed)])

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

	ctx["time_slack"] = time_slack
	ctx["time_pressure"] = time_pressure
	ctx["decision_time"] = decision_time
	ctx["decision_window"] = decision_window
	ctx["deadline"] = decision_time

	ctx["interruptions"] = interruptions_since_last_decision
	ctx["last_interrupt_at"] = last_interrupt_at

	ctx["ambiguous"] = bool(payload.get("ambiguous", false))
	ctx["withheld"] = payload.get("_withheld", {})

	var delay_seconds: float = float(payload.get("info_delay_seconds", 0.0))
	if delay_seconds > 0.0:
		ctx["info_available"] = false
		ctx["info_delay_seconds"] = delay_seconds
	else:
		ctx["info_available"] = true
		ctx["info_delay_seconds"] = 0.0

	ctx["scaffold_tier"] = scaffold_tier_active
	ctx["hint"] = _build_hint_for_tier(rule_id, ctx, scaffold_tier_active)

	return ctx

func _build_hint_for_tier(rule_id: int, ctx: Dictionary, tier: int) -> String:
	# Process-only hints; no outcome revelation.
	if tier >= 3:
		return ""

	var ambiguous: bool = bool(ctx.get("ambiguous", false))
	var intr: int = int(ctx.get("interruptions", 0))

	var base: String = ""
	match rule_id:
		1:
			base = "Confirm location and stage before moving. Follow the standard placement sequence."
		2:
			base = "Scan workflow reminder: verify scan requirement, then confirm pallet ID."
		_:
			base = "Follow the standard steps and confirm required fields before acting."

	if tier == 2:
		base = base.split(".")[0] + "."

	if ambiguous:
		base += " Info may be incomplete—confirm what you can."
	if intr > 0:
		base += " Ignore non-critical noise and re-check last confirmed step."

	return base

# --------------------------
# Role

func set_role(role: int) -> void:
	role_manager.set_role(role)
	if scaffold_source == "role":
		scaffold_tier_active = _tier_for_role(role_manager.get_role())

func get_role() -> int:
	return role_manager.get_role()

func has_capability(capability: String) -> bool:
	return role_manager.has_capability(capability)

# --------------------------
# Zero-score mode API expected by ScoreEngine

func set_zero_score_mode(enabled: bool) -> void:
	zero_score_mode = enabled

func is_zero_score_mode() -> bool:
	return zero_score_mode

# --------------------------
# Internals

func _add_timeline_line(line: String) -> void:
	timeline_lines.append(line)
