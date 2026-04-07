class_name DrillManager
extends RefCounted

## Micro-drills for isolated skill practice (Item 27).
## Three modes: AS400 Navigation, Loading Sequence, Paperwork.
## Each drill is a focused 1-3 minute exercise launched from the portal.

enum Type { AS400_NAV, SEQUENCING, PAPERWORK }

var _ui: BayUI

# --- State ---
var is_active: bool = false
var _type: int = Type.AS400_NAV
var _elapsed: float = 0.0
var _completed: bool = false
var _raq_connected: bool = false
var _paper_phase: int = 0  # 0=pre-load, 1=post-load

# --- Selection overlay ---
var _sel_overlay: ColorRect = null

# --- Result overlay ---
var _res_overlay: ColorRect = null
var _res_score_lbl: Label = null
var _res_feedback: RichTextLabel = null

# --- Submit bar (paperwork drill) ---
var _submit_bar: HBoxContainer = null


func _init(ui: BayUI) -> void:
	_ui = ui


func build(root: Control) -> void:
	_build_selection(root)
	_build_result(root)
	_build_submit_bar(root)


func tick(delta: float) -> void:
	if not is_active or _completed:
		return
	_elapsed += delta
	if _type == Type.SEQUENCING:
		_check_seq_complete()


func open_selection() -> void:
	if _sel_overlay != null:
		# S61 Fix #6: portal rebuild re-parents the portal overlay as the last
		# child of $Root, covering this drill selection overlay. Move ourselves
		# to the top of the sibling stack so the selection is visible.
		var parent_node: Node = _sel_overlay.get_parent()
		if parent_node != null:
			parent_node.move_child(_sel_overlay, parent_node.get_child_count() - 1)
		_sel_overlay.visible = true


# ==========================================
# SELECTION OVERLAY
# ==========================================

func _build_selection(root: Control) -> void:
	_sel_overlay = ColorRect.new()
	_sel_overlay.color = Color(UITokens.CLR_OVERLAY_DARK, 0.96)
	_sel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_sel_overlay.visible = false
	root.add_child(_sel_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel_overlay.add_child(center)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	center.add_child(main_vbox)

	# Header
	var title_lbl: Label = Label.new()
	title_lbl.text = Locale.t("drill.title")
	title_lbl.add_theme_font_size_override("font_size", UITokens.fs(24))
	title_lbl.add_theme_color_override("font_color", UITokens.CLR_TITLE_TEXT)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = Locale.t("drill.subtitle")
	sub_lbl.add_theme_font_size_override("font_size", UITokens.fs(14))
	sub_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.COLOR_TEXT_META))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(sub_lbl)

	# Drill cards
	var cards_hbox: HBoxContainer = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 20)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(cards_hbox)

	_add_card(cards_hbox, "drill.as400_title", "drill.as400_desc", Type.AS400_NAV)
	_add_card(cards_hbox, "drill.seq_title", "drill.seq_desc", Type.SEQUENCING)
	_add_card(cards_hbox, "drill.paper_title", "drill.paper_desc", Type.PAPERWORK)

	# Back button
	var back_btn: Button = Button.new()
	back_btn.text = Locale.t("drill.back")
	back_btn.custom_minimum_size = Vector2(160, 40)
	UIStyles.apply_btn_ghost(back_btn, Color(0.1, 0.1, 0.1, 0.0),
			UITokens.CLR_CELL_TEXT_DIM, Color(0.55, 0.57, 0.6))
	back_btn.add_theme_font_size_override("font_size", UITokens.fs(13))
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(func() -> void: _sel_overlay.visible = false)
	main_vbox.add_child(back_btn)


