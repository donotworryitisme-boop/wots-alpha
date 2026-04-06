class_name PortalScreen
extends RefCounted

# ==========================================
# PORTAL SCREEN — extracted from BayUI.gd
# Owns: portal overlay UI, language picker, scenario picker
# ==========================================

var _ui: BayUI  # BayUI reference

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
var btn_trainer: Button
var btn_quiz: Button
var btn_drill: Button
var btn_close: Button

# Briefing overlay
var briefing_overlay: ColorRect
var briefing_body: RichTextLabel
var btn_briefing_continue: Button

# Training history
var _history_rtl: RichTextLabel

# Trainee selector (Item 54)
var _trainee_input: LineEdit
var _lbl_trainee: Label

# Seed input
var seed_input: LineEdit

# Root node reference for rebuild
var _root: Node = null

func _init(ui: BayUI) -> void:
	_ui = ui


func rebuild() -> void:
	if _root == null:
		return
	if overlay != null and is_instance_valid(overlay):
		if overlay.get_parent() != null:
			overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
		overlay = null
	if briefing_overlay != null and is_instance_valid(briefing_overlay):
		if briefing_overlay.get_parent() != null:
			briefing_overlay.get_parent().remove_child(briefing_overlay)
		briefing_overlay.queue_free()
		briefing_overlay = null
	_build(_root)
	_build_briefing(_root)

