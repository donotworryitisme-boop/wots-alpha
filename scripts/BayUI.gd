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
var _current_scenario_index: int = 0
var highest_unlocked_scenario: int = 0

# --- PORTAL & STAGE CONTAINERS ---
var portal_overlay: ColorRect
var portal_scenario_dropdown: OptionButton

var top_actions_hbox: HBoxContainer
var stage_hbox: HBoxContainer
var lbl_standby: Label 
var pnl_dock_stage: PanelContainer
var pnl_as400_stage: PanelContainer

# GLOBAL BUTTON REFS FOR SPOTLIGHT
var btn_start_load: Button
var btn_call: Button
var btn_seal: Button
var btn_sop: Button
var btn_dock_view: Button

# --- 4 VERTICAL DOCK LANES ---
var lane_m1: VBoxContainer
var lane_m2: VBoxContainer
var lane_b: VBoxContainer
var lane_misc: VBoxContainer

var truck_grid: GridContainer
var truck_cap_label: RichTextLabel 
var truck_cap_bar: ColorRect
var lbl_hover_info: RichTextLabel 

var debrief_overlay: ColorRect
var lbl_debrief_text: RichTextLabel

# --- AS400 TERMINAL VARIABLES ---
var as400_terminal_display: RichTextLabel
var as400_terminal_input: LineEdit
var as400_state: int = 0
var last_avail_cache: Array = []

var store_destinations: Array = [
	{"name": "ALEXANDRIUM", "code": "2093"},
	{"name": "ALKMAAR", "code": "1570"},
	{"name": "AMSTERDAM NOORD", "code": "2226"},
	{"name": "APELDOORN", "code": "896"},
	{"name": "ARENA", "code": "256"},
	{"name": "ARNHEM", "code": "1089"}
]
var current_dest_name: String = "ALKMAAR"
var current_dest_code: String = "1570"

var sop_overlay: ColorRect
var sop_search_input: LineEdit
var sop_results_vbox: VBoxContainer
var sop_content_label: RichTextLabel

# --- NEW SPOTLIGHT TUTORIAL SYSTEM ---
var tut_canvas: CanvasLayer
var tutorial_label: RichTextLabel
var tut_dim_overlay: ColorRect
var tut_highlight_box: ReferenceRect
var tut_screen_margin: MarginContainer
var tut_aligner: VBoxContainer
var _tut_target_node: Control

var tutorial_active: bool = false
var tutorial_step: int = -1

