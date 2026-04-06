class_name PhoneSystem
extends RefCounted

## Manages phone notifications, flash timer, badge, and content panel.

var _ui: BayUI

var messages: Array = []
var flash_active: bool = false
var _flash_timer: Timer = null
var _seen_count: int = 0

# --- TOAST NOTIFICATION ---
var _toast_layer: CanvasLayer = null
var _toast_panel: PanelContainer = null
var _toast_tween: Tween = null
var _toast_dismiss_timer: float = -1.0


func _init(ui: BayUI) -> void:
	_ui = ui


func build_toast_overlay(_root: Control) -> void:
	## Build the slide-in toast notification (top-right corner).
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 15  # Below interruption (18) and tutorial (100), above workspace
	_toast_layer.name = "PhoneToastLayer"
	_ui.add_child(_toast_layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.custom_minimum_size = Vector2(320, 0)
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_panel.offset_left = -340
	_toast_panel.offset_right = -20
	_toast_panel.offset_top = -100  # Start off-screen
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = UIStyles.flat(Color(0.12, 0.18, 0.28), 8, 2, UITokens.CLR_AMBER)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_panel.visible = false
	_toast_layer.add_child(_toast_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_toast_panel.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = "📞"
	icon_lbl.add_theme_font_size_override("font_size", UITokens.fs(22))
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var text_vbox: VBoxContainer = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	var title_lbl: Label = Label.new()
	title_lbl.name = "ToastTitle"
	title_lbl.text = Locale.t("toast.incoming_call")
	title_lbl.add_theme_font_size_override("font_size", UITokens.fs(13))
	title_lbl.add_theme_color_override("font_color", UITokens.CLR_AMBER)
	text_vbox.add_child(title_lbl)

	var body_lbl: Label = Label.new()
	body_lbl.name = "ToastBody"
	body_lbl.text = ""
	body_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	body_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(body_lbl)

	var view_btn: Button = Button.new()
	view_btn.text = Locale.t("toast.view")
	view_btn.custom_minimum_size = Vector2(60, 28)
	view_btn.add_theme_font_size_override("font_size", UITokens.fs(11))
	UIStyles.apply_btn_auto(view_btn, UITokens.CLR_BLUE_DEEP,
			Color(0.82, 0.85, 0.9), Color.WHITE, 4)
	view_btn.pressed.connect(func() -> void:
		_dismiss_toast()
		# Force-open (not toggle) so second call doesn't close the panel
		_ui._ws.set_panel_visible("Phone", true, false)
	)
	hbox.add_child(view_btn)


func reset() -> void:
	messages.clear()
	_seen_count = 0
	clear_flash()
	_dismiss_toast()


func update_badge(count: int) -> void:
	if _ui._phone_btn_top == null: return
	if count > 0:
		_ui._phone_btn_top.text = Locale.t("btn.phone") + " (%d)" % count
		_ui._phone_btn_top.add_theme_color_override("font_color", UITokens.CLR_AMBER)
	else:
		_ui._phone_btn_top.text = Locale.t("btn.phone")
		_ui._phone_btn_top.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))


func clear_flash() -> void:
	flash_active = false
	if _flash_timer != null:
		_flash_timer.stop()
		_flash_timer.queue_free()
		_flash_timer = null
	if _ui.btn_phone != null:
		_ui.btn_phone.text = (" " + Locale.t("btn.phone") + " ")
		_ui.btn_phone.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_MUTED))


func on_pallets_delivered() -> void:
	update_content()
	if _ui._dock.lbl_hover_info:
		_ui._dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_SUCCESS + "[b]" + Locale.t("dock.pallets_arrived") + "[/b]" + UITokens.BB_END + "[/font_size]"


