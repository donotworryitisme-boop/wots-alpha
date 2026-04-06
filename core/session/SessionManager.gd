extends Node
class_name SessionManager

signal time_updated(total_time: float, loading_time: float)
signal session_ended(debrief_payload: Dictionary)
signal role_updated(role_id: int)
signal responsibility_boundary_updated(role_id: int, assignment_text: String, window_active: bool)
signal inventory_updated(available: Array, loaded: Array, cap_used: float, cap_max: float)
signal phone_notification(message: String, pallets_added: int)
signal phone_pallets_delivered

# --- Inventory delegate ---
var _inv: InventoryManager = InventoryManager.new()

# --- Session lifecycle ---
var current_scenario: String = ""
var total_time: float = 0.0
var is_paused: bool = false
var is_active: bool = false
var _manual_decisions: Array = []
var raq_viewed_dests: Array = []
var _action_log: Array = []
var session_seed: int = 0
var _time_breakdown: Dictionary = {}

# --- Pre-loading timeline ---
var clock_base_seconds: int = 31500
var _shift_board_time_paid: bool = false
var _as400_login_time_paid: bool = false

# --- Session metadata ---
var expedition_number_1: String = ""
var expedition_number_2: String = ""
var dock_number: int = 0
var carrier_name: String = ""
var store_code: String = ""
var store_code_2: String = ""
var seal_number: String = ""
var seal_number_2: String = ""

# --- Paperwork tracking ---
var paperwork_ls_opened: bool = false
var paperwork_cmr_opened: bool = false
var paperwork_cmr2_opened: bool = false

# --- Interactive paperwork: user-typed fields (CMR 1 / single-dest) ---
var typed_store_code: String = ""
var typed_seal: String = ""
var typed_dock: String = ""
var typed_expedition_ls: String = ""
var typed_expedition_cmr: String = ""
var typed_weight: String = ""
var typed_dm3: String = ""
var typed_uat_count: String = ""
var typed_collis_count: String = ""
var typed_eur_count: String = ""
var typed_plastic_count: String = ""
var typed_magnum_count: String = ""
var typed_cmr_uats: String = ""
var typed_cmr_collis: String = ""
var typed_cmr_eur: String = ""
var typed_cmr_plastic: String = ""
var typed_cmr_magnum: String = ""
var typed_cmr_cc: String = ""
var typed_cmr_seal: String = ""
var typed_cmr_dock: String = ""
var cmr_franco_correct: bool = true
var cmr_franco_selected: bool = false

# --- Interactive paperwork: user-typed fields (CMR 2 — co-loading only) ---
var typed_cmr2_expedition: String = ""

# --- Interactive paperwork: user-typed fields (LS 2 — co-loading only) ---
var typed_store_code_2: String = ""
var typed_seal_2: String = ""
var typed_dock_2: String = ""
var typed_expedition_ls_2: String = ""
var typed_uat_count_2: String = ""
var typed_collis_count_2: String = ""
var typed_eur_count_2: String = ""
var typed_plastic_count_2: String = ""
var typed_magnum_count_2: String = ""
var typed_cmr2_weight: String = ""
var typed_cmr2_dm3: String = ""
var typed_cmr2_uats: String = ""
var typed_cmr2_collis: String = ""
var typed_cmr2_eur: String = ""
var typed_cmr2_plastic: String = ""
var typed_cmr2_magnum: String = ""
var typed_cmr2_cc: String = ""
var typed_cmr2_seal: String = ""
var typed_cmr2_dock: String = ""
var cmr2_franco_correct: bool = true
var cmr2_franco_selected: bool = false


# ==========================================
# FORWARDING PROPERTIES — InventoryManager state
# External code accesses these via SessionManager; they
# delegate to _inv so nothing outside this file changes.
# ==========================================

var inventory_available: Array:
	get: return _inv.inventory_available
	set(v): _inv.inventory_available = v

var inventory_loaded: Array:
	get: return _inv.inventory_loaded
	set(v): _inv.inventory_loaded = v

var inventory_pending: Array:
	get: return _inv.inventory_pending
	set(v): _inv.inventory_pending = v

var capacity_max: float:
	get: return _inv.capacity_max
	set(v): _inv.capacity_max = v

var capacity_used: float:
	get: return _inv.capacity_used
	set(v): _inv.capacity_used = v