func _build(root: Node) -> void:
	_root = root
	overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.08, 0.11, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(550, 780)
	UIStyles.apply_panel(pnl, UIStyles.modal())
	center.add_child(pnl)

	# Wrap everything in a scroll container so content is always reachable
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pnl.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 55)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 55)
	margin.add_theme_constant_override("margin_bottom", 25)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Decathlon wordmark
	var brand_lbl := Label.new()
	brand_lbl.text = "DECATHLON"
	brand_lbl.add_theme_font_size_override("font_size", UITokens.fs(14))
	brand_lbl.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	brand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(brand_lbl)

	var title := Label.new()
	title.text = "Bay B2B"
	title.add_theme_font_size_override("font_size", UITokens.fs(28))
	title.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TITLE_TEXT))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	lbl_sub = Label.new()
	lbl_sub.text = Locale.t("portal.subtitle")
	lbl_sub.add_theme_font_size_override("font_size", UITokens.fs(13))
	lbl_sub.add_theme_color_override("font_color", UITokens.hc_text(UITokens.COLOR_TEXT_META))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_sub)

	# --- Trainee selector (Item 54) ---
	var trainee_group := VBoxContainer.new()
	trainee_group.add_theme_constant_override("separation", 3)
	vbox.add_child(trainee_group)

	_lbl_trainee = Label.new()
	_lbl_trainee.text = Locale.t("portal.trainee")
	_lbl_trainee.add_theme_font_size_override("font_size", UITokens.fs(12))
	_lbl_trainee.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	_lbl_trainee.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	trainee_group.add_child(_lbl_trainee)

	_trainee_input = LineEdit.new()
	_trainee_input.text = TrainingRecord.get_trainee_display_name()
	_trainee_input.placeholder_text = Locale.t("portal.trainee_placeholder")
	_trainee_input.custom_minimum_size = Vector2(0, 34)
	_trainee_input.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_field_dark(_trainee_input)
	_trainee_input.text_submitted.connect(_on_trainee_submitted)
	_trainee_input.focus_exited.connect(_on_trainee_focus_lost)
	trainee_group.add_child(_trainee_input)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UITokens.hc_panel_border()
	vbox.add_child(div)

	# --- Language group ---
	var lang_group := VBoxContainer.new()
	lang_group.add_theme_constant_override("separation", 3)
	vbox.add_child(lang_group)

	lbl_lang = Label.new()
	lbl_lang.text = Locale.t("portal.select_language")
	lbl_lang.add_theme_font_size_override("font_size", UITokens.fs(12))
	lbl_lang.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	lbl_lang.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lang_group.add_child(lbl_lang)

	language_dropdown = OptionButton.new()
	language_dropdown.custom_minimum_size = Vector2(0, 36)
	for i: int in range(Locale.LANG_NAMES.size()):
		language_dropdown.add_item(Locale.LANG_NAMES[i])
	language_dropdown.select(Locale.current_lang)
	UIStyles.apply_dropdown(language_dropdown)
	var lang_popup := language_dropdown.get_popup()
	if lang_popup:
		UIStyles.apply_dropdown_popup(lang_popup)
	lang_group.add_child(language_dropdown)

	# --- Scenario group ---
	var scen_group := VBoxContainer.new()
	scen_group.add_theme_constant_override("separation", 3)
	vbox.add_child(scen_group)

	lbl_scen = Label.new()
	lbl_scen.text = Locale.t("portal.select_scenario")
	lbl_scen.add_theme_font_size_override("font_size", UITokens.fs(12))
	lbl_scen.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	lbl_scen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scen_group.add_child(lbl_scen)

	scenario_dropdown = OptionButton.new()
	scenario_dropdown.custom_minimum_size = Vector2(0, 40)
	UIStyles.apply_dropdown(scenario_dropdown)
	scenario_dropdown.add_theme_color_override("font_focus_color", Color(0.85, 0.87, 0.9))
	scenario_dropdown.add_theme_stylebox_override("focus",
			UIStyles.flat(UITokens.CLR_SURFACE_DEEP, 4, 1, UITokens.COLOR_ACCENT_BLUE))
	var dd_popup := scenario_dropdown.get_popup()
	if dd_popup:
		UIStyles.apply_dropdown_popup(dd_popup)
		dd_popup.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.45))
	scen_group.add_child(scenario_dropdown)

	scenario_desc = RichTextLabel.new()
	scenario_desc.bbcode_enabled = true
	scenario_desc.fit_content = true
	scenario_desc.custom_minimum_size = Vector2(0, 40)
	scenario_desc.add_theme_color_override("default_color", UITokens.hc_text(Color(0.5, 0.53, 0.57)))
	scenario_desc.add_theme_font_size_override("normal_font_size", UITokens.fs(12))
	scenario_desc.text = ""
	scen_group.add_child(scenario_desc)

	# --- Seed input (optional, for replay) ---
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	vbox.add_child(seed_row)
	var lbl_seed := Label.new()
	lbl_seed.text = Locale.t("portal.seed")
	lbl_seed.add_theme_font_size_override("font_size", UITokens.fs(11))
	lbl_seed.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))
	seed_row.add_child(lbl_seed)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = Locale.t("portal.seed_placeholder")
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.custom_minimum_size = Vector2(0, 26)
	seed_input.add_theme_font_size_override("font_size", UITokens.fs(11))
	UIStyles.apply_field_dark(seed_input)
	seed_row.add_child(seed_input)

	# --- Training history (compact, inline) ---
	_history_rtl = RichTextLabel.new()
	_history_rtl.bbcode_enabled = true
	_history_rtl.fit_content = true
	_history_rtl.custom_minimum_size = Vector2(0, 40)
	_history_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_rtl.add_theme_color_override("default_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	_history_rtl.add_theme_font_size_override("normal_font_size", UITokens.fs(11))
	vbox.add_child(_history_rtl)

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = UITokens.hc_panel_border()
	vbox.add_child(div2)

	var wh_lbl := Label.new()
	wh_lbl.text = "NLDKL01 · W146 · QUAI390"
	wh_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	wh_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))
	wh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wh_lbl)

	btn_start = Button.new()
	btn_start.text = Locale.t("portal.begin_shift")
	btn_start.custom_minimum_size = Vector2(0, 50)
	UIStyles.apply_btn_primary(btn_start)
	btn_start.add_theme_font_size_override("font_size", UITokens.fs(17))
	vbox.add_child(btn_start)

	# --- Utility buttons row: Quiz + Drill (prominent, side by side) ---
	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 6)
	util_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(util_row)

	btn_quiz = Button.new()
	btn_quiz.text = "📷 " + Locale.t("quiz.portal_btn")
	btn_quiz.custom_minimum_size = Vector2(0, 30)
	btn_quiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_btn_auto(btn_quiz, UITokens.CLR_BG_DARK,
			UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY), UITokens.CLR_MUTED, 6,
			1, UITokens.hc_panel_border())
	btn_quiz.add_theme_font_size_override("font_size", UITokens.fs(11))
	util_row.add_child(btn_quiz)

	btn_drill = Button.new()
	btn_drill.text = "🎯 " + Locale.t("drill.portal_btn")
	btn_drill.custom_minimum_size = Vector2(0, 30)
	btn_drill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_btn_auto(btn_drill, UITokens.CLR_BG_DARK,
			UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY), UITokens.CLR_MUTED, 6,
			1, UITokens.hc_panel_border())
	btn_drill.add_theme_font_size_override("font_size", UITokens.fs(11))
	util_row.add_child(btn_drill)

	# --- Second utility row: Trainer + Dev ---
	var util_row2 := HBoxContainer.new()
	util_row2.add_theme_constant_override("separation", 6)
	util_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(util_row2)

	btn_trainer = Button.new()
	btn_trainer.text = "📊 " + Locale.t("trainer.open_dashboard")
	btn_trainer.custom_minimum_size = Vector2(0, 28)
	btn_trainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_btn_ghost(btn_trainer, Color(0.1, 0.1, 0.1, 0.0),
			UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM), Color(0.55, 0.57, 0.6))
	btn_trainer.add_theme_font_size_override("font_size", UITokens.fs(11))
	util_row2.add_child(btn_trainer)

	btn_dev = Button.new()
	btn_dev.text = "🔧 " + Locale.t("portal.dev_unlock")
	btn_dev.custom_minimum_size = Vector2(0, 28)
	btn_dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyles.apply_btn_ghost(btn_dev, Color(0.1, 0.1, 0.1, 0.0),
			UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM), Color(0.55, 0.57, 0.6))
	btn_dev.add_theme_font_size_override("font_size", UITokens.fs(11))
	util_row2.add_child(btn_dev)

	# --- Settings row: HC toggle + Telemetry toggle ---
	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 16)
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(settings_row)

	# High contrast toggle
	var hc_grp := HBoxContainer.new()
	hc_grp.add_theme_constant_override("separation", 6)
	settings_row.add_child(hc_grp)

	var hc_lbl := Label.new()
	hc_lbl.text = Locale.t("portal.high_contrast")
	hc_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	hc_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))
	hc_grp.add_child(hc_lbl)

	var hc_btn := Button.new()
	hc_btn.custom_minimum_size = Vector2(40, 22)
	hc_btn.add_theme_font_size_override("font_size", UITokens.fs(9))
	hc_btn.focus_mode = Control.FOCUS_NONE
	var hc_on: bool = UITokens.high_contrast
	hc_btn.text = "ON" if hc_on else "OFF"
	var hc_bg: Color = UITokens.COLOR_ACCENT_BLUE if hc_on else UITokens.CLR_TOGGLE_OFF
	var hc_fc: Color = UITokens.CLR_WHITE if hc_on else UITokens.CLR_CELL_TEXT_DIM
	UIStyles.apply_btn_auto(hc_btn, hc_bg, hc_fc, UITokens.CLR_WHITE, 12)
	hc_btn.pressed.connect(func() -> void:
		UITokens.toggle_high_contrast()
		_ui.rebuild_portal()
	)
	hc_grp.add_child(hc_btn)

	# Telemetry opt-in toggle (Item 53)
	var telem_grp := HBoxContainer.new()
	telem_grp.add_theme_constant_override("separation", 6)
	settings_row.add_child(telem_grp)

	var telem_lbl := Label.new()
	telem_lbl.text = Locale.t("portal.telemetry")
	telem_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	telem_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))
	telem_grp.add_child(telem_lbl)

	var telem_btn := Button.new()
	telem_btn.custom_minimum_size = Vector2(40, 22)
	telem_btn.add_theme_font_size_override("font_size", UITokens.fs(9))
	telem_btn.focus_mode = Control.FOCUS_NONE
	var tel_on: bool = Telemetry.enabled
	telem_btn.text = "ON" if tel_on else "OFF"
	var tel_bg: Color = UITokens.COLOR_ACCENT_BLUE if tel_on else UITokens.CLR_TOGGLE_OFF
	var tel_fc: Color = UITokens.CLR_WHITE if tel_on else UITokens.CLR_CELL_TEXT_DIM
	UIStyles.apply_btn_auto(telem_btn, tel_bg, tel_fc, UITokens.CLR_WHITE, 12)
	telem_btn.pressed.connect(func() -> void:
		Telemetry.enabled = not Telemetry.enabled
		if Telemetry.enabled:
			Telemetry.load_data()
		UITokens.save_preferences()
		_ui.rebuild_portal()
	)
	telem_grp.add_child(telem_btn)

	# Close / Quit button — top right of overlay
	btn_close = Button.new()
	btn_close.text = "✕  " + Locale.t("btn.close_app")
	btn_close.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_btn_ghost(btn_close, Color(0.2, 0.08, 0.08, 0.6),
			Color(0.4, 0.4, 0.45), Color(0.8, 0.3, 0.3), 4)
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
		Locale.t("portal.scenario_4"),
	]
	for i: int in range(names.size()):
		var n: String = names[i]
		# Free Play (index 4) is always unlocked
		if i <= 3 and i > highest_unlocked:
			scenario_dropdown.add_item("🔒 " + n)
			scenario_dropdown.set_item_disabled(i, true)
		else:
			scenario_dropdown.add_item(n)
	if scenario_dropdown.item_count > 0:
		scenario_dropdown.select(highest_unlocked)
	refresh_history()