func _add_card(parent: HBoxContainer, title_key: String, desc_key: String,
		drill_type: int) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 240)
	UIStyles.apply_panel(card, UIStyles.modal(UITokens.CLR_MODAL_BG, 10, 40, 0.8))
	parent.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_l: Label = Label.new()
	title_l.text = Locale.t(title_key)
	title_l.add_theme_font_size_override("font_size", UITokens.fs(16))
	title_l.add_theme_color_override("font_color", Color(0.9, 0.91, 0.93))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_l)

	var desc_l: Label = Label.new()
	desc_l.text = Locale.t(desc_key)
	desc_l.add_theme_font_size_override("font_size", UITokens.fs(12))
	desc_l.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_l)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var start_btn: Button = Button.new()
	start_btn.text = Locale.t("drill.start")
	start_btn.custom_minimum_size = Vector2(0, 40)
	UIStyles.apply_btn_primary(start_btn)
	start_btn.add_theme_font_size_override("font_size", UITokens.fs(14))
	start_btn.pressed.connect(func() -> void: _begin(drill_type))
	vbox.add_child(start_btn)


# ==========================================
# DRILL LIFECYCLE
# ==========================================

func _begin(drill_type: int) -> void:
	_type = drill_type
	is_active = true
	_elapsed = 0.0
	_completed = false
	_raq_connected = false
	_paper_phase = 0

	# Always use Standard Loading as the base scenario — force dropdown
	# so execute_session_start() reads the correct index (not whatever the
	# user left selected on the portal)
	if _ui._portal.scenario_dropdown != null:
		_ui._portal.scenario_dropdown.select(1)

	_ui._fade.fade_transition(func() -> void:
		_sel_overlay.visible = false
		_ui._portal.overlay.visible = false
		_ui._flow.execute_session_start()
		_apply_overrides()
	)


func _apply_overrides() -> void:
	# Suppress interruptions during drills
	_ui._interruptions.reset()

	# Hide workspace switching tabs
	if _ui._tab_dock_btn != null: _ui._tab_dock_btn.visible = false
	if _ui._tab_office_btn != null: _ui._tab_office_btn.visible = false
	if _ui._btn_abandon != null: _ui._btn_abandon.visible = false

	# Show drill-specific training guide
	var guide: String = ""
	match _type:
		Type.AS400_NAV:
			guide = UITokens.BB_WARNING + "[b]SKILL DRILL — AS400 Navigation[/b]" + UITokens.BB_END
			guide += "  Sign on → 50 → 01 → 02 → 05 → F6 → Badge → Store code "
			guide += UITokens.BB_SUCCESS + "[b]" + _ui.current_dest_code + "[/b]" + UITokens.BB_END
			guide += " → Seal "
			guide += UITokens.BB_SUCCESS + "[b]" + _ui.seal_number_1 + "[/b]" + UITokens.BB_END
			guide += " → F10 → F13 (RAQ)"
			_setup_as400()
		Type.SEQUENCING:
			guide = UITokens.BB_WARNING + "[b]SKILL DRILL — Loading Sequence[/b]" + UITokens.BB_END
			guide += "  Open the dock → Start Loading → Load in order: "
			guide += "[color=#f1c40f]Service Center[/color] → [color=#2ecc71]Bikes[/color]"
			guide += " → [color=#e67e22]Bulky[/color] → [color=#3498db]Mecha[/color]"
			guide += " → [color=#ffffff]C&C[/color] last.  "
			guide += UITokens.BB_DIM + "F13 = check RAQ · Check Transit rack · Check yellow lockers (ADR)" + UITokens.BB_END
			_setup_sequencing()
		Type.PAPERWORK:
			guide = _paper_guide_phase1()
			_setup_paperwork()
	if guide != "":
		_ui._tut.show_drill_guide("🎯 " + guide)


func _setup_as400() -> void:
	_ui._ws.switch_workspace("DOCK")
	_ui._ws.set_panel_visible("AS400", true, true)

	# Force standby label hidden
	if _ui.lbl_standby != null: _ui.lbl_standby.visible = false

	# Hide all dock action buttons — trainee only navigates AS400
	_hide_dock_actions()
	# But keep AS400 toggle accessible so trainee can reopen if closed
	if _ui._dock_action_bar != null: _ui._dock_action_bar.visible = true
	if _ui.btn_as400_dock != null: _ui.btn_as400_dock.visible = true

	# Connect to RAQ signal for completion detection
	if _ui._as400 != null and not _raq_connected:
		_ui._as400.raq_opened.connect(_on_raq_reached)
		_raq_connected = true

	_elapsed = 0.0


