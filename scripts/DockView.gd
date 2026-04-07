class_name DockView
extends RefCounted

# ==========================================
# DOCK VIEW — extracted from BayUI.gd
# Owns: dock floor, lanes, signs, truck, scanner panel, pallet drawing
# ==========================================

var _ui: BayUI  # BayUI reference

# Dock panel
var panel: PanelContainer

# Dock leveler system
var _dock_open: bool = false
var _leveler_overlay: ColorRect = null
var _leveler_label: Label = null
var _leveler_strip: ColorRect = null
var _floor_split_ref: HBoxContainer = null

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
var lifo_lbl: Label = null  # T7: class member so visibility can be toggled

# Scanner
var lbl_hover_info: RichTextLabel
var _hover_tween: Tween = null
var _gfx: DockGraphics

func _init(ui: BayUI) -> void:
	_ui = ui
	_gfx = DockGraphics.new(self)

func _build(stage_hbox: HBoxContainer) -> void:
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.visible = false
	UIStyles.apply_panel(panel, UIStyles.flat(Color(0.22, 0.23, 0.24)))
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
	var sb_dock := UIStyles.flat(Color(0.62, 0.63, 0.61))
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
		{"label": "MECHA 1", "sub": "BLUE BOXES", "color": UITokens.CLR_BLUE_MID},
		{"label": "MECHA 2", "sub": "BLUE BOXES", "color": UITokens.CLR_BLUE_MID},
		{"label": "BULKY", "sub": "TRANSIT", "color": UITokens.CLR_ORANGE_SOFT},
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

	# === DOCK LEVELER (bridge between dock floor and truck) ===
	_floor_split_ref = floor_split
	var leveler_container: Control = Control.new()
	leveler_container.custom_minimum_size = Vector2(24, 0)
	floor_split.add_child(leveler_container)

	_leveler_strip = ColorRect.new()
	_leveler_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leveler_strip.color = UITokens.CLR_DOCK_FLOOR
	leveler_container.add_child(_leveler_strip)

	# Darkening overlay on dock floor when dock is closed
	_leveler_overlay = ColorRect.new()
	_leveler_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leveler_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_leveler_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_leveler_overlay.visible = true
	dock_lanes_bg.add_child(_leveler_overlay)

	_leveler_label = Label.new()
	_leveler_label.text = "DOCK CLOSED — Open dock to begin"
	_leveler_label.add_theme_font_size_override("font_size", UITokens.fs(20))
	_leveler_label.add_theme_color_override("font_color", Color(0.85, 0.4, 0.35))
	_leveler_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leveler_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_leveler_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leveler_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leveler_overlay.add_child(_leveler_label)

	# === TRUCK (door frame) ===
	var truck_outer := PanelContainer.new()
	truck_outer.custom_minimum_size = Vector2(195, 0)
	var truck_frame_sb := UIStyles.flat(Color(0.60, 0.62, 0.64))
	truck_frame_sb.border_width_left = 5; truck_frame_sb.border_width_right = 5
	truck_frame_sb.border_width_top = 5; truck_frame_sb.border_width_bottom = 0
	truck_frame_sb.border_color = Color(0.72, 0.74, 0.76)
	truck_frame_sb.corner_radius_top_left = 4; truck_frame_sb.corner_radius_top_right = 4
	truck_outer.add_theme_stylebox_override("panel", truck_frame_sb)
	floor_split.add_child(truck_outer)

	var truck_inner := PanelContainer.new()
	truck_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var truck_inner_sb := UIStyles.flat(Color(0.28, 0.30, 0.33))
	truck_inner_sb.corner_radius_top_left = 2; truck_inner_sb.corner_radius_top_right = 2
	truck_inner.add_theme_stylebox_override("panel", truck_inner_sb)
	truck_outer.add_child(truck_inner)

	var truck_vbox := VBoxContainer.new()
	truck_vbox.add_theme_constant_override("separation", 4)
	truck_inner.add_child(truck_vbox)

	var truck_header := Label.new()
	truck_header.text = Locale.t("dock.trailer")
	truck_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	truck_header.add_theme_font_size_override("font_size", UITokens.fs(11))
	truck_header.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84))
	truck_vbox.add_child(truck_header)

	truck_cap_label = RichTextLabel.new()
	truck_cap_label.bbcode_enabled = true
	truck_cap_label.scroll_active = false
	truck_cap_label.fit_content = true
	truck_cap_label.text = "[center][color=#c0c8d0]0 / 36[/color][/center]"
	truck_vbox.add_child(truck_cap_label)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.color = Color(0.20, 0.22, 0.25)
	truck_vbox.add_child(bar_bg)
	truck_cap_bar = ColorRect.new()
	truck_cap_bar.custom_minimum_size = Vector2(0, 6)
	truck_cap_bar.color = UITokens.CLR_SUCCESS
	bar_bg.add_child(truck_cap_bar)

	truck_grid = GridContainer.new()
	truck_grid.columns = 3
	truck_grid.add_theme_constant_override("h_separation", 3)
	truck_grid.add_theme_constant_override("v_separation", 3)
	truck_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	truck_vbox.add_child(truck_grid)

	lifo_lbl = Label.new()
	lifo_lbl.text = Locale.t("dock.unload_first")
	lifo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lifo_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	lifo_lbl.add_theme_color_override("font_color", Color(0.85, 0.40, 0.35))
	lifo_lbl.visible = false  # T7: only shown when emballage > 0
	truck_vbox.add_child(lifo_lbl)

	var truck_spacer := Control.new()
	truck_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	truck_vbox.add_child(truck_spacer)

	# === SCANNER PANEL (bottom) ===
	var scanner_bg := PanelContainer.new()
	scanner_bg.custom_minimum_size = Vector2(0, 100)
	scanner_bg.size_flags_vertical = Control.SIZE_SHRINK_END
	var scanner_sb := UIStyles.flat(Color(0.06, 0.07, 0.08))
	scanner_sb.border_width_top = 2
	scanner_sb.border_color = UITokens.COLOR_ACCENT_BLUE
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
	lbl_hover_info.text = "[font_size=15]" + UITokens.BB_DOCK_HINT + Locale.t("dock.hover_scan") + UITokens.BB_END + "[/font_size]"
	scanner_margin.add_child(lbl_hover_info)

