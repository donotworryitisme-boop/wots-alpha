extends Node
class_name SessionManager

signal time_updated(total_time, loading_time)
signal session_ended(debrief_payload)
signal role_updated(role_id)
signal responsibility_boundary_updated(role_id, assignment_text, window_active)
signal inventory_updated(available, loaded, cap_used, cap_max)
signal phone_notification(message: String, pallets_added: int)
signal phone_pallets_delivered  # Fires when 30s timer completes and pallets appear

var scenario_loader = null
var current_scenario = ""
var total_time: float = 0.0
var is_paused: bool = false
var is_active: bool = false

var inventory_available: Array = []
var inventory_loaded: Array = []
var inventory_pending: Array = []  # Kept for compatibility — not used internally
var capacity_max: float = 36.0
var capacity_used: float = 0.0

var _manual_decisions: Array = []
var unload_count: int = 0
var loading_started: bool = false
var loading_start_time: float = 0.0  # When Start Loading was pressed
var raq_viewed_dests: Array = []     # Which dest sequences had RAQ opened before loading

# Wave delivery system
var _wave_times: Array = []    # Sim-time thresholds for each wave (max 3)
var _wave_batches: Array = []  # Each element: Array of pallet Dicts for that wave (1–2 pallets)
var _waves_delivered: int = 0
var _required_rework_ids: Array = []  # Pallet IDs that required rework (no penalty)

# Phone-hold wave system: pallets wait until phone is opened, then 30s delay
var _phone_held_waves: Array = []    # Each: {pallets:[], msg:String, caller:String}
var _phone_deliver_timer: float = -1.0  # -1 = not running; >=0 = countdown
var _phone_delivering_wave: Dictionary = {}  # Wave being delivered after 30s
var _phone_was_opened: bool = false  # Whether phone was opened for current held wave

# Co-loading support
var is_co_load: bool = false
var co_dest_1: Dictionary = {}  # Sequence 1 — loaded first (deeper)
var co_dest_2: Dictionary = {}  # Sequence 2 — loaded second (near door)

# Transit rack
var transit_items: Array = []       # Items physically on transit rack, not yet on dock
var transit_loose_entries: Array = []  # Individual loose colis dicts {colis_id, dest, is_loose}
var transit_collected: bool = false

# ADR / Dangerous Goods
var has_adr: bool = false
var adr_items: Array = []           # ADR UAT(s) in yellow locker, not on dock yet
var adr_collected: bool = false

# Pallet combining system
var combine_count: int = 0
var _combine_source_ids: Array = []  # IDs of combine-eligible pallets at session start
var _reworked_pallet_ids: Array = [] # IDs of pallets that were unloaded and reloaded

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if is_active and not is_paused:
		if loading_started:
			total_time += delta
			emit_signal("time_updated", total_time, 0.0)
			# Waves fire relative to loading_start_time
			var loading_elapsed: float = total_time - loading_start_time
			if _waves_delivered < _wave_times.size():
				if loading_elapsed >= _wave_times[_waves_delivered]:
					_deliver_pending_wave()
			# Handle 30s phone delivery countdown
			if _phone_deliver_timer >= 0.0:
				_phone_deliver_timer -= delta
				if _phone_deliver_timer <= 0.0:
					_complete_wave_delivery(_phone_delivering_wave)
					_phone_deliver_timer = -1.0
					_phone_delivering_wave = {}
					_phone_was_opened = false
					# Check if more waves are held
					if not _phone_held_waves.is_empty():
						var next_wave: Dictionary = _phone_held_waves.pop_front()
						emit_signal("phone_notification", next_wave.msg, next_wave.pallets.size())
		else:
			# Before loading starts: emit time signal so clock shows pre-load time
			emit_signal("time_updated", total_time, 0.0)

func set_pause_state(paused: bool) -> void:
	is_paused = paused

func set_role(role_id: int) -> void:
	emit_signal("role_updated", role_id)
	var assignment: String = "Unassigned"
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
	_wave_batches.clear()
	_waves_delivered = 0
	_required_rework_ids.clear()
	_reworked_pallet_ids.clear()
	unload_count = 0
	loading_started = false
	loading_start_time = 0.0
	raq_viewed_dests.clear()
	_phone_held_waves.clear()
	_phone_deliver_timer = -1.0
	_phone_delivering_wave = {}
	_phone_was_opened = false
	is_active = true
	is_paused = false
	is_co_load = false
	transit_items.clear()
	transit_loose_entries.clear()
	transit_collected = false
	has_adr = false
	adr_items.clear()
	adr_collected = false

	_generate_inventory(scenario_name)
	_emit_inventory()
	set_role(1)

