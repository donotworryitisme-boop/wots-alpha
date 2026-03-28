extends CanvasLayer

signal accepted

const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

@onready var body: RichTextLabel = $Root/Center/Panel/Margin/VBox/BodyPanel/BodyMargin/Body
@onready var accept_button: Button = $Root/Center/Panel/Margin/VBox/ButtonCenter/AcceptButton

func _ready() -> void:
	layer = 10
	add_to_group("wots_trust_contract")

	if body != null:
		body.bbcode_enabled = true
		body.text = _build_contract_text()

	if accept_button == null:
		print("[TrustContract] ERROR: AcceptButton not found (scene mismatch).")
		return

	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Build proper button styles
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.0, 0.51, 0.76)
	normal_sb.set_corner_radius_all(6)
	normal_sb.set_border_width_all(2)
	normal_sb.border_color = Color(0.0, 0.41, 0.62)
	normal_sb.content_margin_left = 24.0
	normal_sb.content_margin_right = 24.0
	normal_sb.content_margin_top = 14.0
	normal_sb.content_margin_bottom = 14.0

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.0, 0.60, 0.88)
	hover_sb.set_corner_radius_all(6)
	hover_sb.set_border_width_all(2)
	hover_sb.border_color = Color(0.0, 0.70, 1.0)
	hover_sb.content_margin_left = 24.0
	hover_sb.content_margin_right = 24.0
	hover_sb.content_margin_top = 14.0
	hover_sb.content_margin_bottom = 14.0

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color(0.0, 0.38, 0.58)
	pressed_sb.set_corner_radius_all(6)
	pressed_sb.set_border_width_all(2)
	pressed_sb.border_color = Color(0.0, 0.30, 0.48)
	pressed_sb.content_margin_left = 24.0
	pressed_sb.content_margin_right = 24.0
	pressed_sb.content_margin_top = 14.0
	pressed_sb.content_margin_bottom = 14.0

	var focus_sb := StyleBoxEmpty.new()

	accept_button.add_theme_stylebox_override("normal", normal_sb)
	accept_button.add_theme_stylebox_override("hover", hover_sb)
	accept_button.add_theme_stylebox_override("pressed", pressed_sb)
	accept_button.add_theme_stylebox_override("focus", focus_sb)
	accept_button.add_theme_color_override("font_color", Color.WHITE)
	accept_button.add_theme_color_override("font_hover_color", Color.WHITE)
	accept_button.add_theme_color_override("font_pressed_color", Color(0.85, 0.90, 0.95))
	accept_button.add_theme_font_size_override("font_size", 20)

	if not accept_button.pressed.is_connected(_on_accept_pressed):
		accept_button.pressed.connect(_on_accept_pressed)

func _build_contract_text() -> String:
	return """[font_size=18][color=#0082c3][b]What this is[/b][/color][/font_size]

This is a training simulator. It recreates real loading scenarios so you can practice decisions — checking the RAQ, handling late arrivals, managing truck capacity — without consequences on the real dock.

[font_size=18][color=#0082c3][b]How it works[/b][/color][/font_size]

You will work through scenarios that get progressively harder. Each one introduces a new layer of the job: first the basics, then priority management, then co-loading. When you demonstrate the foundations, the next scenario unlocks. This is readiness, not a grade.

Mistakes are expected and designed into the training. The simulator shows you what happens downstream when a decision goes wrong — not to judge, but so you understand why the procedures exist.

[font_size=18][color=#0082c3][b]What stays private[/b][/color][/font_size]

Your individual learning runs are yours. Managers and team leads can see anonymised team-level readiness — which scenarios the team has completed and where common patterns appear — but never your personal session details, individual scores, or specific mistakes.

This system exists to make onboarding better, not to monitor performance.

Press [b]I Understand[/b] to start."""

func _on_accept_pressed() -> void:
	print("[TrustContract] Accepted")
	_write_trust_file()
	accepted.emit()
	queue_free()

func _write_trust_file() -> void:
	var f := FileAccess.open(TRUST_FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("seen=1\n")
	f.flush()
