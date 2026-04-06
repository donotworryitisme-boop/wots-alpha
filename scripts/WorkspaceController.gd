class_name WorkspaceController
extends RefCounted

## Manages workspace tabs (DOCK / OFFICE), panel state, overlay styling,
## and the dock paperwork overlay (LS / CMR floating panels on dock).

var _ui: BayUI

# --- Dock paperwork overlay ---
var _dock_paper_overlay: PanelContainer = null
var _dock_paper_title_lbl: Label = null
var _dock_paper_content_box: VBoxContainer = null
var _dock_paper_active: String = ""  # "" / "LS" / "CMR"


func _init(ui: BayUI) -> void:
	_ui = ui


# ==========================================
# WORKSPACE TABS
# ==========================================

func build_workspace_tabs() -> void:
	if _ui._top_bar_hbox == null: return
	var tab_container: HBoxContainer = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	_ui._top_bar_hbox.add_child(tab_container)
	_ui._top_bar_hbox.move_child(tab_container, 1)

	var tab_style: Callable = func(btn: Button, active: bool) -> void:
		var bg_c: Color = UITokens.CLR_BLUE_DEEP if active else UITokens.COLOR_TEXT_PRIMARY
		btn.add_theme_stylebox_override("normal", UIStyles.flat_m(bg_c, 14, 4, 14, 4, 6))
		btn.add_theme_stylebox_override("hover", UIStyles.flat_m(bg_c.lightened(0.12), 14, 4, 14, 4, 6))
		btn.add_theme_stylebox_override("pressed", UIStyles.flat_m(bg_c.lightened(0.12), 14, 4, 14, 4, 6))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", UITokens.CLR_WHITE if active else UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
		btn.add_theme_color_override("font_hover_color", UITokens.CLR_WHITE)

	_ui._tab_dock_btn = Button.new()
	_ui._tab_dock_btn.text = "  DOCK  "
	_ui._tab_dock_btn.tooltip_text = Locale.t("shortcut.dock")
	_ui._tab_dock_btn.add_theme_font_size_override("font_size", UITokens.fs(13))
	_ui._tab_dock_btn.focus_mode = Control.FOCUS_NONE
	_ui._tab_dock_btn.pressed.connect(func() -> void: switch_workspace("DOCK"))
	tab_container.add_child(_ui._tab_dock_btn)

	_ui._tab_office_btn = Button.new()
	_ui._tab_office_btn.text = "  OFFICE  "
	_ui._tab_office_btn.tooltip_text = Locale.t("shortcut.office")
	_ui._tab_office_btn.add_theme_font_size_override("font_size", UITokens.fs(13))
	_ui._tab_office_btn.focus_mode = Control.FOCUS_NONE
	_ui._tab_office_btn.pressed.connect(func() -> void: switch_workspace("OFFICE"))
	tab_container.add_child(_ui._tab_office_btn)

	tab_style.call(_ui._tab_dock_btn, false)
	tab_style.call(_ui._tab_office_btn, false)

	# Phone button in top bar
	_ui._phone_btn_top = Button.new()
	_ui._phone_btn_top.text = Locale.t("btn.phone")
	_ui._phone_btn_top.tooltip_text = Locale.t("shortcut.phone")
	_ui._phone_btn_top.add_theme_font_size_override("font_size", UITokens.fs(12))
	_ui._phone_btn_top.focus_mode = Control.FOCUS_NONE
	_ui._phone_btn_top.add_theme_stylebox_override("normal",
			UIStyles.flat_m(UITokens.COLOR_TEXT_PRIMARY, 10, 4, 10, 4, 6))
	_ui._phone_btn_top.add_theme_stylebox_override("hover",
			UIStyles.flat_m(UITokens.CLR_SURFACE_DEEP, 10, 4, 10, 4, 6))
	_ui._phone_btn_top.add_theme_stylebox_override("pressed",
			UIStyles.flat_m(UITokens.CLR_SURFACE_DEEP, 10, 4, 10, 4, 6))
	_ui._phone_btn_top.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_ui._phone_btn_top.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	_ui._phone_btn_top.add_theme_color_override("font_hover_color", UITokens.CLR_WHITE)
	_ui._phone_btn_top.pressed.connect(func() -> void: toggle_panel("Phone"))
	_ui._top_bar_hbox.add_child(_ui._phone_btn_top)


