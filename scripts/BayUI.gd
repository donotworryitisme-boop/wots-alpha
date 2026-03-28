extends CanvasLayer

signal trust_contract_requested

const PANEL_NAMES: Array[String] = [
	"Dock View", "Shift Board", "AS400", "Trailer Capacity", "Phone", "Notes"
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
var _debrief_total_weight_kg: float = 0.0
var _debrief_total_dm3: int = 0
var _debrief_combine_count: int = 0
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
var btn_transit: Button = null
var btn_adr: Button = null
var btn_combine: Button = null

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
var _phone_flash_timer: Timer = null
var _load_cooldown: bool = false  # Prevents spam-clicking pallets
var btn_sop: Button
var btn_dock_view: Button

# --- SIDEBAR COLLAPSE/EXPAND ---
const SIDEBAR_COLLAPSED_W: float = 52.0
const SIDEBAR_EXPANDED_W: float = 190.0
const SIDEBAR_ANIM_DURATION: float = 0.2
const SIDEBAR_HOVER_DELAY: float = 0.15
const SIDEBAR_COLLAPSE_DELAY: float = 0.25
var _sidebar_pinned: bool = true
var _sidebar_expanded: bool = true
var _sidebar_tween: Tween = null
var _sidebar_hover_timer: SceneTreeTimer = null
var _sidebar_collapse_timer: SceneTreeTimer = null
var _sidebar_btn_labels: Dictionary = {}
var _sidebar_pin_btn: Button
var _sidebar_panels_lbl: Label

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
var as400_tab_bar: HBoxContainer = null
var _as400_tabs: Array = []
var _active_tab_idx: int = 0
var _as400_wrong_store_scans: int = 0
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
var sop_active_tab: int = 1  # 1 = Doing the Job, 2 = Understanding the Job
var sop_tab_btns: Array = []

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
		"title": "Your First Shift: Where to Start",
		"tags": ["start", "first", "beginner", "overview", "what", "do", "how"],
		"content": "[font_size=28][color=#0082c3][b]Your First Shift: Where to Start[/b][/color][/font_size]\n\nEverything in Bay B2B follows the same loop:\n\n[b]1. Check the RAQ[/b] (AS400 → F13)\nThe RAQ is the digital list of pallets assigned to your truck. Open the AS400, navigate to the scanning screen, then press F13. Compare what you see there to what is physically on your dock floor.\n\n[b]2. Verify C&C pallets[/b]\nWhite rows in the RAQ = Click & Collect. These are customer orders. Count them. If one is missing from the dock, click [b]Call Departments[/b] before you start loading.\n\n[b]3. Check any special items[/b]\nIf a [color=#ff4444]red ADR row[/color] appears, collect it from the yellow lockers before sealing. If a [color=#00ffff]TRANSIT[/color] row appears, check the transit rack before sealing.\n\n[b]4. Load in sequence[/b]\nService Center first, then Bikes, Bulky, Mecha. C&C always last, nearest to doors.\n\n[b]5. Validate in AS400[/b]\nOnce all pallets are loaded, press F13 to open the RAQ, then F10 to confirm. The store needs this digital record.\n\n[b]6. Seal the truck[/b]\nClick Seal Truck. The physical seal locks the doors. CMR paperwork follows.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "AS400: Login & Shortcuts",
		"tags": ["as400", "login", "password", "f3", "f10", "terminal", "code", "badge", "navigate", "menu"],
		"content": "[font_size=28][color=#0082c3][b]AS400: Login & Shortcuts[/b][/color][/font_size]\n\nThe AS400 is a real 1980s-era green-screen terminal. No mouse — keyboard only.\n\n[b]Two logins required:[/b]\n\n[b]1. System login (Sign On screen):[/b]\n[b]User:[/b] BAYB2B   [b]Password:[/b] 123456\n\n[b]2. Badge login (after pressing F6 to create a shipment):[/b]\n[b]Badge:[/b] 8600555   [b]Password:[/b] 123456\n\n[b]Navigation path to scanning screen:[/b]\n50 → 01 → 02 → 05 → F6 → badge login → F10 (confirm SAISIE) → [b]SCANNING QUAI[/b]\n\nThe screen layout and all keyboard shortcuts below are identical to the real AS400 terminal at the dock.\n\n[b]Key shortcuts:[/b]\n[b]F3[/b] — Go back one screen\n[b]F10[/b] — Confirm / Validate current screen\n[b]F13[/b] or [b]Shift+F1[/b] — Open RAQ from scanning screen\n[b]F6[/b] — Create new shipment (from EXPEDITION EN COURS)\n[b]F5[/b] — Refresh counters on scanning screen",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Setting the Loading Destination",
		"tags": ["saisie", "expedition", "destinataire", "store", "code", "destination", "declare", "f10"],
		"content": "[font_size=28][color=#0082c3][b]SAISIE D'UNE EXPEDITION[/b][/color][/font_size]\n\nSAISIE means declaration. This screen is where you formally tell the AS400 which store this truck is going to.\n\n[b]When you see this screen:[/b]\nYou pressed F6 from EXPEDITION EN COURS and logged in with your badge. The system needs the destination.\n\n[b]What you do:[/b]\n[b]Solo loading:[/b] The seal number is auto-filled. Press [b]F10[/b] to confirm.\n[b]Co-loading:[/b] Type the [b]store destination code[/b] (e.g. 346 for Kerkrade) and press Enter. Then press [b]F10[/b].\n\n[b]Where to find the store code:[/b]\nCheck the [b]Shift Board[/b]. Store codes are listed next to your truck. For co-loading, look for Seq.1 and Seq.2 labels.\n\n[b]Why this matters:[/b]\nThe code you enter determines which store the AS400 assigns your scanned pallets to. Entering the wrong code causes scan errors when you try to scan pallets for the other store.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "C&C (Click & Collect): What is it?",
		"tags": ["click", "collect", "c&c", "white", "customer", "last", "missing", "call"],
		"content": "[font_size=28][color=#0082c3][b]Click & Collect (C&C)[/b][/color][/font_size]\n\nC&C pallets contain items ordered online by customers for store pickup. The customer is already waiting. Every C&C that misses the truck means a customer arrives to an empty counter.\n\n[color=#e74c3c][b]THE RULE:[/b][/color] C&C MUST be loaded [b]LAST[/b] — nearest to the truck doors — so they come off first.\n\n[b]On the AS400:[/b] C&C rows appear in [color=#ffffff][b]WHITE text[/b][/color]. All other pallets are cyan.\n\n[b]Missing C&C:[/b]\nSometimes a C&C pallet is not on the dock when your shift starts. The RAQ shows it, but it is not on the floor. If you see a mismatch, click [b]Call Departments (C&C Check)[/b]. This takes about 5 minutes but always finds the pallet. Never seal the truck without checking.\n\n[b]In this simulator:[/b] Expect 2 to 4 C&C UATs per store per session. About half of sessions will have one C&C pallet missing at the start.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Service Center & Stands",
		"tags": ["service", "center", "stands", "yellow", "display", "deepest", "first", "fixtures"],
		"content": "[font_size=28][color=#0082c3][b]Service Center & Stands[/b][/color][/font_size]\n\nService Center pallets (shown in [color=#f1c40f]yellow[/color]) contain store display equipment: stands, mannequins, fixtures, signage, and furniture.\n\n[b]Why they load first (deepest in the truck):[/b]\nStands need to be set up before the store opens. They are large and hard to move once placed. Loading them deepest means store staff unload them last, typically during overnight setup.\n\n[b]They are never overdue:[/b]\nService Center pallets always carry a [b]D[/b] promise. They are not part of D-/D+ priority decisions.\n\n[b]How to spot them:[/b]\nYellow colour in the simulator. Sector 86 in the RAQ. UAT prefix 0035 (EWM format, different from standard 8486 mecha codes).\n\n[b]Important:[/b] Never leave a Service Center pallet behind. It is not a critical fail like C&C, but stores depend on display equipment arriving on schedule.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Loading: The Standard Sequence",
		"tags": ["load", "sequence", "truck", "order", "standard", "lifo", "why", "order matters"],
		"content": "[font_size=28][color=#0082c3][b]The Standard Loading Sequence[/b][/color][/font_size]\n\nThe truck is unloaded from the [b]doors inward[/b]. This is LIFO — Last In, First Out. Whatever you load last comes off the truck first at the store.\n\n[b]Load in this order:[/b]\n1. [color=#f1c40f][b]Service Center (Stands)[/b][/color] — deepest in truck\n2. [color=#2ecc71][b]Bikes[/b][/color]\n3. [color=#e67e22][b]Bulky[/b][/color]\n4. [color=#3498db][b]Mecha[/b][/color] — clothing, small electronics, store replenishment boxes\n5. [color=#ffffff][b]Click & Collect[/b][/color] — ALWAYS LAST, nearest to doors\n\n[b]Why this order?[/b]\nC&C comes off first because customers are waiting. Mecha restocks shelves during opening hours. Bikes and Bulky need specialist teams working on a different schedule. Service Center is handled overnight.\n\n[b]LIFO means mistakes cost time:[/b]\nIf you load Mecha before Bikes, the store must move all the Mecha to reach the Bikes. This is why sequence errors are penalised — they create real work at the other end.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "What is a UAT?",
		"tags": ["uat", "label", "number", "pallet", "barcode", "orange", "scan", "15 digits"],
		"content": "[font_size=28][color=#0082c3][b]What is a UAT?[/b][/color][/font_size]\n\nA UAT (Unite d'Aide au Transport) is a transport unit with an orange scannable label. It can be a pallet, roll cage, or any stackable unit.\n\n[b]The orange label shows:[/b]\nSector (84/86 mecha, 84/89 bikes, 84/90 bulky), pallet type (EUR or PLASTIQUE), sender and destination, colis count, weight, volume, and flow code (MAG = direct to store, MAP = palletised).\n\n[b]Colis prefix identification:[/b]\n8486 = Mecha / Bay B2B\n8490 = Bulky\n8489 = Bikes\n0035 = Service Center (EWM format)\n\n[b]In the AS400:[/b] UAT numbers are 15 digits. When you click a pallet on the dock, the simulator scans it. The AS400 links the UAT to the current shipment and counts the colis toward your total.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Reading the RAQ Screen",
		"tags": ["raq", "screen", "columns", "as400", "pjjidfr", "flx", "uni", "nbc", "read", "interpret"],
		"content": "[font_size=28][color=#0082c3][b]Reading the RAQ Screen (PJJIDFR)[/b][/color][/font_size]\n\nThe RAQ is your digital manifest — it lists every UAT assigned to your truck. Check it before loading to know what should be on your dock. Confirm it after loading to close the shipment.\n\n[b]Column guide:[/b]\n[b]N U.A.T[/b] — UAT number (15 digits, matches the orange label)\n[b]Flx[/b] — Flow: MAG (store), MAP (palletised), @Z/UE@Z (e-commerce)\n[b]Uni[/b] — Department code (* = mixed goods)\n[b]NBC[/b] — Number of colis on this UAT\n[b]SE[/b] — Sector: 86=mecha, 89=bikes, 90=bulky\n[b]EM[/b] — Container: 11=Plastic pallet, 01=EUR pallet\n\n[b]Row colours:[/b]\n[color=#00ffff]Cyan[/color] = Regular pallet\n[color=#ffffff]White[/color] = C&C (customer order — must load!)\n[color=#ff4444]Red[/color] = ADR dangerous goods (must retrieve from lockers!)\n[color=#00ffff]TRANSIT label[/color] = Item on transit rack, not yet on dock\n\n[b]Workflow:[/b] F13 from scanning screen opens the RAQ. After loading everything, press F10 to confirm — this creates the digital record for the store.\n\nThis screen is a pixel-accurate replica of the real PJJIDFR screen you will use on the dock.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Late Arrivals & Wave Deliveries",
		"tags": ["late", "wave", "phone", "arrival", "call", "extra", "pallet", "notification", "departments"],
		"content": "[font_size=28][color=#0082c3][b]Late Arrivals & Wave Deliveries[/b][/color][/font_size]\n\nNot all pallets are on the dock when you start. Some arrive mid-session from the sorter or departments.\n\n[b]How you are notified:[/b]\nThe [b]Phone[/b] button flashes orange. Open the Phone panel to see the message — which department, what is coming, roughly when.\n\n[b]What to do:[/b]\nCheck the promise date of the incoming pallet. If it is D- or D: hold space and wait before sealing. If it is D+: you may seal without it if all D and D- pallets are already loaded.\n\nIn real operations you get this call on the dock phone or radio from the department supervisor. The decision — wait or seal — is yours to make.\n\nIf you have already loaded a D+ pallet and the incoming one is D-: you may need to unload (rework) to make room. The simulator forgives this rework — it was the correct call.\n\n[b]Typical wave sources:[/b]\nBIKES ZONE C, BULKY RECEPTION, MECHA LINE, SORTER",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Rework: When to Unload a Pallet",
		"tags": ["rework", "unload", "remove", "pull", "penalty", "mistake", "undo", "fix"],
		"content": "[font_size=28][color=#0082c3][b]Rework: When to Unload a Pallet[/b][/color][/font_size]\n\nRework means pulling a pallet back off the truck after loading it. In real operations this costs about 1.1 minutes per pallet. The simulator adds that time to your shift duration.\n\n[b]When rework is penalised:[/b]\nYou loaded a pallet in the wrong sequence (e.g. Mecha before Bikes) and need to fix it. Or you loaded a D+ pallet and then a D- arrived that you need to fit.\n\n[b]When rework is NOT penalised:[/b]\nIf a [color=#e74c3c][b]priority D- wave[/b][/color] arrives after you have already loaded D+ pallets, unloading D+ to make room for D- is the correct call. The simulator recognises this and forgives that specific rework.\n\n[b]To unload in the simulator:[/b]\nClick a pallet inside the truck visualiser (not on the dock). It is removed and returned to the dock.\n\n[b]Prevention:[/b]\nCheck the RAQ and the phone before loading. Know your sequence. If a D- pallet is expected via phone notification, hold space for it before loading D+.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Emballage (Return Packaging)",
		"tags": ["emballage", "returns", "unload", "live", "trailer", "whiteboard", "packaging", "empty pallets"],
		"content": "[font_size=28][color=#0082c3][b]Emballage (Return Packaging)[/b][/color][/font_size]\n\nEmballage means empty pallets, roll cages, and packaging materials that stores send back to the warehouse. You unload these from an arriving trailer.\n\n[b]Live emballage:[/b]\nA driver arrives at your dock with a trailer of returns. The driver is waiting — unload immediately.\n\n[b]Non-live emballage:[/b]\nAn empty trailer has been sitting at a dock since the previous shift. The whiteboard flags these. Handle them between store loadings when your schedule allows.\n\n[b]Decision process:[/b]\n1. Check the whiteboard for non-live dock numbers at the start of shift.\n2. Handle between loadings if you have a gap.\n3. Live emballage always takes priority over non-live.\n4. If you cannot reach it, flag for the next shift at handover.\n\n[b]In the simulator:[/b] The Shift Board notes non-live emballage from the night shift.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "The CMR Document",
		"tags": ["cmr", "document", "paper", "transport", "legal", "seal", "sign", "driver"],
		"content": "[font_size=28][color=#0082c3][b]The CMR Document[/b][/color][/font_size]\n\nThe CMR (Convention Marchandise Routiere) is the legal transport document. You fill it AFTER loading, before the driver leaves.\n\n[b]Key fields:[/b]\nBox 1: Sender — Decathlon Netherlands, Kroonstraat 3, 5048 AT TILBURG\nBox 2: Destinataire — store name and address\nBox 3: IDEM 2\nBox 4: IDEM 1\nBox 6-7: Counts — EUR pallets, Plastic pallets, Magnums, C&C\nBox 13: Seal number + Expedition number + Dock number\nBox 22: Sender stamp\nBox 23: Driver licence plate + signature\n\n[b]Counts come from the Loading Sheet, not memory.[/b]\n\n[b]The seal:[/b] A physical numbered seal locks the truck door handles. Once sealed, the truck cannot be opened without breaking it. The seal number on the CMR proves the load was not tampered with in transit.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "The Loading Sheet",
		"tags": ["loading", "sheet", "dual", "count", "eur", "plastic", "magnum", "tally", "paper"],
		"content": "[font_size=28][color=#0082c3][b]The Loading Sheet[/b][/color][/font_size]\n\nA paper form filled during loading. Its counts go directly onto the CMR.\n\n[b]Left side — by department:[/b]\nTally marks for: Bikes, Bulky, Mecha, Transit, C&C.\n\n[b]Right side — by container type:[/b]\nGrids for EUR pallets (1-30), Plastic pallets (1-30), Magnums (1-20).\n\n[b]Same pallets, counted twice.[/b] If the totals disagree, you miscounted — recount before signing the CMR.\n\n[b]C&C exception:[/b] A C&C pallet on a EUR wooden base counts as both C&C on the left AND EUR pallet on the right. The two columns serve different purposes: one tracks department content, the other tracks container type for the driver's declaration.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Dock Lines & Cells",
		"tags": ["dock", "line", "cell", "mecha", "bulky", "bikes", "lane", "a", "b", "c", "sector", "bay"],
		"content": "[font_size=28][color=#0082c3][b]Dock Lines & Cells[/b][/color][/font_size]\n\n[b]Cell A[/b] (Docks 17-29): Bulky reception. Large goods arrive and are processed here before moving to the outbound dock.\n\n[b]Cell B[/b] (Docks 3-5): Mecha inbound. Sector 86 goods from the sorter are palletised here for outbound.\n\n[b]Cell C[/b] (Docks 1C-4C): Bikes INBOUND from suppliers only. A dedicated bikes team handles inbound arrivals. Bay B2B does not unload bikes receptions — Bay B2B only loads bikes [i]outbound[/i] to stores (the bikes arrive pre-palletised at your dock from the bikes zone).\n\n[b]At your dock (Bay B2B), pallets arrive from:[/b]\nMecha lines 1 and 2 (sorter conveyor), Bulky (pushed from Cell A), Bikes (pre-palletised from bikes zone), and Misc (C&C, Service Center, ADR from their respective areas).\n\n[b]Sector codes in the RAQ:[/b] 86=mecha, 89=bikes, 90=bulky.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Loading Quality Rules",
		"tags": ["quality", "tall", "height", "damage", "label", "orientation", "overthrow", "stack", "fragile"],
		"content": "[font_size=28][color=#0082c3][b]Loading Quality Rules[/b][/color][/font_size]\n\nHeaviest and tallest pallets at the back-bottom to prevent overthrow during transport.\nNever stack tall next to short — height differences cause pallets to topple at corners.\nMax 6 layers for bulky Type A parcels.\nLabels must face the loading bay door — the driver and store staff need to read them.\nIf you damage goods: Tell your manager immediately. Fill in an incident form. Never hide damage — the store will report it on delivery and it traces back to the dock.\n\n[b]Target:[/b] Complete the physical load within 1 hour of the truck's scheduled departure window.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Trailer Sizes & Capacity",
		"tags": ["trailer", "capacity", "8.5", "13.6", "truck", "size", "pallet", "full", "space"],
		"content": "[font_size=28][color=#0082c3][b]Trailer Sizes & Capacity[/b][/color][/font_size]\n\n[b]8.5m trailer:[/b] approximately 18 EUR pallets\n[b]13.6m trailer:[/b] approximately 33 to 36 EUR pallets\n\n[b]Truck types:[/b]\n[b]Live loading:[/b] Driver arrives with the trailer attached and is waiting. Load immediately.\n[b]Non-live:[/b] An empty trailer is already parked at your dock.\n[b]CO loading:[/b] Two stores in one trailer, loaded in two separate sections.\n\n[b]When the truck is full:[/b]\nThe capacity bar turns red. If you have D+ pallets loaded and a D pallet left behind, you have a sequencing problem — unload the D+ first.\n\n[b]Transport companies:[/b] DHL (primary), SCHOTPOORT, P&M",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Creating a Shipment (F6)",
		"tags": ["shipment", "expedition", "f6", "create", "seal", "destinataire", "saisie"],
		"content": "[font_size=28][color=#0082c3][b]Creating a Shipment[/b][/color][/font_size]\n\nFrom EXPEDITION EN COURS, press [b]F6=Creer[/b].\n\nA badge login popup appears. Log in with badge [b]8600555[/b] and password [b]123456[/b]. After login you land on the SAISIE screen.\n\n[b]SAISIE fields:[/b]\nN expédition: Auto-generated — do not change.\nExpediteur camion: 14  390 — auto-filled.\nDestinataire: For co-loading, type the store code here.\nSEAL number 1: Auto-filled from the seal booklet.\nSEAL number 2: Always empty for Bay B2B standard operations.\nType transport: 1 (road).\nType expedition: C (Classical) or S (Specific).\n\nPress [b]F10=Valider[/b] to confirm. You land on SCANNING QUAI, ready to scan.\n\nThis sequence — F6, badge login, SAISIE, F10 — is exactly what you do on the real terminal before every loading.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Promise Dates: D, D-, D+",
		"tags": ["promise", "date", "d+", "d-", "priority", "capacity", "full", "overdue", "sequence"],
		"content": "[font_size=28][color=#0082c3][b]Promise Dates & Loading Priority[/b][/color][/font_size]\n\nEvery pallet has a promise date telling you when the store expects delivery.\n\n[color=#e74c3c][b]D-[/b][/color] Overdue. Already late. Must load. No exceptions.\n[color=#f1c40f][b]D[/b][/color]  Due today. Must load.\n[color=#95a5a6][b]D+[/b][/color] Due tomorrow. Can wait if the truck is full.\n\n[b]Loading order when dates are mixed:[/b]\nService Center, then D- pallets, then D pallets, then D+ pallets, then C&C always last.\n\nWithin each date group, the standard department sequence (Bikes, Bulky, Mecha) still applies.\n\n[b]Rule:[/b] Never leave a D or D- pallet behind while a D+ is loaded. If space is tight, unload D+ first.\n\n[b]In the simulator:[/b] Promise dates are randomised across Bikes, Bulky, and Mecha pallets. Hover over a pallet on the dock to see its promise date before loading.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Co-Loading: Two Stores, One Truck",
		"tags": ["co", "loading", "two", "stores", "sequence", "divider", "partner", "tab", "saisie", "destinataire"],
		"content": "[font_size=28][color=#0082c3][b]Co-Loading (CO)[/b][/color][/font_size]\n\nSome stores share a truck. The trailer is physically divided.\n\n[b]Sequence 1[/b] = loaded FIRST (deeper in truck, unloaded last at Store 1)\n[b]Sequence 2[/b] = loaded SECOND (near doors, unloaded first at Store 2)\n\n[b]Common CO pairs:[/b]\nKerkrade 346 / Roermond 2094\nCoolsingel 1161 / Den Haag 1186\nGroningen 2224 / Leeuwarden 897\nEnschede 2092 / Nijmegen 2225\nAlexandrium 2093 / Amsterdam Noord 2226\n\n[b]AS400 Path A (Two Tabs — Recommended):[/b]\nF6 → badge → SAISIE → type store 1 code → F10 → scan store 1. Then click New Tab and repeat for store 2. Switch tabs freely to see each store's RAQ.\n\n[b]AS400 Path B (Sequential):[/b]\nComplete store 1 fully (scan → F13 → F10 confirm → F3 back). Then F6 again for store 2.\n\n[b]Critical:[/b] Never mix pallets between stores. The AS400 blocks wrong-store scans. Find codes on the [b]Shift Board[/b].",
		"scenarios": [3],
		"new_in": 3
	},
	{
		"title": "Reading the Loading Plan",
		"tags": ["loading", "plan", "schedule", "time", "store", "co", "solo", "carrier", "truck"],
		"content": "[font_size=28][color=#0082c3][b]Reading the Loading Plan[/b][/color][/font_size]\n\nThe Loading Plan is your shift schedule. It tells you what is coming and when.\n\n[b]It shows:[/b]\nWhich stores, at what time. CO (shared truck) or SOLO. Which carrier (DHL, SCHOTPOORT, P&M). Truck size (8.5m or 13.6m). Live or non-live loading.\n\nYour load is highlighted in yellow. The others give context for pacing your shift.\n\n[b]Three documents, three moments:[/b]\n[b]Loading Plan[/b] — what is scheduled (read before the shift)\n[b]Loading Sheet[/b] — what you physically count (fill during loading)\n[b]CMR[/b] — what you legally certify (sign after loading)",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Transit Rack",
		"tags": ["transit", "rack", "loose", "collis", "missing", "rack check"],
		"content": "[font_size=28][color=#0082c3][b]Transit Rack[/b][/color][/font_size]\n\nSome collis or UATs arrive via the transit rack — a staging area away from the main dock floor. They do not appear on your dock automatically.\n\n[b]Two types:[/b]\n[b]Loose collis[/b] — individual boxes with no UAT. They count toward your total colis but cannot be scanned individually.\n[b]UAT on rack[/b] — a full palletised unit sitting on the transit rack, not yet moved to your dock.\n\n[b]How to know if you have transit items:[/b]\nThe RAQ shows a [color=#00ffff]TRANSIT[/color] row. The [color=#f1c40f]Check Transit[/color] button will be active.\n\n[b]What to do:[/b]\nBefore sealing, click [color=#f1c40f][b]Check Transit + 4 min[/b][/color]. UAT items appear on the dock. Loose collis are counted as collected automatically. Include them in your Loading Sheet.\n\n[b]Timing:[/b] Not every session has transit items (about 35% chance). If the button is greyed out, no trip is needed. Missing transit items is a grading penalty.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "ADR / Dangerous Goods",
		"tags": ["adr", "dangerous", "hazmat", "locker", "red", "lithium", "aerosol", "yellow"],
		"content": "[font_size=28][color=#0082c3][b]ADR — Accord Dangereux Routier[/b][/color][/font_size]\n\nADR goods are legally regulated items: lithium batteries, aerosols, flammable substances, and other hazardous materials under the European ADR road transport agreement.\n\n[b]Recognition:[/b]\nADR pallets appear [color=#ff4444][b]red[/b][/color] in the RAQ from the moment the session starts. They are stored in the [b]yellow lockers[/b] near the dock for safety reasons — not on the open floor.\n\n[b]What to do:[/b]\n1. When you see a red row marked [color=#ff4444]LOCKER[/color], click [color=#f1c40f][b]Check Yellow Lockers + 2 min[/b][/color].\n2. The ADR pallet appears on the dock. The RAQ row updates to ON DOCK.\n3. Load it in promise-date order like any other pallet.\n\n[b]Critical rule:[/b] ADR goods cannot be left in the locker when a shipment is committed. This is a hard operational error — flagged as a critical failure in the debrief.\n\n[b]Documentation:[/b] The dock supervisor handles the dangerous goods declaration. Your job is to make sure the pallet is on the truck.\n\nThe yellow lockers are a real fixture at the dock. ADR goods are always stored separately until collected — this is a legal requirement under the ADR agreement, not a warehouse preference.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Combining Pallets (Deckstacker)",
		"tags": ["combine", "deckstacker", "merge", "stack", "space", "capacity", "light", "small", "c&c", "magnum"],
		"content": "[font_size=28][color=#0082c3][b]Combining Pallets with the Deckstacker[/b][/color][/font_size]\n\nWhen the truck is close to full but you still have small, light pallets to load, combining two pallets into one floor slot can free the space you need.\n\n[b]How it works:[/b]\nUsing a deckstacker, you lift one complete pallet — boxes and all — and place it on top of another closed pallet. Both remain physically intact and clearly separated. The pallet on top sits on the closed lid of the one below. One floor slot. Two UATs. Both scanned into the AS400.\n\n[b]What can be combined:[/b]\nAny small, light pallet where the combined weight stays manageable and the total height stays within the trailer ceiling. C&C Magnum pallets are the most common candidate — a few packages can easily sit on top of a C&C Bulky pallet. Bulky pallets with only a couple of items are also candidates.\n\n[b]Type inheritance:[/b]\nIf either pallet contains C&C, the combined pallet is a C&C pallet and loads last. If either contains ADR goods, the combined pallet is treated as ADR.\n\n[b]Safety rules:[/b]\nIf any individual box weighs more than 20 kg, ask a colleague before moving it — two-person lift required. Never combine if the stack would exceed the trailer's safe loading height (roughly 2.55 m floor to top).\n\n[b]When to combine:[/b]\nOnly combine if the truck is genuinely short on space and combining would let you load an otherwise impossible pallet. If everything fits without combining, skip it — each combine costs about 8 minutes. It is good practice to load the lightest combine-eligible pallets toward the end of your sequence so you have flexibility if a late wave arrives.\n\n[b]C&C still loads last:[/b]\nCombining does not change loading order rules. C&C pallets — combined or not — always load nearest the doors.\n\nThe deckstacker is the actual machine used on the dock floor for this. Combine times in this training reflect realistic deckstacker operation.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Step-by-Step: Tutorial",
		"tags": ["tutorial", "guide", "walkthrough", "start", "step", "how", "first", "begin"],
		"content": "[font_size=28][color=#0082c3][b]Tutorial — Complete Walkthrough[/b][/color][/font_size]\n\nThis is your first shift. Every step is guided on screen. Here is the full sequence so you know what to expect.\n\n[b]Step 1 — Open the AS400[/b]\nClick [b]AS400[/b] in the side panel. You will see the Sign On screen.\n\n[b]Step 2 — Log in to the system[/b]\nType [b]BAYB2B[/b] and press Enter. Then type [b]123456[/b] and press Enter.\n\n[b]Step 3 — Navigate to the scanning screen[/b]\nFollow the prompts: type [b]50[/b], then [b]01[/b], then [b]02[/b], then [b]05[/b]. Press [b]F6[/b] to create a shipment. A badge login appears — type [b]8600555[/b] and press Enter, then [b]123456[/b] and press Enter. Press [b]F10[/b] to confirm the SAISIE screen. You are now on the Scanning screen.\n\n[b]Step 4 — Open Dock View[/b]\nClick [b]Dock View[/b] in the side panel to see the pallets on the dock floor.\n\n[b]Step 5 — Check the RAQ[/b]\nWith the AS400 open, press [b]F13[/b] (or Shift+F1) to open the RAQ — the digital pallet list. Compare the white C&C rows to what is on the dock. One C&C pallet will be missing.\n\n[b]Step 6 — Call departments[/b]\nClick [b]Call Departments (C&C Check)[/b]. The missing pallet will be found and brought to the dock.\n\n[b]Step 7 — Start loading[/b]\nClick [b]Start Loading[/b] to begin. The scanner is now active.\n\n[b]Step 8 — Load one Mecha pallet deliberately out of order[/b]\nClick any blue Mecha pallet. This teaches you what happens when you load out of sequence.\n\n[b]Step 9 — Unload it[/b]\nClick the blue pallet inside the truck view to remove it. This is rework.\n\n[b]Step 10 — Load in correct order[/b]\nNow load in sequence: [color=#f1c40f]Yellow (Service Center)[/color] first, then [color=#2ecc71]Green (Bikes)[/color], then [color=#e67e22]Orange (Bulky)[/color], then [color=#3498db]Blue (Mecha)[/color], then [color=#ffffff]White (C&C)[/color] last.\n\n[b]Step 11 — Check Help & SOPs[/b]\nClick [b]Help & SOPs[/b] in the top right. Time is paused while it is open.\n\n[b]Step 12 — Finish loading[/b]\nLoad all remaining pallets in the correct order.\n\n[b]Step 13 — Validate in the AS400[/b]\nOpen the AS400 and press [b]F10[/b] to confirm the RAQ.\n\n[b]Step 14 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b]. Your shift summary appears.",
		"scenarios": [0],
		"new_in": 0
	},
	{
		"title": "Step-by-Step: Standard Loading",
		"tags": ["standard", "guide", "walkthrough", "step", "how", "solo", "single", "store"],
		"content": "[font_size=28][color=#0082c3][b]Standard Loading — Complete Walkthrough[/b][/color][/font_size]\n\nOne store, one truck. The most common loading type.\n\n[b]Before you start[/b]\nCheck the [b]Shift Board[/b] to confirm your store name, store code, and dock number. The store code is the 3–4 digit number next to your store (e.g. 1570 for Alkmaar). You will need it in the AS400.\n\n[b]Step 1 — Open the AS400 and log in[/b]\nType [b]BAYB2B[/b] → Enter → [b]123456[/b] → Enter.\n\n[b]Step 2 — Navigate to the shipment screen[/b]\nType [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b] → [b]F6[/b]. Enter badge [b]8600555[/b] → Enter → [b]123456[/b] → Enter. The SAISIE screen appears. For solo loading the destination is already set. Press [b]F10[/b] to confirm. You are on the Scanning screen.\n\n[b]Step 3 — Check the RAQ[/b]\nPress [b]F13[/b] to open the RAQ. Check the pallet list:\n• Any [color=#ff4444]red rows[/color] — ADR in the yellow lockers. Click [b]⚠ Check Yellow Lockers[/b] before loading.\n• Any [color=#00ffff]TRANSIT rows[/color] — items on the transit rack. Click [b]Check Transit[/b] before sealing.\n• [color=#ffffff]White rows[/color] — C&C pallets. Count them and compare to the dock.\n\n[b]Step 4 — Call departments if needed[/b]\nIf a C&C pallet is missing from the dock, click [b]Call Departments (C&C Check)[/b] before starting. Do this before clicking Start Loading — it is free time.\n\n[b]Step 5 — Start loading[/b]\nClick [b]Start Loading[/b]. Load in this order:\n1. [color=#f1c40f]Service Center (yellow)[/color]\n2. [color=#2ecc71]Bikes (green)[/color]\n3. [color=#e67e22]Bulky (orange)[/color]\n4. [color=#3498db]Mecha (blue)[/color]\n5. [color=#ffffff]C&C (white)[/color] — always last\n\nIf pallets have mixed promise dates (D-, D, D+), load D- first within each type group, then D, then D+.\n\n[b]Step 6 — Watch the phone[/b]\nIf the Phone button flashes orange, open it. Late pallets may arrive. Check their promise date before deciding to wait or seal.\n\n[b]Step 7 — Check the transit rack[/b]\nIf the RAQ showed a TRANSIT row, click [b]Check Transit · +4 min[/b] before sealing.\n\n[b]Step 8 — Validate the RAQ[/b]\nOnce all pallets are loaded, press [b]F13[/b] to open the RAQ, then [b]F10[/b] to confirm.\n\n[b]Step 9 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b].",
		"scenarios": [1],
		"new_in": 1
	},
	{
		"title": "Step-by-Step: Priority Loading",
		"tags": ["priority", "guide", "walkthrough", "step", "how", "d-", "overdue", "full", "capacity"],
		"content": "[font_size=28][color=#0082c3][b]Priority Loading — Complete Walkthrough[/b][/color][/font_size]\n\nThe truck may not have room for everything. D- pallets will arrive late and force a decision.\n\n[b]Before you start[/b]\nCheck the [b]Shift Board[/b] for your store name, code, and dock. Same as standard — one store, one truck.\n\n[b]Step 1 — Log in and navigate[/b]\nAS400 → [b]BAYB2B[/b] → [b]123456[/b] → [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b] → [b]F6[/b] → badge [b]8600555[/b] → [b]123456[/b] → [b]F10[/b].\n\n[b]Step 2 — Check the RAQ[/b]\nPress [b]F13[/b]. Note what you see. You will have D+ pallets on the dock at the start.\n\n[b]Step 3 — Start loading — but be careful with D+[/b]\nLoad Service Center, Bikes, and Bulky pallets first as normal. For Mecha — these are D+ at the start. Load them if there is clearly enough space. If the truck is getting full, hold back some D+ Mecha pallets.\n\n[b]Step 4 — The phone will ring[/b]\nD- pallets will arrive mid-shift. When the phone flashes, check the message. D- means overdue — they must go on the truck. If you have already loaded D+ pallets and the truck is full, you may need to unload D+ to make room. That is rework, but it is the correct call.\n\n[b]Step 5 — Consider combining[/b]\nIf light pallets (marked with [color=#2ecc71]⊕[/color]) are on the dock and the truck is tight, click [b]⊕ Combine · +8 min[/b] to stack two pallets into one slot. Only worth doing if it lets you load a D- or D pallet you could not otherwise fit.\n\n[b]Step 6 — Load D- pallets first[/b]\nOnce D- pallets arrive on the dock, they load before any D+ pallet. If D+ is already in the truck and there is no room, unload D+ first.\n\n[b]Step 7 — C&C always last[/b]\nRegardless of what else is happening, C&C loads nearest the doors.\n\n[b]Step 8 — Validate and seal[/b]\nF13 → F10 → Seal Truck.",
		"scenarios": [2],
		"new_in": 2
	},
	{
		"title": "Step-by-Step: Co-Loading",
		"tags": ["co", "loading", "guide", "walkthrough", "step", "how", "two", "stores", "sequence", "partner"],
		"content": "[font_size=28][color=#0082c3][b]Co-Loading — Complete Walkthrough[/b][/color][/font_size]\n\nTwo stores share one truck. You load Store 1 completely first (it goes deeper in the truck), then Store 2 (near the doors).\n\n[b]Before you start[/b]\nOpen the [b]Shift Board[/b]. Find your truck entry. It will show two stores with their codes and (Seq.1) / (Seq.2) labels. Write down both codes — you will need them in the AS400.\n\nExample: [b]KERKRADE 346 (Seq.1)[/b] / [b]ROERMOND 2094 (Seq.2)[/b]\n\n[b]Step 1 — Log in to the AS400[/b]\nType [b]BAYB2B[/b] → Enter → [b]123456[/b] → Enter.\n\n[b]Step 2 — Navigate to EXPEDITION EN COURS[/b]\nType [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b].\n\n[b]Step 3 — Create shipment for Store 1 (Seq.1)[/b]\nPress [b]F6[/b]. Badge login: [b]8600555[/b] → Enter → [b]123456[/b] → Enter. You are on the SAISIE screen. Type the [b]Seq.1 store code[/b] (e.g. 346) and press Enter. Press [b]F10[/b] to confirm. You are now on the Scanning screen for Store 1.\n\n[b]Step 4 — Check the RAQ for Store 1[/b]\nPress [b]F13[/b]. Verify C&C pallets, any TRANSIT or ADR rows. Handle them before loading.\n\n[b]Step 5 — Load Store 1 completely[/b]\nLoad ALL pallets for Store 1 in sequence:\n1. [color=#f1c40f]Service Center[/color]\n2. [color=#2ecc71]Bikes[/color]\n3. [color=#e67e22]Bulky[/color]\n4. [color=#3498db]Mecha[/color]\n5. [color=#ffffff]C&C[/color] — last for Store 1\n\nPallet color tags show which store each pallet belongs to. Do not load Store 2 pallets yet.\n\n[b]Step 6 — Validate Store 1 in the AS400[/b]\nPress [b]F13[/b] to open Store 1 RAQ. Press [b]F10[/b] to confirm. Press [b]F3[/b] to return to EXPEDITION EN COURS.\n\n[b]Step 7 — Create shipment for Store 2 (Seq.2)[/b]\nPress [b]F6[/b]. Badge login again: [b]8600555[/b] → Enter → [b]123456[/b] → Enter. On SAISIE, type the [b]Seq.2 store code[/b] (e.g. 2094) and press Enter. Press [b]F10[/b]. You are on the Scanning screen for Store 2.\n\n[b]Tip — Path A (two tabs):[/b] Instead of steps 7 onward, you can click [b]▼ New Tab[/b] in the AS400 panel at any time, log in fresh, and set up Store 2 while Store 1 is still running. Switch tabs freely to see each store's RAQ. Either path is valid.\n\n[b]Step 8 — Check the RAQ for Store 2[/b]\nPress [b]F13[/b] on the Store 2 tab. Handle any TRANSIT or ADR rows.\n\n[b]Step 9 — Load Store 2 completely[/b]\nSame sequence: Service Center → Bikes → Bulky → Mecha → C&C last.\n\n[b]Step 10 — Validate Store 2[/b]\nF13 → F10 to confirm Store 2 RAQ.\n\n[b]Step 11 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b].\n\n[b]Important:[/b] The AS400 will block you from scanning a Store 2 pallet while on the Store 1 tab, and vice versa. If the scanner rejects a pallet, check which tab is active.",
		"scenarios": [3],
		"new_in": 3
	},
	{
		"title": "Good Practices: Thinking Like an Operator",
		"tags": ["good", "practice", "tip", "efficient", "smart", "optimize", "think", "strategy", "combine", "wave", "time", "department"],
		"content": "[font_size=28][color=#0082c3][b]Good Practices: Thinking Like an Operator[/b][/color][/font_size]\n\nThe difference between loading correctly and loading well is timing and anticipation. These practices are not rules — they are habits that experienced operators develop because they reduce pressure and make better use of the time available.\n\n[b]Read before you load[/b]\nOpen the RAQ before clicking Start Loading. Look at what you have: how many pallets, any ADR, any TRANSIT rows. Check the Shift Board for your store code and any notes. One minute of reading saves five minutes of correcting. You cannot unseal a truck.\n\n[b]Call departments before you start — not after[/b]\nIf a C&C pallet is missing from the dock, click Call Departments before you click Start Loading. Calling before loading costs you nothing — that time is not counted against your loading window. Calling after Start Loading adds five minutes to your shift clock. Same action, very different cost depending on when you do it.\n\n[b]Leave combine-eligible pallets for last[/b]\nWhen you see a small, light pallet on the dock (marked with a green [color=#2ecc71]⊕[/color] border), do not rush to load it in strict sequence order. Load the big, heavy pallets first. Keep the light ones near the back of your loading order. Here is why: if a wave arrives later and the truck is suddenly full, those light pallets become your solution — you can combine two of them into one slot and free up space for the incoming priority pallet. If you had already loaded them early, that option is gone. Combining costs 8 minutes but it is worth it if it gets a D- pallet onto the truck.\n\n[b]Do not combine if the truck is not full[/b]\nCombining always costs time. If everything fits without combining, skip it. The deckstacker is a problem-solving tool, not a routine step. The right time to combine is when you are looking at a full truck and a D- pallet still on the dock — not before.\n\n[b]Watch the phone early, not late[/b]\nWhen the phone flashes, open it immediately. The message tells you what is coming and approximately when. If a D- pallet is on its way, you now have time to hold space for it before the truck fills up. If you ignore the phone until the truck is already full, your options become much harder.\n\n[b]Know the difference between waiting and stalling[/b]\nIf a D- wave is confirmed incoming and the truck still has space, wait — there is no cost to holding off on the last few D+ pallets. But if the truck is full of D and D- pallets and only D+ is left on the dock, seal it. Leaving D+ behind while all D and D- are loaded is correct. Do not chase perfection if the truck is already right.\n\n[b]Validate in the AS400 as soon as loading is done[/b]\nDo not wait until the driver is standing at the dock before confirming the RAQ. Confirm it the moment you finish loading — before you think about paperwork or the seal. The confirmation creates the digital record the store relies on. Sealing the truck without confirming means the store receives a truck with no AS400 record of what is on it.\n\n[b]Check the transit rack before you seal, not before you start[/b]\nTransit rack items are added to your RAQ from the start but are not on the dock yet. You do not need to collect them before loading — you can load everything else first and collect transit items at any point before sealing. The cost is 4 minutes. Do not forget: check the RAQ for TRANSIT rows before you click Seal Truck.\n\n[b]For co-loading: treat each store as its own shift[/b]\nThe cleanest mental model for co-loading is to pretend you are doing two separate loadings back to back. Finish Store 1 completely — load, validate in AS400, confirm — then start Store 2 as if it were a fresh shift. Never mix pallets between stores. The physical divider in the truck and the AS400 both enforce this.",
		"scenarios": [1, 2, 3],
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
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar:
		var ptb_sb := StyleBoxFlat.new()
		ptb_sb.bg_color = Color(0.1, 0.11, 0.13)
		ptb_sb.border_width_left = 1
		ptb_sb.border_color = Color(0.2, 0.22, 0.25)
		toggle_bar.add_theme_stylebox_override("panel", ptb_sb)
		toggle_bar.mouse_entered.connect(_on_sidebar_mouse_entered)
		toggle_bar.mouse_exited.connect(_on_sidebar_mouse_exited)

	# Remove Trailer Capacity from sidebar entirely — capacity is shown in the dock view
	if btn_trailer_capacity != null:
		btn_trailer_capacity.queue_free()
		btn_trailer_capacity = null
	# Remove Loading Plan button — content merged into Shift Board
	if btn_loading_plan != null:
		btn_loading_plan.queue_free()
		btn_loading_plan = null

	# Style the Panels header label
	_sidebar_panels_lbl = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PanelsLabel
	if _sidebar_panels_lbl:
		_sidebar_panels_lbl.add_theme_font_size_override("font_size", 12)
		_sidebar_panels_lbl.add_theme_color_override("font_color", Color(0.4, 0.43, 0.47))
		_sidebar_panels_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- PIN BUTTON (top of sidebar) ---
	var toggle_vbox: VBoxContainer = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox
	if toggle_vbox and _sidebar_panels_lbl:
		_sidebar_pin_btn = Button.new()
		_sidebar_pin_btn.text = "<<"
		_sidebar_pin_btn.tooltip_text = "Collapse sidebar"
		_sidebar_pin_btn.focus_mode = Control.FOCUS_NONE
		_sidebar_pin_btn.add_theme_font_size_override("font_size", 11)
		_sidebar_pin_btn.add_theme_color_override("font_color", Color(0.5, 0.53, 0.57))
		_sidebar_pin_btn.add_theme_color_override("font_hover_color", Color(0.8, 0.85, 0.9))
		var pin_n := StyleBoxFlat.new()
		pin_n.bg_color = Color(0.13, 0.14, 0.16)
		pin_n.corner_radius_top_left = 3; pin_n.corner_radius_top_right = 3
		pin_n.corner_radius_bottom_left = 3; pin_n.corner_radius_bottom_right = 3
		pin_n.content_margin_top = 2; pin_n.content_margin_bottom = 2
		_sidebar_pin_btn.add_theme_stylebox_override("normal", pin_n)
		var pin_h := pin_n.duplicate()
		pin_h.bg_color = Color(0.2, 0.22, 0.26)
		_sidebar_pin_btn.add_theme_stylebox_override("hover", pin_h)
		_sidebar_pin_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_sidebar_pin_btn.pressed.connect(_on_sidebar_pin_pressed)
		toggle_vbox.add_child(_sidebar_pin_btn)
		toggle_vbox.move_child(_sidebar_pin_btn, 0)
		toggle_vbox.move_child(_sidebar_panels_lbl, 0)

	# --- REGISTER BUTTON ICON MAPPINGS ---
	_sidebar_btn_labels[btn_shift_board] = {"icon": "SB", "label": "Shift Board"}
	_sidebar_btn_labels[btn_as400] = {"icon": "AS", "label": "AS400"}
	_sidebar_btn_labels[btn_phone] = {"icon": "PH", "label": "Phone"}
	_sidebar_btn_labels[btn_notes] = {"icon": "NT", "label": "Notes"}

	var toggle_buttons: Array = [btn_shift_board, btn_as400, btn_phone, btn_notes]
	for tb: Button in toggle_buttons:
		if tb == null: continue
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_size_override("font_size", 13)
		tb.clip_text = true
		var tb_n := StyleBoxFlat.new()
		tb_n.bg_color = Color(0.15, 0.16, 0.18)
		tb_n.corner_radius_top_left = 4; tb_n.corner_radius_top_right = 4
		tb_n.corner_radius_bottom_left = 4; tb_n.corner_radius_bottom_right = 4
		tb_n.border_width_left = 1; tb_n.border_width_top = 1; tb_n.border_width_right = 1; tb_n.border_width_bottom = 1
		tb_n.border_color = Color(0.25, 0.27, 0.3)
		tb.add_theme_stylebox_override("normal", tb_n)
		var tb_h := tb_n.duplicate()
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
				if as400_state == 9: as400_state = 22
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
				_save_tab_state()
				_render_as400_screen()
		elif event.keycode == KEY_F10:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 19:
					# Co-loading: require destinataire entered first
					var tab_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "") if not _as400_tabs.is_empty() else ""
					if current_dest2_name != "" and tab_code == "":
						if lbl_hover_info:
							lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire requis![/b] Type the store code first, then press Enter, then F10.[/color][/font_size]"
						return
					as400_state = 18
					_save_tab_state()
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
					_save_tab_state()
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
		elif event.keycode == KEY_F13:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 18:
					as400_state = 8
					_save_tab_state()
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
					_on_raq_opened()
					if tutorial_active and tutorial_step == 4:
						tutorial_step = 5
						_update_tutorial_ui()
		elif event.keycode == KEY_F1 and event.shift_pressed:
			if pnl_as400_stage != null and pnl_as400_stage.visible:
				if as400_state == 18:
					as400_state = 8
					_save_tab_state()
					_render_as400_screen()
					WOTSAudio.play_as400_key(self)
					_on_raq_opened()
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
			t += "Great. Now log in. Type [color=#f1c40f]BAYB2B[/color] and press Enter, then type [color=#f1c40f]123456[/color] and press Enter. Each screen shows a prompt telling you what to type next — follow those as you go."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		2: 
			t += "You're in the main menu. Each screen will tell you what to type. Navigate to the scanning screen: the placeholder text at the bottom guides you. Keep going until you see [color=#f1c40f]SCANNING QUAI[/color] — that's your main work screen."
			_set_tutorial_focus(as400_terminal_input, "top", true)
		3: 
			t += "You're on the Scanning screen — this is where you work. Now open [color=#f1c40f][b]Dock View[/b][/color] from the panel menu. Dock View shows you the physical pallets sitting on your dock floor."
			_set_tutorial_focus(btn_dock_view, "top", true)
		4: 
			t += "These are your pallets. Now check the [color=#f1c40f][b]AS400[/b][/color] and press [color=#f1c40f][b]F13[/b][/color] (or [color=#f1c40f]Shift+F1[/color]) to open the RAQ — the digital pallet list. Compare what the system shows to what's on the dock floor."
			_set_tutorial_focus(btn_as400, "top", true)
		5: 
			t += "See the [color=#bdc3c7]White rows[/color] at the bottom of the RAQ? Those are Click & Collect pallets — customer orders. Compare the count in the RAQ to the dock. One C&C pallet isn't on the dock yet — it's somewhere in the warehouse. Click [color=#f1c40f][b]Call Departments (C&C Check)[/b][/color] to have it found and brought over."
			_set_tutorial_focus(btn_call, "bottom", true)
		6: 
			t += "Good — the missing pallet is on its way. That call takes about [color=#f1c40f]5 minutes[/color] of shift time. Now click [color=#f1c40f][b]Start Loading[/b][/color] to begin the physical loading process."
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
	title.text = "Help & SOPs"
	title.add_theme_font_size_override("font_size", 24)
	title_margin.add_child(title)

	# Tab buttons
	var tab_spacer_l := Control.new()
	tab_spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(tab_spacer_l)

	var tab_hbox := HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 4)
	tab_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(tab_hbox)

	var tab_labels: Array[String] = ["Doing the Job", "Understanding the Job"]
	sop_tab_btns.clear()
	for ti: int in range(2):
		var tab_num: int = ti + 1
		var tb := Button.new()
		tb.text = tab_labels[ti]
		tb.custom_minimum_size = Vector2(180, 36)
		tb.focus_mode = Control.FOCUS_NONE
		var tb_active := StyleBoxFlat.new()
		tb_active.bg_color = Color(0.0, 0.51, 0.76)
		tb_active.set_corner_radius_all(4)
		var tb_inactive := StyleBoxFlat.new()
		tb_inactive.bg_color = Color(0.15, 0.2, 0.28)
		tb_inactive.set_corner_radius_all(4)
		tb.add_theme_stylebox_override("normal", tb_active if tab_num == 1 else tb_inactive)
		tb.add_theme_stylebox_override("hover", tb_active)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.add_theme_color_override("font_color", Color.WHITE)
		tb.pressed.connect(func() -> void:
			sop_active_tab = tab_num
			_refresh_sop_tab_styles()
			_on_sop_search_changed(sop_search_input.text)
			sop_content_label.text = "[color=#95a5a6]Select an article from the left.[/color]"
		)
		tab_hbox.add_child(tb)
		sop_tab_btns.append(tb)

	var tab_spacer_r := Control.new()
	tab_spacer_r.custom_minimum_size = Vector2(20, 0)
	header_hbox.add_child(tab_spacer_r)
	
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

