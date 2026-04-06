extends CanvasLayer

signal begin_pressed

# --- CONSTANTS ---
const BG_COLOR: Color = UITokens.CLR_CHARCOAL
const ACCENT_BLUE: Color = UITokens.COLOR_ACCENT_BLUE
const TEXT_WHITE: Color = Color(0.94, 0.95, 0.96, 1.0)
const TEXT_LIGHT: Color = UITokens.CLR_TEXT_SECONDARY
const TEXT_DIM: Color = UITokens.CLR_CELL_TEXT_DIM

# --- NODES ---
var _begin_btn: Button = null


func _ready() -> void:
	layer = 11
	_build_ui()


func _build_ui() -> void:
	# Full-screen background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root control
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# --- Title: WOTS ---
	var title_label := Label.new()
	title_label.text = "WOTS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UITokens.fs(72))
	title_label.add_theme_color_override("font_color", TEXT_WHITE)
	var bold_font := _load_font("res://ui/OpenSans-Bold.ttf")
	if bold_font != null:
		title_label.add_theme_font_override("font", bold_font)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	_add_spacer(vbox, 10)

	# --- Subtitle ---
	var subtitle_label := Label.new()
	subtitle_label.text = Locale.t("start.subtitle")
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", UITokens.fs(18))
	subtitle_label.add_theme_color_override("font_color", TEXT_LIGHT)
	var regular_font := _load_font("res://ui/OpenSans-Regular.ttf")
	if regular_font != null:
		subtitle_label.add_theme_font_override("font", regular_font)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subtitle_label)

	_add_spacer(vbox, 28)

	# --- Accent line ---
	var line_center := CenterContainer.new()
	line_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(line_center)

	var accent_line := ColorRect.new()
	accent_line.custom_minimum_size = Vector2(260, 2)
	accent_line.color = ACCENT_BLUE
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_center.add_child(accent_line)

	_add_spacer(vbox, 28)

	# --- Module label ---
	var module_label := Label.new()
	module_label.text = Locale.t("start.module")
	module_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	module_label.add_theme_font_size_override("font_size", UITokens.fs(15))
	module_label.add_theme_color_override("font_color", TEXT_DIM)
	if regular_font != null:
		module_label.add_theme_font_override("font", regular_font)
	module_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(module_label)

	_add_spacer(vbox, 48)

	# --- Begin button ---
	var btn_center := CenterContainer.new()
	btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_center)

	_begin_btn = Button.new()
	_begin_btn.text = Locale.t("start.begin")
	_begin_btn.custom_minimum_size = Vector2(220, 52)
	_begin_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_begin_button()
	_begin_btn.pressed.connect(_on_begin_pressed)
	btn_center.add_child(_begin_btn)

	_add_spacer(vbox, 64)

	# --- Version tag ---
	var version_label := Label.new()
	version_label.text = "Alpha"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", UITokens.fs(12))
	version_label.add_theme_color_override("font_color", TEXT_DIM)
	if regular_font != null:
		version_label.add_theme_font_override("font", regular_font)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(version_label)


func _style_begin_button() -> void:
	UIStyles.apply_btn_primary_bordered(_begin_btn)
	_begin_btn.add_theme_color_override("font_color", TEXT_WHITE)
	_begin_btn.add_theme_color_override("font_hover_color", TEXT_WHITE)
	_begin_btn.add_theme_font_size_override("font_size", UITokens.fs(18))

	var semibold_font := _load_font("res://ui/OpenSans-Semibold.ttf")
	if semibold_font != null:
		_begin_btn.add_theme_font_override("font", semibold_font)


func _add_spacer(parent: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null


func _on_begin_pressed() -> void:
	if _begin_btn != null:
		_begin_btn.disabled = true
	begin_pressed.emit()
