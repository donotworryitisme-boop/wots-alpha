extends CanvasLayer

signal trust_contract_requested

const PANEL_NAMES: Array[String] = [
	"Dock View", "Shift Board", "Loading Plan", "AS400", "Trailer Capacity", "Phone", "Notes"
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
var _session = null
var _is_active: bool = false
var _debrief_what_happened: String = ""
var _debrief_why_it_mattered: String = ""
var _strip_assignment: String = "Unassigned"
var _strip_window_active: bool = false
var _panel_state: Dictionary = {} 
var _panel_nodes: Dictionary = {} 
var panels_ever_opened: Dictionary = {} 
var _current_scenario_name: String = ""

# --- PORTAL & STAGE CONTAINERS ---
var portal_overlay: ColorRect
var portal_scenario_dropdown: OptionButton

var top_actions_hbox: HBoxContainer
var stage_hbox: HBoxContainer
var lbl_standby: Label 
var pnl_dock_stage: PanelContainer
var pnl_as400_stage: PanelContainer

var row_mecha: HFlowContainer
var row_bulky: HFlowContainer
var row_bikes_cc: HFlowContainer
var truck_grid: GridContainer
var truck_cap_label: RichTextLabel 
var lbl_hover_info: RichTextLabel 
var as400_summary_label: RichTextLabel
var raq_vbox: VBoxContainer

var debrief_overlay: ColorRect
var lbl_debrief_text: RichTextLabel

# --- NEW: SOP KNOWLEDGE BASE CONTAINERS ---
var sop_overlay: ColorRect
var sop_search_input: LineEdit
var sop_results_vbox: VBoxContainer
var sop_content_label: RichTextLabel

var sop_database: Array = [
	{
		"title": "What is Click & Collect (C&C)?",
		"tags": ["click", "collect", "c&c", "white", "customer"],
		"content": "[font_size=22][color=#0082c3][b]Click & Collect (C&C)[/b][/color][/font_size]\n\nThese pallets contain items directly ordered by customers waiting at the store. \n\n[color=#e74c3c][b]THE RULE:[/b][/color] They MUST be loaded [b]LAST[/b] onto the truck (closest to the doors) so they are the very first things taken off at the destination store. If you load them early, the store has to empty the whole truck to give customers their orders.",
		"scenarios": ["Standard Loading", "Promise Loading"]
	},
	{
		"title": "How to check if I have all C&C pallets?",
		"tags": ["check", "click", "missing", "raq", "as400"],
		"content": "[font_size=22][color=#0082c3][b]Verifying Click & Collect[/b][/color][/font_size]\n\nNever guess if you have all your C&C pallets. Verify it:\n\n1. Open the [b]AS400[/b] panel.\n2. Look at the [b]RAQ UATs[/b] list.\n3. Count the white [b]C&C[/b] entries at the bottom of the list.\n4. Compare that number to the physical white pallets sitting in the [b]Dock View[/b].\n5. If the AS400 says you should have 3, but you only see 2 on the floor, click [b]Call Departments[/b] immediately to find the missing pallet before you seal the truck.",
		"scenarios": ["Standard Loading", "Promise Loading"]
	},
	{
		"title": "What is the standard loading sequence?",
		"tags": ["load", "sequence", "truck", "order", "standard", "first"],
		"content": "[font_size=22][color=#0082c3][b]The Standard Loading Sequence[/b][/color][/font_size]\n\nThe physical order in which you put things into the truck is critical for safe transit and efficient unloading.\n\n[b]Load in this exact order:[/b]\n1. [color=#f1c40f][b]Service Center (Stands)[/b][/color] - Yellow\n2. [color=#2ecc71][b]Bikes[/b][/color] - Green\n3. [color=#e67e22][b]Bulky[/b][/color] - Orange\n4. [color=#3498db][b]Mecha[/b][/color] - Blue\n5. [color=#95a5a6][b]Click & Collect[/b][/color] - White (Always last!)",
		"scenarios": ["Standard Loading", "Promise Loading"]
	},
	{
		"title": "How do Promise Dates work? (D, D+, D-)",
		"tags": ["promise", "date", "d+", "d-", "priority", "capacity", "full"],
		"content": "[font_size=22][color=#0082c3][b]Promise Dates & Capacity[/b][/color][/font_size]\n\nWhen you have more pallets than the truck can hold, you must leave some behind. You decide what stays based on the Promise Date.\n\n[color=#e74c3c][b]D-[/b] : Overdue.[/color] CRITICAL priority. Must be loaded.\n[color=#f1c40f][b]D[/b]  : Due today.[/color] High priority. Must be loaded.\n[color=#95a5a6][b]D+[/b] : Due tomorrow.[/color] Low priority. \n\n[b]The Rule:[/b] Load ALL of your D- and D pallets first (following the standard sequence). Only load D+ pallets if you still have empty spaces left in the truck after all priority pallets are loaded.",
		"scenarios": ["Promise Loading"] # PROGRESSIVE DISCLOSURE!
	}
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16) 
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(bg)
	$Root.move_child(bg, 0)
	
	var old_setup = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel
	if old_setup: old_setup.visible = false
	var old_sit = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel
	if old_sit: old_sit.visible = false
	var old_log = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel
	if old_log: old_log.visible = false

	var old_raq_btn = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/RAQBtn
	if old_raq_btn: old_raq_btn.visible = false

	_build_start_portal()
	_build_operational_layout()
	_build_debrief_modal()
	_build_sop_modal() # NEW!

	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

# ==========================================
# 1. SOP KNOWLEDGE BASE MODAL
# ==========================================
func _build_sop_modal() -> void:
	sop_overlay = ColorRect.new()
	sop_overlay.color = Color(0, 0, 0, 0.9) 
	sop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sop_overlay.visible = false
	$Root.add_child(sop_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sop_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(1000, 650)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.95, 0.95, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

	var main_vbox = VBoxContainer.new()
	pnl.add_child(main_vbox)
	
	# Top Header Bar
	var header_bg = ColorRect.new()
	header_bg.custom_minimum_size = Vector2(0, 80)
	header_bg.color = Color(0.08, 0.12, 0.18)
	main_vbox.add_child(header_bg)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_bg.add_child(header_hbox)
	
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 20)
	header_hbox.add_child(title_margin)
	
	var title = Label.new()
	title.text = "SOP Knowledge Base"
	title.add_theme_font_size_override("font_size", 24)
	title_margin.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	var btn_close = Button.new()
	btn_close.text = " Resume Shift "
	btn_close.custom_minimum_size = Vector2(150, 40)
	btn_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.8, 0.2, 0.2)
	close_sb.corner_radius_top_left = 4
	close_sb.corner_radius_bottom_right = 4
	btn_close.add_theme_stylebox_override("normal", close_sb)
	btn_close.pressed.connect(_close_sop_modal)
	
	var close_margin = MarginContainer.new()
	close_margin.add_theme_constant_override("margin_right", 20)
	close_margin.add_child(btn_close)
	header_hbox.add_child(close_margin)

	# Main Split Pane (Left: Search/List, Right: Content)
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split_hbox)

	# Left Panel
	var left_pnl = PanelContainer.new()
	left_pnl.custom_minimum_size = Vector2(350, 0)
	var left_sb = StyleBoxFlat.new()
	left_sb.bg_color = Color(0.9, 0.9, 0.9)
	left_pnl.add_theme_stylebox_override("panel", left_sb)
	split_hbox.add_child(left_pnl)
	
	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 15)
	left_margin.add_theme_constant_override("margin_top", 15)
	left_margin.add_theme_constant_override("margin_right", 15)
	left_margin.add_theme_constant_override("margin_bottom", 15)
	left_pnl.add_child(left_margin)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 15)
	left_margin.add_child(left_vbox)
	
	sop_search_input = LineEdit.new()
	sop_search_input.placeholder_text = "Search SOPs (e.g., 'click')"
	sop_search_input.custom_minimum_size = Vector2(0, 40)
	sop_search_input.text_changed.connect(_on_sop_search_changed)
	left_vbox.add_child(sop_search_input)
	
	var scroll_res = ScrollContainer.new()
	scroll_res.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_res)
	
	sop_results_vbox = VBoxContainer.new()
	sop_results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_res.add_child(sop_results_vbox)

	# Right Panel (Content)
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 30)
	right_margin.add_theme_constant_override("margin_top", 30)
	right_margin.add_theme_constant_override("margin_right", 30)
	split_hbox.add_child(right_margin)
	
	sop_content_label = RichTextLabel.new()
	sop_content_label.bbcode_enabled = true
	sop_content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sop_content_label.add_theme_color_override("default_color", Color.BLACK)
	sop_content_label.text = "[color=#95a5a6]Select an article from the left to read the standard operating procedure.[/color]"
	right_margin.add_child(sop_content_label)