# ==========================================
# DOCK LANE REBUILD
# ==========================================
func rebuild_lanes(is_coload: bool) -> void:
	if dock_signs_hbox == null: return
	# Reset dock leveler state
	_dock_open = false
	if _leveler_overlay != null: _leveler_overlay.visible = true
	if _leveler_strip != null: _leveler_strip.color = UITokens.CLR_DOCK_FLOOR
	for c: Node in dock_signs_hbox.get_children(): c.queue_free()
	for c: Node in dock_lanes_hbox.get_children(): c.queue_free()
	for c: Node in dock_floor_labels_hbox.get_children(): c.queue_free()
	co_lanes.clear()

	if is_coload:
		var sign_data: Array = [
			{"label": _ui.current_dest_name, "sub": "MECHA", "color": UITokens.CLR_AMBER},
			{"label": _ui.current_dest_name, "sub": "BULKY", "color": UITokens.CLR_AMBER},
			{"label": _ui.current_dest_name, "sub": "MISC", "color": UITokens.CLR_AMBER},
			{"label": _ui.current_dest2_name, "sub": "MECHA", "color": UITokens.CLR_ORANGE},
			{"label": _ui.current_dest2_name, "sub": "BULKY", "color": UITokens.CLR_ORANGE},
			{"label": _ui.current_dest2_name, "sub": "MISC", "color": UITokens.CLR_ORANGE},
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
			{"label": "MECHA 1", "sub": "BLUE BOXES", "color": UITokens.CLR_BLUE_MID},
			{"label": "MECHA 2", "sub": "BLUE BOXES", "color": UITokens.CLR_BLUE_MID},
			{"label": "BULKY", "sub": "TRANSIT", "color": UITokens.CLR_ORANGE_SOFT},
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
# DOCK LEVELER — OPEN / CLOSE
# ==========================================
func is_dock_open() -> bool:
	return _dock_open


func open_dock() -> void:
	_dock_open = true
	if _leveler_overlay != null:
		_leveler_overlay.visible = false
	if _leveler_strip != null:
		_leveler_strip.color = Color(0.6, 0.62, 0.58)
	if _ui._session != null:
		_ui._session.manual_decision("Open Dock")


func close_dock() -> void:
	_dock_open = false
	if _leveler_overlay != null:
		_leveler_overlay.visible = true
		if _leveler_label != null:
			_leveler_label.text = "DOCK CLOSED"
	if _leveler_strip != null:
		_leveler_strip.color = UITokens.CLR_DOCK_FLOOR
	if _ui._session != null:
		_ui._session.manual_decision("Close Dock")


# ==========================================
# POPULATE LANES + TRUCK (called from BayUI._on_inventory_updated)
# ==========================================
func populate(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	# --- Capacity label + bar ---
	var emb_remaining: int = 0
	if _ui._session != null:
		emb_remaining = _ui._session.emballage_remaining
	var total_occupied: float = cap_used + float(emb_remaining)
	if truck_cap_label != null:
		var pct: float = total_occupied / cap_max if cap_max > 0 else 0.0
		var color_hex: String = "#c0c8d0"
		if pct > 0.85: color_hex = "#e74c3c"
		elif pct > 0.6: color_hex = "#f1c40f"
		if emb_remaining > 0:
			truck_cap_label.text = "[center][color=%s][b]E:%d + %0.0f / %0.0f[/b][/color][/center]" % [color_hex, emb_remaining, cap_used, cap_max]
		else:
			truck_cap_label.text = "[center][color=%s][b]%0.0f / %0.0f[/b][/color][/center]" % [color_hex, cap_used, cap_max]
		if truck_cap_bar != null and truck_cap_bar.get_parent() != null:
			var parent_w: float = truck_cap_bar.get_parent().size.x
			if parent_w > 0:
				truck_cap_bar.custom_minimum_size.x = parent_w * pct
			if pct > 0.85: truck_cap_bar.color = Color(0.9, 0.3, 0.25)
			elif pct > 0.6: truck_cap_bar.color = UITokens.CLR_AMBER
			else: truck_cap_bar.color = UITokens.CLR_SUCCESS

	# --- CLEAR AND POPULATE DOCK LANES ---
	var is_coload: bool = (_ui._current_scenario_index == 3)
	var MAX_PER_LANE: int = 10
	var buffer_height: int = 10

	if is_coload:
		var all_co_lanes: Array = co_lanes.values()
		for lane: VBoxContainer in all_co_lanes:
			for child: Node in lane.get_children(): child.queue_free()
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
			_gfx.draw_pallet(p, lane)
			lane.move_child(lane.get_child(lane.get_child_count() - 1), 0)
			lane_counts[lane_key] += 1
	else:
		for child: Node in lane_m1.get_children(): child.queue_free()
		for child: Node in lane_m2.get_children(): child.queue_free()
		for child: Node in lane_b.get_children(): child.queue_free()
		for child: Node in lane_misc.get_children(): child.queue_free()
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
			_gfx.draw_pallet(p, row)
			row.move_child(row.get_child(row.get_child_count() - 1), 0)
			std_lane_counts[row] += 1

	_gfx.update_truck_visualizer(loaded)

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
	var sign_sb := UIStyles.flat(Color(0.1, 0.1, 0.12))
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
	sign_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	sign_lbl.add_theme_color_override("font_color", Color.WHITE)
	sign_vbox.add_child(sign_lbl)
	var sign_sub := Label.new()
	sign_sub.text = sd.sub
	sign_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_sub.add_theme_font_size_override("font_size", UITokens.fs(9))
	sign_sub.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_LABEL_DIM))
	sign_vbox.add_child(sign_sub)