var sop_database: Array = [
	{
		"title": "AS400: Login & Shortcuts",
		"tags": ["as400", "login", "password", "f3", "f10", "terminal", "code", "badge"],
		"content": "[font_size=22][color=#0082c3][b]AS400: Login & Shortcuts[/b][/color][/font_size]\n\nThe AS400 is your primary system for managing expeditions and checking the RAQ.\n\n[b]Login Sequence:[/b]\n1. Code opé/badge: [b]BAYB2B[/b]\n2. Mot de passe: [b]123456[/b]\n\n[b]Navigation:[/b]\n• Type [b]50[/b] for Ship Dock 390\n• Then [b]01[/b] → [b]02[/b] → [b]05[/b] to reach the RAQ\n\n[b]Shortcuts:[/b]\n• [b]F3[/b] — Go back one screen (Retour/Sortie)\n• [b]F10[/b] — Confirm/Validate the RAQ\n• [b]F5[/b] — Refresh data on scanning screen",
		"scenarios": [0, 1, 2],
		"new_in": 0
	},
	{
		"title": "C&C (Click & Collect): What is it?",
		"tags": ["click", "collect", "c&c", "white", "customer", "last"],
		"content": "[font_size=22][color=#0082c3][b]Click & Collect (C&C)[/b][/color][/font_size]\n\nC&C pallets contain items ordered by customers online. They are waiting at the store to pick them up.\n\n[color=#e74c3c][b]THE RULE:[/b][/color] C&C MUST be loaded [b]LAST[/b] — closest to the truck doors — so they come off first at the store.\n\n[b]How to identify C&C on the AS400:[/b]\nC&C lines appear in [color=#ffffff][b]WHITE text[/b][/color] on the RAQ screen (all other pallets are cyan/green).\n\n[b]Typical C&C per store:[/b] 1 plastic pallet + 1 magnum + 1 EUR wooden. If more than 3 total, extras go on magnums or wooden — never a second plastic.",
		"scenarios": [0, 1, 2],
		"new_in": 0
	},
	{
		"title": "Loading: The Standard Sequence",
		"tags": ["load", "sequence", "truck", "order", "standard", "first", "lifo"],
		"content": "[font_size=22][color=#0082c3][b]The Standard Loading Sequence[/b][/color][/font_size]\n\nThe physical order matters because the store unloads from the doors inward (LIFO — Last In, First Out).\n\n[b]Load in this exact order:[/b]\n1. [color=#f1c40f][b]Service Center (Stands)[/b][/color] — Yellow — deepest in truck\n2. [color=#2ecc71][b]Bikes[/b][/color] — Green\n3. [color=#e67e22][b]Bulky[/b][/color] — Orange\n4. [color=#3498db][b]Mecha (Blue Boxes)[/b][/color] — Blue\n5. [color=#95a5a6][b]Click & Collect[/b][/color] — White — closest to doors (ALWAYS LAST)\n\n[b]Why this order?[/b]\nThe store needs C&C first (customers waiting), then mecha for shelf stocking, then bulky and bikes which take longer to process.",
		"scenarios": [0, 1, 2],
		"new_in": 0
	},
	{
		"title": "What is a UAT?",
		"tags": ["uat", "label", "number", "pallet", "barcode", "orange"],
		"content": "[font_size=22][color=#0082c3][b]What is a UAT?[/b][/color][/font_size]\n\nA UAT (Unité d'Aide au Transport) is a scannable pallet unit. Each UAT has an orange label with:\n\n• [b]Sector:[/b] 84/86 (mecha), 84/89 (bikes), 84/90 (bulky)\n• [b]Pallet type:[/b] 20-PALETTE EUROPE or PLASTIQUE\n• [b]EXP/DEST:[/b] Sender and destination warehouse/store\n• [b]Colis count, weight, volume[/b]\n• [b]Flow code:[/b] MAG (store), MAP (store palletized)\n• [b]Barcode:[/b] The UAT number you scan\n\n[b]UAT Number formats:[/b]\n• AS400: 15 digits (00900084XXXXXXX)\n• Scanner: 16 digits\n• EWM: 20 digits\n\n[b]Colis prefix identification:[/b]\n• 8486 = Mecha (sorter/Bay B2B)\n• 8490 = Bulky\n• 8489 = Bikes\n• 0035 = Service Center (EWM format)",
		"scenarios": [0, 1, 2],
		"new_in": 0
	},
	{
		"title": "Reading the RAQ Screen",
		"tags": ["raq", "screen", "columns", "as400", "read", "flx", "uni", "nbc"],
		"content": "[font_size=22][color=#0082c3][b]Reading the RAQ Screen[/b][/color][/font_size]\n\nThe RAQ (PJJIDFR) shows all parcels/UATs assigned to your truck.\n\n[b]Column definitions:[/b]\n• [b]N° U.A.T[/b] — UAT number (15 digits)\n• [b]Flx[/b] — Flow: MAG (store), MAP (palletized), @Z/UE@Z (internet)\n• [b]Uni[/b] — Universe number (* = mixed universe)\n• [b]NBC[/b] — Number of colis on this UAT\n• [b]SE[/b] — Sector: 86=mecha, 89=bikes, 90=bulky\n• [b]EM[/b] — Container type: 01=Plastic, 02=Box, 03=Magnum\n• [b]Colis[/b] — Individual parcel number\n• [b]Dt Col / Dt Exp[/b] — Collection/Expedition dates\n\n[b]Color coding:[/b]\n• [color=#00ffff]Cyan/Green[/color] = Regular pallets\n• [color=#ffffff]White[/color] = C&C (PRIORITY — customer waiting)\n• [color=#ff0000]Red[/color] = Hazardous materials (PRIORITY)",
		"scenarios": [0, 1, 2],
		"new_in": 0
	},
	{
		"title": "Promise Dates: Capacity & Priority",
		"tags": ["promise", "date", "d+", "d-", "priority", "capacity", "full"],
		"content": "[font_size=22][color=#0082c3][b]Promise Dates & Capacity[/b][/color][/font_size]\n\nWhen you have more pallets than the truck can hold, you must choose what to leave behind.\n\n[color=#e74c3c][b]D-[/b] : Overdue.[/color] CRITICAL. Must be loaded.\n[color=#f1c40f][b]D[/b]  : Due today.[/color] High priority. Must be loaded.\n[color=#95a5a6][b]D+[/b] : Due tomorrow.[/color] Low priority.\n\n[b]The Rule:[/b] Load ALL D- and D pallets first (following the standard sequence). Only load D+ pallets if you still have space. Never leave D- or D behind while loading D+.",
		"scenarios": [2],
		"new_in": 2
	},
	{
		"title": "The CMR Document",
		"tags": ["cmr", "document", "paper", "transport", "legal", "seal"],
		"content": "[font_size=22][color=#0082c3][b]The CMR Document[/b][/color][/font_size]\n\nThe CMR is the legal transport document filled AFTER loading.\n\n[b]Key fields:[/b]\n• [b]Box 1 (Sender):[/b] Decathlon Netherlands, Logistiek 9017650000, Kroonstraat 3, 5048 AT TILBURG\n• [b]Box 2 (Destinataire):[/b] Store name + address\n• [b]Box 3:[/b] IDEM 2 (delivery = destinataire)\n• [b]Box 4:[/b] IDEM 1 (pickup = sender)\n• [b]Box 6-7:[/b] Counts — UATs, Colis, EUR pallets, Plastic pallets, Magnums, C&C\n• [b]Box 13:[/b] Seal number + Expedition number + Dock number\n• [b]Box 22:[/b] Sender stamp\n• [b]Box 23:[/b] Driver license plate + signature\n\n[b]Important:[/b] The counts on the CMR come from the Loading Sheet, not from memory. Always fill in the Loading Sheet during loading.",
		"scenarios": [1, 2],
		"new_in": 1
	},
	{
		"title": "The Loading Sheet",
		"tags": ["loading", "sheet", "dual", "count", "eur", "plastic", "magnum"],
		"content": "[font_size=22][color=#0082c3][b]The Loading Sheet[/b][/color][/font_size]\n\nThe Loading Sheet uses a dual-count system:\n\n[b]Left side — by department:[/b]\nTally marks for Bikes, Bulky, Mecha, Transit, C&C. This is what operations cares about.\n\n[b]Right side — by container type:[/b]\nGrids for EUR pallets (1-30), Plastic pallets (1-30), Magnums (1-20). This is what the CMR needs.\n\n[b]The same pallets are counted both ways.[/b]\n\n[b]C&C exception:[/b] C&C is its own category regardless of the container type. A C&C pallet on a EUR wooden base counts as both 'C&C' on the left AND 'EUR pallet' on the right.",
		"scenarios": [1, 2],
		"new_in": 1
	},
	{
		"title": "Dock Lines: Where Departments Deliver",
		"tags": ["dock", "line", "cell", "mecha", "bulky", "bikes", "lane"],
		"content": "[font_size=22][color=#0082c3][b]Dock Lines & Cells[/b][/color][/font_size]\n\nThe warehouse has three cells:\n\n[b]Cell A[/b] (Docks 17-29): Bulky area. Sector 90 reception. Transit pallets unloaded here when possible.\n\n[b]Cell B[/b] (Docks 3, 4, 5): Mecha inbound. Sector 86 reception. Transit often comes mixed with sector 86.\n\n[b]Cell C[/b] (Docks 1C-4C): Bikes ONLY. Sector 89 reception. [color=#e74c3c]Bay B2B does NOT unload bikes receptions — the bikes department handles their own.[/color]\n\n[b]At your loading dock, pallets arrive on 4 lines:[/b]\n• Mecha 1 & 2: Blue boxes from the sorter\n• Bulky: Cardboard on wooden pallets from Cell A\n• Mixed (Bikes/C&C/Service Center): Various departments",
		"scenarios": [1, 2],
		"new_in": 1
	},
	{
		"title": "Loading Quality Rules",
		"tags": ["quality", "tall", "height", "damage", "label", "orientation"],
		"content": "[font_size=22][color=#0082c3][b]Loading Quality Rules[/b][/color][/font_size]\n\n• [b]Heaviest/tallest pallets[/b] go at the bottom-right of the truck to prevent overthrow\n• [b]Never place tall pallets next to short ones[/b] — this causes toppling during transport\n• [b]Max 6 layers[/b] for bulky Type A parcels\n• [b]Label orientation:[/b] Parcel labels must face the loading bay door\n• [b]If you damage goods during loading:[/b] You MUST tell your manager or the duty manager immediately. Do not hide it.\n\n[b]Target:[/b] Complete loading within 1 hour of starting.",
		"scenarios": [1, 2],
		"new_in": 1
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

	# --- STYLE: Top bar ---
	var top_bar = $Root/FrameVBox/TopBar
	if top_bar:
		var tb_sb = StyleBoxFlat.new()
		tb_sb.bg_color = Color(0.08, 0.09, 0.11)
		tb_sb.border_width_bottom = 1
		tb_sb.border_color = Color(0.2, 0.22, 0.25)
		top_bar.add_theme_stylebox_override("panel", tb_sb)
	if top_time_label:
		top_time_label.add_theme_font_size_override("font_size", 15)
		top_time_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	if role_strip_label:
		role_strip_label.add_theme_font_size_override("font_size", 13)
		role_strip_label.add_theme_color_override("font_color", Color(0.5, 0.54, 0.58))

	# --- STYLE: Panel toggle bar ---
	var toggle_bar = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar:
		var ptb_sb = StyleBoxFlat.new()
		ptb_sb.bg_color = Color(0.1, 0.11, 0.13)
		ptb_sb.border_width_left = 1
		ptb_sb.border_color = Color(0.2, 0.22, 0.25)
		toggle_bar.add_theme_stylebox_override("panel", ptb_sb)

	var toggle_buttons = [btn_shift_board, btn_loading_plan, btn_as400, btn_trailer_capacity, btn_phone, btn_notes]
	for tb in toggle_buttons:
		if tb == null: continue
		tb.add_theme_font_size_override("font_size", 13)
		var tb_n = StyleBoxFlat.new()
		tb_n.bg_color = Color(0.15, 0.16, 0.18)
		tb_n.corner_radius_top_left = 4; tb_n.corner_radius_top_right = 4
		tb_n.corner_radius_bottom_left = 4; tb_n.corner_radius_bottom_right = 4
		tb_n.border_width_left = 1; tb_n.border_width_top = 1; tb_n.border_width_right = 1; tb_n.border_width_bottom = 1
		tb_n.border_color = Color(0.25, 0.27, 0.3)
		tb.add_theme_stylebox_override("normal", tb_n)
		var tb_h = tb_n.duplicate()
		tb_h.bg_color = Color(0.2, 0.22, 0.26)
		tb_h.border_color = Color(0.0, 0.51, 0.76)
		tb.add_theme_stylebox_override("hover", tb_h)
		tb.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		tb.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	_build_start_portal()
	_build_operational_layout()
	_build_debrief_modal()
	_build_sop_modal()
	_build_tutorial_ui()

	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

func _process(_delta: float) -> void:
	if tutorial_active and _tut_target_node != null and is_instance_valid(_tut_target_node) and _tut_target_node.visible:
		tut_highlight_box.visible = true
		tut_highlight_box.global_position = _tut_target_node.global_position - Vector2(4, 4)
		tut_highlight_box.size = _tut_target_node.size + Vector2(8, 8)
	elif tut_highlight_box != null:
		tut_highlight_box.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_F3:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 7: as400_state = 6
				elif as400_state == 6: as400_state = 5
				elif as400_state == 10: as400_state = 2
				elif as400_state == 11: as400_state = 3
				elif as400_state == 12: as400_state = 4
				elif as400_state > 0: as400_state -= 1
				_render_as400_screen()
		elif event.keycode == KEY_F10:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				_confirm_as400_raq()

# ==========================================
# THE SPOTLIGHT TUTORIAL SYSTEM
# ==========================================
func _build_tutorial_ui() -> void:
	tut_canvas = CanvasLayer.new()
	tut_canvas.layer = 100 
	tut_canvas.visible = false
	self.add_child(tut_canvas)
	
	tut_dim_overlay = ColorRect.new()
	tut_dim_overlay.visible = false
	tut_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_canvas.add_child(tut_dim_overlay)

	tut_highlight_box = ReferenceRect.new()
	tut_highlight_box.border_color = Color(1.0, 0.8, 0.1)
	tut_highlight_box.border_width = 4
	tut_highlight_box.editor_only = false
	tut_highlight_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_canvas.add_child(tut_highlight_box)
	
	tut_screen_margin = MarginContainer.new()
	tut_screen_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tut_screen_margin.anchor_bottom = 0.0
	tut_screen_margin.offset_top = 50
	tut_screen_margin.offset_bottom = 50
	tut_screen_margin.add_theme_constant_override("margin_left", 8)
	tut_screen_margin.add_theme_constant_override("margin_right", 200)
	tut_screen_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_canvas.add_child(tut_screen_margin)
	
	tut_aligner = VBoxContainer.new()
	tut_aligner.alignment = BoxContainer.ALIGNMENT_BEGIN
	tut_aligner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_screen_margin.add_child(tut_aligner)
	
	var tut_panel = PanelContainer.new()
	tut_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 3
	sb.border_color = Color(0.18, 0.8, 0.44) 
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	tut_panel.add_theme_stylebox_override("panel", sb)
	tut_aligner.add_child(tut_panel)
	
	var tut_margin = MarginContainer.new()
	tut_margin.add_theme_constant_override("margin_left", 16)
	tut_margin.add_theme_constant_override("margin_top", 10)
	tut_margin.add_theme_constant_override("margin_right", 16)
	tut_margin.add_theme_constant_override("margin_bottom", 10)
	tut_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_panel.add_child(tut_margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_margin.add_child(hbox)
	
	var icon_lbl = Label.new()
	icon_lbl.text = "🎓"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_lbl)
	
	tutorial_label = RichTextLabel.new()
	tutorial_label.bbcode_enabled = true
	tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tutorial_label.fit_content = true 
	tutorial_label.custom_minimum_size = Vector2(0, 36)
	tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(tutorial_label)

func _set_tutorial_focus(target: Control, _pos: String, _dim: bool):
	_tut_target_node = target
	tut_dim_overlay.visible = false

func _update_tutorial_ui() -> void:
	if not tutorial_active or tutorial_label == null: return
	
	var t = "[font_size=17][color=#2ecc71][b]TRAINING GUIDE[/b][/color]  "
	
	match tutorial_step:
		0: 
			t += "Welcome to the dock! Your very first step is checking the RAQ list. Open the [color=#f1c40f][b]AS400[/b][/color] from the right panel menu."
			_set_tutorial_focus(btn_as400, "top", true)
		1: 
			t += "Great. Now log in to the terminal. Type [color=#f1c40f]BAYB2B[/color] and press Enter, then type the password [color=#f1c40f]123456[/color] and press Enter."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		2: 
			t += "You are in! Navigate to the RAQ list by typing this sequence: [color=#f1c40f]50[/color] -> [color=#f1c40f]01[/color] -> [color=#f1c40f]02[/color] -> [color=#f1c40f]05[/color]."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		3: 
			t += "This is the RAQ. Notice the [color=#bdc3c7]White text[/color] at the bottom—these are your Click & Collect (C&C) pallets! Now, open the [color=#f1c40f][b]Dock View[/b][/color] panel."
			_set_tutorial_focus(btn_dock_view, "top", true)
		4: 
			t += "Compare the White C&C pallets in the AS400 to the Dock View. One is missing! Click [color=#f1c40f][b]Call Departments (C&C Check)[/b][/color] at the top to find it."
			_set_tutorial_focus(btn_call, "bottom", true)
		5: 
			t += "Good! The missing pallet was found and brought to the dock. Now, click [color=#f1c40f][b]Start Loading[/b][/color] to begin the physical loading process."
			_set_tutorial_focus(btn_start_load, "bottom", true)
		6: 
			t += "Look at the [b]Capacity[/b] panel. Pallets have different sizes. Let's learn to fix mistakes. Click any [color=#3498db]Blue Mecha[/color] pallet to intentionally load it out of order."
			_set_tutorial_focus(null, "top", false)
		7: 
			t += "Oops! Mecha is the wrong sequence. Click the [color=#3498db]Blue[/color] pallet [b]inside the truck grid[/b] to remove it. In real shifts, removing a pallet adds a 1.1-minute rework penalty!"
			_set_tutorial_focus(truck_grid, "top", false)
		8: 
			t += "Good recovery. Now, let's do it right. Always load [color=#f1c40f]Yellow Service Center[/color] pallets first. Click a yellow pallet to load it."
			_set_tutorial_focus(null, "top", false)
		9: 
			t += "Perfect! Next is [color=#2ecc71]Green Bikes[/color]. Click a green pallet to load it."
			_set_tutorial_focus(null, "top", false)
		10: 
			t += "Awesome! Before you finish, click [color=#3498db][b]Help & SOPs[/b][/color] in the top right. Time stops when this is open! Check out how new, important articles are highlighted."
			_set_tutorial_focus(btn_sop, "bottom", true)
		11: 
			t += "Great! All the tutorial info is stored there. Now, finish loading all remaining pallets onto the truck (Yellow -> Green -> Orange -> Blue -> White C&C)."
			_set_tutorial_focus(null, "top", false)
		12: 
			t += "All pallets loaded! Open the [color=#f1c40f][b]AS400[/b][/color] and press [color=#f1c40f][b]F10[/b][/color] on your keyboard to confirm the RAQ."
			_set_tutorial_focus(btn_as400, "top", false)
		13: 
			t += "Validation Effectuée! Click [color=#f1c40f][b]Seal Truck & Print Papers[/b][/color]. You'll see a Shift Summary explaining what you did right or wrong. Finish your shift!"
			_set_tutorial_focus(btn_seal, "bottom", true)
	
	t += "[/font_size]"
	tutorial_label.text = t
	
	if tutorial_step > 13:
		tut_canvas.visible = false

func _flash_tutorial_warning(msg: String) -> void:
	if not tutorial_active or tutorial_label == null: return
	var t = "[font_size=17][color=#e74c3c][b]⚠️ INCORRECT ACTION[/b]  "
	t += msg + "[/color][/font_size]"
	tutorial_label.text = t
	get_tree().create_timer(2.5).timeout.connect(_update_tutorial_ui)

# ==========================================
# PROGRESSIVE SOP KNOWLEDGE BASE MODAL
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

	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split_hbox)

	var left_pnl = PanelContainer.new()
	left_pnl.custom_minimum_size = Vector2(400, 0)
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
	sop_search_input.placeholder_text = "Search SOPs..."
	sop_search_input.custom_minimum_size = Vector2(0, 40)
	sop_search_input.text_changed.connect(_on_sop_search_changed)
	left_vbox.add_child(sop_search_input)
	
	var scroll_res = ScrollContainer.new()
	scroll_res.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_res)
	
	sop_results_vbox = VBoxContainer.new()
	sop_results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_res.add_child(sop_results_vbox)

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
	if _session != null: _session.call("set_pause_state", true)
	sop_search_input.text = ""
	sop_content_label.text = "[color=#95a5a6]Select an article from the left to read the standard operating procedure.[/color]"
	_on_sop_search_changed("") 
	sop_overlay.visible = true
	
	if tutorial_active and tutorial_step == 10:
		tutorial_step = 11
		_update_tutorial_ui()

