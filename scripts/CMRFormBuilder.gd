class_name CMRFormBuilder
extends RefCounted

## Static helper that builds the CMR document replica UI.
## Called once by CMRForm._build_form() — sets CMRForm member vars directly.
## Pure UI construction — no state, no actions.


# ==========================================
# ENTRY POINT
# ==========================================

static func build_all(cmr: CMRForm, pv: VBoxContainer) -> void:
	var CR: Color = UITokens.CLR_CMR_BORDER
	var CP: Color = UITokens.CLR_CMR_PAPER
	var CK: Color = UITokens.CLR_CMR_INK
	var CB: Color = UITokens.CLR_CMR_STAMP
	_build_header(cmr, pv, CR, CP, CB)
	_build_boxes_1_to_5(cmr, pv, CR, CP, CK, CB)
	_build_goods_section(cmr, pv, CR, CP, CK)
	_build_boxes_13_to_14(cmr, pv, CR, CP, CK)
	_build_boxes_21_to_24(cmr, pv, CR, CP, CK, CB)


# ==========================================
# HEADER
# ==========================================

static func _build_header(cmr: CMRForm, pv: VBoxContainer,
		CR: Color, CP: Color, _CB: Color) -> void:
	var hdr: PanelContainer = bp(CR, CP, 0, 0, 1, 0, 4)
	pv.add_child(hdr)
	var hdr_h: HBoxContainer = HBoxContainer.new()
	hdr_h.add_theme_constant_override("separation", 4)
	hdr.add_child(hdr_h)
	var cn: Label = mk("1", 32, CR)
	cn.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hdr_h.add_child(cn)
	var title_col: VBoxContainer = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 0)
	hdr_h.add_child(title_col)
	title_col.add_child(mk("Exemplaire pour expéditeur", 6, CR))
	title_col.add_child(mk("Exemplaar voor afzender", 6, CR))
	title_col.add_child(mk("LETTRE DE VOITURE", 9, CR))
	title_col.add_child(mk("VRACHTBRIEF – VERVOERDOCUMENT", 6, CR))
	title_col.add_child(mk("FRACHTBRIEF – TRANSPORTDOKUMENT", 6, CR))

	# Badges + NL
	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_END
	hdr_h.add_child(bv)
	var bh: HBoxContainer = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 2)
	bv.add_child(bh)

	# CMR badge with X-mark overlay
	var cmr_bdg: PanelContainer = bp(CR, CP, 1, 1, 1, 1, 2)
	cmr_bdg.custom_minimum_size = Vector2(44.0, 0.0)
	cmr_bdg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bh.add_child(cmr_bdg)
	var cmr_bdg_stack: Control = Control.new()
	cmr_bdg_stack.custom_minimum_size = Vector2(38.0, 20.0)
	cmr_bdg.add_child(cmr_bdg_stack)
	var cmr_bdg_btn: Button = Button.new()
	cmr_bdg_btn.text = "CMR"
	cmr_bdg_btn.add_theme_font_size_override("font_size", UITokens.fs(11))
	cmr_bdg_btn.add_theme_color_override("font_color", CR)
	cmr_bdg_btn.flat = true
	cmr_bdg_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	cmr_bdg_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_sb: StyleBoxEmpty = StyleBoxEmpty.new()
	cmr_bdg_btn.add_theme_stylebox_override("normal", empty_sb)
	cmr_bdg_btn.add_theme_stylebox_override("hover", empty_sb)
	cmr_bdg_btn.add_theme_stylebox_override("pressed", empty_sb)
	cmr_bdg_btn.add_theme_stylebox_override("focus", empty_sb)
	cmr_bdg_stack.add_child(cmr_bdg_btn)
	cmr._x_label = Label.new()
	cmr._x_label.text = "✕"
	cmr._x_label.add_theme_font_size_override("font_size", UITokens.fs(16))
	cmr._x_label.add_theme_color_override("font_color", UITokens.CLR_CMR_XMARK)
	cmr._x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cmr._x_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cmr._x_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cmr._x_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmr._x_label.visible = false
	cmr_bdg_stack.add_child(cmr._x_label)
	cmr_bdg_btn.pressed.connect(func() -> void: cmr._mark_x())

	var avc_bdg: PanelContainer = bp(CR, CP, 1, 1, 1, 1, 2)
	avc_bdg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var avc_bdg_l: Label = mk("AVC", 11, CR)
	avc_bdg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avc_bdg_l.custom_minimum_size.x = 30.0
	avc_bdg.add_child(avc_bdg_l)
	bh.add_child(avc_bdg)
	var nl_lbl: Label = mk("NL", 16, CR)
	nl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(nl_lbl)


