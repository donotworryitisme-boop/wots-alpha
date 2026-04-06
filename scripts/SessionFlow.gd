class_name SessionFlow
extends RefCounted

## Manages the session lifecycle: portal selection, briefing, scenario start,
## debrief, and abandon. Also holds store destination data and seal generation.

var _ui: BayUI

# --- Store / destination data ---
var store_destinations: Array = [
	{"name": "ALEXANDRIUM", "code": "2093", "co_partner": "2226"},
	{"name": "ALKMAAR", "code": "1570", "co_partner": ""},
	{"name": "AMSTERDAM NOORD", "code": "2226", "co_partner": "2093"},
	{"name": "APELDOORN", "code": "896", "co_partner": ""},
	{"name": "ARENA", "code": "256", "co_partner": ""},
	{"name": "ARNHEM", "code": "1089", "co_partner": ""},
	{"name": "BEST", "code": "664", "co_partner": ""},
	{"name": "BREDA", "code": "1088", "co_partner": ""},
	{"name": "COOLSINGEL", "code": "1161", "co_partner": "1186"},
	{"name": "DEN BOSCH", "code": "3619", "co_partner": ""},
	{"name": "DEN HAAG", "code": "1186", "co_partner": "1161"},
	{"name": "EINDHOVEN", "code": "1185", "co_partner": ""},
	{"name": "ENSCHEDE", "code": "2092", "co_partner": "2225"},
	{"name": "GRONINGEN", "code": "2224", "co_partner": "897"},
	{"name": "KERKRADE", "code": "346", "co_partner": "2094"},
	{"name": "LEEUWARDEN", "code": "897", "co_partner": "2224"},
	{"name": "NIJMEGEN", "code": "2225", "co_partner": "2092"},
	{"name": "ROERMOND", "code": "2094", "co_partner": "346"},
]

var co_pairs: Array = [
	{"store1": "KERKRADE", "code1": "346", "store2": "ROERMOND", "code2": "2094"},
	{"store1": "COOLSINGEL", "code1": "1161", "store2": "DEN HAAG", "code2": "1186"},
	{"store1": "GRONINGEN", "code1": "2224", "store2": "LEEUWARDEN", "code2": "897"},
	{"store1": "ENSCHEDE", "code1": "2092", "store2": "NIJMEGEN", "code2": "2225"},
	{"store1": "ALEXANDRIUM", "code1": "2093", "store2": "AMSTERDAM NOORD", "code2": "2226"},
]

var current_dest_name: String = "ALKMAAR"
var current_dest_code: String = "1570"
var current_dest2_name: String = ""
var current_dest2_code: String = ""
var seal_number_1: String = ""
var seal_number_2: String = ""


func _init(ui: BayUI) -> void:
	_ui = ui


# ==========================================
# ABANDON SHIFT UI CONSTRUCTION
# ==========================================