func _close_sop_modal() -> void:
	if _session != null: _session.call("set_pause_state", false) 
	sop_overlay.visible = false

func _on_sop_search_changed(query: String) -> void:
	for child in sop_results_vbox.get_children():
		child.queue_free()
		
	var q = query.to_lower()
	var new_arts = []
	var old_arts = []
	
	for article in sop_database:
		if not article.scenarios.has(_current_scenario_index):
			continue 
			
		var match_found = false
		if q == "": match_found = true
		elif q in article.title.to_lower(): match_found = true
		else:
			for tag in article.tags:
				if q in tag.to_lower(): match_found = true
				
		if match_found:
			if article.get("new_in", -1) == _current_scenario_index:
				new_arts.append(article)
			else:
				old_arts.append(article)
				
	var create_btn = func(art, is_new):
		var btn = Button.new()
		var prefix = "✨ NEW: " if is_new else ""
		btn.text = prefix + art.title
		btn.custom_minimum_size = Vector2(0, 45)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var btn_sb = StyleBoxFlat.new()
		btn_sb.border_width_bottom = 1
		btn_sb.border_color = Color(0.8, 0.8, 0.8)
		if is_new:
			btn_sb.bg_color = Color(1.0, 0.98, 0.8) 
		else:
			btn_sb.bg_color = Color.WHITE
		
		var btn_hover = btn_sb.duplicate()
		btn_hover.bg_color = Color(0.9, 0.95, 1.0) 
		
		btn.add_theme_stylebox_override("normal", btn_sb)
		btn.add_theme_stylebox_override("hover", btn_hover)
		
		var t_color = Color(0.7, 0.4, 0.0) if is_new else Color(0.2, 0.2, 0.2)
		btn.add_theme_color_override("font_color", t_color)
		btn.add_theme_color_override("font_hover_color", Color(0.0, 0.5, 0.8))
		
		btn.pressed.connect(func(): sop_content_label.text = art.content)
		sop_results_vbox.add_child(btn)
		
	for a in new_arts: create_btn.call(a, true)
	for a in old_arts: create_btn.call(a, false)

# ==========================================
# START PORTAL
# ==========================================
func _build_start_portal() -> void:
	portal_overlay = ColorRect.new()
	portal_overlay.color = Color(0.06, 0.08, 0.11, 1.0)
	portal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(portal_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	portal_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(520, 480)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_top = 3
	sb.border_color = Color(0.0, 0.51, 0.76)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 35)
	pnl.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Decathlon wordmark
	var brand_lbl = Label.new()
	brand_lbl.text = "DECATHLON"
	brand_lbl.add_theme_font_size_override("font_size", 14)
	brand_lbl.add_theme_color_override("font_color", Color(0.0, 0.51, 0.76))
	brand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(brand_lbl)

	var title = Label.new()
	title.text = "Bay B2B"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Operational Training Simulator"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Divider
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.25, 0.27, 0.3)
	vbox.add_child(div)

	var lbl_scen = Label.new()
	lbl_scen.text = "Select Training Scenario"
	lbl_scen.add_theme_font_size_override("font_size", 14)
	lbl_scen.add_theme_color_override("font_color", Color(0.6, 0.63, 0.67))
	vbox.add_child(lbl_scen)

	portal_scenario_dropdown = OptionButton.new()
	portal_scenario_dropdown.custom_minimum_size = Vector2(0, 45)
	var dd_sb = StyleBoxFlat.new()
	dd_sb.bg_color = Color(0.18, 0.19, 0.22)
	dd_sb.corner_radius_top_left = 4; dd_sb.corner_radius_top_right = 4
	dd_sb.corner_radius_bottom_left = 4; dd_sb.corner_radius_bottom_right = 4
	dd_sb.border_width_left = 1; dd_sb.border_width_top = 1; dd_sb.border_width_right = 1; dd_sb.border_width_bottom = 1
	dd_sb.border_color = Color(0.3, 0.32, 0.35)
	portal_scenario_dropdown.add_theme_stylebox_override("normal", dd_sb)
	portal_scenario_dropdown.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	vbox.add_child(portal_scenario_dropdown)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Warehouse ID line
	var wh_lbl = Label.new()
	wh_lbl.text = "NLDKL01 · W146 · QUAI390"
	wh_lbl.add_theme_font_size_override("font_size", 11)
	wh_lbl.add_theme_color_override("font_color", Color(0.35, 0.37, 0.4))
	wh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wh_lbl)

	var btn_start = Button.new()
	btn_start.text = "Begin Shift"
	btn_start.custom_minimum_size = Vector2(0, 55)
	
	var start_sb_normal = StyleBoxFlat.new()
	start_sb_normal.bg_color = Color(0.18, 0.19, 0.22)
	start_sb_normal.corner_radius_top_left = 6; start_sb_normal.corner_radius_top_right = 6
	start_sb_normal.corner_radius_bottom_left = 6; start_sb_normal.corner_radius_bottom_right = 6
	start_sb_normal.border_width_left = 1; start_sb_normal.border_width_top = 1
	start_sb_normal.border_width_right = 1; start_sb_normal.border_width_bottom = 1
	start_sb_normal.border_color = Color(0.3, 0.32, 0.35)
	
	var start_sb_hover = StyleBoxFlat.new()
	start_sb_hover.bg_color = Color(0.0, 0.51, 0.76)
	start_sb_hover.corner_radius_top_left = 6; start_sb_hover.corner_radius_top_right = 6
	start_sb_hover.corner_radius_bottom_left = 6; start_sb_hover.corner_radius_bottom_right = 6

	btn_start.add_theme_stylebox_override("normal", start_sb_normal)
	btn_start.add_theme_stylebox_override("hover", start_sb_hover)
	btn_start.add_theme_color_override("font_color", Color(0.6, 0.63, 0.67))
	btn_start.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_start.add_theme_font_size_override("font_size", 18)
	btn_start.pressed.connect(_on_portal_start_pressed)
	vbox.add_child(btn_start)