func on_notification(message: String, _pallets_added: int) -> void:
	messages.append(message)
	flash_active = true
	WOTSAudio.play_phone_ring(_ui)

	update_content()
	var unread: int = messages.size() - _seen_count
	update_badge(unread)

	# Show toast notification (extract a short preview from the message)
	var preview: String = Locale.t("toast.pallets_incoming")
	_show_toast(preview)

	# Kill existing flash timer
	if _flash_timer != null:
		_flash_timer.stop()
		_flash_timer.queue_free()
		_flash_timer = null

	if _ui.btn_phone != null:
		_ui.btn_phone.text = (" " + Locale.t("btn.phone") + " (!) ")
		var flash_state := {"count": 0}
		var timer := Timer.new()
		timer.wait_time = 0.4
		timer.one_shot = false
		_ui.add_child(timer)
		_flash_timer = timer
		var btn_ref: Button = _ui.btn_phone
		var sys_ref: PhoneSystem = self
		timer.timeout.connect(func() -> void:
			if not sys_ref.flash_active:
				timer.stop()
				timer.queue_free()
				if sys_ref._flash_timer == timer:
					sys_ref._flash_timer = null
				return
			flash_state.count += 1
			if flash_state.count % 2 == 0:
				btn_ref.add_theme_color_override("font_color", UITokens.CLR_RED_BRIGHT)
			else:
				btn_ref.add_theme_color_override("font_color", UITokens.CLR_MUTED)
			if flash_state.count >= 10:
				timer.stop()
				timer.queue_free()
				if sys_ref._flash_timer == timer:
					sys_ref._flash_timer = null
				if sys_ref.flash_active and btn_ref != null:
					btn_ref.add_theme_color_override("font_color", UITokens.CLR_RED_BRIGHT)
		)
		timer.start()


func on_panel_opened() -> void:
	clear_flash()
	_dismiss_toast()
	_seen_count = messages.size()
	update_content()
	update_badge(0)
	if _ui._session != null:
		_ui._session.manual_decision("Phone Opened")


func update_content() -> void:
	var ph_body: RichTextLabel = _ui._paper.find_panel_body(_ui.pnl_phone)
	if ph_body == null: return
	var t: String = "[font_size=14]"
	t += UITokens.BB_ACCENT + "[b]PHONE[/b]" + UITokens.BB_END + "\n"
	t += UITokens.BB_DIM + "────────────────────────────────────────" + UITokens.BB_END + "\n\n"
	if _ui._session != null and _ui._session._phone_deliver_timer > 0.0:
		t += UITokens.BB_WARNING + "[b]⏳ Pallets on the way — arriving in ~10 seconds.[/b]" + UITokens.BB_END + "\n\n"
		t += UITokens.BB_DIM + "────────────────────────────────────────" + UITokens.BB_END + "\n\n"
	if messages.size() > 0:
		for i: int in range(messages.size() - 1, -1, -1):
			if i < _seen_count:
				t += UITokens.BB_SUCCESS + "✓ Answered" + UITokens.BB_END + "\n"
			else:
				t += UITokens.BB_WARNING + "⬤ NEW" + UITokens.BB_END + "\n"
			t += messages[i] + "\n\n"
			if i > 0:
				t += UITokens.BB_DIM + "────────────────────────────────────────" + UITokens.BB_END + "\n\n"
	else:
		t += UITokens.BB_SUBDUED + "No incoming calls.\n\n"
		t += "Departments will call about late pallets\n"
		t += "and priority changes during loading.\n\n"
		t += "[b]Quick dial:[/b]\n"
		t += "  DOUBLON: 1003\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001" + UITokens.BB_END + "\n"
	t += "[/font_size]"
	ph_body.text = t


func tick_toast(delta: float) -> void:
	## Called from BayUI._process() to auto-dismiss the toast after 5 seconds.
	if _toast_dismiss_timer <= 0.0:
		return
	_toast_dismiss_timer -= delta
	if _toast_dismiss_timer <= 0.0:
		_dismiss_toast()


func _show_toast(preview_text: String) -> void:
	if _toast_panel == null:
		return
	# Update body text
	var body_lbl: Label = _toast_panel.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/ToastBody")
	if body_lbl != null:
		body_lbl.text = preview_text
	var title_lbl: Label = _toast_panel.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/ToastTitle")
	if title_lbl != null:
		title_lbl.text = Locale.t("toast.incoming_call")

	# Kill any existing tween
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	# Slide in from top
	_toast_panel.visible = true
	_toast_panel.offset_top = -100.0
	_toast_panel.modulate.a = 0.0
	_toast_tween = _ui.create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "offset_top", 12.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

	_toast_dismiss_timer = 5.0


func _dismiss_toast() -> void:
	_toast_dismiss_timer = -1.0
	if _toast_panel == null or not _toast_panel.visible:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = _ui.create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "offset_top", -100.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.2)
	_toast_tween.chain().tween_callback(func() -> void:
		_toast_panel.visible = false
	)
