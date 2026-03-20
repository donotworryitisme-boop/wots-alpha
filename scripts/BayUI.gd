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
var portal_scenario_desc: RichTextLabel

var top_actions_hbox: HBoxContainer
var stage_hbox: HBoxContainer
var lbl_standby: Label 
var pnl_dock_stage: PanelContainer
var pnl_as400_stage: PanelContainer

# GLOBAL BUTTON REFS FOR SPOTLIGHT
var btn_start_load: Button
var btn_call: Button
var btn_seal: Button

# Dock lane rebuild support
var dock_signs_hbox: HBoxContainer
var dock_lanes_hbox: HBoxContainer
var dock_floor_labels_hbox: HBoxContainer
var dock_inner_vbox_ref: VBoxContainer
# Co-loading lanes (6 lanes: 3 per store)
var co_lanes: Dictionary = {}  # Key: "s1_mecha", "s1_bulky", "s1_misc", "s2_mecha", "s2_bulky", "s2_misc"

# Phone notification system
var phone_messages: Array = []
var phone_flash_active: bool = false
var _load_cooldown: bool = false  # Prevents spam-clicking pallets
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
var _badge_target: int = 18  # Where to go after badge login (18=scanning, 19=SAISIE)
var last_avail_cache: Array = []
var last_loaded_cache: Array = []

var store_destinations: Array = [
	{"name": "ALEXANDRIUM", "code": "2093", "co_partner": "2226"},
	{"name": "ALKMAAR", "code": "1570", "co_partner": ""},
	{"name": "AMSTERDAM NOORD", "code": "2226", "co_partner": "2093"},
	{"name": "APELDOORN", "code": "896", "co_partner": ""},
	{"name": "ARENA", "code": "256", "co_partner": ""},
	{"name": "ARNHEM", "code": "1089", "co_partner": ""},
	{"name": "BEST", "code": "664", "co_partner": ""},
	{"name": "BREDA", "code": "1088", "co_partner": ""},
	{"name": "COOLSINGEL", "code": "1161", "co_partner": "1186"},
	{"name": "DEN BOSCH", "code": "3619", "co_partner": ""},
	{"name": "DEN HAAG", "code": "1186", "co_partner": "1161"},
	{"name": "EINDHOVEN", "code": "1185", "co_partner": ""},
	{"name": "ENSCHEDE", "code": "2092", "co_partner": "2225"},
	{"name": "GRONINGEN", "code": "2224", "co_partner": "897"},
	{"name": "KERKRADE", "code": "346", "co_partner": "2094"},
	{"name": "LEEUWARDEN", "code": "897", "co_partner": "2224"},
	{"name": "NIJMEGEN", "code": "2225", "co_partner": "2092"},
	{"name": "ROERMOND", "code": "2094", "co_partner": "346"},
]

var co_pairs: Array = [
	{"store1": "KERKRADE", "code1": "346", "store2": "ROERMOND", "code2": "2094"},
	{"store1": "COOLSINGEL", "code1": "1161", "store2": "DEN HAAG", "code2": "1186"},
	{"store1": "GRONINGEN", "code1": "2224", "store2": "LEEUWARDEN", "code2": "897"},
	{"store1": "ENSCHEDE", "code1": "2092", "store2": "NIJMEGEN", "code2": "2225"},
	{"store1": "ALEXANDRIUM", "code1": "2093", "store2": "AMSTERDAM NOORD", "code2": "2226"},
]
var current_dest_name: String = "ALKMAAR"
var current_dest_code: String = "1570"
var current_dest2_name: String = ""
var current_dest2_code: String = ""

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
	{"title": "AS400: Login & Shortcuts", "tags": ["as400", "login", "password", "f3", "f10", "terminal", "code", "badge"], "content": "[font_size=28][color=#0082c3][b]AS400: Login & Shortcuts[/b][/color][/font_size]\n\nThe AS400 (nldkl01.neptune.dkcorp.net) is your primary system.\n\n[b]Two logins required:[/b]\n\n[b]1. System login (Sign On screen):[/b]\n• User: [b]BAYB2B[/b]\n• Password: [b]123456[/b]\n\n[b]2. Badge login (before scanning screen):[/b]\n• Code opé/badge: [b]8600555[/b]\n• Mot de passe: [b]123456[/b]\n\n[b]Navigation to RAQ:[/b]\n50 (Ship Dock) → 01 (International Parcel) → 02 (Operation) → 05 (Create shipment) → F6 (Créer) → badge login → F10 (validate SAISIE) → Scanning Screen → [b]Shift+F1[/b] or [b]F13[/b] → RAQ\n\n[b]Key Shortcuts:[/b]\n• [b]F3[/b] — Go back (Retour/Sortie)\n• [b]F10[/b] — Confirm/Validate\n• [b]F5[/b] — Refresh counters on scanning screen\n• [b]Shift+F1[/b] or [b]F13[/b] — Open RAQ from scanning screen", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "C&C (Click & Collect): What is it?", "tags": ["click", "collect", "c&c", "white", "customer", "last"], "content": "[font_size=28][color=#0082c3][b]Click & Collect (C&C)[/b][/color][/font_size]\n\nC&C pallets contain items ordered online by customers. They are waiting at the store.\n\n[color=#e74c3c][b]THE RULE:[/b][/color] C&C MUST be loaded [b]LAST[/b] — closest to the truck doors — so they come off first.\n\n[b]On the AS400:[/b] C&C lines appear in [color=#ffffff][b]WHITE text[/b][/color] (all others are cyan/green).\n\n[b]Typical C&C per store:[/b] 1 plastic pallet + 1 magnum + 1 EUR wooden. If more than 3, extras go on magnums or wooden — never a second plastic pallet.", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "Loading: The Standard Sequence", "tags": ["load", "sequence", "truck", "order", "standard", "lifo"], "content": "[font_size=28][color=#0082c3][b]The Standard Loading Sequence[/b][/color][/font_size]\n\nThe store unloads from the doors inward (LIFO).\n\n[b]Load in this order:[/b]\n1. [color=#f1c40f][b]Service Center (Stands)[/b][/color] — deepest in truck\n2. [color=#2ecc71][b]Bikes[/b][/color]\n3. [color=#e67e22][b]Bulky[/b][/color]\n4. [color=#3498db][b]Mecha (Blue Boxes)[/b][/color]\n5. [color=#95a5a6][b]Click & Collect[/b][/color] — nearest to doors (ALWAYS LAST)\n\n[b]Why?[/b] The store needs C&C first (customers waiting), then mecha for shelves, then bulky/bikes which take longer.", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "What is a UAT?", "tags": ["uat", "label", "number", "pallet", "barcode", "orange"], "content": "[font_size=28][color=#0082c3][b]What is a UAT?[/b][/color][/font_size]\n\nA UAT (Unité d'Aide au Transport) is a scannable pallet unit with an orange label showing:\n\n• [b]Sector:[/b] 84/86 (mecha), 84/89 (bikes), 84/90 (bulky)\n• [b]Pallet type:[/b] PALETTE EUROPE or PLASTIQUE\n• [b]EXP/DEST:[/b] Sender and destination\n• [b]Colis count, weight, volume[/b]\n• [b]Flow code:[/b] MAG (store), MAP (store palletized)\n\n[b]Colis prefix identification:[/b]\n• 8486 = Mecha/Bay B2B\n• 8490 = Bulky\n• 8489 = Bikes\n• 0035 = Service Center (EWM format)", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "Reading the RAQ Screen", "tags": ["raq", "screen", "columns", "as400", "pjjidfr", "flx", "uni", "nbc"], "content": "[font_size=28][color=#0082c3][b]Reading the RAQ Screen (PJJIDFR)[/b][/color][/font_size]\n\nThe RAQ shows all parcels/UATs assigned to your truck.\n\n[b]Columns:[/b]\n• [b]N° U.A.T[/b] — UAT number (15 digits)\n• [b]Flx[/b] — Flow: MAG, MAP, @Z/UE@Z (internet)\n• [b]Uni[/b] — Universe (* = mixed)\n• [b]NBC[/b] — Colis count on UAT\n• [b]SE[/b] — Sector: 86=mecha, 89=bikes, 90=bulky\n• [b]EM[/b] — Container: 01=Plastic, 02=Box, 03=Magnum\n\n[b]Colors:[/b]\n• [color=#00ffff]Cyan[/color] = Regular\n• [color=#ffffff]White[/color] = C&C (customer waiting!)\n• [color=#ff0000]Red[/color] = Hazardous materials", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "Emballage: Live vs Non-Live", "tags": ["emballage", "returns", "unload", "live", "trailer", "whiteboard"], "content": "[font_size=28][color=#0082c3][b]Emballage: Live vs Non-Live[/b][/color][/font_size]\n\nEmballage = returns/packaging from stores.\n\n[b]Live emballage:[/b]\nDriver arrives with trailer → must unload [b]immediately[/b]. Driver is waiting.\n\n[b]Non-live emballage:[/b]\nTrailer is sitting at dock from previous shift. Flagged on the whiteboard for current shift to handle when activity allows.\n\n[b]Decision process:[/b]\n1. Check whiteboard for non-live emballage dock numbers\n2. If loading schedule allows, unload between store loadings\n3. Live emballage always takes priority over non-live\n4. If you can't get to it, flag it for the next shift", "scenarios": [0, 1, 2, 3], "new_in": 0},
	{"title": "The CMR Document", "tags": ["cmr", "document", "paper", "transport", "legal", "seal"], "content": "[font_size=28][color=#0082c3][b]The CMR Document[/b][/color][/font_size]\n\nThe CMR is the legal transport document filled AFTER loading.\n\n[b]Key fields:[/b]\n• [b]Box 1:[/b] Sender — Decathlon Netherlands, Kroonstraat 3, 5048 AT TILBURG\n• [b]Box 2:[/b] Destinataire — store name + address\n• [b]Box 3:[/b] IDEM 2 (delivery = destinataire)\n• [b]Box 4:[/b] IDEM 1 (pickup = sender)\n• [b]Box 6-7:[/b] Counts — EUR pallets, Plastic pallets, Magnums, C&C\n• [b]Box 13:[/b] Seal number + Expedition number + Dock number\n• [b]Box 22:[/b] Sender stamp\n• [b]Box 23:[/b] Driver license plate + signature\n\nCounts come from the Loading Sheet, not memory.", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "The Loading Sheet", "tags": ["loading", "sheet", "dual", "count", "eur", "plastic", "magnum"], "content": "[font_size=28][color=#0082c3][b]The Loading Sheet[/b][/color][/font_size]\n\nDual-count system:\n\n[b]Left side — by department:[/b]\nTally marks for Bikes, Bulky, Mecha, Transit, C&C.\n\n[b]Right side — by container type:[/b]\nGrids for EUR pallets (1-30), Plastic (1-30), Magnums (1-20).\n\n[b]Same pallets counted both ways.[/b]\n\n[b]C&C exception:[/b] C&C is its own category regardless of container. A C&C on EUR base counts as both 'C&C' on the left AND 'EUR pallet' on the right.", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "Dock Lines & Cells", "tags": ["dock", "line", "cell", "mecha", "bulky", "bikes", "lane", "a", "b", "c"], "content": "[font_size=28][color=#0082c3][b]Dock Lines & Cells[/b][/color][/font_size]\n\n[b]Cell A[/b] (Docks 17-29): Bulky area. Sector 90 reception.\n[b]Cell B[/b] (Docks 3-5): Mecha inbound. Sector 86.\n[b]Cell C[/b] (Docks 1C-4C): [color=#e74c3c]Bikes ONLY.[/color] Bay B2B does NOT unload bikes receptions.\n\n[b]At your dock, pallets arrive on 4 lines:[/b]\n• Mecha 1 & 2: Blue boxes from the sorter\n• Bulky: Cardboard on wooden pallets from Cell A\n• Mixed: Bikes/C&C/Service Center from various departments", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "Loading Quality Rules", "tags": ["quality", "tall", "height", "damage", "label", "orientation", "overthrow"], "content": "[font_size=28][color=#0082c3][b]Loading Quality Rules[/b][/color][/font_size]\n\n• [b]Heaviest/tallest[/b] at bottom-right to prevent overthrow\n• [b]Never mix tall next to short[/b] — causes toppling\n• [b]Max 6 layers[/b] for bulky Type A parcels\n• [b]Labels face the loading bay door[/b]\n• [b]If you damage goods:[/b] Tell your manager immediately. Never hide it.\n\n[b]Target:[/b] Complete loading within 1 hour.", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "Trailer Sizes & Capacity", "tags": ["trailer", "capacity", "8.5", "13.6", "truck", "size", "pallet"], "content": "[font_size=28][color=#0082c3][b]Trailer Sizes & Capacity[/b][/color][/font_size]\n\n[b]8.5m trailer:[/b] ~18 EUR pallets\n[b]13.6m trailer:[/b] ~33-36 EUR pallets\n\n[b]Truck types:[/b]\n• [b]Live loading:[/b] Driver arrives with trailer, must load immediately\n• [b]Non-live:[/b] Empty trailer already at dock\n• [b]CO loading:[/b] Two stores in one trailer\n\n[b]Transport companies:[/b] DHL (primary), SCHOTPOORT, P&M", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "Creating a Shipment (F6)", "tags": ["shipment", "expedition", "f6", "create", "seal", "destinataire"], "content": "[font_size=28][color=#0082c3][b]Creating a Shipment[/b][/color][/font_size]\n\nFrom EXPEDITION EN COURS, press [b]F6=Créer[/b].\n\n[b]Fields to fill:[/b]\n• [b]N°expédition:[/b] Auto-generated (8 digits)\n• [b]Expéditeur camion:[/b] 14  390\n• [b]Destinataire:[/b] 7  [store code] (e.g., 7  1570 for Alkmaar)\n• [b]SEAL number 1 & 2:[/b] Physical seal codes\n• [b]Type transport:[/b] 1 (road)\n• [b]Prestataire:[/b] Carrier code\n• [b]Type expédition:[/b] C (Classical) or S (Specific)\n\nPress [b]F10=Valider[/b] to confirm.", "scenarios": [1, 2, 3], "new_in": 1},
	{"title": "Promise Dates: D, D-, D+", "tags": ["promise", "date", "d+", "d-", "priority", "capacity", "full", "overdue"], "content": "[font_size=28][color=#0082c3][b]Promise Dates & Capacity[/b][/color][/font_size]\n\nWhen you have more pallets than space:\n\n[color=#e74c3c][b]D-[/b] : Overdue.[/color] CRITICAL. Must load.\n[color=#f1c40f][b]D[/b]  : Due today.[/color] High priority. Must load.\n[color=#95a5a6][b]D+[/b] : Due tomorrow.[/color] Low priority.\n\n[b]Rule:[/b] Load ALL D- and D first (standard sequence). Only load D+ if space remains. Never leave D-/D behind while loading D+.", "scenarios": [2, 3], "new_in": 2},
	{"title": "Co-Loading: Two Stores, One Truck", "tags": ["co", "loading", "two", "stores", "sequence", "divider", "partner"], "content": "[font_size=28][color=#0082c3][b]Co-Loading (CO)[/b][/color][/font_size]\n\nSome stores share a truck. The trailer is visually split.\n\n[b]Sequence 1[/b] = loaded FIRST (deeper in truck)\n[b]Sequence 2[/b] = loaded SECOND (near doors, unloaded first)\n\n[b]Common CO pairs:[/b]\n• Kerkrade 346 / Roermond 2094\n• Coolsingel 1161 / Den Haag 1186\n• Groningen 2224 / Leeuwarden 897\n• Enschede 2092 / Nijmegen 2225\n• Alexandrium 2093 / Amsterdam Noord 2226\n\n[b]Critical:[/b] Never mix pallets between the two stores. Each store's pallets must stay on their side.", "scenarios": [3], "new_in": 3},
	{"title": "Reading the Loading Plan", "tags": ["loading", "plan", "schedule", "time", "store", "co", "solo"], "content": "[font_size=28][color=#0082c3][b]Reading the Loading Plan[/b][/color][/font_size]\n\nThe Loading Plan tells you WHAT is coming:\n\n• Which stores, what time\n• CO (shared truck) or SOLO\n• Which carrier (DHL, SCHOTPOORT, P&M)\n• Truck size (8.5m or 13.6m)\n• Live or non-live loading\n\n[b]The Loading Plan is NOT the Loading Sheet.[/b]\n• Loading Plan = what's scheduled (before loading)\n• Loading Sheet = what you count (during loading)\n• CMR = what you certify (after loading)", "scenarios": [3], "new_in": 3}
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

	# Audio toggle in top bar
	var top_bar_hbox = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox
	if top_bar_hbox:
		var audio_btn = Button.new()
		audio_btn.text = "🔊"
		audio_btn.custom_minimum_size = Vector2(36, 28)
		audio_btn.focus_mode = Control.FOCUS_NONE
		audio_btn.add_theme_font_size_override("font_size", 16)
		var ab_sb = StyleBoxFlat.new()
		ab_sb.bg_color = Color(0.15, 0.16, 0.18)
		ab_sb.corner_radius_top_left = 4; ab_sb.corner_radius_top_right = 4
		ab_sb.corner_radius_bottom_left = 4; ab_sb.corner_radius_bottom_right = 4
		audio_btn.add_theme_stylebox_override("normal", ab_sb)
		var ab_h = ab_sb.duplicate()
		ab_h.bg_color = Color(0.22, 0.24, 0.28)
		audio_btn.add_theme_stylebox_override("hover", ab_h)
		audio_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		audio_btn.pressed.connect(func() -> void:
			var enabled = not WOTSAudio._enabled
			WOTSAudio.set_enabled(enabled)
			audio_btn.text = "🔊" if enabled else "🔇"
		)
		top_bar_hbox.add_child(audio_btn)

	# --- STYLE: Panel toggle bar ---
	var toggle_bar = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar:
		var ptb_sb = StyleBoxFlat.new()
		ptb_sb.bg_color = Color(0.1, 0.11, 0.13)
		ptb_sb.border_width_left = 1
		ptb_sb.border_color = Color(0.2, 0.22, 0.25)
		toggle_bar.add_theme_stylebox_override("panel", ptb_sb)

	# Hide Trailer Capacity from sidebar (redundant — capacity shown in dock view)
	if btn_trailer_capacity: btn_trailer_capacity.visible = false

	# Style the Panels header label
	var panels_lbl = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PanelsLabel
	if panels_lbl:
		panels_lbl.add_theme_font_size_override("font_size", 12)
		panels_lbl.add_theme_color_override("font_color", Color(0.4, 0.43, 0.47))
		panels_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var toggle_buttons = [btn_shift_board, btn_loading_plan, btn_as400, btn_phone, btn_notes]
	for tb in toggle_buttons:
		if tb == null: continue
		tb.focus_mode = Control.FOCUS_NONE
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
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		tb.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	_build_start_portal()
	_build_operational_layout()
	_build_debrief_modal()
	_build_sop_modal()
	_build_tutorial_ui()
	_style_overlay_panels()

	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

