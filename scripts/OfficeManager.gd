class_name OfficeManager
extends RefCounted

## Desk collectibles, office phase flow (PREP / WRAPUP), paperwork tab bar,
## wrapup sequential buttons, and office seal button.  Lives inside BayUI as `_office`.

var _ui: BayUI  # BayUI reference

# --- Office phase state ---
var office_phase: String = "PREP"
var desk_view_container: VBoxContainer = null
var desk_items_collected: Dictionary = {"cmr": false, "seal": false, "loading_sheet": false}
var desk_collected_count: int = 0
var desk_item_btns: Dictionary = {}
var desk_checkmarks: Dictionary = {}
var docs_row: HBoxContainer = null
var office_vbox_ref: VBoxContainer = null

# --- Wrapup ---
var wrapup_container: VBoxContainer = null
var btn_hand_cmr: Button = null
var btn_archive: Button = null
var btn_seal_final: Button = null
var wrapup_step: int = 0

# --- Progressive reveal ---
var cmr_revealed: bool = false
var office_seal_btn: Button = null

# --- Paperwork tabs ---
var paperwork_tab_bar: HBoxContainer = null
var btn_tab_ls: Button = null
var btn_tab_cmr: Button = null
var active_paperwork_tab: String = "LS"
var paperwork_hint_label: Label = null
var paperwork_panels_ref: HBoxContainer = null


func _init(ui: BayUI) -> void:
	_ui = ui


# ==========================================
# BUILD OFFICE WORKSPACE (called from BayUI._build_operational_layout)
# ==========================================

