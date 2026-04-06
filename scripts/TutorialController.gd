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


func _init(ui: BayUI) -> void:
	_ui = ui


func start() -> void:
	active = true
	step = 0
	_ui._tut.update_ui()


func stop() -> void:
	active = false
	step = -1


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
	elif step == 16 and panel_name == "Loading Sheet":
		_set_step(17)
	elif step == 17 and panel_name == "CMR":
		_set_step(18)
	elif step == 19 and panel_name == "CMR":
		_set_step(20)


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


func try_advance_as400_confirm() -> void:
	## Called from AS400Terminal._confirm_as400_raq() when F10 confirms.
	## Returns early with warning if not ready.
	if not active:
		return
	if step < 18:
		_ui._tut.flash_warning(Locale.t("warn.finish_loading_first"))
		return
	if step == 18:
		# Close any open dock paperwork so user can cleanly reopen CMR
		# to fill weight/dm3 at step 19
		if _ui._ws.is_dock_paperwork_open():
			_ui._ws.hide_dock_paperwork()
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
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "Mecha":
				_set_step(12)
				return
	elif step == 12:
		var has_mecha: bool = false
		for p: Dictionary in loaded:
			if str(p.get("type", "")) == "Mecha":
				has_mecha = true
		if not has_mecha:
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
			# Open LS on dock
			_ui._ws.toggle_panel("Loading Sheet")
		17:
			# Close LS if open, open CMR on dock
			if _ui._ws.is_dock_paperwork_open():
				_ui._ws.hide_dock_paperwork()
			_ui._ws.toggle_panel("CMR")
		18:
			# AS400 F10 confirm
			_skip_as400_confirm()
		19:
			# Reopen CMR on dock
			if _ui._ws.is_dock_paperwork_open():
				_ui._ws.hide_dock_paperwork()
			_ui._ws.toggle_panel("CMR")
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
	if step == 16 and panel_name != "Loading Sheet":
		return "warn.open_loading_sheet"
	if step == 17 and panel_name != "CMR" and panel_name != "Loading Sheet":
		return "warn.open_cmr"
	if step == 18 and panel_name != "AS400":
		return "warn.open_as400_first"
	if step == 19 and panel_name != "CMR":
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
	if step != 12:
		return "warn.dont_unload"
	return ""


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
