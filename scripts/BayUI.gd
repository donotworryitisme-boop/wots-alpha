extends CanvasLayer

signal trust_contract_requested

const PANEL_NAMES: Array[String] = [
	"Dock View", "Shift Board", "Loading Plan", "AS400", "Trailer Capacity", "RAQ", "Phone", "Notes"
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

@onready var log_title: Label = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/LogTitle
@onready var explain_toggle: CheckButton = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/ExplainWhyToggle
@onready var log_text: RichTextLabel = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel/LogMargin/LogVBox/LogText

@onready var btn_shift_board: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/ShiftBoardBtn
@onready var btn_loading_plan: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/LoadingPlanBtn
@onready var btn_as400: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/AS400Btn
@onready var btn_trailer_capacity: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/TrailerCapacityBtn
@onready var btn_raq: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/RAQBtn
@onready var btn_phone: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PhoneBtn
@onready var btn_notes: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/NotesBtn

@onready var pnl_shift_board: PanelContainer = $Root/PanelOverlayLayer/ShiftBoardPanel
@onready var pnl_loading_plan: PanelContainer = $Root/PanelOverlayLayer/LoadingPlanPanel
@onready var pnl_as400: PanelContainer = $Root/PanelOverlayLayer/AS400Panel
@onready var pnl_trailer_capacity: PanelContainer = $Root/PanelOverlayLayer/TrailerCapacityPanel
@onready var pnl_raq: PanelContainer = $Root/PanelOverlayLayer/RAQPanel
@onready var pnl_phone: PanelContainer = $Root/PanelOverlayLayer/PhonePanel
@onready var pnl_notes: PanelContainer = $Root/PanelOverlayLayer/NotesPanel

var _enabled: bool = false
var _session = null
var _is_active: bool = false
var _debrief_what_happened: String = ""
var _debrief_why_it_mattered: String = ""
var _strip_assignment: String = "Unassigned"
var _strip_window_active: bool = false
var _panel_state: Dictionary = {} 
var _panel_nodes: Dictionary = {} 
var panels_ever_opened: Dictionary = {} 

# --- DYNAMIC UI CONTAINERS ---
var pnl_dock_view: PanelContainer
var btn_dock_view: Button
var as400_label: RichTextLabel
var row_mecha: HFlowContainer
var row_bulky: HFlowContainer
var row_bikes_cc: HFlowContainer

# --- VICTORY PANEL CONTAINERS ---
var debrief_overlay: ColorRect
var lbl_debrief_text: RichTextLabel

func _ready() -> void:
	set_enabled(false)
	_reset_panel_state()

	if trust_button != null:
		trust_button.pressed.connect(func() -> void: trust_contract_requested.emit())
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if end_button != null:
		end_button.pressed.connect(_on_end_pressed)

	_build_dynamic_inventory_ui()
	_build_debrief_modal() # NEW: Build the victory screen

	if explain_toggle != null:
		explain_toggle.toggled.connect(_on_explain_toggled)

	_init_panel_nodes_and_buttons()
	_set_setup_guidance()
	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 1.3)
	_setup_tooltips()

# ==========================================
# NEW: BUILD THE VICTORY MODAL
# ==========================================
func _build_debrief_modal() -> void:
	debrief_overlay = ColorRect.new()
	debrief_overlay.color = Color(0, 0, 0, 0.75) # Dark dim background
	debrief_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.visible = false
	$Root.add_child(debrief_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(800, 600)
	center.add_child(pnl)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0, 0, 0, 0.15)
	sb.shadow_size = 20
	pnl.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	pnl.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	lbl_debrief_text = RichTextLabel.new()
	lbl_debrief_text.bbcode_enabled = true
	lbl_debrief_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl_debrief_text)

	var btn_close = Button.new()
	btn_close.text = "Close Report & Return"
	btn_close.custom_minimum_size = Vector2(250, 50)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func(): debrief_overlay.visible = false)
	vbox.add_child(btn_close)

# ==========================================