func update_scenario_desc(idx: int) -> void:
	if scenario_desc == null: return
	var desc_keys: Array[String] = [
		"portal.desc_0", "portal.desc_1", "portal.desc_2", "portal.desc_3", "portal.desc_4"
	]
	if idx >= 0 and idx < desc_keys.size():
		scenario_desc.text = Locale.t(desc_keys[idx])
	else:
		scenario_desc.text = ""


func _on_trainee_submitted(new_name: String) -> void:
	_apply_trainee(new_name)
	if _trainee_input != null:
		_trainee_input.release_focus()


func _on_trainee_focus_lost() -> void:
	if _trainee_input != null:
		_apply_trainee(_trainee_input.text)


func _apply_trainee(raw_name: String) -> void:
	var clean_name: String = raw_name.strip_edges()
	if clean_name == "":
		clean_name = "default"
	TrainingRecord.set_trainee(clean_name)
	UITokens.save_preferences()
	if _trainee_input != null:
		_trainee_input.text = TrainingRecord.get_trainee_display_name()
	refresh_history()


func refresh_language_labels() -> void:
	if lbl_sub != null: lbl_sub.text = Locale.t("portal.subtitle")
	if _lbl_trainee != null: _lbl_trainee.text = Locale.t("portal.trainee")
	if lbl_lang != null: lbl_lang.text = Locale.t("portal.select_language")
	if lbl_scen != null: lbl_scen.text = Locale.t("portal.select_scenario")
	if btn_start != null: btn_start.text = Locale.t("portal.begin_shift")
	if btn_dev != null: btn_dev.text = "🔧 " + Locale.t("portal.dev_unlock")
	if btn_trainer != null: btn_trainer.text = "📊 " + Locale.t("trainer.open_dashboard")
	if btn_quiz != null: btn_quiz.text = "📷 " + Locale.t("quiz.portal_btn")
	if btn_drill != null: btn_drill.text = "🎯 " + Locale.t("drill.portal_btn")
	if btn_close != null: btn_close.text = "✕  " + Locale.t("btn.close_app")
	if seed_input != null: seed_input.placeholder_text = Locale.t("portal.seed_placeholder")
	refresh_history()


