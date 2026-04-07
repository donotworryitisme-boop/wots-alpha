class_name InventoryManager
extends RefCounted

## Holds all inventory state and pallet-related logic.
## SessionManager delegates inventory operations here and handles
## time costs + signal emission.

# --- Inventory arrays ---
var inventory_available: Array = []
var inventory_loaded: Array = []
var inventory_pending: Array = []
var capacity_max: float = 36.0
var capacity_used: float = 0.0
var unload_count: int = 0
var loading_started: bool = false
var loading_start_time: float = 0.0

# --- Wave delivery ---
var wave_times: Array = []
var wave_batches: Array = []
var waves_delivered: int = 0
var required_rework_ids: Array = []
var phone_held_waves: Array = []
var phone_deliver_timer: float = -1.0
var phone_delivering_wave: Dictionary = {}
var phone_was_opened: bool = false

# --- Co-loading ---
var is_co_load: bool = false

# --- Transit ---
var transit_items: Array = []
var transit_loose_entries: Array = []
var transit_collected: bool = false

# --- ADR / Dangerous Goods ---
var has_adr: bool = false
var adr_items: Array = []
var adr_collected: bool = false

# --- Combine ---
var combine_count: int = 0
var combine_source_ids: Array = []
var reworked_pallet_ids: Array = []
var wave_pallet_ids: Array = []

# --- Tutorial mode flag (T5) ---
# When true, is_combine_source() always returns false so the green outline,
# the ⊕ marker, the combine button, and combine_pallets() are all disabled.
# Set in generate_inventory() based on scenario name.
var _tutorial_mode: bool = false

# --- Emballage ---
var emballage_remaining: int = 0
var emballage_initial: int = 0


func reset() -> void:
	inventory_available.clear()
	inventory_loaded.clear()
	inventory_pending.clear()
	capacity_max = 36.0
	capacity_used = 0.0
	unload_count = 0
	loading_started = false
	loading_start_time = 0.0
	wave_times.clear()
	wave_batches.clear()
	waves_delivered = 0
	required_rework_ids.clear()
	phone_held_waves.clear()
	phone_deliver_timer = -1.0
	phone_delivering_wave = {}
	phone_was_opened = false
	is_co_load = false
	transit_items.clear()
	transit_loose_entries.clear()
	transit_collected = false
	has_adr = false
	adr_items.clear()
	adr_collected = false
	combine_count = 0
	combine_source_ids.clear()
	reworked_pallet_ids.clear()
	wave_pallet_ids.clear()
	emballage_remaining = 0
	emballage_initial = 0
	_tutorial_mode = false


# ==========================================
# PALLET FACTORY
# ==========================================

func pallet_weight_kg(ptype: String, subtype: String, rng: RandomNumberGenerator) -> float:
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


func pallet_dm3(ptype: String, subtype: String, rng: RandomNumberGenerator) -> int:
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


func promise_to_date(promise: String, rng: RandomNumberGenerator) -> String:
	if promise == "D": return UITokens.LOADING_DATE
	if promise == "D+":
		return "%02d/%02d/%d" % [UITokens.LOADING_DATE_D + 1, UITokens.LOADING_DATE_M, UITokens.LOADING_DATE_Y]
	# D- : random 1–7 days before loading date
	var days_late: int = rng.randi_range(1, 7)
	var day: int = UITokens.LOADING_DATE_D - days_late
	if day > 0:
		return "%02d/%02d/%d" % [day, UITokens.LOADING_DATE_M, UITokens.LOADING_DATE_Y]
	else:
		# Spill into February (28 days in 2026)
		var feb_day: int = 28 + day
		return "%02d/%02d/%d" % [feb_day, UITokens.LOADING_DATE_M - 1, UITokens.LOADING_DATE_Y]