func _open_sop_modal() -> void:
	if _session != null:
		_session.call("set_pause_state", true) # FREEZE TIME
	sop_search_input.text = ""
	sop_content_label.text = "[color=#95a5a6]Select an article from the left to read the standard operating procedure.[/color]"
	_on_sop_search_changed("") # Load fresh list based on current scenario
	sop_overlay.visible = true

func _close_sop_modal() -> void:
	if _session != null:
		_session.call("set_pause_state", false) # RESUME TIME
	sop_overlay.visible = false

func _on_sop_search_changed(query: String) -> void:
	for child in sop_results_vbox.get_children():
		child.queue_free()
		
	var q = query.to_lower()
	for article in sop_database:
		# Progressive Disclosure Check!
		if not article.scenarios.has(_current_scenario_name):
			continue # Hide advanced articles if in basic scenario
			
		var match_found = false
		if q == "": match_found = true
		elif q in article.title.to_lower(): match_found = true
		else:
			for tag in article.tags:
				if q in tag.to_lower(): match_found = true
				
		if match_found:
			var btn = Button.new()
			btn.text = article.title
			btn.custom_minimum_size = Vector2(0, 45)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var btn_sb = StyleBoxFlat.new()
			btn_sb.bg_color = Color.WHITE
			btn_sb.border_width_bottom = 1
			btn_sb.border_color = Color(0.8, 0.8, 0.8)
			
			var btn_hover = btn_sb.duplicate()
			btn_hover.bg_color = Color(0.9, 0.95, 1.0) # Light blue hover
			
			btn.add_theme_stylebox_override("normal", btn_sb)
			btn.add_theme_stylebox_override("hover", btn_hover)
			btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
			btn.add_theme_color_override("font_hover_color", Color(0.0, 0.5, 0.8))
			
			btn.pressed.connect(func(): sop_content_label.text = article.content)
			sop_results_vbox.add_child(btn)

