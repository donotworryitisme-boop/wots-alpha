class_name SOPModal
extends RefCounted

# ==========================================
# SOP MODAL — extracted from BayUI.gd
# Owns: SOP articles database, modal UI, search, tab system
# ==========================================

var _ui: Node  # BayUI reference

# SOP UI nodes
var overlay: ColorRect
var search_input: LineEdit
var results_vbox: VBoxContainer
var content_label: RichTextLabel
var active_tab: int = 1  # 1 = Doing the Job, 2 = Understanding the Job
var tab_btns: Array = []

func _init(ui: Node) -> void:
	_ui = ui

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
		"content": "[font_size=28][color=#0082c3][b]AS400: Login & Shortcuts[/b][/color][/font_size]\n\nThe AS400 is a real 1980s-era green-screen terminal. No mouse — keyboard only.\n\n[b]Two logins required:[/b]\n\n[b]1. System login (Sign On screen):[/b]\n[b]User:[/b] BAYB2B   [b]Password:[/b] 123456\n\n[b]2. Badge login (after pressing F6 to create a shipment):[/b]\n[b]Badge:[/b] 8600555   [b]Password:[/b] 123456\n\n[b]Navigation path to scanning screen:[/b]\n50 → 01 → 02 → 05 → F6 → badge login → store code → seal number → F10 (confirm SAISIE) → [b]SCANNING QUAI[/b]\n\nThe screen layout and all keyboard shortcuts below are identical to the real AS400 terminal at the dock.\n\n[b]Key shortcuts:[/b]\n[b]F3[/b] — Go back one screen\n[b]F10[/b] — Confirm / Validate current screen\n[b]F13[/b] or [b]Shift+F1[/b] — Open RAQ from scanning screen\n[b]F6[/b] — Create new shipment (from EXPEDITION EN COURS)\n[b]F5[/b] — Refresh counters on scanning screen",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "Setting the Loading Destination",
		"tags": ["saisie", "expedition", "destinataire", "store", "code", "destination", "declare", "f10"],
		"content": "[font_size=28][color=#0082c3][b]SAISIE D'UNE EXPEDITION[/b][/color][/font_size]\n\nSAISIE means declaration. This screen is where you formally tell the AS400 which store this truck is going to.\n\n[b]When you see this screen:[/b]\nYou pressed F6 from EXPEDITION EN COURS and logged in with your badge. The system needs the destination.\n\n[b]What you do:[/b]\n[b]All scenarios:[/b] Two steps:\n1. Type the [b]store destination code[/b] from the Shift Board and press Enter.\n2. Type the [b]seal number[/b] from the Shift Board and press Enter.\n3. Press [b]F10[/b] to confirm.\n[b]Co-loading:[/b] Same steps, but repeat for each store using a separate AS400 tab.\n\n[b]Where to find the store code and seal number:[/b]\nCheck the [b]Shift Board[/b]. Store codes are listed next to your truck. For co-loading, look for Seq.1 and Seq.2 labels. The seal numbers are shown below the store names.\n\n[b]Why this matters:[/b]\nThe code you enter determines which store the AS400 assigns your scanned pallets to. The seal number is the physical seal placed on the trailer door — it must match the AS400 record.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "C&C (Click & Collect): What is it?",
		"tags": ["click", "collect", "c&c", "white", "customer", "last", "missing", "call"],
		"content": "[font_size=28][color=#0082c3][b]Click & Collect (C&C)[/b][/color][/font_size]\n\nC&C pallets contain items ordered online by customers for store pickup. The customer is already waiting. Every C&C that misses the truck means a customer arrives to an empty counter.\n\n[color=#e74c3c][b]THE RULE:[/b][/color] C&C MUST be loaded [b]LAST[/b] — nearest to the truck doors — so they come off first.\n\n[b]On the AS400:[/b] C&C rows appear in [color=#ffffff][b]WHITE text[/b][/color]. All other pallets are cyan.\n\n[b]Identifying a C&C pallet:[/b]\nC&C pallets have a white [b]CC_LOG[/b] label on the box, separate from the orange UAT label underneath.\n[img=450]res://ui/images/uat_click_collect.png[/img]\n\n[b]Missing C&C:[/b]\nSometimes a C&C pallet is not on the dock when your shift starts. The RAQ shows it, but it is not on the floor. If you see a mismatch, click [b]Call Departments (C&C Check)[/b]. This takes about 5 minutes but always finds the pallet. Never seal the truck without checking.\n\n[b]In this simulator:[/b] Expect 2 to 4 C&C UATs per store per session. About half of sessions will have one C&C pallet missing at the start.",
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
		"content": "[font_size=28][color=#0082c3][b]The Standard Loading Sequence[/b][/color][/font_size]\n\nThe truck is unloaded from the [b]doors inward[/b]. This is LIFO — Last In, First Out. Whatever you load last comes off the truck first at the store.\n\n[b]Load in this order:[/b]\n1. [color=#f1c40f][b]Service Center (Stands)[/b][/color] — deepest in truck\n2. [color=#2ecc71][b]Bikes[/b][/color]\n3. [color=#e67e22][b]Bulky[/b][/color]\n4. [color=#3498db][b]Mecha[/b][/color] — clothing, small electronics, store replenishment boxes\n5. [color=#ffffff][b]Click & Collect[/b][/color] — ALWAYS LAST, nearest to doors\n\n[b]What each type looks like on the dock:[/b]\n\n[color=#2ecc71][b]Bikes pallet[/b][/color] — tall cardboard boxes on a EUR pallet:\n[img=350]res://ui/images/bikes_pallet_photo.png[/img]\n\n[color=#e67e22][b]Bulky pallet[/b][/color] — large fitness/furniture boxes, wrapped:\n[img=350]res://ui/images/bulky_pallet_photo.png[/img]\n\n[color=#3498db][b]Mecha pallet[/b][/color] — blue Loadhog boxes stacked and strapped:\n[img=350]res://ui/images/mecha_pallet_photo.png[/img]\n\n[b]Why this order?[/b]\nC&C comes off first because customers are waiting. Mecha restocks shelves during opening hours. Bikes and Bulky need specialist teams working on a different schedule. Service Center is handled overnight.\n\n[b]LIFO means mistakes cost time:[/b]\nIf you load Mecha before Bikes, the store must move all the Mecha to reach the Bikes. This is why sequence errors are penalised — they create real work at the other end.",
		"scenarios": [0, 1, 2, 3],
		"new_in": 0
	},
	{
		"title": "What is a UAT?",
		"tags": ["uat", "label", "number", "pallet", "barcode", "orange", "scan", "15 digits"],
		"content": "[font_size=28][color=#0082c3][b]What is a UAT?[/b][/color][/font_size]\n\nA UAT (Unite d'Aide au Transport) is a transport unit with an orange scannable label. It can be a pallet, roll cage, or any stackable unit.\n\n[b]The orange label shows:[/b]\nSector (84/86 mecha, 84/89 bikes, 84/90 bulky), pallet type (EUR or PLASTIQUE), sender and destination, colis count, weight, volume, and flow code (MAG = direct to store, MAP = palletised).\n\n[b]Mecha UAT label (sector 84/86):[/b]\n[img=450]res://ui/images/mecha_pallet_uat.png[/img]\n\n[b]Bikes UAT label (sector 84/89):[/b]\n[img=450]res://ui/images/bikes_pallet_uat.png[/img]\n\n[b]Bulky UAT label (sector 84/90):[/b]\n[img=450]res://ui/images/bulky_pallet_uat.png[/img]\n\n[b]Colis prefix identification:[/b]\n8486 = Mecha / Bay B2B\n8490 = Bulky\n8489 = Bikes\n0035 = Service Center (EWM format)\n\n[b]In the AS400:[/b] UAT numbers are 15 digits. When you click a pallet on the dock, the simulator scans it. The AS400 links the UAT to the current shipment and counts the colis toward your total.",
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
		"content": "[font_size=28][color=#0082c3][b]Creating a Shipment[/b][/color][/font_size]\n\nFrom EXPEDITION EN COURS, press [b]F6=Creer[/b].\n\nA badge login popup appears. Log in with badge [b]8600555[/b] and password [b]123456[/b]. After login you land on the SAISIE screen.\n\n[b]SAISIE fields:[/b]\nN expédition: Auto-generated — do not change.\nExpediteur camion: 14  390 — auto-filled.\nDestinataire: Type the store destination code from the Shift Board.\nSEAL number 1: Type the seal number from the Shift Board.\nSEAL number 2: Always empty for Bay B2B standard operations.\nType transport: 1 (road).\nType expedition: C (Classical) or S (Specific).\n\nPress [b]F10=Valider[/b] to confirm. You land on SCANNING QUAI, ready to scan.\n\nThis sequence — F6, badge login, SAISIE, F10 — is exactly what you do on the real terminal before every loading.",
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
		"content": "[font_size=28][color=#0082c3][b]Reading the Loading Plan[/b][/color][/font_size]\n\nThe Loading Plan is your shift schedule. It tells you what is coming and when. In this simulator it is displayed on the [b]Shift Board[/b] panel.\n\n[b]It shows:[/b]\nWhich stores, at what time. CO (shared truck) or SOLO. Which carrier (DHL, SCHOTPOORT, P&M). Truck size (8.5m or 13.6m). Live or non-live loading.\n\nYour load is highlighted in yellow. The others give context for pacing your shift.\n\nFor co-loading, the Shift Board also shows [b]seal numbers[/b] for each sequence. You will need to enter these on the SAISIE screen.\n\n[b]Three documents, three moments:[/b]\n[b]Loading Plan / Shift Board[/b] — what is scheduled (read before the shift)\n[b]Loading Sheet[/b] — what you physically count (fill during loading)\n[b]CMR[/b] — what you legally certify (sign after loading)",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "Transit Rack",
		"tags": ["transit", "rack", "loose", "collis", "missing", "rack check"],
		"content": "[font_size=28][color=#0082c3][b]Transit Rack[/b][/color][/font_size]\n\nSome collis or UATs arrive via the transit rack — a staging area away from the main dock floor. They do not appear on your dock automatically.\n\n[b]The transit rack at Bay B2B:[/b]\nA multi-shelf racking unit with store name labels. Each shelf holds loose collis or small items sorted by destination.\n[img=450]res://ui/images/transit_rack.png[/img]\n\n[b]Two types:[/b]\n[b]Loose collis[/b] — individual boxes with no UAT. They count toward your total colis but cannot be scanned individually.\n[b]UAT on rack[/b] — a full palletised unit sitting on the transit rack, not yet moved to your dock.\n\n[b]Transit UAT label:[/b]\n[img=450]res://ui/images/uat_transit.png[/img]\n\n[b]How to know if you have transit items:[/b]\nThe RAQ shows a [color=#00ffff]TRANSIT[/color] row. The [color=#f1c40f]Check Transit[/color] button will be active.\n\n[b]What to do:[/b]\nBefore sealing, click [color=#f1c40f][b]Check Transit + 4 min[/b][/color]. UAT items appear on the dock. Loose collis are counted as collected automatically. Include them in your Loading Sheet.\n\n[b]Timing:[/b] Not every session has transit items (about 35% chance). If the button is greyed out, no trip is needed. Missing transit items is a grading penalty.",
		"scenarios": [1, 2, 3],
		"new_in": 1
	},
	{
		"title": "ADR / Dangerous Goods",
		"tags": ["adr", "dangerous", "hazmat", "locker", "red", "lithium", "aerosol", "yellow"],
		"content": "[font_size=28][color=#0082c3][b]ADR — Accord Dangereux Routier[/b][/color][/font_size]\n\nADR goods are legally regulated items: lithium batteries, aerosols, flammable substances, and other hazardous materials under the European ADR road transport agreement.\n\n[b]Recognition:[/b]\nADR pallets appear [color=#ff4444][b]red[/b][/color] in the RAQ from the moment the session starts. They are stored in the [b]yellow lockers[/b] near the dock for safety reasons — not on the open floor.\n\n[b]The yellow lockers at Bay B2B:[/b]\nTwo cabinets — one for Liquids/Fluids, one for Gas/Aerosol. Only hazardous material with a UAT ready for Bay B2B is stored here.\n[img=220]res://ui/images/yellow_cabinet_left.png[/img] [img=220]res://ui/images/yellow_cabinet_right.png[/img]\n\n[b]What to do:[/b]\n1. When you see a red row marked [color=#ff4444]LOCKER[/color], click [color=#f1c40f][b]Check Yellow Lockers + 2 min[/b][/color].\n2. The ADR pallet appears on the dock. The RAQ row updates to ON DOCK.\n3. Load it in promise-date order like any other pallet.\n\n[b]Critical rule:[/b] ADR goods cannot be left in the locker when a shipment is committed. This is a hard operational error — flagged as a critical failure in the debrief.\n\n[b]Documentation:[/b] You handle the dangerous goods declaration yourself. When ADR goods are loaded, the paperwork is your responsibility — it travels with the shipment.\n\nThe yellow lockers are a real fixture at the dock. ADR goods are always stored separately until collected — this is a legal requirement under the ADR agreement, not a warehouse preference.",
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
		"content": "[font_size=28][color=#0082c3][b]Tutorial — Complete Walkthrough[/b][/color][/font_size]\n\nThis is your first shift. Every step is guided on screen. Here is the full sequence so you know what to expect.\n\n[b]Step 1 — Open the AS400[/b]\nClick [b]AS400[/b] in the side panel. You will see the Sign On screen.\n\n[b]Step 2 — Log in to the system[/b]\nType [b]BAYB2B[/b] and press Enter. Then type [b]123456[/b] and press Enter.\n\n[b]Step 3 — Navigate to the SAISIE screen[/b]\nFollow the prompts: type [b]50[/b], then [b]01[/b], then [b]02[/b], then [b]05[/b] (menu numbers auto-advance). Press [b]F6[/b] to create a shipment. A badge login appears — type [b]8600555[/b] and press Enter, then [b]123456[/b] and press Enter. You land on the SAISIE screen.\n\n[b]Step 4 — Enter the store code and seal number[/b]\nOpen the [b]Shift Board[/b] from the right panel to find your store code and seal number. Type the [b]store code[/b] into the AS400 and press Enter. Then type the [b]seal number[/b] and press Enter. Then press [b]F10[/b] to confirm the SAISIE. You are now on the Scanning screen.\n\n[b]Step 5 — Open Dock View[/b]\nClick [b]Dock View[/b] in the side panel to see the pallets on the dock floor.\n\n[b]Step 6 — Check the RAQ[/b]\nWith the AS400 open, press [b]F13[/b] (or Shift+F1) to open the RAQ — the digital pallet list. Compare the white C&C rows to what is on the dock. One C&C pallet will be missing.\n\n[b]Step 7 — Call departments[/b]\nClick [b]Call Departments (C&C Check)[/b]. The missing pallet will be found and brought to the dock.\n\n[b]Step 8 — Start loading[/b]\nClick [b]Start Loading[/b] to begin. The scanner is now active.\n\n[b]Step 9 — Load one Mecha pallet deliberately out of order[/b]\nClick any blue Mecha pallet. This teaches you what happens when you load out of sequence.\n\n[b]Step 10 — Unload it[/b]\nClick the blue pallet inside the truck view to remove it. This is rework.\n\n[b]Step 11 — Load in correct order[/b]\nNow load in sequence: [color=#f1c40f]Yellow (Service Center)[/color] first, then [color=#2ecc71]Green (Bikes)[/color], then [color=#e67e22]Orange (Bulky)[/color], then [color=#3498db]Blue (Mecha)[/color], then [color=#ffffff]White (C&C)[/color] last.\n\n[b]Step 12 — Check Help & SOPs[/b]\nClick [b]Help & SOPs[/b] in the top right. Time is paused while it is open.\n\n[b]Step 13 — Finish loading[/b]\nLoad all remaining pallets in the correct order.\n\n[b]Step 14 — Validate in the AS400[/b]\nOpen the AS400 and press [b]F10[/b] to confirm the RAQ.\n\n[b]Step 15 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b]. Your shift summary appears.",
		"scenarios": [0],
		"new_in": 0
	},
	{
		"title": "Step-by-Step: Standard Loading",
		"tags": ["standard", "guide", "walkthrough", "step", "how", "solo", "single", "store"],
		"content": "[font_size=28][color=#0082c3][b]Standard Loading — Complete Walkthrough[/b][/color][/font_size]\n\nOne store, one truck. The most common loading type.\n\n[b]Before you start[/b]\nCheck the [b]Shift Board[/b] to confirm your store name, store code, dock number, and [b]seal number[/b]. You will need the seal number in the AS400.\n\n[b]Step 1 — Open the AS400 and log in[/b]\nType [b]BAYB2B[/b] → Enter → [b]123456[/b] → Enter.\n\n[b]Step 2 — Navigate to the SAISIE screen[/b]\nType [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b] → [b]F6[/b]. Enter badge [b]8600555[/b] → Enter → [b]123456[/b] → Enter. The SAISIE screen appears. Type the [b]store code[/b] from the Shift Board and press Enter. Type the [b]seal number[/b] from the Shift Board and press Enter. Press [b]F10[/b] to confirm. You are on the Scanning screen.\n\n[b]Step 3 — Check the RAQ[/b]\nPress [b]F13[/b] to open the RAQ. Check the pallet list:\n• Any [color=#ff4444]red rows[/color] — ADR in the yellow lockers. Click [b]⚠ Check Yellow Lockers[/b] before loading.\n• Any [color=#00ffff]TRANSIT rows[/color] — items on the transit rack. Click [b]Check Transit[/b] before sealing.\n• [color=#ffffff]White rows[/color] — C&C pallets. Count them and compare to the dock.\n\n[b]Step 4 — Call departments if needed[/b]\nIf a C&C pallet is missing from the dock, click [b]Call Departments (C&C Check)[/b] before starting. Do this before clicking Start Loading — it is free time.\n\n[b]Step 5 — Start loading[/b]\nClick [b]Start Loading[/b]. Load in this order:\n1. [color=#f1c40f]Service Center (yellow)[/color]\n2. [color=#2ecc71]Bikes (green)[/color]\n3. [color=#e67e22]Bulky (orange)[/color]\n4. [color=#3498db]Mecha (blue)[/color]\n5. [color=#ffffff]C&C (white)[/color] — always last\n\n[b]Step 6 — Watch the phone[/b]\nIf the Phone button flashes orange, open it. Late pallets may arrive. Check their promise date before deciding to wait or seal.\n\n[b]Step 7 — Check the transit rack[/b]\nIf the RAQ showed a TRANSIT row, click [b]Check Transit · +4 min[/b] before sealing.\n\n[b]Step 8 — Validate the RAQ[/b]\nOnce all pallets are loaded, press [b]F13[/b] to open the RAQ, then [b]F10[/b] to confirm.\n\n[b]Step 9 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b].",
		"scenarios": [1],
		"new_in": 1
	},
	{
		"title": "Step-by-Step: Priority Loading",
		"tags": ["priority", "guide", "walkthrough", "step", "how", "d-", "overdue", "full", "capacity"],
		"content": "[font_size=28][color=#0082c3][b]Priority Loading — Complete Walkthrough[/b][/color][/font_size]\n\nPallets now show delivery dates instead of D/D+/D-. The truck may not have room for everything. Late arrivals will force decisions.\n\n[b]Understanding delivery dates[/b]\nLoading date is 25/03/2026.\n• [b]D-[/b] (before 25/03) = overdue — the store expected this yesterday or earlier. Must go.\n• [b]D[/b] (25/03) = due today. Must go.\n• [b]D+[/b] (after 25/03) = tomorrow's stock. Load if space allows, can be left behind.\n\nD and D- are the [b]same priority[/b] — they must be on this truck, no question. D+ is secondary.\n\n[b]Correct loading sequence[/b]\nLoad in this exact order:\n1. [color=#f1c40f]Service Center[/color] (deepest)\n2. [color=#2ecc71]Bikes D/D-[/color]\n3. [color=#e67e22]Bulky D/D-[/color]\n4. [color=#3498db]Mecha D/D-[/color]\n5. [color=#2ecc71]Bikes D+[/color]\n6. [color=#e67e22]Bulky D+[/color]\n7. [color=#3498db]Mecha D+[/color]\n8. [color=#ffffff]C&C[/color] (near doors — always last)\n\nAll D and D- pallets go in before any D+ pallets. Within each group, type order is always Bikes → Bulky → Mecha.\n\n[b]When a late pallet arrives via phone[/b]\nDuring loading, the phone may flash with a call from the sorter or a department. Late pallets appear on the dock after you open the phone and wait ~10 seconds.\n\nThe late pallet should be loaded based on what is still left to load — [b]not[/b] compared to what is already on the truck:\n• If you already loaded all D/D- and started D+, and a D- Bikes pallet arrives: load it now, ahead of remaining D+. No penalty — you could not have loaded it earlier.\n• If you are mid-way through D/D- Bulky and a D/D- Bikes pallet arrives: load it now. No need to rework — it arrived late, you load it where you are.\n• If the truck is full and a D- arrives: unload D+ to make room. That rework is the right call.\n\n[b]Step-by-step[/b]\n\n[b]Step 1 — Log in and navigate[/b]\nAS400 → [b]BAYB2B[/b] → [b]123456[/b] → [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b] → [b]F6[/b] → badge [b]8600555[/b] → [b]123456[/b]. On SAISIE: enter [b]store code[/b] → Enter → [b]seal number[/b] → Enter → [b]F10[/b].\n\n[b]Step 2 — Check the RAQ[/b]\nPress [b]F13[/b]. Note what you see. Check delivery dates. Identify which pallets are D/D- (must go) and which are D+ (secondary).\n\n[b]Step 3 — Pre-loading actions[/b]\nCall departments for missing C&C. Check transit rack. Check yellow lockers for ADR. These cost no time before Start Loading.\n\n[b]Step 4 — Start loading[/b]\nClick [b]Start Loading[/b]. Follow the sequence above: all D/D- by type, then all D+ by type, then C&C.\n\n[b]Step 5 — Handle phone calls[/b]\nWhen the phone flashes, open it. New pallets arrive ~10 seconds after. Load them based on what is left to load.\n\n[b]Step 6 — Consider combining[/b]\nIf the truck is tight and light pallets (marked [color=#2ecc71]⊕[/color]) are on the dock, click [b]⊕ Combine · +8 min[/b]. Only worth doing if it lets you fit a must-go pallet.\n\n[b]Step 7 — Validate and seal[/b]\nF13 → F10 → Seal Truck.",
		"scenarios": [2],
		"new_in": 2
	},
	{
		"title": "Step-by-Step: Co-Loading",
		"tags": ["co", "loading", "guide", "walkthrough", "step", "how", "two", "stores", "sequence", "partner"],
		"content": "[font_size=28][color=#0082c3][b]Co-Loading — Complete Walkthrough[/b][/color][/font_size]\n\nTwo stores share one truck. You load Store 1 completely first (it goes deeper in the truck), then Store 2 (near the doors).\n\n[b]Before you start[/b]\nOpen the [b]Shift Board[/b]. Find your truck entry. It will show two stores with their codes, (Seq.1) / (Seq.2) labels, and [b]seal numbers[/b] for each sequence. Write down all four values — you will need them in the AS400.\n\nExample: [b]KERKRADE 346 (Seq.1)[/b] / [b]ROERMOND 2094 (Seq.2)[/b]\nSeal Seq.1: [b]865742[/b]   Seal Seq.2: [b]865797[/b]\n\n[b]Step 1 — Log in to the AS400[/b]\nType [b]BAYB2B[/b] → Enter → [b]123456[/b] → Enter.\n\n[b]Step 2 — Navigate to EXPEDITION EN COURS[/b]\nType [b]50[/b] → [b]01[/b] → [b]02[/b] → [b]05[/b].\n\n[b]Step 3 — Create shipment for Store 1 (Seq.1)[/b]\nPress [b]F6[/b]. Badge login: [b]8600555[/b] → Enter → [b]123456[/b] → Enter. You are on the SAISIE screen.\n1. Type the [b]Seq.1 store code[/b] (e.g. 346) and press Enter.\n2. Type the [b]Seq.1 seal number[/b] from the Shift Board and press Enter.\n3. Press [b]F10[/b] to confirm.\nYou are now on the Scanning screen for Store 1.\n\n[b]Step 4 — Check the RAQ for Store 1[/b]\nPress [b]F13[/b]. Verify C&C pallets, any TRANSIT or ADR rows. Handle them before loading.\n\n[b]Step 5 — Load Store 1 completely[/b]\nLoad ALL pallets for Store 1 in sequence:\n1. [color=#f1c40f]Service Center[/color]\n2. [color=#2ecc71]Bikes[/color]\n3. [color=#e67e22]Bulky[/color]\n4. [color=#3498db]Mecha[/color]\n5. [color=#ffffff]C&C[/color] — last for Store 1\n\nPallet color tags show which store each pallet belongs to. Do not load Store 2 pallets yet.\n\n[b]Step 6 — Validate Store 1 in the AS400[/b]\nPress [b]F13[/b] to open Store 1 RAQ. Press [b]F10[/b] to confirm. Press [b]F3[/b] to return to EXPEDITION EN COURS.\n\n[b]Step 7 — Create shipment for Store 2 (Seq.2)[/b]\nPress [b]F6[/b]. Badge login again: [b]8600555[/b] → Enter → [b]123456[/b] → Enter. On SAISIE:\n1. Type the [b]Seq.2 store code[/b] (e.g. 2094) and press Enter.\n2. Type the [b]Seq.2 seal number[/b] from the Shift Board and press Enter.\n3. Press [b]F10[/b].\nYou are on the Scanning screen for Store 2.\n\n[b]Tip — Path A (two tabs):[/b] Instead of steps 7 onward, you can click [b]▼ New Tab[/b] in the AS400 panel at any time, log in fresh, and set up Store 2 while Store 1 is still running. Switch tabs freely to see each store's RAQ. Either path is valid.\n\n[b]Step 8 — Check the RAQ for Store 2[/b]\nPress [b]F13[/b] on the Store 2 tab. Handle any TRANSIT or ADR rows.\n\n[b]Step 9 — Load Store 2 completely[/b]\nSame sequence: Service Center → Bikes → Bulky → Mecha → C&C last.\n\n[b]Step 10 — Validate Store 2[/b]\nF13 → F10 to confirm Store 2 RAQ.\n\n[b]Step 11 — Seal the truck[/b]\nClick [b]Seal Truck & Print Papers[/b].\n\n[b]Important:[/b] The AS400 will block you from scanning a Store 2 pallet while on the Store 1 tab, and vice versa. If the scanner rejects a pallet, check which tab is active.",
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

func _build_sop_modal() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9) 
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	_ui.get_node("Root").add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

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
	title.text = Locale.t("sop.title")
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

	var tab_labels: Array[String] = [Locale.t("sop.tab_doing"), Locale.t("sop.tab_understanding")]
	tab_btns.clear()
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
			active_tab = tab_num
			_refresh_sop_tab_styles()
			_on_sop_search_changed(search_input.text)
			content_label.text = "[color=#95a5a6]" + Locale.t("sop.select_article") + "[/color]"
			content_label.get_v_scroll_bar().value = 0
		)
		tab_hbox.add_child(tb)
		tab_btns.append(tb)

	var tab_spacer_r := Control.new()
	tab_spacer_r.custom_minimum_size = Vector2(20, 0)
	header_hbox.add_child(tab_spacer_r)
	
	var btn_close = Button.new()
	btn_close.text = Locale.t("sop.resume")
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
	
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search SOPs..."
	search_input.custom_minimum_size = Vector2(0, 40)
	search_input.text_changed.connect(_on_sop_search_changed)
	left_vbox.add_child(search_input)
	
	var scroll_res = ScrollContainer.new()
	scroll_res.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_res)
	
	results_vbox = VBoxContainer.new()
	results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_res.add_child(results_vbox)

	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 30)
	right_margin.add_theme_constant_override("margin_top", 30)
	right_margin.add_theme_constant_override("margin_right", 30)
	split_hbox.add_child(right_margin)
	
	content_label = RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_label.add_theme_color_override("default_color", Color.BLACK)
	content_label.text = "[color=#95a5a6]" + Locale.t("sop.select_article_long") + "[/color]"
	right_margin.add_child(content_label)

