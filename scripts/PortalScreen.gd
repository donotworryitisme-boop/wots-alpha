class_name PortalScreen
extends RefCounted

# ==========================================
# PORTAL SCREEN — extracted from BayUI.gd
# Owns: portal overlay UI, language picker, scenario picker
# ==========================================

var _ui: Node  # BayUI reference

# Portal UI nodes
var overlay: ColorRect
var scenario_dropdown: OptionButton
var scenario_desc: RichTextLabel
var language_dropdown: OptionButton
var lbl_scen: Label
var lbl_lang: Label
var lbl_sub: Label
var btn_start: Button
var btn_dev: Button
var btn_close: Button

func _init(ui: Node) -> void:
	_ui = ui

func _build(root: Node) -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.08, 0.11, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(550, 530)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.border_width_top = 3
	sb.border_color = Color(0.0, 0.51, 0.76)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 55)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 55)
	margin.add_theme_constant_override("margin_bottom", 35)
	pnl.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Decathlon wordmark
	var brand_lbl := Label.new()
	brand_lbl.text = "DECATHLON"
	brand_lbl.add_theme_font_size_override("font_size", 14)
	brand_lbl.add_theme_color_override("font_color", Color(0.0, 0.51, 0.76))
	brand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(brand_lbl)

	var title := Label.new()
	title.text = "Bay B2B"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	lbl_sub = Label.new()
	lbl_sub.text = Locale.t("portal.subtitle")
	lbl_sub.add_theme_font_size_override("font_size", 15)
	lbl_sub.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_sub)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.25, 0.27, 0.3)
	vbox.add_child(div)

	# --- Language group ---
	var lang_group := VBoxContainer.new()
	lang_group.add_theme_constant_override("separation", 4)
	vbox.add_child(lang_group)

	lbl_lang = Label.new()
	lbl_lang.text = Locale.t("portal.select_language")
	lbl_lang.add_theme_font_size_override("font_size", 14)
	lbl_lang.add_theme_color_override("font_color", Color(0.6, 0.63, 0.67))
	lbl_lang.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lang_group.add_child(lbl_lang)

	language_dropdown = OptionButton.new()
	language_dropdown.custom_minimum_size = Vector2(0, 40)
	for i: int in range(Locale.LANG_NAMES.size()):
		language_dropdown.add_item(Locale.LANG_NAMES[i])
	language_dropdown.select(Locale.current_lang)
	language_dropdown.focus_mode = Control.FOCUS_NONE
	var lang_dd_sb := StyleBoxFlat.new()
	lang_dd_sb.bg_color = Color(0.18, 0.19, 0.22)
	lang_dd_sb.corner_radius_top_left = 4; lang_dd_sb.corner_radius_top_right = 4
	lang_dd_sb.corner_radius_bottom_left = 4; lang_dd_sb.corner_radius_bottom_right = 4
	lang_dd_sb.border_width_left = 1; lang_dd_sb.border_width_top = 1
	lang_dd_sb.border_width_right = 1; lang_dd_sb.border_width_bottom = 1
	lang_dd_sb.border_color = Color(0.3, 0.32, 0.35)
	lang_dd_sb.content_margin_left = 12.0
	language_dropdown.add_theme_stylebox_override("normal", lang_dd_sb)
	var lang_dd_h := lang_dd_sb.duplicate()
	lang_dd_h.bg_color = Color(0.22, 0.24, 0.28)
	lang_dd_h.border_color = Color(0.0, 0.51, 0.76)
	language_dropdown.add_theme_stylebox_override("hover", lang_dd_h)
	var lang_dd_p := lang_dd_sb.duplicate()
	lang_dd_p.bg_color = Color(0.14, 0.15, 0.18)
	lang_dd_p.border_color = Color(0.0, 0.51, 0.76)
	language_dropdown.add_theme_stylebox_override("pressed", lang_dd_p)
	language_dropdown.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	language_dropdown.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	language_dropdown.add_theme_color_override("font_hover_color", Color.WHITE)
	language_dropdown.add_theme_color_override("font_pressed_color", Color(0.7, 0.73, 0.77))
	var lang_popup := language_dropdown.get_popup()
	if lang_popup:
		var lp_sb := StyleBoxFlat.new()
		lp_sb.bg_color = Color(0.14, 0.15, 0.18)
		lp_sb.border_width_left = 1; lp_sb.border_width_top = 1
		lp_sb.border_width_right = 1; lp_sb.border_width_bottom = 1
		lp_sb.border_color = Color(0.3, 0.32, 0.35)
		lp_sb.corner_radius_top_left = 4; lp_sb.corner_radius_top_right = 4
		lp_sb.corner_radius_bottom_left = 4; lp_sb.corner_radius_bottom_right = 4
		lang_popup.add_theme_stylebox_override("panel", lp_sb)
		var lp_hover := StyleBoxFlat.new()
		lp_hover.bg_color = Color(0.0, 0.35, 0.55)
		lang_popup.add_theme_stylebox_override("hover", lp_hover)
		lang_popup.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
		lang_popup.add_theme_color_override("font_hover_color", Color.WHITE)
		lang_popup.add_theme_color_override("font_selected_color", Color.WHITE)
	lang_group.add_child(language_dropdown)

	# --- Scenario group ---
	var scen_group := VBoxContainer.new()
	scen_group.add_theme_constant_override("separation", 4)
	vbox.add_child(scen_group)

	lbl_scen = Label.new()
	lbl_scen.text = Locale.t("portal.select_scenario")
	lbl_scen.add_theme_font_size_override("font_size", 14)
	lbl_scen.add_theme_color_override("font_color", Color(0.6, 0.63, 0.67))
	lbl_scen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scen_group.add_child(lbl_scen)

	scenario_dropdown = OptionButton.new()
	scenario_dropdown.custom_minimum_size = Vector2(0, 45)
	var dd_sb := StyleBoxFlat.new()
	dd_sb.bg_color = Color(0.18, 0.19, 0.22)
	dd_sb.corner_radius_top_left = 4; dd_sb.corner_radius_top_right = 4
	dd_sb.corner_radius_bottom_left = 4; dd_sb.corner_radius_bottom_right = 4
	dd_sb.border_width_left = 1; dd_sb.border_width_top = 1; dd_sb.border_width_right = 1; dd_sb.border_width_bottom = 1
	dd_sb.border_color = Color(0.3, 0.32, 0.35)
	dd_sb.content_margin_left = 12.0
	scenario_dropdown.add_theme_stylebox_override("normal", dd_sb)
	var dd_hover := dd_sb.duplicate()
	dd_hover.bg_color = Color(0.22, 0.24, 0.28)
	dd_hover.border_color = Color(0.0, 0.51, 0.76)
	scenario_dropdown.add_theme_stylebox_override("hover", dd_hover)
	var dd_pressed := dd_sb.duplicate()
	dd_pressed.bg_color = Color(0.14, 0.15, 0.18)
	dd_pressed.border_color = Color(0.0, 0.51, 0.76)
	scenario_dropdown.add_theme_stylebox_override("pressed", dd_pressed)
	var dd_focus := dd_sb.duplicate()
	dd_focus.border_color = Color(0.0, 0.51, 0.76)
	scenario_dropdown.add_theme_stylebox_override("focus", dd_focus)
	scenario_dropdown.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	scenario_dropdown.add_theme_color_override("font_hover_color", Color.WHITE)
	scenario_dropdown.add_theme_color_override("font_pressed_color", Color(0.7, 0.73, 0.77))
	scenario_dropdown.add_theme_color_override("font_focus_color", Color(0.85, 0.87, 0.9))
	var dd_popup := scenario_dropdown.get_popup()
	if dd_popup:
		var popup_sb := StyleBoxFlat.new()
		popup_sb.bg_color = Color(0.14, 0.15, 0.18)
		popup_sb.border_width_left = 1; popup_sb.border_width_top = 1; popup_sb.border_width_right = 1; popup_sb.border_width_bottom = 1
		popup_sb.border_color = Color(0.3, 0.32, 0.35)
		popup_sb.corner_radius_top_left = 4; popup_sb.corner_radius_top_right = 4
		popup_sb.corner_radius_bottom_left = 4; popup_sb.corner_radius_bottom_right = 4
		dd_popup.add_theme_stylebox_override("panel", popup_sb)
		var popup_hover_sb := StyleBoxFlat.new()
		popup_hover_sb.bg_color = Color(0.0, 0.35, 0.55)
		dd_popup.add_theme_stylebox_override("hover", popup_hover_sb)
		dd_popup.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
		dd_popup.add_theme_color_override("font_hover_color", Color.WHITE)
		dd_popup.add_theme_color_override("font_selected_color", Color.WHITE)
		dd_popup.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.45))
	scenario_dropdown.focus_mode = Control.FOCUS_NONE
	scen_group.add_child(scenario_dropdown)

	scenario_desc = RichTextLabel.new()
	scenario_desc.bbcode_enabled = true
	scenario_desc.fit_content = true
	scenario_desc.custom_minimum_size = Vector2(0, 50)
	scenario_desc.add_theme_color_override("default_color", Color(0.5, 0.53, 0.57))
	scenario_desc.add_theme_font_size_override("normal_font_size", 13)
	scenario_desc.text = ""
	scen_group.add_child(scenario_desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = Color(0.25, 0.27, 0.3)
	vbox.add_child(div2)

	var wh_lbl := Label.new()
	wh_lbl.text = "NLDKL01 · W146 · QUAI390"
	wh_lbl.add_theme_font_size_override("font_size", 11)
	wh_lbl.add_theme_color_override("font_color", Color(0.35, 0.37, 0.4))
	wh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wh_lbl)

	btn_start = Button.new()
	btn_start.text = Locale.t("portal.begin_shift")
	btn_start.custom_minimum_size = Vector2(0, 55)
	var start_sb_normal := StyleBoxFlat.new()
	start_sb_normal.bg_color = Color(0.0, 0.51, 0.76)
	start_sb_normal.corner_radius_top_left = 6; start_sb_normal.corner_radius_top_right = 6
	start_sb_normal.corner_radius_bottom_left = 6; start_sb_normal.corner_radius_bottom_right = 6
	var start_sb_hover := StyleBoxFlat.new()
	start_sb_hover.bg_color = Color(0.0, 0.60, 0.88)
	start_sb_hover.corner_radius_top_left = 6; start_sb_hover.corner_radius_top_right = 6
	start_sb_hover.corner_radius_bottom_left = 6; start_sb_hover.corner_radius_bottom_right = 6
	start_sb_hover.set_border_width_all(1)
	start_sb_hover.border_color = Color(0.0, 0.70, 1.0)
	var start_sb_pressed := StyleBoxFlat.new()
	start_sb_pressed.bg_color = Color(0.0, 0.38, 0.58)
	start_sb_pressed.corner_radius_top_left = 6; start_sb_pressed.corner_radius_top_right = 6
	start_sb_pressed.corner_radius_bottom_left = 6; start_sb_pressed.corner_radius_bottom_right = 6
	btn_start.add_theme_stylebox_override("normal", start_sb_normal)
	btn_start.add_theme_stylebox_override("hover", start_sb_hover)
	btn_start.add_theme_stylebox_override("pressed", start_sb_pressed)
	btn_start.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_start.add_theme_color_override("font_color", Color.WHITE)
	btn_start.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_start.add_theme_color_override("font_pressed_color", Color(0.85, 0.90, 0.95))
	btn_start.add_theme_font_size_override("font_size", 18)
	btn_start.focus_mode = Control.FOCUS_NONE
	vbox.add_child(btn_start)

	btn_dev = Button.new()
	btn_dev.text = "🔧 " + Locale.t("portal.dev_unlock")
	btn_dev.custom_minimum_size = Vector2(0, 32)
	btn_dev.focus_mode = Control.FOCUS_NONE
	var dev_sb := StyleBoxFlat.new()
	dev_sb.bg_color = Color(0.1, 0.1, 0.1, 0.0)
	btn_dev.add_theme_stylebox_override("normal", dev_sb)
	btn_dev.add_theme_stylebox_override("hover", dev_sb)
	btn_dev.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_dev.add_theme_color_override("font_color", Color(0.35, 0.37, 0.4))
	btn_dev.add_theme_color_override("font_hover_color", Color(0.55, 0.57, 0.6))
	btn_dev.add_theme_font_size_override("font_size", 11)
	vbox.add_child(btn_dev)

	# Close / Quit button — top right of overlay
	btn_close = Button.new()
	btn_close.text = "✕  " + Locale.t("btn.close_app")
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_font_size_override("font_size", 13)
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	btn_close.add_theme_stylebox_override("normal", close_sb)
	var close_h := StyleBoxFlat.new()
	close_h.bg_color = Color(0.2, 0.08, 0.08, 0.6)
	close_h.corner_radius_top_left = 4; close_h.corner_radius_top_right = 4
	close_h.corner_radius_bottom_left = 4; close_h.corner_radius_bottom_right = 4
	btn_close.add_theme_stylebox_override("hover", close_h)
	btn_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_close.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	btn_close.add_theme_color_override("font_hover_color", Color(0.8, 0.3, 0.3))
	btn_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_close.position = Vector2(-100, 16)
	btn_close.size = Vector2(90, 32)
	btn_close.pressed.connect(func() -> void: _ui.get_tree().quit())
	overlay.add_child(btn_close)