func _setup_sequencing() -> void:
	_ui._ws.switch_workspace("DOCK")

	# Force standby label hidden — drills skip the intro phase
	if _ui.lbl_standby != null: _ui.lbl_standby.visible = false

	# Ensure dock panel is visible but dock stays CLOSED — trainee opens it
	if _ui._dock.panel != null: _ui._dock.panel.visible = true

	# Pre-stage AS400 to SCANNING state so pallets can be scanned
	if _ui._as400 != null:
		_ui._as400.state = AS400Terminal.S.SCANNING
		_ui._as400._render_as400_screen()

	# Show AS400 panel so trainee can see scanner and check RAQ
	_ui._ws.set_panel_visible("AS400", true, true)

	# Pre-call departments so C&C pallets are available
	if _ui._session != null:
		_ui._session.manual_decision("Call departments (C&C check)")
		# Clear emballages so Start Loading isn't blocked
		_ui._session.emballage_remaining = 0
		_ui._session.emballage_initial = 0

	# Force transit + ADR so the drill always tests the full workflow
	_force_drill_extras()

	# Rebuild dock floor after clearing emballages
	if _ui._session != null:
		_ui._dock.populate(
			_ui._session.inventory_available,
			_ui._session.inventory_loaded,
			_ui._session.capacity_used,
			_ui._session.capacity_max
		)

	# Auto-fill paperwork — sequencing drill tests loading, not forms
	_autofill_paperwork()

	# Keep Open Dock, Start Loading, and AS400 toggle visible
	# Force the action bar itself visible
	if _ui._dock_action_bar != null: _ui._dock_action_bar.visible = true
	if _ui.btn_open_dock != null: _ui.btn_open_dock.visible = true
	if _ui.btn_start_load != null: _ui.btn_start_load.visible = true
	if _ui.btn_as400_dock != null: _ui.btn_as400_dock.visible = true
	# Transit and ADR always present in drill (forced above)
	if _ui.btn_transit != null:
		_ui.btn_transit.visible = true
		_ui.btn_transit.disabled = false
	if _ui.btn_adr != null:
		_ui.btn_adr.visible = true
		_ui.btn_adr.disabled = false
	# Hide only irrelevant actions
	if _ui.btn_call != null: _ui.btn_call.visible = false
	if _ui.btn_seal != null: _ui.btn_seal.visible = false
	if _ui.btn_combine != null: _ui.btn_combine.visible = false
	if _ui.btn_close_dock != null: _ui.btn_close_dock.visible = false

	_elapsed = 0.0