# ==========================================
# 2. START PORTAL
# ==========================================
func _build_start_portal() -> void:
	portal_overlay = ColorRect.new()
	portal_overlay.color = Color(0.08, 0.12, 0.18, 1.0) 
	portal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(portal_overlay) 

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	portal_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(500, 450)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 25
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	pnl.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Decathlon Bay B2B"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 0.5, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Operational Training Simulator"
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	
	vbox.add_child(HSeparator.new())

	var lbl_scen = Label.new()
	lbl_scen.text = "Select Training Scenario:"
	lbl_scen.add_theme_color_override("font_color", Color.BLACK)
	vbox.add_child(lbl_scen)

	portal_scenario_dropdown = OptionButton.new()
	portal_scenario_dropdown.custom_minimum_size = Vector2(0, 45)
	vbox.add_child(portal_scenario_dropdown)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_start = Button.new()
	btn_start.text = "Begin Shift"
	btn_start.custom_minimum_size = Vector2(0, 60)
	
	var start_sb_normal = StyleBoxFlat.new()
	start_sb_normal.bg_color = Color(0.95, 0.95, 0.95) 
	start_sb_normal.corner_radius_top_left = 6
	start_sb_normal.corner_radius_top_right = 6
	start_sb_normal.corner_radius_bottom_left = 6
	start_sb_normal.corner_radius_bottom_right = 6
	start_sb_normal.border_width_left = 1
	start_sb_normal.border_width_top = 1
	start_sb_normal.border_width_right = 1
	start_sb_normal.border_width_bottom = 1
	start_sb_normal.border_color = Color(0.8, 0.8, 0.8)
	
	var start_sb_hover = StyleBoxFlat.new()
	start_sb_hover.bg_color = Color(0.18, 0.8, 0.44) 
	start_sb_hover.corner_radius_top_left = 6
	start_sb_hover.corner_radius_top_right = 6
	start_sb_hover.corner_radius_bottom_left = 6
	start_sb_hover.corner_radius_bottom_right = 6

	btn_start.add_theme_stylebox_override("normal", start_sb_normal)
	btn_start.add_theme_stylebox_override("hover", start_sb_hover)
	btn_start.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3)) 
	btn_start.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0)) 
	btn_start.add_theme_font_size_override("font_size", 20)
	btn_start.pressed.connect(_on_portal_start_pressed)
	vbox.add_child(btn_start)
	
	var btn_quit = Button.new()
	btn_quit.text = "Close Application"
	btn_quit.custom_minimum_size = Vector2(0, 40)
	
	var quit_sb_normal = StyleBoxFlat.new()
	quit_sb_normal.bg_color = Color(0.95, 0.95, 0.95) 
	quit_sb_normal.corner_radius_top_left = 6
	quit_sb_normal.corner_radius_top_right = 6
	quit_sb_normal.corner_radius_bottom_left = 6
	quit_sb_normal.corner_radius_bottom_right = 6
	quit_sb_normal.border_width_left = 1
	quit_sb_normal.border_width_top = 1
	quit_sb_normal.border_width_right = 1
	quit_sb_normal.border_width_bottom = 1
	quit_sb_normal.border_color = Color(0.8, 0.8, 0.8)
	
	var quit_sb_hover = StyleBoxFlat.new()
	quit_sb_hover.bg_color = Color(0.8, 0.2, 0.2) 
	quit_sb_hover.corner_radius_top_left = 6
	quit_sb_hover.corner_radius_top_right = 6
	quit_sb_hover.corner_radius_bottom_left = 6
	quit_sb_hover.corner_radius_bottom_right = 6

	btn_quit.add_theme_stylebox_override("normal", quit_sb_normal)
	btn_quit.add_theme_stylebox_override("hover", quit_sb_hover)
	btn_quit.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3)) 
	btn_quit.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0)) 

	btn_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_quit)

