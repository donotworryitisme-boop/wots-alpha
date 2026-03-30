class_name DebriefScreen
extends RefCounted

# ==========================================
# DEBRIEF SCREEN — extracted from BayUI.gd
# Owns: debrief overlay, debrief text rendering
# ==========================================

var _ui: Node  # BayUI reference

var overlay: ColorRect
var lbl_text: RichTextLabel

var what_happened: String = ""
var why_it_mattered: String = ""
var total_weight_kg: float = 0.0
var total_dm3: int = 0
var combine_count: int = 0

func _init(ui: Node) -> void:
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_top = 3
	sb.border_color = Color(0.0, 0.51, 0.76)
	pnl.add_theme_stylebox_override("panel", sb)
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
	lbl_text.add_theme_color_override("default_color", Color(0.8, 0.82, 0.85))
	vbox.add_child(lbl_text)

	var btn_close := Button.new()
	btn_close.text = Locale.t("debrief.close")
	btn_close.custom_minimum_size = Vector2(280, 48)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_font_size_override("font_size", 15)
	var dcb_n := StyleBoxFlat.new()
	dcb_n.bg_color = Color(0.18, 0.19, 0.22)
	dcb_n.corner_radius_top_left = 6
	dcb_n.corner_radius_top_right = 6
	dcb_n.corner_radius_bottom_left = 6
	dcb_n.corner_radius_bottom_right = 6
	dcb_n.border_width_left = 1
	dcb_n.border_width_top = 1
	dcb_n.border_width_right = 1
	dcb_n.border_width_bottom = 1
	dcb_n.border_color = Color(0.3, 0.32, 0.35)
	btn_close.add_theme_stylebox_override("normal", dcb_n)
	var dcb_h := dcb_n.duplicate()
	dcb_h.bg_color = Color(0.0, 0.51, 0.76)
	dcb_h.border_color = Color(0.0, 0.51, 0.76)
	btn_close.add_theme_stylebox_override("hover", dcb_h)
	btn_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_close.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	btn_close.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_close.pressed.connect(func() -> void: _ui._on_debrief_closed())
	vbox.add_child(btn_close)

func store_payload(payload: Dictionary) -> void:
	what_happened = str(payload.get("what_happened", ""))
	why_it_mattered = str(payload.get("why_it_mattered", ""))
	total_weight_kg = float(payload.get("total_weight_kg", 0.0))
	total_dm3 = int(payload.get("total_dm3", 0))
	combine_count = int(payload.get("combine_count", 0))

func render() -> void:
	var bb := "[center][font_size=28][color=#0082c3][b]" + Locale.t("debrief.title") + "[/b][/color][/font_size][/center]\n\n"
	bb += "[center][font_size=16][color=#7f8fa6]" + Locale.t("debrief.truck_load") + " [b]%.0f kg[/b]  ·  [b]%d dm³[/b]" % [total_weight_kg, total_dm3]
	if combine_count > 0:
		bb += "  ·  [color=#2ecc71][b]%d %s[/b][/color]" % [combine_count, Locale.t("debrief.combines")]
	bb += "[/color][/font_size][/center]\n\n"
	bb += "[font_size=24][b]" + Locale.t("debrief.timeline") + "[/b][/font_size]\n"
	bb += what_happened + "\n"

	if _ui._as400.wrong_store_scans > 0:
		bb += "\n[font_size=18][color=#f1c40f]• " + Locale.t("debrief.wrong_store") + "[/color][/font_size] [font_size=16]" + (Locale.t("debrief.wrong_store_detail") % _ui._as400.wrong_store_scans) + "[/font_size]\n"

	if _ui._session != null:
		var had_transit: bool = (_ui._session.transit_items.size() > 0 or _ui._session.transit_loose_entries.size() > 0 or _ui._session.transit_collected)
		if had_transit and not _ui._session.transit_collected:
			bb += "\n[font_size=18][color=#f1c40f]• " + Locale.t("debrief.transit_not_checked") + "[/color][/font_size] [font_size=16]" + Locale.t("debrief.transit_detail") + "[/font_size]\n"
		if _ui._session.has_adr and not _ui._session.adr_collected:
			bb += "\n[font_size=18][color=#e74c3c]• " + Locale.t("debrief.adr_not_collected") + "[/color][/font_size] [font_size=16]" + Locale.t("debrief.adr_detail") + "[/font_size]\n"

	if why_it_mattered.strip_edges() != "":
		bb += "\n[font_size=24][b]" + Locale.t("debrief.review") + "[/b][/font_size]\n"
		bb += why_it_mattered + "\n"

	if lbl_text != null: lbl_text.text = bb
	if overlay != null: overlay.visible = true
