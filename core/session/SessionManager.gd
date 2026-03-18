extends Node
class_name SessionManager

signal hint_updated(hint_text: String)
signal time_updated(total_time: float, loading_time: float)
signal situation_updated(objective_text: String)
signal session_ended(debrief_payload: Dictionary)
signal action_registered(one_line: String)
signal role_updated(role_id: int)
signal responsibility_boundary_updated(role_id: int, assignment_text: String, window_active: bool)
signal inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float)
signal as400_status_updated(total_uats: int, total_col: int, loaded_uats: int, loaded_col: int)

enum ScenarioState { INIT, ASSIGNED, PREPARED, LOADING, CLOSABLE, CLOSED }
var current_state: int = ScenarioState.INIT

var called_departments_early: bool = false
var c_and_c_loaded: bool = false
var time_penalty_applied: bool = false

var sim_clock: SimClock
var event_queue: EventQueue
var rule_engine: RuleEngine
var scenario_loader
var sorter_model
var loading_model
var role_manager
var score_engine

var timeline_lines: Array[String] = []
var interrupt_frequency: float = 0.0
var ambiguity_level: float = 0.0
var time_slack: float = 1.0
var time_pressure: float = 0.0
var scaffold_source: String = "scenario"
var scaffold_tier_scenario: int = 1
var scaffold_tier_active: int = 1
var interruptions_since_last_decision: int = 0
var last_interrupt_at: float = -1.0
var session_active: bool = false
var current_objective: String = "(none)"
var loading_time_accum: float = 0.0
var zero_score_mode: bool = false
var panel_catalog: Array[String] = []
var panels_ever_opened: Dictionary = {}
var current_assignment: String = "Unassigned"
var responsibility_window_active: bool = false
var escalation_used_count: int = 0

# --- DYNAMIC INVENTORY VARIABLES ---
var inv_available: Array = []
var inv_loaded: Array = []
var truck_cap_max: float = 36.0
var truck_cap_used: float = 0.0
var as400_confirmed: bool = false
var time_elapsed: float = 0.0 # Minutes
var unloaded_count: int = 0 # Track mistakes!
var service_center_count: int = 6

func _ready() -> void:
	sim_clock = SimClock.new()
	add_child(sim_clock)
	event_queue = EventQueue.new()
	add_child(event_queue)
	sim_clock.connect("tick", Callable(self, "_on_tick"))
	rule_engine = RuleEngine.new()
	add_child(rule_engine)
	scenario_loader = load("res://core/scenarios/ScenarioLoader.gd").new()
	add_child(scenario_loader)
	sorter_model = load("res://core/domain/SorterModel.gd").new()
	add_child(sorter_model)
	loading_model = load("res://core/domain/LoadingModel.gd").new()
	add_child(loading_model)
	loading_model.set_sorter_model(sorter_model)
	role_manager = load("res://core/roles/RoleManager.gd").new()
	add_child(role_manager)
	score_engine = load("res://core/scoring/ScoreEngine.gd").new()
	add_child(score_engine)
	_emit_boundary_update()

func register_panel_catalog(names: Array[String]) -> void:
	panel_catalog = names.duplicate()
	panels_ever_opened.clear()
	for n in panel_catalog: panels_ever_opened[str(n)] = false

func panel_opened(panel_name: String) -> void:
	var t: float = sim_clock.current_time
	panels_ever_opened[panel_name] = true
	var line := "%0.2fs: Panel opened — %s" % [t, panel_name]
	action_registered.emit(line)
	_add_timeline_line(line)

func panel_closed(panel_name: String) -> void:
	var t: float = sim_clock.current_time
	var line := "%0.2fs: Panel closed — %s" % [t, panel_name]
	action_registered.emit(line)
	_add_timeline_line(line)

