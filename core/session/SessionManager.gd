extends Node

signal time_updated(total_time, loading_time)
signal session_ended(debrief_payload)
signal role_updated(role_id)
signal responsibility_boundary_updated(role_id, assignment_text, window_active)
signal inventory_updated(available, loaded, cap_used, cap_max)
signal phone_notification(message: String, pallets_added: int)

var scenario_loader = null
var current_scenario = ""
var total_time: float = 0.0
var is_paused: bool = false
var is_active: bool = false

var inventory_available: Array = []
var inventory_loaded: Array = []
var inventory_pending: Array = []  # Pallets not yet on dock (arrive in waves)
var capacity_max: float = 36.0
var capacity_used: float = 0.0

var _manual_decisions: Array = []
var unload_count: int = 0
var loading_started: bool = false

# Wave delivery system
var _wave_times: Array = []  # Sim-time thresholds for each wave
var _waves_delivered: int = 0
var _required_rework_ids: Array = []  # Pallet IDs that required rework (no penalty)

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
		# Check if a pending wave should arrive
		if loading_started and _waves_delivered < _wave_times.size():
			if total_time >= _wave_times[_waves_delivered]:
				_deliver_pending_wave()

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
	inventory_pending.clear()
	_manual_decisions.clear()
	_wave_times.clear()
	_waves_delivered = 0
	_required_rework_ids.clear()
	unload_count = 0
	loading_started = false
	is_active = true
	is_paused = false
	is_co_load = false
	
	_generate_inventory(scenario_name)
	_emit_inventory()
	set_role(1)

func manual_decision(action: String) -> void:
	_manual_decisions.append(action)
	
	if action == "Start Loading":
		loading_started = true
		
	elif action == "Call departments (C&C check)":
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
		
		if scenario_name == "0. Tutorial":
			# Tutorial: all 16 Mecha at start, no waves
			for i in range(16): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		else:
			# Standard: 12 Mecha at start, 4 arrive late
			for i in range(12): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
			for i in range(4): inventory_pending.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
			_wave_times = [400.0]  # ~6 min into shift (after loading ~6 pallets)
	
	elif scenario_name == "2. Priority Loading":
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 1})
		for i in range(15): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(20): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D+", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		# D- pallets arrive LATE — forces priority decision
		for i in range(5):
			inventory_pending.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D-", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		_wave_times = [550.0]  # Arrive after truck is partially loaded (~8 pallets)

	elif scenario_name == "3. Co-Loading":
		is_co_load = true
		# Store 1 pallets (dest=1, loaded deeper — sequence 1)
		for i in range(1): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 1})
		for i in range(5): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(8): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 8), "cap": 1.0, "is_uat": true, "missing": false, "dest": 1})
		# Store 2: most at start, 2 Mecha arrive late
		for i in range(1): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bikes", rng), "type": "Bikes", "code": "MAG", "promise": "D", "p_val": 0, "collis": 5, "cap": 1.3, "is_uat": true, "missing": false, "dest": 2})
		for i in range(4): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Bulky", rng), "type": "Bulky", "code": "MAP", "promise": "D", "p_val": 0, "collis": 20, "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		for i in range(5): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		for i in range(2): inventory_available.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("C&C", rng), "type": "C&C", "code": "MAP", "promise": "D", "p_val": 0, "collis": rng.randi_range(3, 8), "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		# Late arrivals for store 2
		for i in range(2):
			inventory_pending.append({"id": _generate_real_uat(rng), "colis_id": _generate_real_colis("Mecha", rng), "type": "Mecha", "code": "MAP", "promise": "D", "p_val": 0, "collis": 28, "cap": 1.0, "is_uat": true, "missing": false, "dest": 2})
		_wave_times = [450.0]  # Store 2 late Mecha arrive after ~7 pallets loaded

	inventory_available.shuffle()

