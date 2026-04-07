class_name DockGraphics
extends RefCounted

## Pallet graphic building, emballage graphic, truck visualizer, and dock
## pallet drawing.  Extracted from DockView — lives as `_dock._gfx`.

var _dock: DockView


func _init(dock: DockView) -> void:
	_dock = dock


# ==========================================
# TOP-DOWN PALLET GENERATOR
# ==========================================
func build_pallet_graphic(color: Color, is_truck: bool, p_type: String = "") -> Button:
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
	glow.border_color = UITokens.CLR_TRANSPARENT
	glow.border_width = 3
	glow.editor_only = false
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glow)
	btn.mouse_entered.connect(func() -> void: glow.border_color = Color(0.1, 0.8, 1.0))
	btn.mouse_exited.connect(func() -> void: glow.border_color = UITokens.CLR_TRANSPARENT)
	return btn


# ==========================================
# EMBALLAGE PALLET GRAPHIC (empty return pallets)
# ==========================================
func build_emballage_graphic() -> Button:
	var btn := Button.new()
	var p_size: int = 45
	btn.custom_minimum_size = Vector2(p_size, p_size)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	var base_bg := ColorRect.new()
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_bg.color = Color(0.55, 0.4, 0.22)
	btn.add_child(base_bg)
	var planks := HBoxContainer.new()
	planks.set_anchors_preset(Control.PRESET_FULL_RECT)
	planks.add_theme_constant_override("separation", 3)
	planks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_bg.add_child(planks)
	for i: int in range(3):
		var plank := ColorRect.new()
		plank.color = Color(0.68, 0.5, 0.3) if i % 2 == 0 else Color(0.6, 0.42, 0.25)
		plank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		planks.add_child(plank)
	var e_lbl := Label.new()
	e_lbl.text = "E"
	e_lbl.add_theme_font_size_override("font_size", UITokens.fs(16))
	e_lbl.add_theme_color_override("font_color", Color(0.3, 0.22, 0.12))
	e_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	e_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(e_lbl)
	var border := ReferenceRect.new()
	border.border_color = Color(0.4, 0.3, 0.15)
	border.border_width = 2
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(border)
	var glow := ReferenceRect.new()
	glow.border_color = UITokens.CLR_TRANSPARENT
	glow.border_width = 3
	glow.editor_only = false
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glow)
	btn.mouse_entered.connect(func() -> void: glow.border_color = Color(0.9, 0.75, 0.3))
	btn.mouse_exited.connect(func() -> void: glow.border_color = UITokens.CLR_TRANSPARENT)
	return btn