func _refresh_sop_tab_styles() -> void:
	for i: int in range(sop_tab_btns.size()):
		var tb: Button = sop_tab_btns[i]
		var is_active: bool = (i + 1 == sop_active_tab)
		var tb_sb := StyleBoxFlat.new()
		tb_sb.bg_color = Color(0.0, 0.51, 0.76) if is_active else Color(0.15, 0.2, 0.28)
		tb_sb.set_corner_radius_all(4)
		tb.add_theme_stylebox_override("normal", tb_sb)

func _open_sop_modal() -> void:
	if _session != null: _session.call("set_pause_state", true)
	sop_active_tab = 1
	_refresh_sop_tab_styles()
	sop_search_input.text = ""
	sop_content_label.text = "[color=#95a5a6]Select an article from the left.[/color]"
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

	# Tab 1 = simulator procedural articles, Tab 2 = real warehouse knowledge
	var tab1_titles: Array[String] = [
		"Your First Shift: Where to Start",
		"AS400: Login & Shortcuts",
		"Setting the Loading Destination",
		"Reading the RAQ Screen",
		"Creating a Shipment (F6)",
		"Late Arrivals & Wave Deliveries",
		"Rework: When to Unload a Pallet",
		"Transit Rack",
		"ADR / Dangerous Goods",
		"Combining Pallets (Deckstacker)",
		"Step-by-Step: Tutorial",
		"Step-by-Step: Standard Loading",
		"Step-by-Step: Priority Loading",
		"Step-by-Step: Co-Loading",
		"Good Practices: Thinking Like an Operator",
	]

	var q: String = query.to_lower()
	var new_arts: Array = []
	var old_arts: Array = []

	for article: Dictionary in sop_database:
		if not article.scenarios.has(_current_scenario_index):
			continue

		var in_tab1: bool = article.title in tab1_titles
		var article_tab: int = 1 if in_tab1 else 2
		if article_tab != sop_active_tab:
			continue

		var match_found: bool = false
		if q == "": match_found = true
		elif q in article.title.to_lower(): match_found = true
		else:
			for tag: String in article.tags:
				if q in tag.to_lower(): match_found = true

		if match_found:
			if article.get("new_in", -1) == _current_scenario_index:
				new_arts.append(article)
			else:
				old_arts.append(article)
				
	var create_btn: Callable = func(art: Dictionary, is_new: bool) -> void:
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
		
	for a: Dictionary in new_arts: create_btn.call(a, true)
	for a: Dictionary in old_arts: create_btn.call(a, false)

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

	# Dev bypass — unlocks all scenarios for testing
	var btn_dev := Button.new()
	btn_dev.text = "🔧 Dev: Unlock All Scenarios"
	btn_dev.custom_minimum_size = Vector2(0, 32)
	btn_dev.focus_mode = Control.FOCUS_NONE
	var dev_sb := StyleBoxFlat.new()
	dev_sb.bg_color = Color(0.1, 0.1, 0.1, 0.0)
	btn_dev.add_theme_stylebox_override("normal", dev_sb)
	btn_dev.add_theme_stylebox_override("hover", dev_sb)
	btn_dev.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_dev.add_theme_color_override("font_color", Color(0.35, 0.37, 0.4))
	btn_dev.add_theme_color_override("font_hover_color", Color(0.55, 0.57, 0.6))
	btn_dev.add_theme_font_size_override("font_size", 11)
	btn_dev.pressed.connect(func() -> void:
		highest_unlocked_scenario = 3
		_populate_scenarios()
	)
	vbox.add_child(btn_dev)

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

	btn_transit = make_action_btn.call(" Check Transit · +4 min ", false)
	btn_transit.pressed.connect(func() -> void: _on_decision_pressed("Check Transit"))
	btn_transit.visible = false
	btn_transit.disabled = true
	top_actions_hbox.add_child(btn_transit)

	btn_adr = make_action_btn.call(" ⚠ Check Yellow Lockers · +2 min ", true)
	btn_adr.pressed.connect(func() -> void: _on_decision_pressed("Check Yellow Lockers"))
	btn_adr.visible = false
	btn_adr.disabled = true
	var adr_sb := StyleBoxFlat.new()
	adr_sb.bg_color = Color(0.18, 0.08, 0.04)
	adr_sb.border_color = Color(0.9, 0.4, 0.0)
	adr_sb.set_border_width_all(2)
	adr_sb.set_corner_radius_all(4)
	btn_adr.add_theme_stylebox_override("normal", adr_sb)
	btn_adr.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	top_actions_hbox.add_child(btn_adr)

	btn_combine = make_action_btn.call(" ⊕ Combine · +8 min ", false)
	btn_combine.pressed.connect(func() -> void: _on_decision_pressed("Combine Pallets"))
	btn_combine.visible = false
	btn_combine.disabled = true
	var combine_sb := StyleBoxFlat.new()
	combine_sb.bg_color = Color(0.05, 0.18, 0.08)
	combine_sb.border_color = Color(0.18, 0.8, 0.44)
	combine_sb.set_border_width_all(2)
	combine_sb.set_corner_radius_all(4)
	btn_combine.add_theme_stylebox_override("normal", combine_sb)
	btn_combine.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
	top_actions_hbox.add_child(btn_combine)

	var top_spacer := Control.new()
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
	btn_dock_view.clip_text = true
	btn_shift_board.get_parent().add_child(btn_dock_view)
	btn_shift_board.get_parent().move_child(btn_dock_view, 2)

	# Style the dock view button to match others
	btn_dock_view.add_theme_font_size_override("font_size", 13)
	var dv_n := StyleBoxFlat.new()
	dv_n.bg_color = Color(0.15, 0.16, 0.18)
	dv_n.corner_radius_top_left = 4; dv_n.corner_radius_top_right = 4
	dv_n.corner_radius_bottom_left = 4; dv_n.corner_radius_bottom_right = 4
	dv_n.border_width_left = 1; dv_n.border_width_top = 1; dv_n.border_width_right = 1; dv_n.border_width_bottom = 1
	dv_n.border_color = Color(0.25, 0.27, 0.3)
	btn_dock_view.add_theme_stylebox_override("normal", dv_n)
	var dv_h := dv_n.duplicate()
	dv_h.bg_color = Color(0.2, 0.22, 0.26)
	dv_h.border_color = Color(0.0, 0.51, 0.76)
	btn_dock_view.add_theme_stylebox_override("hover", dv_h)
	btn_dock_view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_dock_view.focus_mode = Control.FOCUS_NONE
	btn_dock_view.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	btn_dock_view.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_sidebar_btn_labels[btn_dock_view] = {"icon": "DV", "label": "Dock View"}
	
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
	pnl_as400_stage.size_flags_stretch_ratio = 1.4
	pnl_as400_stage.visible = false 
	
	var as400_sb = StyleBoxFlat.new()
	as400_sb.bg_color = Color(0, 0, 0) 
	pnl_as400_stage.add_theme_stylebox_override("panel", as400_sb)
	stage_hbox.add_child(pnl_as400_stage)
	
	var as400_vbox = VBoxContainer.new()
	pnl_as400_stage.add_child(as400_vbox)

	# --- Tab bar (browser-style tabs, shown for all sessions) ---
	as400_tab_bar = HBoxContainer.new()
	as400_tab_bar.add_theme_constant_override("separation", 2)
	as400_tab_bar.custom_minimum_size = Vector2(0, 30)
	var tab_bar_bg := StyleBoxFlat.new()
	tab_bar_bg.bg_color = Color(0.02, 0.06, 0.02)
	tab_bar_bg.border_width_bottom = 1
	tab_bar_bg.border_color = Color(0.0, 0.4, 0.0)
	as400_tab_bar.add_theme_stylebox_override("panel", tab_bar_bg)
	as400_vbox.add_child(as400_tab_bar)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	as400_vbox.add_child(scroll)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 10)
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
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_seal_confirm(self)