func _force_drill_extras() -> void:
	## Guarantee transit rack and ADR yellow locker are present in sequencing
	## drills so the trainee always practises the full workflow.
	var sm: SessionManager = _ui._session
	if sm == null: return

	var drill_rng := RandomNumberGenerator.new()
	drill_rng.randomize()

	# Force transit — add one Mecha UAT on the transit rack
	if sm.transit_items.is_empty() and sm.transit_loose_entries.is_empty() and not sm.transit_collected:
		var t_pallet: Dictionary = {
			"id": "00900084" + str(drill_rng.randi_range(1000000, 9999999)),
			"colis_id": "8486" + str(drill_rng.randi_range(10000000, 99999999)),
			"type": "Mecha",
			"pallet_base": "plastic",
			"code": "MAP",
			"promise": "D",
			"p_val": 0,
			"collis": drill_rng.randi_range(1, 2),
			"cap": 0.5,
			"is_uat": true,
			"missing": false,
			"dest": 1,
			"subtype": "",
			"weight_kg": float(drill_rng.randi_range(90, 180)),
			"dm3": drill_rng.randi_range(350, 700),
			"combined_uats": [] as Array,
			"combined_collis": 0,
			"delivery_date": "",
			"scan_time": "",
			"has_adr": false,
		}
		sm.transit_items = [t_pallet]

	# Force ADR — add one ADR pallet in the yellow locker
	if not sm.has_adr:
		sm.has_adr = true
		var a_pallet: Dictionary = {
			"id": "00900084" + str(drill_rng.randi_range(1000000, 9999999)),
			"colis_id": "8486" + str(drill_rng.randi_range(10000000, 99999999)),
			"type": "ADR",
			"pallet_base": "plastic",
			"code": "MAP",
			"promise": "D",
			"p_val": 0,
			"collis": drill_rng.randi_range(5, 12),
			"cap": 1.0,
			"is_uat": true,
			"missing": false,
			"dest": 1,
			"subtype": "",
			"weight_kg": float(drill_rng.randi_range(60, 140)),
			"dm3": drill_rng.randi_range(200, 500),
			"combined_uats": [] as Array,
			"combined_collis": 0,
			"delivery_date": "",
			"scan_time": "",
			"has_adr": false,
		}
		sm.adr_items = [a_pallet]


func _autofill_paperwork() -> void:
	## Pre-fill Loading Sheet and CMR with everything the operator would have
	## completed BEFORE loading starts.  Post-loading fields (weight, volume,
	## UATs, collis, pallet counts) are left empty — the trainee only sees
	## what a correctly-prepared CMR/LS looks like at load time.
	var sm: SessionManager = _ui._session
	if sm == null: return

	# --- Loading Sheet: pre-loading fields only ---
	sm.typed_store_code = sm.store_code
	sm.typed_seal = sm.seal_number
	sm.typed_dock = str(sm.dock_number)
	sm.typed_expedition_ls = sm.expedition_number_1
	sm.paperwork_ls_opened = true

	var ls_form: LoadingSheetForm = _ui._paper.ls
	if ls_form.ls_input_store != null: ls_form.ls_input_store.text = sm.store_code
	if ls_form.ls_input_seal != null: ls_form.ls_input_seal.text = sm.seal_number
	if ls_form.ls_input_dock != null: ls_form.ls_input_dock.text = str(sm.dock_number)
	if ls_form.ls_input_expedition != null: ls_form.ls_input_expedition.text = sm.expedition_number_1

	# --- CMR: pre-loading fields only (seal, dock, expedition) ---
	sm.typed_cmr_seal = sm.seal_number
	sm.typed_cmr_dock = str(sm.dock_number)
	sm.typed_expedition_cmr = sm.expedition_number_1
	sm.paperwork_cmr_opened = true

	var cmr_form: CMRForm = _ui._paper.cmr
	if cmr_form._input_seal != null: cmr_form._input_seal.text = sm.seal_number
	if cmr_form._input_dock != null: cmr_form._input_dock.text = str(sm.dock_number)
	if cmr_form._input_expedition != null: cmr_form._input_expedition.text = sm.expedition_number_1

	# --- CMR stamps, sign, X-mark, franco ---
	# Stamp top (sender stamp)
	cmr_form.stamp_top_stamped = true
	cmr_form._stamps_top[0] = true
	if cmr_form._stamp_top_btn != null: cmr_form._stamp_top_btn.visible = false
	if cmr_form._stamp_top_label != null: cmr_form._stamp_top_label.visible = true

	# Stamp & sign bottom
	cmr_form.stamp_bot_stamped = true
	cmr_form._stamps_bot[0] = true
	if cmr_form._stamp_bot_btn != null: cmr_form._stamp_bot_btn.visible = false
	if cmr_form._stamp_bot_label != null: cmr_form._stamp_bot_label.visible = true

	# X mark
	cmr_form.x_marked = true
	cmr_form._x_marks[0] = true
	if cmr_form._x_label != null: cmr_form._x_label.visible = true

	# Franco selection
	cmr_form.franco_selected = "franco"
	cmr_form._francos[0] = "franco"
	sm.cmr_franco_correct = true
	sm.cmr_franco_selected = true
	if cmr_form._franco_btn != null:
		cmr_form._franco_btn.text = "● Franco / Frei"
		cmr_form._franco_btn.button_pressed = true
	if cmr_form._non_franco_btn != null:
		cmr_form._non_franco_btn.text = "○ Non-Franco / Non-Frei"
		cmr_form._non_franco_btn.button_pressed = false

	# Reveal CMR tab so it appears accessible
	_ui._office.cmr_revealed = true
	if _ui._office.paperwork_tab_bar != null:
		_ui._office.paperwork_tab_bar.visible = true
		_ui._office.style_paperwork_tabs()


