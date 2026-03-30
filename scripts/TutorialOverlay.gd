class_name TutorialOverlay
extends RefCounted

# ==========================================
# TUTORIAL OVERLAY — extracted from BayUI.gd
# Owns: tutorial canvas, label, highlight, dim overlay
# tutorial_active and tutorial_step remain in BayUI
# ==========================================

var _ui: Node  # BayUI reference

var canvas: CanvasLayer
var label: RichTextLabel
var dim_overlay: ColorRect
var highlight_box: ReferenceRect
var screen_margin: MarginContainer
var aligner: VBoxContainer
var _target_node: Control

func _init(ui: Node) -> void:
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
	highlight_box.border_color = Color(1.0, 0.8, 0.1)
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
	screen_margin.add_theme_constant_override("margin_right", 200)
	screen_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screen_margin)

	aligner = VBoxContainer.new()
	aligner.alignment = BoxContainer.ALIGNMENT_BEGIN
	aligner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_margin.add_child(aligner)

	var tut_panel := PanelContainer.new()
	tut_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 3
	sb.border_color = Color(0.18, 0.8, 0.44)
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
	icon_lbl.add_theme_font_size_override("font_size", 28)
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

func set_focus(target: Control, _pos: String, _dim: bool) -> void:
	_target_node = target
	dim_overlay.visible = false

func update_ui() -> void:
	if not _ui.tutorial_active or label == null: return

	var t: String = "[font_size=17][color=#2ecc71][b]" + Locale.t("tutorial.header") + "[/b][/color]  "
	var step_key: String = "tutorial.step_%d" % _ui.tutorial_step
	t += Locale.t(step_key)

	match _ui.tutorial_step:
		0: set_focus(_ui.btn_as400, "top", true)
		1: set_focus(_ui._as400._input_field, "top", true)
		2: set_focus(_ui._as400._input_field, "top", true)
		3: set_focus(_ui._as400._input_field, "top", true)
		4: set_focus(_ui.btn_dock_view, "top", true)
		5: set_focus(_ui.btn_as400, "top", true)
		6: set_focus(_ui.btn_call, "bottom", true)
		7: set_focus(_ui.btn_start_load, "bottom", true)
		8: set_focus(null, "top", false)
		9: set_focus(_ui._dock.truck_grid, "top", false)
		10: set_focus(null, "top", false)
		11: set_focus(null, "top", false)
		12: set_focus(_ui.btn_sop, "bottom", true)
		13: set_focus(null, "top", false)
		14: set_focus(_ui.btn_as400, "top", false)
		15: set_focus(_ui.btn_seal, "bottom", true)

	t += "[/font_size]"
	label.text = t

	if _ui.tutorial_step > 15:
		canvas.visible = false

func flash_warning(msg: String) -> void:
	if not _ui.tutorial_active or label == null: return
	WOTSAudio.play_error_buzz(_ui)
	var t: String = "[font_size=17][color=#e74c3c][b]" + Locale.t("tutorial.incorrect") + "[/b]  "
	t += msg + "[/color][/font_size]"
	label.text = t
	_ui.get_tree().create_timer(2.5).timeout.connect(update_ui)
