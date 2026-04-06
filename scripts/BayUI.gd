extends CanvasLayer
class_name BayUI

const PANEL_NAMES: Array[String] = [
	"Dock View", "Office", "AS400", "Trailer Capacity", "Phone", "Loading Sheet", "CMR"
]

@onready var top_time_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/TopTimeLabel
@onready var role_strip_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/RoleStripLabel
@onready var workspace_vbox: VBoxContainer = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox

@onready var btn_shift_board: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/ShiftBoardBtn
@onready var btn_loading_plan: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/LoadingPlanBtn
@onready var btn_as400: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/AS400Btn
@onready var btn_trailer_capacity: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/TrailerCapacityBtn
@onready var btn_phone: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PhoneBtn
@onready var btn_notes: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/NotesBtn

@onready var pnl_shift_board: PanelContainer = $Root/PanelOverlayLayer/ShiftBoardPanel
@onready var pnl_loading_plan: PanelContainer = $Root/PanelOverlayLayer/LoadingPlanPanel
@onready var pnl_trailer_capacity: PanelContainer = $Root/PanelOverlayLayer/TrailerCapacityPanel
@onready var pnl_phone: PanelContainer = $Root/PanelOverlayLayer/PhonePanel
@onready var pnl_notes: PanelContainer = $Root/PanelOverlayLayer/NotesPanel

var _enabled: bool = false
var _session: SessionManager = null
var _is_active: bool = false
var replay_mode: bool = false
var _strip_assignment: String = "Unassigned"
var _strip_window_active: bool = false
var _panel_state: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _panel_nodes: Dictionary = {}
var panels_ever_opened: Dictionary = {}

@warning_ignore("unused_private_class_variable")
var _current_scenario_name: String = ""
@warning_ignore("unused_private_class_variable")
var _current_scenario_index: int = 0
var highest_unlocked_scenario: int = 0

# --- PORTAL & STAGE CONTAINERS ---
var _portal: PortalScreen
var _dock: DockView
var _debrief: DebriefScreen
var _tut: TutorialOverlay

var top_actions_hbox: HBoxContainer
var _top_bar_hbox: HBoxContainer
var stage_hbox: HBoxContainer
var lbl_standby: Label
var pnl_as400_stage: PanelContainer

# GLOBAL BUTTON REFS
var btn_start_load: Button
var btn_call: Button
var btn_seal: Button
var btn_transit: Button = null
var btn_adr: Button = null
var btn_combine: Button = null
var btn_open_dock: Button = null
var btn_close_dock: Button = null
var _as400_confirmed: bool = false

@warning_ignore("unused_private_class_variable")
var _load_cooldown: bool = false
var btn_sop: Button
var btn_dock_view: Button
var btn_as400_dock: Button = null
var btn_dock_ls: Button = null
var btn_dock_cmr: Button = null

# --- UNDO SYSTEM ---
var _undo_pallet_id: String = ""
var _undo_remaining: float = 0.0
var _undo_btn: Button = null
const UNDO_WINDOW: float = 5.0

# --- WORKSPACE SYSTEM ---
@warning_ignore("unused_private_class_variable")
var _active_workspace: String = "DOCK"
var _dock_workspace: Control = null
var _office_workspace: Control = null
@warning_ignore("unused_private_class_variable")
var _tab_dock_btn: Button = null
@warning_ignore("unused_private_class_variable")
var _tab_office_btn: Button = null
@warning_ignore("unused_private_class_variable")
var _phone_btn_top: Button = null
var _dock_action_bar: HBoxContainer = null
@warning_ignore("unused_private_class_variable")
var _btn_abandon: Button
var _abandon_overlay: ColorRect

# --- TRANSITION SYSTEM ---
var _fade: FadeSystem

# --- AS400 TERMINAL ---
var _as400: AS400Terminal

# --- EXTRACTED CLASSES ---
var _paper: PaperworkForms
var _office: OfficeManager
var _lp_board: LoadingPlanBoard
var _sop: SOPModal
var _phone: PhoneSystem
var _flow: SessionFlow
var _ws: WorkspaceController
var _trainer: TrainerDashboard
var _tc: TutorialController
var _interruptions: InterruptionManager
var _quiz: PalletQuiz
var _drills: DrillManager
var _replay: GhostReplay

