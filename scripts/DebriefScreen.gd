class_name DebriefScreen
extends RefCounted

# ==========================================
# DEBRIEF SCREEN — extracted from BayUI.gd
# Owns: debrief overlay, debrief text rendering
# ==========================================

var _ui: BayUI  # BayUI reference

var overlay: ColorRect
var lbl_text: RichTextLabel

var what_happened: String = ""
var why_it_mattered: String = ""
var total_weight_kg: float = 0.0
var total_dm3: int = 0
var combine_count: int = 0
var _mistakes: Dictionary = {}
var _loaded_order: Array[Dictionary] = []
var _ideal_order: Array[Dictionary] = []
var _time_breakdown: Dictionary = {}

# Replay record built from debrief payload + session context
var _replay_record: Dictionary = {}

# Mistake category → SOP article title mapping
const SOP_MAP: Dictionary = {
	"sequence_errors": "Loading: The Standard Sequence",
	"co_interleave_errors": "Co-Loading: Two Stores, One Truck",
	"rework_penalized": "Rework: When to Unload a Pallet",
	"cc_left_behind": "C&C (Click & Collect): What is it?",
	"cc_not_investigated": "C&C (Click & Collect): What is it?",
	"priority_left_behind": "Promise Dates: D, D-, D+",
	"transit_missed": "Transit Rack",
	"adr_missed": "ADR / Dangerous Goods",
	"as400_not_validated": "AS400: Login & Shortcuts",
	"paperwork_errors": "Paperwork: Three Documents, Three Moments",
}

func _init(ui: BayUI) -> void:
	_ui = ui

func _build(root: Node) -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(900, 700)
	UIStyles.apply_panel(pnl, UIStyles.modal(UITokens.CLR_PANEL_BG, 8, 0, 0.0))
	center.add_child(pnl)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 35)
	pnl.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	lbl_text = RichTextLabel.new()
	lbl_text.bbcode_enabled = true
	lbl_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_text.add_theme_color_override("default_color", UITokens.CLR_PALLET_BORDER)
	lbl_text.meta_clicked.connect(_on_meta_clicked)
	vbox.add_child(lbl_text)

	# --- Button row: Replay + Close ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_replay := Button.new()
	btn_replay.text = Locale.t("replay.watch")
	btn_replay.custom_minimum_size = Vector2(200, 48)
	btn_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_replay.add_theme_font_size_override("font_size", UITokens.fs(15))
	UIStyles.apply_btn_auto(btn_replay, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 6, 1, UITokens.CLR_SURFACE_MID)
	btn_replay.pressed.connect(func() -> void: _on_replay_pressed())
	btn_row.add_child(btn_replay)

	var btn_close := Button.new()
	btn_close.text = Locale.t("debrief.close")
	btn_close.custom_minimum_size = Vector2(280, 48)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.add_theme_font_size_override("font_size", UITokens.fs(15))
	UIStyles.apply_btn(btn_close,
			UITokens.CLR_SURFACE_DEEP, UITokens.COLOR_ACCENT_BLUE,
			UITokens.CLR_SURFACE_DEEP,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE,
			6, 1, UITokens.CLR_SURFACE_MID)
	btn_close.pressed.connect(func() -> void: _ui._on_debrief_closed())
	btn_row.add_child(btn_close)

func store_payload(payload: Dictionary) -> void:
	what_happened = str(payload.get("what_happened", ""))
	why_it_mattered = str(payload.get("why_it_mattered", ""))
	total_weight_kg = float(payload.get("total_weight_kg", 0.0))
	total_dm3 = int(payload.get("total_dm3", 0))
	combine_count = int(payload.get("combine_count", 0))
	_mistakes = payload.get("mistakes", {}) as Dictionary
	_loaded_order = []
	for item: Dictionary in (payload.get("loaded_order", []) as Array):
		_loaded_order.append(item)
	_ideal_order = []
	for item: Dictionary in (payload.get("ideal_order", []) as Array):
		_ideal_order.append(item)
	_time_breakdown = payload.get("time_breakdown", {}) as Dictionary

	# Build replay record from payload + current session context
	_replay_record = {
		"scenario": _ui._current_scenario_name,
		"score": int(payload.get("score", 0)),
		"passed": bool(payload.get("passed", false)),
		"time_seconds": _ui._session.total_time if _ui._session != null else 0.0,
		"seed": _ui._session.session_seed if _ui._session != null else 0,
		"action_log": payload.get("action_log", []),
	}

