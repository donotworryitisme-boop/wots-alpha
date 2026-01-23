extends CanvasLayer

signal trust_contract_requested

const PANEL_NAMES: Array[String] = [
	"Shift Board",
	"Loading Plan",
	"AS400",
	"Trailer Capacity",
	"RAQ",
	"Phone",
	"Notes"
]

@onready var top_time_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/TopTimeLabel
@onready var role_strip_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/RoleStripLabel

@onready var scenario_dropdown: OptionButton = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/ScenarioRow/ScenarioDropdown
@onready var role_dropdown: OptionButton = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/RoleRow/RoleDropdown
@onready var start_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/ButtonsRow/StartButton
@onready var end_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/ButtonsRow/EndButton
@onready var trust_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/TrustContractButton
@onready var what_to_do_label: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel/SetupMargin/SetupVBox/WhatToDoPanel/WhatToDoMargin/WhatToDoLabel

@onready var hint_label: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/HintLabel

@onready var situation_panel: PanelContainer = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel
@onready var time_label: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel/SituationMargin/SituationVBox/TimeLabel
@onready var objective_label: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel/SituationMargin/SituationVBox/ObjectiveLabel

@onready var check_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel/SituationMargin/SituationVBox/DecisionRow/CheckButton
@onready var escalate_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel/SituationMargin/SituationVBox/DecisionRow/EscalateButton
@onready var proceed_button: Button = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel/SituationMargin/SituationVBox/DecisionRow/ProceedButton

@onready var log_title: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/LogTitle
@onready var explain_toggle: CheckButton = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/ExplainWhyToggle
@onready var log_text: RichTextLabel = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/LogText

# Toggle buttons
@onready var btn_shift_board: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/ShiftBoardBtn
@onready var btn_loading_plan: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/LoadingPlanBtn
@onready var btn_as400: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/AS400Btn
@onready var btn_trailer_capacity: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/TrailerCapacityBtn
@onready var btn_raq: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/RAQBtn
@onready var btn_phone: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PhoneBtn
@onready var btn_notes: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/NotesBtn

# Overlay panels
@onready var pnl_shift_board: PanelContainer = $Root/PanelOverlayLayer/ShiftBoardPanel
@onready var pnl_loading_plan: PanelContainer = $Root/PanelOverlayLayer/LoadingPlanPanel
@onready var pnl_as400: PanelContainer = $Root/PanelOverlayLayer/AS400Panel
@onready var pnl_trailer_capacity: PanelContainer = $Root/PanelOverlayLayer/TrailerCapacityPanel
@onready var pnl_raq: PanelContainer = $Root/PanelOverlayLayer/RAQPanel
@onready var pnl_phone: PanelContainer = $Root/PanelOverlayLayer/PhonePanel
@onready var pnl_notes: PanelContainer = $Root/PanelOverlayLayer/NotesPanel

var _enabled: bool = false
var _session: SessionManager = null
var _is_active: bool = false

var _debrief_what_happened: String = ""
var _debrief_why_it_mattered: String = ""

# 8.5 strip state
var _strip_assignment: String = "Unassigned"
var _strip_window_active: bool = false

# Per-session panel state (open/closed)
var _panel_state: Dictionary = {} # name -> bool
var _panel_nodes: Dictionary = {} # name -> PanelContainer

func _ready() -> void:
	set_enabled(false)
	_reset_panel_state()

	if trust_button != null:
		trust_button.pressed.connect(func() -> void:
			trust_contract_requested.emit()
		)

	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if end_button != null:
		end_button.pressed.connect(_on_end_pressed)

	if check_button != null:
		check_button.pressed.connect(func() -> void: _on_decision_pressed("Check transit / lines"))
	if escalate_button != null:
		escalate_button.pressed.connect(func() -> void: _on_decision_pressed("Call captain"))
	if proceed_button != null:
		proceed_button.pressed.connect(func() -> void: _on_decision_pressed("Load what's available"))

	if explain_toggle != null:
		explain_toggle.toggled.connect(_on_explain_toggled)

	_init_panel_nodes_and_buttons()

	_set_setup_guidance()
	_update_top_time(0.0)
	_update_strip_text()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

	if trust_button != null:
		trust_button.disabled = false

	if start_button != null:
		start_button.disabled = not enabled
	if scenario_dropdown != null:
		scenario_dropdown.disabled = not enabled
	if role_dropdown != null:
		role_dropdown.disabled = not enabled

	if end_button != null:
		end_button.disabled = true

	if situation_panel != null:
		situation_panel.visible = false

	_is_active = false
	_set_setup_guidance()

	if hint_label != null:
		hint_label.text = ""

	if log_title != null:
		log_title.text = "Learning summary"
	if log_text != null:
		log_text.text = ""
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false

	_close_all_panels(true)