func build_workspace(parent: VBoxContainer) -> Control:
	## Creates the office workspace Control and returns it.
	var workspace: Control = Control.new()
	workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.visible = false
	parent.add_child(workspace)

	var office_margin: MarginContainer = MarginContainer.new()
	office_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	office_margin.add_theme_constant_override("margin_left", 12)
	office_margin.add_theme_constant_override("margin_top", 8)
	office_margin.add_theme_constant_override("margin_right", 12)
	office_margin.add_theme_constant_override("margin_bottom", 8)
	workspace.add_child(office_margin)

	var office_vbox: VBoxContainer = VBoxContainer.new()
	office_vbox.add_theme_constant_override("separation", 8)
	office_margin.add_child(office_vbox)
	office_vbox_ref = office_vbox

	# Desk view (collectible items)
	_build_desk_view(office_vbox)

	# Three document panels side by side
	docs_row = HBoxContainer.new()
	docs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docs_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docs_row.add_theme_constant_override("separation", 8)
	docs_row.visible = false
	office_vbox.add_child(docs_row)

	# Reparent Shift Board into office workspace
	if _ui.pnl_shift_board != null:
		_ui.pnl_shift_board.get_parent().remove_child(_ui.pnl_shift_board)
		docs_row.add_child(_ui.pnl_shift_board)
		_ui.pnl_shift_board.visible = true
		_ui.pnl_shift_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ui.pnl_shift_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_ui.pnl_shift_board.size_flags_stretch_ratio = 1.6

	# Paperwork column: LS/CMR panels + tab bar at bottom
	var paperwork_col: VBoxContainer = VBoxContainer.new()
	paperwork_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paperwork_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paperwork_col.size_flags_stretch_ratio = 0.7
	paperwork_col.add_theme_constant_override("separation", 2)
	docs_row.add_child(paperwork_col)

	var paperwork_panels: HBoxContainer = HBoxContainer.new()
	paperwork_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paperwork_panels.add_theme_constant_override("separation", 8)
	paperwork_col.add_child(paperwork_panels)
	paperwork_panels_ref = paperwork_panels

	if _ui.pnl_notes != null:
		_ui.pnl_notes.get_parent().remove_child(_ui.pnl_notes)
		paperwork_panels.add_child(_ui.pnl_notes)
		_ui.pnl_notes.visible = true
		_ui.pnl_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ui.pnl_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if _ui.pnl_loading_plan != null:
		_ui.pnl_loading_plan.get_parent().remove_child(_ui.pnl_loading_plan)
		paperwork_panels.add_child(_ui.pnl_loading_plan)
		_ui.pnl_loading_plan.visible = true
		_ui.pnl_loading_plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ui.pnl_loading_plan.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Hint label
	paperwork_hint_label = Label.new()
	paperwork_hint_label.text = ""
	paperwork_hint_label.add_theme_font_size_override("font_size", UITokens.fs(11))
	paperwork_hint_label.add_theme_color_override("font_color", UITokens.CLR_AMBER)
	paperwork_hint_label.visible = false
	paperwork_col.add_child(paperwork_hint_label)

	# Tab bar at bottom
	paperwork_tab_bar = HBoxContainer.new()
	paperwork_tab_bar.add_theme_constant_override("separation", 4)
	paperwork_tab_bar.visible = false
	paperwork_col.add_child(paperwork_tab_bar)
	btn_tab_ls = Button.new()
	btn_tab_ls.text = "  Loading Sheet  "
	btn_tab_ls.add_theme_font_size_override("font_size", UITokens.fs(13))
	btn_tab_ls.pressed.connect(func() -> void: switch_paperwork_tab("LS"))
	paperwork_tab_bar.add_child(btn_tab_ls)
	btn_tab_cmr = Button.new()
	btn_tab_cmr.text = "  CMR  "
	btn_tab_cmr.add_theme_font_size_override("font_size", UITokens.fs(13))
	btn_tab_cmr.pressed.connect(func() -> void: switch_paperwork_tab("CMR"))
	paperwork_tab_bar.add_child(btn_tab_cmr)
	style_paperwork_tabs()

	# Hide phone + trailer capacity
	if _ui.pnl_phone != null:
		_ui.pnl_phone.visible = false
		_ui.pnl_phone.anchor_left = 1.0
		_ui.pnl_phone.anchor_right = 1.0
		_ui.pnl_phone.anchor_top = 0.0
		_ui.pnl_phone.anchor_bottom = 0.0
		_ui.pnl_phone.offset_left = -340.0
		_ui.pnl_phone.offset_right = -8.0
		_ui.pnl_phone.offset_top = 48.0
		_ui.pnl_phone.offset_bottom = 400.0
	if _ui.pnl_trailer_capacity != null: _ui.pnl_trailer_capacity.visible = false

	# Wrapup container
	_build_wrapup_bar(office_vbox)

	return workspace


# ==========================================
# DESK VIEW
# ==========================================

func _build_desk_view(parent: VBoxContainer) -> void:
	desk_view_container = VBoxContainer.new()
	desk_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_view_container.add_theme_constant_override("separation", 0)
	parent.add_child(desk_view_container)

	var desk_bg: PanelContainer = PanelContainer.new()
	desk_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_panel(desk_bg,
			UIStyles.flat_m(UITokens.CLR_PANEL_BG, 24, 20, 24, 20, 10, 1, Color(0.2, 0.22, 0.26)))
	desk_view_container.add_child(desk_bg)

	var desk_inner: VBoxContainer = VBoxContainer.new()
	desk_inner.add_theme_constant_override("separation", 24)
	desk_bg.add_child(desk_inner)

	var header_lbl: RichTextLabel = RichTextLabel.new()
	header_lbl.bbcode_enabled = true
	header_lbl.fit_content = true
	header_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_lbl.text = "[font_size=20]" + UITokens.BB_ACCENT + "[b]OFFICE — Bay B2B[/b]" + UITokens.BB_END + "[/font_size]\n[font_size=14]" + UITokens.BB_DIM + "Collect what you need from the desk before heading to the dock." + UITokens.BB_END + "[/font_size]"
	desk_inner.add_child(header_lbl)

	var items_row: HBoxContainer = HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 16)
	items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	desk_inner.add_child(items_row)

	_build_desk_item(items_row, "cmr", "CMR", "Transport document\nGoes with the driver", Color(0.15, 0.25, 0.4))
	_build_desk_item(items_row, "seal", "SEAL", "Physical seal\nLocks the truck doors", Color(0.35, 0.18, 0.08))
	_build_desk_item(items_row, "loading_sheet", "LOADING SHEET", "Counting document\nYour operational record", Color(0.12, 0.3, 0.15))

	var hint: Label = Label.new()
	hint.text = "Click each item to collect it"
	hint.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_MID))
	hint.add_theme_font_size_override("font_size", UITokens.fs(13))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desk_inner.add_child(hint)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_inner.add_child(spacer)