var tutorial_active: bool:
	get: return _tc.active
	set(v): _tc.active = v

var tutorial_step: int:
	get: return _tc.step
	set(v): _tc.step = v

# --- FORWARDING: store/destination data lives in SessionFlow ---
var store_destinations: Array:
	get: return _flow.store_destinations

var co_pairs: Array:
	get: return _flow.co_pairs

var current_dest_name: String:
	get: return _flow.current_dest_name
	set(v): _flow.current_dest_name = v

var current_dest_code: String:
	get: return _flow.current_dest_code
	set(v): _flow.current_dest_code = v

var current_dest2_name: String:
	get: return _flow.current_dest2_name
	set(v): _flow.current_dest2_name = v

var current_dest2_code: String:
	get: return _flow.current_dest2_code
	set(v): _flow.current_dest2_code = v

var seal_number_1: String:
	get: return _flow.seal_number_1
	set(v): _flow.seal_number_1 = v

var seal_number_2: String:
	get: return _flow.seal_number_2
	set(v): _flow.seal_number_2 = v

var phone_messages: Array:
	get: return _phone.messages


func _ready() -> void:
	_fade = FadeSystem.new(self)
	_paper = PaperworkForms.new(self)
	_office = OfficeManager.new(self)
	_lp_board = LoadingPlanBoard.new(self)
	_sop = SOPModal.new(self)
	_phone = PhoneSystem.new(self)
	_flow = SessionFlow.new(self)
	_ws = WorkspaceController.new(self)
	_trainer = TrainerDashboard.new(self)
	_tc = TutorialController.new(self)
	_interruptions = InterruptionManager.new(self)
	_quiz = PalletQuiz.new(self)
	_drills = DrillManager.new(self)
	_replay = GhostReplay.new(self)
	Locale.register_sop_database(_sop.sop_database)
	_debrief = DebriefScreen.new(self)
	_tut = TutorialOverlay.new(self)
	_dock = DockView.new(self)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(bg)
	$Root.move_child(bg, 0)

	var old_setup: Node = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel
	if old_setup: old_setup.visible = false
	var old_sit: Node = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel
	if old_sit: old_sit.visible = false
	var old_log: Node = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel
	if old_log: old_log.visible = false
	var old_hint: Node = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/HintLabel
	if old_hint: old_hint.visible = false
	var old_raq_btn: Node = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/RAQBtn
	if old_raq_btn:
		old_raq_btn.get_parent().remove_child(old_raq_btn)
		old_raq_btn.queue_free()

	# --- STYLE: Top bar ---
	var top_bar: Node = $Root/FrameVBox/TopBar
	if top_bar:
		var tb_sb := UIStyles.flat(Color(0.08, 0.09, 0.11))
		tb_sb.border_width_bottom = 1
		tb_sb.border_color = Color(0.2, 0.22, 0.25)
		top_bar.add_theme_stylebox_override("panel", tb_sb)
	if top_time_label:
		top_time_label.add_theme_font_size_override("font_size", UITokens.fs(15))
		top_time_label.add_theme_color_override("font_color", UITokens.hc_text(Color(0.7, 0.75, 0.8)))
	if role_strip_label:
		role_strip_label.add_theme_font_size_override("font_size", UITokens.fs(13))
		role_strip_label.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_MID))

	# Audio toggle
	_top_bar_hbox = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox
	if _top_bar_hbox:
		var audio_btn: Button = Button.new()
		audio_btn.text = "🔊"
		audio_btn.custom_minimum_size = Vector2(36, 28)
		audio_btn.add_theme_font_size_override("font_size", UITokens.fs(16))
		UIStyles.apply_btn(audio_btn, UITokens.CLR_BG_DARK, UITokens.CLR_SURFACE_DIM,
				UITokens.CLR_BG_DARK, UITokens.CLR_WHITE, UITokens.CLR_WHITE, 4)
		audio_btn.pressed.connect(func() -> void:
			var enabled: bool = not WOTSAudio._enabled
			WOTSAudio.set_enabled(enabled)
			audio_btn.text = "🔊" if enabled else "🔇"
		)
		_top_bar_hbox.add_child(audio_btn)

	_ws.build_workspace_tabs()

	# --- HIDE OLD SIDEBAR ---
	var old_sidebar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if old_sidebar != null:
		old_sidebar.visible = false
		old_sidebar.custom_minimum_size = Vector2.ZERO
		old_sidebar.size_flags_horizontal = 0

	# --- ABANDON SHIFT BUTTON + OVERLAY ---
	_flow.build_abandon_ui($Root)

	_build_start_portal()
	_build_operational_layout()
	_debrief._build($Root)
	_sop._build_sop_modal()
	_tut._build()
	_interruptions.build_overlay($Root)
	_phone.build_toast_overlay($Root)
	_drills.build($Root)
	_replay._build($Root)
	_ws.style_overlay_panels()

	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)