func start_session_with_scenario(scenario_name: String) -> void:
	if session_active: return
	session_active = true
	sim_clock.current_time = 0.0
	current_state = ScenarioState.INIT
	called_departments_early = false
	c_and_c_loaded = false
	time_penalty_applied = false
	rule_engine.waste_log.clear()
	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0
	current_objective = "(none)"
	loading_time_accum = 0.0
	zero_score_mode = false
	timeline_lines.clear()
	escalation_used_count = 0
	unloaded_count = 0
	if panel_catalog.size() > 0:
		for n in panel_catalog: panels_ever_opened[str(n)] = false
	current_assignment = "Bay B2B session"
	responsibility_window_active = true
	_emit_boundary_update()
	score_engine.start_session()
	
	_add_timeline_line("%0.2fs: Session started — scenario: %s" % [sim_clock.current_time, scenario_name])
	scenario_loader.load_scenario(scenario_name, self, rule_engine)
	
	_generate_inventory(scenario_name)
	set_current_objective("Check AS400 expected capacity vs Dock View physical pallets.")

func start_session() -> void:
	start_session_with_scenario("default")

func end_session() -> void:
	if not session_active: return
	session_active = false
	score_engine.end_session(self)
	responsibility_window_active = false
	_emit_boundary_update()
	_add_timeline_line("%0.2fs: Session ended" % sim_clock.current_time)
	
	var what_happened := "[b]Events[/b]\n"
	for line in timeline_lines: what_happened += "• " + line + "\n"
	
	# NEW: TIME CALCULATION & WARNINGS
	var why := "Estimated Total Loading Time: [b]%0.1f minutes[/b].\n" % time_elapsed
	
	if unloaded_count > 0:
		var waste_time = unloaded_count * 1.1
		if unloaded_count >= 3:
			why += "\n[color=#e74c3c]⚠️ REWORK WARNING: You pulled %d pallets off the truck during loading. This added %0.1f minutes of wasted rework time. Plan your sequence carefully before loading.[/color]\n" % [unloaded_count, waste_time]
		else:
			why += "\n[color=#f39c12]Note: You pulled %d pallets off the truck, adding %0.1f minutes of rework.[/color]\n" % [unloaded_count, waste_time]

	var payload := {"what_happened": what_happened, "why_it_mattered": why}
	session_ended.emit(payload)

