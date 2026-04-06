class_name GhostReplay
extends RefCounted

# ==========================================
# GHOST REPLAY — Step-Through Replay Driver
# Replays a recorded session on the real BayUI.
# No auto-play. User steps forward/backward through
# each logged action. All state changes are instant
# (no crossfade animations) so each step shows its
# result immediately.
# ==========================================

var _ui: BayUI

# --- Replay data ---
var _action_log: Array = []
var _scenario_name: String = ""
var _total_session_time: float = 0.0
var _record_score: int = 0
var _record_passed: bool = false
var _record_seed: int = 0

# --- Playback state ---
var _action_index: int = 0
var _active: bool = false

# --- UI nodes ---
var _input_blocker: ColorRect
var _controls_bar: PanelContainer
var _bar_progress: ColorRect
var _btn_prev: Button
var _btn_next: Button
var _btn_back: Button
var _lbl_timer: Label
var _lbl_status: Label
var _lbl_action: Label
var _lbl_count: Label


func _init(ui: BayUI) -> void:
	_ui = ui


func _build(root: Node) -> void:
	# Input blocker — transparent layer that prevents all mouse
	# interaction with the game UI underneath.
	_input_blocker = ColorRect.new()
	_input_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.visible = false
	root.add_child(_input_blocker)

	_build_controls_bar(root)


func is_active() -> bool:
	return _active


# Unused — replay has no auto-play tick
func tick(_delta: float) -> void:
	pass


# ==========================================
# CONTROLS BAR — anchored to screen bottom
# ==========================================