func render() -> void:
	var bb := "[center][font_size=28]" + UITokens.BB_ACCENT + "[b]" + Locale.t("debrief.title") + "[/b]" + UITokens.BB_END + "[/font_size][/center]\n\n"
	bb += "[center][font_size=16]" + UITokens.BB_META + Locale.t("debrief.truck_load") + " [b]%.0f kg[/b]  ·  [b]%d dm³[/b]" % [total_weight_kg, total_dm3]
	if combine_count > 0:
		bb += "  ·  " + UITokens.BB_SUCCESS + "[b]%d %s[/b]" % [combine_count, Locale.t("debrief.combines")] + UITokens.BB_END
	bb += UITokens.BB_END + "[/font_size][/center]\n\n"

	# --- Visual load comparison (Item 20) ---
	if not _loaded_order.is_empty():
		bb += _build_load_comparison()

	# --- Shift timeline bar (Item 21) ---
	if not _time_breakdown.is_empty():
		bb += _build_timeline_bar()

	bb += "[font_size=24][b]" + Locale.t("debrief.timeline") + "[/b][/font_size]\n"
	bb += what_happened + "\n"

	if _ui._as400.wrong_store_scans > 0:
		bb += "\n[font_size=18]" + UITokens.BB_WARNING + "• " + Locale.t("debrief.wrong_store") + UITokens.BB_END + "[/font_size] [font_size=16]" + (Locale.t("debrief.wrong_store_detail") % _ui._as400.wrong_store_scans) + "[/font_size]\n"

	if _ui._session != null:
		var had_transit: bool = (_ui._session.transit_items.size() > 0 or _ui._session.transit_loose_entries.size() > 0 or _ui._session.transit_collected)
		if had_transit and not _ui._session.transit_collected:
			bb += "\n[font_size=18]" + UITokens.BB_WARNING + "• " + Locale.t("debrief.transit_not_checked") + UITokens.BB_END + "[/font_size] [font_size=16]" + Locale.t("debrief.transit_detail") + "[/font_size]\n"
		if _ui._session.has_adr and not _ui._session.adr_collected:
			bb += "\n[font_size=18]" + UITokens.BB_ERROR + "• " + Locale.t("debrief.adr_not_collected") + UITokens.BB_END + "[/font_size] [font_size=16]" + Locale.t("debrief.adr_detail") + "[/font_size]\n"

	if why_it_mattered.strip_edges() != "":
		bb += "\n[font_size=24][b]" + Locale.t("debrief.review") + "[/b][/font_size]\n"
		bb += why_it_mattered + "\n"

	# --- Recommended SOP reading based on mistakes ---
	var sop_titles: Array[String] = _get_relevant_sops()
	if not sop_titles.is_empty():
		bb += "\n[font_size=20][b]" + Locale.t("debrief.recommended_reading") + "[/b][/font_size]\n"
		for sop_title: String in sop_titles:
			bb += UITokens.BB_ACCENT + "[url=sop:" + sop_title + "]→ " + sop_title + "[/url]" + UITokens.BB_END + "\n"

	if lbl_text != null: lbl_text.text = bb
	if overlay != null: overlay.visible = true


func _get_relevant_sops() -> Array[String]:
	## Returns deduplicated list of SOP article titles relevant to the session's mistakes.
	var titles: Array[String] = []
	for key: String in SOP_MAP:
		var val: Variant = _mistakes.get(key, null)
		if val == null:
			continue
		var triggered: bool = false
		if val is bool:
			triggered = val as bool
		elif val is int:
			triggered = (val as int) > 0
		elif val is float:
			triggered = (val as float) > 0.0
		if triggered and SOP_MAP[key] not in titles:
			titles.append(SOP_MAP[key] as String)
	return titles


func _on_meta_clicked(meta: Variant) -> void:
	var meta_str: String = str(meta)
	if meta_str.begins_with("sop:"):
		var sop_title: String = meta_str.substr(4)
		_ui._sop.open_to_article(sop_title)


func _on_replay_pressed() -> void:
	if _replay_record.is_empty():
		return
	if overlay != null:
		overlay.visible = false
	_ui._replay.start_replay(_replay_record)


# ==========================================
# VISUAL LOAD COMPARISON (Item 20)
# ==========================================