func refresh_history() -> void:
	if _history_rtl == null:
		return
	var recent: Array[Dictionary] = TrainingRecord.get_recent(5)
	if recent.is_empty():
		_history_rtl.text = "[center]" + UITokens.BB_DIM + Locale.t("portal.no_history") + UITokens.BB_END + "[/center]"
		return

	var bb: String = ""

	# --- Recent Results ---
	bb += UITokens.BB_HINT + "[b]" + Locale.t("portal.recent_results") + "[/b]" + UITokens.BB_END + "\n"
	for r: Dictionary in recent:
		var scen: String = _short_scenario_name(str(r.get("scenario", "")))
		var score: int = int(r.get("score", 0))
		var passed: bool = bool(r.get("passed", false))
		var date_raw: String = str(r.get("date", ""))
		var date_short: String = _format_date_short(date_raw)

		var score_clr: String = UITokens.BB_SUCCESS if passed else (UITokens.BB_WARNING if score >= 70 else UITokens.BB_ERROR)
		var icon: String = "✓" if passed else "✗"
		var icon_clr: String = UITokens.BB_SUCCESS if passed else UITokens.BB_ERROR
		bb += icon_clr + icon + UITokens.BB_END + " "
		bb += score_clr + "[b]" + str(score) + "[/b]" + UITokens.BB_END + "  "
		bb += UITokens.BB_DIM + scen + UITokens.BB_END + "  "
		bb += UITokens.BB_DIM + date_short + UITokens.BB_END + "\n"

	# --- Personal Bests ---
	var bests: Dictionary = TrainingRecord.get_best_per_scenario()
	if not bests.is_empty():
		bb += "\n" + UITokens.BB_HINT + "[b]" + Locale.t("portal.best_scores") + "[/b]" + UITokens.BB_END + "\n"
		var scenario_keys: Array[String] = ["0. Tutorial", "1. Standard Loading", "2. Priority Loading", "3. Co-Loading"]
		for sk: String in scenario_keys:
			if bests.has(sk):
				var best_score: int = int(bests[sk].get("score", 0))
				var best_clr: String = UITokens.BB_SUCCESS if best_score >= 85 else (UITokens.BB_WARNING if best_score >= 70 else UITokens.BB_ERROR)
				bb += best_clr + "[b]" + str(best_score) + "[/b]" + UITokens.BB_END + "  "
				bb += UITokens.BB_DIM + _short_scenario_name(sk) + UITokens.BB_END + "\n"

	_history_rtl.text = bb