# ==========================================
# DEBRIEF MODAL
# ==========================================
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
# OPERATIONAL STAGE & VERTICAL DOCK
# ==========================================
func _build_operational_layout() -> void:
	top_actions_hbox = HBoxContainer.new()
	top_actions_hbox.add_theme_constant_override("separation", 10)
	top_actions_hbox.visible = false 
	workspace_vbox.add_child(top_actions_hbox)

	# Helper for styled action buttons
	var make_action_btn = func(text: String, accent: bool) -> Button:
		var b = Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 13)
		var n_sb = StyleBoxFlat.new()
		n_sb.corner_radius_top_left = 4; n_sb.corner_radius_top_right = 4
		n_sb.corner_radius_bottom_left = 4; n_sb.corner_radius_bottom_right = 4
		if accent:
			n_sb.bg_color = Color(0.15, 0.16, 0.19)
			n_sb.border_width_bottom = 2
			n_sb.border_color = Color(0.0, 0.51, 0.76)
		else:
			n_sb.bg_color = Color(0.15, 0.16, 0.19)
			n_sb.border_width_left = 1; n_sb.border_width_top = 1
			n_sb.border_width_right = 1; n_sb.border_width_bottom = 1
			n_sb.border_color = Color(0.25, 0.27, 0.3)
		b.add_theme_stylebox_override("normal", n_sb)
		var p_sb = n_sb.duplicate()
		p_sb.bg_color = Color(0.1, 0.12, 0.15)
		b.add_theme_stylebox_override("pressed", p_sb)
		b.add_theme_stylebox_override("disabled", n_sb)
		b.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color(0.5, 0.55, 0.6))
		b.toggle_mode = false
		return b

	btn_start_load = make_action_btn.call(" Start Loading ", false)
	btn_start_load.pressed.connect(func(): _on_decision_pressed("Start Loading"))
	top_actions_hbox.add_child(btn_start_load)

	btn_call = make_action_btn.call(" Call Departments (C&C Check) ", true)
	btn_call.pressed.connect(func(): _on_decision_pressed("Call departments (C&C check)"))
	top_actions_hbox.add_child(btn_call)

	btn_seal = make_action_btn.call(" Seal Truck & Print Papers ", false)
	btn_seal.pressed.connect(func(): _on_decision_pressed("Seal Truck"))
	top_actions_hbox.add_child(btn_seal)
	
	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_actions_hbox.add_child(top_spacer)
	
	btn_sop = Button.new()
	btn_sop.text = " Help & SOPs "
	btn_sop.custom_minimum_size = Vector2(140, 38)
	btn_sop.add_theme_font_size_override("font_size", 13)
	var sop_sb = StyleBoxFlat.new()
	sop_sb.bg_color = Color(0.12, 0.3, 0.55)
	sop_sb.corner_radius_top_left = 4; sop_sb.corner_radius_top_right = 4
	sop_sb.corner_radius_bottom_left = 4; sop_sb.corner_radius_bottom_right = 4
	btn_sop.add_theme_stylebox_override("normal", sop_sb)
	var sop_h = sop_sb.duplicate()
	sop_h.bg_color = Color(0.0, 0.51, 0.76)
	btn_sop.add_theme_stylebox_override("hover", sop_h)
	btn_sop.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	btn_sop.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_sop.pressed.connect(_open_sop_modal)
	top_actions_hbox.add_child(btn_sop)

	stage_hbox = HBoxContainer.new()
	stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	stage_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_hbox.add_theme_constant_override("separation", 0)
	stage_hbox.visible = false
	workspace_vbox.add_child(stage_hbox)
	
	lbl_standby = Label.new()
	lbl_standby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_standby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_standby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_standby.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_standby.text = "Shift Started.\n\nSelect a tool from the Panels menu to begin operations.\n\n(If you don't know what to do, click 'Help & SOPs' in the top right.)"
	lbl_standby.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	lbl_standby.add_theme_font_size_override("font_size", 22)
	stage_hbox.add_child(lbl_standby)

	_build_dock_stage()
	_build_as400_stage()
	
	btn_dock_view = Button.new()
	btn_dock_view.text = "Dock View"
	btn_shift_board.get_parent().add_child(btn_dock_view)
	btn_shift_board.get_parent().move_child(btn_dock_view, 0)

	# Style the dock view button to match others
	btn_dock_view.add_theme_font_size_override("font_size", 13)
	var dv_n = StyleBoxFlat.new()
	dv_n.bg_color = Color(0.15, 0.16, 0.18)
	dv_n.corner_radius_top_left = 4; dv_n.corner_radius_top_right = 4
	dv_n.corner_radius_bottom_left = 4; dv_n.corner_radius_bottom_right = 4
	dv_n.border_width_left = 1; dv_n.border_width_top = 1; dv_n.border_width_right = 1; dv_n.border_width_bottom = 1
	dv_n.border_color = Color(0.25, 0.27, 0.3)
	btn_dock_view.add_theme_stylebox_override("normal", dv_n)
	var dv_h = dv_n.duplicate()
	dv_h.bg_color = Color(0.2, 0.22, 0.26)
	dv_h.border_color = Color(0.0, 0.51, 0.76)
	btn_dock_view.add_theme_stylebox_override("hover", dv_h)
	btn_dock_view.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	btn_dock_view.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	
	_init_panel_nodes_and_buttons(btn_dock_view)