func _process(_delta: float) -> void:
	if tutorial_active and _tut_target_node != null and is_instance_valid(_tut_target_node) and _tut_target_node.visible:
		tut_highlight_box.visible = true
		var pos = _tut_target_node.global_position - Vector2(4, 4)
		pos.x = maxf(pos.x, 0.0)
		pos.y = maxf(pos.y, 0.0)
		tut_highlight_box.global_position = pos
		tut_highlight_box.size = _tut_target_node.size + Vector2(8, 8)
	elif tut_highlight_box != null:
		tut_highlight_box.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if sop_overlay != null and sop_overlay.visible:
				_close_sop_modal()
			elif debrief_overlay != null and debrief_overlay.visible:
				pass  # Don't close debrief with Escape
			elif portal_overlay != null and portal_overlay.visible:
				get_tree().quit()  # Only quit from portal screen
			# During active session, Escape does nothing (prevents accidental demo kill)
		elif event.keycode == KEY_F3:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 9: as400_state = 8
				elif as400_state == 8: as400_state = 18
				elif as400_state == 15: as400_state = 2
				elif as400_state == 16: as400_state = 5
				elif as400_state == 17: as400_state = 5
				elif as400_state == 18: as400_state = 5
				elif as400_state == 19: as400_state = 22
				elif as400_state == 20: as400_state = 2
				elif as400_state == 21: as400_state = 20
				elif as400_state == 22: as400_state = 5
				elif as400_state > 2: as400_state -= 1
				_render_as400_screen()
		elif event.keycode == KEY_F10:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 19:
					as400_state = 18
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
					if tutorial_active and tutorial_step == 2:
						tutorial_step = 3
						_update_tutorial_ui()
				else:
					_confirm_as400_raq()
		elif event.keycode == KEY_F6:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 22:
					_badge_target = 19
					as400_state = 6
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
		elif event.keycode == KEY_F13:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 18:
					as400_state = 8
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
					if tutorial_active and tutorial_step == 4:
						tutorial_step = 5
						_update_tutorial_ui()
		elif event.keycode == KEY_F1 and event.shift_pressed:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 18:
					as400_state = 8
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
					if tutorial_active and tutorial_step == 4:
						tutorial_step = 5
						_update_tutorial_ui()

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
			t += "Great. Now log in to the terminal. Type [color=#f1c40f]BAYB2B[/color] and press Enter, then type the password [color=#f1c40f]123456[/color] and press Enter. This logs you into the AS400 system."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		2: 
			t += "You are in! Navigate to the scanning screen: type [color=#f1c40f]50[/color] -> [color=#f1c40f]01[/color] -> [color=#f1c40f]02[/color] -> [color=#f1c40f]05[/color] -> then press [color=#f1c40f]F6[/color] to create a shipment. Enter badge [color=#f1c40f]8600555[/color] and password [color=#f1c40f]123456[/color], then press [color=#f1c40f]F10[/color] to validate."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		3: 
			t += "This is the scanning screen — your main work screen. The scanner only works here! Now open the [color=#f1c40f][b]Dock View[/b][/color] panel to see what pallets are on the dock floor."
			_set_tutorial_focus(btn_dock_view, "top", true)
		4: 
			t += "This is the dock floor. You can see pallets sorted by type. Now open the [color=#f1c40f][b]AS400[/b][/color] and press [color=#f1c40f][b]F13[/b][/color] (or [color=#f1c40f]Shift+F1[/color]) to view the RAQ — the digital pallet list. Compare the [color=#bdc3c7]White C&C[/color] pallets in the RAQ to the dock."
			_set_tutorial_focus(btn_as400, "top", true)
		5: 
			t += "Notice the [color=#bdc3c7]White text[/color] at the bottom of the RAQ — these are Click & Collect (C&C) pallets. One is missing from the dock! Click [color=#f1c40f][b]Call Departments (C&C Check)[/b][/color] to find it."
			_set_tutorial_focus(btn_call, "bottom", true)
		6: 
			t += "Good! The missing pallet was found and brought to the dock. Now, click [color=#f1c40f][b]Start Loading[/b][/color] to begin the physical loading process."
			_set_tutorial_focus(btn_start_load, "bottom", true)
		7: 
			t += "Time to load! Remember: the scanner only works on the [color=#f1c40f]Scanning screen[/color], not the RAQ. Make sure your AS400 shows [color=#f1c40f]SCANNING QUAI[/color] (press [color=#f1c40f]F3[/color] if needed). Then click any [color=#3498db]Blue Mecha[/color] pallet to intentionally load it out of order."
			_set_tutorial_focus(null, "top", false)
		8: 
			t += "Oops! Mecha is the wrong sequence. Click the [color=#3498db]Blue[/color] pallet [b]inside the truck grid[/b] to remove it. In real shifts, removing a pallet adds a 1.1-minute rework penalty!"
			_set_tutorial_focus(truck_grid, "top", false)
		9: 
			t += "Good recovery. Now, let's do it right. Always load [color=#f1c40f]Yellow Service Center[/color] pallets first. Click a yellow pallet to load it."
			_set_tutorial_focus(null, "top", false)
		10: 
			t += "Perfect! Next is [color=#2ecc71]Green Bikes[/color]. Click a green pallet to load it."
			_set_tutorial_focus(null, "top", false)
		11: 
			t += "Awesome! Before you finish, click [color=#3498db][b]Help & SOPs[/b][/color] in the top right. Time stops when this is open! Check out how new, important articles are highlighted."
			_set_tutorial_focus(btn_sop, "bottom", true)
		12: 
			t += "Great! All the tutorial info is stored there. Now, finish loading all remaining pallets onto the truck (Yellow -> Green -> Orange -> Blue -> White C&C)."
			_set_tutorial_focus(null, "top", false)
		13: 
			t += "All pallets loaded! Open the [color=#f1c40f][b]AS400[/b][/color] and press [color=#f1c40f][b]F10[/b][/color] on your keyboard to confirm the RAQ."
			_set_tutorial_focus(btn_as400, "top", false)
		14: 
			t += "Validation Effectuée! Click [color=#f1c40f][b]Seal Truck & Print Papers[/b][/color]. You'll see a Shift Summary explaining what you did right or wrong. Finish your shift!"
			_set_tutorial_focus(btn_seal, "bottom", true)
	
	t += "[/font_size]"
	tutorial_label.text = t
	
	if tutorial_step > 14:
		tut_canvas.visible = false

