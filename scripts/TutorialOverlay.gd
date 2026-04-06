class_name TutorialOverlay
extends RefCounted

# ==========================================
# TUTORIAL OVERLAY — extracted from BayUI.gd
# Owns: tutorial canvas, label, highlight, dim overlay
# tutorial_active and tutorial_step remain in BayUI
# ==========================================

var _ui: BayUI  # BayUI reference

var canvas: CanvasLayer
var label: RichTextLabel
var dim_overlay: ColorRect
var highlight_box: ReferenceRect
var screen_margin: MarginContainer
var aligner: VBoxContainer
var _target_node: Control
var _skip_btn: Button

# Hint escalation
var _step_timer: float = 0.0
var _hint_level: int = 0  # 0=normal, 1=nudge(30s), 2=hint(60s), 3=skip(120s)
const NUDGE_TIME: float = 30.0
const HINT_TIME: float = 60.0
const SKIP_TIME: float = 120.0

# Drill guide mode — overrides tutorial step text
var _drill_active: bool = false
var _drill_text: String = ""

func _init(ui: BayUI) -> void:
	_ui = ui

func _build() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.visible = false
	_ui.add_child(canvas)

	dim_overlay = ColorRect.new()
	dim_overlay.visible = false
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(dim_overlay)

	highlight_box = ReferenceRect.new()
	highlight_box.border_color = UITokens.CLR_WARNING
	highlight_box.border_width = 4
	highlight_box.editor_only = false
	highlight_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(highlight_box)

	screen_margin = MarginContainer.new()
	screen_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	screen_margin.anchor_bottom = 0.0
	screen_margin.offset_top = 50
	screen_margin.offset_bottom = 50
	screen_margin.add_theme_constant_override("margin_left", 8)
	screen_margin.add_theme_constant_override("margin_right", 8)
	screen_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screen_margin)

	aligner = VBoxContainer.new()
	aligner.alignment = BoxContainer.ALIGNMENT_BEGIN
	aligner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_margin.add_child(aligner)

	var tut_panel := PanelContainer.new()
	tut_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIStyles.flat(Color(0.06, 0.08, 0.12, 0.92))
	sb.border_width_bottom = 3
	sb.border_color = UITokens.CLR_SUCCESS
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	tut_panel.add_theme_stylebox_override("panel", sb)
	aligner.add_child(tut_panel)

	var tut_margin := MarginContainer.new()
	tut_margin.add_theme_constant_override("margin_left", 16)
	tut_margin.add_theme_constant_override("margin_top", 10)
	tut_margin.add_theme_constant_override("margin_right", 16)
	tut_margin.add_theme_constant_override("margin_bottom", 10)
	tut_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_panel.add_child(tut_margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_margin.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "🎓"
	icon_lbl.add_theme_font_size_override("font_size", UITokens.fs(28))
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_lbl)

	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.fit_content = true
	label.custom_minimum_size = Vector2(0, 36)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	_skip_btn = Button.new()
	_skip_btn.text = Locale.t("tutorial.skip")
	_skip_btn.custom_minimum_size = Vector2(90, 30)
	_skip_btn.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn_auto(_skip_btn, Color(0.3, 0.15, 0.08),
			Color(0.9, 0.7, 0.4), Color.WHITE, 4)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.visible = false
	_skip_btn.pressed.connect(_on_skip_pressed)
	hbox.add_child(_skip_btn)

func set_focus(target: Control, _pos: String, _dim: bool) -> void:
	_target_node = target
	dim_overlay.visible = false

func update_ui() -> void:
	if _drill_active: return
	if not _ui.tutorial_active or label == null: return

	# Reset hint escalation on step change
	_step_timer = 0.0
	_hint_level = 0
	if _skip_btn != null: _skip_btn.visible = false

	_render_step_text()

	if _ui.tutorial_step > 24:
		canvas.visible = false