func build_abandon_ui(root: Node) -> void:
	# --- End Shift button (top bar) ---
	_ui._btn_abandon = Button.new()
	_ui._btn_abandon.text = Locale.t("btn.abandon_shift")
	_ui._btn_abandon.add_theme_font_size_override("font_size", UITokens.fs(11))
	var ab_n := UIStyles.flat_m(Color(0.18, 0.08, 0.08), 10, 4, 10, 4, 6, 1, Color(0.4, 0.15, 0.15))
	_ui._btn_abandon.add_theme_stylebox_override("normal", ab_n)
	var ab_h := UIStyles.flat_m(Color(0.28, 0.1, 0.1), 10, 4, 10, 4, 6, 1, Color(0.7, 0.2, 0.2))
	_ui._btn_abandon.add_theme_stylebox_override("hover", ab_h)
	var ab_p := UIStyles.flat_m(Color(0.14, 0.06, 0.06), 10, 4, 10, 4, 6, 1, Color(0.4, 0.15, 0.15))
	_ui._btn_abandon.add_theme_stylebox_override("pressed", ab_p)
	_ui._btn_abandon.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_ui._btn_abandon.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	_ui._btn_abandon.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	_ui._btn_abandon.focus_mode = Control.FOCUS_NONE
	_ui._btn_abandon.visible = false
	_ui._btn_abandon.pressed.connect(show_abandon_confirm)
	if _ui._top_bar_hbox != null:
		_ui._top_bar_hbox.add_child(_ui._btn_abandon)

	# --- Abandon confirm overlay ---
	_ui._abandon_overlay = ColorRect.new()
	_ui._abandon_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_ui._abandon_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui._abandon_overlay.visible = false
	_ui._abandon_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_ui._abandon_overlay)
	var confirm_center := CenterContainer.new()
	confirm_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui._abandon_overlay.add_child(confirm_center)
	var confirm_panel := PanelContainer.new()
	UIStyles.apply_panel(confirm_panel,
			UIStyles.flat(UITokens.CLR_MODAL_BG, 10, 2, Color(0.5, 0.15, 0.15)))
	confirm_center.add_child(confirm_panel)
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 32)
	confirm_margin.add_theme_constant_override("margin_top", 24)
	confirm_margin.add_theme_constant_override("margin_right", 32)
	confirm_margin.add_theme_constant_override("margin_bottom", 24)
	confirm_panel.add_child(confirm_margin)
	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 20)
	confirm_margin.add_child(confirm_vbox)
	var confirm_lbl := Label.new()
	confirm_lbl.text = Locale.t("btn.abandon_confirm")
	confirm_lbl.add_theme_font_size_override("font_size", UITokens.fs(16))
	confirm_lbl.add_theme_color_override("font_color", UITokens.CLR_LIGHT_GRAY)
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_lbl.custom_minimum_size = Vector2(420, 0)
	confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_vbox.add_child(confirm_lbl)
	var confirm_btns := HBoxContainer.new()
	confirm_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_btns.add_theme_constant_override("separation", 16)
	confirm_vbox.add_child(confirm_btns)

	var btn_yes := Button.new()
	btn_yes.text = Locale.t("btn.abandon_yes")
	btn_yes.add_theme_font_size_override("font_size", UITokens.fs(14))
	btn_yes.add_theme_stylebox_override("normal",
			UIStyles.flat_m(Color(0.6, 0.15, 0.15), 20, 8, 20, 8, 6))
	btn_yes.add_theme_stylebox_override("hover",
			UIStyles.flat_m(UITokens.CLR_RED_DIM, 20, 8, 20, 8, 6))
	btn_yes.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_yes.add_theme_color_override("font_color", Color.WHITE)
	btn_yes.focus_mode = Control.FOCUS_NONE
	btn_yes.pressed.connect(do_abandon_shift)
	confirm_btns.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = Locale.t("btn.abandon_no")
	btn_no.add_theme_font_size_override("font_size", UITokens.fs(14))
	btn_no.add_theme_stylebox_override("normal",
			UIStyles.flat_m(Color(0.15, 0.16, 0.18), 20, 8, 20, 8, 6))
	btn_no.add_theme_stylebox_override("hover",
			UIStyles.flat_m(UITokens.CLR_SURFACE_DIM, 20, 8, 20, 8, 6))
	btn_no.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_no.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	btn_no.focus_mode = Control.FOCUS_NONE
	btn_no.pressed.connect(func() -> void: _ui._abandon_overlay.visible = false)
	confirm_btns.add_child(btn_no)


# ==========================================
# PORTAL CALLBACKS
# ==========================================

func on_portal_start_pressed() -> void:
	if _ui._session == null:
		return
	if _ui._portal.btn_start != null:
		_ui._portal.btn_start.disabled = true
	_ui._fade.fade_transition(func() -> void:
		_ui._portal.overlay.visible = false
		_ui._portal.show_briefing(_ui._portal.scenario_dropdown.get_selected_id())
	)


func on_briefing_continue_pressed() -> void:
	if _ui._portal.btn_briefing_continue != null:
		_ui._portal.btn_briefing_continue.disabled = true
	_ui._fade.fade_transition(func() -> void:
		_ui._portal.hide_briefing()
		execute_session_start()
	)


func populate_scenarios() -> void:
	if _ui._portal == null: return
	_ui._portal.populate_scenarios(_ui.highest_unlocked_scenario)
	on_portal_scenario_changed(_ui.highest_unlocked_scenario)