# ==========================================
# DOCK VIEW — CONCRETE FLOOR + OVERHEAD SIGNS
# ==========================================
func _build_dock_stage() -> void:
	pnl_dock_stage = PanelContainer.new()
	pnl_dock_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl_dock_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pnl_dock_stage.visible = false
	var stage_sb = StyleBoxFlat.new()
	stage_sb.bg_color = Color(0.22, 0.23, 0.24)
	pnl_dock_stage.add_theme_stylebox_override("panel", stage_sb)
	stage_hbox.add_child(pnl_dock_stage)

	var dock_margin = MarginContainer.new()
	dock_margin.add_theme_constant_override("margin_left", 10)
	dock_margin.add_theme_constant_override("margin_top", 8)
	dock_margin.add_theme_constant_override("margin_right", 10)
	dock_margin.add_theme_constant_override("margin_bottom", 8)
	pnl_dock_stage.add_child(dock_margin)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 6)
	dock_margin.add_child(dock_vbox)

	# --- MAIN FLOOR AREA ---
	var floor_split = HBoxContainer.new()
	floor_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	floor_split.add_theme_constant_override("separation", 0)
	dock_vbox.add_child(floor_split)

	# === DOCK LANES (concrete floor) ===
	var dock_lanes_bg = PanelContainer.new()
	dock_lanes_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_lanes_bg.size_flags_stretch_ratio = 2.2
	var sb_dock = StyleBoxFlat.new()
	sb_dock.bg_color = Color(0.62, 0.63, 0.61)
	sb_dock.border_width_bottom = 3
	sb_dock.border_color = Color(0.85, 0.65, 0.0)
	dock_lanes_bg.add_theme_stylebox_override("panel", sb_dock)
	floor_split.add_child(dock_lanes_bg)

	var dock_inner_margin = MarginContainer.new()
	dock_inner_margin.add_theme_constant_override("margin_left", 8)
	dock_inner_margin.add_theme_constant_override("margin_top", 0)
	dock_inner_margin.add_theme_constant_override("margin_bottom", 0)
	dock_inner_margin.add_theme_constant_override("margin_right", 8)
	dock_lanes_bg.add_child(dock_inner_margin)

	var dock_inner_vbox = VBoxContainer.new()
	dock_inner_vbox.add_theme_constant_override("separation", 0)
	dock_inner_margin.add_child(dock_inner_vbox)

	# --- OVERHEAD SIGNS ---
	var signs_hbox = HBoxContainer.new()
	signs_hbox.add_theme_constant_override("separation", 6)
	dock_inner_vbox.add_child(signs_hbox)

	var sign_data = [
		{"label": "MECHA 1", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
		{"label": "MECHA 2", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
		{"label": "BULKY", "sub": "TRANSIT", "color": Color(0.9, 0.5, 0.15)},
		{"label": "BIKES / C&C / SC", "sub": "MIXED", "color": Color(0.2, 0.7, 0.35)}
	]
	for sd in sign_data:
		var sign_panel = PanelContainer.new()
		sign_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sign_sb = StyleBoxFlat.new()
		sign_sb.bg_color = Color(0.1, 0.1, 0.12)
		sign_sb.border_width_top = 3
		sign_sb.border_color = sd.color
		sign_sb.corner_radius_bottom_left = 2
		sign_sb.corner_radius_bottom_right = 2
		sign_panel.add_theme_stylebox_override("panel", sign_sb)
		signs_hbox.add_child(sign_panel)

		var sign_margin = MarginContainer.new()
		sign_margin.add_theme_constant_override("margin_left", 6)
		sign_margin.add_theme_constant_override("margin_top", 5)
		sign_margin.add_theme_constant_override("margin_right", 6)
		sign_margin.add_theme_constant_override("margin_bottom", 5)
		sign_panel.add_child(sign_margin)

		var sign_vbox = VBoxContainer.new()
		sign_vbox.add_theme_constant_override("separation", 0)
		sign_margin.add_child(sign_vbox)

		var sign_lbl = Label.new()
		sign_lbl.text = sd.label
		sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign_lbl.add_theme_font_size_override("font_size", 13)
		sign_lbl.add_theme_color_override("font_color", Color.WHITE)
		sign_vbox.add_child(sign_lbl)

		var sign_sub = Label.new()
		sign_sub.text = sd.sub
		sign_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign_sub.add_theme_font_size_override("font_size", 10)
		sign_sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
		sign_vbox.add_child(sign_sub)

	# --- LANE COLUMNS ---
	var lanes_hbox = HBoxContainer.new()
	lanes_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes_hbox.add_theme_constant_override("separation", 0)
	dock_inner_vbox.add_child(lanes_hbox)

	lane_m1 = VBoxContainer.new(); lane_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m1.alignment = BoxContainer.ALIGNMENT_END; lane_m1.add_theme_constant_override("separation", 4)
	lane_m2 = VBoxContainer.new(); lane_m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m2.alignment = BoxContainer.ALIGNMENT_END; lane_m2.add_theme_constant_override("separation", 4)
	lane_b = VBoxContainer.new(); lane_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_b.alignment = BoxContainer.ALIGNMENT_END; lane_b.add_theme_constant_override("separation", 4)
	lane_misc = VBoxContainer.new(); lane_misc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_misc.alignment = BoxContainer.ALIGNMENT_END; lane_misc.add_theme_constant_override("separation", 4)

	var make_divider = func() -> ColorRect:
		var div = ColorRect.new()
		div.custom_minimum_size = Vector2(2, 0)
		div.size_flags_vertical = Control.SIZE_EXPAND_FILL
		div.color = Color(1, 1, 1, 0.3)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return div

	lanes_hbox.add_child(lane_m1)
	lanes_hbox.add_child(make_divider.call())
	lanes_hbox.add_child(lane_m2)
	lanes_hbox.add_child(make_divider.call())
	lanes_hbox.add_child(lane_b)
	lanes_hbox.add_child(make_divider.call())
	lanes_hbox.add_child(lane_misc)

	# --- ORANGE FLOOR LABELS ---
	var floor_labels_hbox = HBoxContainer.new()
	floor_labels_hbox.add_theme_constant_override("separation", 6)
	dock_inner_vbox.add_child(floor_labels_hbox)

	var floor_label_texts = ["MECHA 1", "MECHA 2", "BULKY", "BIKES/C&C"]
	for flt in floor_label_texts:
		var fl_panel = PanelContainer.new()
		fl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fl_sb = StyleBoxFlat.new()
		fl_sb.bg_color = Color(0.9, 0.55, 0.1)
		fl_sb.corner_radius_top_left = 2; fl_sb.corner_radius_top_right = 2
		fl_sb.corner_radius_bottom_left = 2; fl_sb.corner_radius_bottom_right = 2
		fl_panel.add_theme_stylebox_override("panel", fl_sb)
		floor_labels_hbox.add_child(fl_panel)

		var fl_lbl = Label.new()
		fl_lbl.text = flt
		fl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl_lbl.add_theme_font_size_override("font_size", 11)
		fl_lbl.add_theme_color_override("font_color", Color.WHITE)
		var fl_m = MarginContainer.new()
		fl_m.add_theme_constant_override("margin_top", 2)
		fl_m.add_theme_constant_override("margin_bottom", 2)
		fl_m.add_child(fl_lbl)
		fl_panel.add_child(fl_m)

	# === TRUCK (door frame) ===
	var truck_outer = PanelContainer.new()
	truck_outer.custom_minimum_size = Vector2(195, 0)
	var truck_frame_sb = StyleBoxFlat.new()
	truck_frame_sb.bg_color = Color(0.35, 0.36, 0.38)
	truck_frame_sb.border_width_left = 5; truck_frame_sb.border_width_right = 5
	truck_frame_sb.border_width_top = 5; truck_frame_sb.border_width_bottom = 0
	truck_frame_sb.border_color = Color(0.55, 0.56, 0.58)
	truck_frame_sb.corner_radius_top_left = 4; truck_frame_sb.corner_radius_top_right = 4
	truck_outer.add_theme_stylebox_override("panel", truck_frame_sb)
	floor_split.add_child(truck_outer)

	var truck_inner = PanelContainer.new()
	truck_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var truck_inner_sb = StyleBoxFlat.new()
	truck_inner_sb.bg_color = Color(0.12, 0.12, 0.14)
	truck_inner_sb.corner_radius_top_left = 2; truck_inner_sb.corner_radius_top_right = 2
	truck_outer.add_child(truck_inner)

	var truck_vbox = VBoxContainer.new()
	truck_vbox.add_theme_constant_override("separation", 4)
	truck_inner.add_child(truck_vbox)

	var truck_header = Label.new()
	truck_header.text = "TRAILER"
	truck_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	truck_header.add_theme_font_size_override("font_size", 11)
	truck_header.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
	truck_vbox.add_child(truck_header)

	truck_cap_label = RichTextLabel.new()
	truck_cap_label.bbcode_enabled = true
	truck_cap_label.scroll_active = false
	truck_cap_label.fit_content = true
	truck_cap_label.text = "[center][color=#7f8fa6]0 / 36[/color][/center]"
	truck_vbox.add_child(truck_cap_label)

	# Capacity bar
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.color = Color(0.2, 0.2, 0.22)
	truck_vbox.add_child(bar_bg)
	truck_cap_bar = ColorRect.new()
	truck_cap_bar.custom_minimum_size = Vector2(0, 6)
	truck_cap_bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	truck_cap_bar.color = Color(0.18, 0.8, 0.44)
	truck_cap_bar.size = Vector2(0, 6)
	bar_bg.add_child(truck_cap_bar)

	truck_grid = GridContainer.new()
	truck_grid.columns = 3
	truck_grid.add_theme_constant_override("h_separation", 3)
	truck_grid.add_theme_constant_override("v_separation", 3)
	truck_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	truck_vbox.add_child(truck_grid)

	var lifo_lbl = Label.new()
	lifo_lbl.text = "← UNLOAD FIRST"
	lifo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lifo_lbl.add_theme_font_size_override("font_size", 10)
	lifo_lbl.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
	truck_vbox.add_child(lifo_lbl)

	var truck_spacer = Control.new()
	truck_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	truck_vbox.add_child(truck_spacer)

	# === SCANNER PANEL (bottom) ===
	var scanner_bg = PanelContainer.new()
	scanner_bg.custom_minimum_size = Vector2(0, 60)
	var scanner_sb = StyleBoxFlat.new()
	scanner_sb.bg_color = Color(0.08, 0.09, 0.1)
	scanner_sb.border_width_top = 1
	scanner_sb.border_color = Color(0.3, 0.3, 0.32)
	scanner_bg.add_theme_stylebox_override("panel", scanner_sb)
	dock_vbox.add_child(scanner_bg)

	var scanner_margin = MarginContainer.new()
	scanner_margin.add_theme_constant_override("margin_left", 12)
	scanner_margin.add_theme_constant_override("margin_top", 6)
	scanner_margin.add_theme_constant_override("margin_right", 12)
	scanner_margin.add_theme_constant_override("margin_bottom", 6)
	scanner_bg.add_child(scanner_margin)

	lbl_hover_info = RichTextLabel.new()
	lbl_hover_info.bbcode_enabled = true
	lbl_hover_info.custom_minimum_size = Vector2(0, 45)
	lbl_hover_info.text = "[font_size=14][color=#5a6a7a]▶ Hover over a pallet to scan...[/color][/font_size]"
	scanner_margin.add_child(lbl_hover_info)

# ==========================================
# AS400 TERMINAL
# ==========================================
func _build_as400_stage() -> void:
	pnl_as400_stage = PanelContainer.new()
	pnl_as400_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl_as400_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pnl_as400_stage.visible = false 
	
	var as400_sb = StyleBoxFlat.new()
	as400_sb.bg_color = Color(0, 0, 0) 
	pnl_as400_stage.add_theme_stylebox_override("panel", as400_sb)
	stage_hbox.add_child(pnl_as400_stage)
	
	var as400_vbox = VBoxContainer.new()
	pnl_as400_stage.add_child(as400_vbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	as400_vbox.add_child(scroll)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	scroll.add_child(margin)

	as400_terminal_display = RichTextLabel.new()
	as400_terminal_display.bbcode_enabled = true
	as400_terminal_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	as400_terminal_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	as400_terminal_display.text = ""
	as400_terminal_display.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	as400_terminal_display.focus_mode = Control.FOCUS_NONE 
	margin.add_child(as400_terminal_display)

	var input_bg = ColorRect.new()
	input_bg.color = Color(0, 0, 0)
	input_bg.custom_minimum_size = Vector2(0, 40)
	as400_vbox.add_child(input_bg)
	
	var input_hbox = HBoxContainer.new()
	input_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_bg.add_child(input_hbox)
	
	var prompt = Label.new()
	prompt.text = " > "
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0)) 
	input_hbox.add_child(prompt)
	
	as400_terminal_input = LineEdit.new()
	as400_terminal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_sb = StyleBoxEmpty.new()
	as400_terminal_input.add_theme_stylebox_override("normal", input_sb)
	as400_terminal_input.add_theme_stylebox_override("focus", input_sb)
	as400_terminal_input.add_theme_color_override("font_color", Color(0, 1, 0))
	as400_terminal_input.add_theme_font_size_override("font_size", 18)
	
	as400_terminal_input.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_on_as400_input_submitted(as400_terminal_input.text)
			as400_terminal_input.accept_event() 
	)
	input_hbox.add_child(as400_terminal_input)

	var btn_hbox = HBoxContainer.new()
	as400_vbox.add_child(btn_hbox)
	
	var btn_confirm = Button.new()
	btn_confirm.text = " [F10] Confirm RAQ "
	btn_confirm.custom_minimum_size = Vector2(0, 40)
	btn_confirm.focus_mode = Control.FOCUS_NONE 
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.2, 0.2, 0.2)
	btn_confirm.add_theme_stylebox_override("normal", btn_sb)
	btn_confirm.pressed.connect(_confirm_as400_raq)
	btn_hbox.add_child(btn_confirm)
	
	pnl_as400_stage.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if as400_terminal_input != null:
				as400_terminal_input.call_deferred("grab_focus")
	)

	_render_as400_screen()