func set_session(session: SessionManager) -> void:
	_session = session
	_populate_scenarios()
	_populate_roles()

	if _session != null and _session.has_method("register_panel_catalog"):
		_session.call("register_panel_catalog", PANEL_NAMES)

	if _session != null:
		if _session.has_signal("hint_updated"):
			_session.connect("hint_updated", Callable(self, "_on_hint_updated"))
		if _session.has_signal("time_updated"):
			_session.connect("time_updated", Callable(self, "_on_time_updated"))
		if _session.has_signal("situation_updated"):
			_session.connect("situation_updated", Callable(self, "_on_situation_updated"))
		if _session.has_signal("session_ended"):
			_session.connect("session_ended", Callable(self, "_on_session_ended"))
		if _session.has_signal("action_registered"):
			_session.connect("action_registered", Callable(self, "_on_action_registered"))
		if _session.has_signal("role_updated"):
			_session.connect("role_updated", Callable(self, "_on_role_updated"))
		if _session.has_signal("responsibility_boundary_updated"):
			_session.connect("responsibility_boundary_updated", Callable(self, "_on_boundary_updated"))

func _populate_scenarios() -> void:
	if scenario_dropdown == null or _session == null:
		return
	scenario_dropdown.clear()

	var names: Array[String] = []
	if _session.scenario_loader != null and _session.scenario_loader.has_method("get_scenario_names"):
		names = _session.scenario_loader.call("get_scenario_names")
	else:
		names = ["default"]

	for n in names:
		scenario_dropdown.add_item(n)

func _populate_roles() -> void:
	if role_dropdown == null:
		return
	role_dropdown.clear()
	role_dropdown.add_item("Operator", WOTSConfig.Role.OPERATOR)
	role_dropdown.add_item("Captain", WOTSConfig.Role.CAPTAIN)
	role_dropdown.add_item("Trainer", WOTSConfig.Role.TRAINER)
	role_dropdown.select(0)

func _on_start_pressed() -> void:
	if not _enabled or _session == null:
		return

	var scenario_name: String = "default"
	if scenario_dropdown != null:
		scenario_name = scenario_dropdown.get_item_text(scenario_dropdown.get_selected_id())

	var role_id: int = WOTSConfig.Role.OPERATOR
	if role_dropdown != null:
		role_id = role_dropdown.get_selected_id()

	_session.set_role(role_id)

	_is_active = true
	_set_active_guidance()

	_reset_panel_state()
	_close_all_panels(true)

	if situation_panel != null:
		situation_panel.visible = true

	if end_button != null:
		end_button.disabled = false
	if start_button != null:
		start_button.disabled = true

	if log_title != null:
		log_title.text = "Learning summary"
	if log_text != null:
		log_text.text = "[b]What to do:[/b]\nStart the scenario, use actions, then end to review.\n"
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false

	_session.call("start_session_with_scenario", scenario_name)

func _on_end_pressed() -> void:
	if _session == null:
		return
	_session.end_session()

func _on_decision_pressed(action: String) -> void:
	if _session == null:
		return
	_session.call("manual_decision", action)

func _on_hint_updated(hint_text: String) -> void:
	if hint_label != null:
		hint_label.text = hint_text

func _on_time_updated(total_time: float, loading_time: float) -> void:
	_update_top_time(total_time)
	if time_label != null:
		time_label.text = "Time: %0.2fs (Loading: %0.2fs)" % [total_time, loading_time]

func _on_situation_updated(objective_text: String) -> void:
	if objective_label != null:
		objective_label.text = "Objective: " + objective_text

func _on_action_registered(one_line: String) -> void:
	if log_text == null:
		return
	log_text.text += one_line + "\n"

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_set_setup_guidance()

	if situation_panel != null:
		situation_panel.visible = false

	if start_button != null:
		start_button.disabled = false
	if end_button != null:
		end_button.disabled = true

	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))

	if log_title != null:
		log_title.text = "Learning summary"

	if explain_toggle != null:
		explain_toggle.visible = _debrief_why_it_mattered.strip_edges() != ""
		explain_toggle.button_pressed = false

	_render_debrief(false)

