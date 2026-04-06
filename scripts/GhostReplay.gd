class_name GhostReplay
extends RefCounted

# ==========================================
# GHOST REPLAY — Item 33
# Plays back a recorded session action log visually.
# Shows a simplified truck cross-section with pallets accumulating
# and a scrolling action timeline with playback controls.
# ==========================================

var _ui: BayUI

# --- Replay data ---
var _action_log: Array = []
var _pallet_lookup: Dictionary = {}  # id → pallet dict (from regenerated inventory)
var _loaded_ids: Array[String] = []  # current loaded pallet IDs in order
var _scenario_name: String = ""
var _total_session_time: float = 0.0
var _record_score: int = 0
var _record_passed: bool = false

# --- Screen state tracking (for replay context) ---
var _current_workspace: String = "DOCK"
var _dock_open: bool = false
var _decisions_made: Array[String] = []
var _as400_state: int = -1
var _current_snap: Dictionary = {}

# --- Playback state ---
var _is_playing: bool = false
var _elapsed: float = 0.0
var _action_index: int = 0
var _speed: float = 1.0
var _active: bool = false

# --- Speed presets ---
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]
const SPEED_LABELS: Array[String] = ["1×", "2×", "4×", "8×"]
var _speed_idx: int = 0

# --- UI nodes ---
var overlay: ColorRect
var _rtl_truck: RichTextLabel
var _rtl_log: RichTextLabel
var _lbl_time: Label
var _lbl_status: Label
var _bar_progress: ColorRect
var _bar_bg: ColorRect
var _btn_play: Button
var _btn_speed: Button
var _btn_step: Button
var _btn_back: Button
var _scroll_log: ScrollContainer


func _init(ui: BayUI) -> void:
	_ui = ui


func _build(root: Node) -> void:
	overlay = ColorRect.new()
	overlay.color = UITokens.CLR_OVERLAY_DARK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 40)
	main_margin.add_theme_constant_override("margin_top", 24)
	main_margin.add_theme_constant_override("margin_right", 40)
	main_margin.add_theme_constant_override("margin_bottom", 24)
	overlay.add_child(main_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main_margin.add_child(vbox)

	# --- Header row ---
	_build_header(vbox)

	# --- Progress bar ---
	_build_progress_bar(vbox)

	# --- Control bar ---
	_build_controls(vbox)

	# --- Divider ---
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UITokens.CLR_PANEL_BORDER
	vbox.add_child(div)

	# --- Main content: truck left, action log right ---
	_build_content_area(vbox)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	_btn_back = Button.new()
	_btn_back.text = Locale.t("replay.back")
	_btn_back.custom_minimum_size = Vector2(100, 34)
	_btn_back.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_btn_auto(_btn_back, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4, 1, UITokens.CLR_SURFACE_MID)
	_btn_back.pressed.connect(_on_back_pressed)
	row.add_child(_btn_back)

	_lbl_status = Label.new()
	_lbl_status.text = ""
	_lbl_status.add_theme_font_size_override("font_size", UITokens.fs(16))
	_lbl_status.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	_lbl_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lbl_status)

	_lbl_time = Label.new()
	_lbl_time.text = "00:00 / 00:00"
	_lbl_time.add_theme_font_size_override("font_size", UITokens.fs(14))
	_lbl_time.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	_lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_lbl_time)