# ==========================================
# AS400 TAB SYSTEM
# ==========================================
func _init_as400_tabs() -> void:
	_as400_tabs.clear()
	_active_tab_idx = 0
	_as400_tabs.append({"state": 0, "badge_target": 18, "dest_code": "", "dest_name": ""})
	_rebuild_as400_tab_bar()

func _save_tab_state() -> void:
	if _as400_tabs.is_empty(): return
	_as400_tabs[_active_tab_idx]["state"] = as400_state
	_as400_tabs[_active_tab_idx]["badge_target"] = _badge_target

func _load_tab_state() -> void:
	if _as400_tabs.is_empty(): return
	as400_state = _as400_tabs[_active_tab_idx].get("state", 0)
	_badge_target = _as400_tabs[_active_tab_idx].get("badge_target", 18)

func _switch_as400_tab(idx: int) -> void:
	if idx < 0 or idx >= _as400_tabs.size(): return
	if idx == _active_tab_idx: return
	_save_tab_state()
	_active_tab_idx = idx
	_load_tab_state()
	_rebuild_as400_tab_bar()
	_render_as400_screen()
	WOTSAudio.play_as400_key(self)

func _add_as400_tab() -> void:
	if _as400_tabs.size() >= 2: return
	if current_dest2_name == "": return
	_save_tab_state()
	_as400_tabs.append({"state": 0, "badge_target": 18, "dest_code": "", "dest_name": ""})
	_active_tab_idx = _as400_tabs.size() - 1
	_load_tab_state()
	_rebuild_as400_tab_bar()
	_render_as400_screen()
	WOTSAudio.play_as400_key(self)