func _build_dynamic_inventory_ui() -> void:
	if check_button == null: return
	var sit_vbox = check_button.get_parent().get_parent()
	check_button.get_parent().visible = false 

	as400_label = RichTextLabel.new()
	as400_label.bbcode_enabled = true
	as400_label.custom_minimum_size = Vector2(0, 50)
	sit_vbox.add_child(as400_label)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	sit_vbox.add_child(action_row)

	var btn_call = Button.new()
	btn_call.text = "Call departments"
	btn_call.pressed.connect(func(): _on_decision_pressed("Call departments (C&C check)"))
	action_row.add_child(btn_call)

	var btn_start = Button.new()
	btn_start.text = "Start Loading"
	btn_start.pressed.connect(func(): _on_decision_pressed("Start Loading"))
	action_row.add_child(btn_start)

	var btn_confirm = Button.new()
	btn_confirm.text = "Confirm AS400"
	btn_confirm.pressed.connect(func(): _on_decision_pressed("Confirm AS400"))
	action_row.add_child(btn_confirm)

	var btn_seal = Button.new()
	btn_seal.text = "Seal Truck"
	btn_seal.pressed.connect(func(): _on_decision_pressed("Seal Truck"))
	action_row.add_child(btn_seal)

	var quick_row = HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 8)
	sit_vbox.add_child(quick_row)

	var types = ["Mecha", "Bulky", "Bikes", "C&C"]
	for t in types:
		var btn = Button.new()
		btn.text = "Quick Load " + t
		btn.pressed.connect(func(): if _session != null: _session.call("load_random_pallet", t))
		quick_row.add_child(btn)

	btn_dock_view = Button.new()
	btn_dock_view.text = "Dock View"
	var toggle_vbox = btn_shift_board.get_parent()
	toggle_vbox.add_child(btn_dock_view)
	toggle_vbox.move_child(btn_dock_view, 1)

	pnl_dock_view = pnl_loading_plan.duplicate()
	pnl_loading_plan.get_parent().add_child(pnl_dock_view)
	var dv_vbox = pnl_dock_view.get_child(0).get_child(0)
	dv_vbox.get_child(0).text = "Dock View (Physical Pallets)"
	dv_vbox.get_child(1).queue_free()

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_vbox = VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(map_vbox)
	dv_vbox.add_child(scroll)

	row_mecha = HFlowContainer.new()
	row_bulky = HFlowContainer.new()
	row_bikes_cc = HFlowContainer.new()
	
	var lbl_mecha = Label.new()
	lbl_mecha.text = "Mecha (86)"
	map_vbox.add_child(lbl_mecha)
	map_vbox.add_child(row_mecha)
	
	var lbl_bulky = Label.new()
	lbl_bulky.text = "Bulky (90)"
	map_vbox.add_child(lbl_bulky)
	map_vbox.add_child(row_bulky)
	
	var lbl_bikes = Label.new()
	lbl_bikes.text = "Bikes & C&C"
	map_vbox.add_child(lbl_bikes)
	map_vbox.add_child(row_bikes_cc)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if trust_button != null: trust_button.disabled = false
	if start_button != null: start_button.disabled = not enabled
	if scenario_dropdown != null: scenario_dropdown.disabled = not enabled
	if role_dropdown != null: role_dropdown.disabled = not enabled
	if end_button != null: end_button.disabled = true
	if situation_panel != null: situation_panel.visible = false
	_is_active = false
	if hint_label != null: hint_label.text = ""
	if log_title != null: log_title.text = "Scenario selection"
	if log_text != null: log_text.text = ""
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false
	if debrief_overlay != null: debrief_overlay.visible = false # NEW: Hide overlay on reset
	_close_all_panels(true)
	_set_setup_guidance()
	_render_setup_scenario_list()

func set_session(session) -> void:
	_session = session
	_populate_scenarios()
	_populate_roles()

	if _session != null and _session.has_method("register_panel_catalog"):
		_session.call("register_panel_catalog", PANEL_NAMES)

	if scenario_dropdown != null:
		scenario_dropdown.item_selected.connect(func(_idx: int) -> void: _set_setup_guidance())

	if _session != null:
		if _session.has_signal("hint_updated"): _session.connect("hint_updated", Callable(self, "_on_hint_updated"))
		if _session.has_signal("time_updated"): _session.connect("time_updated", Callable(self, "_on_time_updated"))
		if _session.has_signal("situation_updated"): _session.connect("situation_updated", Callable(self, "_on_situation_updated"))
		if _session.has_signal("session_ended"): _session.connect("session_ended", Callable(self, "_on_session_ended"))
		if _session.has_signal("action_registered"): _session.connect("action_registered", Callable(self, "_on_action_registered"))
		if _session.has_signal("role_updated"): _session.connect("role_updated", Callable(self, "_on_role_updated"))
		if _session.has_signal("responsibility_boundary_updated"): _session.connect("responsibility_boundary_updated", Callable(self, "_on_boundary_updated"))
		if _session.has_signal("inventory_updated"): _session.connect("inventory_updated", Callable(self, "_on_inventory_updated"))
		if _session.has_signal("as400_status_updated"): _session.connect("as400_status_updated", Callable(self, "_on_as400_updated"))

	_render_setup_scenario_list()
	_set_setup_guidance()

