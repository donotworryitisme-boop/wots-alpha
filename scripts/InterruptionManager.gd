class_name InterruptionManager
extends RefCounted

## Manages random equipment and disruption events during loading.
## Pre-schedules 2-3 events per shift at random loading-time thresholds.
## Shows a blocking overlay with countdown, then adds time cost.

var _ui: BayUI

# --- Event definitions ---
const EVENT_TYPES: Array[Dictionary] = [
	{"key": "interruption.scanner_offline", "duration": 5.0, "time_cost": 15.0, "icon": "📟", "category": "equipment"},
	{"key": "interruption.forklift_battery", "duration": 8.0, "time_cost": 30.0, "icon": "🔋", "category": "equipment"},
	{"key": "interruption.colleague_help", "duration": 10.0, "time_cost": 45.0, "icon": "🤝", "category": "colleague"},
	{"key": "interruption.label_printer_jam", "duration": 6.0, "time_cost": 20.0, "icon": "🖨️", "category": "equipment"},
	{"key": "interruption.safety_announcement", "duration": 7.0, "time_cost": 25.0, "icon": "📢", "category": "safety"},
]

# --- Schedule ---
var _scheduled_events: Array[Dictionary] = []  # {trigger_time, event_type_idx, fired}
var _active: bool = false
var _countdown: float = 0.0
var _current_event: Dictionary = {}

# --- Overlay nodes ---
var _overlay: ColorRect
var _icon_label: Label
var _msg_label: RichTextLabel
var _countdown_label: Label
var _progress_bar: ColorRect
var _progress_bg: ColorRect


func _init(ui: BayUI) -> void:
	_ui = ui


func build_overlay(root: Node) -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 240)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = UITokens.CLR_MODAL_BG
	panel_sb.corner_radius_top_left = 12
	panel_sb.corner_radius_top_right = 12
	panel_sb.corner_radius_bottom_left = 12
	panel_sb.corner_radius_bottom_right = 12
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_color = Color(0.8, 0.5, 0.1, 0.7)
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Icon
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", UITokens.fs(40))
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_icon_label)

	# Message
	_msg_label = RichTextLabel.new()
	_msg_label.bbcode_enabled = true
	_msg_label.fit_content = true
	_msg_label.custom_minimum_size = Vector2(340, 0)
	_msg_label.add_theme_color_override("default_color", Color(0.85, 0.87, 0.9))
	_msg_label.add_theme_font_size_override("normal_font_size", UITokens.fs(15))
	vbox.add_child(_msg_label)

	# Progress bar background
	_progress_bg = ColorRect.new()
	_progress_bg.custom_minimum_size = Vector2(340, 8)
	_progress_bg.color = UITokens.CLR_TOGGLE_OFF
	vbox.add_child(_progress_bg)

	# Progress bar fill (child of background — positioned manually)
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color(0.9, 0.6, 0.1)
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.size = Vector2(340, 8)
	_progress_bg.add_child(_progress_bar)

	# Countdown text
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", UITokens.fs(22))
	_countdown_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_countdown_label)


func setup_for_session(scenario_index: int, seed_val: int) -> void:
	## Pre-schedule interruption events for this session.
	## Tutorial (0) and Free Play (4) skip interruptions.
	_scheduled_events.clear()
	_active = false
	_countdown = 0.0
	_current_event = {}
	if _overlay != null:
		_overlay.visible = false

	# No interruptions for tutorial or free play
	if scenario_index == 0 or scenario_index == 4:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 31337

	var event_count: int = rng.randi_range(1, 2)
	# Schedule events at random points during loading (300s-900s of loading time)
	var used_times: Array[float] = []
	for _i: int in range(event_count):
		var trigger: float = float(rng.randi_range(300, 900))
		# Avoid events too close together (at least 120s apart)
		var attempts: int = 0
		while _is_too_close(trigger, used_times) and attempts < 20:
			trigger = float(rng.randi_range(200, 900))
			attempts += 1
		used_times.append(trigger)

		var type_idx: int = rng.randi_range(0, EVENT_TYPES.size() - 1)
		_scheduled_events.append({
			"trigger_time": trigger,
			"event_type_idx": type_idx,
			"fired": false,
		})

	# Sort by trigger time
	_scheduled_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.trigger_time) < float(b.trigger_time)
	)


func _is_too_close(t: float, used: Array[float]) -> bool:
	for u: float in used:
		if absf(t - u) < 120.0:
			return true
	return false


func tick(delta: float) -> void:
	## Called every frame from BayUI._process().
	if _scheduled_events.is_empty():
		return

	# If an interruption is active, count down
	if _active:
		_countdown -= delta
		if _countdown <= 0.0:
			_end_interruption()
		else:
			_update_countdown_display()
		return

	# Check if any scheduled event should fire
	if _ui._session == null or not _ui._session.is_active:
		return
	if not _ui._session.loading_started:
		return

	var loading_elapsed: float = _ui._session.total_time - _ui._session.loading_start_time
	for ev: Dictionary in _scheduled_events:
		if bool(ev.fired):
			continue
		if loading_elapsed >= float(ev.trigger_time):
			ev.fired = true
			_start_interruption(int(ev.event_type_idx))
			break


func _start_interruption(type_idx: int) -> void:
	if type_idx < 0 or type_idx >= EVENT_TYPES.size():
		return
	_current_event = EVENT_TYPES[type_idx]
	_countdown = float(_current_event.duration)
	_active = true

	if _overlay != null:
		_icon_label.text = str(_current_event.icon)
		_msg_label.text = "[center][b]" + Locale.t(str(_current_event.key)) + "[/b][/center]"
		_update_countdown_display()
		_overlay.visible = true

	# Pause the session timer so the interruption time is tracked separately
	if _ui._session != null:
		_ui._session.is_paused = true

	WOTSAudio.play_error_buzz(_ui)


func _end_interruption() -> void:
	_active = false
	if _overlay != null:
		_overlay.visible = false

	# Resume session and add the time cost
	if _ui._session != null:
		_ui._session.is_paused = false
		_ui._session._add_categorized_time(float(_current_event.time_cost), "interruption")

	_current_event = {}
	WOTSAudio.play_panel_click(_ui)


func _update_countdown_display() -> void:
	if _countdown_label == null:
		return
	var secs: int = int(ceilf(_countdown))
	_countdown_label.text = str(secs) + "s"

	# Update progress bar width
	if _progress_bar != null and _progress_bg != null and not _current_event.is_empty():
		var total_dur: float = float(_current_event.duration)
		var ratio: float = 1.0 - (_countdown / total_dur) if total_dur > 0.0 else 1.0
		ratio = clampf(ratio, 0.0, 1.0)
		_progress_bar.size.x = _progress_bg.size.x * ratio


func is_blocking() -> bool:
	## Returns true if an interruption is currently blocking input.
	return _active


func reset() -> void:
	_scheduled_events.clear()
	_active = false
	_countdown = 0.0
	_current_event = {}
	if _overlay != null:
		_overlay.visible = false