func manual_decision(action: String) -> void:
	_manual_decisions.append(action)

	if action == "Start Loading":
		loading_started = true
		loading_start_time = total_time

	elif action == "Call departments (C&C check)":
		var found_missing: bool = false
		for p: Dictionary in inventory_available:
			if not p.missing: continue
			var p_dest: int = p.get("dest", 1)
			# For co-loading: only call depts for stores whose RAQ was checked
			# For solo: raq_viewed_dests is [0] (no filter needed)
			var raq_checked: bool = true
			if is_co_load and raq_viewed_dests.size() > 0:
				raq_checked = p_dest in raq_viewed_dests
			if raq_checked:
				p.missing = false
				found_missing = true
		if found_missing:
			# No time cost before loading starts
			if loading_started:
				total_time += 300.0
			_emit_inventory()

	elif action == "Check Transit":
		if not transit_collected:
			transit_collected = true
			if loading_started:
				total_time += 240.0  # 4 minutes — free if done before loading starts
			# Transit UATs go onto existing pallets directly (never a new slot)
			for p: Dictionary in transit_items:
				var placed: bool = _auto_combine_onto_dock(p)
				if not placed:
					# Fallback: add as standalone only if nothing can receive it
					inventory_available.append(p)
			transit_items.clear()
			# Loose collis: counted as collected, no dock pallet needed
			_emit_inventory()

	elif action == "Check Yellow Lockers":
		if not adr_collected:
			adr_collected = true
			if loading_started:
				total_time += 120.0  # 2 minutes — free if done before loading starts
			# ADR boxes go onto an existing dock pallet — never a standalone new slot
			for p: Dictionary in adr_items:
				var placed: bool = _auto_combine_onto_dock(p)
				if not placed:
					# Fallback: standalone only if dock is empty
					inventory_available.append(p)
			adr_items.clear()
			_emit_inventory()

	elif action == "Combine Pallets":
		# Find lightest eligible source pallet
		var best_src: Dictionary = {}
		var best_src_w: float = 999999.0
		for src: Dictionary in inventory_available:
			if not _is_combine_source(src): continue
			var sw: float = src.get("weight_kg", 999999.0)
			if sw < best_src_w:
				best_src_w = sw
				best_src = src
		if best_src.is_empty(): return
		# Find lightest eligible target
		var best_tgt: Dictionary = {}
		var best_tgt_w: float = 999999.0
		for tgt: Dictionary in inventory_available:
			if not _is_combine_target(tgt, best_src): continue
			var tw: float = tgt.get("weight_kg", 999999.0)
			if tw < best_tgt_w:
				best_tgt_w = tw
				best_tgt = tgt
		if best_tgt.is_empty(): return
		# Determine result type (ADR > C&C > original)
		var result_type: String = best_tgt.type
		if best_src.type == "ADR" or best_tgt.type == "ADR":
			result_type = "ADR"
		elif best_src.type == "C&C" or best_tgt.type == "C&C":
			result_type = "C&C"
		# Merge into target
		var tgt_idx: int = inventory_available.find(best_tgt)
		var src_idx: int = inventory_available.find(best_src)
		if tgt_idx < 0 or src_idx < 0: return
		var merged_uats: Array = inventory_available[tgt_idx].get("combined_uats", []).duplicate()
		merged_uats.append(best_src.id)
		inventory_available[tgt_idx]["type"] = result_type
		inventory_available[tgt_idx]["weight_kg"] = best_tgt.get("weight_kg", 0.0) + best_src.get("weight_kg", 0.0)
		inventory_available[tgt_idx]["dm3"] = best_tgt.get("dm3", 0) + best_src.get("dm3", 0)
		inventory_available[tgt_idx]["collis"] = best_tgt.collis + best_src.collis
		inventory_available[tgt_idx]["combined_uats"] = merged_uats
		# Remove source (adjust index if source is after target)
		if src_idx > tgt_idx:
			inventory_available.remove_at(src_idx)
		else:
			inventory_available.remove_at(src_idx)
			# tgt_idx shifted down by 1
		total_time += 480.0  # 8 minutes deckstacker combine
		combine_count += 1
		_emit_inventory()

	elif action == "Phone Opened":
		# Player opened the phone — start the 30s delivery countdown for the waiting wave
		if not _phone_held_waves.is_empty() and _phone_deliver_timer < 0.0:
			_phone_delivering_wave = _phone_held_waves.pop_front()
			_phone_deliver_timer = 30.0
			_phone_was_opened = true

	elif action == "Seal Truck":
		end_session()