func _process(delta: float) -> void:
	if replay_mode:
		_replay.tick(delta)
		return
	_interruptions.tick(delta)
	_phone.tick_toast(delta)
	_drills.tick(delta)
	_replay.tick(delta)

	# Undo window countdown
	if _undo_remaining > 0.0:
		_undo_remaining -= delta
		if _undo_remaining <= 0.0:
			_undo_pallet_id = ""
			_undo_remaining = 0.0
			if _undo_btn != null:
				_undo_btn.visible = false
		elif _undo_btn != null and _undo_btn.visible:
			_undo_btn.text = Locale.t("btn.undo") + " (%ds)" % ceili(_undo_remaining)

	if tutorial_active:
		# Pause hint timer when SOP overlay is open — user is reading help
		var sop_open: bool = _sop.overlay != null and _sop.overlay.visible
		if not sop_open:
			_tut.tick(delta)
		if _tut._target_node != null and is_instance_valid(_tut._target_node) and _tut._target_node.is_visible_in_tree() and not sop_open:
			_tut.highlight_box.visible = true
			var pos: Vector2 = _tut._target_node.global_position - Vector2(4, 4)
			pos.x = maxf(pos.x, 0.0)
			pos.y = maxf(pos.y, 0.0)
			_tut.highlight_box.global_position = pos
			_tut.highlight_box.size = _tut._target_node.size + Vector2(8, 8)
		elif _tut.highlight_box != null:
			_tut.highlight_box.visible = false
	elif _tut.highlight_box != null:
		_tut.highlight_box.visible = false


func _input(event: InputEvent) -> void:
	if replay_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_replay.stop_replay()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Interruption overlay cannot be dismissed
			if _interruptions.is_blocking():
				return
			if _abandon_overlay != null and _abandon_overlay.visible:
				_abandon_overlay.visible = false
			elif _drills._sel_overlay != null and _drills._sel_overlay.visible:
				_drills._sel_overlay.visible = false
			elif _drills._res_overlay != null and _drills._res_overlay.visible:
				pass  # Must click "Return to Portal"
			elif _quiz.overlay != null and _quiz.overlay.visible:
				_quiz.close_quiz()
			elif _trainer.overlay != null and _trainer.overlay.visible:
				_trainer.hide()
			elif _sop.overlay != null and _sop.overlay.visible:
				_sop._close_sop_modal()
			elif _debrief.overlay != null and _debrief.overlay.visible:
				pass
			elif _portal.overlay != null and _portal.overlay.visible:
				pass
			elif _ws.is_dock_paperwork_open():
				_ws.hide_dock_paperwork()
				WOTSAudio.play_panel_click(self)
			else:
				var closed_one: bool = false
				if bool(_panel_state.get("Phone", false)):
					_ws.set_panel_visible("Phone", false, false)
					closed_one = true
				elif bool(_panel_state.get("AS400", false)):
					_ws.set_panel_visible("AS400", false, false)
					closed_one = true
				if closed_one:
					WOTSAudio.play_panel_click(self)
		elif event.keycode in [KEY_F3, KEY_F10, KEY_F6, KEY_F13] or (event.keycode == KEY_F1 and event.shift_pressed):
			if _as400 != null and _as400.handle_fkey(event.keycode, event.shift_pressed):
				return
		elif _can_use_shortcuts() and not _has_text_focus():
			# --- KEYBOARD SHORTCUTS ---
			# During drills, allow SOP (H), AS400 toggle (3), and F-keys only
			if _drills.is_active:
				if event.keycode == KEY_H:
					_sop._open_sop_modal()
				elif event.keycode == KEY_3:
					_ws.toggle_panel("AS400")
				return
			if event.keycode == KEY_1:
				_ws.switch_workspace("DOCK")
			elif event.keycode == KEY_2:
				_ws.switch_workspace("OFFICE")
			elif event.keycode == KEY_3:
				_ws.toggle_panel("AS400")
			elif event.keycode == KEY_4:
				_ws.toggle_panel("Loading Sheet")
			elif event.keycode == KEY_5:
				_ws.toggle_panel("CMR")
			elif event.keycode == KEY_P:
				_ws.toggle_panel("Phone")
			elif event.keycode == KEY_H:
				_sop._open_sop_modal()
			elif event.keycode == KEY_F12 and OS.is_debug_build():
				ScenarioTest.run_all_print()