# ==========================================
# 3. OPERATIONAL STAGE
# ==========================================
func _build_operational_layout() -> void:
	top_actions_hbox = HBoxContainer.new()
	top_actions_hbox.add_theme_constant_override("separation", 15)
	top_actions_hbox.visible = false 
	workspace_vbox.add_child(top_actions_hbox)

	var btn_start_load = Button.new()
	btn_start_load.text = "Start Loading"
	btn_start_load.custom_minimum_size = Vector2(150, 40)
	btn_start_load.pressed.connect(func(): _on_decision_pressed("Start Loading"))
	top_actions_hbox.add_child(btn_start_load)

	var btn_call = Button.new()
	btn_call.text = "Call Departments (C&C Check)"
	btn_call.custom_minimum_size = Vector2(250, 40)
	btn_call.pressed.connect(func(): _on_decision_pressed("Call departments (C&C check)"))
	top_actions_hbox.add_child(btn_call)

	var btn_seal = Button.new()
	btn_seal.text = "Seal Truck & Print Papers"
	btn_seal.custom_minimum_size = Vector2(200, 40)
	btn_seal.pressed.connect(func(): _on_decision_pressed("Seal Truck"))
	top_actions_hbox.add_child(btn_seal)
	
	# Push the SOP button to the far right
	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_actions_hbox.add_child(top_spacer)
	
	var btn_sop = Button.new()
	btn_sop.text = " Help & SOPs "
	btn_sop.custom_minimum_size = Vector2(150, 40)
	var sop_sb = StyleBoxFlat.new()
	sop_sb.bg_color = Color(0.2, 0.4, 0.8) # Blue info button
	sop_sb.corner_radius_top_left = 6
	sop_sb.corner_radius_top_right = 6
	sop_sb.corner_radius_bottom_left = 6
	sop_sb.corner_radius_bottom_right = 6
	btn_sop.add_theme_stylebox_override("normal", sop_sb)
	btn_sop.pressed.connect(_open_sop_modal)
	top_actions_hbox.add_child(btn_sop)

	stage_hbox = HBoxContainer.new()
	stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	stage_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_hbox.add_theme_constant_override("separation", 15)
	stage_hbox.visible = false
	workspace_vbox.add_child(stage_hbox)
	
	lbl_standby = Label.new()
	lbl_standby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_standby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_standby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_standby.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_standby.text = "Shift Started.\n\nSelect a tool from the Panels menu to begin operations.\n\n(If you don't know what to do, click '? Help & SOPs' in the top right.)"
	lbl_standby.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lbl_standby.add_theme_font_size_override("font_size", 24)
	stage_hbox.add_child(lbl_standby)

	_build_dock_stage()
	_build_as400_stage()
	
	var btn_dock_view = Button.new()
	btn_dock_view.text = "Dock View"
	btn_shift_board.get_parent().add_child(btn_dock_view)
	btn_shift_board.get_parent().move_child(btn_dock_view, 0)
	
	_init_panel_nodes_and_buttons(btn_dock_view)