func _flash_tutorial_warning(msg: String) -> void:
	if not tutorial_active or tutorial_label == null: return
	WOTSAudio.play_error_buzz(self)
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
	btn_close.focus_mode = Control.FOCUS_NONE
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.8, 0.2, 0.2)
	close_sb.corner_radius_top_left = 4
	close_sb.corner_radius_top_right = 4
	close_sb.corner_radius_bottom_left = 4
	close_sb.corner_radius_bottom_right = 4
	btn_close.add_theme_stylebox_override("normal", close_sb)
	var close_h = close_sb.duplicate()
	close_h.bg_color = Color(0.9, 0.25, 0.25)
	btn_close.add_theme_stylebox_override("hover", close_h)
	btn_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_close.add_theme_color_override("font_color", Color.WHITE)
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
	
	if tutorial_active and tutorial_step == 11:
		tutorial_step = 12
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
		btn.focus_mode = Control.FOCUS_NONE
		
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
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var t_color = Color(0.7, 0.4, 0.0) if is_new else Color(0.2, 0.2, 0.2)
		btn.add_theme_color_override("font_color", t_color)
		btn.add_theme_color_override("font_hover_color", Color(0.0, 0.5, 0.8))
		
		btn.pressed.connect(func() -> void:
			sop_content_label.text = art.content
			WOTSAudio.play_panel_click(self)
		)
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
	var dd_hover = dd_sb.duplicate()
	dd_hover.bg_color = Color(0.22, 0.24, 0.28)
	dd_hover.border_color = Color(0.0, 0.51, 0.76)
	portal_scenario_dropdown.add_theme_stylebox_override("hover", dd_hover)
	var dd_pressed = dd_sb.duplicate()
	dd_pressed.bg_color = Color(0.14, 0.15, 0.18)
	dd_pressed.border_color = Color(0.0, 0.51, 0.76)
	portal_scenario_dropdown.add_theme_stylebox_override("pressed", dd_pressed)
	var dd_focus = dd_sb.duplicate()
	dd_focus.border_color = Color(0.0, 0.51, 0.76)
	portal_scenario_dropdown.add_theme_stylebox_override("focus", dd_focus)
	portal_scenario_dropdown.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	portal_scenario_dropdown.add_theme_color_override("font_hover_color", Color.WHITE)
	portal_scenario_dropdown.add_theme_color_override("font_pressed_color", Color(0.7, 0.73, 0.77))
	portal_scenario_dropdown.add_theme_color_override("font_focus_color", Color(0.85, 0.87, 0.9))
	# Style the popup menu (dropdown list) dark
	var dd_popup = portal_scenario_dropdown.get_popup()
	if dd_popup:
		var popup_sb = StyleBoxFlat.new()
		popup_sb.bg_color = Color(0.14, 0.15, 0.18)
		popup_sb.border_width_left = 1; popup_sb.border_width_top = 1; popup_sb.border_width_right = 1; popup_sb.border_width_bottom = 1
		popup_sb.border_color = Color(0.3, 0.32, 0.35)
		popup_sb.corner_radius_top_left = 4; popup_sb.corner_radius_top_right = 4
		popup_sb.corner_radius_bottom_left = 4; popup_sb.corner_radius_bottom_right = 4
		dd_popup.add_theme_stylebox_override("panel", popup_sb)
		var popup_hover_sb = StyleBoxFlat.new()
		popup_hover_sb.bg_color = Color(0.0, 0.35, 0.55)
		dd_popup.add_theme_stylebox_override("hover", popup_hover_sb)
		dd_popup.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
		dd_popup.add_theme_color_override("font_hover_color", Color.WHITE)
		dd_popup.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.45))
	portal_scenario_dropdown.focus_mode = Control.FOCUS_NONE
	portal_scenario_dropdown.item_selected.connect(_on_portal_scenario_changed)
	vbox.add_child(portal_scenario_dropdown)

	# Scenario description
	portal_scenario_desc = RichTextLabel.new()
	portal_scenario_desc.bbcode_enabled = true
	portal_scenario_desc.fit_content = true
	portal_scenario_desc.custom_minimum_size = Vector2(0, 50)
	portal_scenario_desc.add_theme_color_override("default_color", Color(0.5, 0.53, 0.57))
	portal_scenario_desc.add_theme_font_size_override("normal_font_size", 13)
	portal_scenario_desc.text = ""
	vbox.add_child(portal_scenario_desc)
	
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
	btn_start.focus_mode = Control.FOCUS_NONE
	btn_start.pressed.connect(_on_portal_start_pressed)
	vbox.add_child(btn_start)

# ==========================================
# DEBRIEF MODAL
# ==========================================
func _build_debrief_modal() -> void:
	debrief_overlay = ColorRect.new()
	debrief_overlay.color = Color(0, 0, 0, 0.92) 
	debrief_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.visible = false
	$Root.add_child(debrief_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_overlay.add_child(center)

	var pnl = PanelContainer.new()
	pnl.custom_minimum_size = Vector2(900, 700)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.border_width_top = 3
	sb.border_color = Color(0.0, 0.51, 0.76)
	pnl.add_theme_stylebox_override("panel", sb)
	center.add_child(pnl)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 35)
	pnl.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	lbl_debrief_text = RichTextLabel.new()
	lbl_debrief_text.bbcode_enabled = true
	lbl_debrief_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_debrief_text.add_theme_color_override("default_color", Color(0.8, 0.82, 0.85))
	vbox.add_child(lbl_debrief_text)

	var btn_close = Button.new()
	btn_close.text = "Finish & Return to Portal"
	btn_close.custom_minimum_size = Vector2(280, 48)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_font_size_override("font_size", 15)
	var dcb_n = StyleBoxFlat.new()
	dcb_n.bg_color = Color(0.18, 0.19, 0.22)
	dcb_n.corner_radius_top_left = 6; dcb_n.corner_radius_top_right = 6
	dcb_n.corner_radius_bottom_left = 6; dcb_n.corner_radius_bottom_right = 6
	dcb_n.border_width_left = 1; dcb_n.border_width_top = 1
	dcb_n.border_width_right = 1; dcb_n.border_width_bottom = 1
	dcb_n.border_color = Color(0.3, 0.32, 0.35)
	btn_close.add_theme_stylebox_override("normal", dcb_n)
	var dcb_h = dcb_n.duplicate()
	dcb_h.bg_color = Color(0.0, 0.51, 0.76)
	dcb_h.border_color = Color(0.0, 0.51, 0.76)
	btn_close.add_theme_stylebox_override("hover", dcb_h)
	btn_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_close.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	btn_close.add_theme_color_override("font_hover_color", Color.WHITE)
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
		var h_sb = n_sb.duplicate()
		h_sb.bg_color = Color(0.22, 0.24, 0.28)
		b.add_theme_stylebox_override("hover", h_sb)
		var p_sb = n_sb.duplicate()
		p_sb.bg_color = Color(0.1, 0.12, 0.15)
		b.add_theme_stylebox_override("pressed", p_sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color(0.5, 0.55, 0.6))
		b.focus_mode = Control.FOCUS_NONE
		return b

	btn_start_load = make_action_btn.call(" Start Loading ", false)
	btn_start_load.pressed.connect(func() -> void: _on_decision_pressed("Start Loading"))
	top_actions_hbox.add_child(btn_start_load)

	btn_call = make_action_btn.call(" Call Departments (C&C Check) ", true)
	btn_call.pressed.connect(func() -> void: _on_decision_pressed("Call departments (C&C check)"))
	top_actions_hbox.add_child(btn_call)

	btn_seal = make_action_btn.call(" Seal Truck & Print Papers ", false)
	btn_seal.pressed.connect(func() -> void: _on_decision_pressed("Seal Truck"))
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
	btn_sop.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_sop.focus_mode = Control.FOCUS_NONE
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
	btn_dock_view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_dock_view.focus_mode = Control.FOCUS_NONE
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
	dock_signs_hbox = signs_hbox
	dock_inner_vbox_ref = dock_inner_vbox

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
	dock_lanes_hbox = lanes_hbox

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
	dock_floor_labels_hbox = floor_labels_hbox

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
	scanner_bg.custom_minimum_size = Vector2(0, 100)
	scanner_bg.size_flags_vertical = Control.SIZE_SHRINK_END
	var scanner_sb = StyleBoxFlat.new()
	scanner_sb.bg_color = Color(0.06, 0.07, 0.08)
	scanner_sb.border_width_top = 2
	scanner_sb.border_color = Color(0.0, 0.51, 0.76)
	scanner_bg.add_theme_stylebox_override("panel", scanner_sb)
	dock_vbox.add_child(scanner_bg)

	var scanner_margin = MarginContainer.new()
	scanner_margin.add_theme_constant_override("margin_left", 16)
	scanner_margin.add_theme_constant_override("margin_top", 10)
	scanner_margin.add_theme_constant_override("margin_right", 16)
	scanner_margin.add_theme_constant_override("margin_bottom", 10)
	scanner_bg.add_child(scanner_margin)

	lbl_hover_info = RichTextLabel.new()
	lbl_hover_info.bbcode_enabled = true
	lbl_hover_info.custom_minimum_size = Vector2(0, 78)
	lbl_hover_info.scroll_active = false
	lbl_hover_info.text = "[font_size=15][color=#7a8a9a]▶ Hover over a pallet to scan...[/color][/font_size]"
	scanner_margin.add_child(lbl_hover_info)