func _on_as400_updated(t_uats: int, t_col: int, l_uats: int, l_col: int) -> void:
	if as400_label != null:
		as400_label.text = "[color=#2ecc71]EXPECTED: %d UATs | %d Collis[/color]\n[color=#95a5a6]LOADED: %d UATs | %d Collis[/color]" % [t_uats, t_col, l_uats, l_col]

func _on_inventory_updated(avail: Array, _loaded: Array, _cap_used: float, _cap_max: float) -> void:
	for child in row_mecha.get_children(): child.queue_free()
	for child in row_bulky.get_children(): child.queue_free()
	for child in row_bikes_cc.get_children(): child.queue_free()

	for p in avail:
		if p.missing: continue
		var row = null
		if p.type == "Mecha": row = row_mecha
		elif p.type == "Bulky": row = row_bulky
		else: row = row_bikes_cc
		_draw_pallet(p, row)

func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(50, 50)
	btn.text = p_data.id.split("-")[1] 
	btn.tooltip_text = "%s\nPromise: %s\nCollis: %d\nCap: %0.1f" % [p_data.type, p_data.promise, p_data.collis, p_data.cap]

	var color = Color(0.2, 0.2, 0.2)
	if p_data.type == "C&C": color = Color(1.0, 1.0, 1.0)
	elif p_data.type == "Bikes": color = Color(0.2, 0.7, 0.3)
	elif p_data.type == "Bulky": color = Color(0.9, 0.5, 0.1)
	elif p_data.type == "Mecha": color = Color(0.0, 0.51, 0.76)

	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb) 
	btn.add_theme_color_override("font_color", Color(0,0,0) if p_data.type == "C&C" else Color(1,1,1))

	btn.pressed.connect(func(): if _session != null: _session.call("load_pallet_by_id", p_data.id))
	parent.add_child(btn)

func _populate_scenarios() -> void:
	if scenario_dropdown == null or _session == null: return
	scenario_dropdown.clear()
	var names: Array[String] = []
	if _session.scenario_loader != null and _session.scenario_loader.has_method("get_scenario_names"):
		names = _session.scenario_loader.call("get_scenario_names")
	else:
		names = ["default"]
	for n in names: scenario_dropdown.add_item(n)
	if scenario_dropdown.item_count > 0: scenario_dropdown.select(0)

func _populate_roles() -> void:
	if role_dropdown == null: return
	role_dropdown.clear()
	role_dropdown.add_item("Operator", WOTSConfig.Role.OPERATOR)
	role_dropdown.add_item("Captain", WOTSConfig.Role.CAPTAIN)
	role_dropdown.add_item("Trainer", WOTSConfig.Role.TRAINER)
	role_dropdown.select(0)

func _on_start_pressed() -> void:
	if not _enabled or _session == null: return
	var scenario_name: String = "default"
	if scenario_dropdown != null: scenario_name = scenario_dropdown.get_item_text(scenario_dropdown.get_selected_id())
	var role_id: int = WOTSConfig.Role.OPERATOR
	if role_dropdown != null: role_id = role_dropdown.get_selected_id()
	_session.set_role(role_id)
	_is_active = true
	_set_active_guidance()
	_reset_panel_state()
	_close_all_panels(true)
	if situation_panel != null: situation_panel.visible = true
	if end_button != null: end_button.disabled = false
	if start_button != null: start_button.disabled = true
	if log_title != null: log_title.text = "Learning summary"
	if log_text != null: log_text.text = "[b]What to do:[/b]\nUse actions, open panels as needed, then the run will end on its own.\n"
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false
	_session.call("start_session_with_scenario", scenario_name)

func _on_end_pressed() -> void:
	if _session == null: return
	_session.end_session()