func pallet_base_type(ptype: String, subtype: String = "") -> String:
	match ptype:
		"Bikes": return "euro"
		"Bulky": return "euro"
		"Mecha": return "plastic"
		"ServiceCenter": return "magnum"
		"C&C":
			if subtype == "Magnum": return "magnum"
			if subtype == "Bulky": return "euro"
			return "plastic"
		"ADR": return "euro"
	return "euro"


func format_scan_time(sim_time: float, clock_base: int) -> String:
	var abs_secs: int = clock_base + int(sim_time)
	@warning_ignore("integer_division")
	var hours: int = abs_secs / 3600
	@warning_ignore("integer_division")
	var mins: int = (abs_secs % 3600) / 60
	var secs: int = abs_secs % 60
	return UITokens.LOADING_DATE + " %02d:%02d:%02d" % [hours, mins, secs]


func make_pallet(rng: RandomNumberGenerator, ptype: String, code: String,
				promise: String, collis: int, cap: float, dest: int,
				subtype: String = "", missing: bool = false) -> Dictionary:
	return {
		"id": generate_real_uat(rng),
		"colis_id": generate_real_colis(ptype, rng),
		"type": ptype,
		"pallet_base": pallet_base_type(ptype, subtype),
		"code": code,
		"promise": promise,
		"p_val": 0,
		"collis": collis,
		"cap": cap,
		"is_uat": true,
		"missing": missing,
		"dest": dest,
		"subtype": subtype,
		"weight_kg": pallet_weight_kg(ptype, subtype, rng),
		"dm3": pallet_dm3(ptype, subtype, rng),
		"combined_uats": [],
		"combined_collis": 0,
		"delivery_date": promise_to_date(promise, rng),
		"scan_time": ""
	}


# ==========================================
# ID GENERATORS
# ==========================================

func generate_real_uat(rng: RandomNumberGenerator) -> String:
	return "00900084" + str(rng.randi_range(1000000, 9999999))


func generate_real_colis(dept: String, rng: RandomNumberGenerator) -> String:
	var prefix: String = ""
	if dept == "Mecha": prefix = "8486"
	elif dept == "Bulky": prefix = "8490"
	elif dept == "Bikes": prefix = "8489"
	elif dept == "ServiceCenter": prefix = "0035"
	elif dept == "C&C": prefix = "8486"
	return prefix + str(rng.randi_range(1000000000000000, 9999999999999999))


# ==========================================
# PROMISE HELPER — 60% D / 30% D+ / 10% D-
# ==========================================