# ==========================================
# TRUCK VISUALIZER
# ==========================================
func update_truck_visualizer(loaded_pallets: Array) -> void:
	if _dock.truck_grid.columns != 3: _dock.truck_grid.columns = 3
	for child: Node in _dock.truck_grid.get_children(): child.queue_free()

	# --- EMBALLAGE PALLETS ---
	var emb_count: int = 0
	if _dock._ui._session != null:
		emb_count = _dock._ui._session.emballage_remaining

	# T7: "← UNLOAD FIRST" arrow only visible while emballage remain
	if _dock.lifo_lbl != null:
		_dock.lifo_lbl.visible = (emb_count > 0)
	for ei: int in range(emb_count):
		var emb_btn := build_emballage_graphic()
		var emb_hover: String = "[font_size=15][color=#c8a860][b]EMBALLAGE[/b][/color]\n[color=#c0c8d0]Empty return pallet %d / %d[/color]\n[color=#f1c40f]Click to remove from truck (~45s)[/color][/font_size]" % [ei + 1, emb_count]
		emb_btn.mouse_entered.connect(func() -> void: _dock._set_hover_text(emb_hover))
		emb_btn.mouse_exited.connect(func() -> void: _dock._set_hover_text(_dock._hover_default_text()))
		emb_btn.pressed.connect(func() -> void:
			if _dock._ui._load_cooldown: return
			# T11: Cannot remove emballage before opening the dock
			if not _dock._dock_open:
				if _dock.lbl_hover_info:
					_dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Open the dock first![/b][/color] [color=#c0c8d0]You cannot enter the trailer with the EPT until the dock leveler is down.[/color][/font_size]"
				WOTSAudio.play_error_buzz(_dock._ui)
				return
			_dock._ui._load_cooldown = true
			emb_btn.modulate = Color(1.5, 1.2, 0.5)
			WOTSAudio.play_emballage_click(_dock._ui)
			var emb_timer := _dock._ui.get_tree().create_timer(0.23)
			emb_timer.timeout.connect(func() -> void:
				if _dock._ui._session != null:
					_dock._ui._session.manual_decision("Remove Emballage")
				var cd_timer := _dock._ui.get_tree().create_timer(0.23)
				cd_timer.timeout.connect(func() -> void:
					_dock._ui._load_cooldown = false
				)
			)
		)
		_dock.truck_grid.add_child(emb_btn)

	for i: int in range(loaded_pallets.size()):
		var p: Dictionary = loaded_pallets[i]
		var btn := build_pallet_graphic(_dock.get_type_color(p.type), true, p.type)

		# Co-loading destination tag
		var p_dest: int = p.get("dest", 1)
		if _dock._ui.current_dest2_name != "":
			var ttag := ColorRect.new()
			ttag.custom_minimum_size = Vector2(8, 8)
			ttag.color = UITokens.CLR_AMBER if p_dest == 1 else UITokens.CLR_ORANGE
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

		btn.mouse_entered.connect(func() -> void: _dock._set_hover_text(hover_text))
		btn.mouse_exited.connect(func() -> void: _dock._set_hover_text(_dock._hover_default_text()))

		btn.pressed.connect(func() -> void:
			if _dock._ui._load_cooldown: return
			var unload_gate: String = _dock._ui._tc.check_pallet_unload_gate()
			if unload_gate != "":
				_dock._ui._tut.flash_warning(Locale.t(unload_gate))
				return
			_dock._ui._load_cooldown = true
			btn.modulate = Color(1.5, 0.5, 0.5)
			var ul_timer := _dock._ui.get_tree().create_timer(0.23)
			ul_timer.timeout.connect(func() -> void:
				if _dock._ui._session != null: _dock._ui._session.unload_pallet_by_id(p.id)
				WOTSAudio.play_unload_warning(_dock._ui)
				var cd_timer := _dock._ui.get_tree().create_timer(0.23)
				cd_timer.timeout.connect(func() -> void:
					_dock._ui._load_cooldown = false
				)
			)
		)
		_dock.truck_grid.add_child(btn)


# ==========================================
# DRAW PALLET ON DOCK
# ==========================================
func draw_pallet(p_data: Dictionary, parent: Control) -> void:
	var btn := build_pallet_graphic(_dock.get_type_color(p_data.type), false, p_data.type)

	# Combine-eligible indicator
	var is_combine_src: bool = false
	if _dock._ui._session != null:
		is_combine_src = _dock._ui._session._is_combine_source(p_data)
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
		lbl_c.add_theme_font_size_override("font_size", UITokens.fs(11))
		lbl_c.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
		lbl_c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		lbl_c.offset_left = 2; lbl_c.offset_bottom = 0; lbl_c.offset_top = -14
		lbl_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl_c)

	# Co-loading destination indicator
	var dest_id: int = p_data.get("dest", 1)
	if _dock._ui.current_dest2_name != "":
		var tag := ColorRect.new()
		tag.custom_minimum_size = Vector2(12, 12)
		tag.color = UITokens.CLR_AMBER if dest_id == 1 else UITokens.CLR_ORANGE
		tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -12; tag.offset_right = 0
		tag.offset_top = 0; tag.offset_bottom = 12
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tag)
		var tag_lbl := Label.new()
		tag_lbl.text = str(dest_id)
		tag_lbl.add_theme_font_size_override("font_size", UITokens.fs(8))
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
		adr_lbl.add_theme_font_size_override("font_size", UITokens.fs(9))
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
	var adr_extra: String = ("  " + UITokens.BB_RED_BRIGHT + "[b]⚠ ADR[/b]" + UITokens.BB_END) if p_data.get("has_adr", false) else ""
	var bb_m: String = UITokens.BB_MUTED
	var bb_w: String = UITokens.BB_WHITE
	var bb_e: String = UITokens.BB_END
	var hover_text: String = "[font_size=15]" + UITokens.BB_ACCENT + "[b]▶ SCAN DATA[/b]" + bb_e + "  "
	hover_text += bb_m + "Type:" + bb_e + " [b]" + bb_w + p_data.type + bb_e + "[/b] " + UITokens.BB_HINT + "(" + base_label + ")" + bb_e + code_str + adr_extra + "\n"
	hover_text += bb_m + "U.A.T:" + bb_e + " [b]" + bb_w + p_data.id + bb_e + "[/b]   " + bb_m + "Colis:" + bb_e + " [b]" + bb_w + colis_str + bb_e + "[/b]\n"
	var ddate: String = p_data.get("delivery_date", "")
	if ddate != "":
		hover_text += bb_m + "Delivery:" + bb_e + " [b]" + UITokens.BB_WARNING + ddate + bb_e + "[/b]   "
	else:
		hover_text += bb_m + "Promise:" + bb_e + " [b]" + bb_w + str(p_data.promise) + bb_e + "[/b]   "
	hover_text += bb_m + "Qty:" + bb_e + " " + bb_w + str(p_data.collis) + bb_e + "   " + bb_m + "Cap:" + bb_e + " " + bb_w + ("%.1f" % p_data.cap) + bb_e
	var w_kg: float = p_data.get("weight_kg", 0.0)
	var v_dm3: int = p_data.get("dm3", 0)
	if w_kg > 0.0:
		hover_text += "\n" + bb_m + "Weight:" + bb_e + " " + bb_w + ("%.0f kg" % w_kg) + bb_e + "   " + bb_m + "Volume:" + bb_e + " " + bb_w + str(v_dm3) + " dm³" + bb_e
	var sub: String = p_data.get("subtype", "")
	if sub != "":
		hover_text += "   " + bb_m + "Type:" + bb_e + " " + bb_w + sub + bb_e
	var combined: Array = p_data.get("combined_uats", [])
	if not combined.is_empty():
		hover_text += "\n" + UITokens.BB_SUCCESS + "[b]⊕ Combined — carries " + str(1 + combined.size()) + " UATs[/b]" + bb_e
	if _dock._ui.current_dest2_name != "":
		var dest_str: String = ("%s %s" % [_dock._ui.current_dest_name, _dock._ui.current_dest_code]) if dest_id == 1 else ("%s %s" % [_dock._ui.current_dest2_name, _dock._ui.current_dest2_code])
		var dest_bb: String = UITokens.BB_WARNING if dest_id == 1 else UITokens.BB_ORANGE
		hover_text += "\n" + dest_bb + "[b]DEST: " + dest_str + " (Seq " + str(dest_id) + ")[/b]" + bb_e
	hover_text += "[/font_size]"

	btn.mouse_entered.connect(func() -> void: _dock._set_hover_text(hover_text))
	btn.mouse_exited.connect(func() -> void: _dock._set_hover_text(_dock._hover_default_text()))

	btn.pressed.connect(func() -> void:
		if _dock._ui._load_cooldown: return
		var load_gate: String = _dock._ui._tc.check_pallet_load_gate(str(p_data.get("type", "")))
		if load_gate != "":
			_dock._ui._tut.flash_warning(Locale.t(load_gate))
			return
		if _dock._ui._as400.state != 18:
			WOTSAudio.play_error_buzz(_dock._ui)
			var scanner_gate: String = _dock._ui._tc.check_scanner_gate()
			if scanner_gate != "":
				_dock._ui._tut.flash_warning(Locale.t(scanner_gate))
			elif _dock.lbl_hover_info:
				_dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.scanner_inactive") + "[/b] " + Locale.t("dock.scanner_inactive_detail") + "[/color][/font_size]"
			return
		if _dock._ui._session != null and not _dock._ui._session.loading_started:
			WOTSAudio.play_error_buzz(_dock._ui)
			if _dock.lbl_hover_info:
				_dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.scanner_inactive") + "[/b] " + Locale.t("dock.start_loading_first") + "[/color][/font_size]"
			return
		if _dock._ui.current_dest2_name != "" and _dock._ui._as400.state == 18:
			var tab_seq: int = _dock._ui._as400._get_tab_dest_seq(_dock._ui._as400._active_tab)
			if tab_seq != 0 and p_data.get("dest", 1) != tab_seq:
				WOTSAudio.play_error_buzz(_dock._ui)
				var wrong_store_name: String = _dock._ui.current_dest_name if p_data.get("dest", 1) == 1 else _dock._ui.current_dest2_name
				var wrong_store_code: String = _dock._ui.current_dest_code if p_data.get("dest", 1) == 1 else _dock._ui.current_dest2_code
				if _dock.lbl_hover_info:
					_dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]" + Locale.t("dock.wrong_store") + "[/b] " + (Locale.t("dock.wrong_store_detail") % [wrong_store_name, wrong_store_code]) + "[/color][/font_size]"
				_dock._ui._as400.wrong_store_scans += 1
				return
		_dock._ui._load_cooldown = true
		var _orig_mod: Color = btn.modulate
		btn.modulate = Color(1.5, 1.5, 1.5)
		btn.pivot_offset = btn.size / 2.0
		WOTSAudio.play_scan_beep(_dock._ui)
		var anim_tw: Tween = _dock._ui.create_tween().set_parallel(true)
		anim_tw.tween_property(btn, "scale", Vector2(0.3, 0.3), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		anim_tw.tween_property(btn, "modulate:a", 0.0, 0.2)
		var load_timer := _dock._ui.get_tree().create_timer(0.23)
		load_timer.timeout.connect(func() -> void:
			if _dock._ui._session != null: _dock._ui._session.load_pallet_by_id(p_data.id)
			_dock._ui._start_undo_window(p_data.id)
			WOTSAudio.play_load_confirm(_dock._ui)
			var cd_timer := _dock._ui.get_tree().create_timer(0.23)
			cd_timer.timeout.connect(func() -> void:
				_dock._ui._load_cooldown = false
			)
		)
	)
	parent.add_child(btn)