func _render_step_text() -> void:
	if _drill_active: return
	if label == null: return
	var t: String = "[font_size=17]"

	# Nudge indicator at 30s+
	if _hint_level >= 1:
		t += UITokens.BB_WARNING + "⏰ " + UITokens.BB_END
	t += UITokens.BB_SUCCESS + "[b]" + Locale.t("tutorial.header") + "[/b]" + UITokens.BB_END + "  "

	var step_key: String = "tutorial.step_%d" % _ui.tutorial_step
	t += Locale.t(step_key)

	# Detailed hint at 60s+
	if _hint_level >= 2:
		var hint_key: String = "tutorial.hint_%d" % _ui.tutorial_step
		var hint_text: String = Locale.t(hint_key)
		if hint_text == hint_key:
			hint_text = Locale.t("tutorial.hint_generic")
		t += "\n" + UITokens.BB_WARNING + "[b]💡 " + hint_text + "[/b]" + UITokens.BB_END

	match _ui.tutorial_step:
		0: set_focus(_ui._tab_office_btn, "bottom", true)
		1: set_focus(null, "top", false)
		2: set_focus(null, "top", false)
		3: set_focus(null, "top", false)
		4: set_focus(_ui.btn_open_dock, "top", true)
		5: set_focus(_ui.btn_as400_dock, "top", true)
		6: set_focus(_ui._as400._input_field, "top", true)
		7: set_focus(_ui._as400._input_field, "top", true)
		8: set_focus(_ui._as400._input_field, "top", true)
		9: set_focus(_ui.btn_call, "bottom", true)
		10: set_focus(_ui.btn_start_load, "bottom", true)
		11: set_focus(null, "top", false)
		12: set_focus(_ui._dock.truck_grid, "top", false)
		13: set_focus(null, "top", false)
		14: set_focus(null, "top", false)
		15: set_focus(_ui.btn_sop, "bottom", true)
		16: set_focus(_ui.btn_dock_cmr, "bottom", true)
		17: set_focus(_ui.btn_dock_cmr, "bottom", true)
		18: set_focus(_ui.btn_as400_dock, "top", true)
		19: set_focus(_ui.btn_dock_cmr, "bottom", true)
		20: set_focus(_ui.btn_close_dock, "bottom", true)
		21: set_focus(_ui._tab_office_btn, "bottom", true)
		_: set_focus(null, "top", false)

	t += "[/font_size]"
	label.text = t

func flash_warning(msg: String) -> void:
	if label == null: return
	if not _drill_active and not _ui.tutorial_active: return
	WOTSAudio.play_error_buzz(_ui)
	var t: String = "[font_size=17]" + UITokens.BB_ERROR + "[b]" + Locale.t("tutorial.incorrect") + "[/b]  "
	t += msg + UITokens.BB_END + "[/font_size]"
	label.text = t
	_ui.get_tree().create_timer(2.5).timeout.connect(_restore_text)


func reset_hint_timer() -> void:
	## Resets hint escalation without changing the step text.
	## Call when the user takes a meaningful action (e.g. loading a pallet)
	## so they don't get nudged while actively working.
	_step_timer = 0.0
	_hint_level = 0
	if _skip_btn != null:
		_skip_btn.visible = false


func tick(delta: float) -> void:
	if _drill_active: return
	if not _ui.tutorial_active:
		return
	_step_timer += delta
	var new_level: int = _hint_level
	if _step_timer >= SKIP_TIME:
		new_level = 3
	elif _step_timer >= HINT_TIME:
		new_level = 2
	elif _step_timer >= NUDGE_TIME:
		new_level = 1
	if new_level != _hint_level:
		_hint_level = new_level
		_render_step_text()
		if _hint_level >= 3 and _skip_btn != null:
			_skip_btn.visible = true


func _on_skip_pressed() -> void:
	if not _ui.tutorial_active: return
	_ui._tc.skip_current_step()


func show_drill_guide(bbcode: String) -> void:
	_drill_active = true
	_drill_text = "[font_size=17]" + bbcode + "[/font_size]"
	if canvas != null: canvas.visible = true
	if _skip_btn != null: _skip_btn.visible = false
	if dim_overlay != null: dim_overlay.visible = false
	if highlight_box != null: highlight_box.visible = false
	if label != null:
		label.text = _drill_text


func hide_drill_guide() -> void:
	_drill_active = false
	_drill_text = ""
	if canvas != null: canvas.visible = false


func _restore_text() -> void:
	if _drill_active:
		if label != null and _drill_text != "":
			label.text = _drill_text
	else:
		_render_step_text()