func _on_explain_toggled(pressed: bool) -> void:
	_render_debrief(pressed)

func _render_debrief(show_why: bool) -> void:
	if log_text == null:
		return

	var bb := "[b]Learning summary[/b]\n\n"
	bb += "[b]What happened[/b]\n"
	bb += _debrief_what_happened + "\n"

	if show_why and _debrief_why_it_mattered.strip_edges() != "":
		bb += "\n[b]Why it mattered[/b]\n"
		bb += _debrief_why_it_mattered + "\n"

	log_text.text = bb

func _set_setup_guidance() -> void:
	if what_to_do_label != null:
		what_to_do_label.text = "Pick a scenario and role, then start."

func _set_active_guidance() -> void:
	if what_to_do_label != null:
		what_to_do_label.text = "Use actions to manage priorities and uncertainty. End to review learning summary."

func _update_top_time(total_time: float) -> void:
	if top_time_label != null:
		top_time_label.text = "Time: %0.2fs" % total_time

func _on_role_updated(_role_id: int) -> void:
	_update_strip_text()

func _on_boundary_updated(role_id: int, assignment_text: String, window_active: bool) -> void:
	_strip_assignment = assignment_text
	_strip_window_active = window_active
	_update_strip_text()

func _update_strip_text() -> void:
	if role_strip_label == null:
		return

	var role_name := "Operator"
	if role_dropdown != null:
		match role_dropdown.get_selected_id():
			WOTSConfig.Role.OPERATOR:
				role_name = "Operator"
			WOTSConfig.Role.CAPTAIN:
				role_name = "Captain"
			WOTSConfig.Role.TRAINER:
				role_name = "Trainer"

	var window_text := "Not Active"
	if _strip_window_active:
		window_text = "Active"

	# Neutral language only.
	role_strip_label.text = "Role: %s | Assignment: %s | Window: %s" % [role_name, _strip_assignment, window_text]

# ------------------------------
# Attention Panels (8.4)

func _init_panel_nodes_and_buttons() -> void:
	_panel_nodes.clear()
	_panel_nodes["Shift Board"] = pnl_shift_board
	_panel_nodes["Loading Plan"] = pnl_loading_plan
	_panel_nodes["AS400"] = pnl_as400
	_panel_nodes["Trailer Capacity"] = pnl_trailer_capacity
	_panel_nodes["RAQ"] = pnl_raq
	_panel_nodes["Phone"] = pnl_phone
	_panel_nodes["Notes"] = pnl_notes

	if btn_shift_board != null:
		btn_shift_board.pressed.connect(func() -> void: _toggle_panel("Shift Board"))
	if btn_loading_plan != null:
		btn_loading_plan.pressed.connect(func() -> void: _toggle_panel("Loading Plan"))
	if btn_as400 != null:
		btn_as400.pressed.connect(func() -> void: _toggle_panel("AS400"))
	if btn_trailer_capacity != null:
		btn_trailer_capacity.pressed.connect(func() -> void: _toggle_panel("Trailer Capacity"))
	if btn_raq != null:
		btn_raq.pressed.connect(func() -> void: _toggle_panel("RAQ"))
	if btn_phone != null:
		btn_phone.pressed.connect(func() -> void: _toggle_panel("Phone"))
	if btn_notes != null:
		btn_notes.pressed.connect(func() -> void: _toggle_panel("Notes"))

func _reset_panel_state() -> void:
	_panel_state.clear()
	for name in PANEL_NAMES:
		_panel_state[name] = false

func _close_all_panels(silent: bool) -> void:
	for name in PANEL_NAMES:
		_set_panel_visible(name, false, silent)

func _toggle_panel(name: String) -> void:
	var is_open: bool = bool(_panel_state.get(name, false))
	_set_panel_visible(name, not is_open, false)

func _set_panel_visible(name: String, visible: bool, silent: bool) -> void:
	_panel_state[name] = visible

	var node: PanelContainer = _panel_nodes.get(name, null)
	if node != null:
		node.visible = visible

	if silent:
		return

	if _session != null:
		if visible:
			_session.call("panel_opened", name)
		else:
			_session.call("panel_closed", name)