func _setup_paperwork() -> void:
	if _ui._session == null:
		return

	# --- Phase 1: Pre-load paperwork in PREP phase ---
	_paper_phase = 0

	# Pre-collect desk items so we skip straight to paperwork
	var office: OfficeManager = _ui._office
	office.desk_items_collected = {"cmr": true, "seal": true, "loading_sheet": true}
	office.desk_collected_count = 3
	for key: String in office.desk_checkmarks:
		if office.desk_checkmarks[key] != null:
			office.desk_checkmarks[key].visible = true
	for key: String in office.desk_item_btns:
		if office.desk_item_btns[key] != null:
			office.desk_item_btns[key].disabled = true

	# Switch to office at PREP phase (not WRAPUP)
	_ui._ws.switch_workspace("OFFICE")
	office.office_phase = "PREP"

	# Show docs row (paperwork), hide desk view
	if office.desk_view_container != null:
		office.desk_view_container.visible = false
	if office.docs_row != null:
		office.docs_row.visible = true

	# Show LS tab, CMR tab visible but LS active
	office.cmr_revealed = true
	office.active_paperwork_tab = "LS"
	if office.paperwork_tab_bar != null:
		office.paperwork_tab_bar.visible = true
	office.style_paperwork_tabs()
	if _ui.pnl_notes != null:
		_ui.pnl_notes.visible = true
	if _ui.pnl_loading_plan != null:
		_ui.pnl_loading_plan.visible = false
	_ui._paper.update_loading_sheet()
	_ui._paper.update_cmr()

	# Hide wrapup container — not part of this drill
	if office.wrapup_container != null:
		office.wrapup_container.visible = false

	# Hide dock workspace (office only for this drill)
	if _ui._dock_workspace != null:
		_ui._dock_workspace.visible = false

	# Show submit bar with "Continue →" text
	_set_submit_text(Locale.t("drill.paper_continue"))
	if _submit_bar != null:
		_submit_bar.visible = true

	_elapsed = 0.0


func _hide_dock_actions() -> void:
	if _ui.btn_start_load != null: _ui.btn_start_load.visible = false
	if _ui.btn_call != null: _ui.btn_call.visible = false
	if _ui.btn_seal != null: _ui.btn_seal.visible = false
	if _ui.btn_transit != null: _ui.btn_transit.visible = false
	if _ui.btn_adr != null: _ui.btn_adr.visible = false
	if _ui.btn_combine != null: _ui.btn_combine.visible = false
	if _ui.btn_open_dock != null: _ui.btn_open_dock.visible = false
	if _ui.btn_close_dock != null: _ui.btn_close_dock.visible = false
	if _ui._dock_action_bar != null: _ui._dock_action_bar.visible = false