# ==========================================
# PROMISE DATE HELPER — 60% D / 30% D+ / 10% D-
# ==========================================
func _random_promise(rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	if r < 0.60: return "D"
	elif r < 0.90: return "D+"
	return "D-"

# ==========================================
# WAVE BATCH BUILDER
# Splits pallets into chunks of batch_size, sets matching _wave_times.
# base_times: candidate trigger times (max 3). Stops when pallets exhausted or times exhausted.
# ==========================================
func _make_wave_batches(pallets: Array, batch_size: int, base_times: Array) -> void:
	var i: int = 0
	var bi: int = 0
	while i < pallets.size() and bi < base_times.size():
		var chunk: Array = []
		for j: int in range(batch_size):
			if i + j < pallets.size():
				chunk.append(pallets[i + j])
		if not chunk.is_empty():
			_wave_batches.append(chunk)
			_wave_times.append(base_times[bi])
		i += batch_size
		bi += 1

# ==========================================
# INVENTORY GENERATION
# ==========================================
func _generate_inventory(scenario_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Service Center — always D, always dest 1
	inventory_available.append(_make_pallet(rng, "ServiceCenter", "MAG", "D", 1, 0.5, 1))

	# C&C Pallets — always D, first=Magnum, second=Bulky, extras alternate
	var cc_count: int = rng.randi_range(2, 4)
	var missing_idx: int = -1
	if scenario_name == "0. Tutorial":
		missing_idx = 0
	elif rng.randf() > 0.5:
		missing_idx = rng.randi_range(0, cc_count - 1)

	for i: int in range(cc_count):
		var cc_sub: String = "Magnum" if (i % 2 == 0) else "Bulky"
		var cc_collis: int = rng.randi_range(3, 8) if cc_sub == "Magnum" else rng.randi_range(2, 6)
		inventory_available.append(_make_pallet(rng, "C&C", "MAP", "D", cc_collis, 1.0, 1, cc_sub, i == missing_idx))

	if scenario_name == "0. Tutorial":
		# Tutorial: fixed D promises, all on dock, no waves
		for _i: int in range(2):
			inventory_available.append(_make_pallet(rng, "Bikes", "MAG", "D", 5, 1.3, 1))
		for _i: int in range(10):
			inventory_available.append(_make_pallet(rng, "Bulky", "MAP", "D", 20, 1.0, 1))
		for _i: int in range(16):
			inventory_available.append(_make_pallet(rng, "Mecha", "MAP", "D", 28, 1.0, 1))

	elif scenario_name == "1. Standard Loading":
		for _i: int in range(2):
			inventory_available.append(_make_pallet(rng, "Bikes", "MAG", _random_promise(rng), 5, 1.3, 1))
		for _i: int in range(10):
			inventory_available.append(_make_pallet(rng, "Bulky", "MAP", _random_promise(rng), 20, 1.0, 1))
		for _i: int in range(12):
			inventory_available.append(_make_pallet(rng, "Mecha", "MAP", _random_promise(rng), 28, 1.0, 1))
		var pending_std: Array = []
		# Varied wave types: Mecha, Bulky, or Bikes, 1-3 per wave
		var std_wave_pool: Array[String] = ["Mecha", "Mecha", "Bulky", "Bikes"]
		var n_std: int = rng.randi_range(2, 4)
		for _i: int in range(n_std):
			var wt: String = std_wave_pool[rng.randi_range(0, std_wave_pool.size() - 1)]
			var wc: int = 28 if wt == "Mecha" else (5 if wt == "Bikes" else 20)
			var wcp: float = 1.0 if wt == "Mecha" or wt == "Bulky" else 1.3
			pending_std.append(_make_pallet(rng, wt, "MAP" if wt != "Bikes" else "MAG", _random_promise(rng), wc, wcp, 1))
		_make_wave_batches(pending_std, rng.randi_range(1, 2), [400.0, 700.0, 1000.0])

	elif scenario_name == "2. Priority Loading":
		# Priority: all initial pallets get delivery_date shown instead of D/D+/D-
		for _i: int in range(2):
			var p := _make_pallet(rng, "Bikes", "MAG", _random_promise(rng), 5, 1.3, 1)
			p["delivery_date"] = _promise_to_date(p["promise"], rng)
			inventory_available.append(p)
		for _i: int in range(15):
			var p := _make_pallet(rng, "Bulky", "MAP", _random_promise(rng), 20, 1.0, 1)
			p["delivery_date"] = _promise_to_date(p["promise"], rng)
			inventory_available.append(p)
		for _i: int in range(20):
			var p := _make_pallet(rng, "Mecha", "MAP", "D+", 28, 1.0, 1)
			p["delivery_date"] = _promise_to_date("D+", rng)
			inventory_available.append(p)
		# Wave pallets: mixed types, D- (overdue), shown with date
		var pending_pri: Array = []
		var wave_types: Array[String] = ["Mecha", "Mecha", "Bikes", "Bulky", "Mecha"]
		for i: int in range(5):
			var wt: String = wave_types[i]
			var wc: int = 28 if wt == "Mecha" else (5 if wt == "Bikes" else 20)
			var wcp: float = 1.0 if wt == "Mecha" or wt == "Bulky" else 1.3
			var p := _make_pallet(rng, wt, "MAP" if wt != "Bikes" else "MAG", "D-", wc, wcp, 1)
			p["delivery_date"] = _promise_to_date("D-", rng)
			pending_pri.append(p)
		_make_wave_batches(pending_pri, 2, [550.0, 850.0, 1100.0])

	elif scenario_name == "3. Co-Loading":
		is_co_load = true
		# Store 1 (dest=1, deeper in truck)
		inventory_available.append(_make_pallet(rng, "Bikes", "MAG", _random_promise(rng), 5, 1.3, 1))
		for _i: int in range(5):
			inventory_available.append(_make_pallet(rng, "Bulky", "MAP", _random_promise(rng), 20, 1.0, 1))
		for _i: int in range(8):
			inventory_available.append(_make_pallet(rng, "Mecha", "MAP", _random_promise(rng), 28, 1.0, 1))
		for ci: int in range(2):
			var s1_sub: String = "Magnum" if ci == 0 else "Bulky"
			inventory_available.append(_make_pallet(rng, "C&C", "MAP", "D", rng.randi_range(3, 8), 1.0, 1, s1_sub))
		# Store 2 (dest=2, near doors)
		inventory_available.append(_make_pallet(rng, "Bikes", "MAG", _random_promise(rng), 5, 1.3, 2))
		for _i: int in range(4):
			inventory_available.append(_make_pallet(rng, "Bulky", "MAP", _random_promise(rng), 20, 1.0, 2))
		for _i: int in range(5):
			inventory_available.append(_make_pallet(rng, "Mecha", "MAP", _random_promise(rng), 28, 1.0, 2))
		for ci: int in range(2):
			var s2_sub: String = "Magnum" if ci == 0 else "Bulky"
			inventory_available.append(_make_pallet(rng, "C&C", "MAP", "D", rng.randi_range(3, 8), 1.0, 2, s2_sub))
		# Late arrivals
		var pending_co: Array = []
		var co_wave_types: Array[String] = ["Mecha", "Bulky", "Bikes", "Mecha"]
		var n_co: int = rng.randi_range(1, 3)
		for _i: int in range(n_co):
			var wt: String = co_wave_types[rng.randi_range(0, co_wave_types.size() - 1)]
			var wc: int = 28 if wt == "Mecha" else (5 if wt == "Bikes" else 20)
			var wcp: float = 1.0 if wt == "Mecha" or wt == "Bulky" else 1.3
			pending_co.append(_make_pallet(rng, wt, "MAP" if wt != "Bikes" else "MAG", _random_promise(rng), wc, wcp, 2))
		_make_wave_batches(pending_co, 1, [450.0, 700.0, 950.0])

	inventory_available.shuffle()

	# --- TRANSIT RACK (Standard onwards, ~35% per session) ---
	if scenario_name != "0. Tutorial" and rng.randf() < 0.35:
		var use_loose: bool = rng.randf() < 0.30
		if use_loose:
			var n_loose_d1: int = rng.randi_range(1, 4)
			for _li: int in range(n_loose_d1):
				transit_loose_entries.append({
					"colis_id": _generate_real_colis("Mecha", rng),
					"dest": 1,
					"is_loose": true
				})
			if is_co_load:
				var n_loose_d2: int = rng.randi_range(1, 3)
				for _li: int in range(n_loose_d2):
					transit_loose_entries.append({
						"colis_id": _generate_real_colis("Mecha", rng),
						"dest": 2,
						"is_loose": true
					})
		else:
			var uat_count: int = rng.randi_range(1, 2)
			for _ti: int in range(uat_count):
				var dest_v: int = 1
				if is_co_load and _ti == 1: dest_v = 2
				transit_items.append(_make_pallet(rng, "Mecha", "MAP", _random_promise(rng),
						rng.randi_range(1, 2), 0.5, dest_v))
			if rng.randf() < 0.40:
				for p: Dictionary in transit_items:
					inventory_available.append(p)
				transit_items.clear()
				transit_collected = true

	# --- ADR / DANGEROUS GOODS (Standard onwards, ~40% per session) ---
	if scenario_name != "0. Tutorial" and rng.randf() < 0.40:
		has_adr = true
		var adr_dest: int = 1
		if is_co_load and rng.randf() < 0.50:
			adr_dest = 2
		adr_items.append(_make_pallet(rng, "ADR", "MAP", "D",
				rng.randi_range(5, 15), 1.0, adr_dest))

	# Mark combine candidates for sequence exemption
	_combine_source_ids.clear()
	for p: Dictionary in inventory_available:
		if _is_combine_source(p):
			_combine_source_ids.append(p.id)

# ==========================================
# WAVE DELIVERY
# ==========================================
func _deliver_pending_wave() -> void:
	if _waves_delivered >= _wave_batches.size(): return
	var wave_pallets: Array = _wave_batches[_waves_delivered]
	_waves_delivered += 1

	# Vary caller department
	var rng_c := RandomNumberGenerator.new()
	rng_c.randomize()
	var caller: String = "SORTER"
	if not wave_pallets.is_empty():
		match (wave_pallets[0] as Dictionary).type:
			"Bikes":  caller = "BIKES ZONE C"
			"Bulky":  caller = "BULKY RECEPTION"
			"Mecha":  caller = "MECHA LINE" if rng_c.randf() < 0.5 else "SORTER"

	# Build notification message — do not reveal exact promise in message
	var type_counts: Dictionary = {}
	for p: Dictionary in wave_pallets:
		type_counts[p.type] = type_counts.get(p.type, 0) + 1

	var msg: String = "[color=#e74c3c][b]INCOMING CALL — %s[/b][/color]\n\n" % caller
	msg += "[color=#f1c40f]%d pallet(s) on their way to the dock:[/color]\n" % wave_pallets.size()
	for t: String in type_counts:
		msg += "  • %d × %s\n" % [type_counts[t], t]
	msg += "\n[color=#95a5a6]Open this panel to confirm receipt. Pallets arrive within 30 seconds.[/color]"

	# Hold pallets — they only appear after phone is opened + 30s delay
	_phone_held_waves.append({"pallets": wave_pallets, "msg": msg, "caller": caller})

	# If no delivery currently in progress, emit notification now
	if _phone_deliver_timer < 0.0:
		emit_signal("phone_notification", msg, wave_pallets.size())
		# (timer starts when player opens phone via "Phone Opened" action)

func _complete_wave_delivery(wave: Dictionary) -> void:
	var wave_pallets: Array = wave.get("pallets", [])
	for p: Dictionary in wave_pallets:
		inventory_available.append(p)
		if p.promise == "D-" or p.promise == "D":
			_required_rework_ids.append(p.id)
	emit_signal("phone_pallets_delivered")
	_emit_inventory()

# ==========================================
# UAT / COLIS GENERATORS
# ==========================================
func _generate_real_uat(rng: RandomNumberGenerator) -> String:
	return "00900084" + str(rng.randi_range(1000000, 9999999))

func _generate_real_colis(dept: String, rng: RandomNumberGenerator) -> String:
	var prefix: String = ""
	if dept == "Mecha": prefix = "8486"
	elif dept == "Bulky": prefix = "8490"
	elif dept == "Bikes": prefix = "8489"
	elif dept == "ServiceCenter": prefix = "0035"
	elif dept == "C&C": prefix = "8486"
	return prefix + str(rng.randi_range(1000000000000000, 9999999999999999))

# ==========================================
# PALLET LOAD / UNLOAD
# ==========================================
func load_pallet_by_id(id: String) -> void:
	var target: Dictionary = {}
	for p: Dictionary in inventory_available:
		if p.id == id:
			target = p
			break
	if not target.is_empty() and (capacity_used + target.cap) <= capacity_max:
		target["scan_time"] = _format_scan_time(total_time)
		inventory_available.erase(target)
		inventory_loaded.append(target)
		capacity_used += target.cap
		total_time += 67.0  # ~67s per pallet = 40 min for full 36-pallet truck
		_emit_inventory()

func unload_pallet_by_id(id: String) -> void:
	var target: Dictionary = {}
	var idx: int = -1
	for i: int in range(inventory_loaded.size()):
		if inventory_loaded[i].id == id:
			target = inventory_loaded[i]
			idx = i
			break

	if not target.is_empty() and idx >= (inventory_loaded.size() - 3):
		target["scan_time"] = ""
		inventory_loaded.erase(target)
		inventory_available.append(target)
		capacity_used -= target.cap
		total_time += 66.0
		unload_count += 1
		if target.id not in _reworked_pallet_ids:
			_reworked_pallet_ids.append(target.id)
		_emit_inventory()

func mark_raq_viewed(dest_seq: int) -> void:
	if dest_seq not in raq_viewed_dests:
		raq_viewed_dests.append(dest_seq)

func _emit_inventory() -> void:
	emit_signal("inventory_updated", inventory_available, inventory_loaded, capacity_used, capacity_max)

# ==========================================
# LOAD RANK HELPER
# Promise-aware loading order:
#   0  = ServiceCenter (always deepest)
#   1–33 = D- pallets by type (Bikes=1, Bulky=2, Mecha=3)
#   11–13 = D pallets by type
#   21–23 = D+ pallets by type
#   99 = C&C (always last, doors)
# ==========================================
func _get_load_rank(p: Dictionary) -> int:
	if p.type == "ServiceCenter": return 0
	if p.type == "C&C": return 99
	var promise_rank: int = 1
	match p.promise:
		"D-": promise_rank = 0
		"D":  promise_rank = 1
		"D+": promise_rank = 2
	var type_rank: int = 3
	match p.type:
		"Bikes": type_rank = 1
		"Bulky": type_rank = 2
		"Mecha": type_rank = 3
		"ADR":   type_rank = 4  # After Mecha, before C&C
	return promise_rank * 10 + type_rank

# ==========================================
# PALLET FACTORY & COMBINE HELPERS
# ==========================================
func _pallet_weight_kg(ptype: String, subtype: String, rng: RandomNumberGenerator) -> float:
	match ptype:
		"Mecha": return float(rng.randi_range(400, 650))
		"Bulky": return float(rng.randi_range(75, 350))
		"Bikes": return float(rng.randi_range(85, 98))
		"ServiceCenter": return float(rng.randi_range(100, 200))
		"ADR": return float(rng.randi_range(80, 200))
		"C&C":
			if subtype == "Magnum": return float(rng.randi_range(50, 180))
			if subtype == "Bulky": return float(rng.randi_range(80, 250))
	return float(rng.randi_range(100, 300))

func _pallet_dm3(ptype: String, subtype: String, rng: RandomNumberGenerator) -> int:
	match ptype:
		"Mecha": return rng.randi_range(1800, 2400)
		"Bulky": return rng.randi_range(400, 2000)
		"Bikes": return rng.randi_range(1200, 1800)
		"ServiceCenter": return rng.randi_range(800, 1500)
		"ADR": return rng.randi_range(400, 1200)
		"C&C":
			if subtype == "Magnum": return rng.randi_range(200, 700)
			if subtype == "Bulky": return rng.randi_range(600, 2000)
	return rng.randi_range(400, 1500)

# Loading date is 25/03/2026. Dates shown instead of D/D+/D- in Priority Loading.
const LOADING_DATE_D: int = 25   # day of month
const LOADING_DATE_M: int = 3    # month
const LOADING_DATE_Y: int = 2026 # year

func _promise_to_date(promise: String, rng: RandomNumberGenerator) -> String:
	# Returns DD/MM/YYYY string. Only used in Priority Loading.
	if promise == "D": return "25/03/2026"
	if promise == "D+": return "26/03/2026"
	# D- : random 1–7 days before 25/03
	var days_late: int = rng.randi_range(1, 7)
	# Simple day arithmetic (March has 31 days)
	var day: int = 25 - days_late
	if day > 0:
		return "%02d/03/2026" % day
	else:
		# Spill into February (28 days in 2026)
		var feb_day: int = 28 + day
		return "%02d/02/2026" % feb_day

# Formats sim time as DD/MM/YYYY HH:MM:SS (clock starts at 09:00)
func _format_scan_time(sim_time: float) -> String:
	var total_secs: int = int(sim_time)
	@warning_ignore("integer_division")
	var hours: int = 9 + (total_secs / 3600)
	@warning_ignore("integer_division")
	var mins: int = (total_secs % 3600) / 60
	var secs: int = total_secs % 60
	return "25/03/2026 %02d:%02d:%02d" % [hours, mins, secs]

func _make_pallet(rng: RandomNumberGenerator, ptype: String, code: String,
				  promise: String, collis: int, cap: float, dest: int,
				  subtype: String = "", missing: bool = false) -> Dictionary:
	return {
		"id": _generate_real_uat(rng),
		"colis_id": _generate_real_colis(ptype, rng),
		"type": ptype,
		"code": code,
		"promise": promise,
		"p_val": 0,
		"collis": collis,
		"cap": cap,
		"is_uat": true,
		"missing": missing,
		"dest": dest,
		"subtype": subtype,
		"weight_kg": _pallet_weight_kg(ptype, subtype, rng),
		"dm3": _pallet_dm3(ptype, subtype, rng),
		"combined_uats": [],
		"combined_collis": 0,
		"delivery_date": "",
		"scan_time": ""
	}

# Auto-places incoming boxes (ADR, transit) onto an existing dock pallet.
# Finds the lightest non-Mecha pallet with matching dest that can absorb the weight/volume.
# Returns true if placed, false if nothing suitable exists.
func _auto_combine_onto_dock(incoming: Dictionary) -> bool:
	var best_idx: int = -1
	var best_w: float = 999999.0
	for i: int in range(inventory_available.size()):
		var tgt: Dictionary = inventory_available[i]
		if tgt.type == "Mecha": continue
		if tgt.get("dest", 1) != incoming.get("dest", 1): continue
		var cw: float = tgt.get("weight_kg", 0.0) + incoming.get("weight_kg", 0.0)
		var cv: int = tgt.get("dm3", 0) + incoming.get("dm3", 0)
		if cw > 700.0 or cv > 2500: continue
		var tw: float = tgt.get("weight_kg", 999999.0)
		if tw < best_w:
			best_w = tw
			best_idx = i
	if best_idx < 0: return false
	# Merge onto target
	var result_type: String = inventory_available[best_idx].type
	if incoming.type == "ADR" or inventory_available[best_idx].type == "ADR":
		result_type = "ADR"
	elif incoming.type == "C&C" or inventory_available[best_idx].type == "C&C":
		result_type = "C&C"
	var merged: Array = inventory_available[best_idx].get("combined_uats", []).duplicate()
	merged.append(incoming.id)
	inventory_available[best_idx]["type"] = result_type
	inventory_available[best_idx]["weight_kg"] = inventory_available[best_idx].get("weight_kg", 0.0) + incoming.get("weight_kg", 0.0)
	inventory_available[best_idx]["dm3"] = inventory_available[best_idx].get("dm3", 0) + incoming.get("dm3", 0)
	inventory_available[best_idx]["collis"] = inventory_available[best_idx].collis + incoming.collis
	inventory_available[best_idx]["combined_uats"] = merged
	return true

func _is_combine_source(p: Dictionary) -> bool:
	if p.type == "Mecha": return false
	if p.type == "C&C" and p.get("subtype", "") == "Bulky": return false
	if not p.get("combined_uats", []).is_empty(): return false
	return p.get("weight_kg", 999.0) < 200.0 and p.get("dm3", 9999) < 1440

func _is_combine_target(target: Dictionary, source: Dictionary) -> bool:
	if target.id == source.id: return false
	if target.type == "Mecha": return false
	var cw: float = target.get("weight_kg", 0.0) + source.get("weight_kg", 0.0)
	var cv: int = target.get("dm3", 0) + source.get("dm3", 0)
	return cw <= 700.0 and cv <= 2500

func has_combine_pair() -> bool:
	for src: Dictionary in inventory_available:
		if not _is_combine_source(src): continue
		for tgt: Dictionary in inventory_available:
			if _is_combine_target(tgt, src): return true
	return false

# ==========================================
# THE GRADING ENGINE
# ==========================================
func end_session() -> void:
	is_active = false

	# --- SEQUENCE CHECK (promise-aware, per-destination for co-loading) ---
	var seq_errors: int = 0
	var co_interleave_errors: int = 0

	if is_co_load:
		# Check that all dest=1 pallets were loaded before any dest=2 pallet
		var first_dest2_pos: int = inventory_loaded.size()
		for i: int in range(inventory_loaded.size()):
			if inventory_loaded[i].get("dest", 1) == 2:
				first_dest2_pos = i
				break
		for i: int in range(first_dest2_pos + 1, inventory_loaded.size()):
			if inventory_loaded[i].get("dest", 1) == 1:
				# Reworked pallets are exempt — rework to fit priority arrivals is correct
				if inventory_loaded[i].id not in _reworked_pallet_ids:
					co_interleave_errors += 1
					seq_errors += 1  # Store 1 pallet loaded after store 2 started
		# Within each store: promise-aware type sequence
		for dest_id: int in [1, 2]:
			var highest_rank: int = -1
			var co_seq_exempt_used: int = 0
			for p: Dictionary in inventory_loaded:
				if p.get("dest", 1) != dest_id:
					continue
				var rank: int = _get_load_rank(p)
				if rank < highest_rank:
					if p.id in _combine_source_ids and co_seq_exempt_used < 4 and p.type != "C&C":
						co_seq_exempt_used += 1
					else:
						seq_errors += 1
				else:
					highest_rank = rank
	else:
		var highest_rank: int = -1
		var seq_exempt_used: int = 0
		for p: Dictionary in inventory_loaded:
			var rank: int = _get_load_rank(p)
			if rank < highest_rank:
				if p.id in _combine_source_ids and seq_exempt_used < 4 and p.type != "C&C":
					seq_exempt_used += 1
				else:
					seq_errors += 1
			else:
				highest_rank = rank

	var did_validate: bool = false
	if is_co_load:
		var validated_d1: bool = "Confirm AS400 Dest 1" in _manual_decisions
		var validated_d2: bool = "Confirm AS400 Dest 2" in _manual_decisions
		did_validate = validated_d1 and validated_d2
	else:
		did_validate = "Confirm AS400 Dest 1" in _manual_decisions
	var called_departments: bool = "Call departments (C&C check)" in _manual_decisions

	var tutorial_rework_forgiven: bool = false
	if current_scenario == "0. Tutorial" and unload_count > 0:
		unload_count -= 1
		total_time -= 66.0
		tutorial_rework_forgiven = true

	var forgiven_rework: int = mini(_required_rework_ids.size(), unload_count)
	var penalized_unloads: int = unload_count - forgiven_rework

	var score: int = 100
	var feedback: Array = []
	var critical_fail: bool = false

	if tutorial_rework_forgiven:
		feedback.append("[color=#f1c40f]• Tutorial rework:[/color] 1 deliberate rework was forgiven for learning purposes. In a real shift, this would cost ~1.1 minutes and 5 points.")

	var type_seq_errors: int = seq_errors - co_interleave_errors
	if type_seq_errors > 0:
		score -= (type_seq_errors * 10)
		if type_seq_errors <= 2:
			feedback.append("[color=#e74c3c]• Sequence:[/color] " + str(type_seq_errors) + " pallet(s) loaded out of the standard sequence. The truck unloads from the doors inward — last in, first out. Every pallet in the wrong position means the store team has to move it aside to reach what they need. That's extra handling time at the store that delays their opening routine.")
		else:
			feedback.append("[color=#e74c3c]• Sequence:[/color] " + str(type_seq_errors) + " pallet(s) loaded out of the standard sequence. The truck unloads from the doors inward — last in, first out. The store team works in a fixed order: C&C off first for waiting customers, then Mecha for shelf restocking, then Bulky and Bikes for specialist teams, and Service Center last.\n\nEvery pallet in the wrong position has to be moved aside to reach what they need. At " + str(type_seq_errors) + " sequence errors, the store team could spend 30-60 minutes rearranging pallets on the dock floor — people who should be helping customers on the shop floor.")
	if co_interleave_errors > 0:
		score -= (co_interleave_errors * 10)
		feedback.append("[color=#e74c3c]• Co-Loading Sequence:[/color] " + str(co_interleave_errors) + " Store 1 pallet(s) loaded after Store 2 pallets had started. Store 1 goes deepest because it is unloaded second — the truck visits Store 2 first. A Store 1 pallet among Store 2's section means the driver at Store 2 encounters pallets that do not belong to them. They have to move them aside, unload their own, then push the Store 1 pallets back. This adds 10-15 minutes at Store 2 and risks Store 1 pallets being damaged or left behind at the wrong location.")

	if unload_count > 0:
		score -= (penalized_unloads * 5)
		if forgiven_rework > 0:
			feedback.append("[color=#2ecc71]• Smart rework:[/color] " + str(forgiven_rework) + " pallet(s) removed to make room for late-arriving D- pallets. No penalty — this was the right call. The D- pallets were overdue and the store needed them. Unloading D+ to make room shows you understood the priority and acted on it.")
		if penalized_unloads > 0:
			if penalized_unloads <= 2:
				feedback.append("[color=#e74c3c]• Rework:[/color] " + str(penalized_unloads) + " pallet(s) pulled back off the truck. Each rework costs 5 points and adds ~1.1 minutes to your shift clock.")
			else:
				feedback.append("[color=#e74c3c]• Rework:[/color] " + str(penalized_unloads) + " pallet(s) removed and reloaded during the shift. Occasional rework is normal — a wave arrives and you need to make space. But " + str(penalized_unloads) + " reworks in a single loading suggests pallets were loaded without checking the full picture first. Each one adds ~1.1 minutes, pushing closer to the departure window. If the driver is waiting, that's time the store receives their delivery late.")

	if not did_validate:
		if is_co_load:
			var has_d1_confirm: bool = "Confirm AS400 Dest 1" in _manual_decisions
			var has_d2_confirm: bool = "Confirm AS400 Dest 2" in _manual_decisions
			var missing_dests: Array[String] = []
			if not has_d1_confirm:
				missing_dests.append("Store 1")
			if not has_d2_confirm:
				missing_dests.append("Store 2")
			score -= (missing_dests.size() * 10)
			feedback.append("[color=#e74c3c]• AS400 Validation:[/color] RAQ not confirmed for " + ", ".join(missing_dests) + ". Each store needs its own F10 confirmation. Without it, the receiving team has no digital record of what is on the truck — they have to manually check every pallet against the paper CMR. Any discrepancy becomes harder to trace because there is no system record of what was supposed to be there.")
		else:
			score -= 20
			feedback.append("[color=#e74c3c]• AS400 Validation:[/color] The truck was sealed without pressing F10 to confirm the RAQ. The AS400 is the digital twin of the physical truck — it is how the store knows what is coming before the truck arrives. Without validation, the receiving team has to manually check every pallet against the paper CMR. If there is a discrepancy — a missing pallet, a wrong delivery — there is no digital trail to trace it. The store loses 15-20 minutes of receiving time, and any missing item becomes an investigation with no starting point.")

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
		feedback.append("[color=#e74c3c][b]• CRITICAL — C&C Left Behind:[/b][/color] " + str(left_behind_cc) + " Click & Collect pallet(s) left on the dock. These are customer orders — someone placed an order online, chose store pickup, and received a confirmation with a pickup date. They may have driven 30 minutes to the store. When they arrive at the counter, the store team searches the system, sees the pallet was assigned to your truck, and has to tell the customer it did not arrive. The customer either waits for the next truck — which may not be until tomorrow — or cancels. One forgotten C&C pallet can cost a customer relationship that took years to build.")

	if left_behind_cc_uncalled > 0 and not called_departments:
		critical_fail = true
		score -= 20
		feedback.append("[color=#e74c3c][b]• CRITICAL — C&C Not Investigated:[/b][/color] " + str(left_behind_cc_uncalled) + " C&C pallet(s) were listed in the RAQ but not on the dock — and departments were never contacted. The pallets were somewhere in the warehouse: possibly still being picked, stuck on a conveyor, or placed at the wrong dock. A single phone call to the C&C department would have located them in time. Without that call, the truck sealed without them, and the store has no way to know they were supposed to be there until a customer arrives to collect an order that is not in the building. The RAQ existed specifically to catch this — checking it before loading, noticing the gap, and calling is the procedure that prevents this.")

	if left_behind_priority > 0 and current_scenario == "2. Priority Loading":
		score -= (left_behind_priority * 15)
		feedback.append("[color=#e74c3c]• Priority Pallets Left Behind:[/color] " + str(left_behind_priority) + " pallet(s) with a D or D- promise date left on the dock while D+ pallets were loaded. D- means the delivery is already overdue — the store expected it yesterday or earlier. D means due today. D+ means tomorrow.\n\nLoading D+ instead of D- means a customer whose order is already late waits another day, while tomorrow's stock arrives early and sits in the store's backroom taking up space. The store team lead has to explain to their manager why overdue deliveries keep slipping while future stock arrives on time. The information was right there in the RAQ.")

	# Transit rack — soft penalty
	var had_transit_items: bool = (transit_loose_entries.size() > 0 or transit_items.size() > 0)
	if had_transit_items and not transit_collected:
		score -= 10
		feedback.append("[color=#f1c40f]• Transit Rack Not Checked:[/color] Items were waiting on the transit rack — collis or UATs that belong to this shipment but were not placed on the dock with the rest. They were listed in the RAQ as TRANSIT rows. The truck sealed without them, so the store receives an incomplete delivery. Those items stay in Tilburg until someone notices and adds them to the next available truck — which may not go to the same store for another day.")

	# ADR — critical
	if has_adr and not adr_collected:
		score -= 25
		critical_fail = true
		feedback.append("[color=#e74c3c][b]• CRITICAL — ADR Not Collected:[/b][/color] The ADR pallet was listed in the RAQ from the start — a red row signaling dangerous goods under the Accord Dangereux Routier (lithium batteries, aerosols, or other regulated items). It was in the yellow lockers, locked separately because ADR goods require controlled handling. Sealing the truck without it means regulated goods remain unsecured in the warehouse without an active shipment record. This is not an efficiency issue — it is a compliance requirement. If an incident occurs with unsecured ADR material, the warehouse is liable. The store also expected the ADR goods and may have customer orders depending on them.")

	score = clampi(score, 0, 100)
	var passed: bool = score >= 85 and not critical_fail

	# ---- BUILD DEBRIEF NARRATIVE ----
	var what_happened: String = ""
	@warning_ignore("integer_division")
	var mins: int = int(total_time) / 60
	var secs: int = int(total_time) % 60
	what_happened += "[color=#7f8fa6]Shift duration: %02d:%02d[/color]\n\n" % [mins, secs]

	if feedback.size() > 0:
		what_happened += "[font_size=18][b]Story of the Shift[/b][/font_size]\n\n"
		for f: String in feedback:
			what_happened += f + "\n\n"
	else:
		what_happened += "[font_size=18][color=#2ecc71][b]Clean shift.[/b][/color][/font_size]\nThe physical load matches the digital AS400 twin. The truck is sequenced correctly for the store — C&C nearest the doors, Service Center deepest. Every promise date was respected, every committed item is on board. The store's receiving team will unload this truck in the order they need, with a confirmed digital record to match. No calls back to Tilburg, no missing items, no customer waiting at an empty counter.\n\n"

	if passed:
		what_happened += "[color=#2ecc71]You've demonstrated the foundations needed for the next scenario.[/color]\n"
	else:
		what_happened += "[color=#95a5a6]Review the patterns above and try again. The next scenario unlocks when these fundamentals are solid.[/color]\n"

	# ---- CONTEXT: CONDITIONS DURING THE SHIFT ----
	var why_it_mattered: String = ""
	if score < 100 or critical_fail:
		why_it_mattered += "[font_size=16][b]Conditions during this shift[/b][/font_size]\n\n"
		why_it_mattered += "[color=#7f8fa6]Truck: %.0f / %.0f slots used[/color]\n" % [capacity_used, capacity_max]
		var loaded_count: int = inventory_loaded.size()
		var avail_count: int = inventory_available.size()
		why_it_mattered += "[color=#7f8fa6]Pallets loaded: %d — Left on dock: %d[/color]\n" % [loaded_count, avail_count]
		if _waves_delivered > 0:
			why_it_mattered += "[color=#7f8fa6]Late arrivals: %d wave(s) delivered during loading[/color]\n" % _waves_delivered
		if raq_viewed_dests.size() > 0:
			why_it_mattered += "[color=#7f8fa6]RAQ was checked before loading[/color]\n"
		else:
			why_it_mattered += "[color=#e67e22]RAQ was not checked before loading started[/color]\n"
		if combine_count > 0:
			why_it_mattered += "[color=#7f8fa6]Deckstacker combines: %d[/color]\n" % combine_count
		why_it_mattered += "\n"
		if _waves_delivered > 0 and (penalized_unloads > 0 or left_behind_priority > 0):
			why_it_mattered += "[color=#c0c8d0]Late-arriving pallets added pressure during this shift. Rework and prioritisation decisions are harder when the truck is filling up and new pallets keep arriving. These are the moments where preparation — checking the RAQ early, leaving space for possible arrivals — makes the difference.[/color]\n\n"
		if raq_viewed_dests.size() == 0 and (left_behind_cc > 0 or left_behind_cc_uncalled > 0 or had_transit_items):
			why_it_mattered += "[color=#c0c8d0]The RAQ was not checked before loading began. Missing items — C&C pallets, transit rack collis — are visible in the RAQ before the first pallet is scanned. Checking it costs nothing before Start Loading and can prevent most of the issues above.[/color]\n\n"
	else:
		why_it_mattered = "[color=#2ecc71]The SOP was followed precisely. Physical load matches the digital twin, sequence is correct, and all commitments are met.[/color]"

	if combine_count > 0:
		what_happened += "[color=#2ecc71]• Deckstacker combine:[/color] %d pallet(s) combined — one slot freed per combine.\n\n" % combine_count

	var total_weight_kg: float = 0.0
	var total_dm3: int = 0
	for p: Dictionary in inventory_loaded:
		total_weight_kg += p.get("weight_kg", 0.0)
		total_dm3 += p.get("dm3", 0)

	var payload: Dictionary = {
		"what_happened": what_happened,
		"why_it_mattered": why_it_mattered,
		"passed": passed,
		"score": score,
		"total_weight_kg": total_weight_kg,
		"total_dm3": total_dm3,
		"combine_count": combine_count
	}

	emit_signal("session_ended", payload)