# ==========================================
# BOXES 1-5
# ==========================================

static func _build_boxes_1_to_5(cmr: CMRForm, pv: VBoxContainer,
		CR: Color, CP: Color, CK: Color, CB: Color) -> void:
	# ═══ BOX 1 + 16 ═══
	var r1: HBoxContainer = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 0)
	pv.add_child(r1)
	var b1: PanelContainer = bp(CR, CP, 0, 1, 1, 0)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.size_flags_stretch_ratio = 5.5
	r1.add_child(b1)
	var b1v: VBoxContainer = VBoxContainer.new()
	b1v.add_theme_constant_override("separation", 1)
	b1.add_child(b1v)
	b1v.add_child(mk("1  Expéditeur / Afzender / Absender", 6, CR))
	b1v.add_child(mk(WarehouseData.SENDER_NAME, 9, CK))
	b1v.add_child(mk(WarehouseData.SENDER_LINE2, 8, CK))
	b1v.add_child(mk(WarehouseData.SENDER_STREET, 8, CK))
	b1v.add_child(mk(WarehouseData.SENDER_POSTCODE_CITY, 8, CK))

	# Top stamp button
	cmr._stamp_top_btn = Button.new()
	cmr._stamp_top_btn.text = "▣ STAMP"
	cmr._stamp_top_btn.add_theme_font_size_override("font_size", UITokens.fs(7))
	cmr._stamp_top_btn.add_theme_color_override("font_color", CB)
	var ssb := UIStyles.flat(UITokens.CLR_CMR_SECTION_BG, 2, 1, UITokens.CLR_CMR_SECTION_BORDER)
	ssb.set_content_margin_all(2)
	cmr._stamp_top_btn.add_theme_stylebox_override("normal", ssb)
	cmr._stamp_top_btn.add_theme_stylebox_override("hover",
			UIStyles.flat(UITokens.CLR_CMR_SECTION_BG_ALT, 2, 1, UITokens.CLR_CMR_SECTION_BORDER))
	cmr._stamp_top_btn.pressed.connect(func() -> void: cmr._apply_stamp_top())
	b1v.add_child(cmr._stamp_top_btn)
	cmr._stamp_top_label = Label.new()
	cmr._stamp_top_label.text = WarehouseData.SENDER_NAME + "\n" + WarehouseData.SENDER_LINE2 + ", " + WarehouseData.SENDER_STREET + "\n" + WarehouseData.SENDER_POSTCODE_CITY
	cmr._stamp_top_label.add_theme_font_size_override("font_size", UITokens.fs(7))
	cmr._stamp_top_label.add_theme_color_override("font_color", CB)
	cmr._stamp_top_label.visible = false
	b1v.add_child(cmr._stamp_top_label)

	# Box 16
	var b16: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	b16.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b16.size_flags_stretch_ratio = 4.5
	r1.add_child(b16)
	var b16v: VBoxContainer = VBoxContainer.new()
	b16v.add_theme_constant_override("separation", 1)
	b16.add_child(b16v)
	b16v.add_child(mk("16  Transporteur / Vervoerder", 6, CR))
	cmr._lbl_carrier = mk("", 9, CK)
	b16v.add_child(cmr._lbl_carrier)

	# ═══ BOX 2 + 17 ═══
	var r2: HBoxContainer = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 0)
	pv.add_child(r2)
	var b2: PanelContainer = bp(CR, CP, 0, 1, 1, 0)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_stretch_ratio = 5.5
	r2.add_child(b2)
	var b2v: VBoxContainer = VBoxContainer.new()
	b2v.add_theme_constant_override("separation", 1)
	b2.add_child(b2v)
	b2v.add_child(mk("2  Destinataire / Geadresseerde / Empfänger", 6, CR))
	cmr._lbl_consignee = mk("", 9, CK)
	cmr._lbl_consignee.autowrap_mode = TextServer.AUTOWRAP_WORD
	b2v.add_child(cmr._lbl_consignee)
	cmr._lbl_consignee2 = mk("", 8, UITokens.CLR_CMR_DEST2)
	cmr._lbl_consignee2.autowrap_mode = TextServer.AUTOWRAP_WORD
	cmr._lbl_consignee2.visible = false
	b2v.add_child(cmr._lbl_consignee2)

	var b17: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	b17.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b17.size_flags_stretch_ratio = 4.5
	r2.add_child(b17)
	var b17v: VBoxContainer = VBoxContainer.new()
	b17v.add_theme_constant_override("separation", 1)
	b17.add_child(b17v)
	b17v.add_child(mk("17  Transporteurs successifs", 6, CR))

	# ═══ BOX 3 + 18 ═══
	var r3: HBoxContainer = HBoxContainer.new()
	r3.add_theme_constant_override("separation", 0)
	pv.add_child(r3)
	var b3: PanelContainer = bp(CR, CP, 0, 1, 1, 0)
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b3.size_flags_stretch_ratio = 5.5
	r3.add_child(b3)
	var b3v: VBoxContainer = VBoxContainer.new()
	b3v.add_theme_constant_override("separation", 1)
	b3.add_child(b3v)
	b3v.add_child(mk("3  Lieu de livraison / Plaats bestemd", 6, CR))
	b3v.add_child(mk("IDEM 2", 10, CK))
	var b18: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	b18.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b18.size_flags_stretch_ratio = 4.5
	r3.add_child(b18)
	var b18v: VBoxContainer = VBoxContainer.new()
	b18v.add_theme_constant_override("separation", 1)
	b18.add_child(b18v)
	b18v.add_child(mk("18  Réserves et observations / Voorbehoud", 6, CR))

	# ═══ BOX 4 ═══
	var b4: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	pv.add_child(b4)
	var b4v: VBoxContainer = VBoxContainer.new()
	b4v.add_theme_constant_override("separation", 1)
	b4.add_child(b4v)
	b4v.add_child(mk("4  Lieu de prise en charge / Plaats inontvangstneming", 6, CR))
	b4v.add_child(mk("IDEM 1", 10, CK))

	# ═══ BOX 5 ═══
	var b5: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	pv.add_child(b5)
	var b5v: VBoxContainer = VBoxContainer.new()
	b5v.add_theme_constant_override("separation", 1)
	b5.add_child(b5v)
	b5v.add_child(mk("5  Documents annexés / Bijgevoegde documenten", 6, CR))