func _has_text_focus() -> bool:
	## Returns true if a text input control currently has focus.
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _can_use_shortcuts() -> bool:
	## Returns true if keyboard shortcuts are allowed (no overlay blocking).
	if not _is_active: return false
	if _portal.overlay != null and _portal.overlay.visible: return false
	if _debrief.overlay != null and _debrief.overlay.visible: return false
	if _interruptions.is_blocking(): return false
	if _abandon_overlay != null and _abandon_overlay.visible: return false
	if _sop.overlay != null and _sop.overlay.visible: return false
	if _trainer.overlay != null and _trainer.overlay.visible: return false
	if _quiz.overlay != null and _quiz.overlay.visible: return false
	if _drills._sel_overlay != null and _drills._sel_overlay.visible: return false
	if _drills._res_overlay != null and _drills._res_overlay.visible: return false
	return true


# ==========================================
# BUILD METHODS
# ==========================================

func _build_start_portal() -> void:
	_portal = PortalScreen.new(self)
	_portal._build($Root)
	_portal._build_briefing($Root)
	_connect_portal_signals()
	_trainer._build($Root)
	_quiz.build($Root)


func _connect_portal_signals() -> void:
	_portal.scenario_dropdown.item_selected.connect(_flow.on_portal_scenario_changed)
	_portal.language_dropdown.item_selected.connect(_flow.on_portal_language_changed)
	_portal.btn_start.pressed.connect(_flow.on_portal_start_pressed)
	_portal.btn_briefing_continue.pressed.connect(_flow.on_briefing_continue_pressed)
	_portal.btn_dev.pressed.connect(func() -> void:
		highest_unlocked_scenario = 3
		_flow.populate_scenarios()
	)
	_portal.btn_trainer.pressed.connect(func() -> void: _trainer.show())
	_portal.btn_quiz.pressed.connect(func() -> void: _quiz.start_quiz())
	_portal.btn_drill.pressed.connect(func() -> void: _drills.open_selection())


func rebuild_portal() -> void:
	_portal.rebuild()
	_connect_portal_signals()
	_flow.populate_scenarios()


func _on_login_success() -> void:
	_portal._apply_login_visibility()
	_portal.refresh_history()
	_flow.populate_scenarios()


