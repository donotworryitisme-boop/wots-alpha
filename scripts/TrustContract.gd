extends CanvasLayer

signal accepted

const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

@onready var body: RichTextLabel = $Root/Center/Panel/Margin/VBox/BodyPanel/BodyMargin/Body
@onready var accept_button: Button = $Root/Center/Panel/Margin/VBox/ButtonCenter/AcceptButton

func _ready() -> void:
	layer = 10
	add_to_group("wots_trust_contract")

	# --- Dark theme (matching portal) ---
	var panel_node: PanelContainer = $Root/Center/Panel
	if panel_node != null:
		var p_sb := UIStyles.modal(Color(0.12, 0.13, 0.16), 12, 8, 0.4)
		p_sb.content_margin_left = 0.0
		p_sb.content_margin_right = 0.0
		p_sb.content_margin_top = 0.0
		p_sb.content_margin_bottom = 0.0
		UIStyles.apply_panel(panel_node, p_sb)
	var body_panel: PanelContainer = $Root/Center/Panel/Margin/VBox/BodyPanel
	if body_panel != null:
		UIStyles.apply_panel(body_panel, UIStyles.flat(Color(0.09, 0.1, 0.12), 8))
	var title_label: Label = $Root/Center/Panel/Margin/VBox/Title
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", UITokens.fs(22))
		title_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))

	if body != null:
		body.bbcode_enabled = true
		body.add_theme_color_override("default_color", UITokens.CLR_MUTED)
		body.text = _build_contract_text()

	if accept_button == null:
		print("[TrustContract] ERROR: AcceptButton not found (scene mismatch).")
		return

	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyles.apply_btn_primary_bordered(accept_button, 6, 24.0, 14.0, 24.0, 14.0)
	accept_button.add_theme_font_size_override("font_size", UITokens.fs(20))

	if not accept_button.pressed.is_connected(_on_accept_pressed):
		accept_button.pressed.connect(_on_accept_pressed)

func _build_contract_text() -> String:
	return """[font_size=18]""" + UITokens.BB_ACCENT + """[b]What this is[/b]""" + UITokens.BB_END + """[/font_size]

This is a training simulator. It recreates real loading scenarios so you can practice decisions — checking the RAQ, handling late arrivals, managing truck capacity — without consequences on the real dock.

[font_size=18]""" + UITokens.BB_ACCENT + """[b]How it works[/b]""" + UITokens.BB_END + """[/font_size]

You will work through scenarios that get progressively harder. Each one introduces a new layer of the job: first the basics, then priority management, then co-loading. When you demonstrate the foundations, the next scenario unlocks. This is readiness, not a grade.

Mistakes are expected and designed into the training. The simulator shows you what happens downstream when a decision goes wrong — not to judge, but so you understand why the procedures exist.

[font_size=18]""" + UITokens.BB_ACCENT + """[b]What stays private[/b]""" + UITokens.BB_END + """[/font_size]

Your individual learning runs are yours. Managers and team leads can see anonymised team-level readiness — which scenarios the team has completed and where common patterns appear — but never your personal session details, individual scores, or specific mistakes.

This system exists to make onboarding better, not to monitor performance.

Press [b]I Understand[/b] to start."""

func _on_accept_pressed() -> void:
	print("[TrustContract] Accepted")
	if accept_button != null:
		accept_button.disabled = true
	_write_trust_file()
	_fade_out_and_dismiss()


func _fade_out_and_dismiss() -> void:
	var dimmer: ColorRect = $Dimmer
	var root_ctrl: Control = $Root
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if dimmer != null:
		tw.tween_property(dimmer, "color:a", 0.0, 0.4).set_ease(
				Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	if root_ctrl != null:
		tw.tween_property(root_ctrl, "modulate:a", 0.0, 0.4).set_ease(
				Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void: accepted.emit())


func _write_trust_file() -> void:
	var f := FileAccess.open(TRUST_FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("seen=1\n")
	f.flush()