var unload_count: int:
	get: return _inv.unload_count
	set(v): _inv.unload_count = v

var loading_started: bool:
	get: return _inv.loading_started
	set(v): _inv.loading_started = v

var loading_start_time: float:
	get: return _inv.loading_start_time
	set(v): _inv.loading_start_time = v

var is_co_load: bool:
	get: return _inv.is_co_load
	set(v): _inv.is_co_load = v

var transit_items: Array:
	get: return _inv.transit_items
	set(v): _inv.transit_items = v

var transit_loose_entries: Array:
	get: return _inv.transit_loose_entries
	set(v): _inv.transit_loose_entries = v

var transit_collected: bool:
	get: return _inv.transit_collected
	set(v): _inv.transit_collected = v

var has_adr: bool:
	get: return _inv.has_adr
	set(v): _inv.has_adr = v

var adr_items: Array:
	get: return _inv.adr_items
	set(v): _inv.adr_items = v

var adr_collected: bool:
	get: return _inv.adr_collected
	set(v): _inv.adr_collected = v

var combine_count: int:
	get: return _inv.combine_count
	set(v): _inv.combine_count = v

@warning_ignore("unused_private_class_variable")
var _combine_source_ids: Array:
	get: return _inv.combine_source_ids
	set(v): _inv.combine_source_ids = v

@warning_ignore("unused_private_class_variable")
var _reworked_pallet_ids: Array:
	get: return _inv.reworked_pallet_ids
	set(v): _inv.reworked_pallet_ids = v

@warning_ignore("unused_private_class_variable")
var _wave_pallet_ids: Array:
	get: return _inv.wave_pallet_ids
	set(v): _inv.wave_pallet_ids = v

@warning_ignore("unused_private_class_variable")
var _waves_delivered: int:
	get: return _inv.waves_delivered
	set(v): _inv.waves_delivered = v

@warning_ignore("unused_private_class_variable")
var _required_rework_ids: Array:
	get: return _inv.required_rework_ids
	set(v): _inv.required_rework_ids = v

var emballage_remaining: int:
	get: return _inv.emballage_remaining
	set(v): _inv.emballage_remaining = v

var emballage_initial: int:
	get: return _inv.emballage_initial
	set(v): _inv.emballage_initial = v

@warning_ignore("unused_private_class_variable")
var _phone_deliver_timer: float:
	get: return _inv.phone_deliver_timer
	set(v): _inv.phone_deliver_timer = v

@warning_ignore("unused_private_class_variable")
var _phone_held_waves: Array:
	get: return _inv.phone_held_waves
	set(v): _inv.phone_held_waves = v


# ==========================================
# LIFECYCLE
# ==========================================

func _ready() -> void:
	pass


## Time speed multiplier — 1.0 = real-time, 1.5 = 50% faster.
## Slightly faster than real-life to keep the training engaging.
const TIME_SPEED: float = 1.3

func _process(delta: float) -> void:
	if is_active and not is_paused:
		# Clock always ticks when session is active
		total_time += delta * TIME_SPEED
		if not _time_breakdown.has("dock_wait"):
			_time_breakdown["dock_wait"] = 0.0
		_time_breakdown["dock_wait"] = float(_time_breakdown["dock_wait"]) + delta * TIME_SPEED
		emit_signal("time_updated", total_time, 0.0)

		if _inv.loading_started:
			var loading_elapsed: float = total_time - _inv.loading_start_time
			# Wave trigger check
			var wave_result: Dictionary = _inv.check_wave_trigger(loading_elapsed)
			if not wave_result.is_empty():
				emit_signal("phone_notification", wave_result.msg, wave_result.count)
			# Phone delivery timer
			var timer_result: Dictionary = _inv.tick_phone_timer(delta * TIME_SPEED)
			if not timer_result.is_empty():
				emit_signal("phone_pallets_delivered")
				_emit_inventory()
				if timer_result.chain_msg != "":
					emit_signal("phone_notification", timer_result.chain_msg, timer_result.chain_count)


func set_pause_state(paused: bool) -> void:
	is_paused = paused


func set_role(role_id: int) -> void:
	emit_signal("role_updated", role_id)
	var assignment: String = "Unassigned"
	if current_scenario != "":
		assignment = "Bay B2B — " + current_scenario
	emit_signal("responsibility_boundary_updated", role_id, assignment, true)