func switch_workspace(ws_name: String) -> void:
	if ws_name == _ui._active_workspace: return
	var is_initial: bool = (_ui._active_workspace == "")
	_ui._active_workspace = ws_name
	_style_workspace_tabs(ws_name)
	if not is_initial:
		WOTSAudio.play_panel_click(_ui)

	_apply_workspace(ws_name)

	if is_initial:
		return

	var incoming: Control = _ui._office_workspace if ws_name == "OFFICE" else _ui._dock_workspace
	if incoming == null: return

	if _ui._fade._xfade_tween != null and _ui._fade._xfade_tween.is_valid():
		_ui._fade._xfade_tween.kill()
	if _ui._fade._xfade_target != null and is_instance_valid(_ui._fade._xfade_target):
		_ui._fade._xfade_target.modulate.a = 1.0
		_ui._fade._xfade_target.position.x = 0.0
	_ui._fade._xfade_target = incoming

	var slide_from: float = FadeSystem.SLIDE_OFFSET if ws_name == "OFFICE" else -FadeSystem.SLIDE_OFFSET
	incoming.position.x = slide_from
	incoming.modulate.a = 0.0

	_ui._fade._xfade_tween = _ui.create_tween().set_parallel(true)
	_ui._fade._xfade_tween.tween_property(incoming, "position:x", 0.0, FadeSystem.SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ui._fade._xfade_tween.tween_property(incoming, "modulate:a", 1.0, FadeSystem.SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ui._fade._xfade_tween.chain().tween_callback(func() -> void:
		_ui._fade._xfade_target = null
	)


func _apply_workspace(ws_name: String) -> void:
	# Log workspace switch for ghost replay
	if _ui._session != null:
		_ui._session.log_action("workspace", ws_name)

	# Auto-close dock paperwork overlay when leaving dock
	if ws_name != "DOCK" and _dock_paper_active != "":
		hide_dock_paperwork()

	if _ui._dock_workspace != null:
		_ui._dock_workspace.visible = (ws_name == "DOCK")
	if _ui._office_workspace != null:
		_ui._office_workspace.visible = (ws_name == "OFFICE")
	if ws_name == "DOCK" and _ui._dock.panel != null:
		if _ui._tc.is_dock_hidden_at_start():
			_ui._dock.panel.visible = false
			_ui._panel_state["Dock View"] = false
			if _ui.lbl_standby != null:
				_ui.lbl_standby.visible = true
				_ui.lbl_standby.text = Locale.t("standby.tutorial")
		else:
			_ui._dock.panel.visible = true
			_ui._panel_state["Dock View"] = true
			if _ui.lbl_standby != null: _ui.lbl_standby.visible = false
	if _ui._dock_action_bar != null:
		if _ui._tc.is_dock_hidden_at_start():
			_ui._dock_action_bar.visible = false
		else:
			_ui._dock_action_bar.visible = (ws_name == "DOCK")
	if ws_name == "OFFICE":
		_ui._panel_state["Office"] = true
		_ui._panel_state["Loading Sheet"] = true
		_ui._panel_state["CMR"] = true
		_ui.panels_ever_opened["Office"] = true
		_ui.panels_ever_opened["Loading Sheet"] = true
		_ui.panels_ever_opened["CMR"] = true
		if _ui._session != null:
			if not _ui._session._shift_board_time_paid:
				_ui._session.manual_decision("Open Office")
			_ui._session.manual_decision("Open Loading Sheet")
			_ui._session.manual_decision("Open CMR")
		_ui._paper.update_loading_sheet()
		_ui._paper.update_cmr()
		_ui._office.refresh_office_phase_ui()
	_ui._tc.try_advance_workspace(ws_name)


func _style_workspace_tabs(ws_name: String) -> void:
	if _ui._tab_dock_btn == null or _ui._tab_office_btn == null: return
	var active_sb := UIStyles.flat_m(UITokens.CLR_BLUE_DEEP, 14, 4, 14, 4, 6)
	var inactive_sb := UIStyles.flat_m(UITokens.COLOR_TEXT_PRIMARY, 14, 4, 14, 4, 6)
	var inactive_text: Color = UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY)
	var dock_is_active: bool = (ws_name == "DOCK") and not _ui._tc.is_dock_hidden_at_start()
	var office_is_active: bool = (ws_name == "OFFICE")
	if dock_is_active:
		_ui._tab_dock_btn.add_theme_stylebox_override("normal", active_sb)
		_ui._tab_dock_btn.add_theme_color_override("font_color", UITokens.CLR_WHITE)
		_ui._tab_office_btn.add_theme_stylebox_override("normal", inactive_sb)
		_ui._tab_office_btn.add_theme_color_override("font_color", inactive_text)
	elif office_is_active:
		_ui._tab_office_btn.add_theme_stylebox_override("normal", active_sb)
		_ui._tab_office_btn.add_theme_color_override("font_color", UITokens.CLR_WHITE)
		_ui._tab_dock_btn.add_theme_stylebox_override("normal", inactive_sb)
		_ui._tab_dock_btn.add_theme_color_override("font_color", inactive_text)
	else:
		_ui._tab_dock_btn.add_theme_stylebox_override("normal", inactive_sb)
		_ui._tab_dock_btn.add_theme_color_override("font_color", inactive_text)
		_ui._tab_office_btn.add_theme_stylebox_override("normal", inactive_sb)
		_ui._tab_office_btn.add_theme_color_override("font_color", inactive_text)
	var active_h := UIStyles.flat_m(UITokens.CLR_BLUE_DEEP.lightened(0.12), 14, 4, 14, 4, 6)
	var inactive_h := UIStyles.flat_m(UITokens.COLOR_TEXT_PRIMARY.lightened(0.12), 14, 4, 14, 4, 6)
	_ui._tab_dock_btn.add_theme_stylebox_override("hover", active_h if dock_is_active else inactive_h)
	_ui._tab_office_btn.add_theme_stylebox_override("hover", active_h if office_is_active else inactive_h)
	_ui._tab_dock_btn.add_theme_stylebox_override("pressed", active_h if dock_is_active else inactive_h)
	_ui._tab_office_btn.add_theme_stylebox_override("pressed", active_h if office_is_active else inactive_h)


# ==========================================
# PANEL MANAGEMENT
# ==========================================

func init_panel_nodes_and_buttons(dock_view_button: Button) -> void:
	_ui._panel_nodes.clear()
	_ui._panel_nodes["Dock View"] = _ui._dock.panel
	_ui._panel_nodes["AS400"] = _ui.pnl_as400_stage
	_ui._panel_nodes["Office"] = _ui.pnl_shift_board
	_ui._panel_nodes["Trailer Capacity"] = _ui.pnl_trailer_capacity
	_ui._panel_nodes["Phone"] = _ui.pnl_phone
	_ui._panel_nodes["Loading Sheet"] = _ui.pnl_notes
	_ui._panel_nodes["CMR"] = _ui.pnl_loading_plan

	var ls_title: Label = _ui.pnl_notes.get_node_or_null("NotesMargin/NotesVBox/NotesTitle")
	if ls_title != null: ls_title.text = Locale.t("btn.loading_sheet")
	var cmr_title: Label = _ui.pnl_loading_plan.get_node_or_null("LoadingPlanMargin/LoadingPlanVBox/LoadingPlanTitle")
	if cmr_title != null: cmr_title.text = "CMR"
	var office_title: Label = _ui.pnl_shift_board.get_node_or_null("ShiftBoardMargin/ShiftBoardVBox/ShiftBoardTitle")
	if office_title != null: office_title.text = Locale.t("btn.office")

	if dock_view_button != null: dock_view_button.pressed.connect(func() -> void: toggle_panel("Dock View"))
	if _ui.btn_shift_board != null: _ui.btn_shift_board.pressed.connect(func() -> void: toggle_panel("Office"))
	if _ui.btn_as400 != null: _ui.btn_as400.pressed.connect(func() -> void: toggle_panel("AS400"))
	if _ui.btn_trailer_capacity != null: _ui.btn_trailer_capacity.pressed.connect(func() -> void: toggle_panel("Trailer Capacity"))
	if _ui.btn_phone != null: _ui.btn_phone.pressed.connect(func() -> void: toggle_panel("Phone"))
	if _ui.btn_notes != null: _ui.btn_notes.pressed.connect(func() -> void: toggle_panel("Loading Sheet"))
	if _ui.btn_loading_plan != null: _ui.btn_loading_plan.pressed.connect(func() -> void: toggle_panel("CMR"))


func reset_panel_state() -> void:
	_ui._panel_state.clear()
	_ui.panels_ever_opened.clear()
	for panel_name: String in BayUI.PANEL_NAMES: _ui._panel_state[panel_name] = false
	_dock_paper_active = ""
	if _dock_paper_overlay != null:
		_dock_paper_overlay.visible = false


func close_all_panels(silent: bool) -> void:
	if _dock_paper_active != "":
		hide_dock_paperwork()
	for panel_name: String in BayUI.PANEL_NAMES:
		if panel_name in ["Office", "Loading Sheet", "CMR"]:
			_ui._panel_state[panel_name] = false
			continue
		set_panel_visible(panel_name, false, silent)


func toggle_panel(panel_name: String) -> void:
	if panel_name in ["Office", "Loading Sheet", "CMR"]:
		# From the dock, show LS/CMR as floating overlay instead of switching
		if _ui._active_workspace == "DOCK" and panel_name in ["Loading Sheet", "CMR"]:
			if _ui.tutorial_active:
				var gate_warning: String = _ui._tc.check_panel_gate(panel_name)
				if gate_warning != "":
					_ui._tut.flash_warning(Locale.t(gate_warning))
					return
			var tab: String = "LS" if panel_name == "Loading Sheet" else "CMR"
			_toggle_dock_paperwork(tab)
			WOTSAudio.play_panel_click(_ui)
			return
		switch_workspace("OFFICE")
		set_panel_visible(panel_name, true, false)
		WOTSAudio.play_panel_click(_ui)
		return
	if panel_name == "Dock View":
		switch_workspace("DOCK")
		set_panel_visible(panel_name, true, false)
		WOTSAudio.play_panel_click(_ui)
		return
	if panel_name == "AS400":
		switch_workspace("DOCK")
	var is_open: bool = bool(_ui._panel_state.get(panel_name, false))

	# Tutorial gates
	if _ui.tutorial_active and not is_open:
		var gate_warning: String = _ui._tc.check_panel_gate(panel_name)
		if gate_warning != "":
			_ui._tut.flash_warning(Locale.t(gate_warning))
			return

	set_panel_visible(panel_name, not is_open, false)
	WOTSAudio.play_panel_click(_ui)


func set_panel_visible(panel_name: String, make_visible: bool, _silent: bool) -> void:
	_ui._panel_state[panel_name] = make_visible
	if make_visible: _ui.panels_ever_opened[panel_name] = true

	if panel_name not in ["Office", "Loading Sheet", "CMR"]:
		var node: Variant = _ui._panel_nodes.get(panel_name, null)
		if node != null: node.visible = make_visible

	if _ui.lbl_standby != null:
		var dock_panel_open: bool = false
		if bool(_ui._panel_state.get("Dock View", false)): dock_panel_open = true
		if bool(_ui._panel_state.get("AS400", false)): dock_panel_open = true
		_ui.lbl_standby.visible = not dock_panel_open

	if panel_name == "AS400" and make_visible and _ui._as400 != null:
		_ui._as400.grab_input_focus()
		if _ui._session != null and not _ui._session._as400_login_time_paid:
			_ui._session.manual_decision("Open AS400")
	if panel_name == "AS400" and not make_visible and _ui._as400 != null:
		_ui._as400.release_input_focus()

	if panel_name == "Office" and make_visible:
		if _ui._session != null and not _ui._session._shift_board_time_paid:
			_ui._session.manual_decision("Open Office")

	if panel_name == "Loading Sheet" and make_visible:
		if _ui._session != null: _ui._session.manual_decision("Open Loading Sheet")
	if panel_name == "CMR" and make_visible:
		if _ui._session != null: _ui._session.manual_decision("Open CMR")

	if panel_name == "Phone":
		if make_visible:
			_ui._phone.on_panel_opened()
		else:
			_ui._phone.update_badge(0)

	if _ui.tutorial_active:
		_ui._tc.try_advance_panel(panel_name, make_visible)


# ==========================================
# DOCK PAPERWORK OVERLAY
# ==========================================

func build_dock_paperwork_overlay() -> void:
	## Creates the floating overlay container for showing LS/CMR on the dock.
	## Called once from BayUI._build_operational_layout().
	if _ui._dock_workspace == null:
		return

	_dock_paper_overlay = PanelContainer.new()
	_dock_paper_overlay.visible = false
	# Position: left side of dock, full height minus action bar
	_dock_paper_overlay.anchor_left = 0.0
	_dock_paper_overlay.anchor_right = 0.0
	_dock_paper_overlay.anchor_top = 0.0
	_dock_paper_overlay.anchor_bottom = 1.0
	_dock_paper_overlay.offset_left = 6.0
	_dock_paper_overlay.offset_right = 440.0
	_dock_paper_overlay.offset_top = 4.0
	_dock_paper_overlay.offset_bottom = -50.0
	var overlay_sb: StyleBoxFlat = UIStyles.flat_m(
			Color(0.09, 0.1, 0.13, 0.97), 8, 6, 8, 6, 8, 2,
			UITokens.COLOR_ACCENT_BLUE)
	overlay_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	overlay_sb.shadow_size = 16
	UIStyles.apply_panel(_dock_paper_overlay, overlay_sb)
	_ui._dock_workspace.add_child(_dock_paper_overlay)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	_dock_paper_overlay.add_child(inner)

	# Header row
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	inner.add_child(header)

	_dock_paper_title_lbl = Label.new()
	_dock_paper_title_lbl.text = ""
	_dock_paper_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_paper_title_lbl.add_theme_font_size_override("font_size", UITokens.fs(14))
	_dock_paper_title_lbl.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	header.add_child(_dock_paper_title_lbl)

	var close_btn: Button = Button.new()
	close_btn.text = "  X  "
	close_btn.custom_minimum_size = Vector2(32, 26)
	close_btn.add_theme_font_size_override("font_size", UITokens.fs(12))
	close_btn.focus_mode = Control.FOCUS_NONE
	UIStyles.apply_btn(close_btn, Color(0.25, 0.1, 0.1), Color(0.4, 0.15, 0.1),
			Color(0.2, 0.08, 0.08), UITokens.CLR_TEXT_SECONDARY,
			Color(1.0, 0.4, 0.4), 4)
	close_btn.pressed.connect(func() -> void: hide_dock_paperwork())
	header.add_child(close_btn)

	# Divider line
	var divider: ColorRect = ColorRect.new()
	divider.color = UITokens.CLR_SURFACE_DIM
	divider.custom_minimum_size = Vector2(0, 1)
	inner.add_child(divider)

	# Content area — reparented panel goes here
	_dock_paper_content_box = VBoxContainer.new()
	_dock_paper_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock_paper_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_dock_paper_content_box)