func _build_dock_stage() -> void:
	pnl_dock_stage = PanelContainer.new()
	pnl_dock_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl_dock_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pnl_dock_stage.visible = false 
	stage_hbox.add_child(pnl_dock_stage)
	
	var dock_margin = MarginContainer.new()
	dock_margin.add_theme_constant_override("margin_left", 15)
	dock_margin.add_theme_constant_override("margin_top", 15)
	dock_margin.add_theme_constant_override("margin_right", 15)
	dock_margin.add_theme_constant_override("margin_bottom", 15)
	pnl_dock_stage.add_child(dock_margin)
	
	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 10)
	dock_margin.add_child(dock_vbox)
	
	lbl_hover_info = RichTextLabel.new()
	lbl_hover_info.bbcode_enabled = true
	lbl_hover_info.custom_minimum_size = Vector2(0, 60) 
	lbl_hover_info.text = "[color=#95a5a6]Hover over a pallet to scan details instantly...[/color]"
	dock_vbox.add_child(lbl_hover_info)
	
	var floor_split = HBoxContainer.new()
	floor_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_vbox.add_child(floor_split)
	
	var scroll_dock = ScrollContainer.new()
	scroll_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_dock.size_flags_stretch_ratio = 2.0
	var sb_dock = StyleBoxFlat.new()
	sb_dock.bg_color = Color(0.9, 0.9, 0.9) 
	sb_dock.corner_radius_top_left = 6
	sb_dock.corner_radius_bottom_left = 6
	scroll_dock.add_theme_stylebox_override("panel", sb_dock)
	floor_split.add_child(scroll_dock)
	
	var lines_margin = MarginContainer.new()
	lines_margin.add_theme_constant_override("margin_left", 15)
	lines_margin.add_theme_constant_override("margin_top", 15)
	scroll_dock.add_child(lines_margin)

	var map_vbox = VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 20)
	lines_margin.add_child(map_vbox)

	row_mecha = HFlowContainer.new()
	row_bulky = HFlowContainer.new()
	row_bikes_cc = HFlowContainer.new()
	
	var lbl_mecha = Label.new()
	lbl_mecha.text = "Mecha (MAP/MAG)"
	lbl_mecha.add_theme_color_override("font_color", Color.BLACK)
	map_vbox.add_child(lbl_mecha)
	map_vbox.add_child(row_mecha)
	
	var lbl_bulky = Label.new()
	lbl_bulky.text = "Bulky (90)"
	lbl_bulky.add_theme_color_override("font_color", Color.BLACK)
	map_vbox.add_child(lbl_bulky)
	map_vbox.add_child(row_bulky)
	
	var lbl_bikes = Label.new()
	lbl_bikes.text = "Bikes, C&C, Service Center"
	lbl_bikes.add_theme_color_override("font_color", Color.BLACK)
	map_vbox.add_child(lbl_bikes)
	map_vbox.add_child(row_bikes_cc)

	var truck_pnl = PanelContainer.new()
	truck_pnl.custom_minimum_size = Vector2(180, 0)
	var t_sb = StyleBoxFlat.new()
	t_sb.bg_color = Color(0.15, 0.15, 0.15)
	t_sb.border_width_left = 4
	t_sb.border_width_right = 4
	t_sb.border_width_top = 4
	t_sb.border_width_bottom = 4
	t_sb.border_color = Color.BLACK
	truck_pnl.add_theme_stylebox_override("panel", t_sb)
	floor_split.add_child(truck_pnl)

	var truck_vbox = VBoxContainer.new()
	truck_pnl.add_child(truck_vbox)

	truck_cap_label = RichTextLabel.new()
	truck_cap_label.bbcode_enabled = true
	truck_cap_label.scroll_active = false 
	truck_cap_label.fit_content = true
	truck_cap_label.text = "[center][color=#7f8fa6]Capacity: 0.0 / 36.0[/color]\n[b][color=#f5f6fa]Spaces Left: 36.0[/color][/b][/center]"
	truck_vbox.add_child(truck_cap_label)

	truck_grid = GridContainer.new()
	truck_grid.columns = 3
	truck_grid.add_theme_constant_override("h_separation", 4)
	truck_grid.add_theme_constant_override("v_separation", 4)
	truck_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	truck_vbox.add_child(truck_grid)

