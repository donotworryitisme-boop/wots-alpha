class_name TutorialController
extends RefCounted

# ==========================================
# TUTORIAL CONTROLLER — Item 25
# Single owner of tutorial state and all step transition logic.
#
# POST-LOADING FLOW (steps 16-24):
#   16  Open LS on dock overlay → fill counts
#   17  Open CMR on dock overlay → fill fields (exp, seal, dock, stamp, sign, X, franco)
#   18  Open AS400 → F10 confirm → weight/dm3 appear
#   19  Open CMR again on dock → fill weight/dm3
#   20  Close dock
#   21  Switch to Office
#   22  Hand CMR to driver
#   23  Archive paperwork
#   24  Seal truck → shift complete
# ==========================================

var _ui: BayUI
var active: bool = false
var step: int = -1

# T4: Step 11 has two phases — first Mecha load must be UNDONE,
# second Mecha load must be UNLOADED via the truck (penalty).
# These flags track sub-state inside step 11.
var mecha_loaded_in_step_11: bool = false
var mecha_undone_once: bool = false


func _init(ui: BayUI) -> void:
	_ui = ui


func start() -> void:
	active = true
	step = 0
	mecha_loaded_in_step_11 = false
	mecha_undone_once = false
	_ui._tut.update_ui()


func stop() -> void:
	active = false
	step = -1
	mecha_loaded_in_step_11 = false
	mecha_undone_once = false


# ==========================================
# STEP ADVANCE METHODS
# Each method handles one event type. The calling file
# invokes the appropriate method; all step logic lives here.
# ==========================================

func try_advance_workspace(ws_name: String) -> void:
	## Called from WorkspaceController._apply_workspace().
	if not active:
		return
	if ws_name == "OFFICE" and step == 0:
		_set_step(1)
	elif ws_name == "DOCK" and step == 3:
		_set_step(4)
	elif ws_name == "OFFICE" and step == 21:
		_set_step(22)


func try_advance_panel(panel_name: String, make_visible: bool) -> void:
	## Called from WorkspaceController.set_panel_visible() and _show_dock_paperwork().
	if not active or not make_visible:
		return
	if step == 0 and panel_name == "Office":
		_set_step(1)
	elif step == 1 and panel_name == "Loading Sheet":
		_set_step(2)
	elif step == 2 and panel_name == "CMR":
		_set_step(3)
	elif step == 3 and panel_name == "Dock View":
		_set_step(4)
	elif step == 5 and panel_name == "AS400":
		_set_step(6)


func try_advance_desk(collected_count: int) -> void:
	## Called from OfficeManager desk item collection.
	if not active:
		return
	if step == 1 and collected_count >= 3:
		_set_step(2)


func try_advance_dock_open() -> void:
	## Called from BayUI._on_open_dock_pressed().
	if not active:
		return
	if step == 4:
		_set_step(5)


func try_advance_dock_close() -> void:
	## Called from BayUI._on_close_dock_pressed().
	if not active:
		return
	if step == 20:
		_set_step(21)


func try_advance_as400_state(as400_state: int) -> void:
	## Called from AS400Terminal after state transitions.
	## Uses AS400Terminal.S enum values.
	if not active:
		return
	# S.MENU_MAIN = 2, S.SAISIE_EXPEDITION = 3, S.RAQ = 14
	if step == 5 and as400_state == AS400Terminal.S.MENU_MAIN:
		_set_step(6)
	elif step == 6 and as400_state == AS400Terminal.S.SAISIE_EXPEDITION:
		_set_step(7)
	elif step == 8 and as400_state == AS400Terminal.S.RAQ:
		_set_step(9)


func try_advance_as400_seal_entered() -> void:
	## Called from AS400Terminal when seal entry completes (F10 → SCANNING).
	if not active:
		return
	if step == 7:
		_set_step(8)


func try_advance_as400_raq_opened() -> void:
	## Called from AS400Terminal when F13 opens RAQ.
	if not active:
		return
	if step == 8:
		_set_step(9)