func _build_desk_item(parent: HBoxContainer, key: String, title: String, desc: String, accent: Color) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_panel(card,
			UIStyles.flat_m(UITokens.CLR_INPUT_BG, 16, 16, 16, 16, 8, 2, accent.darkened(0.3)))
	parent.add_child(card)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	card.add_child(inner)

	var icon_lbl: Label = Label.new()
	if key == "cmr": icon_lbl.text = "CMR"
	elif key == "seal": icon_lbl.text = "SEAL"
	else: icon_lbl.text = "LS"
	icon_lbl.add_theme_font_size_override("font_size", UITokens.fs(32))
	icon_lbl.add_theme_color_override("font_color", accent.lightened(0.4))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(icon_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", UITokens.fs(15))
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", UITokens.fs(12))
	desc_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_LABEL_DIM))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_lbl)

	var check_lbl: Label = Label.new()
	check_lbl.text = "COLLECTED"
	check_lbl.add_theme_font_size_override("font_size", UITokens.fs(13))
	check_lbl.add_theme_color_override("font_color", UITokens.CLR_SUCCESS)
	check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_lbl.visible = false
	inner.add_child(check_lbl)
	desk_checkmarks[key] = check_lbl

	var click_btn: Button = Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var k: String = key
	click_btn.pressed.connect(func() -> void: _collect_desk_item(k))
	var hov_bg: Color = accent.lightened(0.1)
	hov_bg.a = 0.08
	var hover_sb := UIStyles.flat(hov_bg, 8, 2, accent.lightened(0.2))
	click_btn.add_theme_stylebox_override("hover", hover_sb)
	click_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.add_child(click_btn)
	desk_item_btns[key] = click_btn


func _collect_desk_item(key: String) -> void:
	if desk_items_collected.get(key, false): return
	desk_items_collected[key] = true
	desk_collected_count += 1
	WOTSAudio.play_scan_beep(_ui)
	if desk_checkmarks.has(key):
		desk_checkmarks[key].visible = true
	if desk_item_btns.has(key):
		desk_item_btns[key].disabled = true
		desk_item_btns[key].mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _ui._session != null:
		if key == "cmr":
			_ui._session.manual_decision("Collect CMR")
		elif key == "seal":
			_ui._session.manual_decision("Collect Seal")
		elif key == "loading_sheet":
			_ui._session.manual_decision("Collect Loading Sheet")
	if _ui.tutorial_active and _ui.tutorial_step == 1 and desk_collected_count >= 3:
		_ui._tc.try_advance_desk(desk_collected_count)
	if desk_collected_count >= 3:
		_on_all_items_collected()


func _on_all_items_collected() -> void:
	_ui._fade.crossfade(office_vbox_ref, func() -> void:
		if desk_view_container != null: desk_view_container.visible = false
		if docs_row != null: docs_row.visible = true
		if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
		cmr_revealed = false
		active_paperwork_tab = "LS"
		if paperwork_tab_bar != null: paperwork_tab_bar.visible = false
		_ui._paper.update_loading_sheet()
		_ui._populate_overlay_panels()
		if _ui._paper.ls.ls_input_store != null:
			_ui._paper.ls.ls_input_store.call_deferred("grab_focus")
	)