# ==========================================
# GOODS SECTION (boxes 6-12)
# ==========================================

static func _build_goods_section(cmr: CMRForm, pv: VBoxContainer,
		CR: Color, CP: Color, CK: Color) -> void:
	# Column headers
	var gh: HBoxContainer = HBoxContainer.new()
	gh.add_theme_constant_override("separation", 0)
	pv.add_child(gh)
	var col_defs: Array = [
		["6", "Marques\nMerken", 2.0],
		["7", "Nombre\nAantal", 1.3],
		["8", "Emballage\nVerpakking", 1.5],
		["9", "Nature\nAard", 2.0],
		["10", "No stat.", 1.2],
		["11", "Poids kg\nBrutogewicht", 1.4],
		["12", "Cubage m³\nInhoud", 1.2],
	]
	for cd: Array in col_defs:
		var col_p: PanelContainer = bp(CR, CP, 0, 1, 1, 0, 2)
		col_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_p.size_flags_stretch_ratio = cd[2] as float
		gh.add_child(col_p)
		var col_v: VBoxContainer = VBoxContainer.new()
		col_v.add_theme_constant_override("separation", 0)
		col_p.add_child(col_v)
		col_v.add_child(mk(cd[0] as String, 7, CR))
		var sub_l: Label = mk(cd[1] as String, 5, CR)
		sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		col_v.add_child(sub_l)

	# Goods content: count fields (left) + weight/cubage (right)
	var gp: PanelContainer = bp(CR, CP, 0, 0, 1, 0, 4)
	gp.custom_minimum_size.y = 60.0
	pv.add_child(gp)
	var gh2: HBoxContainer = HBoxContainer.new()
	gh2.add_theme_constant_override("separation", 0)
	gp.add_child(gh2)

	# Left column — count fields
	var gl: VBoxContainer = VBoxContainer.new()
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.size_flags_stretch_ratio = 6.0
	gl.add_theme_constant_override("separation", 2)
	gh2.add_child(gl)

	var cmr_count_fields: Array[Array] = [
		["UATs:", "total UATs"],
		["Colis:", "total colis"],
		["EUR pallets:", "EUR count"],
		["Plastic pallets:", "plastic count"],
		["Magnums:", "magnum count"],
		["C&C:", "C&C count"],
	]
	var cmr_count_inputs: Array[LineEdit] = []
	for cf: Array in cmr_count_fields:
		var cr_row: HBoxContainer = HBoxContainer.new()
		cr_row.add_theme_constant_override("separation", 4)
		gl.add_child(cr_row)
		var cr_lbl: Label = mk(cf[0] as String, 8, CK)
		cr_lbl.custom_minimum_size.x = 90.0
		cr_row.add_child(cr_lbl)
		var cr_inp: LineEdit = le(cf[1] as String, 60.0)
		cr_row.add_child(cr_inp)
		cmr_count_inputs.append(cr_inp)
	cmr._input_uats = cmr_count_inputs[0]
	cmr._input_uats.text_changed.connect(func(new_text: String) -> void: cmr._write_field("uats", new_text))
	cmr._input_collis = cmr_count_inputs[1]
	cmr._input_collis.text_changed.connect(func(new_text: String) -> void: cmr._write_field("collis", new_text))
	cmr._input_eur = cmr_count_inputs[2]
	cmr._input_eur.text_changed.connect(func(new_text: String) -> void: cmr._write_field("eur", new_text))
	cmr._input_plastic = cmr_count_inputs[3]
	cmr._input_plastic.text_changed.connect(func(new_text: String) -> void: cmr._write_field("plastic", new_text))
	cmr._input_magnum = cmr_count_inputs[4]
	cmr._input_magnum.text_changed.connect(func(new_text: String) -> void: cmr._write_field("magnum", new_text))
	cmr._input_cc = cmr_count_inputs[5]
	cmr._input_cc.text_changed.connect(func(new_text: String) -> void: cmr._write_field("cc", new_text))

	# Right column — weight + cubage
	var gr: PanelContainer = bp(CR, CP, 0, 0, 0, 1, 4)
	gr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gr.size_flags_stretch_ratio = 4.0
	gh2.add_child(gr)
	var grv: VBoxContainer = VBoxContainer.new()
	grv.add_theme_constant_override("separation", 4)
	gr.add_child(grv)
	grv.add_child(mk("11  Poids brut kg", 6, CR))
	grv.add_child(mk("Brutogewicht in kg", 5, CR))
	cmr._input_weight = le("from AS400", 70.0)
	cmr._input_weight.text_changed.connect(func(new_text: String) -> void: cmr._write_field("weight", new_text))
	grv.add_child(cmr._input_weight)
	var sp1: Control = Control.new()
	sp1.custom_minimum_size.y = 4.0
	grv.add_child(sp1)
	grv.add_child(mk("12  Cubage m³", 6, CR))
	grv.add_child(mk("Inhoud in m³", 5, CR))
	cmr._input_dm3 = le("from AS400", 70.0)
	cmr._input_dm3.text_changed.connect(func(new_text: String) -> void: cmr._write_field("dm3", new_text))
	grv.add_child(cmr._input_dm3)