func _confirm_as400_raq() -> void:
	if tutorial_active:
		if tutorial_step < 12:
			_flash_tutorial_warning("Finish loading all pallets into the truck before confirming the RAQ!")
			return
		elif tutorial_step == 12:
			tutorial_step = 13
			_update_tutorial_ui()

	if _session != null:
		_session.call("manual_decision", "Confirm AS400")
	if as400_state == 6:
		as400_state = 7
		_render_as400_screen()

func _render_as400_screen() -> void:
	if as400_terminal_display == null: return
	var t = "[font_size=14]"
	var date_str = "25/03/26"
	
	if as400_state == 0:
		# SIMPLIFIED MENU (PSIP0120) — login prompt
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]Simplified Menu[/color]      [color=#00ff00]***[/color] [color=#00ff00]DKOSUT01[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:00[/color]                  [color=#ffff00]PSIP0120[/color]         [color=#00ff00]ENTER[/color]   [color=#00ff00]SOHKPVR[/color]\n\n"
		t += "[color=#00ffff]                    Profession Opt[/color]\n"
		t += "                                          [color=#00ff00]10  Change Password[/color]\n"
		t += "    [color=#ffff00]1[/color]  [color=#00ff00]-[/color]\n"
		t += "    [color=#ffff00]2[/color]  [color=#00ff00]-[/color]                        [color=#00ff00]20  GE Menu[/color]\n"
		t += "    [color=#ffff00]3[/color]  [color=#00ff00]-[/color]\n"
		t += "    [color=#ffff00]4[/color]  [color=#00ff00]-[/color]                        [color=#00ff00]30  PARCELx[/color]\n\n"
		t += "[color=#00ffff]                Own Options[/color]        [color=#00ff00]40  Recep Dock[/color]  [color=#ffff00]390[/color]\n\n"
		t += "    [color=#ffff00]11[/color] [color=#00ff00]-[/color]                        [color=#00ff00]50  Ship Dock[/color]   [color=#ffff00]390[/color]\n"
		t += "    [color=#ffff00]12[/color] [color=#00ff00]-[/color]\n"
		t += "    [color=#ffff00]13[/color] [color=#00ff00]-[/color]                        [color=#00ff00]80  Modification[/color]\n"
		t += "    [color=#ffff00]14[/color] [color=#00ff00]-[/color]                            [color=#00ff00]Own Options[/color]\n"
		t += "    [color=#ffff00]15[/color] [color=#00ff00]-[/color]\n"
		t += "                                          [color=#00ff00]90  End of session[/color]\n\n"
		t += "[color=#00ff00]              Code opé/badge :[/color] [color=#ffff00]_[/color]\n"
		as400_terminal_input.placeholder_text = "Type 'BAYB2B' and press Enter"
		t += "\n[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Exit  F10=Reinit Docks[/color]\n"
	
	elif as400_state == 1:
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]Simplified Menu[/color]      [color=#00ff00]***[/color] [color=#00ff00]DKOSUT01[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:00[/color]                  [color=#ffff00]PSIP0120[/color]\n\n"
		t += "[color=#00ff00]  Code opé/badge : BAYB2B[/color]\n"
		t += "[color=#00ff00]  Mot de passe   :[/color] [color=#ffff00]_[/color]\n"
		as400_terminal_input.placeholder_text = "Type '123456' and press Enter"
		t += "\n\n[color=#00ffff]F3=Retour   F6=Chgt Mot Passe[/color]\n"
		
	elif as400_state == 2:
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]Simplified Menu[/color]      [color=#00ff00]***[/color] [color=#00ff00]DKOSUT01[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:12[/color]                  [color=#ffff00]PSIP0120[/color]\n\n"
		t += "[color=#00ffff]                Own Options[/color]        [color=#00ff00]40  Recep Dock[/color]  [color=#ffff00]390[/color]\n\n"
		t += "                                        [color=#00ff00]50  Ship Dock[/color]   [color=#ffff00]390[/color]\n\n"
		t += "                                        [color=#00ff00]90  End of session[/color]\n\n"
		t += "[color=#00ff00]              Your Choice[/color] [color=#ffff00]__[/color]\n"
		as400_terminal_input.placeholder_text = "Type '50' for Ship Dock"
		t += "\n\n[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Exit  F10=Reinit Docks[/color]\n"
		
	elif as400_state == 3:
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]SHIP DOCK 390[/color]        [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:18[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIEMDFR[/color]\n\n"
		t += "[color=#00ff00]  01 - Gestion des RAQ[/color]\n"
		t += "[color=#00ff00]  02 - Impression[/color]\n\n"
		t += "[color=#00ff00]  Selection :[/color] [color=#ffff00]__[/color]\n"
		as400_terminal_input.placeholder_text = "Type '01' for RAQ management"
		t += "\n\n\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"
		
	elif as400_state == 4:
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]GESTION DES RAQ[/color]      [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:24[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIEMRFR[/color]\n\n"
		t += "[color=#00ff00]  02 - RAQ Par Camion[/color]\n"
		t += "[color=#00ff00]  03 - RAQ Par Magasin[/color]\n\n"
		t += "[color=#00ff00]  Selection :[/color] [color=#ffff00]__[/color]\n"
		as400_terminal_input.placeholder_text = "Type '02' for RAQ by truck"
		t += "\n\n\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"
		
	elif as400_state == 5:
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]RAQ PAR CAMION[/color]       [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:30[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIEHCFR[/color]\n\n"
		t += "[color=#00ff00]  05 - Afficher RAQ Actuel[/color]\n\n"
		t += "[color=#00ff00]  Selection :[/color] [color=#ffff00]__[/color]\n"
		as400_terminal_input.placeholder_text = "Type '05' to display current RAQ"
		t += "\n\n\n\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"
		
	elif as400_state == 6:
		as400_terminal_input.placeholder_text = "N° Colis ou UAT — F10 to confirm, F3 to exit"
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]      [color=#00ffff]DSPF COLIS RAQ/RAC[/color]       [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:01:00[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PJJIDFR[/color]\n\n"
		t += "[color=#00ff00]Expéditeur   :   14    390   CAR TILBURG EXPE[/color]"
		
		# Count total colis
		var total_colis = 0
		for p in last_avail_cache:
			if p.is_uat: total_colis += p.collis
		t += "       [color=#00ff00]Total colis :   %d[/color]\n" % total_colis
		t += "[color=#00ff00]Destinataire :    7  %5s   %s[/color]\n\n" % [current_dest_code, current_dest_name]
		t += "[color=#00ffff]5=Détail Colis/UAT   7=Validation UAT transit vocal[/color]\n\n"
		t += "[color=#00ff00]? N° U.A.T                  Flx Uni NBC SE EM Colis                  Dt Col  CCC/[/color]\n"
		t += "[color=#00ff00]                              CFP     CD                       Dt Exp Adresse[/color]\n\n"
		
		var regular_uats = []
		var cc_uats = []
		for p in last_avail_cache:
			if p.is_uat:
				if p.type == "C&C": cc_uats.append(p)
				else: regular_uats.append(p)
		
		var se_map = {"Mecha": "86", "Bulky": "90", "Bikes": "89", "ServiceCenter": "86", "C&C": "86"}
		var uni_map = {"Mecha": "62*", "Bulky": "10 ", "Bikes": "63*", "ServiceCenter": "02*", "C&C": "61*"}
		
		for p in regular_uats:
			var se = se_map.get(p.type, "86")
			var uni = uni_map.get(p.type, "02*")
			t += "[color=#00ffff]_ %-20s  MAG %s %3d %s 11 %-20s %s[/color]\n" % [p.id, uni, p.collis, se, p.get("colis_id", "N/A"), "250924"]
			
		for p in cc_uats:
			t += "[color=#ffffff]_ %-20s  MAG 61* %3d 86 11 %-20s %s[/color]\n" % [p.id, p.collis, p.get("colis_id", "N/A"), "250924"]
					
		t += "\n[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Sortie   F5=Ttes UAT   F7=UAT non Adressées   F8=UAT Adressées   F9=CCC/ADR[/color]\n"
		t += "[color=#00ffff]F10=NBC/CFP   F11=EM/CD   F15=Tri F&R[/color]\n"
		
	elif as400_state == 7:
		as400_terminal_input.placeholder_text = "F3=Sortie"
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]      [color=#00ffff]DSPF COLIS RAQ/RAC[/color]       [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:01:00[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PJJIDFR[/color]\n\n"
		t += "[color=#00ff00]Expéditeur   :   14    390   CAR TILBURG EXPE[/color]\n"
		t += "[color=#00ff00]Destinataire :    7  %5s   %s[/color]\n\n" % [current_dest_code, current_dest_name]
		t += "[color=#f1c40f]╔══════════════════════════════════════════════════╗\n"
		t += "║                                                  ║\n"
		t += "║     VALIDATION EFFECTUEE                         ║\n"
		t += "║     (RAQ CONFIRMED)                              ║\n"
		t += "║                                                  ║\n"
		t += "╚══════════════════════════════════════════════════╝[/color]\n\n"
		t += "[color=#00ffff]You may now physically Seal the Truck.[/color]\n"
		t += "\n[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Sortie[/color]\n"

	elif as400_state == 10:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]RECEP DOCK 390[/color]       [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:18[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIRCDFR[/color]\n\n"
		t += "[color=#00ff00]  Réception — Gestion des arrivages[/color]\n\n"
		t += "[color=#00ff00]  Aucune réception en cours.[/color]\n\n"
		t += "[color=#ffff00]  (Ce module n'est pas actif dans cette version de la simulation.)[/color]\n"
		t += "\n\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"

	elif as400_state == 11:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]IMPRESSION[/color]           [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:18[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIEMIFR[/color]\n\n"
		t += "[color=#00ff00]  01 - Imprimer CMR[/color]\n"
		t += "[color=#00ff00]  02 - Imprimer Bordereau[/color]\n"
		t += "[color=#00ff00]  03 - Imprimer Etiquettes[/color]\n\n"
		t += "[color=#ffff00]  (Les impressions ne sont pas actives dans cette version de la simulation.)[/color]\n"
		t += "\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"

	elif as400_state == 12:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "[color=#00ff00]%s[/color]   [color=#00ff00]***[/color]       [color=#00ffff]RAQ PAR MAGASIN[/color]      [color=#00ff00]***[/color]  [color=#00ff00]QUAI390[/color]    [color=#00ff00]NLDKL01[/color]\n" % date_str
		t += "[color=#00ff00]09:00:30[/color]                                    [color=#ffff00]AFFICH.[/color]  [color=#00ff00]PIEHMFR[/color]\n\n"
		t += "[color=#00ff00]  Entrez le code magasin :[/color] [color=#ffff00]_____[/color]\n\n"
		t += "[color=#ffff00]  (La consultation par magasin n'est pas active dans cette version.)[/color]\n"
		t += "\n\n\n\n\n\n\n"
		t += "[color=#00ffff]─────────────────────────────────────────────────────[/color]\n"
		t += "[color=#00ffff]F3=Retour  F12=Annuler[/color]\n"

	t += "[/font_size]"
	as400_terminal_display.text = t

func _on_as400_input_submitted(text: String) -> void:
	var input = text.strip_edges().to_upper()
	as400_terminal_input.text = ""
	
	if as400_state == 0 and input == "BAYB2B": as400_state = 1
	elif as400_state == 1 and input == "123456": as400_state = 2
	elif as400_state == 2:
		if input == "50": as400_state = 3
		elif input == "40": as400_state = 10
	elif as400_state == 3:
		if input == "01": as400_state = 4
		elif input == "02": as400_state = 11
	elif as400_state == 4:
		if input == "02": as400_state = 5
		elif input == "03": as400_state = 12
	elif as400_state == 5 and input == "05": as400_state = 6
	elif as400_state == 6 and input == "F3": as400_state = 5 
	elif as400_state == 7 and input == "F3": as400_state = 6
	elif as400_state == 10 and input == "F3": as400_state = 2
	elif as400_state == 11 and input == "F3": as400_state = 3
	elif as400_state == 12 and input == "F3": as400_state = 4
	
	_render_as400_screen()
	
	if tutorial_active:
		if tutorial_step == 1 and as400_state == 2:
			tutorial_step = 2
			_update_tutorial_ui()
		elif tutorial_step == 2 and as400_state == 6:
			tutorial_step = 3
			_update_tutorial_ui()

# ==========================================
# FLOW LOGIC & DATA UPDATES
# ==========================================
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled: return
	if portal_overlay != null: portal_overlay.visible = true

func _on_portal_start_pressed() -> void:
	if _session == null: return
	var _scenario_name: String = "default"
	if portal_scenario_dropdown != null: _scenario_name = portal_scenario_dropdown.get_item_text(portal_scenario_dropdown.get_selected_id())
	
	_current_scenario_index = portal_scenario_dropdown.get_selected_id()
	if _current_scenario_index == 0: _current_scenario_name = "0. Tutorial"
	elif _current_scenario_index == 1: _current_scenario_name = "1. Standard Loading"
	elif _current_scenario_index == 2: _current_scenario_name = "2. Priority Loading"
	
	_session.set_role(WOTSConfig.Role.OPERATOR)
	_is_active = true
	
	var dest = store_destinations[randi() % store_destinations.size()]
	current_dest_name = dest.name
	current_dest_code = dest.code
	
	portal_overlay.visible = false
	top_actions_hbox.visible = true
	stage_hbox.visible = true
	
	_reset_panel_state()
	_close_all_panels(true)
	
	as400_state = 0
	_render_as400_screen()
	
	if _current_scenario_index == 0:
		tutorial_active = true
		tutorial_step = 0
		tut_canvas.visible = true
		_update_tutorial_ui()
		lbl_standby.text = "Your first shift starts here.\n\nFollow the green Training Guide at the top.\nIt will walk you through every step."
		lbl_standby.visible = true
	else:
		tutorial_active = false
		if tut_canvas != null: tut_canvas.visible = false
		lbl_standby.visible = true
	
	_session.call("start_session_with_scenario", _current_scenario_name)

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))
	
	var passed = debrief_payload.get("passed", false)
	if passed:
		if _current_scenario_index == highest_unlocked_scenario and highest_unlocked_scenario < 2:
			highest_unlocked_scenario += 1
			
	if tutorial_active: tut_canvas.visible = false
	
	_populate_scenarios() 
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

func _populate_scenarios() -> void:
	if portal_scenario_dropdown == null: return
	portal_scenario_dropdown.clear()
	
	var names: Array[String] = [
		"0. Tutorial", 
		"1. Standard Loading", 
		"2. Priority Loading"
	]
	names.sort() 
		
	for i in range(names.size()):
		var n = names[i]
		if i > highest_unlocked_scenario:
			portal_scenario_dropdown.add_item("🔒 " + n)
			portal_scenario_dropdown.set_item_disabled(i, true)
		else:
			portal_scenario_dropdown.add_item(n)
		
	if portal_scenario_dropdown.item_count > 0: 
		portal_scenario_dropdown.select(highest_unlocked_scenario)

func _on_decision_pressed(action: String) -> void:
	if tutorial_active:
		if tutorial_step < 4:
			_flash_tutorial_warning("Follow the guide! We aren't ready for this yet.")
			return
		if tutorial_step == 4:
			if action != "Call departments (C&C check)":
				_flash_tutorial_warning("Count the C&C pallets first and click 'Call Departments'!")
				return
			else:
				tutorial_step = 5
				_update_tutorial_ui()
		elif tutorial_step == 5:
			if action != "Start Loading":
				_flash_tutorial_warning("Now click 'Start Loading' to begin!")
				return
			else:
				tutorial_step = 6
				_update_tutorial_ui()
		elif tutorial_step < 13 and action == "Seal Truck":
			_flash_tutorial_warning("You haven't finished the loading and AS400 validation yet!")
			return
			
	if _session == null: return
	_session.call("manual_decision", action)

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)

func _update_top_time(total_time: float) -> void:
	if top_time_label == null: return
	var mins = int(total_time) / 60
	var secs = int(total_time) % 60
	top_time_label.text = "Shift Time: %02d:%02d" % [mins, secs]

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

func _on_inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	last_avail_cache = avail.duplicate(true)
	
	if as400_state == 6:
		_render_as400_screen() 

	if truck_cap_label != null:
		var _spaces_left = cap_max - cap_used
		var pct = cap_used / cap_max if cap_max > 0 else 0
		var color_hex = "#8fa6bf"
		if pct > 0.85: color_hex = "#e74c3c"
		elif pct > 0.6: color_hex = "#f1c40f"
		truck_cap_label.text = "[center][color=%s][b]%0.0f / %0.0f[/b][/color][/center]" % [color_hex, cap_used, cap_max]

		# Update capacity bar
		if truck_cap_bar != null and truck_cap_bar.get_parent() != null:
			var parent_w = truck_cap_bar.get_parent().size.x
			truck_cap_bar.custom_minimum_size.x = parent_w * pct
			if pct > 0.85: truck_cap_bar.color = Color(0.9, 0.3, 0.25)
			elif pct > 0.6: truck_cap_bar.color = Color(0.94, 0.76, 0.2)
			else: truck_cap_bar.color = Color(0.18, 0.8, 0.44)

	for child in lane_m1.get_children(): child.queue_free()
	for child in lane_m2.get_children(): child.queue_free()
	for child in lane_b.get_children(): child.queue_free()
	for child in lane_misc.get_children(): child.queue_free()

	var buffer_height = 10
	for lane in [lane_m1, lane_m2, lane_b, lane_misc]:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, buffer_height)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane.add_child(spacer)

	var mecha_count = 0
	for p in avail:
		if p.missing: continue
		var row = null
		if p.type == "Mecha": 
			if mecha_count % 2 == 0: row = lane_m1
			else: row = lane_m2
			mecha_count += 1
		elif p.type == "Bulky": row = lane_b
		else: row = lane_misc
		
		_draw_pallet(p, row)
		row.move_child(row.get_child(row.get_child_count() - 1), 0)
		
	_update_truck_visualizer(loaded)
	
	if tutorial_active:
		if tutorial_step == 6:
			for p in loaded:
				if p.type == "Mecha":
					tutorial_step = 7
					_update_tutorial_ui()
					break
		elif tutorial_step == 7:
			var has_mecha = false
			for p in loaded:
				if p.type == "Mecha": has_mecha = true
			if not has_mecha:
				tutorial_step = 8
				_update_tutorial_ui()
		elif tutorial_step == 8:
			for p in loaded:
				if p.type == "ServiceCenter":
					tutorial_step = 9
					_update_tutorial_ui()
					break
		elif tutorial_step == 9:
			for p in loaded:
				if p.type == "Bikes":
					tutorial_step = 10
					_update_tutorial_ui()
					break
		elif tutorial_step == 11:
			if avail.is_empty():
				tutorial_step = 12
				_update_tutorial_ui()

func _get_type_color(p_type: String) -> Color:
	if p_type == "C&C": return Color(1.0, 1.0, 1.0) 
	if p_type == "Bikes": return Color(0.2, 0.7, 0.3)
	if p_type == "Bulky": return Color(0.9, 0.5, 0.1)
	if p_type == "Mecha": return Color(0.0, 0.51, 0.76)
	if p_type == "ServiceCenter": return Color(0.8, 0.8, 0.1)
	return Color(0.5, 0.5, 0.5)

# ==========================================
# TOP-DOWN PALLET GENERATOR (type-specific)
# ==========================================
func _build_pallet_graphic(color: Color, is_truck: bool, p_type: String = "") -> Button:
	var btn = Button.new()
	var p_size = 45 if is_truck else 64
	btn.custom_minimum_size = Vector2(p_size, p_size)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var empty_sb = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)

	var is_plastic = (p_type == "Mecha" or p_type == "C&C")
	var base_bg = ColorRect.new()
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(base_bg)

	if is_plastic:
		base_bg.color = Color(0.15, 0.15, 0.17)
		var grid_h = VBoxContainer.new()
		grid_h.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid_h.add_theme_constant_override("separation", 0)
		grid_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_bg.add_child(grid_h)
		for i in range(3):
			var row = ColorRect.new()
			row.color = Color(0.2, 0.2, 0.22) if i % 2 == 0 else Color(0.15, 0.15, 0.17)
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_h.add_child(row)
	else:
		base_bg.color = Color(0.65, 0.45, 0.25)
		var planks = HBoxContainer.new()
		planks.set_anchors_preset(Control.PRESET_FULL_RECT)
		planks.add_theme_constant_override("separation", 3)
		planks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_bg.add_child(planks)
		for i in range(3):
			var plank = ColorRect.new()
			plank.color = Color(0.78, 0.58, 0.38) if i % 2 == 0 else Color(0.7, 0.5, 0.32)
			plank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			planks.add_child(plank)

	var cargo_margin = MarginContainer.new()
	cargo_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset = 5 if is_truck else 7
	cargo_margin.add_theme_constant_override("margin_left", inset)
	cargo_margin.add_theme_constant_override("margin_top", inset)
	cargo_margin.add_theme_constant_override("margin_right", inset)
	cargo_margin.add_theme_constant_override("margin_bottom", inset)
	cargo_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cargo_margin)

	var cargo_box = ColorRect.new()
	cargo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo_margin.add_child(cargo_box)

	if p_type == "Mecha":
		cargo_box.color = Color(0.15, 0.45, 0.75)
		var mid_line = ColorRect.new()
		mid_line.color = Color(0.1, 0.35, 0.6)
		mid_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		mid_line.custom_minimum_size = Vector2(0, 2)
		mid_line.offset_top = (p_size - inset * 2) * 0.5 - 1
		mid_line.offset_bottom = (p_size - inset * 2) * 0.5 + 1
		mid_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(mid_line)
	elif p_type == "Bulky":
		cargo_box.color = Color(0.82, 0.68, 0.45)
		cargo_box.clip_contents = true
		var tape_h = ColorRect.new()
		tape_h.color = Color(0.65, 0.5, 0.28)
		tape_h.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		tape_h.offset_top = -1; tape_h.offset_bottom = 1
		tape_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(tape_h)
		var tape_v = ColorRect.new()
		tape_v.color = Color(0.65, 0.5, 0.28)
		tape_v.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
		tape_v.offset_left = -1; tape_v.offset_right = 1
		tape_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(tape_v)
	elif p_type == "Bikes":
		cargo_box.color = Color(0.28, 0.62, 0.35)
		var box_line1 = ColorRect.new()
		box_line1.color = Color(0.22, 0.52, 0.28)
		box_line1.set_anchors_preset(Control.PRESET_TOP_WIDE)
		box_line1.custom_minimum_size = Vector2(0, 1)
		box_line1.offset_top = (p_size - inset * 2) * 0.33
		box_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(box_line1)
		var box_line2 = ColorRect.new()
		box_line2.color = Color(0.22, 0.52, 0.28)
		box_line2.set_anchors_preset(Control.PRESET_TOP_WIDE)
		box_line2.custom_minimum_size = Vector2(0, 1)
		box_line2.offset_top = (p_size - inset * 2) * 0.66
		box_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(box_line2)
	elif p_type == "C&C":
		cargo_box.color = Color(0.92, 0.92, 0.92)
		var cc_dot = ColorRect.new()
		cc_dot.color = Color(0.7, 0.7, 0.7)
		cc_dot.custom_minimum_size = Vector2(6, 6)
		cc_dot.set_anchors_preset(Control.PRESET_CENTER)
		cc_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(cc_dot)
	elif p_type == "ServiceCenter":
		cargo_box.color = Color(0.88, 0.82, 0.2)
	else:
		cargo_box.color = color.lerp(Color.WHITE, 0.15)

	var border = ReferenceRect.new()
	border.border_color = color.darkened(0.35)
	border.border_width = 2
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo_box.add_child(border)

	var glow = ReferenceRect.new()
	glow.border_color = Color(0, 0, 0, 0)
	glow.border_width = 3
	glow.editor_only = false
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glow)

	btn.mouse_entered.connect(func(): glow.border_color = Color(0.1, 0.8, 1.0))
	btn.mouse_exited.connect(func(): glow.border_color = Color(0, 0, 0, 0))

	return btn