func refresh_desk_view_visuals() -> void:
	for key: String in desk_checkmarks:
		if desk_checkmarks[key] != null and is_instance_valid(desk_checkmarks[key]):
			desk_checkmarks[key].visible = false
	for key: String in desk_item_btns:
		if desk_item_btns[key] != null and is_instance_valid(desk_item_btns[key]):
			desk_item_btns[key].disabled = false
			desk_item_btns[key].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# ==========================================
# OFFICE PHASE UI
# ==========================================

func refresh_office_phase_ui() -> void:
	if office_phase == "PREP":
		if desk_collected_count >= 3:
			if desk_view_container != null: desk_view_container.visible = false
			if docs_row != null: docs_row.visible = true
			if wrapup_container != null: wrapup_container.visible = false
			if _ui.pnl_shift_board != null: _ui.pnl_shift_board.visible = true
			if cmr_revealed:
				if paperwork_tab_bar != null: paperwork_tab_bar.visible = true
				if active_paperwork_tab == "LS":
					if _ui.pnl_notes != null: _ui.pnl_notes.visible = true
					if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
				else:
					if _ui.pnl_notes != null: _ui.pnl_notes.visible = false
					if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = true
			else:
				if paperwork_tab_bar != null: paperwork_tab_bar.visible = false
				if _ui.pnl_notes != null: _ui.pnl_notes.visible = true
				if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
		else:
			if desk_view_container != null: desk_view_container.visible = true
			if docs_row != null: docs_row.visible = false
			if wrapup_container != null: wrapup_container.visible = false
			if paperwork_tab_bar != null: paperwork_tab_bar.visible = false
	elif office_phase == "WRAPUP":
		if desk_view_container != null: desk_view_container.visible = false
		if docs_row != null: docs_row.visible = true
		# Show shift board like PREP phase
		if _ui.pnl_shift_board != null: _ui.pnl_shift_board.visible = true
		# Show paperwork tabs like PREP phase (LS/CMR toggle)
		if paperwork_tab_bar != null: paperwork_tab_bar.visible = true
		if paperwork_hint_label != null: paperwork_hint_label.visible = false
		# Show correct panel based on active tab
		if active_paperwork_tab == "LS":
			if _ui.pnl_notes != null: _ui.pnl_notes.visible = true
			if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
		else:
			if _ui.pnl_notes != null: _ui.pnl_notes.visible = false
			if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = true
		if wrapup_container != null:
			wrapup_container.visible = true
			_refresh_wrapup_buttons()


func set_office_phase_wrapup() -> void:
	office_phase = "WRAPUP"
	if _ui._active_workspace == "OFFICE":
		_ui._fade.crossfade(office_vbox_ref, func() -> void: refresh_office_phase_ui())


# ==========================================
# WRAPUP BAR
# ==========================================

func _build_wrapup_bar(parent: VBoxContainer) -> void:
	wrapup_container = VBoxContainer.new()
	wrapup_container.add_theme_constant_override("separation", 8)
	wrapup_container.visible = false
	parent.add_child(wrapup_container)

	var wrapup_row: HBoxContainer = HBoxContainer.new()
	wrapup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapup_row.add_theme_constant_override("separation", 12)
	wrapup_container.add_child(wrapup_row)

	var step_lbl: Label = Label.new()
	step_lbl.text = "WRAP-UP"
	step_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	step_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_MID))
	step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrapup_container.add_child(step_lbl)
	wrapup_container.move_child(step_lbl, 0)

	btn_hand_cmr = _make_wrapup_btn("Hand CMR to Driver", UITokens.CLR_BLUE_DEEP)
	btn_hand_cmr.pressed.connect(func() -> void: advance_wrapup("hand_cmr"))
	wrapup_row.add_child(btn_hand_cmr)

	btn_archive = _make_wrapup_btn("Archive Papers", Color(0.2, 0.25, 0.35))
	btn_archive.pressed.connect(func() -> void: advance_wrapup("archive"))
	btn_archive.disabled = true
	wrapup_row.add_child(btn_archive)

	btn_seal_final = _make_wrapup_btn("Seal Truck", Color(0.5, 0.15, 0.15))
	btn_seal_final.pressed.connect(func() -> void: advance_wrapup("seal"))
	btn_seal_final.disabled = true
	wrapup_row.add_child(btn_seal_final)