# ==========================================
# DOCK LANE REBUILD (co-loading = 6 lanes)
# ==========================================
func _rebuild_dock_lanes(is_coload: bool) -> void:
	if dock_signs_hbox == null: return
	# Clear existing signs, lanes, floor labels
	for c in dock_signs_hbox.get_children(): c.queue_free()
	for c in dock_lanes_hbox.get_children(): c.queue_free()
	for c in dock_floor_labels_hbox.get_children(): c.queue_free()
	co_lanes.clear()

	var make_divider = func() -> ColorRect:
		var div = ColorRect.new()
		div.custom_minimum_size = Vector2(2, 0)
		div.size_flags_vertical = Control.SIZE_EXPAND_FILL
		div.color = Color(1, 1, 1, 0.3)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return div

	var make_thick_divider = func() -> ColorRect:
		var tdiv = ColorRect.new()
		tdiv.custom_minimum_size = Vector2(4, 0)
		tdiv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tdiv.color = Color(0.9, 0.55, 0.1, 0.7)
		tdiv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tdiv

	if is_coload:
		# 6 lanes: s1_mecha, s1_bulky, s1_misc | s2_mecha, s2_bulky, s2_misc
		var sign_data = [
			{"label": current_dest_name, "sub": "MECHA", "color": Color(0.94, 0.76, 0.2)},
			{"label": current_dest_name, "sub": "BULKY", "color": Color(0.94, 0.76, 0.2)},
			{"label": current_dest_name, "sub": "MISC", "color": Color(0.94, 0.76, 0.2)},
			{"label": current_dest2_name, "sub": "MECHA", "color": Color(0.9, 0.45, 0.15)},
			{"label": current_dest2_name, "sub": "BULKY", "color": Color(0.9, 0.45, 0.15)},
			{"label": current_dest2_name, "sub": "MISC", "color": Color(0.9, 0.45, 0.15)},
		]
		var lane_keys = ["s1_mecha", "s1_bulky", "s1_misc", "s2_mecha", "s2_bulky", "s2_misc"]
		var floor_texts = ["S1 MECHA", "S1 BULKY", "S1 MISC", "S2 MECHA", "S2 BULKY", "S2 MISC"]

		for i in range(6):
			_add_sign(dock_signs_hbox, sign_data[i])
			var lane = VBoxContainer.new()
			lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lane.alignment = BoxContainer.ALIGNMENT_END
			lane.add_theme_constant_override("separation", 4)
			co_lanes[lane_keys[i]] = lane
			dock_lanes_hbox.add_child(lane)
			if i == 2:
				dock_lanes_hbox.add_child(make_thick_divider.call())
			elif i < 5:
				dock_lanes_hbox.add_child(make_divider.call())
			_add_floor_label(dock_floor_labels_hbox, floor_texts[i])
	else:
		# Standard 4 lanes
		var std_sign_data = [
			{"label": "MECHA 1", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
			{"label": "MECHA 2", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
			{"label": "BULKY", "sub": "TRANSIT", "color": Color(0.9, 0.5, 0.15)},
			{"label": "BIKES / C&C / SC", "sub": "MIXED", "color": Color(0.2, 0.7, 0.35)}
		]
		for sd in std_sign_data:
			_add_sign(dock_signs_hbox, sd)
		
		lane_m1 = VBoxContainer.new(); lane_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m1.alignment = BoxContainer.ALIGNMENT_END; lane_m1.add_theme_constant_override("separation", 4)
		lane_m2 = VBoxContainer.new(); lane_m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m2.alignment = BoxContainer.ALIGNMENT_END; lane_m2.add_theme_constant_override("separation", 4)
		lane_b = VBoxContainer.new(); lane_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_b.alignment = BoxContainer.ALIGNMENT_END; lane_b.add_theme_constant_override("separation", 4)
		lane_misc = VBoxContainer.new(); lane_misc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_misc.alignment = BoxContainer.ALIGNMENT_END; lane_misc.add_theme_constant_override("separation", 4)
		dock_lanes_hbox.add_child(lane_m1)
		dock_lanes_hbox.add_child(make_divider.call())
		dock_lanes_hbox.add_child(lane_m2)
		dock_lanes_hbox.add_child(make_divider.call())
		dock_lanes_hbox.add_child(lane_b)
		dock_lanes_hbox.add_child(make_divider.call())
		dock_lanes_hbox.add_child(lane_misc)

		var std_floor_texts = ["MECHA 1", "MECHA 2", "BULKY", "BIKES/C&C"]
		for ft in std_floor_texts:
			_add_floor_label(dock_floor_labels_hbox, ft)

func _add_sign(parent: HBoxContainer, sd: Dictionary) -> void:
	var sign_panel = PanelContainer.new()
	sign_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sign_sb = StyleBoxFlat.new()
	sign_sb.bg_color = Color(0.1, 0.1, 0.12)
	sign_sb.border_width_top = 3
	sign_sb.border_color = sd.color
	sign_sb.corner_radius_bottom_left = 2
	sign_sb.corner_radius_bottom_right = 2
	sign_panel.add_theme_stylebox_override("panel", sign_sb)
	parent.add_child(sign_panel)
	var sign_margin = MarginContainer.new()
	sign_margin.add_theme_constant_override("margin_left", 4)
	sign_margin.add_theme_constant_override("margin_top", 4)
	sign_margin.add_theme_constant_override("margin_right", 4)
	sign_margin.add_theme_constant_override("margin_bottom", 4)
	sign_panel.add_child(sign_margin)
	var sign_vbox = VBoxContainer.new()
	sign_vbox.add_theme_constant_override("separation", 0)
	sign_margin.add_child(sign_vbox)
	var sign_lbl = Label.new()
	sign_lbl.text = sd.label
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 11)
	sign_lbl.add_theme_color_override("font_color", Color.WHITE)
	sign_vbox.add_child(sign_lbl)
	var sign_sub = Label.new()
	sign_sub.text = sd.sub
	sign_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_sub.add_theme_font_size_override("font_size", 9)
	sign_sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	sign_vbox.add_child(sign_sub)

func _add_floor_label(parent: HBoxContainer, text: String) -> void:
	var fl_panel = PanelContainer.new()
	fl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fl_sb = StyleBoxFlat.new()
	fl_sb.bg_color = Color(0.9, 0.55, 0.1)
	fl_sb.corner_radius_top_left = 2; fl_sb.corner_radius_top_right = 2
	fl_sb.corner_radius_bottom_left = 2; fl_sb.corner_radius_bottom_right = 2
	fl_panel.add_theme_stylebox_override("panel", fl_sb)
	parent.add_child(fl_panel)
	var fl_lbl = Label.new()
	fl_lbl.text = text
	fl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl_lbl.add_theme_font_size_override("font_size", 10)
	fl_lbl.add_theme_color_override("font_color", Color.WHITE)
	var fl_m = MarginContainer.new()
	fl_m.add_theme_constant_override("margin_top", 2)
	fl_m.add_theme_constant_override("margin_bottom", 2)
	fl_m.add_child(fl_lbl)
	fl_panel.add_child(fl_m)
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
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var center_hbox = HBoxContainer.new()
	center_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center_hbox)

	# Left spacer pushes text block right to visually center it
	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(left_spacer)

	as400_terminal_display = RichTextLabel.new()
	as400_terminal_display.bbcode_enabled = true
	as400_terminal_display.fit_content = true
	as400_terminal_display.autowrap_mode = TextServer.AUTOWRAP_OFF
	as400_terminal_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	as400_terminal_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	as400_terminal_display.text = ""
	as400_terminal_display.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	as400_terminal_display.focus_mode = Control.FOCUS_NONE
	# Use monospace font for authentic AS400 terminal look
	var mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	as400_terminal_display.add_theme_font_override("normal_font", mono_font)
	as400_terminal_display.add_theme_font_override("bold_font", mono_font)
	center_hbox.add_child(as400_terminal_display)

	# Right spacer balances the left spacer for true centering
	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(right_spacer)

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
	var prompt_mono = SystemFont.new()
	prompt_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	prompt.add_theme_font_override("font", prompt_mono)
	input_hbox.add_child(prompt)
	
	as400_terminal_input = LineEdit.new()
	as400_terminal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_sb = StyleBoxEmpty.new()
	as400_terminal_input.add_theme_stylebox_override("normal", input_sb)
	as400_terminal_input.add_theme_stylebox_override("focus", input_sb)
	as400_terminal_input.add_theme_color_override("font_color", Color(0, 1, 0))
	as400_terminal_input.add_theme_font_size_override("font_size", 18)
	var input_mono = SystemFont.new()
	input_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	as400_terminal_input.add_theme_font_override("font", input_mono)
	
	as400_terminal_input.gui_input.connect(func(event: InputEvent) -> void:
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
	
	pnl_as400_stage.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if as400_terminal_input != null:
				as400_terminal_input.call_deferred("grab_focus")
	)

	_render_as400_screen()

func _confirm_as400_raq() -> void:
	if tutorial_active:
		if tutorial_step < 13:
			_flash_tutorial_warning("Finish loading all pallets into the truck before confirming the RAQ!")
			return
		elif tutorial_step == 13:
			tutorial_step = 14
			_update_tutorial_ui()

	if _session != null:
		_session.call("manual_decision", "Confirm AS400")
	if as400_state == 8 or as400_state == 18:
		as400_state = 9
		_render_as400_screen()
		WOTSAudio.play_seal_confirm(self)

func _build_deca_art(art_rows: Array, fg_color: String) -> String:
	var bg_c := "[color=#000000]"
	var fg_c := fg_color
	var E := "[/color]"
	# Single-width pixels at large font, each row rendered twice for vertical thickness
	var out := "[center][font_size=36]"
	for row in art_rows:
		for _dup in range(2):
			var i := 0
			while i < row.length():
				var ch: String = row[i]
				var run := 1
				while i + run < row.length() and row[i + run] == ch:
					run += 1
				if ch == "1":
					out += fg_c + "█".repeat(run) + E
				else:
					out += bg_c + "█".repeat(run) + E
				i += run
			out += "\n"
	out += "[/font_size][/center]"
	return out

# Pixel-art digit patterns (5 wide x 5 tall, using * like real AS400)
const DIGIT_ART: Dictionary = {
	"0": [" *** ","*   *","*   *","*   *"," *** "],
	"1": ["  *  ","  *  ","  *  ","  *  ","  *  "],
	"2": [" *** ","    *"," *** ","*    "," *** "],
	"3": [" *** ","    *"," *** ","    *"," *** "],
	"4": ["*   *","*   *"," *** ","    *","    *"],
	"5": [" *** ","*    "," *** ","    *"," *** "],
	"6": [" *** ","*    "," *** ","*   *"," *** "],
	"7": [" *** ","    *","    *","    *","    *"],
	"8": [" *** ","*   *"," *** ","*   *"," *** "],
	"9": [" *** ","*   *"," *** ","    *"," *** "],
}

func _build_number_art(num: int, _digits: int, color: String) -> Array:
	var s := str(num)
	var rows: Array = ["", "", "", "", ""]
	for i in range(s.length()):
		if i > 0:
			for r in range(5): rows[r] += " "
		var d: String = s[i]
		var art: Array = DIGIT_ART.get(d, DIGIT_ART["0"])
		for r in range(5):
			rows[r] += art[r]
	var result: Array = []
	for row in rows:
		var line := ""
		for ch in row:
			if ch == "*":
				line += color + "*[/color]"
			else:
				line += " "
		result.append(line)
	return result