func _rebuild_as400_tab_bar() -> void:
	if as400_tab_bar == null: return
	for child in as400_tab_bar.get_children():
		child.queue_free()

	for i: int in range(_as400_tabs.size()):
		var tab_dict: Dictionary = _as400_tabs[i]
		var tab_btn := Button.new()
		var dest_code_str: String = tab_dict.get("dest_code", "")
		var tab_label: String
		if dest_code_str != "":
			var dname: String = tab_dict.get("dest_name", dest_code_str)
			tab_label = " %s %s " % [dname, dest_code_str]
		else:
			tab_label = " Tab %d " % (i + 1)
		tab_btn.text = tab_label
		tab_btn.focus_mode = Control.FOCUS_NONE
		var is_active: bool = (i == _active_tab_idx)
		var tab_sb := StyleBoxFlat.new()
		tab_sb.bg_color = Color(0.05, 0.25, 0.05) if is_active else Color(0.02, 0.08, 0.02)
		tab_sb.border_width_bottom = 0 if is_active else 1
		tab_sb.border_color = Color(0.0, 0.55, 0.0)
		tab_sb.corner_radius_top_left = 4
		tab_sb.corner_radius_top_right = 4
		tab_btn.add_theme_stylebox_override("normal", tab_sb)
		tab_btn.add_theme_stylebox_override("hover", tab_sb)
		tab_btn.add_theme_stylebox_override("pressed", tab_sb)
		tab_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0) if is_active else Color(0.0, 0.65, 0.0))
		tab_btn.add_theme_font_size_override("font_size", 13)
		var cap_i: int = i
		tab_btn.pressed.connect(func() -> void: _switch_as400_tab(cap_i))
		as400_tab_bar.add_child(tab_btn)

	# Spacer to push "New Tab" button to right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	as400_tab_bar.add_child(spacer)

	# "New Tab" arrow button — only for co-loading with room for a second tab
	if current_dest2_name != "" and _as400_tabs.size() < 2:
		var plus_btn := Button.new()
		plus_btn.text = " ▼ New Tab "
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.tooltip_text = "Open a second tab for %s %s" % [current_dest2_name, current_dest2_code]
		var plus_sb := StyleBoxFlat.new()
		plus_sb.bg_color = Color(0.03, 0.1, 0.03)
		plus_sb.border_width_bottom = 1
		plus_sb.border_color = Color(0.0, 0.4, 0.0)
		plus_btn.add_theme_stylebox_override("normal", plus_sb)
		plus_btn.add_theme_stylebox_override("hover", plus_sb)
		plus_btn.add_theme_stylebox_override("pressed", plus_sb)
		plus_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 0.0))
		plus_btn.add_theme_font_size_override("font_size", 13)
		plus_btn.pressed.connect(_add_as400_tab)
		as400_tab_bar.add_child(plus_btn)