func random_promise(rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	if r < 0.60: return "D"
	elif r < 0.90: return "D+"
	return "D-"


# ==========================================
# WAVE BATCH BUILDER
# ==========================================

func make_wave_batches(pallets: Array, batch_size: int, base_times: Array) -> void:
	var i: int = 0
	var bi: int = 0
	while i < pallets.size() and bi < base_times.size():
		var chunk: Array = []
		for j: int in range(batch_size):
			if i + j < pallets.size():
				chunk.append(pallets[i + j])
		if not chunk.is_empty():
			wave_batches.append(chunk)
			wave_times.append(base_times[bi])
		i += batch_size
		bi += 1


# ==========================================
# LOAD / UNLOAD
# ==========================================

## Loads a pallet by ID. Returns true if successful.
## Caller must handle time cost and signal emission.
func load_pallet(id: String, sim_time: float, clock_base: int) -> bool:
	var target: Dictionary = {}
	for p: Dictionary in inventory_available:
		if p.id == id:
			target = p
			break
	if not target.is_empty() and (capacity_used + target.cap) <= capacity_max:
		target["scan_time"] = format_scan_time(sim_time, clock_base)
		inventory_available.erase(target)
		inventory_loaded.append(target)
		capacity_used += target.cap
		return true
	return false


## Unloads a pallet by ID (must be within last 3 loaded). Returns true if successful.
## Caller must handle time cost and signal emission.
func unload_pallet(id: String) -> bool:
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
		unload_count += 1
		if target.id not in reworked_pallet_ids:
			reworked_pallet_ids.append(target.id)
		return true
	return false


## Undoes the most recent load — no rework penalty, no unload_count increment.
## Used by the 5-second undo window. Caller must roll back time cost.
func undo_load(id: String) -> bool:
	var target: Dictionary = {}
	var idx: int = -1
	for i: int in range(inventory_loaded.size()):
		if inventory_loaded[i].id == id:
			target = inventory_loaded[i]
			idx = i
			break
	if target.is_empty():
		return false
	target["scan_time"] = ""
	inventory_loaded.remove_at(idx)
	inventory_available.append(target)
	capacity_used -= target.cap
	return true


# ==========================================
# COMBINE LOGIC
# ==========================================

func is_combine_source(p: Dictionary) -> bool:
	# T5: combinable pairs are confusing in the tutorial — disable entirely
	if _tutorial_mode: return false
	if p.type == "Mecha": return false
	if p.type == "C&C" and p.get("subtype", "") == "Bulky": return false
	if not p.get("combined_uats", []).is_empty(): return false
	return p.get("weight_kg", 999.0) < 200.0 and p.get("dm3", 9999) < 1440


func is_combine_target(target: Dictionary, source: Dictionary) -> bool:
	if target.id == source.id: return false
	if target.type == "Mecha": return false
	var cw: float = target.get("weight_kg", 0.0) + source.get("weight_kg", 0.0)
	var cv: int = target.get("dm3", 0) + source.get("dm3", 0)
	return cw <= 700.0 and cv <= 2500


func has_combine_pair() -> bool:
	for src: Dictionary in inventory_available:
		if not is_combine_source(src): continue
		for tgt: Dictionary in inventory_available:
			if is_combine_target(tgt, src): return true
	return false


## Executes a combine operation. Returns true if a pair was found and combined.
func combine_pallets() -> bool:
	# Find lightest eligible source
	var best_src: Dictionary = {}
	var best_src_w: float = 999999.0
	for src: Dictionary in inventory_available:
		if not is_combine_source(src): continue
		var sw: float = src.get("weight_kg", 999999.0)
		if sw < best_src_w:
			best_src_w = sw
			best_src = src
	if best_src.is_empty(): return false
	# Find lightest eligible target
	var best_tgt: Dictionary = {}
	var best_tgt_w: float = 999999.0
	for tgt: Dictionary in inventory_available:
		if not is_combine_target(tgt, best_src): continue
		var tw: float = tgt.get("weight_kg", 999999.0)
		if tw < best_tgt_w:
			best_tgt_w = tw
			best_tgt = tgt
	if best_tgt.is_empty(): return false
	# Determine result type
	var result_type: String = best_tgt.type
	var result_has_adr: bool = best_src.get("has_adr", false) or best_tgt.get("has_adr", false) or best_src.type == "ADR" or best_tgt.type == "ADR"
	if best_src.type == "C&C" or best_tgt.type == "C&C":
		result_type = "C&C"
	elif best_src.type != "ADR" and best_tgt.type != "ADR":
		pass  # Keep target type
	elif best_src.type == "ADR":
		result_type = best_tgt.type
	else:
		result_type = best_src.type
	# Merge
	var tgt_idx: int = inventory_available.find(best_tgt)
	var src_idx: int = inventory_available.find(best_src)
	if tgt_idx < 0 or src_idx < 0: return false
	var merged_uats: Array = inventory_available[tgt_idx].get("combined_uats", []).duplicate()
	merged_uats.append(best_src.id)
	inventory_available[tgt_idx]["type"] = result_type
	if result_has_adr:
		inventory_available[tgt_idx]["has_adr"] = true
	inventory_available[tgt_idx]["weight_kg"] = best_tgt.get("weight_kg", 0.0) + best_src.get("weight_kg", 0.0)
	inventory_available[tgt_idx]["dm3"] = best_tgt.get("dm3", 0) + best_src.get("dm3", 0)
	inventory_available[tgt_idx]["collis"] = best_tgt.collis + best_src.collis
	inventory_available[tgt_idx]["combined_uats"] = merged_uats
	# Remove source
	if src_idx > tgt_idx:
		inventory_available.remove_at(src_idx)
	else:
		inventory_available.remove_at(src_idx)
	combine_count += 1
	return true


## Auto-places incoming boxes (ADR, transit) onto an existing dock pallet.
## Returns true if placed.
func auto_combine_onto_dock(incoming: Dictionary) -> bool:
	var best_idx: int = -1
	var best_w: float = 999999.0
	var is_adr_incoming: bool = (incoming.type == "ADR")
	if is_adr_incoming:
		# ADR Pass 1: lightest D/D- pallet (not C&C, not missing)
		for i: int in range(inventory_available.size()):
			var tgt: Dictionary = inventory_available[i]
			if tgt.type == "C&C": continue
			if tgt.get("missing", false): continue
			if tgt.get("dest", 1) != incoming.get("dest", 1): continue
			var pr: String = tgt.get("promise", "D")
			if pr != "D" and pr != "D-": continue
			var tw: float = tgt.get("weight_kg", 999999.0)
			if tw < best_w:
				best_w = tw
				best_idx = i
		# ADR Pass 2: lightest D+ pallet (still not C&C, not missing)
		if best_idx < 0:
			best_w = 999999.0
			for i: int in range(inventory_available.size()):
				var tgt: Dictionary = inventory_available[i]
				if tgt.type == "C&C": continue
				if tgt.get("missing", false): continue
				if tgt.get("dest", 1) != incoming.get("dest", 1): continue
				var tw: float = tgt.get("weight_kg", 999999.0)
				if tw < best_w:
					best_w = tw
					best_idx = i
	else:
		# Transit Pass 1: prefer Bikes
		for i: int in range(inventory_available.size()):
			var tgt: Dictionary = inventory_available[i]
			if tgt.type != "Bikes": continue
			if tgt.get("dest", 1) != incoming.get("dest", 1): continue
			var tw: float = tgt.get("weight_kg", 999999.0)
			if tw < best_w:
				best_w = tw
				best_idx = i
		# Transit Pass 2: Bulky fallback
		if best_idx < 0:
			best_w = 999999.0
			for i: int in range(inventory_available.size()):
				var tgt: Dictionary = inventory_available[i]
				if tgt.type != "Bulky": continue
				if tgt.get("dest", 1) != incoming.get("dest", 1): continue
				var tw: float = tgt.get("weight_kg", 999999.0)
				if tw < best_w:
					best_w = tw
					best_idx = i
	if best_idx < 0: return false
	# Merge onto target
	if is_adr_incoming:
		inventory_available[best_idx]["has_adr"] = true
	var merged: Array = inventory_available[best_idx].get("combined_uats", []).duplicate()
	merged.append(incoming.id)
	inventory_available[best_idx]["weight_kg"] = inventory_available[best_idx].get("weight_kg", 0.0) + incoming.get("weight_kg", 0.0)
	inventory_available[best_idx]["dm3"] = inventory_available[best_idx].get("dm3", 0) + incoming.get("dm3", 0)
	inventory_available[best_idx]["collis"] = inventory_available[best_idx].collis + incoming.collis
	inventory_available[best_idx]["combined_uats"] = merged
	return true


# ==========================================
# EMBALLAGE
# ==========================================

## Removes one emballage pallet. Returns true if there was one to remove.
func remove_emballage() -> bool:
	if emballage_remaining > 0:
		emballage_remaining -= 1
		return true
	return false


# ==========================================
# TRANSIT COLLECTION
# ==========================================

## Collects transit rack items. Returns true if collected (first time only).
func collect_transit() -> bool:
	if transit_collected: return false
	transit_collected = true
	for p: Dictionary in transit_items:
		var placed: bool = auto_combine_onto_dock(p)
		if not placed:
			inventory_available.append(p)
	transit_items.clear()
	return true


# ==========================================
# ADR COLLECTION
# ==========================================

## Collects ADR items from yellow lockers. Returns true if collected (first time only).
func collect_adr() -> bool:
	if adr_collected: return false
	adr_collected = true
	for p: Dictionary in adr_items:
		var placed: bool = auto_combine_onto_dock(p)
		if not placed:
			inventory_available.append(p)
	adr_items.clear()
	return true


# ==========================================
# CALL DEPARTMENTS (C&C CHECK)
# ==========================================

## Marks missing pallets as found for checked destinations.
## Returns true if any pallets were found.
func call_departments(raq_viewed_dests: Array) -> bool:
	var found_missing: bool = false
	for p: Dictionary in inventory_available:
		if not p.missing: continue
		var p_dest: int = p.get("dest", 1)
		var raq_checked: bool = true
		if is_co_load and raq_viewed_dests.size() > 0:
			raq_checked = p_dest in raq_viewed_dests
		if raq_checked:
			p.missing = false
			found_missing = true
	return found_missing


# ==========================================
# WAVE DELIVERY
# ==========================================

## Checks if a wave should fire. Returns notification data or empty dict.
func check_wave_trigger(loading_elapsed: float) -> Dictionary:
	if waves_delivered >= wave_times.size(): return {}
	if loading_elapsed < wave_times[waves_delivered]: return {}
	# Fire this wave
	var wave_pallets: Array = wave_batches[waves_delivered]
	waves_delivered += 1
	# Vary caller department
	var rng_c := RandomNumberGenerator.new()
	rng_c.randomize()
	var caller: String = "SORTER"
	if not wave_pallets.is_empty():
		match (wave_pallets[0] as Dictionary).type:
			"Bikes":  caller = "BIKES ZONE C"
			"Bulky":  caller = "BULKY RECEPTION"
			"Mecha":  caller = "MECHA LINE" if rng_c.randf() < 0.5 else "SORTER"
	# Build notification message
	var type_counts: Dictionary = {}
	for p: Dictionary in wave_pallets:
		type_counts[p.type] = type_counts.get(p.type, 0) + 1
	var msg: String = (UITokens.BB_ERROR + "[b]INCOMING CALL — %s[/b]" + UITokens.BB_END + "\n\n") % caller
	msg += (UITokens.BB_WARNING + "%d pallet(s) on their way to the dock:" + UITokens.BB_END + "\n") % wave_pallets.size()
	for t: String in type_counts:
		msg += "  • %d × %s\n" % [type_counts[t], t]
	msg += "\n" + UITokens.BB_GRAY + "Open this panel to confirm receipt. Pallets arrive within 10 seconds." + UITokens.BB_END
	# Hold pallets
	phone_held_waves.append({"pallets": wave_pallets, "msg": msg, "caller": caller})
	# Return notification if no delivery in progress
	if phone_deliver_timer < 0.0:
		return {"msg": msg, "count": wave_pallets.size()}
	return {}


## Player opened the phone — starts 10s countdown if a wave is waiting.
## Returns true if a wave was started.
func phone_opened() -> bool:
	if phone_held_waves.is_empty(): return false
	if phone_deliver_timer >= 0.0: return false
	phone_delivering_wave = phone_held_waves.pop_front()
	phone_deliver_timer = 10.0
	phone_was_opened = true
	return true


## Ticks the phone delivery timer. Returns a result dictionary:
## - empty: nothing happened
## - {delivered: true, chain_msg: "", chain_count: 0}: wave completed, no chain
## - {delivered: true, chain_msg: "...", chain_count: N}: wave completed, next wave started
func tick_phone_timer(delta: float) -> Dictionary:
	if phone_deliver_timer < 0.0: return {}
	phone_deliver_timer -= delta
	if phone_deliver_timer > 0.0: return {}
	# Timer expired — deliver
	_complete_wave_delivery(phone_delivering_wave)
	phone_deliver_timer = -1.0
	phone_delivering_wave = {}
	phone_was_opened = false
	# Chain next wave
	var result: Dictionary = {"delivered": true, "chain_msg": "", "chain_count": 0}
	if not phone_held_waves.is_empty():
		var next_wave: Dictionary = phone_held_waves.pop_front()
		phone_delivering_wave = next_wave
		phone_deliver_timer = 10.0
		result["chain_msg"] = next_wave.msg
		result["chain_count"] = (next_wave.pallets as Array).size()
	return result


func _complete_wave_delivery(wave: Dictionary) -> void:
	var wave_pallets: Array = wave.get("pallets", [])
	for p: Dictionary in wave_pallets:
		inventory_available.append(p)
		wave_pallet_ids.append(p.id)
		if p.promise == "D-" or p.promise == "D":
			required_rework_ids.append(p.id)


# ==========================================
# INVENTORY GENERATION
# ==========================================

func generate_inventory(scenario_name: String, seed_value: int = 0) -> void:
	# T5: tutorial scenario disables combinable pairs (confusing for new users)
	_tutorial_mode = scenario_name.begins_with("0")
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	# --- Config-driven generation (Items 30 + 34) ---
	var cfg: Dictionary = ScenarioConfig.get_config(scenario_name)
	cfg = ScenarioConfig.apply_adaptive(cfg, scenario_name)

	# Service Center — always D, always dest 1
	inventory_available.append(make_pallet(rng, "ServiceCenter", "MAG", "D", 1, 0.5, 1))

	# C&C Pallets — always D, first=Magnum, second=Bulky, extras alternate
	var cc_count: int = rng.randi_range(int(cfg.get("cc_count_min", 2)), int(cfg.get("cc_count_max", 4)))
	var missing_idx: int = int(cfg.get("cc_force_missing_idx", -1))
	if missing_idx == -1 and rng.randf() > 0.5:
		missing_idx = rng.randi_range(0, cc_count - 1)

	for i: int in range(cc_count):
		var cc_sub: String = "Magnum" if (i % 2 == 0) else "Bulky"
		var cc_collis: int = rng.randi_range(3, 8) if cc_sub == "Magnum" else rng.randi_range(2, 6)
		inventory_available.append(make_pallet(rng, "C&C", "MAP", "D", cc_collis, 1.0, 1, cc_sub, i == missing_idx))

	var use_promise: bool = bool(cfg.get("use_random_promise", false))

	if bool(cfg.get("is_co_load", false)):
		is_co_load = true
		_generate_co_loading(rng, cfg)
	else:
		_generate_single_store(rng, cfg, use_promise)

	# Seeded Fisher-Yates shuffle so replay seed produces identical dock layout
	for i: int in range(inventory_available.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = inventory_available[i]
		inventory_available[i] = inventory_available[j]
		inventory_available[j] = tmp

	# --- TRANSIT RACK ---
	var transit_prob: float = float(cfg.get("transit_probability", 0.0))
	if transit_prob > 0.0 and rng.randf() < transit_prob:
		var use_loose: bool = rng.randf() < 0.30
		if use_loose:
			var n_loose_d1: int = rng.randi_range(1, 4)
			for _li: int in range(n_loose_d1):
				transit_loose_entries.append({
					"colis_id": generate_real_colis("Mecha", rng),
					"dest": 1,
					"is_loose": true
				})
			if is_co_load:
				var n_loose_d2: int = rng.randi_range(1, 3)
				for _li: int in range(n_loose_d2):
					transit_loose_entries.append({
						"colis_id": generate_real_colis("Mecha", rng),
						"dest": 2,
						"is_loose": true
					})
		else:
			var uat_count: int = rng.randi_range(1, 2)
			for _ti: int in range(uat_count):
				var dest_v: int = 1
				if is_co_load and _ti == 1: dest_v = 2
				transit_items.append(make_pallet(rng, "Mecha", "MAP", random_promise(rng),
						rng.randi_range(1, 2), 0.5, dest_v))
			if rng.randf() < 0.40:
				for p: Dictionary in transit_items:
					var placed: bool = auto_combine_onto_dock(p)
					if not placed:
						inventory_available.append(p)
				transit_items.clear()
				transit_collected = true

	# --- ADR / DANGEROUS GOODS ---
	var adr_prob: float = float(cfg.get("adr_probability", 0.0))
	if adr_prob > 0.0 and rng.randf() < adr_prob:
		has_adr = true
		var adr_dest: int = 1
		if is_co_load and rng.randf() < 0.50:
			adr_dest = 2
		adr_items.append(make_pallet(rng, "ADR", "MAP", "D",
				rng.randi_range(5, 15), 1.0, adr_dest))

	# Mark combine candidates for sequence exemption
	combine_source_ids.clear()
	for p: Dictionary in inventory_available:
		if is_combine_source(p):
			combine_source_ids.append(p.id)

	# --- EMBALLAGE ---
	var emb_fractions: Array = cfg.get("emballage_fractions", []) as Array
	if not emb_fractions.is_empty():
		var emb_thresholds: Array = cfg.get("emballage_thresholds", [0.20, 0.55]) as Array
		var emb_roll: float = rng.randf()
		var emb_fraction: float = float(emb_fractions[emb_fractions.size() - 1])
		if emb_thresholds.size() >= 2:
			if emb_roll < float(emb_thresholds[0]):
				emb_fraction = float(emb_fractions[0])
			elif emb_roll < float(emb_thresholds[1]):
				emb_fraction = float(emb_fractions[mini(1, emb_fractions.size() - 1)])
		emballage_initial = int(capacity_max * emb_fraction)
		emballage_remaining = emballage_initial


func _generate_single_store(rng: RandomNumberGenerator, cfg: Dictionary, use_promise: bool) -> void:
	## Generates pallets for single-store scenarios (Tutorial, Standard, Priority, Free Play).
	var bikes_count: int = int(cfg.get("bikes_count", 2))
	var bulky_count: int = int(cfg.get("bulky_count", 10))
	var mecha_count: int = int(cfg.get("mecha_count", 12))

	for _i: int in range(bikes_count):
		var p_b: String = random_promise(rng) if use_promise else "D"
		inventory_available.append(make_pallet(rng, "Bikes", "MAG", p_b, 5, 1.3, 1))
	for _i: int in range(bulky_count):
		var p_k: String = random_promise(rng) if use_promise else "D"
		inventory_available.append(make_pallet(rng, "Bulky", "MAP", p_k, 20, 1.0, 1))
	for _i: int in range(mecha_count):
		var p_m: String = random_promise(rng) if use_promise else "D"
		inventory_available.append(make_pallet(rng, "Mecha", "MAP", p_m, 28, 1.0, 1))

	# Waves
	var wave_min: int = int(cfg.get("wave_count_min", 0))
	var wave_max: int = int(cfg.get("wave_count_max", 0))
	if wave_max > 0:
		var wave_pool: Array = cfg.get("wave_pool", []) as Array
		var wave_promise: String = str(cfg.get("wave_promise", "D"))
		var cfg_wave_times: Array = cfg.get("wave_times", []) as Array
		var batch_min: int = int(cfg.get("wave_batch_count_min", 1))
		var batch_max: int = int(cfg.get("wave_batch_count_max", 2))

		var pending: Array = []
		var n_waves: int = rng.randi_range(wave_min, wave_max)
		for idx: int in range(n_waves):
			var wt: String
			if idx < wave_pool.size():
				wt = str(wave_pool[idx])
			else:
				wt = str(wave_pool[rng.randi_range(0, wave_pool.size() - 1)])
			var wc: int = 28 if wt == "Mecha" else (5 if wt == "Bikes" else 20)
			var wcp: float = 1.0 if wt == "Mecha" or wt == "Bulky" else 1.3
			var wp: String = wave_promise if use_promise and wave_promise != "D" else (random_promise(rng) if use_promise else "D")
			pending.append(make_pallet(rng, wt, "MAP" if wt != "Bikes" else "MAG", wp, wc, wcp, 1))

		var float_times: Array[float] = []
		for t: Variant in cfg_wave_times:
			float_times.append(float(t))
		make_wave_batches(pending, rng.randi_range(batch_min, batch_max), float_times)


func _generate_co_loading(rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	## Generates pallets for co-loading scenario (two stores).
	# Store 1 (dest=1, deeper in truck)
	var s1_bikes: int = int(cfg.get("s1_bikes_count", 1))
	var s1_bulky: int = int(cfg.get("s1_bulky_count", 5))
	var s1_mecha: int = int(cfg.get("s1_mecha_count", 8))
	var s1_cc: int = int(cfg.get("s1_cc_count", 2))

	for _i: int in range(s1_bikes):
		inventory_available.append(make_pallet(rng, "Bikes", "MAG", random_promise(rng), 5, 1.3, 1))
	for _i: int in range(s1_bulky):
		inventory_available.append(make_pallet(rng, "Bulky", "MAP", random_promise(rng), 20, 1.0, 1))
	for _i: int in range(s1_mecha):
		inventory_available.append(make_pallet(rng, "Mecha", "MAP", random_promise(rng), 28, 1.0, 1))
	for ci: int in range(s1_cc):
		var s1_sub: String = "Magnum" if ci == 0 else "Bulky"
		inventory_available.append(make_pallet(rng, "C&C", "MAP", "D", rng.randi_range(3, 8), 1.0, 1, s1_sub))

	# Store 2 (dest=2, near doors)
	var s2_bikes: int = int(cfg.get("s2_bikes_count", 1))
	var s2_bulky: int = int(cfg.get("s2_bulky_count", 4))
	var s2_mecha: int = int(cfg.get("s2_mecha_count", 5))
	var s2_cc: int = int(cfg.get("s2_cc_count", 2))

	for _i: int in range(s2_bikes):
		inventory_available.append(make_pallet(rng, "Bikes", "MAG", random_promise(rng), 5, 1.3, 2))
	for _i: int in range(s2_bulky):
		inventory_available.append(make_pallet(rng, "Bulky", "MAP", random_promise(rng), 20, 1.0, 2))
	for _i: int in range(s2_mecha):
		inventory_available.append(make_pallet(rng, "Mecha", "MAP", random_promise(rng), 28, 1.0, 2))
	for ci: int in range(s2_cc):
		var s2_sub: String = "Magnum" if ci == 0 else "Bulky"
		inventory_available.append(make_pallet(rng, "C&C", "MAP", "D", rng.randi_range(3, 8), 1.0, 2, s2_sub))

	# Late arrivals (waves for store 2)
	var wave_min: int = int(cfg.get("wave_count_min", 1))
	var wave_max: int = int(cfg.get("wave_count_max", 3))
	var wave_pool: Array = cfg.get("wave_pool", []) as Array
	var cfg_wave_times: Array = cfg.get("wave_times", []) as Array
	var batch_min: int = int(cfg.get("wave_batch_count_min", 1))
	var batch_max: int = int(cfg.get("wave_batch_count_max", 1))

	var pending_co: Array = []
	var n_co: int = rng.randi_range(wave_min, wave_max)
	for _i: int in range(n_co):
		var wt: String = str(wave_pool[rng.randi_range(0, wave_pool.size() - 1)])
		var wc: int = 28 if wt == "Mecha" else (5 if wt == "Bikes" else 20)
		var wcp: float = 1.0 if wt == "Mecha" or wt == "Bulky" else 1.3
		pending_co.append(make_pallet(rng, wt, "MAP" if wt != "Bikes" else "MAG", random_promise(rng), wc, wcp, 2))

	var float_times: Array[float] = []
	for t: Variant in cfg_wave_times:
		float_times.append(float(t))
	make_wave_batches(pending_co, rng.randi_range(batch_min, batch_max), float_times)
