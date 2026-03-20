extends Node

signal time_updated(total_time, loading_time)
signal session_ended(debrief_payload)
signal role_updated(role_id)
signal responsibility_boundary_updated(role_id, assignment_text, window_active)
signal inventory_updated(available, loaded, cap_used, cap_max)

var scenario_loader = null
var current_scenario = ""
var total_time: float = 0.0
var is_paused: bool = false
var is_active: bool = false

var inventory_available: Array = []
var inventory_loaded: Array = []
var capacity_max: float = 36.0
var capacity_used: float = 0.0

var _manual_decisions: Array = []
var unload_count: int = 0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if is_active and not is_paused:
		total_time += delta
		emit_signal("time_updated", total_time, 0.0)

func set_pause_state(paused: bool) -> void:
	is_paused = paused

func set_role(role_id: int) -> void:
	emit_signal("role_updated", role_id)
	var assignment = "Unassigned"
	if current_scenario != "":
		assignment = "Bay B2B — " + current_scenario
	emit_signal("responsibility_boundary_updated", role_id, assignment, true)

func start_session_with_scenario(scenario_name: String) -> void:
	current_scenario = scenario_name
	total_time = 0.0
	capacity_used = 0.0
	inventory_available.clear()
	inventory_loaded.clear()
	_manual_decisions.clear()
	unload_count = 0
	is_active = true
	is_paused = false
	
	_generate_inventory(scenario_name)
	_emit_inventory()
	set_role(1)

func manual_decision(action: String) -> void:
	_manual_decisions.append(action)
	
	if action == "Call departments (C&C check)":
		var found_missing = false
		for p in inventory_available:
			if p.missing:
				p.missing = false
				found_missing = true
		if found_missing:
			total_time += 300.0 # 5 minute penalty for waiting
			_emit_inventory() 
			
	elif action == "Seal Truck":
		end_session()

func _generate_inventory(scenario_name: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 1. Service Center
	for i in range(1):
		inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("ServiceCenter", rng), "type": "ServiceCenter", "code": "MAG", "promise": "D", "p_val": 0, "collis": 1, "cap": 0.5, "is_uat": true, "missing": false})
	
	# 2. C&C Pallets
	var cc_count = rng.randi_range(2, 4)
	var missing_idx = -1
	if scenario_name == "0. Tutorial": missing_idx = 0 
	elif rng.randf() > 0.5: missing_idx = rng.randi_range(0, cc_count - 1)
	
	for i in range(cc_count):
		inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 12), "cap": 1.0, "is_uat": true, "missing": (i == missing_idx)})

	# 3. Standard Pallets
	if scenario_name == "1. Standard Loading" or scenario_name == "0. Tutorial":
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false})
		for i in range(10): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(16): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})
	else:
		# Priority Loading Logic
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false})
		for i in range(15): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(20): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D+", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})
		for i in range(5): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D-", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false})

	inventory_available.shuffle()

func _generate_real_uat(rng: RandomNumberGenerator) -> String:
	return "00900084" + str(rng.randi_range(1000000, 9999999))
	
func _generate_real_colis(dept: String, rng: RandomNumberGenerator) -> String:
	var prefix = ""
	if dept == "Mecha": prefix = "8486"
	elif dept == "Bulky": prefix = "8490"
	elif dept == "Bikes": prefix = "8489"
	elif dept == "ServiceCenter": prefix = "0035"
	elif dept == "C&C": prefix = "8486" 
	return prefix + str(rng.randi_range(1000000000000000, 9999999999999999))

func load_pallet_by_id(id: String) -> void:
	var target = null
	for p in inventory_available:
		if p.id == id:
			target = p
			break
	if target and (capacity_used + target.cap) <= capacity_max:
		inventory_available.erase(target)
		inventory_loaded.append(target)
		capacity_used += target.cap
		_emit_inventory()

func unload_pallet_by_id(id: String) -> void:
	var target = null
	var idx = -1
	for i in range(inventory_loaded.size()):
		if inventory_loaded[i].id == id:
			target = inventory_loaded[i]
			idx = i
			break
	
	if target and idx >= (inventory_loaded.size() - 3):
		inventory_loaded.erase(target)
		inventory_available.append(target)
		capacity_used -= target.cap
		total_time += 66.0 # 1.1 minute penalty
		unload_count += 1 
		_emit_inventory()