func _get_tab_dest_seq(tab_idx: int) -> int:
	# Returns 1 or 2 (which sequence this tab is scanning for), or 0 if undetermined
	if tab_idx >= _as400_tabs.size(): return 0
	var code: String = _as400_tabs[tab_idx].get("dest_code", "")
	if code == "": return 0
	if code == current_dest_code: return 1
	if current_dest2_code != "" and code == current_dest2_code: return 2
	return 0

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
		# Filter RAQ to active tab's destination sequence (0 = no filter for single-store)
		var raq_seq_filter: int = _get_tab_dest_seq(_active_tab_idx)
		var total_colis: int = 0
		for p: Dictionary in last_avail_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
			if p.is_uat: total_colis += p.collis
		t += "%sExp{diteur   :   14    390   CAR TILBURG EXPE%s       %sTotal colis :   %d%s\n" % [H, E, H, total_colis, E]
		if current_dest2_name != "":
			var raq_tab_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "") if not _as400_tabs.is_empty() else ""
			var raq_tab_name: String = _as400_tabs[_active_tab_idx].get("dest_name", "") if not _as400_tabs.is_empty() else ""
			if raq_tab_code != "":
				var raq_seq: int = _get_tab_dest_seq(_active_tab_idx)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, raq_tab_code, raq_tab_name, Y, raq_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, current_dest_code, current_dest_name, E]
		t += "%s5=D{tail Colis/UAT   7=Validation UAT transit vocal%s\n\n" % [C, E]
		t += "%s? N{ U.A.T                  Flx Uni NBC SE EM Colis                  Dt Col  CCC/%s\n" % [H, E]
		t += "%s                              CFP     CD                       Dt Exp Adresse%s\n" % [H, E]
		var regular_uats: Array = []
		var cc_uats: Array = []
		for p: Dictionary in last_avail_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
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
			var ddate: String = p.get("delivery_date", "")
			var date_col: String = ddate if ddate != "" else "250326"
			t += "%s  %-20s  MAG %s   0 %s %s %-20s %s %d:%02d:%02d%s\n" % [C, p.id, uni, se, em, p.get("colis_id", "N/A"), date_col, hr, mn, rng_dt.randi_range(0,59), E]
		for p in cc_uats:
			var hr: int = 13 + rng_dt.randi_range(0, 2)
			var mn: int = rng_dt.randi_range(10, 59)
			t += "%s  %-20s  MAP 10    0 86 11 %-20s 170326 %d:%02d:%02d%s\n" % [W, p.id, p.get("colis_id", "N/A"), hr, mn, rng_dt.randi_range(0,59), E]
		# Transit loose collis rows (no UAT, not yet collected)
		if _session != null and not _session.transit_collected:
			var t_loose: int = _session.transit_loose_collis
			var t_loose2: int = _session.transit_loose_dest2_collis
			if current_dest2_name != "":
				var t_seq: int = _get_tab_dest_seq(_active_tab_idx)
				if t_seq == 2:
					t_loose = t_loose2
				else:
					t_loose2 = 0
			if t_loose > 0:
				t += "%s  TRANSIT RACK            MAG ---   -- -- -- %-20s TRANSIT%s\n" % [C, "(" + str(t_loose) + " loose collis — no UAT)", E]
		# Transit UATs not yet collected
		if _session != null and not _session.transit_collected:
			for p_tr: Dictionary in _session.transit_items:
				var p_tr_dest: int = p_tr.get("dest", 1)
				if current_dest2_name != "":
					var tr_seq: int = _get_tab_dest_seq(_active_tab_idx)
					if tr_seq > 0 and p_tr_dest != tr_seq:
						continue
				t += "%s  %-20s  MAP ---   0 86 -- %-20s TRANSIT%s\n" % [C, p_tr.id, p_tr.get("colis_id", ""), E]
		# ADR rows — always red, visible from session start; in locker until collected, then on dock
		if _session != null and _session.has_adr:
			for p_adr: Dictionary in _session.adr_items:
				var p_adr_dest: int = p_adr.get("dest", 1)
				if current_dest2_name != "":
					var adr_seq: int = _get_tab_dest_seq(_active_tab_idx)
					if adr_seq > 0 and p_adr_dest != adr_seq:
						continue
				t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s LOCKER%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), E]
			for p_adr: Dictionary in _session.inventory_available:
				if p_adr.get("type", "") == "ADR":
					var p_adr_dest: int = p_adr.get("dest", 1)
					if current_dest2_name != "":
						var adr_seq: int = _get_tab_dest_seq(_active_tab_idx)
						if adr_seq > 0 and p_adr_dest != adr_seq:
							continue
					t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s ON DOCK%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), E]
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
			var s9_tab_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "") if not _as400_tabs.is_empty() else ""
			var s9_tab_name: String = _as400_tabs[_active_tab_idx].get("dest_name", "") if not _as400_tabs.is_empty() else ""
			if s9_tab_code != "":
				var s9_seq: int = _get_tab_dest_seq(_active_tab_idx)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, s9_tab_code, s9_tab_name, Y, s9_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
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
		# Co-loading: show which store this tab is for
		if current_dest2_name != "" and not _as400_tabs.is_empty():
			var tab_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "")
			var tab_name: String = _as400_tabs[_active_tab_idx].get("dest_name", "")
			if tab_code != "":
				var tab_seq: int = _get_tab_dest_seq(_active_tab_idx)
				var seq_color: String = Y if tab_seq == 1 else "[color=#e67e22]"
				t += "  %sDESTINATAIRE ACTIF:%s %s%s %s (Seq.%d)%s\n\n" % [H, E, seq_color, tab_name, tab_code, tab_seq, E]
			else:
				t += "  %sDESTINATAIRE ACTIF:%s %s[NON DEFINI — Allez sur SAISIE d'abord]%s\n\n" % [H, E, R, E]
		var colis_remaining: int = 0
		var uat_remaining: int = 0
		var colis_loaded: int = 0
		var uat_loaded: int = 0
		var scan_seq_filter: int = _get_tab_dest_seq(_active_tab_idx)
		for p: Dictionary in last_avail_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
			if p.is_uat and not p.missing:
				uat_remaining += 1
				colis_remaining += p.collis
		for p: Dictionary in last_loaded_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
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

	# === SAISIE D'UNE EXPEDITION (state 19) — destinataire typed by user for co-loading ===
	elif as400_state == 19:
		var tab_dest_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "") if not _as400_tabs.is_empty() else ""
		var tab_dest_name: String = _as400_tabs[_active_tab_idx].get("dest_name", "") if not _as400_tabs.is_empty() else ""
		var dest_filled: bool = tab_dest_code != ""
		# For non-co-loading, auto-fill from scenario as before
		if current_dest2_name == "" and not dest_filled:
			tab_dest_code = current_dest_code
			tab_dest_name = current_dest_name
			dest_filled = true
		if dest_filled:
			as400_terminal_input.placeholder_text = "F10=Valider (proceed to scanning) — F3=Sortie"
		else:
			as400_terminal_input.placeholder_text = "Enter store destination code, then press Enter"
		t += "%s%s%s   %s***%s    %s[u]SAISIE D'UNE EXPEDITION[/u]%s  %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:30:24%s                                    %sAJOUTER%s  %sPID2E1R%s\n\n" % [H, E, R, E, H, E]
		t += "%sN{exp{dition    :%s  %s06948174%s              %sExp{diteur camion:%s %s[u]14    390[/u]%s\n\n" % [H, E, Y, E, H, E, Y, E]
		t += "%sExpediteur       :   14    390%s %sCAR TILBURG EXPE%s\n\n" % [H, E, H, E]
		if dest_filled:
			t += "%sDestinataire     :%s  %s 7  %s%s   %s%s%s\n\n" % [H, E, Y, tab_dest_code, E, H, tab_dest_name, E]
		else:
			t += "%sDestinataire     :%s  %s 7  ________%s   %s← Type store code above%s\n\n" % [H, E, Y, E, R, E]
		# Seal number 1: co-loading tabs get different numbers from same booklet
		var seal1_base: int = 8600000 + (hash(current_dest_name) % 9999)
		var seal1: String
		if current_dest2_name != "" and _get_tab_dest_seq(_active_tab_idx) == 2:
			var seal_offset: int = 1 + (hash(current_dest_name + current_dest2_name) % 10)
			seal1 = str(seal1_base + seal_offset)
		else:
			seal1 = str(seal1_base)
		t += "%sSEAL number 1    :%s  %s[u]%s[/u]%s\n" % [H, E, Y, seal1, E]
		t += "%sSEAL number 2    :%s  %s________%s\n\n" % [H, E, Y, E]
		t += "%sType transport :%s %s1%s\n" % [H, E, Y, E]
		t += "%sPrestataire    :%s %sDHL%s\n" % [H, E, Y, E]
		t += "%sType exp{dition :%s %s[u]C[/u]%s %s(C=Classical / S=Specific)%s\n\n\n" % [H, E, Y, E, H, E]
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian"]
		var op_name: String = operators[hash(tab_dest_name if dest_filled else "default") % operators.size()]
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
	var input: String = text.strip_edges().to_upper()
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
		if input == "05": as400_state = 22
		elif input == "06": as400_state = 22
	elif as400_state == 22:
		if input == "F6":
			_badge_target = 19
			as400_state = 6
	elif as400_state == 6 and input == "8600555": as400_state = 7
	elif as400_state == 7 and input == "123456": as400_state = _badge_target
	elif as400_state == 19:
		if input == "F10":
			# For co-loading: require destinataire to be entered first
			var tab_code: String = _as400_tabs[_active_tab_idx].get("dest_code", "") if not _as400_tabs.is_empty() else ""
			if current_dest2_name != "" and tab_code == "":
				# Reject — show error on screen (re-render with error hint)
				_as400_tabs[_active_tab_idx]["dest_code"] = "__ERROR__"
				_render_as400_screen()
				_as400_tabs[_active_tab_idx]["dest_code"] = ""
				if lbl_hover_info:
					lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire requis![/b] Type the store code first, then press Enter, then F10.[/color][/font_size]"
				_save_tab_state()
				return
			as400_state = 18
		elif input == "F3":
			as400_state = 22
		else:
			# User is typing the destinataire store code
			_handle_saisie_dest_input(input)
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(self)
			return
	elif as400_state == 18:
		if input == "F3": as400_state = 5
		elif input == "F13" or input == "SHIFT+F1":
			as400_state = 8
			_on_raq_opened()
	elif as400_state == 8:
		if input == "F3": as400_state = 18
		elif input == "F13": as400_state = 18
	elif as400_state == 9 and input == "F3": as400_state = 22
	elif as400_state == 15 and input == "F3": as400_state = 2
	elif as400_state == 16 and input == "F3": as400_state = 5
	elif as400_state == 17 and input == "F3": as400_state = 5
	elif as400_state == 22 and input == "F3": as400_state = 5
	elif as400_state == 20:
		if input == "1": as400_state = 21
		elif input == "F3": as400_state = 2
	elif as400_state == 21 and input == "F3": as400_state = 20

	_save_tab_state()
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