func _update_truck_visualizer(loaded_pallets: Array) -> void:
	if truck_grid.columns != 3: truck_grid.columns = 3
	for child in truck_grid.get_children(): child.queue_free()
	
	for i in range(loaded_pallets.size()):
		var p = loaded_pallets[i]
		
		var btn = _build_pallet_graphic(_get_type_color(p.type), true, p.type)
		
		var is_reachable = i >= (loaded_pallets.size() - 3)
		var hover_text = ""
		
		if is_reachable:
			hover_text = "[font_size=14][color=#e74c3c][b]⚠ UNLOAD PALLET[/b][/color]\n[color=#aab0b8]U.A.T:[/color] [b]%s[/b]\n[color=#aab0b8]Colis:[/color] %s\n[color=#e74c3c]Penalty: +1.1 min rework[/color][/font_size]" % [p.id, p.get("colis_id", "N/A")]
		else:
			btn.modulate = Color(0.6, 0.6, 0.6) 
			hover_text = "[font_size=14][color=#95a5a6][b]BLOCKED[/b]\n%s\nUnload the pallets near the door first.[/color][/font_size]" % p.id

		btn.mouse_entered.connect(func(): if lbl_hover_info: lbl_hover_info.text = hover_text)
		btn.mouse_exited.connect(func(): if lbl_hover_info: lbl_hover_info.text = "[font_size=14][color=#5a6a7a]▶ Hover over a pallet to scan...[/color][/font_size]")
		
		btn.pressed.connect(func(): 
			if tutorial_active and tutorial_step != 7:
				_flash_tutorial_warning("Don't unload anything right now, follow the guide!")
				return
			if _session != null: _session.call("unload_pallet_by_id", p.id)
		)
		truck_grid.add_child(btn)