func manual_decision(action: String) -> void:
	if not session_active: return
	var t := sim_clock.current_time

	if action == "Call departments (C&C check)":
		var any_missing = false
		for p in inv_available:
			if p.missing: any_missing = true

		if current_state <= ScenarioState.PREPARED:
			if any_missing:
				called_departments_early = true
				current_state = ScenarioState.PREPARED
				set_current_objective("Departments looking for missing pallets. Ready to load.")
				_add_timeline_line("%0.2fs: ✔️ Called departments early to find missing pallets." % t)
				schedule_event_in(3.0, Callable(self, "_reveal_missing_pallets"))
			else:
				sim_clock.current_time += 2.0
				time_elapsed += 2.0
				current_state = ScenarioState.PREPARED
				_add_timeline_line("%0.2fs: ⚠️ Called departments, but all pallets were already on dock. (+2m time wasted)" % t)
				
		elif current_state == ScenarioState.LOADING:
			if any_missing:
				sim_clock.current_time += 15.0
				time_elapsed += 15.0
				_add_timeline_line("%0.2fs: ❌ Called departments LATE for missing pallets. (+15m penalty)" % t)
				_reveal_missing_pallets()
			else:
				sim_clock.current_time += 2.0
				time_elapsed += 2.0
				_add_timeline_line("%0.2fs: ⚠️ Called departments late, but nothing was missing. (+2m time wasted)" % t)

	elif action == "Start Loading" and current_state <= ScenarioState.PREPARED:
		current_state = ScenarioState.LOADING
		set_current_objective("Loading in progress. Use Dock View or Quick Buttons.")
		_add_timeline_line("%0.2fs: Started Loading Phase." % t)

	elif action == "Confirm AS400":
		as400_confirmed = true
		_add_timeline_line("%0.2fs: Confirmed RAQ in AS400." % t)

	elif action == "Seal Truck":
		current_state = ScenarioState.CLOSED
		if not as400_confirmed and inv_available.size() > 0:
			_add_timeline_line("%0.2fs: ❌ AS400: Sealed truck without confirming final RAQ!" % t)

		var left_priority = 0
		var left_cc = 0
		for p in inv_available:
			if p.type == "C&C": left_cc += 1
			elif p.p_val <= 0 and p.promise != "N/A": left_priority += 1

		var type_ranks = {"ServiceCenter": 0, "Bikes": 1, "Bulky": 2, "Mecha": 3, "C&C": 4}
		var order_broken = false
		var last_rank = -1
		for p in inv_loaded:
			var rank = type_ranks.get(p.type, -1)
			if rank < last_rank:
				order_broken = true
				break
			last_rank = max(last_rank, rank)

		var flawless = true
		
		if left_cc > 0:
			_add_timeline_line("%0.2fs: ❌ CRITICAL: Left %d mandatory C&C pallets behind!" % [t, left_cc])
			flawless = false
		else:
			_add_timeline_line("%0.2fs: ✔️ C&C Pallets: All mandatory C&C successfully loaded." % t)

		var loaded_d_plus = false
		for p in inv_loaded:
			if p.p_val > 0: loaded_d_plus = true
			
		if left_priority > 0 and (loaded_d_plus or truck_cap_used >= truck_cap_max - 1.0):
			_add_timeline_line("%0.2fs: ❌ PROMISE DATES: Left %d priority (D/D-) pallets behind while space was taken by D+." % [t, left_priority])
			flawless = false
		elif left_priority == 0:
			_add_timeline_line("%0.2fs: ✔️ PROMISE DATES: All priority pallets (D/D-) successfully loaded." % t)

		if order_broken:
			_add_timeline_line("%0.2fs: ❌ LOADING ORDER: Pallets loaded out of sequence! This delays unloading." % t)
			flawless = false
		elif inv_loaded.size() > 0:
			_add_timeline_line("%0.2fs: ✔️ LOADING ORDER: Perfect physical sequence used." % t)

		if flawless:
			_add_timeline_line("%0.2fs: 🏆 PERFECT LOAD! All constraints and priorities flawlessly managed." % t)

		set_current_objective("Truck Sealed. Scenario Complete.")
		end_session() 
		return

	var payload := {"action": action, "objective": current_objective}
	var ctx := {"scaffold_tier": scaffold_tier_active, "time_pressure": time_pressure, "interruptions": interruptions_since_last_decision}
	var produces_waste := rule_engine.evaluate_event(0, payload, ctx, t)
	score_engine.apply_rule(0, produces_waste)
	action_registered.emit("%0.2fs: Action registered: %s" % [t, action])

func schedule_event_in(delay: float, callback: Callable) -> void:
	event_queue.schedule_event_in(delay, callback, sim_clock)

func schedule_event_at(time: float, callback: Callable) -> void:
	event_queue.schedule_event_at(time, callback)

func _on_tick(_delta_time: float, current_time: float) -> void:
	if session_active:
		event_queue.process_events(current_time)
		time_updated.emit(sim_clock.current_time, loading_time_accum)

func set_scaffolding(source: String, tier: int) -> void:
	scaffold_source = source
	scaffold_tier_scenario = clamp(tier, 1, 3)
	if scaffold_source == "role": scaffold_tier_active = _tier_for_role(role_manager.get_role())
	else: scaffold_tier_active = scaffold_tier_scenario

func _tier_for_role(role: int) -> int:
	if role == WOTSConfig.Role.TRAINER: return 1
	if role == WOTSConfig.Role.CAPTAIN: return 2
	return 3

func publish_hint(hint_text: String) -> void: hint_updated.emit(hint_text)
func set_current_objective(text: String) -> void:
	current_objective = text
	situation_updated.emit(current_objective)
func set_assignment(text: String) -> void:
	current_assignment = text
	_emit_boundary_update()
func set_responsibility_window(active: bool) -> void:
	responsibility_window_active = active
	_emit_boundary_update()
func _emit_boundary_update() -> void:
	responsibility_boundary_updated.emit(role_manager.get_role(), current_assignment, responsibility_window_active)