func _handle_saisie_dest_input(input: String) -> void:
	if _as400_tabs.is_empty(): return
	# Find store by code
	var matched_store: Dictionary = {}
	for s: Dictionary in store_destinations:
		if s.code == input:
			matched_store = s
			break
	if matched_store.is_empty():
		if lbl_hover_info:
			lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire inconnu:[/b] Code '%s' not found. Try again.[/color][/font_size]" % input
		return
	# For co-loading: must be one of the two assigned stores
	if current_dest2_name != "":
		if input != current_dest_code and input != current_dest2_code:
			if lbl_hover_info:
				lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire incorrect:[/b] Code '%s' is not assigned to this truck. Check the Shift Board for the correct store codes.[/color][/font_size]" % input
			return
		# Check if other tab already claimed this store
		for i: int in range(_as400_tabs.size()):
			if i == _active_tab_idx: continue
			if _as400_tabs[i].get("dest_code", "") == input:
				if lbl_hover_info:
					lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Already open:[/b] Store %s is already open in the other tab.[/color][/font_size]" % input
				return
	_as400_tabs[_active_tab_idx]["dest_code"] = matched_store.code
	_as400_tabs[_active_tab_idx]["dest_name"] = matched_store.name
	_rebuild_as400_tab_bar()
	if lbl_hover_info:
		lbl_hover_info.text = "[font_size=15][color=#2ecc71][b]Destinataire OK:[/b] %s %s — press F10 to validate.[/color][/font_size]" % [matched_store.name, matched_store.code]

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
	_clear_phone_flash()
	_load_cooldown = false
	
	portal_overlay.visible = false
	top_actions_hbox.visible = true
	stage_hbox.visible = true
	
	_reset_panel_state()
	_close_all_panels(true)
	
	as400_state = 0
	_as400_wrong_store_scans = 0
	_init_as400_tabs()
	_render_as400_screen()
	
	if _current_scenario_index == 0:
		tutorial_active = true
		tutorial_step = 0
		tut_canvas.visible = true
		_update_tutorial_ui()
		lbl_standby.text = "Your first shift starts here.\n\nFollow the green Training Guide at the top.\nIt will walk you through every step."
		lbl_standby.visible = true
		# Keep sidebar pinned open during tutorial so labels are visible
		_sidebar_pinned = true
		if _sidebar_pin_btn:
			_sidebar_pin_btn.text = "<<"
		_expand_sidebar()
	else:
		tutorial_active = false
		if tut_canvas != null: tut_canvas.visible = false
		lbl_standby.visible = true
	
	_session.call("start_session_with_scenario", _current_scenario_name)
	# Transit: visible for Standard onwards, enabled once player opens the RAQ
	if btn_transit != null:
		btn_transit.visible = (_current_scenario_index >= 1)
		btn_transit.disabled = true
	# ADR: visible only if session has ADR, enabled once player opens the RAQ
	if btn_adr != null:
		btn_adr.visible = (_current_scenario_index >= 1 and _session.has_adr)
		btn_adr.disabled = true
	# Combine: visible for Standard onwards, enabled only after Start Loading
	if btn_combine != null:
		btn_combine.visible = (_current_scenario_index >= 1)
		btn_combine.disabled = true
	_populate_overlay_panels()

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))
	_debrief_total_weight_kg = float(debrief_payload.get("total_weight_kg", 0.0))
	_debrief_total_dm3 = int(debrief_payload.get("total_dm3", 0))
	_debrief_combine_count = int(debrief_payload.get("combine_count", 0))
	
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
	if btn_transit != null: btn_transit.visible = false
	if btn_adr != null: btn_adr.visible = false
	if btn_combine != null: btn_combine.visible = false
	portal_overlay.visible = true