func _advance_to_post_load() -> void:
	## Phase transition: pre-load → post-load.
	## Auto-loads all pallets, advances AS400, shows CMR post-load fields.
	_paper_phase = 1
	if _ui._session == null:
		return

	WOTSAudio.play_scan_beep(_ui)

	# Pre-stage AS400 to VALIDATION (F10 done — weight/dm3 available)
	if _ui._as400 != null:
		_ui._as400.state = AS400Terminal.S.VALIDATION
		_ui._as400._render_as400_screen()
	_ui._as400_confirmed = true

	# Pre-call departments so session data is complete
	_ui._session.manual_decision("Call departments (C&C check)")

	# Load all pallets in correct order
	var sorted: Array = _ui._session.inventory_available.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)
	for p: Dictionary in sorted:
		_ui._session.load_pallet_by_id(str(p.get("id", "")))

	# Switch to CMR tab for post-load fields
	_ui._office.active_paperwork_tab = "CMR"
	_ui._office.style_paperwork_tabs()
	if _ui.pnl_notes != null:
		_ui.pnl_notes.visible = false
	if _ui.pnl_loading_plan != null:
		_ui.pnl_loading_plan.visible = true
	_ui._paper.update_cmr()
	_ui._paper.update_loading_sheet()

	# Update banner to post-load instructions
	_ui._tut.show_drill_guide("🎯 " + _paper_guide_phase2())

	# Update submit button text
	_set_submit_text(Locale.t("drill.submit"))


func _paper_guide_phase1() -> String:
	var g: String = UITokens.BB_WARNING + "[b]SKILL DRILL — Paperwork[/b]" + UITokens.BB_END
	g += "  [b]Pre-load:[/b] Fill the Loading Sheet (store, seal, dock). "
	g += "Then fill the CMR pre-load (stamp & sign, Franco, seal, dock). "
	g += "Click [b]Continue[/b] when done."
	return g


func _paper_guide_phase2() -> String:
	var g: String = UITokens.BB_WARNING + "[b]SKILL DRILL — Paperwork[/b]" + UITokens.BB_END
	g += "  [b]Post-load:[/b] Fill the CMR pallet counts (UATs, collis, EUR, plastic, magnum, C&C). "
	g += "Enter expedition, weight, and volume (dm³). "
	g += "Click [b]Submit[/b] when done."
	return g


func _set_submit_text(text: String) -> void:
	if _submit_bar == null:
		return
	for child: Node in _submit_bar.get_children():
		if child is Button:
			(child as Button).text = text
			break


# ==========================================
# COMPLETION DETECTION
# ==========================================

func _on_raq_reached() -> void:
	if is_active and _type == Type.AS400_NAV and not _completed:
		_finish()


func _check_seq_complete() -> void:
	if _ui._session == null:
		return
	if _ui._session.loading_started and _ui._session.inventory_available.is_empty():
		_finish()


func on_submit_paperwork() -> void:
	if not is_active or _type != Type.PAPERWORK or _completed:
		return
	if _paper_phase == 0:
		_advance_to_post_load()
	else:
		_finish()


func _finish() -> void:
	_completed = true
	_ui._tut.hide_drill_guide()
	if _ui._session != null:
		_ui._session.is_active = false

	# Disconnect AS400 signal
	if _raq_connected and _ui._as400 != null:
		if _ui._as400.raq_opened.is_connected(_on_raq_reached):
			_ui._as400.raq_opened.disconnect(_on_raq_reached)
		_raq_connected = false

	# Hide submit bar
	if _submit_bar != null: _submit_bar.visible = false

	WOTSAudio.play_success_chime(_ui)
	var result: Dictionary = _grade()
	_show_result(result)


# ==========================================
# GRADING (delegated to DrillGrading)
# ==========================================

func _grade() -> Dictionary:
	match _type:
		Type.AS400_NAV:
			var scans: int = _ui._as400.wrong_store_scans if _ui._as400 != null else 0
			return DrillGrading.grade_as400(_elapsed, scans)
		Type.SEQUENCING:
			if _ui._session == null:
				return {"score": 0, "feedback": ""}
			return DrillGrading.grade_sequencing(_ui._session, _elapsed)
		Type.PAPERWORK:
			if _ui._session == null:
				return {"score": 0, "feedback": ""}
			return DrillGrading.grade_paperwork(_ui._session, _elapsed)
	return {"score": 0, "feedback": ""}


# ==========================================
# RESULT OVERLAY
# ==========================================