func _build_operational_layout() -> void:
	# === DOCK WORKSPACE ===
	_dock_workspace = Control.new()
	_dock_workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dock_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_vbox.add_child(_dock_workspace)

	var dock_vbox: VBoxContainer = VBoxContainer.new()
	dock_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_vbox.add_theme_constant_override("separation", 0)
	_dock_workspace.add_child(dock_vbox)

	stage_hbox = HBoxContainer.new()
	stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_hbox.add_theme_constant_override("separation", 0)
	stage_hbox.visible = true
	dock_vbox.add_child(stage_hbox)

	lbl_standby = Label.new()
	lbl_standby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_standby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_standby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_standby.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_standby.text = Locale.t("standby.message")
	lbl_standby.add_theme_color_override("font_color", UITokens.hc_text(UITokens.COLOR_TEXT_META))
	lbl_standby.add_theme_font_size_override("font_size", UITokens.fs(22))
	stage_hbox.add_child(lbl_standby)

	# Dock action bar
	_dock_action_bar = HBoxContainer.new()
	_dock_action_bar.add_theme_constant_override("separation", 8)
	_dock_action_bar.visible = false
	var action_bar_bg: PanelContainer = PanelContainer.new()
	var ab_sb := UIStyles.flat_m(Color(0.08, 0.09, 0.1, 0.92), 16, 6, 16, 6)
	ab_sb.border_width_top = 1
	ab_sb.border_color = UITokens.CLR_SURFACE_DIM
	UIStyles.apply_panel(action_bar_bg, ab_sb)
	dock_vbox.add_child(action_bar_bg)
	action_bar_bg.add_child(_dock_action_bar)
	top_actions_hbox = _dock_action_bar

	# Action buttons — unified style, primary actions get blue accent
	var bar_border_c: Color = UITokens.CLR_SURFACE_MID
	var bar_bg_c: Color = UITokens.CLR_INPUT_BG
	var make_btn: Callable = func(text: String, primary: bool) -> Button:
		var b: Button = Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_font_size_override("font_size", UITokens.fs(12))
		if primary:
			UIStyles.apply_btn_auto(b, bar_bg_c,
					UITokens.CLR_BLUE_LIGHT, Color.WHITE, 6,
					1, UITokens.COLOR_ACCENT_BLUE)
		else:
			UIStyles.apply_btn_auto(b, bar_bg_c,
					Color(0.78, 0.8, 0.85), Color.WHITE, 6,
					1, bar_border_c)
		return b

	btn_as400_dock = make_btn.call("AS400", false)
	btn_as400_dock.tooltip_text = Locale.t("shortcut.as400")
	btn_as400_dock.pressed.connect(func() -> void: _ws.toggle_panel("AS400"))
	_dock_action_bar.add_child(btn_as400_dock)

	btn_dock_ls = make_btn.call("LS", false)
	btn_dock_ls.tooltip_text = Locale.t("shortcut.ls")
	btn_dock_ls.pressed.connect(func() -> void: _ws.toggle_panel("Loading Sheet"))
	_dock_action_bar.add_child(btn_dock_ls)

	btn_dock_cmr = make_btn.call("CMR", false)
	btn_dock_cmr.tooltip_text = Locale.t("shortcut.cmr")
	btn_dock_cmr.pressed.connect(func() -> void: _ws.toggle_panel("CMR"))
	_dock_action_bar.add_child(btn_dock_cmr)

	# Vertical separator
	var bar_sep := ColorRect.new()
	bar_sep.custom_minimum_size = Vector2(1, 20)
	bar_sep.color = UITokens.CLR_SURFACE_MID
	_dock_action_bar.add_child(bar_sep)

	btn_open_dock = make_btn.call("Open Dock", true)
	btn_open_dock.pressed.connect(func() -> void: _on_open_dock_pressed())
	_dock_action_bar.add_child(btn_open_dock)

	btn_start_load = make_btn.call(Locale.t("btn.start_loading"), true)
	btn_start_load.pressed.connect(func() -> void: _on_decision_pressed("Start Loading"))
	_dock_action_bar.add_child(btn_start_load)

	btn_call = make_btn.call(Locale.t("btn.call_depts"), false)
	btn_call.pressed.connect(func() -> void: _on_decision_pressed("Call departments (C&C check)"))
	_dock_action_bar.add_child(btn_call)

	btn_seal = make_btn.call(Locale.t("btn.seal_truck"), true)
	btn_seal.pressed.connect(func() -> void: _on_decision_pressed("Seal Truck"))
	btn_seal.visible = false
	_dock_action_bar.add_child(btn_seal)

	btn_close_dock = make_btn.call("Close Dock", false)
	btn_close_dock.pressed.connect(func() -> void: _on_close_dock_pressed())
	btn_close_dock.visible = false
	_dock_action_bar.add_child(btn_close_dock)

	btn_transit = make_btn.call(Locale.t("btn.check_transit"), false)
	btn_transit.pressed.connect(func() -> void: _on_decision_pressed("Check Transit"))
	btn_transit.visible = false
	btn_transit.disabled = true
	_dock_action_bar.add_child(btn_transit)

	btn_adr = make_btn.call(Locale.t("btn.check_adr"), false)
	btn_adr.pressed.connect(func() -> void: _on_decision_pressed("Check Yellow Lockers"))
	btn_adr.visible = false
	btn_adr.disabled = true
	btn_adr.add_theme_stylebox_override("normal",
			UIStyles.flat(Color(0.18, 0.12, 0.06), 6, 1, Color(0.9, 0.4, 0.0)))
	btn_adr.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	_dock_action_bar.add_child(btn_adr)

	btn_combine = make_btn.call(Locale.t("btn.combine"), false)
	btn_combine.pressed.connect(func() -> void: _on_decision_pressed("Combine Pallets"))
	btn_combine.visible = false
	btn_combine.disabled = true
	btn_combine.add_theme_stylebox_override("normal",
			UIStyles.flat(Color(0.06, 0.16, 0.08), 6, 1, UITokens.CLR_SUCCESS))
	btn_combine.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
	_dock_action_bar.add_child(btn_combine)

	# --- UNDO BUTTON ---
	_undo_btn = make_btn.call(Locale.t("btn.undo"), false)
	_undo_btn.visible = false
	_undo_btn.add_theme_stylebox_override("normal",
			UIStyles.flat(Color(0.2, 0.15, 0.06), 6, 1, UITokens.CLR_AMBER))
	_undo_btn.add_theme_color_override("font_color", UITokens.CLR_AMBER)
	_undo_btn.pressed.connect(func() -> void: _perform_undo())
	_dock_action_bar.add_child(_undo_btn)

	# === OFFICE WORKSPACE ===
	_office_workspace = _office.build_workspace(workspace_vbox)

	btn_sop = Button.new()
	btn_sop.text = Locale.t("btn.help_sops")
	btn_sop.tooltip_text = Locale.t("shortcut.help")
	btn_sop.custom_minimum_size = Vector2(110, 28)
	btn_sop.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn(btn_sop, Color(0.12, 0.3, 0.55), UITokens.COLOR_ACCENT_BLUE,
			Color(0.08, 0.2, 0.4), Color(0.7, 0.8, 0.95), Color.WHITE, 4)
	btn_sop.pressed.connect(_sop._open_sop_modal)
	if _top_bar_hbox != null:
		_top_bar_hbox.add_child(btn_sop)

	_dock._build(stage_hbox)
	_build_as400_stage()
	_ws.build_dock_paperwork_overlay()

	btn_dock_view = Button.new()
	btn_dock_view.text = Locale.t("btn.dock_view")
	btn_dock_view.visible = false

	_ws.init_panel_nodes_and_buttons(btn_dock_view)
	_fade.build_fade_overlay()