func _emit_inventory() -> void:
	emit_signal("inventory_updated", inventory_available, inventory_loaded, capacity_used, capacity_max)

# ==========================================
# THE GRADING ENGINE
# ==========================================
func end_session() -> void:
	is_active = false
	
	var seq_errors = 0
	var type_order = {"ServiceCenter": 0, "Bikes": 1, "Bulky": 2, "Mecha": 3, "C&C": 4}
	var highest_seen = -1
	
	# Check LIFO Sequence mathematically
	for p in inventory_loaded:
		var current_rank = type_order.get(p.type, 99)
		if current_rank < highest_seen:
			seq_errors += 1
		else:
			highest_seen = current_rank
			
	var did_validate = "Confirm AS400" in _manual_decisions
	
	# THE FIX: TUTORIAL FORGIVENESS
	if current_scenario == "0. Tutorial" and unload_count > 0:
		unload_count -= 1
		total_time -= 66.0 
	
	var score = 100
	var feedback = []
	
	if seq_errors > 0:
		score -= (seq_errors * 10)
		feedback.append("[color=#e74c3c]• Sequence Errors (-" + str(seq_errors * 10) + "):[/color] Pallets were loaded out of the strict LIFO operational order.")
		
	if unload_count > 0:
		score -= (unload_count * 5)
		feedback.append("[color=#e74c3c]• Rework Penalties (-" + str(unload_count * 5) + "):[/color] You had to pull " + str(unload_count) + " pallet(s) off the truck.")
		
	if not did_validate:
		score -= 20
		feedback.append("[color=#e74c3c]• AS400 Validation (-20):[/color] You sealed the truck without confirming the RAQ with F10!")
		
	var left_behind_cc = 0
	var left_behind_priority = 0
	for p in inventory_available:
		if not p.missing:
			if p.type == "C&C":
				left_behind_cc += 1
			elif p.promise == "D" or p.promise == "D-":
				left_behind_priority += 1
				
	if left_behind_cc > 0:
		score -= (left_behind_cc * 15)
		feedback.append("[color=#e74c3c]• Missing C&C (-" + str(left_behind_cc * 15) + "):[/color] You left " + str(left_behind_cc) + " Click & Collect pallet(s) on the dock!")
		
	if left_behind_priority > 0 and current_scenario == "2. Priority Loading":
		score -= (left_behind_priority * 15)
		feedback.append("[color=#e74c3c]• Priority Violation (-" + str(left_behind_priority * 15) + "):[/color] You left " + str(left_behind_priority) + " critical (D or D-) pallet(s) behind while loading D+!")

	score = clampi(score, 0, 100)
	var passed = score >= 85
	
	# Build the dynamic UI Report Card
	var what_happened = ""
	if passed:
		what_happened += "[center][font_size=32][color=#2ecc71]PASSED (" + str(score) + "%)[/color][/font_size][/center]\n\n"
	else:
		what_happened += "[center][font_size=32][color=#e74c3c]FAILED (" + str(score) + "%)[/color][/font_size][/center]\n\n"
		
	what_happened += "[b]Minimum required to pass:[/b] 85%\n\n"
	
	if feedback.size() > 0:
		what_happened += "[b]Errors & Penalties:[/b]\n"
		for f in feedback:
			what_happened += f + "\n"
	else:
		what_happened += "[color=#2ecc71]Flawless execution! No errors or penalties.[/color]\n"
		
	var why_it_mattered = ""
	if not did_validate:
		why_it_mattered += "Forgetting to validate the AS400 means the destination store doesn't legally know what is on the truck. "
	if seq_errors > 0:
		why_it_mattered += "Loading out of sequence forces the destination store to empty the entire truck just to reach their C&C pallets or stands, destroying their operational efficiency. "
	if unload_count > 0:
		why_it_mattered += "Unloading pallets adds 1.1 minutes of rework time per pallet, directly threatening our departure cut-off times. "
	if left_behind_priority > 0:
		why_it_mattered += "Leaving D- or D Promise pallets behind forces the stores to fail their customer promises. Always leave D+ behind first. "
	if score == 100:
		why_it_mattered = "You followed the SOP perfectly. The physical load matches the digital AS400 twin, and the truck is perfectly sequenced for the destination store. Excellent work."
		
	var payload = {
		"what_happened": what_happened,
		"why_it_mattered": why_it_mattered,
		"passed": passed, 
		"score": score
	}
	
	emit_signal("session_ended", payload)