func populate_scenarios(highest_unlocked: int) -> void:
	if scenario_dropdown == null: return
	scenario_dropdown.clear()
	var names: Array[String] = [
		Locale.t("portal.scenario_0"),
		Locale.t("portal.scenario_1"),
		Locale.t("portal.scenario_2"),
		Locale.t("portal.scenario_3"),
	]
	for i: int in range(names.size()):
		var n: String = names[i]
		if i > highest_unlocked:
			scenario_dropdown.add_item("🔒 " + n)
			scenario_dropdown.set_item_disabled(i, true)
		else:
			scenario_dropdown.add_item(n)
	if scenario_dropdown.item_count > 0:
		scenario_dropdown.select(highest_unlocked)

func update_scenario_desc(idx: int) -> void:
	if scenario_desc == null: return
	var desc_keys: Array[String] = [
		"portal.desc_0", "portal.desc_1", "portal.desc_2", "portal.desc_3"
	]
	if idx >= 0 and idx < desc_keys.size():
		scenario_desc.text = Locale.t(desc_keys[idx])
	else:
		scenario_desc.text = ""

func refresh_language_labels() -> void:
	if lbl_sub != null: lbl_sub.text = Locale.t("portal.subtitle")
	if lbl_lang != null: lbl_lang.text = Locale.t("portal.select_language")
	if lbl_scen != null: lbl_scen.text = Locale.t("portal.select_scenario")
	if btn_start != null: btn_start.text = Locale.t("portal.begin_shift")
	if btn_dev != null: btn_dev.text = "🔧 " + Locale.t("portal.dev_unlock")
	if btn_close != null: btn_close.text = "✕  " + Locale.t("btn.close_app")