func _build_as400_stage() -> void:
	_as400 = AS400Terminal.new(self, stage_hbox)
	_as400._build_as400_stage()
	pnl_as400_stage = _as400.panel
	_as400.raq_opened.connect(_on_raq_opened)


# ==========================================
# SESSION & SIGNAL HANDLERS
# ==========================================

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled: return
	if _portal.overlay != null: _portal.overlay.visible = true
	if _portal.btn_start != null: _portal.btn_start.disabled = false
	if _portal.btn_briefing_continue != null: _portal.btn_briefing_continue.disabled = false


func set_session(session: SessionManager) -> void:
	# Disconnect old session signals if re-assigned
	if _session != null:
		if _session.time_updated.is_connected(_on_time_updated):
			_session.time_updated.disconnect(_on_time_updated)
		if _session.session_ended.is_connected(_flow.on_session_ended):
			_session.session_ended.disconnect(_flow.on_session_ended)
		if _session.role_updated.is_connected(_on_role_updated):
			_session.role_updated.disconnect(_on_role_updated)
		if _session.responsibility_boundary_updated.is_connected(_on_boundary_updated):
			_session.responsibility_boundary_updated.disconnect(_on_boundary_updated)
		if _session.inventory_updated.is_connected(_on_inventory_updated):
			_session.inventory_updated.disconnect(_on_inventory_updated)
		if _session.phone_notification.is_connected(_phone.on_notification):
			_session.phone_notification.disconnect(_phone.on_notification)
		if _session.phone_pallets_delivered.is_connected(_phone.on_pallets_delivered):
			_session.phone_pallets_delivered.disconnect(_phone.on_pallets_delivered)
	_session = session
	_flow.populate_scenarios()
	if _session != null:
		_session.time_updated.connect(_on_time_updated)
		_session.session_ended.connect(_flow.on_session_ended)
		_session.role_updated.connect(_on_role_updated)
		_session.responsibility_boundary_updated.connect(_on_boundary_updated)
		_session.inventory_updated.connect(_on_inventory_updated)
		_session.phone_notification.connect(_phone.on_notification)
		_session.phone_pallets_delivered.connect(_phone.on_pallets_delivered)