# ==========================================
# SESSION START
# ==========================================

func start_session_with_scenario(scenario_name: String, seed_value: int = 0) -> void:
	current_scenario = scenario_name
	session_seed = seed_value
	total_time = 0.0
	_manual_decisions.clear()
	raq_viewed_dests.clear()
	_action_log.clear()
	_time_breakdown.clear()
	is_active = true
	is_paused = false
	# Session metadata
	expedition_number_1 = ""
	expedition_number_2 = ""
	dock_number = 0
	carrier_name = ""
	store_code = ""
	store_code_2 = ""
	seal_number = ""
	seal_number_2 = ""
	_shift_board_time_paid = false
	_as400_login_time_paid = false
	paperwork_ls_opened = false
	paperwork_cmr_opened = false
	paperwork_cmr2_opened = false
	# CMR 1 typed fields
	typed_store_code = ""
	typed_seal = ""
	typed_dock = ""
	typed_expedition_ls = ""
	typed_expedition_cmr = ""
	typed_weight = ""
	typed_dm3 = ""
	typed_uat_count = ""
	typed_collis_count = ""
	typed_eur_count = ""
	typed_plastic_count = ""
	typed_magnum_count = ""
	typed_cmr_uats = ""
	typed_cmr_collis = ""
	typed_cmr_eur = ""
	typed_cmr_plastic = ""
	typed_cmr_magnum = ""
	typed_cmr_cc = ""
	typed_cmr_seal = ""
	typed_cmr_dock = ""
	cmr_franco_correct = true
	cmr_franco_selected = false
	# CMR 2 typed fields (co-loading)
	typed_cmr2_expedition = ""
	typed_cmr2_weight = ""
	typed_cmr2_dm3 = ""
	typed_cmr2_uats = ""
	typed_cmr2_collis = ""
	typed_cmr2_eur = ""
	typed_cmr2_plastic = ""
	typed_cmr2_magnum = ""
	typed_cmr2_cc = ""
	typed_cmr2_seal = ""
	typed_cmr2_dock = ""
	cmr2_franco_correct = true
	cmr2_franco_selected = false
	# LS 2 typed fields (co-loading)
	typed_store_code_2 = ""
	typed_seal_2 = ""
	typed_dock_2 = ""
	typed_expedition_ls_2 = ""
	typed_uat_count_2 = ""
	typed_collis_count_2 = ""
	typed_eur_count_2 = ""
	typed_plastic_count_2 = ""
	typed_magnum_count_2 = ""
	clock_base_seconds = 31500

	_inv.reset()
	_inv.generate_inventory(scenario_name, session_seed)
	_emit_inventory()
	set_role(1)


# ==========================================
# MANUAL DECISION ROUTING
# ==========================================

func manual_decision(action: String) -> void:
	_manual_decisions.append(action)
	log_action("decision", action)

	if action == "Start Loading":
		if _inv.emballage_remaining > 0:
			return
		_inv.loading_started = true
		_inv.loading_start_time = total_time

	elif action == "Remove Emballage":
		if _inv.remove_emballage():
			_add_categorized_time(45.0, "emballage")
			emit_signal("time_updated", total_time, 0.0)
			_emit_inventory()

	elif action == "Call departments (C&C check)":
		if _inv.call_departments(raq_viewed_dests):
			if _inv.loading_started:
				_add_categorized_time(300.0, "call_depts")
			_emit_inventory()

	elif action == "Check Transit":
		if _inv.collect_transit():
			if _inv.loading_started:
				_add_categorized_time(240.0, "transit")
			_emit_inventory()

	elif action == "Check Yellow Lockers":
		if _inv.collect_adr():
			if _inv.loading_started:
				_add_categorized_time(120.0, "adr")
			_emit_inventory()

	elif action == "Combine Pallets":
		if _inv.combine_pallets():
			if _inv.loading_started:
				_add_categorized_time(480.0, "combine")
			_emit_inventory()

	elif action == "Phone Opened":
		_inv.phone_opened()

	elif action == "Open Office":
		if not _shift_board_time_paid:
			_shift_board_time_paid = true
			_add_categorized_time(300.0, "office")
			emit_signal("time_updated", total_time, 0.0)

	elif action == "Open AS400":
		if not _as400_login_time_paid:
			_as400_login_time_paid = true
			_add_categorized_time(300.0, "as400")
			emit_signal("time_updated", total_time, 0.0)

	elif action == "Open Loading Sheet":
		paperwork_ls_opened = true

	elif action == "Open CMR":
		paperwork_cmr_opened = true

	elif action == "Open CMR 2":
		paperwork_cmr2_opened = true

	elif action == "Seal Truck":
		end_session()