func on_portal_scenario_changed(idx: int) -> void:
	if _ui._portal == null: return
	_ui._portal.update_scenario_desc(idx)


func on_portal_language_changed(idx: int) -> void:
	Locale.current_lang = idx
	if _ui._portal != null: _ui._portal.refresh_language_labels()
	populate_scenarios()
	refresh_ui_locale()


func refresh_ui_locale() -> void:
	var ls_title: Label = _ui.pnl_notes.get_node_or_null("NotesMargin/NotesVBox/NotesTitle")
	if ls_title != null: ls_title.text = Locale.t("btn.loading_sheet")
	var office_title: Label = _ui.pnl_shift_board.get_node_or_null("ShiftBoardMargin/ShiftBoardVBox/ShiftBoardTitle")
	if office_title != null: office_title.text = Locale.t("btn.office")
	if _ui.btn_start_load != null: _ui.btn_start_load.text = Locale.t("btn.start_loading")
	if _ui.btn_call != null: _ui.btn_call.text = Locale.t("btn.call_depts")
	if _ui.btn_seal != null: _ui.btn_seal.text = Locale.t("btn.seal_truck")
	if _ui.btn_transit != null: _ui.btn_transit.text = Locale.t("btn.check_transit")
	if _ui.btn_adr != null: _ui.btn_adr.text = Locale.t("btn.check_adr")
	if _ui.btn_combine != null: _ui.btn_combine.text = Locale.t("btn.combine")
	if _ui.btn_sop != null: _ui.btn_sop.text = Locale.t("btn.help_sops")
	if _ui._btn_abandon != null: _ui._btn_abandon.text = Locale.t("btn.abandon_shift")
	if _ui._phone_btn_top != null: _ui._phone_btn_top.text = Locale.t("btn.phone")
	if _ui._office.office_seal_btn != null: _ui._office.office_seal_btn.text = Locale.t("btn.seal_truck")


# ==========================================
# SESSION START
# ==========================================

func _read_portal_seed() -> int:
	if _ui._portal == null or _ui._portal.seed_input == null:
		return 0
	var txt: String = _ui._portal.seed_input.text.strip_edges()
	if txt == "":
		return 0
	if txt.is_valid_int():
		return int(txt)
	return 0