func _refresh_combine_btn() -> void:
	if btn_combine == null or _session == null: return
	if not btn_combine.visible: return
	btn_combine.disabled = not _session.has_combine_pair()


func _populate_overlay_panels() -> void:
	_ws.populate_overlay_panels()


func _on_debrief_closed() -> void:
	_flow.on_debrief_closed()


func _on_raq_opened() -> void:
	var dest_seq: int = _as400._get_tab_dest_seq(_as400._active_tab)
	if _session != null:
		_session.mark_raq_viewed(dest_seq)
	if btn_transit != null and btn_transit.visible:
		btn_transit.disabled = false
	if btn_adr != null and btn_adr.visible:
		btn_adr.disabled = false


func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)


func _update_top_time(total_time: float) -> void:
	if top_time_label == null: return
	var base: int = 31500
	if _session != null: base = _session.clock_base_seconds
	var abs_secs: int = base + int(total_time)
	@warning_ignore("integer_division")
	var hours: int = abs_secs / 3600
	@warning_ignore("integer_division")
	var mins: int = (abs_secs % 3600) / 60
	var secs: int = abs_secs % 60
	top_time_label.text = "%02d:%02d:%02d" % [hours, mins, secs]


func _on_role_updated(_role_id: int) -> void:
	_update_strip_text()


func _on_boundary_updated(_role_id: int, assignment_text: String, window_active: bool) -> void:
	_strip_assignment = assignment_text
	_strip_window_active = window_active
	_update_strip_text()


func _update_strip_text() -> void:
	if role_strip_label == null: return
	var window_text := "Not Active"
	if _strip_window_active: window_text = "Active"
	var trainee: String = TrainingRecord.get_trainee_display_name()
	role_strip_label.text = trainee + "  ·  " + Locale.t("dock.assignment") % [_strip_assignment, window_text]


func _on_inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	_as400.last_avail_cache = avail.duplicate(true)
	_as400.last_loaded_cache = loaded.duplicate(true)
	_refresh_combine_btn()
	_paper.update_loading_sheet()
	_paper.update_cmr()

	if _as400.state == AS400Terminal.S.RAQ or _as400.state == AS400Terminal.S.SCANNING:
		_as400._render_as400_screen()

	_dock.populate(avail, loaded, cap_used, cap_max)

	# Emballage status
	if _session != null and _dock.lbl_hover_info and _dock.is_dock_open():
		if _session.emballage_remaining > 0:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_WARNING + "[b]" + (Locale.t("dock.emballage_count") % str(_session.emballage_remaining)) + "[/b]" + UITokens.BB_END + "\n" + UITokens.BB_MUTED + Locale.t("dock.emballage_remove") + UITokens.BB_END + "[/font_size]"
		elif _session.emballage_initial > 0 and not _session.loading_started:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_SUCCESS + "[b]" + Locale.t("dock.emballage_cleared") + "[/b]" + UITokens.BB_END + " " + UITokens.BB_MUTED + Locale.t("dock.emballage_cleared_detail") + UITokens.BB_END + "[/font_size]"

	if tutorial_active:
		_tut.reset_hint_timer()
		_tc.try_advance_inventory(avail, loaded)


# ==========================================
# DOCK OPERATIONS
# ==========================================