# ==========================================
# BOXES 13-14
# ==========================================

static func _build_boxes_13_to_14(cmr: CMRForm, pv: VBoxContainer,
		CR: Color, CP: Color, CK: Color) -> void:
	# ═══ BOX 13 + 19 ═══
	var r13: HBoxContainer = HBoxContainer.new()
	r13.add_theme_constant_override("separation", 0)
	pv.add_child(r13)
	var b13: PanelContainer = bp(CR, CP, 0, 1, 1, 0)
	b13.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b13.size_flags_stretch_ratio = 5.5
	r13.add_child(b13)
	var b13v: VBoxContainer = VBoxContainer.new()
	b13v.add_theme_constant_override("separation", 2)
	b13.add_child(b13v)
	b13v.add_child(mk("13  Instructions expéditeur / Instructies afzender", 6, CR))
	var er: HBoxContainer = HBoxContainer.new()
	er.add_theme_constant_override("separation", 4)
	b13v.add_child(er)
	er.add_child(mk("EXPEDITION:", 8, CK))
	cmr._input_expedition = le("from AS400 SAISIE", 100.0)
	cmr._input_expedition.text_changed.connect(func(new_text: String) -> void: cmr._write_field("expedition", new_text))
	er.add_child(cmr._input_expedition)
	var sr: HBoxContainer = HBoxContainer.new()
	sr.add_theme_constant_override("separation", 4)
	b13v.add_child(sr)
	sr.add_child(mk("SEAL:", 8, CK))
	cmr._input_seal = le("seal number", 100.0)
	cmr._input_seal.text_changed.connect(func(new_text: String) -> void: cmr._write_field("seal", new_text))
	sr.add_child(cmr._input_seal)
	var dr: HBoxContainer = HBoxContainer.new()
	dr.add_theme_constant_override("separation", 4)
	b13v.add_child(dr)
	dr.add_child(mk("DOCK:", 8, CK))
	cmr._input_dock = le("dock number", 100.0)
	cmr._input_dock.text_changed.connect(func(new_text: String) -> void: cmr._write_field("dock", new_text))
	dr.add_child(cmr._input_dock)

	var b19: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	b19.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b19.size_flags_stretch_ratio = 4.5
	r13.add_child(b19)
	var b19v: VBoxContainer = VBoxContainer.new()
	b19v.add_theme_constant_override("separation", 1)
	b19.add_child(b19v)
	b19v.add_child(mk("19  Conventions particulières / Speciale overeenkomsten", 6, CR))

	# ═══ BOX 14 (Franco) ═══
	var b14: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	pv.add_child(b14)
	var b14v: VBoxContainer = VBoxContainer.new()
	b14v.add_theme_constant_override("separation", 1)
	b14.add_child(b14v)
	b14v.add_child(mk("14  Prescriptions d'affranchissement / Frankeringsvoorschrift", 6, CR))
	var fh: HBoxContainer = HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	b14v.add_child(fh)

	# Franco button
	cmr._franco_btn = Button.new()
	cmr._franco_btn.text = "○ Franco / Frei"
	cmr._franco_btn.toggle_mode = true
	cmr._franco_btn.add_theme_font_size_override("font_size", UITokens.fs(9))
	cmr._franco_btn.add_theme_color_override("font_color", CK)
	var fr_sb := UIStyles.flat(Color(0.97, 0.97, 0.97), 2, 1, Color(0.6, 0.6, 0.6))
	fr_sb.set_content_margin_all(3)
	cmr._franco_btn.add_theme_stylebox_override("normal", fr_sb)
	var fr_sb_p := UIStyles.flat(Color(0.85, 0.95, 0.85), 2, 1, Color(0.2, 0.6, 0.2))
	fr_sb_p.set_content_margin_all(3)
	cmr._franco_btn.add_theme_stylebox_override("pressed", fr_sb_p)
	var fr_sb_h := UIStyles.flat(Color(0.93, 0.93, 0.97), 2, 1, Color(0.6, 0.6, 0.6))
	fr_sb_h.set_content_margin_all(3)
	cmr._franco_btn.add_theme_stylebox_override("hover", fr_sb_h)
	cmr._franco_btn.pressed.connect(func() -> void: cmr._select_franco("franco"))
	fh.add_child(cmr._franco_btn)

	# Non-Franco button
	cmr._non_franco_btn = Button.new()
	cmr._non_franco_btn.text = "○ Non-Franco / Non-Frei"
	cmr._non_franco_btn.toggle_mode = true
	cmr._non_franco_btn.add_theme_font_size_override("font_size", UITokens.fs(9))
	cmr._non_franco_btn.add_theme_color_override("font_color", CK)
	cmr._non_franco_btn.add_theme_stylebox_override("normal", fr_sb.duplicate())
	var nfr_sb_p := UIStyles.flat(Color(0.95, 0.85, 0.85), 2, 1, Color(0.6, 0.2, 0.2))
	nfr_sb_p.set_content_margin_all(3)
	cmr._non_franco_btn.add_theme_stylebox_override("pressed", nfr_sb_p)
	cmr._non_franco_btn.add_theme_stylebox_override("hover", fr_sb_h.duplicate())
	cmr._non_franco_btn.pressed.connect(func() -> void: cmr._select_franco("non_franco"))
	fh.add_child(cmr._non_franco_btn)