func _build_controls_bar(root: Node) -> void:
	_controls_bar = PanelContainer.new()
	_controls_bar.visible = false
	_controls_bar.anchor_left = 0.0
	_controls_bar.anchor_right = 1.0
	_controls_bar.anchor_top = 1.0
	_controls_bar.anchor_bottom = 1.0
	_controls_bar.offset_top = -56.0
	_controls_bar.offset_bottom = 0.0
	_controls_bar.offset_left = 0.0
	_controls_bar.offset_right = 0.0
	UIStyles.apply_panel(_controls_bar, UIStyles.flat(
			Color(0.05, 0.06, 0.08, 0.96), 0, 1, UITokens.CLR_PANEL_BORDER))
	root.add_child(_controls_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_controls_bar.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# --- Progress bar ---
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.color = UITokens.CLR_SURFACE_DIM
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bar_bg)

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

	# --- Main row ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_btn_back = _make_btn(Locale.t("replay.back"), 90)
	_btn_back.pressed.connect(_on_back_pressed)
	row.add_child(_btn_back)

	_lbl_status = Label.new()
	_lbl_status.add_theme_font_size_override("font_size", UITokens.fs(12))
	_lbl_status.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	row.add_child(_lbl_status)

	_add_separator(row)

	_btn_prev = _make_btn(Locale.t("replay.prev"), 80)
	_btn_prev.pressed.connect(_on_prev_pressed)
	row.add_child(_btn_prev)

	_btn_next = Button.new()
	_btn_next.text = Locale.t("replay.next")
	_btn_next.custom_minimum_size = Vector2(80, 28)
	_btn_next.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn_primary(_btn_next, 4)
	_btn_next.pressed.connect(_on_next_pressed)
	row.add_child(_btn_next)

	_lbl_count = Label.new()
	_lbl_count.add_theme_font_size_override("font_size", UITokens.fs(12))
	_lbl_count.add_theme_color_override("font_color",
			UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	row.add_child(_lbl_count)

	_add_separator(row)

	_lbl_action = Label.new()
	_lbl_action.text = ""
	_lbl_action.add_theme_font_size_override("font_size", UITokens.fs(12))
	_lbl_action.add_theme_color_override("font_color", UITokens.CLR_WHITE)
	_lbl_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_action.clip_text = true
	row.add_child(_lbl_action)

	_lbl_timer = Label.new()
	_lbl_timer.text = "0:00 / 0:00"
	_lbl_timer.add_theme_font_size_override("font_size", UITokens.fs(12))
	_lbl_timer.add_theme_color_override("font_color",
			UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	row.add_child(_lbl_timer)


func _add_separator(parent: HBoxContainer) -> void:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 20)
	sep.color = UITokens.CLR_SURFACE_MID
	parent.add_child(sep)


func _make_btn(text: String, min_w: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 28)
	btn.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn_auto(btn, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4,
			1, UITokens.CLR_SURFACE_MID)
	return btn


# ==========================================
# PUBLIC API
# ==========================================

func start_replay(record: Dictionary) -> void:
	_scenario_name = str(record.get("scenario", ""))
	_total_session_time = float(record.get("time_seconds", 0.0))
	_record_score = int(record.get("score", 0))
	_record_passed = bool(record.get("passed", false))
	_record_seed = int(record.get("seed", 0))

	_action_log.clear()
	var raw: Array = record.get("action_log", []) as Array
	for entry: Variant in raw:
		if entry is Dictionary:
			var e: Dictionary = entry as Dictionary
			if _is_side_effect(e):
				continue
			_action_log.append(e)

	_action_index = 0
	_active = true

	# Hide debrief if visible
	if _ui._debrief.overlay != null:
		_ui._debrief.overlay.visible = false

	# Set up a fresh session with the same scenario + seed
	_init_replay_session()

	# Show controls
	_input_blocker.visible = true
	_controls_bar.visible = true
	_refresh_all()


func stop_replay() -> void:
	_active = false

	# Hide replay UI
	_input_blocker.visible = false
	_controls_bar.visible = false

	# Exit replay mode
	_ui.replay_mode = false
	if _ui._session != null:
		_ui._session.replay_suppress_log = false
		_ui._session.is_active = false
		_ui._session.is_paused = false

	# Return to portal with a fade
	_ui._fade.fade_transition(_ui._flow._return_to_portal)


# ==========================================
# SESSION SETUP
# ==========================================

func _init_replay_session() -> void:
	var idx: int = _scenario_name_to_index(_scenario_name)

	# Configure portal so execute_session_start reads the right values
	if _ui._portal.scenario_dropdown != null:
		_ui._portal.scenario_dropdown.select(idx)
	if _ui._portal.seed_input != null:
		_ui._portal.seed_input.text = str(_record_seed)

	# Set replay mode BEFORE session start so telemetry is suppressed
	_ui.replay_mode = true

	# Start the session — sets up inventory, metadata, dock, etc.
	_ui._flow.execute_session_start()

	# Remaining replay flags (replay_mode already true)
	if _ui._session != null:
		_ui._session.is_paused = true
		_ui._session.replay_suppress_log = true

	# Disable tutorial
	_ui._tc.stop()
	if _ui._tut.canvas != null:
		_ui._tut.canvas.visible = false

	# Release focus from any control
	var focus_owner: Control = _ui.get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()


static func _scenario_name_to_index(scenario: String) -> int:
	if scenario.begins_with("0"):
		return 0
	if scenario.begins_with("1"):
		return 1
	if scenario.begins_with("2"):
		return 2
	if scenario.begins_with("3"):
		return 3
	if scenario.begins_with("4"):
		return 4
	return 1


# ==========================================
# STEPPING
# ==========================================

func _on_next_pressed() -> void:
	if _action_index >= _action_log.size():
		return
	_apply_action(_action_log[_action_index])
	_action_index += 1
	_refresh_all()


func _on_prev_pressed() -> void:
	if _action_index <= 0:
		return
	_step_to(_action_index - 1)


func _on_back_pressed() -> void:
	stop_replay()


func _step_to(target: int) -> void:
	## Replays from scratch to the given action index.
	## All actions are applied instantly (no animations).
	_init_replay_session()
	for i: int in range(target):
		if i >= _action_log.size():
			break
		_apply_action(_action_log[i])
	_action_index = target
	# Kill any stray tweens left by methods that sneak them in
	_kill_tweens()
	# Force correct modulate on workspace containers
	if _ui._dock_workspace != null:
		_ui._dock_workspace.modulate.a = 1.0
		_ui._dock_workspace.position.x = 0.0
	if _ui._office_workspace != null:
		_ui._office_workspace.modulate.a = 1.0
		_ui._office_workspace.position.x = 0.0
	_refresh_all()


func _kill_tweens() -> void:
	if _ui._fade._xfade_tween != null and _ui._fade._xfade_tween.is_valid():
		_ui._fade._xfade_tween.kill()
	_ui._fade._xfade_target = null


# ==========================================
# ACTION INTERPRETER — all instant, no animations
# ==========================================

func _apply_action(entry: Dictionary) -> void:
	var action: String = str(entry.get("action", ""))
	var detail: String = str(entry.get("detail", ""))
	var action_time: float = float(entry.get("time", 0.0))

	# Sync session clock
	if _ui._session != null:
		_ui._session.total_time = action_time
		_ui._update_top_time(action_time)

	match action:
		"load_pallet":
			_replay_load(detail)
		"unload_pallet":
			_replay_unload(detail)
		"undo_load":
			_replay_undo(detail)
		"workspace":
			_replay_workspace(detail)
		"dock":
			_replay_dock(detail)
		"decision":
			_replay_decision(detail)
		"as400_state":
			_replay_as400(detail)
		"as400_dest":
			_replay_as400_dest(detail)
		"as400_seal":
			_replay_as400_seal(detail)
		"cmr_field":
			_replay_cmr_field(detail)
		"ls_field":
			_replay_ls_field(detail)
		"cmr_franco":
			_replay_franco(detail)
		"tutorial_skip":
			pass

	# Re-sync clock (some methods add time internally)
	if _ui._session != null:
		_ui._session.total_time = action_time
		_ui._update_top_time(action_time)


# --- Pallet operations (instant, no animations) ---

func _replay_load(id: String) -> void:
	if _ui._session != null:
		_ui._session.load_pallet_by_id(id)


func _replay_unload(id: String) -> void:
	if _ui._session != null:
		_ui._session.unload_pallet_by_id(id)


func _replay_undo(id: String) -> void:
	if _ui._session != null:
		var _ok: bool = _ui._session.undo_last_load(id)


# --- Workspace (instant — skip crossfade) ---

func _replay_workspace(ws: String) -> void:
	_ui._active_workspace = ws
	_ui._ws._style_workspace_tabs(ws)
	_ui._ws._apply_workspace(ws)
	# Ensure no mid-fade modulate from killed tweens
	if _ui._dock_workspace != null:
		_ui._dock_workspace.modulate.a = 1.0
		_ui._dock_workspace.position.x = 0.0
	if _ui._office_workspace != null:
		_ui._office_workspace.modulate.a = 1.0
		_ui._office_workspace.position.x = 0.0


# --- Dock (already instant) ---

func _replay_dock(detail: String) -> void:
	if detail == "open":
		_ui._dock.open_dock()
		if _ui.btn_open_dock != null:
			_ui.btn_open_dock.visible = false
	elif detail == "close":
		_ui._dock.close_dock()
		if _ui.btn_close_dock != null:
			_ui.btn_close_dock.visible = false
		# Set wrapup phase instantly (no crossfade)
		_ui._office.office_phase = "WRAPUP"
		_ui._office.refresh_office_phase_ui()


# --- Decisions (instant) ---

func _replay_decision(detail: String) -> void:
	match detail:
		"Collect CMR":
			_collect_desk("cmr")
		"Collect Seal":
			_collect_desk("seal")
		"Collect Loading Sheet":
			_collect_desk("loading_sheet")
		"CMR Stamp Top":
			_ui._paper.cmr._apply_stamp_top()
		"CMR Stamp & Sign":
			_ui._paper.cmr._apply_stamp_bot()
		"Mark CMR":
			_ui._paper.cmr._mark_x()
		"Hand CMR to Driver":
			_replay_workspace("OFFICE")
			_ui._office.advance_wrapup("hand_cmr")
		"Archive Papers":
			_ui._office.advance_wrapup("archive")
		"Seal Truck":
			_ui._office.advance_wrapup("seal")
		"Open Loading Sheet":
			# Only toggle when on dock — on office it is a side-effect
			# of the workspace switch, already handled by _apply_workspace
			if _ui._active_workspace == "DOCK":
				_ensure_panel("Loading Sheet")
		"Open CMR":
			if _ui._active_workspace == "DOCK":
				_ensure_panel("CMR")
		"Open CMR 2":
			_ui._paper.cmr.switch_dest(2)
		"Open Office", "Open AS400", "Phone Opened":
			pass
		_:
			if _ui._session != null:
				_ui._session.manual_decision(detail)


func _collect_desk(key: String) -> void:
	## Collect a desk item instantly — no crossfade animation.
	var office: OfficeManager = _ui._office
	if office.desk_items_collected.get(key, false):
		return
	office.desk_items_collected[key] = true
	office.desk_collected_count += 1
	# Visual: checkmark + disable button
	if office.desk_checkmarks.has(key):
		office.desk_checkmarks[key].visible = true
	if office.desk_item_btns.has(key):
		office.desk_item_btns[key].disabled = true
	# After all 3: instantly swap to paperwork view
	if office.desk_collected_count >= 3:
		if office.desk_view_container != null:
			office.desk_view_container.visible = false
		if office.docs_row != null:
			office.docs_row.visible = true
		office.cmr_revealed = false
		office.active_paperwork_tab = "LS"
		_ui._paper.update_loading_sheet()
		_ui._populate_overlay_panels()
		# Sync panel visibility: show LS, hide CMR
		office.refresh_office_phase_ui()


func _ensure_panel(panel_name: String) -> void:
	if not bool(_ui._panel_state.get(panel_name, false)):
		_ui._ws.toggle_panel(panel_name)


# --- AS400 (instant) ---

func _replay_as400(detail: String) -> void:
	if _ui._as400 == null or not detail.is_valid_int():
		return
	var state_id: int = int(detail)
	_ui._as400.state = state_id
	_ui._as400._render_as400_screen()
	# VALIDATION state (F10 confirm) enables dock close
	if state_id == AS400Terminal.S.VALIDATION:
		_ui._as400_confirmed = true
		if _ui.btn_close_dock != null:
			_ui.btn_close_dock.visible = true
	if not bool(_ui._panel_state.get("AS400", false)):
		_ui._ws.set_panel_visible("AS400", true, true)


func _replay_as400_dest(detail: String) -> void:
	## Restore dest_code + dest_name on a specific AS400 tab.
	## Format: "tab_idx:code:name"
	if _ui._as400 == null:
		return
	var parts: PackedStringArray = detail.split(":", true, 2)
	if parts.size() < 3:
		return
	var tab_idx: int = int(parts[0])
	var code: String = parts[1]
	var dname: String = parts[2]
	if tab_idx >= 0 and tab_idx < _ui._as400._tabs.size():
		_ui._as400._tabs[tab_idx]["dest_code"] = code
		_ui._as400._tabs[tab_idx]["dest_name"] = dname
		_ui._as400._rebuild__tab_bar()
		_ui._as400._render_as400_screen()


func _replay_as400_seal(detail: String) -> void:
	## Restore seal_entered on a specific AS400 tab.
	## Format: "tab_idx:seal_value"
	if _ui._as400 == null:
		return
	var sep: int = detail.find(":")
	if sep < 0:
		return
	var tab_idx: int = int(detail.left(sep))
	var seal_val: String = detail.substr(sep + 1)
	if tab_idx >= 0 and tab_idx < _ui._as400._tabs.size():
		_ui._as400._tabs[tab_idx]["seal_entered"] = seal_val
		_ui._as400._render_as400_screen()


# --- Field inputs (instant) ---

func _replay_cmr_field(detail: String) -> void:
	var sep: int = detail.find(":")
	if sep < 0:
		return
	var field: String = detail.left(sep)
	var value: String = detail.substr(sep + 1)
	_set_cmr_input(field, value)
	_ui._paper.cmr._write_field(field, value)


func _replay_ls_field(detail: String) -> void:
	var sep: int = detail.find(":")
	if sep < 0:
		return
	var field: String = detail.left(sep)
	var value: String = detail.substr(sep + 1)
	_set_ls_input(field, value)
	_ui._paper.ls._write_field(field, value)


func _replay_franco(detail: String) -> void:
	_ui._paper.cmr._select_franco(detail)


func _set_cmr_input(field: String, value: String) -> void:
	var cmr: CMRForm = _ui._paper.cmr
	match field:
		"uats":
			if cmr._input_uats != null: cmr._input_uats.text = value
		"collis":
			if cmr._input_collis != null: cmr._input_collis.text = value
		"eur":
			if cmr._input_eur != null: cmr._input_eur.text = value
		"plastic":
			if cmr._input_plastic != null: cmr._input_plastic.text = value
		"magnum":
			if cmr._input_magnum != null: cmr._input_magnum.text = value
		"cc":
			if cmr._input_cc != null: cmr._input_cc.text = value
		"weight":
			if cmr._input_weight != null: cmr._input_weight.text = value
		"dm3":
			if cmr._input_dm3 != null: cmr._input_dm3.text = value
		"expedition":
			if cmr._input_expedition != null: cmr._input_expedition.text = value
		"seal":
			if cmr._input_seal != null: cmr._input_seal.text = value
		"dock":
			if cmr._input_dock != null: cmr._input_dock.text = value


func _set_ls_input(field: String, value: String) -> void:
	var ls: LoadingSheetForm = _ui._paper.ls
	match field:
		"store":
			if ls.ls_input_store != null: ls.ls_input_store.text = value
		"seal":
			if ls.ls_input_seal != null: ls.ls_input_seal.text = value
		"dock":
			if ls.ls_input_dock != null: ls.ls_input_dock.text = value
		"expedition":
			if ls.ls_input_expedition != null: ls.ls_input_expedition.text = value


# ==========================================
# DISPLAY UPDATES
# ==========================================

func _refresh_all() -> void:
	_refresh_status()
	_refresh_action()
	_refresh_count()
	_refresh_progress()
	_refresh_buttons()


func _refresh_status() -> void:
	if _lbl_status == null:
		return
	var icon: String = "✓" if _record_passed else "✗"
	_lbl_status.text = (Locale.t("replay.title")
			+ "  —  " + _scenario_name
			+ "  " + icon + " " + str(_record_score))


func _refresh_action() -> void:
	if _lbl_action == null:
		return
	if _action_index <= 0 or _action_index > _action_log.size():
		_lbl_action.text = "—"
		return
	var entry: Dictionary = _action_log[_action_index - 1]
	var action: String = str(entry.get("action", ""))
	var detail: String = str(entry.get("detail", ""))
	var ts: String = _fmt_time(float(entry.get("time", 0.0)))
	_lbl_action.text = "► " + ts + "  " + _action_text(action, detail)


func _refresh_count() -> void:
	if _lbl_count == null:
		return
	_lbl_count.text = str(_action_index) + " / " + str(_action_log.size())


func _refresh_progress() -> void:
	if _total_session_time < 0.1:
		return
	var current_time: float = 0.0
	if _action_index > 0 and _action_index <= _action_log.size():
		current_time = float(_action_log[_action_index - 1].get("time", 0.0))
	var pct: float = clampf(current_time / _total_session_time, 0.0, 1.0)
	if _bar_progress != null:
		_bar_progress.anchor_right = pct
	if _lbl_timer != null:
		_lbl_timer.text = _fmt_time(current_time) + " / " + _fmt_time(_total_session_time)


func _refresh_buttons() -> void:
	if _btn_prev != null:
		_btn_prev.disabled = (_action_index <= 0)
	if _btn_next != null:
		_btn_next.disabled = (_action_index >= _action_log.size())
		_btn_next.text = Locale.t("replay.done") if _action_index >= _action_log.size() else Locale.t("replay.next")


# ==========================================
# HELPERS
# ==========================================

# Decisions logged as side-effects of workspace/dock/AS400 actions.
# These duplicate real actions already in the log and should not
# appear as separate replay steps.
const _SIDE_EFFECT_DECISIONS: Array[String] = [
	"Open Office", "Open Loading Sheet", "Open CMR",
	"Open CMR 2", "Open AS400", "Open Dock", "Close Dock",
	"Phone Opened",
]


static func _is_side_effect(entry: Dictionary) -> bool:
	## Returns true if this action log entry is a side-effect decision
	## that duplicates another action and should be skipped in replay.
	if str(entry.get("action", "")) != "decision":
		return false
	var detail: String = str(entry.get("detail", ""))
	if detail in _SIDE_EFFECT_DECISIONS:
		return true
	if detail.begins_with("Confirm AS400"):
		return true
	return false

static func _fmt_time(secs: float) -> String:
	var total: int = int(secs)
	@warning_ignore("integer_division")
	var m: int = total / 60
	var s: int = total % 60
	return "%d:%02d" % [m, s]


func _action_text(action: String, detail: String) -> String:
	match action:
		"load_pallet":
			return Locale.t("replay.act_load") + " #" + detail
		"unload_pallet":
			return Locale.t("replay.act_unload") + " #" + detail
		"undo_load":
			return Locale.t("replay.act_undo") + " #" + detail
		"workspace":
			return "→ " + detail
		"dock":
			return "Dock " + detail
		"decision":
			return detail
		"as400_state":
			var sname: String = ReplayScreenRenderer._as400_state_name(
					int(detail) if detail.is_valid_int() else -1)
			return "AS400 → " + sname
		"as400_dest":
			var dparts: PackedStringArray = detail.split(":", true, 2)
			if dparts.size() >= 3:
				return "AS400 dest → " + dparts[2] + " " + dparts[1]
			return "AS400 dest → " + detail
		"as400_seal":
			var ssep: int = detail.find(":")
			if ssep >= 0:
				return "AS400 seal → " + detail.substr(ssep + 1)
			return "AS400 seal → " + detail
		"cmr_field":
			return "CMR: " + detail
		"ls_field":
			return "LS: " + detail
		"cmr_franco":
			return "Franco → " + detail
		"tutorial_skip":
			return "Skip step " + detail
	return action + ": " + detail