func try_advance_cmr_filled() -> void:
	## Called from CMRForm._write_field(), _apply_stamp_top(), _apply_stamp_bot(),
	## _select_franco(). Handles step 16 → 17 (CMR pallet counts),
	## step 17 → 18 (expedition/seal/stamp), and step 19 → 20 (weight/dm³).
	if not active:
		return
	if _ui._session == null:
		return
	var sm: SessionManager = _ui._session
	if step == 16:
		if sm.typed_cmr_uats.strip_edges() != "" or sm.typed_cmr_collis.strip_edges() != "":
			_set_step(17)
	elif step == 17:
		var has_input: bool = (
			sm.typed_expedition_cmr.strip_edges() != ""
			or sm.typed_cmr_seal.strip_edges() != ""
			or _ui._paper.cmr.stamp_top_stamped
		)
		if has_input:
			_set_step(18)
	elif step == 19:
		if sm.typed_weight.strip_edges() != "" or sm.typed_dm3.strip_edges() != "":
			_set_step(20)


func try_advance_as400_confirm() -> void:
	## Called from AS400Terminal._confirm_as400_raq() when F10 confirms.
	## Returns early with warning if not ready.
	if not active:
		return
	if step < 18:
		_ui._tut.flash_warning(Locale.t("warn.finish_loading_first"))
		return
	if step == 18:
		# Advance to step 19 — CMR stays open so user can fill weight/dm³
		_set_step(19)


func is_as400_confirm_blocked() -> bool:
	## Returns true if the AS400 confirm should be blocked by tutorial.
	if not active:
		return false
	return step < 18


func try_advance_inventory(avail: Array, loaded: Array) -> void:
	## Called from BayUI._on_inventory_updated().
	if not active:
		return
	if step == 11:
		# T4: Two-phase Mecha lesson.
		# Phase A: no Mecha loaded yet, undone_once=false → wait for first load
		# Phase B: Mecha loaded, undone_once=false → force UNDO
		# Phase C: no Mecha loaded, undone_once=true → wait for second load
		# Then advance to step 12 (truck-unload phase).
		var has_mecha: bool = false
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "Mecha":
				has_mecha = true
				break
		if has_mecha and mecha_undone_once:
			_set_step(12)
			return
		if has_mecha and not mecha_undone_once:
			# Entered Phase B — refresh overlay text to prompt undo
			if not mecha_loaded_in_step_11:
				mecha_loaded_in_step_11 = true
				_ui._tut.update_ui()
			return
		if not has_mecha and mecha_loaded_in_step_11 and mecha_undone_once:
			# Just exited Phase B via undo → entered Phase C
			mecha_loaded_in_step_11 = false
			_ui._tut.update_ui()
			return
	elif step == 12:
		var has_mecha_12: bool = false
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "Mecha":
				has_mecha_12 = true
				break
		if not has_mecha_12:
			_set_step(13)
	elif step == 13:
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "ServiceCenter":
				_set_step(14)
				return
	elif step == 14:
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "Bikes":
				_set_step(15)
				return
	elif step == 15:
		if avail.is_empty():
			_set_step(16)


func try_advance_decision(action: String) -> bool:
	## Called from BayUI._on_decision_pressed().
	## Returns false if the action is gated (caller should return early).
	if not active:
		return true
	if step < 9:
		_ui._tut.flash_warning(Locale.t("warn.not_ready"))
		return false
	if step == 9:
		if action != "Call departments (C&C check)":
			_ui._tut.flash_warning(Locale.t("warn.call_depts"))
			return false
		_set_step(10)
		return true
	if step == 10:
		if action != "Start Loading":
			_ui._tut.flash_warning(Locale.t("warn.start_loading"))
			return false
		_set_step(11)
		return true
	if step < 24 and action == "Seal Truck":
		_ui._tut.flash_warning(Locale.t("warn.not_finished"))
		return false
	return true


func try_advance_wrapup(phase: String) -> void:
	## Called from OfficeManager.advance_wrapup().
	if not active:
		return
	if phase == "hand_cmr" and step == 22:
		_set_step(23)
	elif phase == "archive" and step == 23:
		_set_step(24)


func try_advance_paperwork_tab(_tab: String) -> void:
	## Called from OfficeManager.switch_paperwork_tab().
	## In the current flow LS/CMR are opened via dock overlay (steps 16-19),
	## so office-side tab switching does not advance tutorial steps.
	if not active:
		return


# ==========================================
# SKIP — auto-perform the user's expected action
# ==========================================

