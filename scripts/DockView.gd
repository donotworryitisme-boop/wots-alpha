class_name DockView
extends RefCounted

# ==========================================
# DOCK VIEW — extracted from BayUI.gd
# Owns: dock floor, lanes, signs, truck, scanner panel, pallet drawing
# ==========================================

var _ui: Node  # BayUI reference

# Dock panel
var panel: PanelContainer

# Lane containers
var dock_signs_hbox: HBoxContainer
var dock_lanes_hbox: HBoxContainer
var dock_floor_labels_hbox: HBoxContainer
var dock_inner_vbox_ref: VBoxContainer
var co_lanes: Dictionary = {}
var lane_m1: VBoxContainer
var lane_m2: VBoxContainer
var lane_b: VBoxContainer
var lane_misc: VBoxContainer

# Truck
var truck_grid: GridContainer
var truck_cap_label: RichTextLabel
var truck_cap_bar: ColorRect

# Scanner
var lbl_hover_info: RichTextLabel
var _hover_tween: Tween = null

func _init(ui: Node) -> void:
	_ui = ui

func _build(stage_hbox: HBoxContainer) -> void:
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.visible = false
	var stage_sb := StyleBoxFlat.new()
	stage_sb.bg_color = Color(0.22, 0.23, 0.24)
	panel.add_theme_stylebox_override("panel", stage_sb)
	stage_hbox.add_child(panel)

	var dock_margin := MarginContainer.new()
	dock_margin.add_theme_constant_override("margin_left", 10)
	dock_margin.add_theme_constant_override("margin_top", 8)
	dock_margin.add_theme_constant_override("margin_right", 10)
	dock_margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(dock_margin)

	var dock_vbox := VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 6)
	dock_margin.add_child(dock_vbox)

	# --- MAIN FLOOR AREA ---
	var floor_split := HBoxContainer.new()
	floor_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	floor_split.add_theme_constant_override("separation", 0)
	dock_vbox.add_child(floor_split)

	# === DOCK LANES (concrete floor) ===
	var dock_lanes_bg := PanelContainer.new()
	dock_lanes_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_lanes_bg.size_flags_stretch_ratio = 2.2
	var sb_dock := StyleBoxFlat.new()
	sb_dock.bg_color = Color(0.62, 0.63, 0.61)
	sb_dock.border_width_bottom = 3
	sb_dock.border_color = Color(0.85, 0.65, 0.0)
	dock_lanes_bg.add_theme_stylebox_override("panel", sb_dock)
	floor_split.add_child(dock_lanes_bg)

	var dock_inner_margin := MarginContainer.new()
	dock_inner_margin.add_theme_constant_override("margin_left", 8)
	dock_inner_margin.add_theme_constant_override("margin_top", 0)
	dock_inner_margin.add_theme_constant_override("margin_bottom", 0)
	dock_inner_margin.add_theme_constant_override("margin_right", 8)
	dock_lanes_bg.add_child(dock_inner_margin)

	var dock_inner_vbox := VBoxContainer.new()
	dock_inner_vbox.add_theme_constant_override("separation", 0)
	dock_inner_margin.add_child(dock_inner_vbox)

	# --- OVERHEAD SIGNS ---
	var signs_hbox := HBoxContainer.new()
	signs_hbox.add_theme_constant_override("separation", 6)
	dock_inner_vbox.add_child(signs_hbox)
	dock_signs_hbox = signs_hbox
	dock_inner_vbox_ref = dock_inner_vbox

	var sign_data: Array = [
		{"label": "MECHA 1", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
		{"label": "MECHA 2", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
		{"label": "BULKY", "sub": "TRANSIT", "color": Color(0.9, 0.5, 0.15)},
		{"label": "BIKES / C&C / SC", "sub": "MIXED", "color": Color(0.2, 0.7, 0.35)}
	]
	for sd: Dictionary in sign_data:
		_add_sign(signs_hbox, sd)

	# --- LANE COLUMNS ---
	var lanes_hbox := HBoxContainer.new()
	lanes_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes_hbox.add_theme_constant_override("separation", 0)
	dock_inner_vbox.add_child(lanes_hbox)
	dock_lanes_hbox = lanes_hbox

	lane_m1 = VBoxContainer.new(); lane_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m1.alignment = BoxContainer.ALIGNMENT_END; lane_m1.add_theme_constant_override("separation", 4)
	lane_m2 = VBoxContainer.new(); lane_m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m2.alignment = BoxContainer.ALIGNMENT_END; lane_m2.add_theme_constant_override("separation", 4)
	lane_b = VBoxContainer.new(); lane_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_b.alignment = BoxContainer.ALIGNMENT_END; lane_b.add_theme_constant_override("separation", 4)
	lane_misc = VBoxContainer.new(); lane_misc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_misc.alignment = BoxContainer.ALIGNMENT_END; lane_misc.add_theme_constant_override("separation", 4)

	lanes_hbox.add_child(lane_m1)
	lanes_hbox.add_child(_make_divider())
	lanes_hbox.add_child(lane_m2)
	lanes_hbox.add_child(_make_divider())
	lanes_hbox.add_child(lane_b)
	lanes_hbox.add_child(_make_divider())
	lanes_hbox.add_child(lane_misc)

	# --- ORANGE FLOOR LABELS ---
	var floor_labels_hbox := HBoxContainer.new()
	floor_labels_hbox.add_theme_constant_override("separation", 6)
	dock_inner_vbox.add_child(floor_labels_hbox)
	dock_floor_labels_hbox = floor_labels_hbox

	var floor_label_texts: Array[String] = ["MECHA 1", "MECHA 2", "BULKY", "BIKES/C&C"]
	for flt: String in floor_label_texts:
		_add_floor_label(floor_labels_hbox, flt)

	# === TRUCK (door frame) ===
	var truck_outer := PanelContainer.new()
	truck_outer.custom_minimum_size = Vector2(195, 0)
	var truck_frame_sb := StyleBoxFlat.new()
	truck_frame_sb.bg_color = Color(0.35, 0.36, 0.38)
	truck_frame_sb.border_width_left = 5; truck_frame_sb.border_width_right = 5
	truck_frame_sb.border_width_top = 5; truck_frame_sb.border_width_bottom = 0
	truck_frame_sb.border_color = Color(0.55, 0.56, 0.58)
	truck_frame_sb.corner_radius_top_left = 4; truck_frame_sb.corner_radius_top_right = 4
	truck_outer.add_theme_stylebox_override("panel", truck_frame_sb)
	floor_split.add_child(truck_outer)

	var truck_inner := PanelContainer.new()
	truck_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var truck_inner_sb := StyleBoxFlat.new()
	truck_inner_sb.bg_color = Color(0.12, 0.12, 0.14)
	truck_inner_sb.corner_radius_top_left = 2; truck_inner_sb.corner_radius_top_right = 2
	truck_outer.add_child(truck_inner)

	var truck_vbox := VBoxContainer.new()
	truck_vbox.add_theme_constant_override("separation", 4)
	truck_inner.add_child(truck_vbox)

	var truck_header := Label.new()
	truck_header.text = Locale.t("dock.trailer")
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

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.color = Color(0.2, 0.2, 0.22)
	truck_vbox.add_child(bar_bg)
	truck_cap_bar = ColorRect.new()
	truck_cap_bar.custom_minimum_size = Vector2(0, 6)
	truck_cap_bar.color = Color(0.18, 0.8, 0.44)
	bar_bg.add_child(truck_cap_bar)

	truck_grid = GridContainer.new()
	truck_grid.columns = 3
	truck_grid.add_theme_constant_override("h_separation", 3)
	truck_grid.add_theme_constant_override("v_separation", 3)
	truck_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	truck_vbox.add_child(truck_grid)

	var lifo_lbl := Label.new()
	lifo_lbl.text = Locale.t("dock.unload_first")
	lifo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lifo_lbl.add_theme_font_size_override("font_size", 10)
	lifo_lbl.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
	truck_vbox.add_child(lifo_lbl)

	var truck_spacer := Control.new()
	truck_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	truck_vbox.add_child(truck_spacer)

	# === SCANNER PANEL (bottom) ===
	var scanner_bg := PanelContainer.new()
	scanner_bg.custom_minimum_size = Vector2(0, 100)
	scanner_bg.size_flags_vertical = Control.SIZE_SHRINK_END
	var scanner_sb := StyleBoxFlat.new()
	scanner_sb.bg_color = Color(0.06, 0.07, 0.08)
	scanner_sb.border_width_top = 2
	scanner_sb.border_color = Color(0.0, 0.51, 0.76)
	scanner_bg.add_theme_stylebox_override("panel", scanner_sb)
	dock_vbox.add_child(scanner_bg)

	var scanner_margin := MarginContainer.new()
	scanner_margin.add_theme_constant_override("margin_left", 16)
	scanner_margin.add_theme_constant_override("margin_top", 10)
	scanner_margin.add_theme_constant_override("margin_right", 16)
	scanner_margin.add_theme_constant_override("margin_bottom", 10)
	scanner_bg.add_child(scanner_margin)

	lbl_hover_info = RichTextLabel.new()
	lbl_hover_info.bbcode_enabled = true
	lbl_hover_info.custom_minimum_size = Vector2(0, 120)
	lbl_hover_info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lbl_hover_info.scroll_active = false
	lbl_hover_info.text = "[font_size=15][color=#7a8a9a]" + Locale.t("dock.hover_scan") + "[/color][/font_size]"
	scanner_margin.add_child(lbl_hover_info)

# ==========================================
# DOCK LANE REBUILD
# ==========================================
func rebuild_lanes(is_coload: bool) -> void:
	if dock_signs_hbox == null: return
	for c in dock_signs_hbox.get_children(): c.queue_free()
	for c in dock_lanes_hbox.get_children(): c.queue_free()
	for c in dock_floor_labels_hbox.get_children(): c.queue_free()
	co_lanes.clear()

	if is_coload:
		var sign_data: Array = [
			{"label": _ui.current_dest_name, "sub": "MECHA", "color": Color(0.94, 0.76, 0.2)},
			{"label": _ui.current_dest_name, "sub": "BULKY", "color": Color(0.94, 0.76, 0.2)},
			{"label": _ui.current_dest_name, "sub": "MISC", "color": Color(0.94, 0.76, 0.2)},
			{"label": _ui.current_dest2_name, "sub": "MECHA", "color": Color(0.9, 0.45, 0.15)},
			{"label": _ui.current_dest2_name, "sub": "BULKY", "color": Color(0.9, 0.45, 0.15)},
			{"label": _ui.current_dest2_name, "sub": "MISC", "color": Color(0.9, 0.45, 0.15)},
		]
		var lane_keys: Array[String] = ["s1_mecha", "s1_bulky", "s1_misc", "s2_mecha", "s2_bulky", "s2_misc"]
		var floor_texts: Array[String] = ["S1 MECHA", "S1 BULKY", "S1 MISC", "S2 MECHA", "S2 BULKY", "S2 MISC"]
		for i: int in range(6):
			_add_sign(dock_signs_hbox, sign_data[i])
			var lane := VBoxContainer.new()
			lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lane.alignment = BoxContainer.ALIGNMENT_END
			lane.add_theme_constant_override("separation", 4)
			co_lanes[lane_keys[i]] = lane
			dock_lanes_hbox.add_child(lane)
			if i == 2:
				dock_lanes_hbox.add_child(_make_thick_divider())
			elif i < 5:
				dock_lanes_hbox.add_child(_make_divider())
			_add_floor_label(dock_floor_labels_hbox, floor_texts[i])
	else:
		var std_sign_data: Array = [
			{"label": "MECHA 1", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
			{"label": "MECHA 2", "sub": "BLUE BOXES", "color": Color(0.2, 0.5, 0.8)},
			{"label": "BULKY", "sub": "TRANSIT", "color": Color(0.9, 0.5, 0.15)},
			{"label": "BIKES / C&C / SC", "sub": "MIXED", "color": Color(0.2, 0.7, 0.35)}
		]
		for sd: Dictionary in std_sign_data:
			_add_sign(dock_signs_hbox, sd)
		lane_m1 = VBoxContainer.new(); lane_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m1.alignment = BoxContainer.ALIGNMENT_END; lane_m1.add_theme_constant_override("separation", 4)
		lane_m2 = VBoxContainer.new(); lane_m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_m2.alignment = BoxContainer.ALIGNMENT_END; lane_m2.add_theme_constant_override("separation", 4)
		lane_b = VBoxContainer.new(); lane_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_b.alignment = BoxContainer.ALIGNMENT_END; lane_b.add_theme_constant_override("separation", 4)
		lane_misc = VBoxContainer.new(); lane_misc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lane_misc.alignment = BoxContainer.ALIGNMENT_END; lane_misc.add_theme_constant_override("separation", 4)
		dock_lanes_hbox.add_child(lane_m1)
		dock_lanes_hbox.add_child(_make_divider())
		dock_lanes_hbox.add_child(lane_m2)
		dock_lanes_hbox.add_child(_make_divider())
		dock_lanes_hbox.add_child(lane_b)
		dock_lanes_hbox.add_child(_make_divider())
		dock_lanes_hbox.add_child(lane_misc)
		var std_floor_texts: Array[String] = ["MECHA 1", "MECHA 2", "BULKY", "BIKES/C&C"]
		for ft: String in std_floor_texts:
			_add_floor_label(dock_floor_labels_hbox, ft)

# ==========================================
# POPULATE LANES + TRUCK (called from BayUI._on_inventory_updated)
# ==========================================
func populate(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	# --- Capacity label + bar ---
	if truck_cap_label != null:
		var pct: float = cap_used / cap_max if cap_max > 0 else 0.0
		var color_hex: String = "#8fa6bf"
		if pct > 0.85: color_hex = "#e74c3c"
		elif pct > 0.6: color_hex = "#f1c40f"
		truck_cap_label.text = "[center][color=%s][b]%0.0f / %0.0f[/b][/color][/center]" % [color_hex, cap_used, cap_max]
		if truck_cap_bar != null and truck_cap_bar.get_parent() != null:
			var parent_w: float = truck_cap_bar.get_parent().size.x
			if parent_w > 0:
				truck_cap_bar.custom_minimum_size.x = parent_w * pct
			if pct > 0.85: truck_cap_bar.color = Color(0.9, 0.3, 0.25)
			elif pct > 0.6: truck_cap_bar.color = Color(0.94, 0.76, 0.2)
			else: truck_cap_bar.color = Color(0.18, 0.8, 0.44)

	# --- CLEAR AND POPULATE DOCK LANES ---
	var is_coload: bool = (_ui._current_scenario_index == 3)
	var MAX_PER_LANE: int = 10
	var buffer_height: int = 10

	if is_coload:
		var all_co_lanes: Array = co_lanes.values()
		for lane: VBoxContainer in all_co_lanes:
			for child in lane.get_children(): child.queue_free()
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, buffer_height)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lane.add_child(spacer)
		var lane_counts: Dictionary = {}
		for key: String in co_lanes: lane_counts[key] = 0
		for p: Dictionary in avail:
			if p.missing: continue
			var dest: int = p.get("dest", 1)
			var prefix: String = "s1_" if dest == 1 else "s2_"
			var lane_key: String = ""
			if p.type == "Mecha": lane_key = prefix + "mecha"
			elif p.type == "Bulky": lane_key = prefix + "bulky"
			else: lane_key = prefix + "misc"
			if not co_lanes.has(lane_key): continue
			if lane_counts[lane_key] >= MAX_PER_LANE: continue
			var lane: VBoxContainer = co_lanes[lane_key]
			_draw_pallet(p, lane)
			lane.move_child(lane.get_child(lane.get_child_count() - 1), 0)
			lane_counts[lane_key] += 1
	else:
		for child in lane_m1.get_children(): child.queue_free()
		for child in lane_m2.get_children(): child.queue_free()
		for child in lane_b.get_children(): child.queue_free()
		for child in lane_misc.get_children(): child.queue_free()
		for lane: VBoxContainer in [lane_m1, lane_m2, lane_b, lane_misc]:
			var lane_spacer := Control.new()
			lane_spacer.custom_minimum_size = Vector2(0, buffer_height)
			lane_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lane.add_child(lane_spacer)
		var allow_overflow: bool = (_ui._current_scenario_index >= 2)
		var std_lane_counts: Dictionary = {lane_m1: 0, lane_m2: 0, lane_b: 0, lane_misc: 0}
		var all_lanes: Array = [lane_m1, lane_m2, lane_b, lane_misc]
		var mecha_count: int = 0
		for p: Dictionary in avail:
			if p.missing: continue
			var preferred_row: VBoxContainer = lane_misc
			if p.type == "Mecha":
				if mecha_count % 2 == 0: preferred_row = lane_m1
				else: preferred_row = lane_m2
				mecha_count += 1
			elif p.type == "Bulky": preferred_row = lane_b
			var row: VBoxContainer = preferred_row
			if std_lane_counts[row] >= MAX_PER_LANE:
				if allow_overflow:
					row = lane_misc  # fallback
					var best_space: int = -1
					for candidate: VBoxContainer in all_lanes:
						var space: int = MAX_PER_LANE - std_lane_counts[candidate]
						if space > best_space:
							best_space = space
							row = candidate
					if std_lane_counts[row] >= MAX_PER_LANE:
						continue
				else:
					continue
			_draw_pallet(p, row)
			row.move_child(row.get_child(row.get_child_count() - 1), 0)
			std_lane_counts[row] += 1

	_update_truck_visualizer(loaded)

# ==========================================
# HELPERS
# ==========================================
func _make_divider() -> ColorRect:
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(2, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	div.color = Color(1, 1, 1, 0.3)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return div

func _make_thick_divider() -> ColorRect:
	var tdiv := ColorRect.new()
	tdiv.custom_minimum_size = Vector2(4, 0)
	tdiv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tdiv.color = Color(0.9, 0.55, 0.1, 0.7)
	tdiv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tdiv

func _add_sign(parent: HBoxContainer, sd: Dictionary) -> void:
	var sign_panel := PanelContainer.new()
	sign_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sign_sb := StyleBoxFlat.new()
	sign_sb.bg_color = Color(0.1, 0.1, 0.12)
	sign_sb.border_width_top = 3
	sign_sb.border_color = sd.color
	sign_sb.corner_radius_bottom_left = 2
	sign_sb.corner_radius_bottom_right = 2
	sign_panel.add_theme_stylebox_override("panel", sign_sb)
	parent.add_child(sign_panel)
	var sign_margin := MarginContainer.new()
	sign_margin.add_theme_constant_override("margin_left", 4)
	sign_margin.add_theme_constant_override("margin_top", 4)
	sign_margin.add_theme_constant_override("margin_right", 4)
	sign_margin.add_theme_constant_override("margin_bottom", 4)
	sign_panel.add_child(sign_margin)
	var sign_vbox := VBoxContainer.new()
	sign_vbox.add_theme_constant_override("separation", 0)
	sign_margin.add_child(sign_vbox)
	var sign_lbl := Label.new()
	sign_lbl.text = sd.label
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.add_theme_font_size_override("font_size", 11)
	sign_lbl.add_theme_color_override("font_color", Color.WHITE)
	sign_vbox.add_child(sign_lbl)
	var sign_sub := Label.new()
	sign_sub.text = sd.sub
	sign_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_sub.add_theme_font_size_override("font_size", 9)
	sign_sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	sign_vbox.add_child(sign_sub)

func _add_floor_label(parent: HBoxContainer, text: String) -> void:
	var fl_panel := PanelContainer.new()
	fl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fl_sb := StyleBoxFlat.new()
	fl_sb.bg_color = Color(0.9, 0.55, 0.1)
	fl_sb.corner_radius_top_left = 2; fl_sb.corner_radius_top_right = 2
	fl_sb.corner_radius_bottom_left = 2; fl_sb.corner_radius_bottom_right = 2
	fl_panel.add_theme_stylebox_override("panel", fl_sb)
	parent.add_child(fl_panel)
	var fl_lbl := Label.new()
	fl_lbl.text = text
	fl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl_lbl.add_theme_font_size_override("font_size", 10)
	fl_lbl.add_theme_color_override("font_color", Color.WHITE)
	var fl_m := MarginContainer.new()
	fl_m.add_theme_constant_override("margin_top", 2)
	fl_m.add_theme_constant_override("margin_bottom", 2)
	fl_m.add_child(fl_lbl)
	fl_panel.add_child(fl_m)

func get_type_color(p_type: String) -> Color:
	if p_type == "C&C": return Color(1.0, 1.0, 1.0)
	if p_type == "Bikes": return Color(0.2, 0.7, 0.3)
	if p_type == "Bulky": return Color(0.9, 0.5, 0.1)
	if p_type == "Mecha": return Color(0.0, 0.51, 0.76)
	if p_type == "ServiceCenter": return Color(0.8, 0.8, 0.1)
	if p_type == "ADR": return Color(0.9, 0.15, 0.15)
	return Color(0.5, 0.5, 0.5)

func _hover_default_text() -> String:
	return "[font_size=15][color=#7a8a9a]" + Locale.t("dock.hover_scan") + "[/color][/font_size]"

func _set_hover_text(new_text: String) -> void:
	if lbl_hover_info == null: return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	# Instant swap — no fade out. Avoids stuck alpha on fast mouse movement.
	lbl_hover_info.modulate.a = 0.0
	lbl_hover_info.text = new_text
	_hover_tween = _ui.create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_SINE)
	_hover_tween.tween_property(lbl_hover_info, "modulate:a", 1.0, 0.22)

# ==========================================
# TOP-DOWN PALLET GENERATOR
# ==========================================
func _build_pallet_graphic(color: Color, is_truck: bool, p_type: String = "") -> Button:
	var btn := Button.new()
	var p_size: int = 45 if is_truck else 52
	btn.custom_minimum_size = Vector2(p_size, p_size)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	var is_plastic: bool = (p_type == "Mecha" or p_type == "C&C" or p_type == "ADR")
	var base_bg := ColorRect.new()
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(base_bg)
	if is_plastic:
		base_bg.color = Color(0.15, 0.15, 0.17)
		var grid_h := VBoxContainer.new()
		grid_h.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid_h.add_theme_constant_override("separation", 0)
		grid_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_bg.add_child(grid_h)
		for i: int in range(3):
			var row := ColorRect.new()
			row.color = Color(0.2, 0.2, 0.22) if i % 2 == 0 else Color(0.15, 0.15, 0.17)
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_h.add_child(row)
	else:
		base_bg.color = Color(0.65, 0.45, 0.25)
		var planks := HBoxContainer.new()
		planks.set_anchors_preset(Control.PRESET_FULL_RECT)
		planks.add_theme_constant_override("separation", 3)
		planks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_bg.add_child(planks)
		for i: int in range(3):
			var plank := ColorRect.new()
			plank.color = Color(0.78, 0.58, 0.38) if i % 2 == 0 else Color(0.7, 0.5, 0.32)
			plank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			planks.add_child(plank)
	var inset: int = 5 if is_truck else 7
	var cargo_margin := MarginContainer.new()
	cargo_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	cargo_margin.add_theme_constant_override("margin_left", inset)
	cargo_margin.add_theme_constant_override("margin_top", inset)
	cargo_margin.add_theme_constant_override("margin_right", inset)
	cargo_margin.add_theme_constant_override("margin_bottom", inset)
	cargo_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cargo_margin)
	var cargo_box := ColorRect.new()
	cargo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo_margin.add_child(cargo_box)
	if p_type == "Mecha":
		cargo_box.color = Color(0.15, 0.45, 0.75)
		var mid_line := ColorRect.new()
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
		var tape_h := ColorRect.new()
		tape_h.color = Color(0.65, 0.5, 0.28)
		tape_h.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		tape_h.offset_top = -1; tape_h.offset_bottom = 1
		tape_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(tape_h)
		var tape_v := ColorRect.new()
		tape_v.color = Color(0.65, 0.5, 0.28)
		tape_v.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
		tape_v.offset_left = -1; tape_v.offset_right = 1
		tape_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(tape_v)
	elif p_type == "Bikes":
		cargo_box.color = Color(0.28, 0.62, 0.35)
		var box_line1 := ColorRect.new()
		box_line1.color = Color(0.22, 0.52, 0.28)
		box_line1.set_anchors_preset(Control.PRESET_TOP_WIDE)
		box_line1.custom_minimum_size = Vector2(0, 1)
		box_line1.offset_top = (p_size - inset * 2) * 0.33
		box_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(box_line1)
		var box_line2 := ColorRect.new()
		box_line2.color = Color(0.22, 0.52, 0.28)
		box_line2.set_anchors_preset(Control.PRESET_TOP_WIDE)
		box_line2.custom_minimum_size = Vector2(0, 1)
		box_line2.offset_top = (p_size - inset * 2) * 0.66
		box_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(box_line2)
	elif p_type == "C&C":
		cargo_box.color = Color(0.92, 0.92, 0.92)
		var cc_dot := ColorRect.new()
		cc_dot.color = Color(0.7, 0.7, 0.7)
		cc_dot.custom_minimum_size = Vector2(6, 6)
		cc_dot.set_anchors_preset(Control.PRESET_CENTER)
		cc_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cargo_box.add_child(cc_dot)
	elif p_type == "ServiceCenter":
		cargo_box.color = Color(0.88, 0.82, 0.2)
	else:
		cargo_box.color = color.lerp(Color.WHITE, 0.15)
	var border := ReferenceRect.new()
	border.border_color = color.darkened(0.35)
	border.border_width = 2
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo_box.add_child(border)
	var glow := ReferenceRect.new()
	glow.border_color = Color(0, 0, 0, 0)
	glow.border_width = 3
	glow.editor_only = false
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glow)
	btn.mouse_entered.connect(func() -> void: glow.border_color = Color(0.1, 0.8, 1.0))
	btn.mouse_exited.connect(func() -> void: glow.border_color = Color(0, 0, 0, 0))
	return btn

# ==========================================
# TRUCK VISUALIZER
# ==========================================
func _update_truck_visualizer(loaded_pallets: Array) -> void:
	if truck_grid.columns != 3: truck_grid.columns = 3
	for child in truck_grid.get_children(): child.queue_free()

	for i: int in range(loaded_pallets.size()):
		var p: Dictionary = loaded_pallets[i]
		var btn := _build_pallet_graphic(get_type_color(p.type), true, p.type)

		# Co-loading destination tag
		var p_dest: int = p.get("dest", 1)
		if _ui.current_dest2_name != "":
			var ttag := ColorRect.new()
			ttag.custom_minimum_size = Vector2(8, 8)
			ttag.color = Color(0.94, 0.76, 0.2) if p_dest == 1 else Color(0.9, 0.45, 0.15)
			ttag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			ttag.offset_left = -8; ttag.offset_right = 0
			ttag.offset_top = 0; ttag.offset_bottom = 8
			ttag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(ttag)

		# ADR indicator
		if p.get("has_adr", false):
			var adr_ttag := ColorRect.new()
			adr_ttag.custom_minimum_size = Vector2(8, 8)
			adr_ttag.color = Color(0.9, 0.15, 0.15, 0.85)
			adr_ttag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			adr_ttag.offset_left = -8; adr_ttag.offset_right = 0
			adr_ttag.offset_top = -8; adr_ttag.offset_bottom = 0
			adr_ttag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(adr_ttag)

		var is_reachable: bool = i >= (loaded_pallets.size() - 3)
		var hover_text: String = ""
		var p_w: float = p.get("weight_kg", 0.0)
		var p_v: int = p.get("dm3", 0)
		var p_sub: String = p.get("subtype", "")
		var p_sub_str: String = ("  [color=#c0c8d0]Sub:[/color] [color=#ffffff]%s[/color]" % p_sub) if p_sub != "" else ""
		var p_combined: Array = p.get("combined_uats", [])
		var p_combined_str: String = ("\n[color=#2ecc71][b]⊕ Combined — carries %d UATs[/b][/color]" % (1 + p_combined.size())) if not p_combined.is_empty() else ""
		var p_adr_str: String = "  [color=#ff4444][b]⚠ ADR[/b][/color]" if p.get("has_adr", false) else ""
		var p_ddate: String = p.get("delivery_date", "")
		var p_promise_label: String = "Delivery" if p_ddate != "" else "Promise"
		var p_promise_val: String = p_ddate if p_ddate != "" else p.promise
		if is_reachable:
			hover_text = "[font_size=15][color=#e74c3c][b]⚠ UNLOAD PALLET[/b][/color]\n[color=#c0c8d0]Type:[/color] [b][color=#ffffff]%s[/color][/b]%s%s  [color=#c0c8d0]%s:[/color] [b][color=#ffffff]%s[/color][/b]\n[color=#c0c8d0]U.A.T:[/color] [b][color=#ffffff]%s[/color][/b]  [color=#c0c8d0]Colis:[/color] [color=#ffffff]%s[/color]\n[color=#c0c8d0]Weight:[/color] [color=#ffffff]%.0f kg[/color]  [color=#c0c8d0]Volume:[/color] [color=#ffffff]%d dm³[/color]%s\n[color=#e74c3c]Penalty: +1.1 min rework[/color][/font_size]" % [p.type, p_sub_str, p_adr_str, p_promise_label, p_promise_val, p.id, p.get("colis_id", "N/A"), p_w, p_v, p_combined_str]
		else:
			btn.modulate = Color(0.6, 0.6, 0.6)
			hover_text = "[font_size=15][color=#95a5a6][b]BLOCKED[/b]\n[color=#c0c8d0]Type:[/color] [color=#ffffff]%s[/color]%s  [color=#c0c8d0]%s:[/color] [color=#ffffff]%s[/color]\n%s\n" % [p.type, p_adr_str, p_promise_label, p_promise_val, p.id] + Locale.t("dock.blocked_unload") + "[/color][/font_size]"

		btn.mouse_entered.connect(func() -> void: _set_hover_text(hover_text))
		btn.mouse_exited.connect(func() -> void: _set_hover_text(_hover_default_text()))

		btn.pressed.connect(func() -> void:
			if _ui._load_cooldown: return
			if _ui.tutorial_active and _ui.tutorial_step != 9:
				_ui._tut.flash_warning(Locale.t("warn.dont_unload"))
				return
			_ui._load_cooldown = true
			btn.modulate = Color(1.5, 0.5, 0.5)
			var ul_timer := _ui.get_tree().create_timer(0.23)
			ul_timer.timeout.connect(func() -> void:
				if _ui._session != null: _ui._session.call("unload_pallet_by_id", p.id)
				WOTSAudio.play_unload_warning(_ui)
				var cd_timer := _ui.get_tree().create_timer(0.23)
				cd_timer.timeout.connect(func() -> void:
					_ui._load_cooldown = false
				)
			)
		)
		truck_grid.add_child(btn)

# ==========================================
# DRAW PALLET ON DOCK
# ==========================================
func _draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn := _build_pallet_graphic(get_type_color(p_data.type), false, p_data.type)

	# Combine-eligible indicator
	var is_combine_src: bool = false
	if _ui._session != null:
		is_combine_src = _ui._session.call("_is_combine_source", p_data)
	if is_combine_src:
		var cb_border := ReferenceRect.new()
		cb_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		cb_border.border_color = Color(0.18, 0.9, 0.5, 0.9)
		cb_border.border_width = 2.5
		cb_border.editor_only = false
		cb_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cb_border)
		var lbl_c := Label.new()
		lbl_c.text = "⊕"
		lbl_c.add_theme_font_size_override("font_size", 11)
		lbl_c.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
		lbl_c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		lbl_c.offset_left = 2; lbl_c.offset_bottom = 0; lbl_c.offset_top = -14
		lbl_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl_c)

	# Co-loading destination indicator
	var dest_id: int = p_data.get("dest", 1)
	if _ui.current_dest2_name != "":
		var tag := ColorRect.new()
		tag.custom_minimum_size = Vector2(12, 12)
		tag.color = Color(0.94, 0.76, 0.2) if dest_id == 1 else Color(0.9, 0.45, 0.15)
		tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -12; tag.offset_right = 0
		tag.offset_top = 0; tag.offset_bottom = 12
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tag)
		var tag_lbl := Label.new()
		tag_lbl.text = str(dest_id)
		tag_lbl.add_theme_font_size_override("font_size", 8)
		tag_lbl.add_theme_color_override("font_color", Color.BLACK)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(tag_lbl)

	# ADR indicator
	if p_data.get("has_adr", false):
		var adr_tag := ColorRect.new()
		adr_tag.custom_minimum_size = Vector2(12, 12)
		adr_tag.color = Color(0.9, 0.15, 0.15, 0.85)
		adr_tag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		adr_tag.offset_left = -12; adr_tag.offset_right = 0
		adr_tag.offset_top = -12; adr_tag.offset_bottom = 0
		adr_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(adr_tag)
		var adr_lbl := Label.new()
		adr_lbl.text = "!"
		adr_lbl.add_theme_font_size_override("font_size", 9)
		adr_lbl.add_theme_color_override("font_color", Color.WHITE)
		adr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		adr_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		adr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		adr_tag.add_child(adr_lbl)

	var code_str: String = ""
	if p_data.has("code"): code_str = " | Code: " + p_data.code
	var colis_str: String = p_data.get("colis_id", "N/A")
	var base_label: String = "Plastic" if (p_data.type == "Mecha" or p_data.type == "C&C") else "EUR Wood"
	if p_data.type == "ADR": base_label = "Plastic ⚠ ADR"
	var adr_extra: String = "  [color=#ff4444][b]⚠ ADR[/b][/color]" if p_data.get("has_adr", false) else ""
	var hover_text: String = "[font_size=15][color=#0082c3][b]▶ SCAN DATA[/b][/color]  "
	hover_text += "[color=#c0c8d0]Type:[/color] [b][color=#ffffff]%s[/color][/b] [color=#8a9aaa](%s)[/color]%s%s\n" % [p_data.type, base_label, code_str, adr_extra]
	hover_text += "[color=#c0c8d0]U.A.T:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Colis:[/color] [b][color=#ffffff]%s[/color][/b]\n" % [p_data.id, colis_str]
	var ddate: String = p_data.get("delivery_date", "")
	if ddate != "":
		hover_text += "[color=#c0c8d0]Delivery:[/color] [b][color=#f1c40f]%s[/color][/b]   [color=#c0c8d0]Qty:[/color] [color=#ffffff]%d[/color]   [color=#c0c8d0]Cap:[/color] [color=#ffffff]%0.1f[/color]" % [ddate, p_data.collis, p_data.cap]
	else:
		hover_text += "[color=#c0c8d0]Promise:[/color] [b][color=#ffffff]%s[/color][/b]   [color=#c0c8d0]Qty:[/color] [color=#ffffff]%d[/color]   [color=#c0c8d0]Cap:[/color] [color=#ffffff]%0.1f[/color]" % [p_data.promise, p_data.collis, p_data.cap]
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
	if _ui.current_dest2_name != "":
		var dest_str: String = "%s %s" % [_ui.current_dest_name, _ui.current_dest_code] if dest_id == 1 else "%s %s" % [_ui.current_dest2_name, _ui.current_dest2_code]
		var dest_color: String = "#f1c40f" if dest_id == 1 else "#e67e22"
		hover_text += "\n[color=%s][b]DEST: %s (Seq %d)[/b][/color]" % [dest_color, dest_str, dest_id]
	hover_text += "[/font_size]"

	btn.mouse_entered.connect(func() -> void: _set_hover_text(hover_text))
	btn.mouse_exited.connect(func() -> void: _set_hover_text(_hover_default_text()))

	btn.pressed.connect(func() -> void:
		if _ui._load_cooldown: return
		if _ui.tutorial_active:
			if _ui.tutorial_step < 8:
				_ui._tut.flash_warning(Locale.t("warn.not_ready_load"))
				return
			if _ui.tutorial_step == 8 and p_data.type != "Mecha":
				_ui._tut.flash_warning(Locale.t("warn.click_mecha"))
				return
			if _ui.tutorial_step == 9:
				_ui._tut.flash_warning(Locale.t("warn.remove_mecha"))
				return
			if _ui.tutorial_step == 10 and p_data.type != "ServiceCenter":
				_ui._tut.flash_warning(Locale.t("warn.service_first"))
				return
			if _ui.tutorial_step == 11 and p_data.type != "Bikes":
				_ui._tut.flash_warning(Locale.t("warn.bikes_next"))
				return
			if _ui.tutorial_step == 12:
				_ui._tut.flash_warning(Locale.t("warn.help_sops_first"))
				return
		if _ui._as400.state != 18:
			WOTSAudio.play_error_buzz(_ui)
			if _ui.tutorial_active and _ui.tutorial_step == 8:
				_ui._tut.flash_warning(Locale.t("warn.scanner_raq_tutorial"))
			elif lbl_hover_info:
				lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.scanner_inactive") + "[/b] " + Locale.t("dock.scanner_inactive_detail") + "[/color][/font_size]"
			return
		if _ui._session != null and not _ui._session.loading_started:
			WOTSAudio.play_error_buzz(_ui)
			if lbl_hover_info:
				lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.scanner_inactive") + "[/b] " + Locale.t("dock.start_loading_first") + "[/color][/font_size]"
			return
		if _ui.current_dest2_name != "" and _ui._as400.state == 18:
			var tab_seq: int = _ui._as400._get_tab_dest_seq(_ui._as400._active_tab)
			if tab_seq != 0 and p_data.get("dest", 1) != tab_seq:
				WOTSAudio.play_error_buzz(_ui)
				var wrong_store_name: String = _ui.current_dest_name if p_data.get("dest", 1) == 1 else _ui.current_dest2_name
				var wrong_store_code: String = _ui.current_dest_code if p_data.get("dest", 1) == 1 else _ui.current_dest2_code
				if lbl_hover_info:
					lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.wrong_store") + "[/b] " + (Locale.t("dock.wrong_store_detail") % [wrong_store_name, wrong_store_code]) + "[/color][/font_size]"
				_ui._as400.wrong_store_scans += 1
				return
		_ui._load_cooldown = true
		var _orig_mod: Color = btn.modulate
		btn.modulate = Color(1.5, 1.5, 1.5)
		WOTSAudio.play_scan_beep(_ui)
		var load_timer := _ui.get_tree().create_timer(0.23)
		load_timer.timeout.connect(func() -> void:
			if _ui._session != null: _ui._session.call("load_pallet_by_id", p_data.id)
			WOTSAudio.play_load_confirm(_ui)
			var cd_timer := _ui.get_tree().create_timer(0.23)
			cd_timer.timeout.connect(func() -> void:
				_ui._load_cooldown = false
			)
		)
	)
	parent.add_child(btn)