func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn = _build_pallet_graphic(_get_type_color(p_data.type), false, p_data.type)

	var code_str = ""
	if p_data.has("code"): code_str = " | Code: " + p_data.code
	var colis_str = p_data.get("colis_id", "N/A")
	
	var base_label = "Plastic" if (p_data.type == "Mecha" or p_data.type == "C&C") else "EUR Wood"
	var hover_text = "[font_size=14][color=#0082c3][b]▶ SCAN DATA[/b][/color]\n"
	hover_text += "[color=#aab0b8]Type:[/color] [b]%s[/b] [color=#6a7a8a](%s)[/color]%s\n" % [p_data.type, base_label, code_str]
	hover_text += "[color=#aab0b8]U.A.T:[/color] [b]%s[/b]   [color=#aab0b8]Colis:[/color] [b]%s[/b]\n" % [p_data.id, colis_str]
	hover_text += "[color=#aab0b8]Promise:[/color] [b]%s[/b]   [color=#aab0b8]Qty:[/color] %d   [color=#aab0b8]Cap:[/color] %0.1f[/font_size]" % [p_data.promise, p_data.collis, p_data.cap]
	btn.mouse_entered.connect(func(): if lbl_hover_info: lbl_hover_info.text = hover_text)
	btn.mouse_exited.connect(func(): if lbl_hover_info: lbl_hover_info.text = "[font_size=14][color=#5a6a7a]▶ Hover over a pallet to scan...[/color][/font_size]")

	btn.pressed.connect(func(): 
		if tutorial_active:
			if tutorial_step < 6:
				_flash_tutorial_warning("We aren't ready to load pallets yet. Follow the guide!")
				return
			if tutorial_step == 6 and p_data.type != "Mecha":
				_flash_tutorial_warning("Click a Blue Mecha pallet so we can learn how to fix mistakes!")
				return
			if tutorial_step == 7:
				_flash_tutorial_warning("Remove the Blue Mecha pallet from the truck first by clicking it in the Trailer Capacity panel!")
				return
			if tutorial_step == 8 and p_data.type != "ServiceCenter":
				_flash_tutorial_warning("Wait! You must load the Yellow Service Center pallet first.")
				return
			if tutorial_step == 9 and p_data.type != "Bikes":
				_flash_tutorial_warning("Wait! You must load the Green Bikes pallet next.")
				return
			if tutorial_step == 10:
				_flash_tutorial_warning("Click 'Help & SOPs' in the top right before continuing!")
				return
				
		if _session != null: _session.call("load_pallet_by_id", p_data.id)
	)
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
	if tutorial_active:
		if tutorial_step < 3 and panel_name != "AS400":
			_flash_tutorial_warning("Please open the AS400 panel first!")
			return
		if tutorial_step == 3 and panel_name != "Dock View" and panel_name != "AS400":
			_flash_tutorial_warning("Please open the Dock View next!")
			return

	var is_open: bool = bool(_panel_state.get(panel_name, false))
	_set_panel_visible(panel_name, not is_open, false)

func _set_panel_visible(panel_name: String, make_visible: bool, _silent: bool) -> void:
	_panel_state[panel_name] = make_visible
	if make_visible: panels_ever_opened[panel_name] = true 
	
	var node = _panel_nodes.get(panel_name, null)
	if node != null: node.visible = make_visible

	if lbl_standby != null:
		var any_open = false
		for p in _panel_state.keys():
			if _panel_state[p]: any_open = true
		lbl_standby.visible = not any_open

	if panel_name == "AS400" and make_visible and as400_terminal_input != null:
		as400_terminal_input.call_deferred("grab_focus")
		
	if tutorial_active:
		if tutorial_step == 0 and panel_name == "AS400" and make_visible:
			tutorial_step = 1
			_update_tutorial_ui()
		elif tutorial_step == 3 and panel_name == "Dock View" and make_visible:
			tutorial_step = 4
			_update_tutorial_ui()