static func _short_scenario_name(full: String) -> String:
	if full.begins_with("0"): return "Tutorial"
	if full.begins_with("1"): return "Standard"
	if full.begins_with("2"): return "Priority"
	if full.begins_with("3"): return "Co-Load"
	if full.begins_with("4"): return "Free Play"
	return full


static func _format_date_short(iso: String) -> String:
	## Turns "2026-04-04T14:30:00" into "04 Apr 14:30"
	if iso.length() < 16:
		return iso
	var date_part: String = iso.substr(0, 10)
	var time_part: String = iso.substr(11, 5)
	var parts: PackedStringArray = date_part.split("-")
	if parts.size() < 3:
		return iso
	var months: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var m_idx: int = clampi(int(parts[1]) - 1, 0, 11)
	return parts[2] + " " + months[m_idx] + " " + time_part


# ==========================================
# BRIEFING OVERLAY
# ==========================================

func _build_briefing(root: Node) -> void:
	briefing_overlay = ColorRect.new()
	briefing_overlay.color = UITokens.CLR_OVERLAY_DARK
	briefing_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing_overlay.visible = false
	root.add_child(briefing_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing_overlay.add_child(center)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(620, 520)
	UIStyles.apply_panel(pnl, UIStyles.modal(UITokens.CLR_MODAL_BG, 10, 40, 0.6))
	center.add_child(pnl)

	var bmargin := MarginContainer.new()
	bmargin.add_theme_constant_override("margin_left", 40)
	bmargin.add_theme_constant_override("margin_top", 30)
	bmargin.add_theme_constant_override("margin_right", 40)
	bmargin.add_theme_constant_override("margin_bottom", 30)
	pnl.add_child(bmargin)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 16)
	bmargin.add_child(bvbox)

	# Header
	var hdr := Label.new()
	hdr.text = "SCENARIO BRIEFING"
	hdr.add_theme_font_size_override("font_size", UITokens.fs(12))
	hdr.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvbox.add_child(hdr)

	# Scrollable body
	var bscroll := ScrollContainer.new()
	bscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bvbox.add_child(bscroll)

	briefing_body = RichTextLabel.new()
	briefing_body.bbcode_enabled = true
	briefing_body.fit_content = true
	briefing_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	briefing_body.add_theme_color_override("default_color", UITokens.hc_text(UITokens.CLR_BORDER_LIGHT))
	briefing_body.add_theme_font_size_override("normal_font_size", UITokens.fs(14))
	bscroll.add_child(briefing_body)

	# Divider
	var bdiv := ColorRect.new()
	bdiv.custom_minimum_size = Vector2(0, 1)
	bdiv.color = UITokens.hc_panel_border()
	bvbox.add_child(bdiv)

	# Continue button
	btn_briefing_continue = Button.new()
	btn_briefing_continue.text = Locale.t("briefing.continue")
	btn_briefing_continue.custom_minimum_size = Vector2(0, 50)
	UIStyles.apply_btn_primary(btn_briefing_continue)
	btn_briefing_continue.add_theme_font_size_override("font_size", UITokens.fs(17))
	bvbox.add_child(btn_briefing_continue)


func show_briefing(scenario_index: int) -> void:
	if briefing_overlay == null: return
	var briefing_keys: Array[String] = [
		"briefing.scenario_0", "briefing.scenario_1",
		"briefing.scenario_2", "briefing.scenario_3",
		"briefing.scenario_4"
	]
	if scenario_index >= 0 and scenario_index < briefing_keys.size():
		briefing_body.text = Locale.t(briefing_keys[scenario_index])
	else:
		briefing_body.text = ""
	briefing_overlay.visible = true


func hide_briefing() -> void:
	if briefing_overlay != null:
		briefing_overlay.visible = false