func record_rule_result(rule_id: int, produces_waste: bool, timestamp: float) -> void:
	var tag := "Aligned with priorities"
	if produces_waste: tag = "Unfavorable outcome"
	_add_timeline_line("%0.2fs: Rule %d — %s" % [timestamp, rule_id, tag])
func register_interrupt(_related_rule_id: int, timestamp: float) -> void:
	interruptions_since_last_decision += 1
	last_interrupt_at = timestamp
	_add_timeline_line("%0.2fs: Interrupt (non-critical noise)" % timestamp)
func register_info_reveal(revealed: Dictionary, timestamp: float) -> void:
	_add_timeline_line("%0.2fs: Info reveal: %s" % [timestamp, str(revealed)])
func consume_interruptions() -> void:
	interruptions_since_last_decision = 0
	last_interrupt_at = -1.0

func build_decision_context(rule_id: int, payload: Dictionary, current_time: float, decision_time: float, decision_window: float) -> Dictionary:
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
	if tier >= 3: return ""
	var ambiguous: bool = bool(ctx.get("ambiguous", false))
	var intr: int = int(ctx.get("interruptions", 0))
	var base: String = ""
	match rule_id:
		1: base = "Confirm location and stage before moving. Follow the standard placement sequence."
		2: base = "Scan workflow reminder: verify scan requirement, then confirm pallet ID."
		_: base = "Follow the standard steps and confirm required fields before acting."
	if tier == 2: base = base.split(".")[0] + "."
	if ambiguous: base += " Info may be incomplete—confirm what you can."
	if intr > 0: base += " Ignore non-critical noise and re-check last confirmed step."
	return base

func set_role(role: int) -> void:
	role_manager.set_role(role)
	if scaffold_source == "role": scaffold_tier_active = _tier_for_role(role_manager.get_role())
	role_updated.emit(role)
	_emit_boundary_update()

func get_role() -> int: return role_manager.get_role()
func has_capability(capability: String) -> bool: return role_manager.has_capability(capability)
func set_zero_score_mode(enabled: bool) -> void: zero_score_mode = enabled
func is_zero_score_mode() -> bool: return zero_score_mode
func _add_timeline_line(line: String) -> void: timeline_lines.append(line)