func _build_as400_stage() -> void:
	pnl_as400_stage = PanelContainer.new()
	pnl_as400_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl_as400_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pnl_as400_stage.visible = false 
	
	var as400_sb = StyleBoxFlat.new()
	as400_sb.bg_color = Color(0.12, 0.12, 0.15) 
	pnl_as400_stage.add_theme_stylebox_override("panel", as400_sb)
	stage_hbox.add_child(pnl_as400_stage)

	var as400_tabs = TabContainer.new()
	pnl_as400_stage.add_child(as400_tabs)

	var tab_summary = MarginContainer.new()
	tab_summary.name = "Summary"
	tab_summary.add_theme_constant_override("margin_left", 15)
	tab_summary.add_theme_constant_override("margin_top", 15)
	as400_tabs.add_child(tab_summary)
	
	as400_summary_label = RichTextLabel.new()
	as400_summary_label.bbcode_enabled = true
	tab_summary.add_child(as400_summary_label)

	var tab_raq = MarginContainer.new()
	tab_raq.name = "RAQ UATs"
	tab_raq.add_theme_constant_override("margin_left", 15)
	tab_raq.add_theme_constant_override("margin_top", 15)
	as400_tabs.add_child(tab_raq)

	var raq_scroll = ScrollContainer.new()
	tab_raq.add_child(raq_scroll)
	
	var raq_content = VBoxContainer.new()
	raq_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raq_scroll.add_child(raq_content)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Confirm AS400"
	btn_confirm.custom_minimum_size = Vector2(0, 40)
	btn_confirm.pressed.connect(func(): _on_decision_pressed("Confirm AS400"))
	raq_content.add_child(btn_confirm)
	
	raq_content.add_child(HSeparator.new())
	
	raq_vbox = VBoxContainer.new()
	raq_content.add_child(raq_vbox)

func _build_debrief_modal() -> void:
	debrief_overlay = ColorRect.new()
	debrief_overlay.color = Color(0, 0, 0, 0.9) 
	debrief_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.visible = false
	$Root.add_child(debrief_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(900, 700)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.95, 0.95, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

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
	btn_close.text = "Finish & Return to Portal"
	btn_close.custom_minimum_size = Vector2(250, 50)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(_on_debrief_closed)
	vbox.add_child(btn_close)

# ==========================================
# FLOW LOGIC
# ==========================================
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled: return
	if portal_overlay != null: portal_overlay.visible = true

func _on_portal_start_pressed() -> void:
	if _session == null: return
	var scenario_name: String = "default"
	if portal_scenario_dropdown != null: scenario_name = portal_scenario_dropdown.get_item_text(portal_scenario_dropdown.get_selected_id())
	
	_current_scenario_name = scenario_name # Save for SOP filters
	_session.set_role(WOTSConfig.Role.OPERATOR)
	_is_active = true
	
	portal_overlay.visible = false
	top_actions_hbox.visible = true
	stage_hbox.visible = true
	
	_reset_panel_state()
	_close_all_panels(true)
	lbl_standby.visible = true 
	
	_session.call("start_session_with_scenario", scenario_name)

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))
	_render_debrief()

func _on_debrief_closed() -> void:
	debrief_overlay.visible = false
	top_actions_hbox.visible = false
	stage_hbox.visible = false
	_close_all_panels(true)
	portal_overlay.visible = true

func _render_debrief() -> void:
	var bb := "[center][font_size=28][color=#0082c3][b]Story of the Shift[/b][/color][/font_size][/center]\n\n"
	bb += "[font_size=18][b]Operational Timeline & Decisions[/b][/font_size]\n"
	bb += _debrief_what_happened + "\n"
	
	if _debrief_why_it_mattered.strip_edges() != "":
		bb += "\n[font_size=18][b]Managerial Review[/b][/font_size]\n"
		bb += _debrief_why_it_mattered + "\n"
		
	if lbl_debrief_text != null: lbl_debrief_text.text = bb
	if debrief_overlay != null: debrief_overlay.visible = true