func execute_session_start() -> void:
	_ui._current_scenario_index = _ui._portal.scenario_dropdown.get_selected_id()
	if _ui._current_scenario_index == 0: _ui._current_scenario_name = "0. Tutorial"
	elif _ui._current_scenario_index == 1: _ui._current_scenario_name = "1. Standard Loading"
	elif _ui._current_scenario_index == 2: _ui._current_scenario_name = "2. Priority Loading"
	elif _ui._current_scenario_index == 3: _ui._current_scenario_name = "3. Co-Loading"
	elif _ui._current_scenario_index == 4: _ui._current_scenario_name = "4. Free Play"

	_ui._session.set_role(WOTSConfig.Role.OPERATOR)
	_ui._is_active = true

	# --- Determine seed ---
	var seed_val: int = _read_portal_seed()
	if seed_val == 0:
		seed_val = randi()
	# Write seed back to portal so user can see/copy it
	if _ui._portal.seed_input != null:
		_ui._portal.seed_input.text = str(seed_val)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var dest: Dictionary = store_destinations[rng.randi_range(0, store_destinations.size() - 1)]
	current_dest_name = dest.name
	current_dest_code = dest.code
	current_dest2_name = ""
	current_dest2_code = ""

	if _ui._current_scenario_index == 3:
		var pair: Dictionary = co_pairs[rng.randi_range(0, co_pairs.size() - 1)]
		current_dest_name = pair.store1
		current_dest_code = pair.code1
		current_dest2_name = pair.store2
		current_dest2_code = pair.code2

	# Generate seal numbers
	var seal_prefix: int = 865 if rng.randf() < 0.85 else 866
	var seal_suffix: int = 700 + (hash(current_dest_name + str(rng.randi())) % 300)
	seal_number_1 = str(seal_prefix * 1000 + seal_suffix)
	if current_dest2_name != "":
		var seal_suffix_2: int = 700 + (hash(current_dest2_name + str(rng.randi())) % 300)
		while seal_suffix_2 == seal_suffix:
			seal_suffix_2 = 700 + (rng.randi() % 300)
		seal_number_2 = str(seal_prefix * 1000 + seal_suffix_2)
	else:
		seal_number_2 = ""

	_ui._dock.rebuild_lanes(_ui._current_scenario_index == 3)
	_ui._phone.reset()
	_ui._load_cooldown = false
	_ui._undo_pallet_id = ""
	_ui._undo_remaining = 0.0
	if _ui._undo_btn != null: _ui._undo_btn.visible = false

	_ui._portal.overlay.visible = false
	_ui.top_actions_hbox.visible = true
	_ui.stage_hbox.visible = true
	if _ui._btn_abandon != null: _ui._btn_abandon.visible = true

	_ui._ws.reset_panel_state()
	_ui._ws.close_all_panels(true)

	_ui._office.reset_for_new_session()
	_ui._lp_board.reset()

	_ui._as400_confirmed = false
	if _ui.btn_open_dock != null: _ui.btn_open_dock.visible = true
	if _ui.btn_close_dock != null: _ui.btn_close_dock.visible = false
	_ui._dock._dock_open = false
	if _ui._dock._leveler_overlay != null: _ui._dock._leveler_overlay.visible = true
	if _ui._dock._leveler_label != null: _ui._dock._leveler_label.text = "DOCK CLOSED — Open dock to begin"
	if _ui._dock._leveler_strip != null: _ui._dock._leveler_strip.color = UITokens.CLR_DOCK_FLOOR

	_ui._as400.state = AS400Terminal.S.SIGN_ON
	_ui._as400.wrong_store_scans = 0
	_ui._as400._init_tabs()
	_ui._as400._render_as400_screen()

	_ui._active_workspace = ""
	if _ui._current_scenario_index == 0:
		_ui._tc.start()
		_ui._tut.canvas.visible = true
		_ui._ws.switch_workspace("DOCK")
	else:
		_ui._tc.stop()
		if _ui._tut.canvas != null: _ui._tut.canvas.visible = false
		_ui._ws.switch_workspace("OFFICE")

	_ui._session.start_session_with_scenario(_ui._current_scenario_name, seed_val)
	Telemetry.log_session_start(_ui._current_scenario_name)

	# Setup interruption events for this session
	_ui._interruptions.setup_for_session(_ui._current_scenario_index, seed_val)

	# Set metadata AFTER start_session_with_scenario (which resets them)
	var co_partner: String = current_dest2_name if current_dest2_name != "" else ""
	_ui._session.dock_number = WarehouseData.get_dock_number(current_dest_name, co_partner)
	_ui._session.carrier_name = WarehouseData.get_carrier(_ui._session.dock_number)
	var exp_rng := RandomNumberGenerator.new()
	exp_rng.seed = seed_val + 7919
	if current_dest2_name != "":
		var exp_pair: Array = WarehouseData.generate_co_expedition_numbers(exp_rng)
		_ui._session.expedition_number_1 = exp_pair[0] as String
		_ui._session.expedition_number_2 = exp_pair[1] as String
	else:
		_ui._session.expedition_number_1 = WarehouseData.generate_expedition_number(exp_rng)
		_ui._session.expedition_number_2 = ""
	_ui._session.store_code = current_dest_code
	_ui._session.store_code_2 = current_dest2_code
	_ui._session.seal_number = seal_number_1
	_ui._session.seal_number_2 = seal_number_2

	if _ui.btn_transit != null:
		_ui.btn_transit.visible = (_ui._current_scenario_index >= 1)
		_ui.btn_transit.disabled = true
	if _ui.btn_adr != null:
		_ui.btn_adr.visible = (_ui._current_scenario_index >= 1)
		_ui.btn_adr.disabled = true
	if _ui.btn_combine != null:
		_ui.btn_combine.visible = (_ui._current_scenario_index >= 1)
		_ui._refresh_combine_btn()
	_ui._paper.clear_paperwork_fields()
	_ui._paper.cmr.show_dest_tabs(_ui._session.is_co_load)
	_ui._paper.ls.show_dest_tabs(_ui._session.is_co_load)
	_ui._ws.populate_overlay_panels()
	if _ui._portal.btn_start != null:
		_ui._portal.btn_start.disabled = false