func skip_current_step() -> void:
	## Called from TutorialOverlay._on_skip_pressed().
	## Performs the action the user was supposed to do, then the step
	## advances via the normal trigger path.
	if not active:
		return
	if _ui._session != null:
		_ui._session.log_action("tutorial_skip", str(step))

	match step:
		0:
			# Switch to OFFICE — triggers try_advance_workspace
			_ui._ws.switch_workspace("OFFICE")
		1:
			# Collect all desk items
			_skip_collect_desk()
		2:
			# Fill LS pre-load fields → triggers CMR reveal → advance
			_skip_fill_ls_preload()
		3:
			# Switch to DOCK
			_ui._ws.switch_workspace("DOCK")
		4:
			# Open dock
			_ui._on_open_dock_pressed()
		5:
			# Open AS400 panel
			_ui._ws.toggle_panel("AS400")
		6, 7, 8:
			# Jump AS400 to RAQ state
			_skip_as400_to_raq()
		9:
			# Call departments
			_ui._on_decision_pressed("Call departments (C&C check)")
		10:
			# Start loading
			_ui._on_decision_pressed("Start Loading")
		11, 12, 13, 14, 15:
			# Load all pallets in correct order (skips the Mecha mistake)
			_skip_load_all_pallets()
		16:
			# Fill CMR pallet counts + advance
			_skip_fill_cmr_counts()
		17:
			# Fill CMR expedition/seal/dock, stamp, sign, Franco + advance
			_skip_fill_cmr_details()
		18:
			# AS400 F10 confirm
			_skip_as400_confirm()
		19:
			# Fill CMR weight/dm³ + advance
			_skip_fill_cmr_weight_dm3()
		20:
			# Close dock (ensure AS400 confirmed first)
			_skip_close_dock()
		21:
			# Switch to OFFICE
			_ui._ws.switch_workspace("OFFICE")
		22:
			# Hand CMR
			_ui._office.advance_wrapup("hand_cmr")
		23:
			# Archive
			_ui._office.advance_wrapup("archive")
		24:
			# Seal truck
			_ui._office.advance_wrapup("seal")
		_:
			_set_step(step + 1)


func _skip_collect_desk() -> void:
	## Auto-collect all desk items.
	for key: String in ["cmr", "seal", "loading_sheet"]:
		_ui._office._collect_desk_item(key)


func _skip_fill_ls_preload() -> void:
	## Auto-fill LS store/seal/dock fields with correct values.
	if _ui._session == null:
		_set_step(3)
		return
	var store_code: String = _ui.current_dest_code
	var seal: String = _ui.seal_number_1
	var dock: String = str(WarehouseData.get_dock_number(_ui.current_dest_name))
	var ls: LoadingSheetForm = _ui._paper.ls
	if ls.ls_input_store != null:
		ls.ls_input_store.text = store_code
		_ui._session.typed_store_code = store_code
	if ls.ls_input_seal != null:
		ls.ls_input_seal.text = seal
		_ui._session.typed_seal = seal
	if ls.ls_input_dock != null:
		ls.ls_input_dock.text = dock
		_ui._session.typed_dock = dock
	# Trigger the preload check which reveals CMR → advances to step 3
	_ui._paper.check_ls_preload_done()


func _skip_fill_cmr_counts() -> void:
	## Auto-fill CMR pallet count fields from loaded inventory.
	if _ui._session == null:
		_set_step(17)
		return
	# Ensure CMR is open on dock
	if not _ui._ws.is_dock_paperwork_open():
		_ui._ws.toggle_panel("CMR")
	var cmr: CMRForm = _ui._paper.cmr
	cmr.build_if_needed()
	# Calculate counts from loaded pallets
	var source: Array = _ui._session.inventory_loaded
	var uats: int = source.size()
	var collis: int = 0
	var eur: int = 0
	var plastic: int = 0
	var magnum: int = 0
	var cc: int = 0
	for p: Dictionary in source:
		collis += int(p.get("collis", 0))
		var base: String = str(p.get("pallet_base", "euro"))
		if base == "euro":
			eur += 1
		elif base == "plastic":
			plastic += 1
		elif base == "magnum":
			magnum += 1
		if str(p.get("type", "")) == "C&C":
			cc += 1
	# Set input fields (text_changed triggers _write_field + log_action)
	if cmr._input_uats != null:
		cmr._input_uats.text = str(uats)
	if cmr._input_collis != null:
		cmr._input_collis.text = str(collis)
	if cmr._input_eur != null:
		cmr._input_eur.text = str(eur)
	if cmr._input_plastic != null:
		cmr._input_plastic.text = str(plastic)
	if cmr._input_magnum != null:
		cmr._input_magnum.text = str(magnum)
	if cmr._input_cc != null:
		cmr._input_cc.text = str(cc)
	# Advance (may already have advanced via try_advance_cmr_filled)
	if step == 16:
		_set_step(17)