func _toggle_dock_paperwork(tab: String) -> void:
	## Toggle dock paperwork overlay. Same tab → close. Different → swap.
	if _dock_paper_active == tab:
		hide_dock_paperwork()
		return
	if _dock_paper_active != "":
		_restore_panel_to_office()
	_show_dock_paperwork(tab)


func _show_dock_paperwork(tab: String) -> void:
	## Reparent the requested paperwork panel into the dock overlay.
	if _dock_paper_overlay == null or _dock_paper_content_box == null:
		return
	var panel: PanelContainer = _get_panel_for_tab(tab)
	if panel == null:
		return

	# Remove panel from its current parent (office paperwork_panels_ref)
	var old_parent: Node = panel.get_parent()
	if old_parent != null:
		old_parent.remove_child(panel)

	# Add to dock overlay content
	_dock_paper_content_box.add_child(panel)
	panel.visible = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_dock_paper_active = tab
	if _dock_paper_title_lbl != null:
		_dock_paper_title_lbl.text = Locale.t("btn.loading_sheet") if tab == "LS" else "CMR"
	_dock_paper_overlay.visible = true

	# Record panel opening for grading
	var pname: String = "Loading Sheet" if tab == "LS" else "CMR"
	_ui._panel_state[pname] = true
	_ui.panels_ever_opened[pname] = true
	if _ui._session != null:
		_ui._session.manual_decision("Open " + pname)
	if tab == "LS":
		_ui._paper.update_loading_sheet()
	else:
		_ui._paper.update_cmr()

	if _ui.tutorial_active:
		_ui._tc.try_advance_panel(pname, true)