func _make_wrapup_btn(text: String, bg_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = "  " + text + "  "
	btn.custom_minimum_size = Vector2(180, 42)
	btn.add_theme_font_size_override("font_size", UITokens.fs(14))
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", UIStyles.flat(bg_color, 8))
	btn.add_theme_stylebox_override("hover", UIStyles.flat(bg_color.lightened(0.15), 8))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("disabled", UIStyles.flat(UITokens.COLOR_TEXT_PRIMARY, 8))
	btn.add_theme_color_override("font_disabled_color", UITokens.CLR_CELL_TEXT_DIM)
	return btn


func _refresh_wrapup_buttons() -> void:
	if btn_hand_cmr != null:
		btn_hand_cmr.disabled = (wrapup_step > 0)
		if wrapup_step > 0:
			btn_hand_cmr.text = "  Hand CMR to Driver  Done  "
	if btn_archive != null:
		btn_archive.disabled = (wrapup_step != 1)
		if wrapup_step > 1:
			btn_archive.text = "  Archive Papers  Done  "
	if btn_seal_final != null:
		btn_seal_final.disabled = (wrapup_step != 2)


func advance_wrapup(action: String) -> void:
	if action == "hand_cmr" and wrapup_step == 0:
		WOTSAudio.play_scan_beep(_ui)
		if _ui._session != null:
			_ui._session.manual_decision("Hand CMR to Driver")
		wrapup_step = 1
		if _ui.tutorial_active:
			_ui._tc.try_advance_wrapup("hand_cmr")
	elif action == "archive" and wrapup_step == 1:
		WOTSAudio.play_panel_click(_ui)
		if _ui._session != null:
			_ui._session.manual_decision("Archive Papers")
		wrapup_step = 2
		# Hide LS and CMR — papers are archived, no longer accessible
		if _ui.pnl_notes != null: _ui.pnl_notes.visible = false
		if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
		if paperwork_tab_bar != null: paperwork_tab_bar.visible = false
		if _ui.tutorial_active:
			_ui._tc.try_advance_wrapup("archive")
	elif action == "seal" and wrapup_step == 2:
		WOTSAudio.play_seal_confirm(_ui)
		# Hide the office seal button — seal is removed from desk
		if office_seal_btn != null:
			office_seal_btn.visible = false
		if _ui._session != null:
			_ui._session.manual_decision("Seal Truck")
		wrapup_step = 3
		_ui._on_decision_pressed("Seal Truck")
		return
	_refresh_wrapup_buttons()


# ==========================================
# PAPERWORK TABS
# ==========================================

func switch_paperwork_tab(tab: String) -> void:
	active_paperwork_tab = tab
	if paperwork_hint_label != null: paperwork_hint_label.visible = false
	# Tab styling + audio fire immediately for snappy feedback
	style_paperwork_tabs()
	WOTSAudio.play_panel_click(_ui)
	if tab == "CMR" and _ui._session != null:
		_ui._session.manual_decision("Open CMR")
	# Tutorial advances (immediate, not deferred through crossfade)
	if _ui.tutorial_active:
		_ui._tc.try_advance_paperwork_tab(tab)
	# Panel swap crossfades for smooth transition
	_ui._fade.crossfade(paperwork_panels_ref, func() -> void:
		if tab == "LS":
			if _ui.pnl_notes != null: _ui.pnl_notes.visible = true
			if _ui.pnl_loading_plan != null: _ui.pnl_loading_plan.visible = false
		else:
			if _ui.pnl_notes != null: _ui.pnl_notes.visible = false
			if _ui.pnl_loading_plan != null:
				_ui.pnl_loading_plan.visible = true
				_ui._paper.update_cmr()
	)


func style_paperwork_tabs() -> void:
	if btn_tab_ls == null or btn_tab_cmr == null: return
	var active_sb := UIStyles.flat_m(Color(0.0, 0.45, 0.7), 12, 6, 12, 6, 4)
	active_sb.border_color = Color(0.3, 0.7, 1.0)
	active_sb.border_width_bottom = 3
	var inactive_sb := UIStyles.flat_m(Color(0.35, 0.35, 0.42), 12, 6, 12, 6, 4)
	var hover_sb := UIStyles.flat_m(Color(0.42, 0.42, 0.52), 12, 6, 12, 6, 4)
	if active_paperwork_tab == "LS":
		btn_tab_ls.add_theme_stylebox_override("normal", active_sb)
		btn_tab_ls.add_theme_stylebox_override("hover", active_sb)
		btn_tab_ls.add_theme_color_override("font_color", UITokens.CLR_WHITE)
		btn_tab_cmr.add_theme_stylebox_override("normal", inactive_sb)
		btn_tab_cmr.add_theme_stylebox_override("hover", hover_sb)
		btn_tab_cmr.add_theme_color_override("font_color", UITokens.CLR_LIGHT_GRAY)
	else:
		btn_tab_cmr.add_theme_stylebox_override("normal", active_sb)
		btn_tab_cmr.add_theme_stylebox_override("hover", active_sb)
		btn_tab_cmr.add_theme_color_override("font_color", UITokens.CLR_WHITE)
		btn_tab_ls.add_theme_stylebox_override("normal", inactive_sb)
		btn_tab_ls.add_theme_stylebox_override("hover", hover_sb)
		btn_tab_ls.add_theme_color_override("font_color", UITokens.CLR_LIGHT_GRAY)


# ==========================================
# OFFICE SEAL BUTTON
# ==========================================

func build_office_seal_button() -> void:
	if office_seal_btn != null and is_instance_valid(office_seal_btn): return
	var margin_node: Node = _ui.pnl_shift_board.get_child(0) if _ui.pnl_shift_board.get_child_count() > 0 else null
	if margin_node == null: return
	var vbox_node: Node = margin_node.get_child(0) if margin_node.get_child_count() > 0 else null
	if vbox_node == null: return

	var seal_margin: MarginContainer = MarginContainer.new()
	seal_margin.add_theme_constant_override("margin_top", 12)
	vbox_node.add_child(seal_margin)

	office_seal_btn = Button.new()
	office_seal_btn.text = Locale.t("btn.seal_truck")
	office_seal_btn.custom_minimum_size = Vector2(0, 44)
	office_seal_btn.focus_mode = Control.FOCUS_NONE
	office_seal_btn.add_theme_stylebox_override("normal",
			UIStyles.flat(UITokens.CLR_RED_DIM, 4))
	office_seal_btn.add_theme_stylebox_override("hover",
			UIStyles.flat(Color(0.9, 0.25, 0.25), 4))
	office_seal_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	office_seal_btn.add_theme_color_override("font_color", Color.WHITE)
	office_seal_btn.add_theme_font_size_override("font_size", UITokens.fs(16))
	office_seal_btn.pressed.connect(func() -> void: _ui._on_decision_pressed("Seal Truck"))
	seal_margin.add_child(office_seal_btn)


# ==========================================
# SESSION RESET HELPERS
# ==========================================

func reset_for_new_session() -> void:
	office_phase = "PREP"
	desk_items_collected = {"cmr": false, "seal": false, "loading_sheet": false}
	desk_collected_count = 0
	wrapup_step = 0
	cmr_revealed = false
	active_paperwork_tab = "LS"
	if paperwork_tab_bar != null: paperwork_tab_bar.visible = false
	refresh_desk_view_visuals()
	if docs_row != null: docs_row.visible = false
	if wrapup_container != null: wrapup_container.visible = false
	if desk_view_container != null: desk_view_container.visible = true