func _skip_fill_cmr_details() -> void:
	## Auto-fill CMR expedition, seal, dock, stamp, sign, Franco.
	if _ui._session == null:
		_set_step(18)
		return
	# Ensure CMR is open on dock
	if _ui._ws.is_dock_paperwork_open():
		_ui._ws.hide_dock_paperwork()
	_ui._ws.toggle_panel("CMR")
	var cmr: CMRForm = _ui._paper.cmr
	cmr.build_if_needed()
	# Fill expedition, seal, dock
	var expedition: String = _ui._session.expedition_number_1
	var seal: String = _ui.seal_number_1
	var dock: String = str(_ui._session.dock_number)
	if cmr._input_expedition != null:
		cmr._input_expedition.text = expedition
	if cmr._input_seal != null:
		cmr._input_seal.text = seal
	if cmr._input_dock != null:
		cmr._input_dock.text = dock
	# Stamp and sign
	cmr._apply_stamp_top()
	cmr._apply_stamp_bot()
	# Franco
	cmr._select_franco("franco")
	# Advance
	if step == 17:
		_set_step(18)


func _skip_fill_cmr_weight_dm3() -> void:
	## Auto-fill CMR weight and dm³ from loaded inventory.
	if _ui._session == null:
		_set_step(20)
		return
	# Ensure CMR is open on dock
	if _ui._ws.is_dock_paperwork_open():
		_ui._ws.hide_dock_paperwork()
	_ui._ws.toggle_panel("CMR")
	var cmr: CMRForm = _ui._paper.cmr
	cmr.build_if_needed()
	# Calculate weight and dm³
	var total_weight: float = 0.0
	var total_dm3: int = 0
	for p: Dictionary in _ui._session.inventory_loaded:
		total_weight += float(p.get("weight_kg", 0.0))
		total_dm3 += int(p.get("dm3", 0))
	if cmr._input_weight != null:
		cmr._input_weight.text = str(int(total_weight))
	if cmr._input_dm3 != null:
		cmr._input_dm3.text = str(total_dm3)
	# Advance
	if step == 19:
		_set_step(20)


func _skip_as400_to_raq() -> void:
	## Jump AS400 directly to RAQ state (skipping login menus).
	var as400: AS400Terminal = _ui._as400
	if as400 == null:
		_set_step(9)
		return
	# Ensure AS400 panel is visible
	if as400.panel != null and not as400.panel.visible:
		_ui._ws.set_panel_visible("AS400", true, true)
	# Set up tab with correct destination and seal
	if not as400._tabs.is_empty():
		as400._tabs[as400._active_tab]["dest_code"] = _ui.current_dest_code
		as400._tabs[as400._active_tab]["dest_name"] = _ui.current_dest_name
		as400._tabs[as400._active_tab]["seal_entered"] = _ui.seal_number_1
		as400._tabs[as400._active_tab]["state"] = AS400Terminal.S.RAQ
	as400.state = AS400Terminal.S.RAQ
	as400._save_tab_state()
	as400._render_as400_screen()
	as400.raq_opened.emit()
	_set_step(9)


func _skip_load_all_pallets() -> void:
	## Load all available pallets in correct sequence.
	if _ui._session == null:
		_set_step(16)
		return
	# Temporarily disable tutorial advance to avoid step-by-step triggers
	var saved_step: int = step
	active = false
	# Unload any incorrectly loaded Mecha first (step 11-12 teaching)
	for p: Dictionary in _ui._session.inventory_loaded.duplicate():
		if str(p.get("type", "")) == "Mecha":
			_ui._session.unload_pallet_by_id(str(p.get("id", "")))
	# Load in correct order
	var type_order: Array[String] = ["ServiceCenter", "Bikes", "Bulky", "Mecha", "C&C"]
	for ptype: String in type_order:
		var found: bool = true
		while found:
			found = false
			for p: Dictionary in _ui._session.inventory_available.duplicate():
				if str(p.get("type", "")) == ptype:
					_ui._session.load_pallet_by_id(str(p.get("id", "")))
					found = true
					break
	# Restore tutorial and jump to step 16
	active = true
	step = saved_step
	_set_step(16)


func _skip_as400_confirm() -> void:
	## Trigger AS400 F10 confirm (sets _as400_confirmed, shows close dock btn).
	var as400: AS400Terminal = _ui._as400
	if as400 == null:
		_set_step(19)
		return
	# Ensure AS400 is in RAQ or SCANNING state for confirm to work
	if as400.state != AS400Terminal.S.RAQ and as400.state != AS400Terminal.S.SCANNING:
		as400.state = AS400Terminal.S.RAQ
		as400._save_tab_state()
	# Ensure AS400 panel is visible
	if as400.panel != null and not as400.panel.visible:
		_ui._ws.set_panel_visible("AS400", true, true)
	# Call the confirm — this triggers try_advance_as400_confirm → step 19
	as400._confirm_as400_raq()