func set_session(session) -> void:
	_session = session
	_populate_scenarios()
	
	if _session != null:
		if _session.has_signal("time_updated"): _session.connect("time_updated", Callable(self, "_on_time_updated"))
		if _session.has_signal("session_ended"): _session.connect("session_ended", Callable(self, "_on_session_ended"))
		if _session.has_signal("role_updated"): _session.connect("role_updated", Callable(self, "_on_role_updated"))
		if _session.has_signal("responsibility_boundary_updated"): _session.connect("responsibility_boundary_updated", Callable(self, "_on_boundary_updated"))
		if _session.has_signal("inventory_updated"): _session.connect("inventory_updated", Callable(self, "_on_inventory_updated"))
		if _session.has_signal("as400_status_updated"): _session.connect("as400_status_updated", Callable(self, "_on_as400_updated"))

func _populate_scenarios() -> void:
	if portal_scenario_dropdown == null or _session == null: return
	portal_scenario_dropdown.clear()
	var names: Array[String] = []
	if _session.scenario_loader != null and _session.scenario_loader.has_method("get_scenario_names"):
		names = _session.scenario_loader.call("get_scenario_names")
	else: names = ["default"]
	
	if names.has("Standard Loading"):
		names.erase("Standard Loading")
		names.push_front("Standard Loading")
		
	for n in names: portal_scenario_dropdown.add_item(n)
	if portal_scenario_dropdown.item_count > 0: portal_scenario_dropdown.select(0)

func _on_decision_pressed(action: String) -> void:
	if _session == null: return
	_session.call("manual_decision", action)

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)

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
	var window_text := "Not Active"
	if _strip_window_active: window_text = "Active"
	role_strip_label.text = "Assignment: %s | Window: %s" % [_strip_assignment, window_text]

func _on_as400_updated(t_uats: int, t_col: int, l_uats: int, l_col: int) -> void:
	if as400_summary_label != null:
		as400_summary_label.text = "[font_size=18][color=#2ecc71]EXPECTED: %d UATs | %d Collis[/color]\n\n[color=#95a5a6]LOADED: %d UATs | %d Collis[/color][/font_size]" % [t_uats, t_col, l_uats, l_col]

func _on_inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	if truck_cap_label != null:
		var spaces_left = cap_max - cap_used
		var color_hex = "#f5f6fa" 
		if spaces_left <= 5.0: color_hex = "#e74c3c"
		truck_cap_label.text = "[center][color=#7f8fa6]Capacity: %0.1f / %0.1f[/color]\n[b][color=%s]Spaces Left: %0.1f[/color][/b][/center]" % [cap_used, cap_max, color_hex, spaces_left]

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
		
	_update_truck_visualizer(loaded)
	
	if raq_vbox != null:
		for child in raq_vbox.get_children(): child.queue_free()
		var regular_uats = []
		var cc_uats = []
		for p in avail:
			if p.is_uat:
				if p.type == "C&C": cc_uats.append(p)
				else: regular_uats.append(p)
		
		for p in regular_uats:
			var lbl = Label.new()
			lbl.text = "UAT: " + p.id + " (" + p.type + ")"
			lbl.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44))
			raq_vbox.add_child(lbl)
			
		for p in cc_uats:
			var lbl = Label.new()
			lbl.text = "UAT: " + p.id + " (" + p.type + ")"
			lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			raq_vbox.add_child(lbl)

func _get_type_color(p_type: String) -> Color:
	if p_type == "C&C": return Color(1.0, 1.0, 1.0) 
	if p_type == "Bikes": return Color(0.2, 0.7, 0.3)
	if p_type == "Bulky": return Color(0.9, 0.5, 0.1)
	if p_type == "Mecha": return Color(0.0, 0.51, 0.76)
	if p_type == "ServiceCenter": return Color(0.8, 0.8, 0.1)
	return Color(0.5, 0.5, 0.5)