func _build_result(root: Control) -> void:
	_res_overlay = ColorRect.new()
	_res_overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	_res_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_res_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_res_overlay.visible = false
	root.add_child(_res_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_res_overlay.add_child(center)

	var pnl: PanelContainer = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(440, 360)
	UIStyles.apply_panel(pnl, UIStyles.modal(UITokens.CLR_MODAL_BG, 10, 40, 0.8))
	center.add_child(pnl)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	pnl.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var hdr: Label = Label.new()
	hdr.text = Locale.t("drill.complete")
	hdr.add_theme_font_size_override("font_size", UITokens.fs(20))
	hdr.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hdr)

	_res_score_lbl = Label.new()
	_res_score_lbl.add_theme_font_size_override("font_size", UITokens.fs(40))
	_res_score_lbl.add_theme_color_override("font_color", UITokens.CLR_TITLE_TEXT)
	_res_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_res_score_lbl)

	var div: ColorRect = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UITokens.CLR_PANEL_BORDER
	vbox.add_child(div)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_res_feedback = RichTextLabel.new()
	_res_feedback.bbcode_enabled = true
	_res_feedback.fit_content = true
	_res_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_res_feedback.add_theme_color_override("default_color", UITokens.CLR_TEXT_SECONDARY)
	_res_feedback.add_theme_font_size_override("normal_font_size", UITokens.fs(13))
	scroll.add_child(_res_feedback)

	var btn_ret: Button = Button.new()
	btn_ret.text = Locale.t("drill.return")
	btn_ret.custom_minimum_size = Vector2(0, 45)
	UIStyles.apply_btn_primary(btn_ret)
	btn_ret.add_theme_font_size_override("font_size", UITokens.fs(15))
	btn_ret.pressed.connect(func() -> void: _return_to_portal())
	vbox.add_child(btn_ret)


func _show_result(result: Dictionary) -> void:
	var score: int = int(result.get("score", 0))
	if _res_score_lbl != null:
		_res_score_lbl.text = str(score)
		var clr: Color = UITokens.CLR_SUCCESS if score >= 85 else (
				UITokens.CLR_AMBER if score >= 70 else UITokens.CLR_RED_DIM)
		_res_score_lbl.add_theme_color_override("font_color", clr)
	if _res_feedback != null:
		_res_feedback.text = str(result.get("feedback", ""))
	if _res_overlay != null:
		_res_overlay.visible = true


# ==========================================
# SUBMIT BAR (Paperwork Drill)
# ==========================================

func _build_submit_bar(root: Control) -> void:
	_submit_bar = HBoxContainer.new()
	_submit_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_submit_bar.offset_top = -60
	_submit_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_submit_bar.visible = false
	_submit_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_submit_bar)

	var btn: Button = Button.new()
	btn.text = Locale.t("drill.submit")
	btn.custom_minimum_size = Vector2(260, 50)
	UIStyles.apply_btn_primary(btn)
	btn.add_theme_font_size_override("font_size", UITokens.fs(16))
	btn.pressed.connect(func() -> void: on_submit_paperwork())
	_submit_bar.add_child(btn)


# ==========================================
# RETURN TO PORTAL
# ==========================================

func _return_to_portal() -> void:
	is_active = false
	_completed = false
	_elapsed = 0.0
	_paper_phase = 0
	_ui._tut.hide_drill_guide()

	if _res_overlay != null: _res_overlay.visible = false
	if _submit_bar != null: _submit_bar.visible = false

	# Restore workspace tabs
	if _ui._tab_dock_btn != null: _ui._tab_dock_btn.visible = true
	if _ui._tab_office_btn != null: _ui._tab_office_btn.visible = true

	_ui._fade.fade_transition(func() -> void:
		if _ui._session != null:
			_ui._session.is_active = false
		_ui._flow._return_to_portal()
		# Reset portal dropdown to actual unlock state (drill forced it to 1)
		_ui._flow.populate_scenarios()
	)