func _render_as400_screen() -> void:
	if as400_terminal_display == null: return
	# --- DECATHLON pixel art (all chars are █, color switches between filled and bg) ---
	# This guarantees alignment regardless of proportional/monospace font
	var _deca_art := [
		"11100111100111001100111101001010000011001001",
		"10010100001000010010011001001010000100101101",
		"10010111001000011110011001111010000100101011",
		"10010100001000010010011001001010000100101001",
		"11100111100111010010011001001011110011001001",
	]
	var t = "[font_size=24]"
	var d = "19/03/26"
	var H = "[color=#00ff00]"
	var C = "[color=#00ffff]"
	var Y = "[color=#ffff00]"
	var W = "[color=#ffffff]"
	var R = "[color=#ff0000]"
	var P = "[color=#ff88aa]"
	var B = "[color=#8888ff]"
	var E = "[/color]"
	
	# State 0: Sign On — DECATHLON
	if as400_state == 0:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %s_________%s[/center]\n" % [P, E, Y, E]
		t += "[center]%sPassword  . . . . . . . . . .%s[/center]\n\n" % [P, E]
		t += "[/font_size]" + _build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		as400_terminal_input.placeholder_text = "Type 'BAYB2B' and press Enter"

	# State 1: Sign On password
	elif as400_state == 1:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %sBAYB2B%s[/center]\n" % [P, E, H, E]
		t += "[center]%sPassword  . . . . . . . . . .%s   %s______%s[/center]\n\n" % [P, E, Y, E]
		t += "[/font_size]" + _build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		as400_terminal_input.placeholder_text = "Type '123456' and press Enter"

	# State 2: Simplified Menu (PSIP0120) — all right items start at col 48
	elif as400_state == 2:
		t += "%s%s%s   %s***%s       %s[u]Simplified Men[/u]%s        %s***%s %sDKOSUT01%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:16:23%s                    %sPSIP0120%s           %sENTER%s   %sSOHKPVR%s\n" % [H, E, Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                      %sProfession Opt%s\n" % [C, E]
		t += "                                                %s10  Change%s\n" % [H, E]
		t += "                                                    %sPassword%s\n" % [H, E]
		t += "  %s 1%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 2%s  %s-%s                                         %s20  GE Menu%s\n" % [Y, E, H, E, H, E]
		t += "  %s 3%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 4%s  %s-%s                                         %s30  PARCELx%s\n" % [Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                  %sOwn Options%s                   %s40  Recep Dock%s  %s390%s\n\n" % [C, E, H, E, Y, E]
		t += "  %s11%s  %s-%s                                         %s50  Ship Dock%s   %s390%s\n" % [Y, E, H, E, H, E, Y, E]
		t += "  %s12%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s13%s  %s-%s                                         %s80  Modification%s\n" % [Y, E, H, E, H, E]
		t += "  %s14%s  %s-%s                                             %sOwn Options%s\n" % [Y, E, H, E, H, E]
		t += "  %s15%s  %s-%s\n" % [Y, E, H, E]
		t += "                                                %s90  End of cession%s\n\n" % [H, E]
		t += "                %sYour Choice%s %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Exit  F10=Reinit Docks%s\n" % [C, E]
		as400_terminal_input.placeholder_text = "Type '50' for Ship Dock"

	# State 3: MENU DES APPLICATIONS (after typing 50 — Ship Dock)
	elif as400_state == 3:
		t += "%s19:29:15%s              %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   EXPEDITION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "      %s2%s  %s-   RECEPTION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "\n\n\n\n\n\n\n\n\n\n"
		t += "              %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]
		as400_terminal_input.placeholder_text = "Type '01' for Expedition"

	# State 4: SEND AN INTERNATIONAL PARCEL / MENU01 (after typing 01)
	elif as400_state == 4:
		t += "%s19:29:26%s          %s[u]SEND AN INTERNATIONAL PARCEL[/u]%s       %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s1%s                                                     %sMENU01%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   Param{trage%s\n\n" % [Y, E, H, E]
		t += "      %s2%s  %s-%s   %s[u]: menu : Operation[/u]%s\n\n" % [Y, E, H, E, C, E]
		t += "      %s3%s  %s-   Menu : Export%s\n\n" % [Y, E, H, E]
		t += "      %s4%s  %s-   : menu : Utilities%s\n\n" % [Y, E, H, E]
		t += "      %s5%s  %s-   Piloting Parcel%s\n\n" % [Y, E, H, E]
		t += "      %s6%s  %s-   Enter a Transit Flow 4%s\n\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "                                           %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]
		as400_terminal_input.placeholder_text = "Type '02' for Operation menu"

	# State 5: MENU : OPERATION / MENU03 (after typing 02)
	elif as400_state == 5:
		t += "%s19:29:36%s              %s[u]: MENU : OPERATION[/u]%s              %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s2%s                                                     %sMENU03%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s   %s-   Delete UAT%s\n" % [Y, E, H, E]
		t += "      %s2%s   %s-   Create UAT (regroup parcels)%s\n" % [Y, E, H, E]
		t += "      %s3%s   %s-   CFP : Control UAT%s\n" % [Y, E, H, E]
		t += "      %s4%s   %s-   : Menu : Addressing UAT%s\n" % [Y, E, H, E]
		t += "      %s5%s   %s-   Create shipment%s\n" % [Y, E, H, E]
		t += "      %s6%s   %s-   Manage shipping%s\n\n" % [Y, E, H, E]
		t += "      %s7%s   %s-   Visualize left on loading bay%s\n" % [Y, E, H, E]
		t += "      %s8%s   %s-   Visualize RAQ Worldwide Warehouse%s\n" % [Y, E, H, E]
		t += "      %s9%s   %s-   Visualize a parcel%s\n\n" % [Y, E, H, E]
		t += "      %s10%s  %s-   Menu : dangerous substances%s\n" % [Y, E, H, E]
		t += "      %s11%s  %s-   Transport schedule%s\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent F16=Premier menu%s\n" % [C, E]
		as400_terminal_input.placeholder_text = "Type '05' for Create shipment, or '06' for Manage shipping"

	# State 6: Badge login popup (overlaying EXPEDITION EN COURS)
	elif as400_state == 6:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s_______%s               │\n" % [H, E, Y, E]
		t += "         │ %sNom            :%s                         │\n" % [H, E]
		t += "         │ %sPrénom         :%s                         │\n" % [H, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		var exp_dest = current_dest_name
		if current_dest2_name != "":
			exp_dest = current_dest_name + "/" + current_dest2_name
		t += "%s__  06948174 XXXXXXXX    7 %5s %-18s   EN COURS%s\n" % [H, current_dest_code, exp_dest, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Créer%s                                                %sAIDE%s\n" % [C, E, C, E]
		as400_terminal_input.placeholder_text = "Type '8600555' (your badge code)"

	# State 7: Badge password (overlaying EXPEDITION EN COURS)
	elif as400_state == 7:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s8600555%s               │\n" % [H, E, H, E]
		t += "         │ %sMot de passe  :%s  %s______%s                │\n" % [H, E, Y, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		as400_terminal_input.placeholder_text = "Type '123456' (your password)"

	# State 8: RAQ screen (DSPF COLIS RAQ/RAC) — matches real AS400 layout
	elif as400_state == 8:
		as400_terminal_input.placeholder_text = "N° Colis ou UAT — F10 to confirm, F3=Back to Scanning"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:25%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		var total_colis: int = 0
		for p in last_avail_cache:
			if p.is_uat: total_colis += p.collis
		t += "%sExp{diteur   :   14    390   CAR TILBURG EXPE%s       %sTotal colis :   %d%s\n" % [H, E, H, total_colis, E]
		if current_dest2_name != "":
			t += "%sDestinataire :    7  %5s   %s%s\n" % [H, current_dest_code, current_dest_name, E]
			t += "%s             +   7  %5s   %s%s  %s(CO LOADING)%s\n\n" % [H, current_dest2_code, current_dest2_name, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, current_dest_code, current_dest_name, E]
		t += "%s5=D{tail Colis/UAT   7=Validation UAT transit vocal%s\n\n" % [C, E]
		t += "%s? N{ U.A.T                  Flx Uni NBC SE EM Colis                  Dt Col  CCC/%s\n" % [H, E]
		t += "%s                              CFP     CD                       Dt Exp Adresse%s\n" % [H, E]
		var regular_uats: Array = []
		var cc_uats: Array = []
		for p in last_avail_cache:
			if p.is_uat:
				if p.type == "C&C": cc_uats.append(p)
				else: regular_uats.append(p)
		var se_map: Dictionary = {"Mecha": "86", "Bulky": "90", "Bikes": "89", "ServiceCenter": "86", "C&C": "86"}
		var uni_map: Dictionary = {"Mecha": "62*", "Bulky": "10 ", "Bikes": "63*", "ServiceCenter": "02*", "C&C": "61*"}
		var em_map: Dictionary = {"Mecha": "11", "Bulky": "11", "Bikes": "11", "ServiceCenter": "11", "C&C": "11"}
		var rng_dt := RandomNumberGenerator.new()
		rng_dt.seed = 42
		for p in regular_uats:
			var se: String = se_map.get(p.type, "86")
			var uni: String = uni_map.get(p.type, "02*")
			var em: String = em_map.get(p.type, "11")
			var hr: int = 11 + rng_dt.randi_range(0, 3)
			var mn: int = rng_dt.randi_range(10, 59)
			t += "%s  %-20s  MAG %s   0 %s %s %-20s 170326 %d:%02d:%02d%s\n" % [C, p.id, uni, se, em, p.get("colis_id", "N/A"), hr, mn, rng_dt.randi_range(0,59), E]
		for p in cc_uats:
			var hr: int = 13 + rng_dt.randi_range(0, 2)
			var mn: int = rng_dt.randi_range(10, 59)
			t += "%s  %-20s  MAP 10    0 86 11 %-20s 170326 %d:%02d:%02d%s\n" % [W, p.id, p.get("colis_id", "N/A"), hr, mn, rng_dt.randi_range(0,59), E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie  F5=Ttes UAT  F7=UAT non Adress{es  F8=UAT Adress{es  F9=CCC/ADR%s\n" % [C, E]
		t += "%sF10=NBC/CFP   F11=EM/CD   F15=Tri F&R%s\n" % [C, E]

	# State 9: Validation
	elif as400_state == 9:
		as400_terminal_input.placeholder_text = "F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:01:00%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur   :   14    390   CAR TILBURG EXPE%s\n" % [H, E]
		if current_dest2_name != "":
			t += "%sDestinataire :    7  %5s   %s%s\n" % [H, current_dest_code, current_dest_name, E]
			t += "%s             +   7  %5s   %s%s  %s(CO LOADING)%s\n\n" % [H, current_dest2_code, current_dest2_name, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, current_dest_code, current_dest_name, E]
		t += "%s╔══════════════════════════════════════════════════╗%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s║     VALIDATION EFFECTUEE                         ║%s\n" % [Y, E]
		t += "%s║     (RAQ CONFIRMED)                              ║%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s╚══════════════════════════════════════════════════╝%s\n\n" % [Y, E]
		t += "%sYou may now physically Seal the Truck.%s\n" % [C, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie%s\n" % [C, E]

	# === EASTER EGG: Recep Dock (state 15) ===
	elif as400_state == 15:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RECEP DOCK 390[/u]%s        %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIRCDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Réception — Gestion des arrivages%s\n\n" % [H, E]
		t += "%s  Aucune réception en cours.%s\n\n" % [H, E]
		t += "%s  (Ce module n'est pas actif dans cette version de la simulation.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: Impression (state 16) ===
	elif as400_state == 16:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]IMPRESSION[/u]%s            %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIEMIFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  01 - Imprimer CMR%s\n" % [H, E]
		t += "%s  02 - Imprimer Bordereau%s\n" % [H, E]
		t += "%s  03 - Imprimer Etiquettes%s\n\n" % [H, E]
		t += "%s  (Les impressions ne sont pas actives dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: RAQ Par Magasin (state 17) ===
	elif as400_state == 17:
		as400_terminal_input.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RAQ PAR MAGASIN[/u]%s       %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:30%s                                    %sAFFICH.%s  %sPIEHMFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Entrez le code magasin :%s %s_____%s\n\n" % [H, E, Y, E]
		t += "%s  (La consultation par magasin n'est pas active dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === SCANNING SCREEN (state 18) — Primary view after badge login ===
	elif as400_state == 18:
		as400_terminal_input.placeholder_text = "N° Colis ou UAT — Shift+F1 or F13=RAQ"
		t += "%s%s%s   %s***%s      %s[u]SCANNING QUAI[/u]%s          %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:02%s                                    %sENTRER%s   %sPII1PVR%s\n\n" % [H, E, H, E, H, E]
		var colis_remaining: int = 0
		var uat_remaining: int = 0
		var colis_loaded: int = 0
		var uat_loaded: int = 0
		for p in last_avail_cache:
			if p.is_uat and not p.missing:
				uat_remaining += 1
				colis_remaining += p.collis
		for p in last_loaded_cache:
			if p.is_uat:
				uat_loaded += 1
				colis_loaded += p.collis
		var G := "[color=#00ff00]"
		t += "  %sCOLIS EN RESTE A CHARGER%s    %sUAT VOCAL%s    %sUAT EN RESTE A CHARGER%s\n" % [H, E, H, E, H, E]
		# Render numbers at larger font
		t += "[/font_size][font_size=28]"
		var cr_art: Array = _build_number_art(colis_remaining, 4, G)
		var ur_art: Array = _build_number_art(uat_remaining, 4, G)
		for r in range(5):
			t += "    %s              %s\n" % [cr_art[r], ur_art[r]]
		t += "[/font_size][font_size=24]\n"
		# Loading time
		var load_mins: int = 0
		var load_secs: int = 0
		if _session != null:
			var t_total: float = _session.total_time
			load_mins = int(t_total) / 60
			load_secs = int(t_total) % 60
		t += "%s------------------------------]TEMPS CHARGEMENT]------------------------------%s\n" % [C, E]
		t += "  %sCOLIS CHARGES%s              %s]   %02d:%02d:%02d   ]%s      %sUAT CHARGEES%s\n" % [H, E, H, load_mins, load_secs, 0, E, H, E]
		t += "[/font_size][font_size=28]\n"
		var cl_art: Array = _build_number_art(colis_loaded, 4, G)
		var ul_art: Array = _build_number_art(uat_loaded, 4, G)
		for r in range(5):
			t += "    %s              %s\n" % [cl_art[r], ul_art[r]]
		t += "[/font_size][font_size=24]\n"
		t += "    %sN° Colis ou UAT%s %s_________________________%s\n" % [H, E, Y, E]
		t += "    %sMode%s %s+%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie F5=R@J F13=RAQ (or Shift+F1)  F10=Valider F14=UAT/Colis Charg{s%s\n" % [C, E]
		t += "%sF6=Toisage F7=EXPE colis sans flux F8=UAT normal/vrac F9=Modif support UAT%s\n" % [C, E]

	# === SAISIE D'UNE EXPEDITION (state 19) — autofilled with scenario data ===
	elif as400_state == 19:
		as400_terminal_input.placeholder_text = "F10=Valider (proceed to scanning) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]SAISIE D'UNE EXPEDITION[/u]%s  %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:30:24%s                                    %sAJOUTER%s  %sPID2E1R%s\n\n" % [H, E, R, E, H, E]
		t += "%sN{exp{dition    :%s  %s06948174%s              %sExp{diteur camion:%s %s[u]14    390[/u]%s\n\n" % [H, E, Y, E, H, E, Y, E]
		t += "%sExpediteur       :   14    390%s %sCAR TILBURG EXPE%s\n\n" % [H, E, H, E]
		# Autofill destination from scenario
		var dest_c: String = current_dest_code if current_dest_code != "" else "1570"
		var dest_n: String = current_dest_name if current_dest_name != "" else "ALKMAAR"
		t += "%sDestinataire     :%s  %s 7  %s%s   %s%s%s\n\n" % [H, E, Y, dest_c, E, H, dest_n, E]
		# Random but realistic seal numbers
		var seal1: String = str(8600000 + (hash(current_dest_name) % 9999))
		var seal2: String = str(8600000 + (hash(current_dest_code) % 9999))
		t += "%sSEAL number 1    :%s  %s[u]%s[/u]%s\n" % [H, E, Y, seal1, E]
		t += "%sSEAL number 2    :%s  %s[u]%s[/u]%s\n\n" % [H, E, Y, seal2, E]
		t += "%sType transport :%s %s1%s\n" % [H, E, Y, E]
		t += "%sPrestataire    :%s %sDHL%s\n" % [H, E, Y, E]
		t += "%sType exp{dition :%s %s[u]C[/u]%s %s(C=Classical / S=Specific)%s\n\n\n" % [H, E, Y, E, H, E]
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian"]
		var op_name: String = operators[hash(current_dest_name) % operators.size()]
		t += "%sOp{rateur        :%s                  %s%s%s\n" % [H, E, R, op_name.to_upper(), E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F4=Invite    F10=Valider%s                            %sAIDE%s\n" % [C, E, C, E]

	# === EXPEDITION EN COURS (state 22) — accessible from Operation menu via 06 ===
	elif as400_state == 22:
		as400_terminal_input.placeholder_text = "F6=Créer (opens badge login) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExp{diteur :   14    390 CAR TILBURG EXPE%s\n\n" % [H, E]
		t += "%sAfficher @ partir de : N{ exp{dition :%s %s________%s\n\n" % [H, E, Y, E]
		t += "%sIndiquez vos options, puis appuyez sur Entr{e.%s\n" % [H, E]
		t += "%s2=Compl{ter    4=Supprimer%s\n\n" % [H, E]
		t += "%sOpt N{Exp{  Plb n{1     Code destinataire          Par        Etat%s\n" % [H, E]
		var exp_dest: String = current_dest_name
		if current_dest2_name != "":
			exp_dest = current_dest_name + "/" + current_dest2_name
		t += "%s__  06948174 XXXXXXXX    7 %5s %-20s Georgios   EN COURS%s\n" % [H, current_dest_code, exp_dest, E]
		t += "%s__  06947961 XXXXXXXX   14    63 CAR HOUPLINES (quai  Artemios   EN COURS%s\n" % [H, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB JAKUB      EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              Georgios   EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB DANIEL     EN COURS%s\n" % [H, E]
		t += "\n\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Cr{er%s                                                %sAIDE%s\n" % [C, E, C, E]
		t += "%sFin de balayage; utilisez la touche D{filH afin d'explorer davantage d'enreg%s\n" % [H, E]

	# === EASTER EGG: MENU DES APPLICATIONS (GE Menu, state 20) ===
	elif as400_state == 20:
		as400_terminal_input.placeholder_text = "Votre choix ==> (1-8, or F3)"
		t += "%s19:17:20%s                  %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Outils d'aides @ la décision%s\n" % [H, E]
		t += "      %s2  -   GESTION ENTREPOT OXYLANE%s\n" % [H, E]
		t += "      %s3  -   Remise en fonction des écrans%s\n" % [H, E]
		t += "      %s4  -   Gestion des factures%s\n" % [H, E]
		t += "      %s5  -   Menu Radio%s\n" % [H, E]
		t += "      %s6  -   Adressage dirigé par les ORGANISATEUR%s\n" % [H, E]
		t += "      %s7  -   HUB MENU%s\n" % [H, E]
		t += "      %s8  -   Gestion des Profils utilisateurs%s\n" % [H, E]
		t += "\n\n\n\n\n"
		t += "                    %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]

	# === EASTER EGG: AIDE A LA DECISION (state 21) ===
	elif as400_state == 21:
		as400_terminal_input.placeholder_text = "Votre choix : (1-5, or F3)"
		t += "%s19:17:38%s       %s[u]AIDE A LA DECISION   D E C A T H L O N[/u]%s     %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "    %s1%s                                                     %sDECINIT%s\n\n" % [H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Query/400%s\n\n" % [H, E]
		t += "      %s2  -   Tableaux de pilotage%s\n\n" % [H, E]
		t += "      %s3  -   Accès aux autres ordinateurs%s\n\n" % [H, E]
		t += "      %s4  -   REACTIVATION DES ECRANS%s\n\n" % [H, E]
		t += "      %s5  -   WORK WTR%s\n\n\n" % [H, E]
		t += "              %sVotre choix :%s  %s_%s\n" % [H, E, Y, E]
		t += "                                               %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]

	t += "[/font_size]"
	as400_terminal_display.text = t

func _on_as400_input_submitted(text: String) -> void:
	var input = text.strip_edges().to_upper()
	as400_terminal_input.text = ""
	
	if as400_state == 0 and input == "BAYB2B": as400_state = 1
	elif as400_state == 1 and input == "123456": as400_state = 2
	elif as400_state == 2:
		if input == "50": as400_state = 3
		elif input == "40": as400_state = 15
		elif input == "20": as400_state = 20
	elif as400_state == 3:
		if input == "01": as400_state = 4
	elif as400_state == 4:
		if input == "02": as400_state = 5
	elif as400_state == 5:
		if input == "05": as400_state = 22  # Create shipment → EXPEDITION EN COURS
		elif input == "06": as400_state = 22  # Manage shipping → EXPEDITION EN COURS
	elif as400_state == 22:
		if input == "F6":
			_badge_target = 19  # F6 from Expedition → badge → SAISIE
			as400_state = 6
	elif as400_state == 6 and input == "8600555": as400_state = 7
	elif as400_state == 7 and input == "123456": as400_state = _badge_target
	elif as400_state == 19:
		if input == "F10": as400_state = 18  # Validate SAISIE → scanning
		elif input == "F3": as400_state = 22  # Back to EXPEDITION
	elif as400_state == 18:
		if input == "F3": as400_state = 5
		elif input == "F13" or input == "SHIFT+F1": as400_state = 8
	elif as400_state == 8:
		if input == "F3": as400_state = 18
		elif input == "F13": as400_state = 18
	elif as400_state == 9 and input == "F3": as400_state = 8
	elif as400_state == 15 and input == "F3": as400_state = 2
	elif as400_state == 16 and input == "F3": as400_state = 5
	elif as400_state == 17 and input == "F3": as400_state = 5
	elif as400_state == 22 and input == "F3": as400_state = 5
	elif as400_state == 20:
		if input == "1": as400_state = 21
		elif input == "F3": as400_state = 2
	elif as400_state == 21 and input == "F3": as400_state = 20
	
	_render_as400_screen()
	WOTSAudio.play_as400_key(self)
	
	if tutorial_active:
		if tutorial_step == 1 and as400_state == 2:
			tutorial_step = 2
			_update_tutorial_ui()
		elif tutorial_step == 2 and as400_state == 18:
			tutorial_step = 3
			_update_tutorial_ui()
		elif tutorial_step == 4 and as400_state == 8:
			tutorial_step = 5
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
	var scenario_name: String = "default"
	if portal_scenario_dropdown != null: scenario_name = portal_scenario_dropdown.get_item_text(portal_scenario_dropdown.get_selected_id())
	
	_current_scenario_index = portal_scenario_dropdown.get_selected_id()
	if _current_scenario_index == 0: _current_scenario_name = "0. Tutorial"
	elif _current_scenario_index == 1: _current_scenario_name = "1. Standard Loading"
	elif _current_scenario_index == 2: _current_scenario_name = "2. Priority Loading"
	elif _current_scenario_index == 3: _current_scenario_name = "3. Co-Loading"
	
	_session.set_role(WOTSConfig.Role.OPERATOR)
	_is_active = true
	
	var dest = store_destinations[randi() % store_destinations.size()]
	current_dest_name = dest.name
	current_dest_code = dest.code
	current_dest2_name = ""
	current_dest2_code = ""
	
	# For co-loading, pick a CO pair
	if _current_scenario_index == 3:
		var pair = co_pairs[randi() % co_pairs.size()]
		current_dest_name = pair.store1
		current_dest_code = pair.code1
		current_dest2_name = pair.store2
		current_dest2_code = pair.code2
	
	# Rebuild dock lanes for current scenario type
	_rebuild_dock_lanes(_current_scenario_index == 3)
	phone_messages.clear()
	phone_flash_active = false
	_load_cooldown = false
	
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
	_populate_overlay_panels()

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))
	
	var passed = debrief_payload.get("passed", false)
	if passed:
		if _current_scenario_index == highest_unlocked_scenario and highest_unlocked_scenario < 3:
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
	bb += "[font_size=24][b]Operational Timeline & Decisions[/b][/font_size]\n"
	bb += _debrief_what_happened + "\n"
	
	if _debrief_why_it_mattered.strip_edges() != "":
		bb += "\n[font_size=24][b]Managerial Review[/b][/font_size]\n"
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
		if _session.has_signal("phone_notification"): _session.connect("phone_notification", Callable(self, "_on_phone_notification"))

func _populate_scenarios() -> void:
	if portal_scenario_dropdown == null: return
	portal_scenario_dropdown.clear()
	
	var names: Array[String] = [
		"0. Tutorial", 
		"1. Standard Loading", 
		"2. Priority Loading",
		"3. Co-Loading"
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
	_on_portal_scenario_changed(highest_unlocked_scenario)

func _on_portal_scenario_changed(idx: int) -> void:
	if portal_scenario_desc == null: return
	var descriptions = [
		"[b]Tutorial[/b] — Guided walkthrough of a standard loading shift. Learn to navigate the AS400, check the RAQ, identify C&C pallets, load in the correct sequence, and validate your work.",
		"[b]Standard Loading[/b] — Load a truck for a single store without guidance. Apply everything from the tutorial. New SOP articles unlock: CMR, Loading Sheet, dock lines, quality rules.",
		"[b]Priority Loading[/b] — More pallets than the truck can hold. You must choose what to leave behind based on promise dates (D-, D, D+). Critical decision-making under pressure.",
		"[b]Co-Loading[/b] — Two stores share one truck. Load sequence 1 first (deeper), then sequence 2 (near doors). Never mix destinations. Real CO pairs from the loading plan."
	]
	if idx >= 0 and idx < descriptions.size():
		portal_scenario_desc.text = descriptions[idx]
	else:
		portal_scenario_desc.text = ""

func _on_decision_pressed(action: String) -> void:
	if tutorial_active:
		if tutorial_step < 5:
			_flash_tutorial_warning("Follow the guide! We aren't ready for this yet.")
			return
		if tutorial_step == 5:
			if action != "Call departments (C&C check)":
				_flash_tutorial_warning("Count the C&C pallets first and click 'Call Departments'!")
				return
			else:
				tutorial_step = 6
				_update_tutorial_ui()
		elif tutorial_step == 6:
			if action != "Start Loading":
				_flash_tutorial_warning("Now click 'Start Loading' to begin!")
				return
			else:
				tutorial_step = 7
				_update_tutorial_ui()
		elif tutorial_step < 14 and action == "Seal Truck":
			_flash_tutorial_warning("You haven't finished the loading and AS400 validation yet!")
			return
			
	if _session == null: return
	_session.call("manual_decision", action)
	if action == "Seal Truck":
		WOTSAudio.play_seal_confirm(self)
	elif action == "Call departments (C&C check)":
		WOTSAudio.play_scan_beep(self)
	elif action == "Start Loading":
		WOTSAudio.play_panel_click(self)

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)

func _update_top_time(total_time: float) -> void:
	if top_time_label == null: return
	# Show as realistic warehouse clock starting at 09:00
	var base_hour = 9
	var total_secs = int(total_time)
	var hours = base_hour + (total_secs / 3600)
	var mins = (total_secs % 3600) / 60
	var secs = total_secs % 60
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
	role_strip_label.text = "Assignment: %s | Window: %s" % [_strip_assignment, window_text]

func _on_inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	last_avail_cache = avail.duplicate(true)
	last_loaded_cache = loaded.duplicate(true)
	
	if as400_state == 8 or as400_state == 18:
		_render_as400_screen() 

	if truck_cap_label != null:
		var spaces_left = cap_max - cap_used
		var pct = cap_used / cap_max if cap_max > 0 else 0
		var color_hex = "#8fa6bf"
		if pct > 0.85: color_hex = "#e74c3c"
		elif pct > 0.6: color_hex = "#f1c40f"
		truck_cap_label.text = "[center][color=%s][b]%0.0f / %0.0f[/b][/color][/center]" % [color_hex, cap_used, cap_max]

		# Update capacity bar
		if truck_cap_bar != null and truck_cap_bar.get_parent() != null:
			var parent_w = truck_cap_bar.get_parent().size.x
			if parent_w > 0:
				truck_cap_bar.custom_minimum_size.x = parent_w * pct
			if pct > 0.85: truck_cap_bar.color = Color(0.9, 0.3, 0.25)
			elif pct > 0.6: truck_cap_bar.color = Color(0.94, 0.76, 0.2)
			else: truck_cap_bar.color = Color(0.18, 0.8, 0.44)

	# === CLEAR AND POPULATE DOCK LANES ===
	var is_coload = (_current_scenario_index == 3)
	var MAX_PER_LANE = 10
	var buffer_height = 10
	
	if is_coload:
		# Co-loading: 6 dedicated lanes (3 per store)
		var all_co_lanes = co_lanes.values()
		for lane in all_co_lanes:
			for child in lane.get_children(): child.queue_free()
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, buffer_height)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lane.add_child(spacer)
		
		var lane_counts = {}
		for key in co_lanes: lane_counts[key] = 0
		
		for p in avail:
			if p.missing: continue
			var dest = p.get("dest", 1)
			var prefix = "s1_" if dest == 1 else "s2_"
			var lane_key = ""
			if p.type == "Mecha": lane_key = prefix + "mecha"
			elif p.type == "Bulky": lane_key = prefix + "bulky"
			else: lane_key = prefix + "misc"
			
			if not co_lanes.has(lane_key): continue
			if lane_counts[lane_key] >= MAX_PER_LANE: continue
			
			var lane = co_lanes[lane_key]
			_draw_pallet(p, lane)
			lane.move_child(lane.get_child(lane.get_child_count() - 1), 0)
			lane_counts[lane_key] += 1
	else:
		# Standard 4-lane layout
		for child in lane_m1.get_children(): child.queue_free()
		for child in lane_m2.get_children(): child.queue_free()
		for child in lane_b.get_children(): child.queue_free()
		for child in lane_misc.get_children(): child.queue_free()
		
		for lane in [lane_m1, lane_m2, lane_b, lane_misc]:
			var lane_spacer = Control.new()
			lane_spacer.custom_minimum_size = Vector2(0, buffer_height)
			lane_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lane.add_child(lane_spacer)
		
		var allow_overflow = (_current_scenario_index >= 2)
		var std_lane_counts = {lane_m1: 0, lane_m2: 0, lane_b: 0, lane_misc: 0}
		var all_lanes = [lane_m1, lane_m2, lane_b, lane_misc]
		
		var mecha_count = 0
		for p in avail:
			if p.missing: continue
			var preferred_row = null
			if p.type == "Mecha": 
				if mecha_count % 2 == 0: preferred_row = lane_m1
				else: preferred_row = lane_m2
				mecha_count += 1
			elif p.type == "Bulky": preferred_row = lane_b
			else: preferred_row = lane_misc
			
			var row = preferred_row
			if std_lane_counts[row] >= MAX_PER_LANE:
				if allow_overflow:
					row = null
					var best_space = -1
					for candidate in all_lanes:
						var space = MAX_PER_LANE - std_lane_counts[candidate]
						if space > best_space:
							best_space = space
							row = candidate
					if row == null or std_lane_counts[row] >= MAX_PER_LANE:
						continue
				else:
					continue
			
			_draw_pallet(p, row)
			row.move_child(row.get_child(row.get_child_count() - 1), 0)
			std_lane_counts[row] += 1
		
	_update_truck_visualizer(loaded)
	
	if tutorial_active:
		if tutorial_step == 7:
			for p in loaded:
				if p.type == "Mecha":
					tutorial_step = 8
					_update_tutorial_ui()
					break
		elif tutorial_step == 8:
			var has_mecha = false
			for p in loaded:
				if p.type == "Mecha": has_mecha = true
			if not has_mecha:
				tutorial_step = 9
				_update_tutorial_ui()
		elif tutorial_step == 9:
			for p in loaded:
				if p.type == "ServiceCenter":
					tutorial_step = 10
					_update_tutorial_ui()
					break
		elif tutorial_step == 10:
			for p in loaded:
				if p.type == "Bikes":
					tutorial_step = 11
					_update_tutorial_ui()
					break
		elif tutorial_step == 12:
			if avail.is_empty():
				tutorial_step = 13
				_update_tutorial_ui()

# ==========================================
# PHONE NOTIFICATION SYSTEM
# ==========================================
func _on_phone_notification(message: String, pallets_added: int) -> void:
	phone_messages.append(message)
	phone_flash_active = true
	WOTSAudio.play_error_buzz(self)
	
	# Update phone panel content live
	_update_phone_content()
	
	# Flash the phone button
	if btn_phone != null:
		var orig_color: Color = btn_phone.get_theme_color("font_color")
		var state := {"count": 0}
		var timer := Timer.new()
		timer.wait_time = 0.4
		timer.one_shot = false
		add_child(timer)
		timer.timeout.connect(func() -> void:
			state.count += 1
			if state.count % 2 == 0:
				btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				btn_phone.text = " Phone (!) "
			else:
				btn_phone.add_theme_color_override("font_color", orig_color)
				btn_phone.text = " Phone "
			if state.count >= 10:
				timer.stop()
				timer.queue_free()
				btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				btn_phone.text = " Phone (!) "
		)
		timer.start()
	
	# Auto-open phone panel if not in tutorial
	if not tutorial_active:
		_set_panel_visible("Phone", true, false)

func _update_phone_content() -> void:
	var ph_body = _find_panel_body(pnl_phone)
	if ph_body == null: return
	var t = "[font_size=14]"
	t += "[color=#0082c3][b]PHONE[/b][/color]\n"
	t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	if phone_messages.size() > 0:
		for i in range(phone_messages.size() - 1, -1, -1):
			t += phone_messages[i] + "\n\n"
			if i > 0:
				t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	else:
		t += "[color=#95a5a6]No incoming calls.\n\n"
		t += "In future scenarios, departments may call\n"
		t += "you about missing pallets, delays, or\n"
		t += "urgent priority changes.\n\n"
		t += "[b]Quick dial:[/b]\n"
		t += "  DOUBLON: 1003\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001[/color]\n"
	t += "[/font_size]"
	ph_body.text = t

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
	var p_size = 45 if is_truck else 52
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
		tape_h.offset_top = -1
		tape_h.offset_bottom = 1
		tape_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(tape_h)
		var tape_v = ColorRect.new()
		tape_v.color = Color(0.65, 0.5, 0.28)
		tape_v.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
		tape_v.offset_left = -1
		tape_v.offset_right = 1
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

	btn.mouse_entered.connect(func() -> void: glow.border_color = Color(0.1, 0.8, 1.0))
	btn.mouse_exited.connect(func() -> void: glow.border_color = Color(0, 0, 0, 0))

	return btn

func _update_truck_visualizer(loaded_pallets: Array) -> void:
	if truck_grid.columns != 3: truck_grid.columns = 3
	for child in truck_grid.get_children(): child.queue_free()
	
	for i in range(loaded_pallets.size()):
		var p = loaded_pallets[i]
		
		var btn = _build_pallet_graphic(_get_type_color(p.type), true, p.type)
		
		# Co-loading destination tag in truck
		var p_dest = p.get("dest", 1)
		if current_dest2_name != "":
			var ttag = ColorRect.new()
			ttag.custom_minimum_size = Vector2(8, 8)
			ttag.color = Color(0.94, 0.76, 0.2) if p_dest == 1 else Color(0.9, 0.45, 0.15)
			ttag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			ttag.offset_left = -8
			ttag.offset_right = 0
			ttag.offset_top = 0
			ttag.offset_bottom = 8
			ttag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ttag)
		
		var is_reachable = i >= (loaded_pallets.size() - 3)
		var hover_text = ""
		
		if is_reachable:
			hover_text = "[font_size=15][color=#e74c3c][b]⚠ UNLOAD PALLET[/b][/color]\n[color=#c0c8d0]U.A.T:[/color] [b][color=#ffffff]%s[/color][/b]\n[color=#c0c8d0]Colis:[/color] [color=#ffffff]%s[/color]\n[color=#e74c3c]Penalty: +1.1 min rework[/color][/font_size]" % [p.id, p.get("colis_id", "N/A")]
		else:
			btn.modulate = Color(0.6, 0.6, 0.6) 
			hover_text = "[font_size=15][color=#95a5a6][b]BLOCKED[/b]\n%s\nUnload the pallets near the door first.[/color][/font_size]" % p.id

		btn.mouse_entered.connect(func() -> void: if lbl_hover_info: lbl_hover_info.text = hover_text)
		btn.mouse_exited.connect(func() -> void: if lbl_hover_info: lbl_hover_info.text = "[font_size=15][color=#7a8a9a]▶ Hover over a pallet to scan...[/color][/font_size]")
		
		btn.pressed.connect(func() -> void: 
			if _load_cooldown: return
			if tutorial_active and tutorial_step != 8:
				_flash_tutorial_warning("Don't unload anything right now, follow the guide!")
				return
			_load_cooldown = true
			btn.modulate = Color(1.5, 0.5, 0.5)
			var ul_timer := get_tree().create_timer(0.35)
			ul_timer.timeout.connect(func() -> void:
				if _session != null: _session.call("unload_pallet_by_id", p.id)
				WOTSAudio.play_unload_warning(self)
				var cd_timer := get_tree().create_timer(0.35)
				cd_timer.timeout.connect(func() -> void:
					_load_cooldown = false
				)
			)
		)
		truck_grid.add_child(btn)

func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn = _build_pallet_graphic(_get_type_color(p_data.type), false, p_data.type)

	# Co-loading destination indicator (small colored corner tag)
	var dest_id = p_data.get("dest", 1)
	if current_dest2_name != "":
		var tag = ColorRect.new()
		tag.custom_minimum_size = Vector2(12, 12)
		tag.color = Color(0.94, 0.76, 0.2) if dest_id == 1 else Color(0.9, 0.45, 0.15)
		tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -12
		tag.offset_right = 0
		tag.offset_top = 0
		tag.offset_bottom = 12
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tag)
		var tag_lbl = Label.new()
		tag_lbl.text = str(dest_id)
		tag_lbl.add_theme_font_size_override("font_size", 8)
		tag_lbl.add_theme_color_override("font_color", Color.BLACK)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(tag_lbl)

	var code_str = ""
	if p_data.has("code"): code_str = " | Code: " + p_data.code
	var colis_str = p_data.get("colis_id", "N/A")
	
	var base_label = "Plastic" if (p_data.type == "Mecha" or p_data.type == "C&C") else "EUR Wood"
	var hover_text = "[font_size=15][color=#0082c3][b]▶ SCAN DATA[/b][/color]  "
	hover_text += "[color=#c0c8d0]Type:[/color] [b][color=#ffffff]%s[/color][/b] [color=#8a9aaa](%s)[/color]%s\n" % [p_data.type, base_label, code_str]
	hover_text += "[color=#c0c8d0]U.A.T:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Colis:[/color] [b][color=#ffffff]%s[/color][/b]\n" % [p_data.id, colis_str]
	hover_text += "[color=#c0c8d0]Promise:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Qty:[/color] [color=#ffffff]%d[/color]   [color=#c0c8d0]Cap:[/color] [color=#ffffff]%0.1f[/color]" % [p_data.promise, p_data.collis, p_data.cap]
	# Show destination for co-loading (reuse dest_id from above)
	if current_dest2_name != "":
		var dest_str = "%s %s" % [current_dest_name, current_dest_code] if dest_id == 1 else "%s %s" % [current_dest2_name, current_dest2_code]
		var dest_color = "#f1c40f" if dest_id == 1 else "#e67e22"
		hover_text += "\n[color=%s][b]DEST: %s (Seq %d)[/b][/color]" % [dest_color, dest_str, dest_id]
	hover_text += "[/font_size]"
	
	btn.mouse_entered.connect(func() -> void: if lbl_hover_info: lbl_hover_info.text = hover_text)
	btn.mouse_exited.connect(func() -> void: if lbl_hover_info: lbl_hover_info.text = "[font_size=15][color=#7a8a9a]▶ Hover over a pallet to scan...[/color][/font_size]")

	btn.pressed.connect(func() -> void: 
		# Loading cooldown — prevents spam clicking
		if _load_cooldown: return
		
		if tutorial_active:
			if tutorial_step < 7:
				_flash_tutorial_warning("We aren't ready to load pallets yet. Follow the guide!")
				return
			if tutorial_step == 7 and p_data.type != "Mecha":
				_flash_tutorial_warning("Click a Blue Mecha pallet so we can learn how to fix mistakes!")
				return
			if tutorial_step == 8:
				_flash_tutorial_warning("Remove the Blue Mecha pallet from the truck first by clicking it in the trailer!")
				return
			if tutorial_step == 9 and p_data.type != "ServiceCenter":
				_flash_tutorial_warning("Wait! You must load the Yellow Service Center pallet first.")
				return
			if tutorial_step == 10 and p_data.type != "Bikes":
				_flash_tutorial_warning("Wait! You must load the Green Bikes pallet next.")
				return
			if tutorial_step == 11:
				_flash_tutorial_warning("Click 'Help & SOPs' in the top right before continuing!")
				return
				
		# Scanner only works on scanning screen, not RAQ
		if as400_state == 8:
			WOTSAudio.play_error_buzz(self)
			if tutorial_active and tutorial_step == 7:
				_flash_tutorial_warning("The scanner doesn't work on the RAQ screen! Press [color=#f1c40f]F3[/color] on your keyboard to return to the Scanning screen, then try again.")
			elif lbl_hover_info:
				lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Scanner inactive on RAQ screen![/b] Press F3 to return to the Scanning screen first.[/color][/font_size]"
			return
		
		# Start cooldown
		_load_cooldown = true
		
		# Visual feedback: flash pallet before loading
		var orig_mod: Color = btn.modulate
		btn.modulate = Color(1.5, 1.5, 1.5)
		WOTSAudio.play_scan_beep(self)
		
		# Delay the actual load for smooth feel
		var load_timer := get_tree().create_timer(0.35)
		load_timer.timeout.connect(func() -> void:
			if _session != null: _session.call("load_pallet_by_id", p_data.id)
			WOTSAudio.play_load_confirm(self)
			# Release cooldown after a short extra pause
			var cd_timer := get_tree().create_timer(0.35)
			cd_timer.timeout.connect(func() -> void:
				_load_cooldown = false
			)
		)
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
			_flash_tutorial_warning("Please open the Dock View to see the pallets!")
			return
		if tutorial_step == 4 and panel_name != "AS400" and panel_name != "Dock View":
			_flash_tutorial_warning("Open the AS400 and press F13 to check the RAQ pallet list!")
			return

	var is_open: bool = bool(_panel_state.get(panel_name, false))
	_set_panel_visible(panel_name, not is_open, false)
	WOTSAudio.play_panel_click(self)

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

	if panel_name == "AS400" and make_visible and as400_terminal_input != null:
		as400_terminal_input.call_deferred("grab_focus")
	
	# Clear phone flash when Phone panel is opened
	if panel_name == "Phone" and make_visible and phone_flash_active:
		phone_flash_active = false
		if btn_phone != null:
			btn_phone.text = " Phone "
			btn_phone.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		
	if tutorial_active:
		if tutorial_step == 0 and panel_name == "AS400" and make_visible:
			tutorial_step = 1
			_update_tutorial_ui()
		elif tutorial_step == 3 and panel_name == "Dock View" and make_visible:
			tutorial_step = 4
			_update_tutorial_ui()

# ==========================================
# OVERLAY PANEL STYLING & CONTENT
# ==========================================
func _style_overlay_panels() -> void:
	var overlay_panels = [pnl_shift_board, pnl_loading_plan, pnl_phone, pnl_notes]
	for p in overlay_panels:
		if p == null: continue
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.13)
		sb.border_width_left = 1
		sb.border_color = Color(0.2, 0.22, 0.25)
		p.add_theme_stylebox_override("panel", sb)
	# Style title labels inside each panel
	for p in overlay_panels:
		if p == null: continue
		var margin = p.get_child(0) if p.get_child_count() > 0 else null
		if margin == null: continue
		var vbox = margin.get_child(0) if margin.get_child_count() > 0 else null
		if vbox == null: continue
		var title_lbl = vbox.get_child(0) if vbox.get_child_count() > 0 else null
		if title_lbl and title_lbl is Label:
			title_lbl.add_theme_font_size_override("font_size", 16)
			title_lbl.add_theme_color_override("font_color", Color(0.0, 0.51, 0.76))
		var body = vbox.get_child(1) if vbox.get_child_count() > 1 else null
		if body and body is RichTextLabel:
			body.add_theme_color_override("default_color", Color(0.7, 0.73, 0.77))

func _populate_overlay_panels() -> void:
	# --- SHIFT BOARD ---
	var sb_body = _find_panel_body(pnl_shift_board)
	if sb_body:
		var operators = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian", "Juan", "Jakub", "Camilo", "Vasco"]
		operators.shuffle()
		var team_str = ""
		for i in range(mini(operators.size(), 6)):
			team_str += "  %d. %s\n" % [i + 1, operators[i]]
		
		var t = "[font_size=14]"
		t += "[color=#0082c3][b]SHIFT BOARD — Bay B2B[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[color=#f1c40f][b]DATE:[/b][/color] 25/03/2026   [color=#f1c40f][b]SHIFT:[/b][/color] AM\n\n"
		t += "[b]TEAM TODAY:[/b]\n"
		t += team_str + "\n"
		t += "[b]LOADING SCHEDULE:[/b]\n"
		if current_dest2_name != "":
			t += "  [color=#f1c40f]09:00  %s %s / %s %s (CO) — %s[/color]\n" % [current_dest_name, current_dest_code, current_dest2_name, current_dest2_code, operators[0]]
		else:
			t += "  [color=#f1c40f]09:00  %s %s — %s[/color]\n" % [current_dest_name, current_dest_code, operators[0]]
		t += "  10:30  DEN BOSCH 3619 — %s\n" % operators[1]
		t += "  11:00  ARENA 256 — %s\n" % operators[2]
		t += "  12:00  BREDA 1088 — %s\n" % operators[3]
		t += "  13:30  EINDHOVEN 1185 — %s\n\n" % operators[4]
		t += "[b]EMBALLAGE:[/b]\n"
		t += "  Dock 12 — non-live (from night shift)\n\n"
		t += "[b]EMERGENCY CONTACTS:[/b]\n"
		t += "  [color=#e74c3c]DOUBLON: 1003[/color]\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001\n\n"
		t += "[b]NOTES:[/b]\n"
		t += "  Sorter maintenance 14:00-15:00\n"
		t += "  New agency: Stan (first day, assign buddy)\n"
		t += "[/font_size]"
		sb_body.text = t

	# --- LOADING PLAN ---
	var lp_body = _find_panel_body(pnl_loading_plan)
	if lp_body:
		var t = "[font_size=14]"
		t += "[color=#0082c3][b]LOADING PLAN — 25/03/2026[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[b]TIME    STORE                  TYPE    CARRIER   SIZE[/b]\n"
		t += "[color=#5a6a7a]─────────────────────────────────────────────────────[/color]\n"
		if current_dest2_name != "":
			t += "[color=#f1c40f]09:00   %s %s /[/color]    [color=#f1c40f]CO      DHL       13.6m[/color]\n" % [current_dest_name, current_dest_code]
			t += "[color=#f1c40f]        %s %s[/color]    [color=#f1c40f]← YOUR LOAD[/color]\n" % [current_dest2_name, current_dest2_code]
		else:
			t += "[color=#f1c40f]09:00   %-14s %-5s  SOLO    DHL       13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
		t += "10:30   DEN BOSCH 3619          SOLO    DHL       13.6m\n"
		t += "11:00   ARENA 256               SOLO    DHL       13.6m\n"
		t += "11:30   KERKRADE 346 /          CO      SCHOTPOORT 13.6m\n"
		t += "        ROERMOND 2094\n"
		t += "12:00   BREDA 1088              SOLO    DHL       8.5m\n"
		t += "13:00   COOLSINGEL 1161 /       CO      P&M       13.6m\n"
		t += "        DEN HAAG 1186\n"
		t += "13:30   EINDHOVEN 1185          SOLO    DHL       13.6m\n"
		t += "14:30   TILBURG 2013            SOLO    DHL       8.5m\n\n"
		t += "[color=#5a6a7a]Live loading: ARENA 256, BREDA 1088[/color]\n"
		t += "[color=#5a6a7a]Non-live: all others (trailers at dock)[/color]\n"
		t += "[/font_size]"
		lp_body.text = t

	# --- PHONE ---
	_update_phone_content()

	# --- NOTES ---
	var notes_body = _find_panel_body(pnl_notes)
	if notes_body:
		var t = "[font_size=14]"
		t += "[color=#0082c3][b]NOTES[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[color=#95a5a6]Jot down what you notice during the shift.\n\n"
		t += "In the real warehouse, operators keep a\n"
		t += "mental note of anomalies and flag them\n"
		t += "at shift handover.\n\n"
		t += "Things to watch for:\n"
		t += "• Missing pallets on dock vs AS400\n"
		t += "• Damaged goods\n"
		t += "• Capacity issues\n"
		t += "• Sorter delays[/color]\n"
		t += "[/font_size]"
		notes_body.text = t

func _find_panel_body(panel: PanelContainer) -> RichTextLabel:
	if panel == null: return null
	var margin = panel.get_child(0) if panel.get_child_count() > 0 else null
	if margin == null: return null
	var vbox = margin.get_child(0) if margin.get_child_count() > 0 else null
	if vbox == null: return null
	if vbox.get_child_count() > 1:
		var body = vbox.get_child(1)
		if body is RichTextLabel: return body
	return null