func _deliver_pending_wave() -> void:
	if _waves_delivered >= _wave_times.size(): return
	if inventory_pending.is_empty(): return
	
	var wave_pallets: Array = []
	# Deliver all remaining pending pallets in this wave
	for p in inventory_pending:
		wave_pallets.append(p)
	
	for p in wave_pallets:
		inventory_pending.erase(p)
		inventory_available.append(p)
		# Track D- arrivals so rework to fit them isn't penalized
		if p.promise == "D-" or p.promise == "D":
			_required_rework_ids.append(p.id)
	
	_waves_delivered += 1
	
	# Build notification message
	var type_counts = {}
	for p in wave_pallets:
		var key = p.type
		if p.promise == "D-": key += " (D-)"
		type_counts[key] = type_counts.get(key, 0) + 1
	
	var msg = "[color=#e74c3c][b]INCOMING CALL — SORTER[/b][/color]\n\n"
	msg += "[color=#f1c40f]%d new pallet(s) arrived on dock:[/color]\n" % wave_pallets.size()
	for t in type_counts:
		msg += "  • %d × %s\n" % [type_counts[t], t]
	if current_scenario == "2. Priority Loading":
		msg += "\n[color=#e74c3c][b]These are D- priority — customer promise![/b]\nYou may need to unload D+ pallets to make room.[/color]"
	
	emit_signal("phone_notification", msg, wave_pallets.size())
	_emit_inventory()

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
	
	# --- SEQUENCE CHECK (per-destination for co-loading) ---
	var type_order: Dictionary = {"ServiceCenter": 0, "Bikes": 1, "Bulky": 2, "Mecha": 3, "C&C": 4}
	var seq_errors: int = 0
	
	if is_co_load:
		for dest_id: int in [1, 2]:
			var highest_seen: int = -1
			for p: Dictionary in inventory_loaded:
				if p.get("dest", 1) != dest_id:
					continue
				var current_rank: int = type_order.get(p.type, 99)
				if current_rank < highest_seen:
					seq_errors += 1
				else:
					highest_seen = current_rank
	else:
		var highest_seen: int = -1
		for p: Dictionary in inventory_loaded:
			var current_rank: int = type_order.get(p.type, 99)
			if current_rank < highest_seen:
				seq_errors += 1
			else:
				highest_seen = current_rank
			
	var did_validate: bool = "Confirm AS400" in _manual_decisions
	var called_departments: bool = "Call departments (C&C check)" in _manual_decisions
	
	if current_scenario == "0. Tutorial" and unload_count > 0:
		unload_count -= 1
		total_time -= 66.0 
	
	var forgiven_rework: int = mini(_required_rework_ids.size(), unload_count)
	var penalized_unloads: int = unload_count - forgiven_rework
	
	var score: int = 100
	var feedback: Array = []
	var critical_fail: bool = false
	
	if seq_errors > 0:
		score -= (seq_errors * 10)
		feedback.append("[color=#e74c3c]• Sequence:[/color] " + str(seq_errors) + " pallet(s) loaded out of the standard order. The store has to dig through the truck to find what they need first.")
		
	if unload_count > 0:
		score -= (penalized_unloads * 5)
		if forgiven_rework > 0:
			feedback.append("[color=#f1c40f]• Required rework:[/color] " + str(forgiven_rework) + " pallet(s) removed to fit late-arriving priority pallets. No penalty — this was the right call.")
		if penalized_unloads > 0:
			feedback.append("[color=#e74c3c]• Rework:[/color] " + str(penalized_unloads) + " pallet(s) pulled back off. Each costs ~1.1 minutes, pressuring the departure window.")
		
	if not did_validate:
		score -= 20
		feedback.append("[color=#e74c3c]• AS400 Validation:[/color] Truck sealed without confirming the RAQ. The store won't know what's on the truck.")
		
	var left_behind_cc: int = 0
	var left_behind_cc_uncalled: int = 0
	var left_behind_priority: int = 0
	for p: Dictionary in inventory_available:
		if p.type == "C&C":
			if p.missing:
				left_behind_cc_uncalled += 1
			else:
				left_behind_cc += 1
		elif not p.missing and (p.promise == "D" or p.promise == "D-"):
			left_behind_priority += 1
				
	if left_behind_cc > 0:
		critical_fail = true
		score -= (left_behind_cc * 25)
		feedback.append("[color=#e74c3c][b]• CRITICAL — Missing C&C:[/b][/color] " + str(left_behind_cc) + " Click & Collect pallet(s) left on dock. Customers are waiting at the store for their orders.")
	
	if left_behind_cc_uncalled > 0 and not called_departments:
		critical_fail = true
		score -= 20
		feedback.append("[color=#e74c3c][b]• CRITICAL — C&C Not Called:[/b][/color] " + str(left_behind_cc_uncalled) + " C&C pallet(s) were missing from the dock and departments were never contacted.")
		
	if left_behind_priority > 0 and current_scenario == "2. Priority Loading":
		score -= (left_behind_priority * 15)
		feedback.append("[color=#e74c3c]• Priority:[/color] " + str(left_behind_priority) + " critical (D/D-) pallet(s) left behind while D+ was loaded.")

	if is_co_load:
		var dest_errors: int = 0
		var saw_dest_2: bool = false
		for p: Dictionary in inventory_loaded:
			if p.get("dest", 1) == 2:
				saw_dest_2 = true
			elif saw_dest_2 and p.get("dest", 1) == 1:
				dest_errors += 1
		if dest_errors > 0:
			score -= (dest_errors * 10)
			feedback.append("[color=#e74c3c]• Destination mixing:[/color] " + str(dest_errors) + " Store 1 pallet(s) loaded after Store 2 pallets started. Store 1 must be loaded entirely first (deeper in truck).")

	score = clampi(score, 0, 100)
	var passed: bool = score >= 85 and not critical_fail
	
	var what_happened: String = ""
	var mins: int = int(total_time) / 60
	var secs: int = int(total_time) % 60
	what_happened += "[color=#7f8fa6]Shift duration: %02d:%02d[/color]\n\n" % [mins, secs]
	
	if feedback.size() > 0:
		what_happened += "[font_size=18][b]What happened during this shift[/b][/font_size]\n\n"
		for f: String in feedback:
			what_happened += f + "\n\n"
	else:
		what_happened += "[font_size=18][color=#2ecc71][b]Clean shift.[/b][/color][/font_size]\nThe physical load matches the digital AS400 twin. The truck is sequenced correctly for the destination store. No rework, no missing pallets.\n\n"

	if passed:
		what_happened += "[color=#2ecc71]You've demonstrated the foundations needed for the next scenario.[/color]\n"
	else:
		what_happened += "[color=#95a5a6]Review the patterns above and try again. The next scenario unlocks when these fundamentals are solid.[/color]\n"
		
	var why_it_mattered: String = ""
	if not did_validate:
		why_it_mattered += "Without AS400 validation, the store receives a truck with no digital record. They lose time reconciling what arrived. "
	if seq_errors > 0:
		why_it_mattered += "Out-of-sequence loading means the store unstacks everything to reach priority items at the back. "
	if unload_count > 0:
		if penalized_unloads > 0:
			why_it_mattered += "Every pallet pulled back costs ~1.1 minutes. Over a shift, rework adds up and threatens departure times. "
		if forgiven_rework > 0:
			why_it_mattered += "Some rework was necessary to fit late-arriving priority pallets — good situational awareness. "
	if left_behind_cc > 0 or left_behind_cc_uncalled > 0:
		why_it_mattered += "C&C contains customer orders with promised pickup times. Every missing C&C means a customer arrives to an empty counter. "
	if left_behind_priority > 0:
		why_it_mattered += "D-/D pallets are customer promises with deadlines. Leaving them behind while loading D+ breaks the store's delivery schedule. "
	if is_co_load and score < 100:
		why_it_mattered += "In co-loading, mixing destinations means the first store has to search through pallets belonging to the second store. "
	if score == 100 and not critical_fail:
		why_it_mattered = "The SOP was followed precisely. Physical load matches the digital twin, sequence is correct, and all commitments are met."
		
	var payload: Dictionary = {
		"what_happened": what_happened,
		"why_it_mattered": why_it_mattered,
		"passed": passed, 
		"score": score
	}
	
	emit_signal("session_ended", payload)