func _build_progress_bar(parent: VBoxContainer) -> void:
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 8)
	parent.add_child(bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.color = UITokens.CLR_SURFACE_DIM
	_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(_bar_bg)

	_bar_progress = ColorRect.new()
	_bar_progress.color = UITokens.COLOR_ACCENT_BLUE
	_bar_progress.anchor_top = 0.0
	_bar_progress.anchor_bottom = 1.0
	_bar_progress.anchor_left = 0.0
	_bar_progress.anchor_right = 0.0
	_bar_progress.offset_left = 0.0
	_bar_progress.offset_right = 0.0
	_bar_progress.offset_top = 0.0
	_bar_progress.offset_bottom = 0.0
	bar_container.add_child(_bar_progress)


func _build_controls(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	_btn_play = Button.new()
	_btn_play.text = Locale.t("replay.play")
	_btn_play.custom_minimum_size = Vector2(90, 34)
	_btn_play.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_btn_primary(_btn_play, 4)
	_btn_play.pressed.connect(_on_play_pressed)
	row.add_child(_btn_play)

	_btn_step = Button.new()
	_btn_step.text = Locale.t("replay.step")
	_btn_step.custom_minimum_size = Vector2(80, 34)
	_btn_step.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_btn_auto(_btn_step, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4, 1, UITokens.CLR_SURFACE_MID)
	_btn_step.pressed.connect(_on_step_pressed)
	row.add_child(_btn_step)

	_btn_speed = Button.new()
	_btn_speed.text = "1×"
	_btn_speed.custom_minimum_size = Vector2(60, 34)
	_btn_speed.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_btn_auto(_btn_speed, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4, 1, UITokens.CLR_SURFACE_MID)
	_btn_speed.pressed.connect(_on_speed_pressed)
	row.add_child(_btn_speed)


func _build_content_area(parent: VBoxContainer) -> void:
	var hsplit := HBoxContainer.new()
	hsplit.add_theme_constant_override("separation", 16)
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(hsplit)

	# --- Left: truck visualization ---
	var truck_panel := PanelContainer.new()
	truck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	truck_panel.size_flags_stretch_ratio = 1.2
	UIStyles.apply_panel(truck_panel, UIStyles.flat(Color(0.08, 0.09, 0.12), 6, 1, UITokens.CLR_PANEL_BORDER))
	hsplit.add_child(truck_panel)

	var truck_margin := MarginContainer.new()
	truck_margin.add_theme_constant_override("margin_left", 16)
	truck_margin.add_theme_constant_override("margin_top", 12)
	truck_margin.add_theme_constant_override("margin_right", 16)
	truck_margin.add_theme_constant_override("margin_bottom", 12)
	truck_panel.add_child(truck_margin)

	var truck_scroll := ScrollContainer.new()
	truck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	truck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	truck_margin.add_child(truck_scroll)

	_rtl_truck = RichTextLabel.new()
	_rtl_truck.bbcode_enabled = true
	_rtl_truck.fit_content = true
	_rtl_truck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl_truck.add_theme_color_override("default_color", UITokens.CLR_TEXT_SECONDARY)
	_rtl_truck.add_theme_font_size_override("normal_font_size", UITokens.fs(13))
	truck_scroll.add_child(_rtl_truck)

	# --- Right: action log ---
	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 0.8
	UIStyles.apply_panel(log_panel, UIStyles.flat(Color(0.06, 0.07, 0.10), 6, 1, UITokens.CLR_PANEL_BORDER))
	hsplit.add_child(log_panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 12)
	log_margin.add_theme_constant_override("margin_top", 8)
	log_margin.add_theme_constant_override("margin_right", 12)
	log_margin.add_theme_constant_override("margin_bottom", 8)
	log_panel.add_child(log_margin)

	_scroll_log = ScrollContainer.new()
	_scroll_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_log.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_margin.add_child(_scroll_log)

	_rtl_log = RichTextLabel.new()
	_rtl_log.bbcode_enabled = true
	_rtl_log.fit_content = true
	_rtl_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl_log.add_theme_color_override("default_color", UITokens.CLR_TEXT_SECONDARY)
	_rtl_log.add_theme_font_size_override("normal_font_size", UITokens.fs(12))
	_scroll_log.add_child(_rtl_log)


# ==========================================
# PUBLIC API
# ==========================================

func is_active() -> bool:
	return _active


func start_replay(record: Dictionary) -> void:
	## Initialise and show the replay overlay for the given training record.
	_scenario_name = str(record.get("scenario", ""))
	_total_session_time = float(record.get("time_seconds", 0.0))
	_record_score = int(record.get("score", 0))
	_record_passed = bool(record.get("passed", false))
	var seed_val: int = int(record.get("seed", 0))

	# Parse action log
	_action_log.clear()
	var raw_log: Array = record.get("action_log", []) as Array
	for entry: Variant in raw_log:
		if entry is Dictionary:
			_action_log.append(entry as Dictionary)

	# Regenerate inventory from seed to build pallet lookup
	_pallet_lookup.clear()
	_loaded_ids.clear()
	var inv := InventoryManager.new()
	inv.generate_inventory(_scenario_name, seed_val)
	for p: Dictionary in inv.inventory_available:
		_pallet_lookup[str(p.get("id", ""))] = p.duplicate()

	# Reset playback
	_action_index = 0
	_elapsed = 0.0
	_is_playing = false
	_speed_idx = 0
	_speed = SPEEDS[0]
	_active = true
	_current_workspace = "DOCK"
	_dock_open = false
	_decisions_made.clear()
	_as400_state = -1
	_current_snap = {}

	# Update header
	if _lbl_status != null:
		var _score_clr: String = UITokens.BB_SUCCESS if _record_passed else UITokens.BB_ERROR
		_lbl_status.text = Locale.t("replay.title") + "  —  " + _scenario_name

	if _btn_play != null:
		_btn_play.text = Locale.t("replay.play")
	if _btn_speed != null:
		_btn_speed.text = SPEED_LABELS[0]

	_refresh_views()
	_update_progress()
	if overlay != null:
		overlay.visible = true


func stop_replay() -> void:
	_active = false
	_is_playing = false
	if overlay != null:
		overlay.visible = false


func tick(delta: float) -> void:
	## Called from BayUI._process each frame while active.
	if not _active or not _is_playing:
		return
	if _action_index >= _action_log.size():
		_is_playing = false
		if _btn_play != null:
			_btn_play.text = Locale.t("replay.done")
		return

	_elapsed += delta * _speed
	var advanced: bool = false
	while _action_index < _action_log.size():
		var entry: Dictionary = _action_log[_action_index]
		var action_time: float = float(entry.get("time", 0.0))
		if _elapsed < action_time:
			break
		_apply_action(entry)
		_action_index += 1
		advanced = true

	if advanced:
		_refresh_views()
	_update_progress()


# ==========================================
# PLAYBACK CONTROLS
# ==========================================

func _on_play_pressed() -> void:
	if _action_index >= _action_log.size():
		# Restart replay
		_action_index = 0
		_elapsed = 0.0
		_loaded_ids.clear()
		_current_workspace = "DOCK"
		_dock_open = false
		_decisions_made.clear()
		_as400_state = -1
		_current_snap = {}
		_is_playing = true
		if _btn_play != null:
			_btn_play.text = Locale.t("replay.pause")
		_refresh_views()
		_update_progress()
		return

	_is_playing = not _is_playing
	if _btn_play != null:
		_btn_play.text = Locale.t("replay.pause") if _is_playing else Locale.t("replay.play")


func _on_step_pressed() -> void:
	if _action_index >= _action_log.size():
		return
	_is_playing = false
	if _btn_play != null:
		_btn_play.text = Locale.t("replay.play")

	var entry: Dictionary = _action_log[_action_index]
	_elapsed = float(entry.get("time", 0.0))
	_apply_action(entry)
	_action_index += 1
	_refresh_views()
	_update_progress()

	if _action_index >= _action_log.size():
		if _btn_play != null:
			_btn_play.text = Locale.t("replay.done")


func _on_speed_pressed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	_speed = SPEEDS[_speed_idx]
	if _btn_speed != null:
		_btn_speed.text = SPEED_LABELS[_speed_idx]


func _on_back_pressed() -> void:
	stop_replay()


# ==========================================
# ACTION APPLICATION
# ==========================================

func _apply_action(entry: Dictionary) -> void:
	var action: String = str(entry.get("action", ""))
	var detail: String = str(entry.get("detail", ""))

	# Capture state snapshot if present
	var snap: Variant = entry.get("state", null)
	if snap is Dictionary:
		_current_snap = snap as Dictionary

	match action:
		"load_pallet":
			if detail not in _loaded_ids:
				_loaded_ids.append(detail)
		"unload_pallet":
			_loaded_ids.erase(detail)
		"undo_load":
			_loaded_ids.erase(detail)
		"workspace":
			_current_workspace = detail
		"dock":
			if detail == "open":
				_dock_open = true
			elif detail == "close":
				_dock_open = false
		"decision":
			if detail not in _decisions_made:
				_decisions_made.append(detail)
		"as400_state":
			_as400_state = int(detail) if detail.is_valid_int() else -1


# ==========================================
# VIEW RENDERING
# ==========================================

func _refresh_views() -> void:
	_render_truck()
	_render_action_log()


func _render_truck() -> void:
	if _rtl_truck == null:
		return

	var bb: String = ""
	bb += "[font_size=20]" + UITokens.BB_ACCENT + "[b]" + Locale.t("replay.truck_title") + "[/b]" + UITokens.BB_END + "[/font_size]\n"
	bb += UITokens.BB_DIM + Locale.t("replay.loaded_count") % _loaded_ids.size() + UITokens.BB_END + "\n\n"

	# Screen context — what the user was seeing
	bb += _render_screen_context()

	if _loaded_ids.is_empty():
		bb += "[font_size=14]" + UITokens.BB_HINT + Locale.t("replay.truck_empty") + UITokens.BB_END + "[/font_size]\n"
	else:
		# Render pallet sequence as colored blocks
		bb += _render_pallet_sequence()
		bb += "\n"
		# Render pallet detail list
		bb += _render_pallet_list()

	# Score preview (always visible)
	bb += "\n" + UITokens.BB_DIM + "─────────────────────" + UITokens.BB_END + "\n"
	var score_clr: String = UITokens.BB_SUCCESS if _record_passed else UITokens.BB_ERROR
	var result_text: String = Locale.t("replay.passed") if _record_passed else Locale.t("replay.failed")
	bb += "[font_size=14]" + UITokens.BB_HINT + Locale.t("replay.final_score") + " " + UITokens.BB_END
	bb += score_clr + "[b]" + str(_record_score) + "[/b] — " + result_text + UITokens.BB_END + "[/font_size]\n"

	_rtl_truck.text = bb


func _render_pallet_sequence() -> String:
	## Renders a visual row of colored type abbreviations (matches debrief style).
	var bb: String = "[font_size=13]"
	for i: int in range(_loaded_ids.size()):
		var pid: String = _loaded_ids[i]
		var p: Dictionary = _pallet_lookup.get(pid, {})
		var ptype: String = str(p.get("type", "?"))
		var abbr: String = _type_abbr(ptype)
		var clr: String = _type_bb_color(ptype)
		bb += clr + "[" + str(i + 1) + ":" + abbr + "]" + UITokens.BB_END + " "
	bb += "[/font_size]\n"

	# Legend
	bb += "[font_size=11]" + UITokens.BB_DIM
	bb += "SC=ServiceCenter  BK=Bikes  BU=Bulky  ME=Mecha  AD=ADR  CC=C&C"
	bb += UITokens.BB_END + "[/font_size]\n"
	return bb


func _render_screen_context() -> String:
	## Delegates to ReplayScreenRenderer for full frame capture display.
	return ReplayScreenRenderer.render(
		_current_snap, _as400_state, _current_workspace,
		_dock_open, _decisions_made,
	)


func _render_pallet_list() -> String:
	## Renders a numbered list of loaded pallets with type and promise.
	var bb: String = "[font_size=12]"
	for i: int in range(_loaded_ids.size()):
		var pid: String = _loaded_ids[i]
		var p: Dictionary = _pallet_lookup.get(pid, {})
		var ptype: String = str(p.get("type", "?"))
		var promise: String = str(p.get("promise", ""))
		var dest: int = int(p.get("dest", 1))
		var clr: String = _type_bb_color(ptype)

		bb += UITokens.BB_DIM + "%2d. " % (i + 1) + UITokens.BB_END
		bb += clr + ptype + UITokens.BB_END
		if promise != "":
			bb += UITokens.BB_HINT + " (" + promise + ")" + UITokens.BB_END
		if dest == 2:
			bb += UITokens.BB_STORE + " [D2]" + UITokens.BB_END
		bb += "\n"
	bb += "[/font_size]"
	return bb


func _render_action_log() -> void:
	if _rtl_log == null:
		return

	var bb: String = ""
	bb += "[font_size=16]" + UITokens.BB_ACCENT + "[b]" + Locale.t("replay.log_title") + "[/b]" + UITokens.BB_END + "[/font_size]\n\n"

	if _action_log.is_empty():
		bb += UITokens.BB_HINT + Locale.t("replay.no_actions") + UITokens.BB_END + "\n"
		_rtl_log.text = bb
		return

	for i: int in range(_action_log.size()):
		var entry: Dictionary = _action_log[i]
		var action_time: float = float(entry.get("time", 0.0))
		var action: String = str(entry.get("action", ""))
		var detail: String = str(entry.get("detail", ""))

		var is_current: bool = (i == _action_index - 1)
		var is_future: bool = (i >= _action_index)
		var time_str: String = _format_time(action_time)

		var line_clr: String = UITokens.BB_WHITE if is_current else (UITokens.BB_DIM if is_future else UITokens.BB_HINT)
		var marker: String = "►" if is_current else " "

		var action_display: String = _format_action(action, detail)

		bb += "[font_size=12]"
		if is_current:
			bb += UITokens.BB_ACCENT + marker + UITokens.BB_END + " "
		else:
			bb += UITokens.BB_DIM + marker + UITokens.BB_END + " "
		bb += line_clr + time_str + "  " + action_display + UITokens.BB_END
		bb += "[/font_size]\n"

	_rtl_log.text = bb

	# Auto-scroll to current action
	if _scroll_log != null and _action_index > 0:
		_scroll_log.call_deferred("set_v_scroll", maxi(0, (_action_index - 3) * 20))


func _format_action(action: String, detail: String) -> String:
	## Returns a human-readable description of the action.
	match action:
		"load_pallet":
			var p: Dictionary = _pallet_lookup.get(detail, {})
			var ptype: String = str(p.get("type", "?"))
			var clr: String = _type_bb_color(ptype)
			return Locale.t("replay.act_load") + " " + clr + ptype + UITokens.BB_END
		"unload_pallet":
			var p: Dictionary = _pallet_lookup.get(detail, {})
			var ptype: String = str(p.get("type", "?"))
			return Locale.t("replay.act_unload") + " " + UITokens.BB_ERROR + ptype + UITokens.BB_END
		"undo_load":
			var p: Dictionary = _pallet_lookup.get(detail, {})
			var ptype: String = str(p.get("type", "?"))
			return Locale.t("replay.act_undo") + " " + UITokens.BB_WARNING + ptype + UITokens.BB_END
		"workspace":
			var ws_icon: String = "🏗" if detail == "DOCK" else "🗂"
			return ws_icon + " " + UITokens.BB_HINT + "→ " + detail + UITokens.BB_END
		"dock":
			if detail == "open":
				return "🚪 " + UITokens.BB_SUCCESS + "Dock opened" + UITokens.BB_END
			return "🚪 " + UITokens.BB_DIM + "Dock closed" + UITokens.BB_END
		"decision":
			return UITokens.BB_ACCENT + detail + UITokens.BB_END
		"tutorial_skip":
			return UITokens.BB_WARNING + "⏭ Skip step " + detail + UITokens.BB_END
		"as400_state":
			var sname: String = ReplayScreenRenderer._as400_state_name(int(detail) if detail.is_valid_int() else -1)
			return "💻 " + UITokens.BB_HINT + "AS400 → " + sname + UITokens.BB_END
	return action + ": " + detail


# ==========================================
# PROGRESS BAR
# ==========================================

func _update_progress() -> void:
	if _total_session_time < 0.1:
		return
	var progress: float = clampf(_elapsed / _total_session_time, 0.0, 1.0)

	if _bar_progress != null and _bar_bg != null:
		_bar_progress.anchor_right = progress

	if _lbl_time != null:
		_lbl_time.text = _format_time(_elapsed) + " / " + _format_time(_total_session_time)


# ==========================================
# HELPERS
# ==========================================

static func _format_time(secs: float) -> String:
	var total: int = int(secs)
	@warning_ignore("integer_division")
	var m: int = total / 60
	var s: int = total % 60
	return "%d:%02d" % [m, s]


static func _type_abbr(ptype: String) -> String:
	match ptype:
		"ServiceCenter": return "SC"
		"Bikes": return "BK"
		"Bulky": return "BU"
		"Mecha": return "ME"
		"ADR": return "AD"
		"C&C": return "CC"
	return ptype.left(2).to_upper()


static func _type_bb_color(ptype: String) -> String:
	match ptype:
		"ServiceCenter": return UITokens.BB_SUCCESS
		"Bikes": return UITokens.BB_BLUE
		"Bulky": return UITokens.BB_ORANGE
		"Mecha": return UITokens.BB_MAGNUM
		"ADR": return UITokens.BB_RED_BRIGHT
		"C&C": return UITokens.BB_WARNING
	return UITokens.BB_DIM