func hide_dock_paperwork() -> void:
	## Close the dock paperwork overlay and restore panel to office.
	if _dock_paper_active == "":
		return
	_restore_panel_to_office()
	_dock_paper_active = ""
	if _dock_paper_overlay != null:
		_dock_paper_overlay.visible = false


func _restore_panel_to_office() -> void:
	## Move the currently shown panel back to its office parent.
	if _dock_paper_active == "" or _dock_paper_content_box == null:
		return
	var panel: PanelContainer = _get_panel_for_tab(_dock_paper_active)
	if panel == null:
		return

	var current_parent: Node = panel.get_parent()
	if current_parent != null:
		current_parent.remove_child(panel)

	var target: HBoxContainer = _ui._office.paperwork_panels_ref
	if target == null:
		return
	if _dock_paper_active == "LS":
		# LS always goes first (index 0)
		target.add_child(panel)
		target.move_child(panel, 0)
	else:
		# CMR goes after LS
		target.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Restore office visibility state
	_ui._office.refresh_office_phase_ui()


func is_dock_paperwork_open() -> bool:
	## Returns true when a paperwork panel is shown on the dock overlay.
	return _dock_paper_active != ""


func _get_panel_for_tab(tab: String) -> PanelContainer:
	## Returns the PanelContainer node for the given tab identifier.
	if tab == "LS":
		return _ui.pnl_notes
	if tab == "CMR":
		return _ui.pnl_loading_plan
	return null