func _build_load_comparison() -> String:
	## Renders two truck cross-sections: actual load vs ideal load.
	## Each pallet is a colored type abbreviation showing load position.
	var bb: String = ""

	# Check if actual matches ideal (no comparison needed)
	var is_identical: bool = _orders_match(_loaded_order, _ideal_order)
	if is_identical:
		bb += "[font_size=14]" + UITokens.BB_SUCCESS + "✓ " + Locale.t("debrief.load_match") + UITokens.BB_END + "[/font_size]\n\n"
		return bb

	bb += "[font_size=16][b]" + Locale.t("debrief.load_comparison") + "[/b][/font_size]\n"

	# Your truck
	bb += "[font_size=13]" + UITokens.BB_HINT + Locale.t("debrief.your_truck") + UITokens.BB_END + "[/font_size]\n"
	bb += _render_truck_row(_loaded_order) + "\n"

	# Ideal truck
	bb += "[font_size=13]" + UITokens.BB_HINT + Locale.t("debrief.ideal_truck") + UITokens.BB_END + "[/font_size]\n"
	bb += _render_truck_row(_ideal_order) + "\n"

	# Legend
	bb += "[font_size=11]" + UITokens.BB_DIM
	bb += "SC=ServiceCenter  BK=Bikes  BU=Bulky  ME=Mecha  AD=ADR  CC=C&C"
	bb += UITokens.BB_END + "[/font_size]\n\n"
	return bb


func _render_truck_row(order: Array[Dictionary]) -> String:
	## Renders a single truck as a row of colored type abbreviations.
	## Format: [1:SC] [2:BK] [3:BU] ... with type-specific colors.
	var bb: String = "[font_size=12]"
	for i: int in range(order.size()):
		var entry: Dictionary = order[i]
		var ptype: String = str(entry.get("type", ""))
		var abbr: String = _type_abbr(ptype)
		var clr: String = _type_bb_color(ptype)
		bb += clr + "[" + str(i + 1) + ":" + abbr + "]" + UITokens.BB_END + " "
	bb += "[/font_size]"
	return bb


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


func _orders_match(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if str(a[i].get("type", "")) != str(b[i].get("type", "")):
			return false
	return true


# ==========================================
# SHIFT TIMELINE BAR (Item 21)
# ==========================================

const TIMELINE_CATEGORIES: Array[String] = [
	"office", "as400", "loading", "rework", "emballage",
	"call_depts", "transit", "adr", "combine", "interruption", "dock_wait"
]

const TIMELINE_LABELS: Dictionary = {
	"office": "Office",
	"as400": "AS400",
	"loading": "Loading",
	"rework": "Rework",
	"emballage": "Emballage",
	"call_depts": "Call Depts",
	"transit": "Transit",
	"adr": "ADR",
	"combine": "Combine",
	"interruption": "Interruption",
	"dock_wait": "Dock Wait",
}

const TIMELINE_COLORS: Dictionary = {
	"office": "#3498db",
	"as400": "#9b59b6",
	"loading": "#2ecc71",
	"rework": "#e74c3c",
	"emballage": "#f1c40f",
	"call_depts": "#e67e22",
	"transit": "#00bcd4",
	"adr": "#ff4444",
	"combine": "#1abc9c",
	"interruption": "#e056a0",
	"dock_wait": "#7f8c8d",
}

func _build_timeline_bar() -> String:
	## Renders a horizontal bar showing time allocation by category,
	## with a legend row beneath it.
	var grand_total: float = 0.0
	for cat: String in TIMELINE_CATEGORIES:
		grand_total += float(_time_breakdown.get(cat, 0.0))
	if grand_total < 1.0:
		return ""

	var bb: String = ""
	bb += "[font_size=16][b]" + Locale.t("debrief.time_allocation") + "[/b][/font_size]\n"

	# Render the bar using block characters, scaled to ~50 characters wide
	var bar_width: int = 50
	bb += "[font_size=14]"
	for cat: String in TIMELINE_CATEGORIES:
		var secs: float = float(_time_breakdown.get(cat, 0.0))
		if secs < 1.0:
			continue
		var segment_len: int = maxi(1, int((secs / grand_total) * float(bar_width)))
		var clr: String = "[color=" + str(TIMELINE_COLORS.get(cat, "#7f8c8d")) + "]"
		var block: String = ""
		for _j: int in range(segment_len):
			block += "█"
		bb += clr + block + UITokens.BB_END
	bb += "[/font_size]\n"

	# Legend: category labels with time
	bb += "[font_size=12]"
	for cat: String in TIMELINE_CATEGORIES:
		var secs: float = float(_time_breakdown.get(cat, 0.0))
		if secs < 1.0:
			continue
		@warning_ignore("integer_division")
		var m: int = int(secs) / 60
		var s: int = int(secs) % 60
		var pct: int = int((secs / grand_total) * 100.0)
		var clr: String = "[color=" + str(TIMELINE_COLORS.get(cat, "#7f8c8d")) + "]"
		var label: String = str(TIMELINE_LABELS.get(cat, cat))
		bb += clr + "■" + UITokens.BB_END + " "
		bb += UITokens.BB_DIM + label + " " + str(m) + ":" + "%02d" % s
		bb += " (" + str(pct) + "%)" + UITokens.BB_END + "  "
	bb += "[/font_size]\n\n"
	return bb