func _refresh_combine_btn() -> void:
	if btn_combine == null or _session == null: return
	if not btn_combine.visible: return
	var has_pair: bool = _session.call("has_combine_pair")
	btn_combine.disabled = not has_pair

func _on_raq_opened() -> void:
	# RAQ has been viewed — enable pre-loading action buttons
	# Determine which dest sequence this tab represents
	var dest_seq: int = _get_tab_dest_seq(_active_tab_idx)
	if _session != null:
		_session.call("mark_raq_viewed", dest_seq)
	# Enable transit and call buttons (ADR always visible from session start if applicable)
	if btn_transit != null and btn_transit.visible:
		btn_transit.disabled = false
	if btn_adr != null and btn_adr.visible:
		btn_adr.disabled = false
	# btn_call is always enabled — no gate needed

func _render_debrief() -> void:
	var bb := "[center][font_size=28][color=#0082c3][b]Story of the Shift[/b][/color][/font_size][/center]\n\n"
	# Truck load summary line
	bb += "[center][font_size=16][color=#7f8fa6]Truck load: [b]%.0f kg[/b]  ·  [b]%d dm³[/b]" % [_debrief_total_weight_kg, _debrief_total_dm3]
	if _debrief_combine_count > 0:
		bb += "  ·  [color=#2ecc71][b]%d deckstacker combine(s)[/b][/color]" % _debrief_combine_count
	bb += "[/color][/font_size][/center]\n\n"
	bb += "[font_size=24][b]Operational Timeline & Decisions[/b][/font_size]\n"
	bb += _debrief_what_happened + "\n"

	if _as400_wrong_store_scans > 0:
		bb += "\n[font_size=18][color=#f1c40f]• AS400 soft error:[/color][/font_size] [font_size=16]The scanner blocked %d attempt(s) to scan a pallet belonging to the wrong store. AS400 prevented incorrect scanning — this is the system working correctly, but it signals the wrong tab was active.[/font_size]\n" % _as400_wrong_store_scans

	if _session != null:
		var had_transit: bool = (_session.transit_items.size() > 0 or _session.transit_loose_collis > 0 or _session.transit_loose_dest2_collis > 0 or _session.transit_collected)
		if had_transit and not _session.transit_collected:
			bb += "\n[font_size=18][color=#f1c40f]• Transit rack not checked:[/color][/font_size] [font_size=16]Collis or UATs were waiting on the transit rack but were never collected before sealing.[/font_size]\n"
		if _session.has_adr and not _session.adr_collected:
			bb += "\n[font_size=18][color=#e74c3c]• ADR pallet not collected:[/color][/font_size] [font_size=16]The ADR pallet was in the yellow lockers but was never retrieved. Dangerous goods cannot be left unsecured when committed to a shipment.[/font_size]\n"

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
		if _session.has_signal("phone_pallets_delivered"): _session.connect("phone_pallets_delivered", Callable(self, "_on_phone_pallets_delivered"))

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
		# Combine is the only button gated behind Start Loading
		if btn_combine != null and btn_combine.visible:
			btn_combine.disabled = false
	elif action == "Check Transit":
		if btn_transit != null:
			btn_transit.disabled = true
	elif action == "Check Yellow Lockers":
		if btn_adr != null:
			btn_adr.disabled = true
	elif action == "Combine Pallets":
		WOTSAudio.play_scan_beep(self)
		_refresh_combine_btn()

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)

func _update_top_time(total_time: float) -> void:
	if top_time_label == null: return
	# Clock starts at 09:00 and only advances once loading has started
	var base_hour: int = 9
	if _session != null and not _session.loading_started:
		top_time_label.text = "09:00:00"
		return
	var total_secs: int = int(total_time)
	var hours: int = base_hour + (total_secs / 3600)
	var mins: int = (total_secs % 3600) / 60
	var secs: int = total_secs % 60
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
	_refresh_combine_btn()
	
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
func _clear_phone_flash() -> void:
	phone_flash_active = false
	if _phone_flash_timer != null:
		_phone_flash_timer.stop()
		_phone_flash_timer.queue_free()
		_phone_flash_timer = null
	if btn_phone != null:
		btn_phone.text = " Phone " if _sidebar_expanded else "PH"
		btn_phone.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))

func _on_phone_pallets_delivered() -> void:
	_update_phone_content()
	if lbl_hover_info:
		lbl_hover_info.text = "[font_size=15][color=#2ecc71][b]Pallets arrived on the dock.[/b][/color][/font_size]"

func _on_phone_notification(message: String, _pallets_added: int) -> void:
	phone_messages.append(message)
	phone_flash_active = true
	WOTSAudio.play_error_buzz(self)

	# Update phone panel content live
	_update_phone_content()

	# Kill any existing flash timer before starting a new one
	if _phone_flash_timer != null:
		_phone_flash_timer.stop()
		_phone_flash_timer.queue_free()
		_phone_flash_timer = null

	if btn_phone != null:
		var orig_color: Color = btn_phone.get_theme_color("font_color")
		var flash_state := {"count": 0}
		var timer := Timer.new()
		timer.wait_time = 0.4
		timer.one_shot = false
		add_child(timer)
		_phone_flash_timer = timer
		timer.timeout.connect(func() -> void:
			if not phone_flash_active:
				timer.stop()
				timer.queue_free()
				if _phone_flash_timer == timer:
					_phone_flash_timer = null
				return
			flash_state.count += 1
			var lbl_full: String = " Phone (!) " if _sidebar_expanded else "!!"
			var lbl_norm: String = " Phone " if _sidebar_expanded else "PH"
			if flash_state.count % 2 == 0:
				btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				btn_phone.text = lbl_full
			else:
				btn_phone.add_theme_color_override("font_color", orig_color)
				btn_phone.text = lbl_norm
			if flash_state.count >= 10:
				timer.stop()
				timer.queue_free()
				if _phone_flash_timer == timer:
					_phone_flash_timer = null
				if phone_flash_active and btn_phone != null:
					btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
					btn_phone.text = lbl_full
		)
		timer.start()

	# Auto-open phone panel if not in tutorial
	if not tutorial_active:
		_set_panel_visible("Phone", true, false)

func _update_phone_content() -> void:
	var ph_body: RichTextLabel = _find_panel_body(pnl_phone)
	if ph_body == null: return
	var t: String = "[font_size=14]"
	t += "[color=#0082c3][b]PHONE[/b][/color]\n"
	t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	# Show delivery-in-progress banner if pallets are on their way
	if _session != null and _session.get("_phone_deliver_timer") > 0.0:
		t += "[color=#f1c40f][b]⏳ Pallets on the way — arriving in ~30 seconds.[/b][/color]\n\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	if phone_messages.size() > 0:
		for i: int in range(phone_messages.size() - 1, -1, -1):
			t += phone_messages[i] + "\n\n"
			if i > 0:
				t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	else:
		t += "[color=#95a5a6]No incoming calls.\n\n"
		t += "Departments will call about late pallets\n"
		t += "and priority changes during loading.\n\n"
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
	if p_type == "ADR": return Color(0.9, 0.15, 0.15)
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

	var is_plastic: bool = (p_type == "Mecha" or p_type == "C&C" or p_type == "ADR")
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
			var ul_timer := get_tree().create_timer(0.23)
			ul_timer.timeout.connect(func() -> void:
				if _session != null: _session.call("unload_pallet_by_id", p.id)
				WOTSAudio.play_unload_warning(self)
				var cd_timer := get_tree().create_timer(0.23)
				cd_timer.timeout.connect(func() -> void:
					_load_cooldown = false
				)
			)
		)
		truck_grid.add_child(btn)