func _skip_close_dock() -> void:
	## Close the dock, ensuring AS400 is confirmed first.
	if not _ui._as400_confirmed:
		_ui._as400_confirmed = true
		if _ui.btn_close_dock != null:
			_ui.btn_close_dock.visible = true
	if _ui._dock.is_dock_open():
		_ui._on_close_dock_pressed()
	else:
		_set_step(21)


# ==========================================
# GATE CHECKS
# ==========================================

func check_panel_gate(panel_name: String) -> String:
	## Returns "" if panel is allowed, or a warning locale key if gated.
	## Called from WorkspaceController.toggle_panel().
	if not active:
		return ""
	if step == 0 and panel_name != "Office":
		return "warn.open_office_first"
	if step == 1 and panel_name != "Loading Sheet" and panel_name != "Office":
		return "warn.open_loading_sheet"
	if step == 2 and panel_name != "CMR" and panel_name != "Loading Sheet" and panel_name != "Office":
		return "warn.open_cmr"
	if step == 3 and panel_name != "Dock View":
		return "warn.open_dock_view"
	# Steps 4-5: AS400 login — allow AS400 + Loading Sheet
	if step >= 4 and step <= 5 and panel_name != "AS400" and panel_name != "Loading Sheet":
		return "warn.open_as400_first"
	# Steps 6-7: SAISIE screen — also allow CMR (good practice to note expedition early)
	if step >= 6 and step <= 7 and panel_name != "AS400" and panel_name != "Loading Sheet" and panel_name != "CMR":
		return "warn.open_as400_first"
	if step == 8 and panel_name != "AS400":
		return "warn.open_as400_f13"
	# Post-loading gates
	if step == 16 and panel_name != "CMR" and panel_name != "Loading Sheet":
		return "warn.open_cmr"
	if step == 17 and panel_name != "CMR" and panel_name != "Loading Sheet":
		return "warn.open_cmr"
	if step == 18 and panel_name != "AS400":
		return "warn.open_as400_first"
	if step == 19 and panel_name != "CMR" and panel_name != "AS400":
		return "warn.open_cmr"
	return ""


func is_dock_hidden_at_start() -> bool:
	## Returns true when the tutorial first starts and dock should be hidden.
	return active and step == 0


func check_pallet_load_gate(ptype: String) -> String:
	## Returns "" if loading this pallet type is allowed, or a warning locale key.
	## Called from DockView._draw_pallet() pressed handler.
	if not active:
		return ""
	if step < 11:
		return "warn.not_ready_load"
	if step == 11 and ptype != "Mecha":
		return "warn.click_mecha"
	if step == 12:
		return "warn.remove_mecha"
	if step == 13 and ptype != "ServiceCenter":
		return "warn.service_first"
	if step == 14 and ptype != "Bikes":
		return "warn.bikes_next"
	return ""


func check_pallet_unload_gate() -> String:
	## Returns "" if unloading is allowed, or a warning locale key.
	## Called from DockView truck grid unload pressed handler.
	if not active:
		return ""
	# T4: Step 11 Phase B — force player to use the Undo button, not the truck
	if step == 11 and mecha_loaded_in_step_11 and not mecha_undone_once:
		return "warn.use_undo_first"
	if step != 12:
		return "warn.dont_unload"
	return ""


func on_undo_used() -> void:
	## T4: Called from BayUI._perform_undo() BEFORE the actual undo runs,
	## so the inventory_updated signal that follows sees the correct flag state.
	if not active:
		return
	if step == 11 and mecha_loaded_in_step_11 and not mecha_undone_once:
		mecha_undone_once = true
		# mecha_loaded_in_step_11 is reset by try_advance_inventory once
		# the inventory_updated signal arrives showing no Mecha loaded.


func check_scanner_gate() -> String:
	## Returns "" if scanning is allowed, or a warning locale key.
	## Called from DockView when AS400 not in scanning state during tutorial.
	if not active:
		return ""
	if step == 8:
		return "warn.scanner_raq_tutorial"
	return ""


# ==========================================
# INTERNAL
# ==========================================

func _set_step(new_step: int) -> void:
	step = new_step
	_ui._tut.update_ui()