func _add_floor_label(parent: HBoxContainer, text: String) -> void:
	var fl_panel := PanelContainer.new()
	fl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fl_sb := UIStyles.flat(Color(0.9, 0.55, 0.1), 2)
	fl_panel.add_theme_stylebox_override("panel", fl_sb)
	parent.add_child(fl_panel)
	var fl_lbl := Label.new()
	fl_lbl.text = text
	fl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	fl_lbl.add_theme_color_override("font_color", Color.WHITE)
	var fl_m := MarginContainer.new()
	fl_m.add_theme_constant_override("margin_top", 2)
	fl_m.add_theme_constant_override("margin_bottom", 2)
	fl_m.add_child(fl_lbl)
	fl_panel.add_child(fl_m)

func get_type_color(p_type: String) -> Color:
	if p_type == "C&C": return UITokens.CLR_WHITE
	if p_type == "Bikes": return Color(0.2, 0.7, 0.3)
	if p_type == "Bulky": return Color(0.9, 0.5, 0.1)
	if p_type == "Mecha": return UITokens.COLOR_ACCENT_BLUE
	if p_type == "ServiceCenter": return Color(0.8, 0.8, 0.1)
	if p_type == "ADR": return Color(0.9, 0.15, 0.15)
	return Color(0.5, 0.5, 0.5)

func _hover_default_text() -> String:
	return "[font_size=15]" + UITokens.BB_DOCK_HINT + Locale.t("dock.hover_scan") + UITokens.BB_END + "[/font_size]"

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