# ==========================================
# BOXES 21-24
# ==========================================

static func _build_boxes_21_to_24(cmr: CMRForm, pv: VBoxContainer,
		CR: Color, CP: Color, CK: Color, CB: Color) -> void:
	# ═══ BOX 21 ═══
	var b21: PanelContainer = bp(CR, CP, 0, 0, 1, 0)
	pv.add_child(b21)
	var b21h: HBoxContainer = HBoxContainer.new()
	b21h.add_theme_constant_override("separation", 4)
	b21.add_child(b21h)
	b21h.add_child(mk("21  Établi à / Opgemaakt te", 6, CR))
	b21h.add_child(mk("TILBURG", 10, CK))
	b21h.add_child(mk("le / de / am", 6, CR))
	b21h.add_child(mk(UITokens.LOADING_DATE, 10, CK))

	# ═══ BOXES 22 + 23 + 24 ═══
	var rs: HBoxContainer = HBoxContainer.new()
	rs.add_theme_constant_override("separation", 0)
	pv.add_child(rs)

	# Box 22 — stamp & sign
	var b22: PanelContainer = bp(CR, CP, 0, 1, 0, 0)
	b22.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b22.size_flags_stretch_ratio = 3.5
	b22.custom_minimum_size.y = 50.0
	rs.add_child(b22)
	var b22v: VBoxContainer = VBoxContainer.new()
	b22v.add_theme_constant_override("separation", 1)
	b22.add_child(b22v)
	b22v.add_child(mk("22", 7, CR))
	b22v.add_child(mk("Signature et timbre de l'expéditeur", 5, CR))
	b22v.add_child(mk("Handtekening en stempel van de afzender", 5, CR))
	cmr._stamp_bot_btn = Button.new()
	cmr._stamp_bot_btn.text = "▣ STAMP & SIGN"
	cmr._stamp_bot_btn.add_theme_font_size_override("font_size", UITokens.fs(7))
	cmr._stamp_bot_btn.add_theme_color_override("font_color", CB)
	var ssb2 := UIStyles.flat(UITokens.CLR_CMR_SECTION_BG, 2, 1, UITokens.CLR_CMR_SECTION_BORDER)
	ssb2.set_content_margin_all(2)
	cmr._stamp_bot_btn.add_theme_stylebox_override("normal", ssb2)
	cmr._stamp_bot_btn.add_theme_stylebox_override("hover",
			UIStyles.flat(UITokens.CLR_CMR_SECTION_BG_ALT, 2, 1, UITokens.CLR_CMR_SECTION_BORDER))
	cmr._stamp_bot_btn.pressed.connect(func() -> void: cmr._apply_stamp_bot())
	b22v.add_child(cmr._stamp_bot_btn)
	cmr._stamp_bot_label = Label.new()
	cmr._stamp_bot_label.text = WarehouseData.SENDER_NAME + "\n" + WarehouseData.SENDER_LINE2 + ", " + WarehouseData.SENDER_STREET + "\n" + WarehouseData.SENDER_POSTCODE_CITY + "\n[signed]"
	cmr._stamp_bot_label.add_theme_font_size_override("font_size", UITokens.fs(7))
	cmr._stamp_bot_label.add_theme_color_override("font_color", CB)
	cmr._stamp_bot_label.visible = false
	b22v.add_child(cmr._stamp_bot_label)

	# Box 23
	var b23: PanelContainer = bp(CR, CP, 0, 1, 0, 0)
	b23.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b23.size_flags_stretch_ratio = 3.0
	b23.custom_minimum_size.y = 50.0
	rs.add_child(b23)
	var b23v: VBoxContainer = VBoxContainer.new()
	b23v.add_theme_constant_override("separation", 1)
	b23.add_child(b23v)
	b23v.add_child(mk("23", 7, CR))
	b23v.add_child(mk("Signature transporteur / Handtekening vervoerder", 5, CR))

	# Box 24
	var b24: PanelContainer = bp(CR, CP, 0, 0, 0, 0)
	b24.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b24.size_flags_stretch_ratio = 3.5
	b24.custom_minimum_size.y = 50.0
	rs.add_child(b24)
	var b24v: VBoxContainer = VBoxContainer.new()
	b24v.add_theme_constant_override("separation", 1)
	b24.add_child(b24v)
	b24v.add_child(mk("24  Marchandises reçues / Goederen ontvangen", 6, CR))