func _refresh_sop_tab_styles() -> void:
	for i: int in range(tab_btns.size()):
		var tb: Button = tab_btns[i]
		var is_active: bool = (i + 1 == active_tab)
		var tb_sb := StyleBoxFlat.new()
		tb_sb.bg_color = Color(0.0, 0.51, 0.76) if is_active else Color(0.15, 0.2, 0.28)
		tb_sb.set_corner_radius_all(4)
		tb.add_theme_stylebox_override("normal", tb_sb)

func _open_sop_modal() -> void:
	if _ui._session != null: _ui._session.call("set_pause_state", true)
	active_tab = 1
	_refresh_sop_tab_styles()
	search_input.text = ""
	content_label.text = "[color=#95a5a6]" + Locale.t("sop.select_article") + "[/color]"
	content_label.get_v_scroll_bar().value = 0
	_on_sop_search_changed("")
	overlay.visible = true

	if _ui.tutorial_active and _ui.tutorial_step == 12:
		_ui.tutorial_step = 13
		_ui._tut.update_ui()

func _close_sop_modal() -> void:
	if _ui._session != null: _ui._session.call("set_pause_state", false) 
	overlay.visible = false

func _on_sop_search_changed(query: String) -> void:
	for child in results_vbox.get_children():
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
		if not article.scenarios.has(_ui._current_scenario_index):
			continue

		var in_tab1: bool = article.title in tab1_titles
		var article_tab: int = 1 if in_tab1 else 2
		if article_tab != active_tab:
			continue

		var match_found: bool = false
		if q == "": match_found = true
		elif q in article.title.to_lower(): match_found = true
		else:
			for tag: String in article.tags:
				if q in tag.to_lower(): match_found = true

		if match_found:
			if article.get("new_in", -1) == _ui._current_scenario_index:
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
			content_label.text = art.content
			content_label.get_v_scroll_bar().value = 0
			WOTSAudio.play_panel_click(_ui)
		)
		results_vbox.add_child(btn)
		
	for a: Dictionary in new_arts: create_btn.call(a, true)
	for a: Dictionary in old_arts: create_btn.call(a, false)