func _on_open_dock_pressed() -> void:
	if _dock.is_dock_open(): return
	_dock.open_dock()
	WOTSAudio.play_dock_open(self)
	if _session != null:
		_session.log_action("dock", "open")
	if btn_open_dock != null: btn_open_dock.visible = false
	if _session != null and _session.emballage_remaining > 0 and _dock.lbl_hover_info:
		_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_WARNING + "[b]" + (Locale.t("dock.emballage_count") % str(_session.emballage_remaining)) + "[/b]" + UITokens.BB_END + "\n" + UITokens.BB_MUTED + Locale.t("dock.emballage_remove") + " " + Locale.t("dock.emballage_remove_click") + UITokens.BB_END + "[/font_size]"
	if tutorial_active and tutorial_step == 4:
		_tc.try_advance_dock_open()


func _on_close_dock_pressed() -> void:
	if not _dock.is_dock_open(): return
	if not _as400_confirmed:
		if _dock.lbl_hover_info:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_ERROR + "[b]" + Locale.t("dock.confirm_as400") + "[/b]" + UITokens.BB_END + " " + UITokens.BB_MUTED + Locale.t("dock.confirm_as400_detail") + UITokens.BB_END + "[/font_size]"
		WOTSAudio.play_error_buzz(self)
		return
	_dock.close_dock()
	WOTSAudio.play_dock_close(self)
	if _session != null:
		_session.log_action("dock", "close")
	if btn_close_dock != null: btn_close_dock.visible = false
	_office.set_office_phase_wrapup()
	if tutorial_active and tutorial_step == 20:
		_tc.try_advance_dock_close()


func _on_decision_pressed(action: String) -> void:
	if tutorial_active:
		if not _tc.try_advance_decision(action):
			return

	if _session == null: return
	if action == "Start Loading" and not _dock.is_dock_open():
		WOTSAudio.play_error_buzz(self)
		if _dock.lbl_hover_info:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_ERROR + "[b]" + Locale.t("dock.not_open") + "[/b]" + UITokens.BB_END + " " + UITokens.BB_MUTED + Locale.t("dock.not_open_detail") + UITokens.BB_END + "[/font_size]"
		return
	if action == "Start Loading" and _session.emballage_remaining > 0:
		WOTSAudio.play_error_buzz(self)
		if _dock.lbl_hover_info:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_ERROR + "[b]" + Locale.t("dock.emballage_blocked") + "[/b]" + UITokens.BB_END + " " + UITokens.BB_MUTED + (Locale.t("dock.emballage_blocked_detail") % str(_session.emballage_remaining)) + UITokens.BB_END + "[/font_size]"
		return
	_session.manual_decision(action)
	if action == "Seal Truck":
		WOTSAudio.play_seal_confirm(self)
	elif action == "Call departments (C&C check)":
		WOTSAudio.play_scan_beep(self)
	elif action == "Start Loading":
		WOTSAudio.play_panel_click(self)
		if btn_combine != null and btn_combine.visible:
			_refresh_combine_btn()
	elif action == "Check Transit":
		if btn_transit != null: btn_transit.disabled = true
	elif action == "Check Yellow Lockers":
		if btn_adr != null: btn_adr.disabled = true
	elif action == "Combine Pallets":
		WOTSAudio.play_scan_beep(self)
		_refresh_combine_btn()


func _start_undo_window(pallet_id: String) -> void:
	## Begin the 5-second undo window for the most recently loaded pallet.
	_undo_pallet_id = pallet_id
	_undo_remaining = UNDO_WINDOW
	if _undo_btn != null:
		_undo_btn.text = Locale.t("btn.undo") + " (%ds)" % ceili(UNDO_WINDOW)
		_undo_btn.visible = true


func _perform_undo() -> void:
	## Execute the undo — remove last loaded pallet without penalty.
	if _undo_pallet_id == "" or _session == null:
		return
	if _session.undo_last_load(_undo_pallet_id):
		WOTSAudio.play_undo_confirm(self)
		if _dock.lbl_hover_info:
			_dock.lbl_hover_info.text = "[font_size=15]" + UITokens.BB_SUCCESS + "[b]" + Locale.t("dock.undo_success") + "[/b]" + UITokens.BB_END + "[/font_size]"
	_undo_pallet_id = ""
	_undo_remaining = 0.0
	if _undo_btn != null:
		_undo_btn.visible = false
