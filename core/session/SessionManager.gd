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

# Co-loading support
var is_co_load: bool = false
var co_dest_1: Dictionary = {}  # Sequence 1 — loaded first (deeper)
var co_dest_2: Dictionary = {}  # Sequence 2 — loaded second (near door)

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
	is_co_load = false
	
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
			total_time += 300.0
			_emit_inventory() 
			
	elif action == "Seal Truck":
		end_session()

func _generate_inventory(scenario_name: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Service Center (all scenarios)
	for i in range(1):
		inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("ServiceCenter", rng), "type": "ServiceCenter", "code": "MAG", "promise": "D", "p_val": 0, "collis": 1, "cap": 0.5, "is_uat": true, "missing": false, "dest": 1})
	
	# C&C Pallets
	var cc_count = rng.randi_range(2, 4)
	var missing_idx = -1
	if scenario_name == "0. Tutorial": missing_idx = 0 
	elif rng.randf() > 0.5: missing_idx = rng.randi_range(0, cc_count - 1)
	
	for i in range(cc_count):
		inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 12), "cap": 1.0, "is_uat": true, "missing": (i == missing_idx), "dest": 1})

	if scenario_name == "0. Tutorial" or scenario_name == "1. Standard Loading":
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 1})
		for i in range(10): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(16): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
	
	elif scenario_name == "2. Priority Loading":
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 1})
		for i in range(15): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(20): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D+", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(5): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D-", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})

	elif scenario_name == "3. Co-Loading":
		is_co_load = true
		# Store 1 pallets (dest=1, loaded deeper — sequence 1)
		for i in range(1): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 1})
		for i in range(5): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(8): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 8), "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		# Store 2 pallets (dest=2, loaded near door — sequence 2)
		for i in range(1): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 2})
		for i in range(4): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		for i in range(7): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 8), "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})

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
		# ~67s per pallet = 40 min for full 36-pallet truck
		total_time += 67.0
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
		total_time += 66.0
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
	
	for p in inventory_loaded:
		var current_rank = type_order.get(p.type, 99)
		if current_rank < highest_seen:
			seq_errors += 1
		else:
			highest_seen = current_rank
			
	var did_validate = "Confirm AS400" in _manual_decisions
	
	# Tutorial forgiveness
	if current_scenario == "0. Tutorial" and unload_count > 0:
		unload_count -= 1
		total_time -= 66.0 
	
	var score = 100
	var feedback = []
	
	if seq_errors > 0:
		score -= (seq_errors * 10)
		feedback.append("[color=#e74c3c]• Sequence:[/color] " + str(seq_errors) + " pallet(s) loaded out of the standard order. The store has to dig through the truck to find what they need first.")
		
	if unload_count > 0:
		score -= (unload_count * 5)
		feedback.append("[color=#e74c3c]• Rework:[/color] " + str(unload_count) + " pallet(s) pulled back off. Each costs ~1.1 minutes, pressuring the departure window.")
		
	if not did_validate:
		score -= 20
		feedback.append("[color=#e74c3c]• AS400 Validation:[/color] Truck sealed without confirming the RAQ. The store won't know what's on the truck.")
		
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
		feedback.append("[color=#e74c3c]• Missing C&C:[/color] " + str(left_behind_cc) + " Click & Collect pallet(s) left on dock. Customers are waiting.")
		
	if left_behind_priority > 0 and current_scenario == "2. Priority Loading":
		score -= (left_behind_priority * 15)
		feedback.append("[color=#e74c3c]• Priority:[/color] " + str(left_behind_priority) + " critical (D/D-) pallet(s) left behind while D+ was loaded.")

	# Co-loading: check destination mixing
	if is_co_load:
		var dest_errors = 0
		var saw_dest_2 = false
		for p in inventory_loaded:
			if p.get("dest", 1) == 2: saw_dest_2 = true
			elif saw_dest_2 and p.get("dest", 1) == 1:
				dest_errors += 1
		if dest_errors > 0:
			score -= (dest_errors * 10)
			feedback.append("[color=#e74c3c]• Destination mixing:[/color] " + str(dest_errors) + " Store 1 pallet(s) loaded after Store 2 pallets started. Store 1 must be loaded entirely first (deeper in truck).")

	score = clampi(score, 0, 100)
	var passed = score >= 85
	
	# --- NEUTRAL DEBRIEF ---
	var what_happened = ""
	var mins = int(total_time) / 60
	var secs = int(total_time) % 60
	what_happened += "[color=#7f8fa6]Shift duration: %02d:%02d[/color]\n\n" % [mins, secs]
	
	if feedback.size() > 0:
		what_happened += "[font_size=18][b]What happened during this shift[/b][/font_size]\n\n"
		for f in feedback:
			what_happened += f + "\n\n"
	else:
		what_happened += "[font_size=18][color=#2ecc71][b]Clean shift.[/b][/color][/font_size]\nThe physical load matches the digital AS400 twin. The truck is sequenced correctly for the destination store. No rework, no missing pallets.\n\n"

	if passed:
		what_happened += "[color=#2ecc71]You've demonstrated the foundations needed for the next scenario.[/color]\n"
	else:
		what_happened += "[color=#95a5a6]Review the patterns above and try again. The next scenario unlocks when these fundamentals are solid.[/color]\n"
		
	var why_it_mattered = ""
	if not did_validate:
		why_it_mattered += "Without AS400 validation, the store receives a truck with no digital record. They lose time reconciling what arrived. "
	if seq_errors > 0:
		why_it_mattered += "Out-of-sequence loading means the store unstacks everything to reach priority items at the back. "
	if unload_count > 0:
		why_it_mattered += "Every pallet pulled back costs ~1.1 minutes. Over a shift, rework adds up and threatens departure times. "
	if left_behind_priority > 0:
		why_it_mattered += "D-/D pallets are customer promises with deadlines. Leaving them behind while loading D+ breaks the store's delivery schedule. "
	if is_co_load and score < 100:
		why_it_mattered += "In co-loading, mixing destinations means the first store has to search through pallets belonging to the second store. "
	if score == 100:
		why_it_mattered = "The SOP was followed precisely. Physical load matches the digital twin, sequence is correct, and all commitments are met."
		
	var payload = {
		"what_happened": what_happened,
		"why_it_mattered": why_it_mattered,
		"passed": passed, 
		"score": score
	}
	
	emit_signal("session_ended", payload)