# ==========================================
# OVERLAY STYLING & CONTENT
# ==========================================

func style_overlay_panels() -> void:
	var all_overlay_panels: Array = [_ui.pnl_shift_board, _ui.pnl_notes, _ui.pnl_loading_plan,
			_ui.pnl_phone, _ui.pnl_trailer_capacity]
	for p: Variant in all_overlay_panels:
		if p == null: continue
		UIStyles.apply_panel(p as PanelContainer,
				UIStyles.flat(UITokens.CLR_PANEL_BG, 8, 1, UITokens.CLR_SURFACE_DIM))
	for p: Variant in all_overlay_panels:
		if p == null: continue
		var margin: Node = p.get_child(0) if p.get_child_count() > 0 else null
		if margin == null: continue
		var vbox: Node = margin.get_child(0) if margin.get_child_count() > 0 else null
		if vbox == null: continue
		var title_lbl: Node = vbox.get_child(0) if vbox.get_child_count() > 0 else null
		if title_lbl and title_lbl is Label:
			title_lbl.add_theme_font_size_override("font_size", UITokens.fs(16))
			title_lbl.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
		var body_node: Node = vbox.get_child(1) if vbox.get_child_count() > 1 else null
		if body_node and body_node is RichTextLabel:
			body_node.add_theme_color_override("default_color", UITokens.CLR_BORDER_LIGHT)

	# Add close button to phone panel header
	if _ui.pnl_phone != null:
		var phone_margin: Node = _ui.pnl_phone.get_child(0) if _ui.pnl_phone.get_child_count() > 0 else null
		if phone_margin != null:
			var phone_vbox: Node = phone_margin.get_child(0) if phone_margin.get_child_count() > 0 else null
			if phone_vbox != null:
				var phone_title: Node = phone_vbox.get_child(0) if phone_vbox.get_child_count() > 0 else null
				if phone_title is Label:
					# Replace title label with an HBox containing title + close button
					var header_hbox: HBoxContainer = HBoxContainer.new()
					header_hbox.add_theme_constant_override("separation", 4)
					phone_vbox.add_child(header_hbox)
					phone_vbox.move_child(header_hbox, 0)
					phone_title.get_parent().remove_child(phone_title)
					phone_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					header_hbox.add_child(phone_title)
					var close_btn: Button = Button.new()
					close_btn.text = "  X  "
					close_btn.custom_minimum_size = Vector2(32, 26)
					close_btn.add_theme_font_size_override("font_size", UITokens.fs(12))
					close_btn.focus_mode = Control.FOCUS_NONE
					UIStyles.apply_btn(close_btn, Color(0.25, 0.1, 0.1), Color(0.4, 0.15, 0.1),
							Color(0.2, 0.08, 0.08), UITokens.CLR_TEXT_SECONDARY,
							Color(1.0, 0.4, 0.4), 4)
					close_btn.pressed.connect(func() -> void:
						set_panel_visible("Phone", false, false)
					)
					header_hbox.add_child(close_btn)


func populate_overlay_panels() -> void:
	_ui._lp_board.populate()
	_ui._office.build_office_seal_button()
	_ui._phone.update_content()
	_ui._paper.update_loading_sheet()
	_ui._paper.update_cmr()