# ==========================================
# PALLET LOAD / UNLOAD
# ==========================================

func load_pallet_by_id(id: String) -> void:
	if _inv.load_pallet(id, total_time, clock_base_seconds):
		log_action("load_pallet", id)
		_add_categorized_time(67.0, "loading")
		_emit_inventory()


func unload_pallet_by_id(id: String) -> void:
	if _inv.unload_pallet(id):
		log_action("unload_pallet", id)
		_add_categorized_time(66.0, "rework")
		_emit_inventory()


func undo_last_load(pallet_id: String) -> bool:
	## Undoes a recently loaded pallet — no rework penalty.
	## Returns true if the undo was successful.
	if not _inv.undo_load(pallet_id):
		return false
	log_action("undo_load", pallet_id)
	# Roll back the 67-second loading time cost
	total_time -= 67.0
	if total_time < 0.0:
		total_time = 0.0
	if _time_breakdown.has("loading"):
		_time_breakdown["loading"] = maxf(float(_time_breakdown["loading"]) - 67.0, 0.0)
	_emit_inventory()
	return true


# ==========================================
# DELEGATING HELPERS
# ==========================================

func has_combine_pair() -> bool:
	return _inv.has_combine_pair()


func _is_combine_source(p: Dictionary) -> bool:
	return _inv.is_combine_source(p)


func mark_raq_viewed(dest_seq: int) -> void:
	if dest_seq not in raq_viewed_dests:
		raq_viewed_dests.append(dest_seq)


func _emit_inventory() -> void:
	emit_signal("inventory_updated", _inv.inventory_available, _inv.inventory_loaded, _inv.capacity_used, _inv.capacity_max)


func _get_load_rank(p: Dictionary) -> int:
	return GradingEngine.get_load_rank(p)


func _add_categorized_time(seconds: float, category: String) -> void:
	total_time += seconds
	if not _time_breakdown.has(category):
		_time_breakdown[category] = 0.0
	_time_breakdown[category] = float(_time_breakdown[category]) + seconds


func log_action(category: String, detail: String, extra_state: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"time": total_time,
		"action": category,
		"detail": detail,
	}
	var snap: Dictionary = _build_snapshot()
	if not extra_state.is_empty():
		snap.merge(extra_state, true)
	if not snap.is_empty():
		entry["state"] = snap
	_action_log.append(entry)


func _build_snapshot() -> Dictionary:
	## Returns a compact state snapshot for ghost replay frame capture.
	## Keys are kept short to minimise storage.
	var ls_filled: int = 0
	var ls_fields: Array[String] = [
		typed_store_code, typed_seal, typed_dock, typed_expedition_ls,
		typed_uat_count, typed_collis_count, typed_eur_count,
		typed_plastic_count, typed_magnum_count,
	]
	for f: String in ls_fields:
		if f != "":
			ls_filled += 1

	var cmr_filled: int = 0
	var cmr_fields: Array[String] = [
		typed_expedition_cmr, typed_weight, typed_dm3,
		typed_cmr_uats, typed_cmr_collis, typed_cmr_eur,
		typed_cmr_plastic, typed_cmr_magnum, typed_cmr_cc,
		typed_cmr_seal, typed_cmr_dock,
	]
	for f: String in cmr_fields:
		if f != "":
			cmr_filled += 1

	return {
		"ls": ls_filled,
		"ls_max": ls_fields.size(),
		"cmr": cmr_filled,
		"cmr_max": cmr_fields.size(),
		"cf": cmr_franco_selected,
		"ld": _inv.inventory_loaded.size(),
		"av": _inv.inventory_available.size(),
		"st": loading_started,
	}


# ==========================================
# GRADING
# ==========================================

func end_session() -> void:
	is_active = false
	var payload: Dictionary = GradingEngine.grade(self)
	emit_signal("session_ended", payload)