# ==========================================
# SESSION END / DEBRIEF
# ==========================================

func on_session_ended(debrief_payload: Dictionary) -> void:
	_ui._is_active = false
	_ui._interruptions.reset()

	# Free Play — skip debrief and training record, return to portal
	if _ui._current_scenario_index == 4:
		if _ui.tutorial_active: _ui._tut.canvas.visible = false
		_ui._fade.fade_transition(_return_to_portal)
		return

	_ui._debrief.store_payload(debrief_payload)

	# Persist training record
	if _ui._session != null:
		TrainingRecord.save_record(debrief_payload, _ui._current_scenario_name, _ui._session.total_time, _ui._session.session_seed)
		Telemetry.log_session_complete(
			_ui._current_scenario_name,
			int(debrief_payload.get("score", 0)),
			_ui._session.total_time,
			debrief_payload.get("mistakes", {}) as Dictionary
		)

	var passed: bool = debrief_payload.get("passed", false)
	if passed:
		WOTSAudio.play_success_chime(_ui)
		if _ui._current_scenario_index == _ui.highest_unlocked_scenario and _ui.highest_unlocked_scenario < 3:
			_ui.highest_unlocked_scenario += 1

	if _ui.tutorial_active: _ui._tut.canvas.visible = false

	populate_scenarios()
	_ui._fade.fade_transition(func() -> void: _ui._debrief.render())


func on_debrief_closed() -> void:
	_ui._fade.fade_transition(_return_to_portal)


func _return_to_portal() -> void:
	_ui._debrief.overlay.visible = false
	_ui.top_actions_hbox.visible = false
	_ui.stage_hbox.visible = false
	_ui._ws.close_all_panels(true)
	if _ui._dock_workspace != null: _ui._dock_workspace.visible = false
	if _ui._office_workspace != null: _ui._office_workspace.visible = false
	if _ui.btn_transit != null: _ui.btn_transit.visible = false
	if _ui.btn_adr != null: _ui.btn_adr.visible = false
	if _ui.btn_combine != null: _ui.btn_combine.visible = false
	if _ui._btn_abandon != null: _ui._btn_abandon.visible = false
	_ui._portal.overlay.visible = true
	if _ui._portal.btn_start != null: _ui._portal.btn_start.disabled = false
	if _ui._portal.btn_briefing_continue != null: _ui._portal.btn_briefing_continue.disabled = false


# ==========================================
# ABANDON SHIFT
# ==========================================

func show_abandon_confirm() -> void:
	if _ui._abandon_overlay != null:
		_ui._abandon_overlay.visible = true


func do_abandon_shift() -> void:
	_ui._abandon_overlay.visible = false
	_ui._fade.fade_transition(func() -> void: _execute_abandon())


func _execute_abandon() -> void:
	if _ui._session != null:
		_ui._session.is_active = false
		_ui._session.is_paused = false
	_ui._is_active = false
	_ui._tc.stop()
	_ui._interruptions.reset()
	if _ui._tut.canvas != null: _ui._tut.canvas.visible = false
	_ui._debrief.overlay.visible = false
	_ui.top_actions_hbox.visible = false
	_ui.stage_hbox.visible = false
	_ui._ws.close_all_panels(true)
	if _ui._dock_workspace != null: _ui._dock_workspace.visible = false
	if _ui._office_workspace != null: _ui._office_workspace.visible = false
	if _ui.btn_transit != null: _ui.btn_transit.visible = false
	if _ui.btn_adr != null: _ui.btn_adr.visible = false
	if _ui.btn_combine != null: _ui.btn_combine.visible = false
	if _ui._btn_abandon != null: _ui._btn_abandon.visible = false
	_ui._phone.reset()
	_ui._portal.overlay.visible = true
	if _ui._portal.btn_start != null: _ui._portal.btn_start.disabled = false
	if _ui._portal.btn_briefing_continue != null: _ui._portal.btn_briefing_continue.disabled = false