func _on_decision_pressed(action: String) -> void:
	if _session == null: return
	_session.call("manual_decision", action)

func _on_hint_updated(hint_text: String) -> void:
	if hint_label != null: hint_label.text = hint_text

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)
	if time_label != null: time_label.text = "Time: %0.2fs" % [total_time]

func _on_situation_updated(objective_text: String) -> void:
	if objective_label != null: objective_label.text = "Objective: " + objective_text

func _on_action_registered(one_line: String) -> void:
	if log_text == null: return
	log_text.text += one_line + "\n"

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_set_setup_guidance()
	if situation_panel != null: situation_panel.visible = false
	if start_button != null: start_button.disabled = false
	if end_button != null: end_button.disabled = true
	
	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))
	
	if log_title != null: log_title.text = "Story of the Shift"
	
	if explain_toggle != null:
		explain_toggle.visible = _debrief_why_it_mattered.strip_edges() != ""
		explain_toggle.button_pressed = false
	_render_debrief(false)

func _on_explain_toggled(pressed: bool) -> void:
	_render_debrief(pressed)

func _render_debrief(show_why: bool) -> void:
	# POPULATE THE NEW VICTORY SCREEN
	var bb := "[center][font_size=24][color=#0082c3][b]Story of the Shift[/b][/color][/font_size][/center]\n\n"
	bb += "[b]Timeline of Events[/b]\n"
	bb += _debrief_what_happened + "\n"
	
	bb += "[b]Context Coverage Matrix (Information Visibility)[/b]\n"
	var opened_panels = []
	var missed_panels = []
	for p in PANEL_NAMES:
		if p != "Dock View":
			if panels_ever_opened.get(p, false): opened_panels.append(p)
			else: missed_panels.append(p)
				
	bb += "[color=#2ecc71]✔️ Consulted:[/color] " 
	bb += ", ".join(opened_panels) if opened_panels.size() > 0 else "None"
	bb += "\n[color=#95a5a6]⬛ Not Consulted:[/color] "
	bb += ", ".join(missed_panels) if missed_panels.size() > 0 else "None"
	bb += "\n\n"
	
	if show_why and _debrief_why_it_mattered.strip_edges() != "":
		bb += "[b]Neutral Pattern Callout[/b]\n"
		bb += _debrief_why_it_mattered + "\n"
		
	# Show the popup modal!
	if lbl_debrief_text != null:
		lbl_debrief_text.text = bb
	if debrief_overlay != null:
		debrief_overlay.visible = true
		
	# Also set it to the background log just so it stays there when closed
	if log_text != null: log_text.text = bb

func _set_setup_guidance() -> void:
	if what_to_do_label == null: return
	var scenario_name: String = "default"
	if scenario_dropdown != null and scenario_dropdown.item_count > 0:
		scenario_name = scenario_dropdown.get_item_text(scenario_dropdown.get_selected_id())
	var desc := ""
	if _session != null and _session.scenario_loader != null and _session.scenario_loader.has_method("get_scenario_description"):
		desc = str(_session.scenario_loader.call("get_scenario_description", scenario_name))
	what_to_do_label.text = "Pick a scenario and role, then start.\n\nSelected scenario:\n%s" % (desc if desc != "" else "(no description)")

func _set_active_guidance() -> void:
	if what_to_do_label != null:
		what_to_do_label.text = "Use actions to manage priorities and uncertainty. End to review learning summary."

func _update_top_time(total_time: float) -> void:
	if top_time_label != null: top_time_label.text = "Time: %0.2fs" % total_time

func _on_role_updated(_role_id: int) -> void:
	_update_strip_text()

func _on_boundary_updated(_role_id: int, assignment_text: String, window_active: bool) -> void:
	_strip_assignment = assignment_text
	_strip_window_active = window_active
	_update_strip_text()

func _update_strip_text() -> void:
	if role_strip_label == null: return
	var role_name := "Operator"
	if role_dropdown != null:
		match role_dropdown.get_selected_id():
			WOTSConfig.Role.OPERATOR: role_name = "Operator"
			WOTSConfig.Role.CAPTAIN: role_name = "Captain"
			WOTSConfig.Role.TRAINER: role_name = "Trainer"
	var window_text := "Not Active"
	if _strip_window_active: window_text = "Active"
	role_strip_label.text = "Role: %s | Assignment: %s | Window: %s" % [role_name, _strip_assignment, window_text]