func _generate_inventory(scenario_name: String) -> void:
	inv_available.clear()
	inv_loaded.clear()
	truck_cap_used = 0.0
	time_elapsed = 0.0
	as400_confirmed = false

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	service_center_count = rng.randi_range(1, 3)
	for i in range(service_center_count):
		inv_available.append({
			"id": "SC-" + str(i), 
			"type": "ServiceCenter", 
			"code": "N/A",
			"promise": "N/A", 
			"p_val": 0,
			"collis": 1, 
			"cap": 0.5, 
			"is_uat": false, 
			"missing": false
		})

	var cc_count = rng.randi_range(2, 4)
	var missing_idx = -1
	if rng.randf() > 0.5: missing_idx = rng.randi_range(0, cc_count - 1)
	
	for i in range(cc_count):
		inv_available.append({
			"id": "CC-" + str(i+1), "type": "C&C", "code": "MAP", "promise": "D", 
			"p_val": 0, "collis": rng.randi_range(3, 12), "cap": 1.0, "is_uat": true, 
			"missing": (i == missing_idx)
		})

	if scenario_name == "Standard Loading":
		for i in range(2): inv_available.append({"id": "B-" + str(i), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false})
		for i in range(10): inv_available.append({"id": "BLK-" + str(i), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(16): inv_available.append({"id": "M-" + str(i), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})
	else:
		for i in range(2): inv_available.append({"id": "B-" + str(i), "type": "Bikes", "code": "MAG", "promise": "D-", "p_val": -1, "collis": 6, "cap": 1.3, "is_uat": true, "missing": false})
		for i in range(2): inv_available.append({"id": "B-" + str(i+2), "type": "Bikes", "code": "MAG", "promise": "D+", "p_val": 1, "collis": 6, "cap": 1.3, "is_uat": true, "missing": false})
		
		for i in range(3): inv_available.append({"id": "BLK-" + str(i), "type": "Bulky", "code": "MAG", "promise": "D", "p_val": 0, "collis": 15, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(3): inv_available.append({"id": "BLK-" + str(i+3), "type": "Bulky", "code": "MAG", "promise": "D+", "p_val": 1, "collis": 15, "cap": 1.0, "is_uat": true, "missing": false})
		
		for i in range(15): inv_available.append({"id": "M-" + str(i), "type": "Mecha", "code": "MAP", "promise": "D+", "p_val": 1, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(8): inv_available.append({"id": "MD-" + str(i), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})

	inv_available.shuffle()
	_emit_inventory()

func load_pallet_by_id(id: String) -> void:
	if current_state < ScenarioState.LOADING:
		_add_timeline_line("Cannot load yet. Start loading first!")
		return

	var to_load = null
	for p in inv_available:
		if p.id == id and not p.missing:
			to_load = p
			break

	if to_load == null: return

	var sc_left = false
	for p in inv_available:
		if p.type == "ServiceCenter" and not p.missing: sc_left = true
	
	if sc_left and to_load.type != "ServiceCenter":
		_add_timeline_line("⚠️ Sequence Warning: Loaded %s before Service Center stands." % to_load.id)

	if truck_cap_used + to_load.cap > truck_cap_max:
		_add_timeline_line("Truck is full! Cannot load %s." % to_load.id)
		return

	inv_available.erase(to_load)
	inv_loaded.append(to_load)
	truck_cap_used += to_load.cap
	time_elapsed += 1.1 
	_add_timeline_line("Loaded %s (%s) - Promise: %s" % [to_load.id, to_load.type, to_load.promise])
	_emit_inventory()

# --- NEW: UNLOAD FUNCTION ---
func unload_pallet_by_id(id: String) -> void:
	if current_state < ScenarioState.LOADING: return
	
	var idx = -1
	for i in range(inv_loaded.size()):
		if inv_loaded[i].id == id:
			idx = i
			break
			
	if idx == -1: return
	
	# LIFO CHECK: You can only physically reach the last 3 pallets loaded (the tail)
	if idx < inv_loaded.size() - 3:
		_add_timeline_line("⚠️ Cannot unload %s. It is blocked by pallets in front of it! You must unload the tail first." % id)
		return
	
	var to_unload = inv_loaded[idx]
	inv_loaded.erase(to_unload)
	inv_available.append(to_unload)
	truck_cap_used -= to_unload.cap
	time_elapsed += 1.1 # Penalty for pulling it off
	unloaded_count += 1
	
	_add_timeline_line("⚠️ Unloaded %s (%s) back to the dock." % [to_unload.id, to_unload.type])
	_emit_inventory()

func load_random_pallet(type: String) -> void:
	var candidates = []
	for p in inv_available:
		if p.type == type and not p.missing:
			candidates.append(p)
	if candidates.size() > 0:
		var pick = candidates[randi() % candidates.size()]
		load_pallet_by_id(pick.id)
	else:
		_add_timeline_line("No visible %s pallets left to load!" % type)

func _reveal_missing_pallets() -> void:
	var found = 0
	for p in inv_available:
		if p.missing:
			p.missing = false
			found += 1
	if found > 0:
		_add_timeline_line("Departments delivered %d missing pallets to the dock!" % found)
		_emit_inventory()

func _emit_inventory() -> void:
	var total_uats = inv_available.size() + inv_loaded.size()
	var total_col = 0
	for p in inv_available: total_col += p.collis
	for p in inv_loaded: total_col += p.collis

	var loaded_uats = inv_loaded.size()
	var loaded_col = 0
	for p in inv_loaded: loaded_col += p.collis

	inventory_updated.emit(inv_available.duplicate(true), inv_loaded.duplicate(true), truck_cap_used, truck_cap_max)
	as400_status_updated.emit(total_uats, total_col, loaded_uats, loaded_col)
	if current_state == ScenarioState.LOADING:
		set_current_objective("Loading in progress. Capacity: %0.1f / %0.1f" % [truck_cap_used, truck_cap_max])