# ==========================================
# UI ELEMENT FACTORIES
# ==========================================

## Bordered panel container with configurable margins.
static func bp(bc: Color, bg: Color, bt: int, br: int, bb: int, bl: int,
		pad: int = 3) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	var sb := UIStyles.flat(bg)
	sb.border_color = bc
	sb.border_width_top = bt
	sb.border_width_right = br
	sb.border_width_bottom = bb
	sb.border_width_left = bl
	sb.content_margin_top = float(maxi(pad, bt))
	sb.content_margin_right = float(maxi(pad, br))
	sb.content_margin_bottom = float(maxi(pad, bb))
	sb.content_margin_left = float(maxi(pad, bl))
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return pc


## Label with font size and colour.
static func mk(txt: String, sz: int, clr: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", clr)
	return lbl


## Styled line edit for CMR input fields.
static func le(placeholder: String, w: float) -> LineEdit:
	var inp: LineEdit = LineEdit.new()
	inp.placeholder_text = placeholder
	inp.custom_minimum_size.x = w
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp.add_theme_font_size_override("font_size", UITokens.fs(10))
	UIStyles.apply_field_light(inp)
	inp.add_theme_color_override("font_color", Color(0.0, 0.0, 0.6))
	inp.add_theme_color_override("font_placeholder_color", Color(0.6, 0.6, 0.7))
	return inp