func _render_setup_scenario_list() -> void:
	if _is_active: return
	if log_title != null: log_title.text = "Scenario selection"
	if log_text == null: return
	if _session == null or _session.scenario_loader == null:
		log_text.text = "[b]Scenario selection[/b]\n(Scenario list unavailable)\n"
		return
	var names: Array[String] = []
	if _session.scenario_loader.has_method("get_scenario_names"):
		names = _session.scenario_loader.call("get_scenario_names")
	var bb := "[b]Scenario selection[/b]\nChoose a scenario (neutral descriptions):\n\n"
	for n in names:
		var d := ""
		if _session.scenario_loader.has_method("get_scenario_description"):
			d = str(_session.scenario_loader.call("get_scenario_description", n))
		bb += "• [b]%s[/b] — %s\n" % [n, d]
	log_text.text = bb

func _init_panel_nodes_and_buttons() -> void:
	_panel_nodes.clear()
	_panel_nodes["Dock View"] = pnl_dock_view
	_panel_nodes["Shift Board"] = pnl_shift_board
	_panel_nodes["Loading Plan"] = pnl_loading_plan
	_panel_nodes["AS400"] = pnl_as400
	_panel_nodes["Trailer Capacity"] = pnl_trailer_capacity
	_panel_nodes["RAQ"] = pnl_raq
	_panel_nodes["Phone"] = pnl_phone
	_panel_nodes["Notes"] = pnl_notes
	if btn_dock_view != null: btn_dock_view.pressed.connect(func() -> void: _toggle_panel("Dock View"))
	if btn_shift_board != null: btn_shift_board.pressed.connect(func() -> void: _toggle_panel("Shift Board"))
	if btn_loading_plan != null: btn_loading_plan.pressed.connect(func() -> void: _toggle_panel("Loading Plan"))
	if btn_as400 != null: btn_as400.pressed.connect(func() -> void: _toggle_panel("AS400"))
	if btn_trailer_capacity != null: btn_trailer_capacity.pressed.connect(func() -> void: _toggle_panel("Trailer Capacity"))
	if btn_raq != null: btn_raq.pressed.connect(func() -> void: _toggle_panel("RAQ"))
	if btn_phone != null: btn_phone.pressed.connect(func() -> void: _toggle_panel("Phone"))
	if btn_notes != null: btn_notes.pressed.connect(func() -> void: _toggle_panel("Notes"))

func _reset_panel_state() -> void:
	_panel_state.clear()
	panels_ever_opened.clear()
	for panel_name in PANEL_NAMES: _panel_state[panel_name] = false

func _close_all_panels(silent: bool) -> void:
	for panel_name in PANEL_NAMES: _set_panel_visible(panel_name, false, silent)

func _toggle_panel(panel_name: String) -> void:
	var is_open: bool = bool(_panel_state.get(panel_name, false))
	_set_panel_visible(panel_name, not is_open, false)

func _set_panel_visible(panel_name: String, make_visible: bool, silent: bool) -> void:
	_panel_state[panel_name] = make_visible
	if make_visible: panels_ever_opened[panel_name] = true 
	var node: PanelContainer = _panel_nodes.get(panel_name, null)
	if node != null: node.visible = make_visible
	if silent: return
	if _session != null:
		if make_visible: _session.call("panel_opened", panel_name)
		else: _session.call("panel_closed", panel_name)

func _setup_tooltips() -> void:
	if btn_shift_board != null: btn_shift_board.tooltip_text = "Shift Board\nProvides staffing, breaks, and key tasks."
	if btn_loading_plan != null: btn_loading_plan.tooltip_text = "Loading Plan\nShows planned loads, priorities, and constraints."
	if btn_as400 != null: btn_as400.tooltip_text = "AS400\nSystem lookups and current status."
	if btn_trailer_capacity != null: btn_trailer_capacity.tooltip_text = "Trailer Capacity\nDisplays cube/weight and remaining space."
	if btn_raq != null: btn_raq.tooltip_text = "RAQ\nShows Requests, Adjustments, and Questions."
	if btn_phone != null: btn_phone.tooltip_text = "Phone\nIncoming calls and messages needing attention."
	if btn_notes != null: btn_notes.tooltip_text = "Notes\nScratchpad to jot down what you noticed."