func _update_truck_visualizer(loaded_pallets: Array) -> void:
	if truck_grid.columns != 3: truck_grid.columns = 3
	for child in truck_grid.get_children(): child.queue_free()
	
	for i in range(loaded_pallets.size()):
		var p = loaded_pallets[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(50, 50) 
		btn.text = "" 
		
		var color = _get_type_color(p.type)
		var sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.corner_radius_top_left = 2
		sb.corner_radius_bottom_right = 2
		
		var sb_hover = sb.duplicate()
		sb_hover.border_width_left = 3
		sb_hover.border_width_top = 3
		sb_hover.border_width_right = 3
		sb_hover.border_width_bottom = 3
		
		var is_reachable = i >= (loaded_pallets.size() - 3)
		var hover_text = ""
		
		if is_reachable:
			sb_hover.border_color = Color(0.9, 0.2, 0.2) 
			hover_text = "[font_size=18][color=#e74c3c][b]⚠️ UNLOAD PALLET[/b][/color]\nClick to return [b]%s[/b] to dock.\n[b]Penalty:[/b] +1.1 Minutes[/font_size]" % p.id
		else:
			sb_hover.border_color = Color(0.5, 0.5, 0.5) 
			hover_text = "[font_size=18][color=#95a5a6][b]🔒 BLOCKED[/b][/color]\n[b]%s[/b] is blocked by pallets in front of it. Unload the tail first.[/font_size]" % p.id

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		
		btn.mouse_entered.connect(func(): if lbl_hover_info: lbl_hover_info.text = hover_text)
		btn.mouse_exited.connect(func(): if lbl_hover_info: lbl_hover_info.text = "[color=#95a5a6]Hover over a pallet to scan details instantly...[/color]")
		
		btn.pressed.connect(func(): if _session != null: _session.call("unload_pallet_by_id", p.id))
		truck_grid.add_child(btn)

func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(50, 50)
	btn.text = "" 
	
	var color = _get_type_color(p_data.type)
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 3
	if p_data.type == "C&C": sb.border_color = Color(0.3, 0.3, 0.3) 
	else: sb.border_color = color.darkened(0.25)

	var sb_hover = sb.duplicate()
	sb_hover.border_color = Color(0.1, 0.8, 1.0) 
	sb_hover.border_width_left = 3
	sb_hover.border_width_top = 3
	sb_hover.border_width_right = 3
	sb_hover.border_width_bottom = 3
	sb_hover.shadow_color = Color(0.1, 0.8, 1.0, 0.6)
	sb_hover.shadow_size = 10

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover) 
	btn.add_theme_stylebox_override("focus", sb_hover) 

	var code_str = ""
	if p_data.has("code"): code_str = " | Code: " + p_data.code
	var hover_text = "[font_size=18][color=#0082c3][b]SCAN DATA:[/b][/color] Type: [b]%s[/b]%s\nPromise Date: [b]%s[/b] | Collis: %d | Capacity Space: %0.1f[/font_size]" % [p_data.type, code_str, p_data.promise, p_data.collis, p_data.cap]
	
	btn.mouse_entered.connect(func(): if lbl_hover_info: lbl_hover_info.text = hover_text)
	btn.mouse_exited.connect(func(): if lbl_hover_info: lbl_hover_info.text = "[color=#95a5a6]Hover over a pallet to scan details instantly...[/color]")

	btn.pressed.connect(func(): if _session != null: _session.call("load_pallet_by_id", p_data.id))
	parent.add_child(btn)

func _init_panel_nodes_and_buttons(btn_dock_view: Button) -> void:
	_panel_nodes.clear()
	_panel_nodes["Dock View"] = pnl_dock_stage
	_panel_nodes["AS400"] = pnl_as400_stage
	
	_panel_nodes["Shift Board"] = pnl_shift_board
	_panel_nodes["Loading Plan"] = pnl_loading_plan
	_panel_nodes["Trailer Capacity"] = pnl_trailer_capacity
	_panel_nodes["Phone"] = pnl_phone
	_panel_nodes["Notes"] = pnl_notes
	
	if btn_dock_view != null: btn_dock_view.pressed.connect(func() -> void: _toggle_panel("Dock View"))
	if btn_shift_board != null: btn_shift_board.pressed.connect(func() -> void: _toggle_panel("Shift Board"))
	if btn_loading_plan != null: btn_loading_plan.pressed.connect(func() -> void: _toggle_panel("Loading Plan"))
	if btn_as400 != null: btn_as400.pressed.connect(func() -> void: _toggle_panel("AS400"))
	if btn_trailer_capacity != null: btn_trailer_capacity.pressed.connect(func() -> void: _toggle_panel("Trailer Capacity"))
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
	
	var node = _panel_nodes.get(panel_name, null)
	if node != null: node.visible = make_visible

	if lbl_standby != null:
		var any_open = false
		for p in _panel_state.keys():
			if _panel_state[p]: any_open = true
		lbl_standby.visible = not any_open

func _setup_tooltips() -> void:
	pass