func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn = _build_pallet_graphic(_get_type_color(p_data.type), false, p_data.type)

	# Combine-eligible indicator: green dashed border overlay
	var is_combine_src: bool = false
	if _session != null:
		is_combine_src = _session.call("_is_combine_source", p_data)
	if is_combine_src:
		var border := ReferenceRect.new()
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color(0.18, 0.9, 0.5, 0.9)
		border.border_width = 2.5
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(border)
		var lbl_c := Label.new()
		lbl_c.text = "⊕"
		lbl_c.add_theme_font_size_override("font_size", 11)
		lbl_c.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
		lbl_c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		lbl_c.offset_left = 2
		lbl_c.offset_bottom = 0
		lbl_c.offset_top = -14
		lbl_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl_c)

	# Co-loading destination indicator (small colored corner tag)
	var dest_id: int = p_data.get("dest", 1)
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
	
	var base_label: String = "Plastic" if (p_data.type == "Mecha" or p_data.type == "C&C") else "EUR Wood"
	if p_data.type == "ADR": base_label = "Plastic ⚠ ADR"
	var hover_text = "[font_size=15][color=#0082c3][b]▶ SCAN DATA[/b][/color]  "
	hover_text += "[color=#c0c8d0]Type:[/color] [b][color=#ffffff]%s[/color][/b] [color=#8a9aaa](%s)[/color]%s\n" % [p_data.type, base_label, code_str]
	hover_text += "[color=#c0c8d0]U.A.T:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Colis:[/color] [b][color=#ffffff]%s[/color][/b]\n" % [p_data.id, colis_str]
	hover_text += "[color=#c0c8d0]Promise:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Qty:[/color] [color=#ffffff]%d[/color]   [color=#c0c8d0]Cap:[/color] [color=#ffffff]%0.1f[/color]" % [p_data.promise, p_data.collis, p_data.cap]
	var ddate: String = p_data.get("delivery_date", "")
	if ddate != "":
		hover_text += "\n[color=#c0c8d0]Store delivery date:[/color] [color=#f1c40f][b]%s[/b][/color]" % ddate
	else:
		hover_text += ""
	var w_kg: float = p_data.get("weight_kg", 0.0)
	var v_dm3: int = p_data.get("dm3", 0)
	if w_kg > 0.0:
		hover_text += "\n[color=#c0c8d0]Weight:[/color] [color=#ffffff]%.0f kg[/color]   [color=#c0c8d0]Volume:[/color] [color=#ffffff]%d dm³[/color]" % [w_kg, v_dm3]
	var sub: String = p_data.get("subtype", "")
	if sub != "":
		hover_text += "   [color=#c0c8d0]Type:[/color] [color=#ffffff]%s[/color]" % sub
	var combined: Array = p_data.get("combined_uats", [])
	if not combined.is_empty():
		hover_text += "\n[color=#2ecc71][b]⊕ Combined — carries %d UATs[/b][/color]" % (1 + combined.size())
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

		# Co-loading: wrong-store tab check (scanner blocks wrong-store pallets)
		if current_dest2_name != "" and as400_state == 18:
			var tab_seq: int = _get_tab_dest_seq(_active_tab_idx)
			if tab_seq != 0 and p_data.get("dest", 1) != tab_seq:
				WOTSAudio.play_error_buzz(self)
				var wrong_store_name: String = current_dest_name if p_data.get("dest", 1) == 1 else current_dest2_name
				var wrong_store_code: String = current_dest_code if p_data.get("dest", 1) == 1 else current_dest2_code
				if lbl_hover_info:
					lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]AS400 ERROR — Wrong Store:[/b] This pallet belongs to %s %s. Switch to the correct tab first.[/color][/font_size]" % [wrong_store_name, wrong_store_code]
				_as400_wrong_store_scans += 1
				return
		
		# Start cooldown
		_load_cooldown = true
		
		# Visual feedback: flash pallet before loading
		var orig_mod: Color = btn.modulate
		btn.modulate = Color(1.5, 1.5, 1.5)
		WOTSAudio.play_scan_beep(self)
		
		# Delay the actual load for smooth feel
		var load_timer := get_tree().create_timer(0.23)
		load_timer.timeout.connect(func() -> void:
			if _session != null: _session.call("load_pallet_by_id", p_data.id)
			WOTSAudio.play_load_confirm(self)
			# Release cooldown after a short extra pause
			var cd_timer := get_tree().create_timer(0.23)
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
	_panel_nodes["Trailer Capacity"] = pnl_trailer_capacity
	_panel_nodes["Phone"] = pnl_phone
	_panel_nodes["Notes"] = pnl_notes
	
	if btn_dock_view != null: btn_dock_view.pressed.connect(func() -> void: _toggle_panel("Dock View"))
	if btn_shift_board != null: btn_shift_board.pressed.connect(func() -> void: _toggle_panel("Shift Board"))
	if btn_as400 != null: btn_as400.pressed.connect(func() -> void: _toggle_panel("AS400"))
	if btn_trailer_capacity != null: btn_trailer_capacity.pressed.connect(func() -> void: _toggle_panel("Trailer Capacity"))
	if btn_phone != null: btn_phone.pressed.connect(func() -> void: _toggle_panel("Phone"))
	if btn_notes != null: btn_notes.pressed.connect(func() -> void: _toggle_panel("Notes"))

func _reset_panel_state() -> void:
	_panel_state.clear()
	panels_ever_opened.clear()
	for panel_name in PANEL_NAMES: _panel_state[panel_name] = false

# ==========================================
# SIDEBAR COLLAPSE / EXPAND
# ==========================================

func _on_sidebar_pin_pressed() -> void:
	if _sidebar_pinned:
		_sidebar_pinned = false
		_sidebar_pin_btn.text = ">>"
		_sidebar_pin_btn.tooltip_text = "Pin sidebar open"
		_collapse_sidebar()
	else:
		_sidebar_pinned = true
		_sidebar_pin_btn.text = "<<"
		_sidebar_pin_btn.tooltip_text = "Collapse sidebar"
		_expand_sidebar()

func _on_sidebar_mouse_entered() -> void:
	# Cancel any pending collapse
	_sidebar_collapse_timer = null
	if _sidebar_pinned:
		return
	if _sidebar_expanded:
		return
	_sidebar_hover_timer = get_tree().create_timer(SIDEBAR_HOVER_DELAY)
	_sidebar_hover_timer.timeout.connect(_on_sidebar_hover_expand, CONNECT_ONE_SHOT)

func _on_sidebar_hover_expand() -> void:
	if _sidebar_pinned:
		return
	_expand_sidebar()

func _on_sidebar_mouse_exited() -> void:
	# Cancel any pending expand
	_sidebar_hover_timer = null
	if _sidebar_pinned:
		return
	if not _sidebar_expanded:
		return
	# Delay collapse to prevent flicker during animation
	_sidebar_collapse_timer = get_tree().create_timer(SIDEBAR_COLLAPSE_DELAY)
	_sidebar_collapse_timer.timeout.connect(_on_sidebar_collapse_check, CONNECT_ONE_SHOT)

func _on_sidebar_collapse_check() -> void:
	if _sidebar_pinned:
		return
	if not _sidebar_expanded:
		return
	# Verify mouse is truly outside the sidebar before collapsing
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar == null:
		return
	var mouse_pos := toggle_bar.get_local_mouse_position()
	var bar_rect := Rect2(Vector2.ZERO, toggle_bar.size)
	if not bar_rect.has_point(mouse_pos):
		_collapse_sidebar()

func _expand_sidebar() -> void:
	if _sidebar_expanded:
		return
	_sidebar_expanded = true
	# Animate width first, swap text AFTER animation finishes
	_animate_sidebar(SIDEBAR_EXPANDED_W, true)

func _collapse_sidebar() -> void:
	if not _sidebar_expanded:
		return
	_sidebar_expanded = false
	# Swap text to icons BEFORE animation starts
	_update_sidebar_button_text(false)
	_animate_sidebar(SIDEBAR_COLLAPSED_W, false)

func _animate_sidebar(target_width: float, show_labels_on_finish: bool) -> void:
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar == null:
		return
	if _sidebar_tween != null and _sidebar_tween.is_valid():
		_sidebar_tween.kill()
	_sidebar_tween = create_tween()
	_sidebar_tween.set_ease(Tween.EASE_OUT)
	_sidebar_tween.set_trans(Tween.TRANS_CUBIC)
	_sidebar_tween.tween_property(
		toggle_bar, "custom_minimum_size:x", target_width, SIDEBAR_ANIM_DURATION
	)
	if show_labels_on_finish:
		_sidebar_tween.tween_callback(_update_sidebar_button_text.bind(true))

func _update_sidebar_button_text(expanded: bool) -> void:
	for btn: Button in _sidebar_btn_labels:
		var data: Dictionary = _sidebar_btn_labels[btn]
		if expanded:
			btn.text = data["label"]
		else:
			btn.text = data["icon"]
	if _sidebar_panels_lbl:
		_sidebar_panels_lbl.visible = expanded
	if _sidebar_pin_btn:
		if expanded:
			_sidebar_pin_btn.text = "<<" if _sidebar_pinned else ">>"
		else:
			_sidebar_pin_btn.text = "<<"
		_sidebar_pin_btn.visible = expanded

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
	
	# Clear phone flash when Phone panel is opened, and always refresh content
	if panel_name == "Phone":
		if make_visible:
			_clear_phone_flash()
			_update_phone_content()
			# Tell SessionManager the phone was opened — starts the 30s pallet delivery timer
			if _session != null:
				_session.call("manual_decision", "Phone Opened")
		else:
			# On close, ensure button is in clean state
			if btn_phone != null and not phone_flash_active:
				btn_phone.text = " Phone " if _sidebar_expanded else "PH"
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
	var overlay_panels = [pnl_shift_board, pnl_phone, pnl_notes]
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
	# --- SHIFT BOARD (merged with Loading Plan) ---
	# Hide the now-unused loading plan panel
	if pnl_loading_plan != null: pnl_loading_plan.visible = false

	var sb_body: RichTextLabel = _find_panel_body(pnl_shift_board)
	if sb_body:
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian", "Juan", "Jakub", "Camilo", "Vasco"]
		operators.shuffle()
		var team_str: String = ""
		for i: int in range(mini(operators.size(), 6)):
			team_str += "  %d. %s\n" % [i + 1, operators[i]]

		var t: String = "[font_size=14]"
		t += "[color=#0082c3][b]SHIFT BOARD — Bay B2B[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[color=#f1c40f][b]DATE:[/b][/color] 25/03/2026   [color=#f1c40f][b]SHIFT:[/b][/color] AM\n\n"

		t += "[b]TEAM TODAY:[/b]\n"
		t += team_str + "\n"

		# Loading schedule — full day plan
		t += "[b]LOADING PLAN — 25/03/2026[/b]\n"
		t += "[color=#5a6a7a]TIME    STORE                     TYPE   CARRIER    SIZE[/color]\n"
		t += "[color=#5a6a7a]──────────────────────────────────────────────────────[/color]\n"
		if current_dest2_name != "":
			t += "[color=#f1c40f]09:00   %s %s (Seq.1) /  CO     DHL        13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
			t += "[color=#f1c40f]        %s %s (Seq.2)[/color]\n" % [current_dest2_name, current_dest2_code]
		else:
			t += "[color=#f1c40f]09:00   %-14s %-5s  SOLO   DHL        13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
		t += "10:30   DEN BOSCH 3619             SOLO   DHL        13.6m\n"
		t += "11:00   ARENA 256                  SOLO   DHL        13.6m\n"
		t += "11:30   KERKRADE 346 /             CO     SCHOTPOORT 13.6m\n"
		t += "        ROERMOND 2094\n"
		t += "12:00   BREDA 1088                 SOLO   DHL        8.5m\n"
		t += "13:00   COOLSINGEL 1161 /          CO     P&M        13.6m\n"
		t += "        DEN HAAG 1186\n"
		t += "13:30   EINDHOVEN 1185             SOLO   DHL        13.6m\n"
		t += "14:30   TILBURG 2013               SOLO   DHL        8.5m\n"
		t += "[color=#5a6a7a]Live: ARENA 256, BREDA 1088  ·  Non-live: all others[/color]\n\n"

		t += "[b]EMBALLAGE:[/b]\n"
		t += "  Dock 12 — non-live (from night shift)\n\n"
		t += "[b]EMERGENCY CONTACTS:[/b]\n"
		t += "  [color=#e74c3c]DOUBLON: 1003[/color]\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001\n\n"
		t += "[b]NOTES:[/b]\n"
		t += "  Sorter maintenance 14:00-15:00\n"
		t += "[/font_size]"
		sb_body.text = t

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
