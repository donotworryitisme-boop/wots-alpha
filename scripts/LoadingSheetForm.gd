class_name LoadingSheetForm
extends RefCounted

## Loading Sheet form building, pallet grids, auto-content rendering.
## Extracted from PaperworkForms — lives as `_paper.ls`.
## Supports dual destination for co-loading (one LS per store).

# --- Pallet grid constants ---
const GRID_COLS: int = 10
const GRID_ROWS: int = 3

var _ui: BayUI

# --- Form controls ---
var form_built: bool = false
var ls_input_store: LineEdit = null
var ls_input_seal: LineEdit = null
var ls_input_dock: LineEdit = null
var ls_input_expedition: LineEdit = null
var ls_auto_label: RichTextLabel = null
var ls_auto_label_bottom: RichTextLabel = null
var ls_input_uats: LineEdit = null
var ls_input_collis: LineEdit = null
var ls_input_eur: LineEdit = null
var ls_input_plastic: LineEdit = null
var ls_input_magnum: LineEdit = null

# --- Pallet grid UI ---
var _pallet_grid_container: VBoxContainer = null
var _eur_grid_cells: Array[Label] = []
var _plastic_grid_cells: Array[Label] = []
var _magnum_grid_cells: Array[Label] = []
var _eur_count_label: Label = null
var _plastic_count_label: Label = null
var _magnum_count_label: Label = null

# --- Co-loading: per-dest state ---
var active_dest: int = 1
var _dest_sub_tabs: HBoxContainer = null
var _btn_dest1: Button = null
var _btn_dest2: Button = null
var _scroll_ref: ScrollContainer = null


func _init(ui: BayUI) -> void:
	_ui = ui


# ==========================================
# PUBLIC API
# ==========================================

func build_if_needed() -> void:
	if not form_built:
		_build_ls_form()


func refresh() -> void:
	_refresh_ls_auto_content()


func clear_fields() -> void:
	if ls_input_store != null: ls_input_store.text = ""
	if ls_input_seal != null: ls_input_seal.text = ""
	if ls_input_dock != null: ls_input_dock.text = ""
	if ls_input_expedition != null: ls_input_expedition.text = ""
	if ls_input_uats != null: ls_input_uats.text = ""
	if ls_input_collis != null: ls_input_collis.text = ""
	if ls_input_eur != null: ls_input_eur.text = ""
	if ls_input_plastic != null: ls_input_plastic.text = ""
	if ls_input_magnum != null: ls_input_magnum.text = ""
	_reset_pallet_grids()
	active_dest = 1
	if _dest_sub_tabs != null: _dest_sub_tabs.visible = false


func are_preload_fields_filled() -> bool:
	var store_ok: bool = ls_input_store != null and ls_input_store.text.strip_edges() != ""
	var seal_ok: bool = ls_input_seal != null and ls_input_seal.text.strip_edges() != ""
	var dock_ok: bool = ls_input_dock != null and ls_input_dock.text.strip_edges() != ""
	return store_ok and seal_ok and dock_ok


func format_clock_time(sim_time: float) -> String:
	var base: int = 32400
	if _ui._session != null: base = _ui._session.clock_base_seconds
	var abs_secs: int = base + int(sim_time)
	@warning_ignore("integer_division")
	var hours: int = abs_secs / 3600
	@warning_ignore("integer_division")
	var mins: int = (abs_secs % 3600) / 60
	return "%02d:%02d" % [hours, mins]


func show_dest_tabs(is_co_load: bool) -> void:
	if _dest_sub_tabs == null: return
	_dest_sub_tabs.visible = is_co_load
	if is_co_load:
		if _btn_dest1 != null:
			_btn_dest1.text = "  LS — " + _ui.current_dest_name + "  "
		if _btn_dest2 != null:
			_btn_dest2.text = "  LS — " + _ui.current_dest2_name + "  "
		active_dest = 1
		_style_dest_tabs()


func switch_dest(dest: int) -> void:
	if dest == active_dest: return
	if _ui._session == null: return
	active_dest = dest
	_style_dest_tabs()
	_restore_inputs(_ui._session, dest)
	_refresh_ls_auto_content()
	if _scroll_ref != null:
		_scroll_ref.scroll_vertical = 0
	WOTSAudio.play_panel_click(_ui)


# ==========================================
# FIELD WRITE-THROUGH
# ==========================================

func _write_field(field: String, value: String) -> void:
	if _ui._session == null: return
	var sm: SessionManager = _ui._session
	if active_dest == 1:
		match field:
			"store": sm.typed_store_code = value
			"seal": sm.typed_seal = value
			"dock": sm.typed_dock = value
			"expedition": sm.typed_expedition_ls = value
			"uats": sm.typed_uat_count = value
			"collis": sm.typed_collis_count = value
			"eur": sm.typed_eur_count = value
			"plastic": sm.typed_plastic_count = value
			"magnum": sm.typed_magnum_count = value
	else:
		match field:
			"store": sm.typed_store_code_2 = value
			"seal": sm.typed_seal_2 = value
			"dock": sm.typed_dock_2 = value
			"expedition": sm.typed_expedition_ls_2 = value
			"uats": sm.typed_uat_count_2 = value
			"collis": sm.typed_collis_count_2 = value
			"eur": sm.typed_eur_count_2 = value
			"plastic": sm.typed_plastic_count_2 = value
			"magnum": sm.typed_magnum_count_2 = value


func _restore_inputs(sm: SessionManager, dest: int) -> void:
	var d1: bool = (dest == 1)
	if ls_input_store != null: ls_input_store.text = sm.typed_store_code if d1 else sm.typed_store_code_2
	if ls_input_seal != null: ls_input_seal.text = sm.typed_seal if d1 else sm.typed_seal_2
	if ls_input_dock != null: ls_input_dock.text = sm.typed_dock if d1 else sm.typed_dock_2
	if ls_input_expedition != null: ls_input_expedition.text = sm.typed_expedition_ls if d1 else sm.typed_expedition_ls_2
	if ls_input_uats != null: ls_input_uats.text = sm.typed_uat_count if d1 else sm.typed_uat_count_2
	if ls_input_collis != null: ls_input_collis.text = sm.typed_collis_count if d1 else sm.typed_collis_count_2
	if ls_input_eur != null: ls_input_eur.text = sm.typed_eur_count if d1 else sm.typed_eur_count_2
	if ls_input_plastic != null: ls_input_plastic.text = sm.typed_plastic_count if d1 else sm.typed_plastic_count_2
	if ls_input_magnum != null: ls_input_magnum.text = sm.typed_magnum_count if d1 else sm.typed_magnum_count_2


# ==========================================
# DEST TAB STYLING
# ==========================================

func _style_dest_tabs() -> void:
	if _btn_dest1 == null or _btn_dest2 == null: return
	var active_sb: StyleBoxFlat = UIStyles.flat(Color(0.18, 0.35, 0.55), 4, 2, Color(0.0, 0.51, 0.76))
	active_sb.set_content_margin_all(4)
	var inactive_sb: StyleBoxFlat = UIStyles.flat(Color(0.15, 0.17, 0.20), 4, 1, Color(0.25, 0.28, 0.32))
	inactive_sb.set_content_margin_all(4)
	if active_dest == 1:
		_btn_dest1.add_theme_stylebox_override("normal", active_sb)
		_btn_dest1.add_theme_color_override("font_color", Color.WHITE)
		_btn_dest2.add_theme_stylebox_override("normal", inactive_sb)
		_btn_dest2.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_MID))
	else:
		_btn_dest2.add_theme_stylebox_override("normal", active_sb)
		_btn_dest2.add_theme_color_override("font_color", Color.WHITE)
		_btn_dest1.add_theme_stylebox_override("normal", inactive_sb)
		_btn_dest1.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_MID))


# ==========================================
# FORM BUILDER
# ==========================================

func _make_form_row(label_text: String, placeholder: String, width: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 100.0
	lbl.add_theme_color_override("font_color", UITokens.CLR_WARNING)
	lbl.add_theme_font_size_override("font_size", UITokens.fs(13))
	row.add_child(lbl)
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size.x = width
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_field_dark(input)
	row.add_child(input)
	return row


func _build_ls_form() -> void:
	# If form already exists from a previous session, just clear the fields
	if ls_input_store != null and is_instance_valid(ls_input_store):
		ls_input_store.text = ""
		ls_input_seal.text = ""
		ls_input_dock.text = ""
		ls_input_expedition.text = ""
		ls_input_uats.text = ""
		ls_input_collis.text = ""
		ls_input_eur.text = ""
		ls_input_plastic.text = ""
		ls_input_magnum.text = ""
		_reset_pallet_grids()
		form_built = true
		return
	var body: RichTextLabel = _ui._paper.find_panel_body(_ui.pnl_notes)
	if body == null: return
	var parent_vbox: VBoxContainer = body.get_parent() as VBoxContainer
	if parent_vbox == null: return
	parent_vbox.remove_child(body)
	body.queue_free()

	# --- Dest sub-tabs (co-loading only) ---
	_dest_sub_tabs = HBoxContainer.new()
	_dest_sub_tabs.add_theme_constant_override("separation", 4)
	_dest_sub_tabs.visible = false
	parent_vbox.add_child(_dest_sub_tabs)
	_btn_dest1 = Button.new()
	_btn_dest1.text = "  LS — Store 1  "
	_btn_dest1.add_theme_font_size_override("font_size", UITokens.fs(11))
	_btn_dest1.focus_mode = Control.FOCUS_NONE
	_btn_dest1.pressed.connect(func() -> void: switch_dest(1))
	_dest_sub_tabs.add_child(_btn_dest1)
	_btn_dest2 = Button.new()
	_btn_dest2.text = "  LS — Store 2  "
	_btn_dest2.add_theme_font_size_override("font_size", UITokens.fs(11))
	_btn_dest2.focus_mode = Control.FOCUS_NONE
	_btn_dest2.pressed.connect(func() -> void: switch_dest(2))
	_dest_sub_tabs.add_child(_btn_dest2)
	_style_dest_tabs()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent_vbox.add_child(scroll)
	_scroll_ref = scroll

	var form_vbox: VBoxContainer = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(form_vbox)

	# Title
	var title_lbl: RichTextLabel = RichTextLabel.new()
	title_lbl.bbcode_enabled = true
	title_lbl.fit_content = true
	title_lbl.scroll_active = false
	title_lbl.text = "[font_size=14]" + UITokens.BB_ACCENT + "[b]B2B LOADING SHEET[/b]" + UITokens.BB_END + "[/font_size]"
	form_vbox.add_child(title_lbl)

	# Store code row
	var row_store: HBoxContainer = _make_form_row("STORE:", "e.g. 1570", 120.0)
	(row_store.get_child(0) as Label).add_theme_color_override("font_color", UITokens.CLR_STORE)
	form_vbox.add_child(row_store)
	ls_input_store = row_store.get_child(1) as LineEdit
	ls_input_store.text_changed.connect(func(new_text: String) -> void:
		_write_field("store", new_text)
		if active_dest == 1:
			_ui._paper.check_ls_preload_done()
	)
	ls_input_store.text_submitted.connect(func(_t: String) -> void:
		if ls_input_seal != null: ls_input_seal.grab_focus()
	)

	# Seal row
	var row_seal: HBoxContainer = _make_form_row("SEAL:", "e.g. 1234700", 120.0)
	(row_seal.get_child(0) as Label).add_theme_color_override("font_color", UITokens.CLR_SEAL)
	form_vbox.add_child(row_seal)
	ls_input_seal = row_seal.get_child(1) as LineEdit
	ls_input_seal.text_changed.connect(func(new_text: String) -> void:
		_write_field("seal", new_text)
		if active_dest == 1:
			_ui._paper.check_ls_preload_done()
	)
	ls_input_seal.text_submitted.connect(func(_t: String) -> void:
		if ls_input_dock != null: ls_input_dock.grab_focus()
	)

	# Dock row
	var row_dock: HBoxContainer = _make_form_row("DOCK:", "e.g. 7", 80.0)
	(row_dock.get_child(0) as Label).add_theme_color_override("font_color", UITokens.CLR_DOCK)
	form_vbox.add_child(row_dock)
	ls_input_dock = row_dock.get_child(1) as LineEdit
	ls_input_dock.text_changed.connect(func(new_text: String) -> void:
		_write_field("dock", new_text)
		if active_dest == 1:
			_ui._paper.check_ls_preload_done()
	)
	ls_input_dock.text_submitted.connect(func(_t: String) -> void:
		if ls_input_expedition != null: ls_input_expedition.grab_focus()
	)

	# Expedition row
	var row_exp: HBoxContainer = _make_form_row("EXPEDITION:", "from AS400 SAISIE", 120.0)
	form_vbox.add_child(row_exp)
	ls_input_expedition = row_exp.get_child(1) as LineEdit
	ls_input_expedition.text_changed.connect(func(new_text: String) -> void:
		_write_field("expedition", new_text)
	)

	# Auto-content section TOP (date, carrier, checks)
	ls_auto_label = RichTextLabel.new()
	ls_auto_label.bbcode_enabled = true
	ls_auto_label.fit_content = true
	ls_auto_label.scroll_active = false
	ls_auto_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_child(ls_auto_label)

	# --- LIVE PALLET GRID (fills as pallets are loaded) ---
	_build_pallet_grids(form_vbox)

	# Auto-content section BOTTOM (service center, RAQ, departments)
	ls_auto_label_bottom = RichTextLabel.new()
	ls_auto_label_bottom.bbcode_enabled = true
	ls_auto_label_bottom.fit_content = true
	ls_auto_label_bottom.scroll_active = false
	ls_auto_label_bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_child(ls_auto_label_bottom)

	# --- FINAL COUNTS (typed by user before sealing) ---
	var counts_header: RichTextLabel = RichTextLabel.new()
	counts_header.bbcode_enabled = true
	counts_header.fit_content = true
	counts_header.scroll_active = false
	counts_header.text = "[font_size=13]" + UITokens.BB_DIM + "────────────────────────────────────" + UITokens.BB_END + "\n" + UITokens.BB_ACCENT + "[b]FINAL COUNTS — fill before sealing[/b]" + UITokens.BB_END + "[/font_size]"
	form_vbox.add_child(counts_header)

	var row_uats: HBoxContainer = _make_form_row("UATs:", "total loaded", 80.0)
	form_vbox.add_child(row_uats)
	ls_input_uats = row_uats.get_child(1) as LineEdit
	ls_input_uats.text_changed.connect(func(new_text: String) -> void:
		_write_field("uats", new_text)
	)

	var row_collis: HBoxContainer = _make_form_row("COLLIS:", "total loaded", 80.0)
	form_vbox.add_child(row_collis)
	ls_input_collis = row_collis.get_child(1) as LineEdit
	ls_input_collis.text_changed.connect(func(new_text: String) -> void:
		_write_field("collis", new_text)
	)

	var row_eur: HBoxContainer = _make_form_row("EUR:", "euro pallets", 80.0)
	form_vbox.add_child(row_eur)
	ls_input_eur = row_eur.get_child(1) as LineEdit
	ls_input_eur.text_changed.connect(func(new_text: String) -> void:
		_write_field("eur", new_text)
	)

	var row_plastic: HBoxContainer = _make_form_row("PLASTIC:", "plastic pallets", 80.0)
	form_vbox.add_child(row_plastic)
	ls_input_plastic = row_plastic.get_child(1) as LineEdit
	ls_input_plastic.text_changed.connect(func(new_text: String) -> void:
		_write_field("plastic", new_text)
	)

	var row_magnum: HBoxContainer = _make_form_row("MAGNUMS:", "magnum pallets", 80.0)
	form_vbox.add_child(row_magnum)
	ls_input_magnum = row_magnum.get_child(1) as LineEdit
	ls_input_magnum.text_changed.connect(func(new_text: String) -> void:
		_write_field("magnum", new_text)
	)

	form_built = true


# ==========================================
# PALLET GRID UI
# ==========================================

func _build_pallet_grids(parent: VBoxContainer) -> void:
	_pallet_grid_container = VBoxContainer.new()
	_pallet_grid_container.add_theme_constant_override("separation", 6)
	parent.add_child(_pallet_grid_container)

	_eur_grid_cells.clear()
	_plastic_grid_cells.clear()
	_magnum_grid_cells.clear()

	_eur_count_label = _add_grid_section("EUR", _eur_grid_cells, UITokens.CLR_EUR)
	_plastic_count_label = _add_grid_section("PLASTIC", _plastic_grid_cells, UITokens.CLR_PLASTIC)
	_magnum_count_label = _add_grid_section("MAGNUMS", _magnum_grid_cells, UITokens.CLR_MAGNUM)


func _add_grid_section(type_name: String, cells: Array[Label], fill_color: Color) -> Label:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	_pallet_grid_container.add_child(section)

	# Header row: type name + live count
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	section.add_child(header)

	var name_lbl: Label = Label.new()
	name_lbl.text = type_name
	name_lbl.add_theme_font_size_override("font_size", UITokens.fs(12))
	name_lbl.add_theme_color_override("font_color", fill_color)
	header.add_child(name_lbl)

	var count_lbl: Label = Label.new()
	count_lbl.text = "0"
	count_lbl.add_theme_font_size_override("font_size", UITokens.fs(12))
	count_lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.88))
	header.add_child(count_lbl)

	# Grid: 10 columns x 3 rows = 30 cells
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	section.add_child(grid)

	for i: int in range(GRID_COLS * GRID_ROWS):
		var cell: Label = Label.new()
		cell.text = str(i + 1)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(22.0, 18.0)
		cell.add_theme_font_size_override("font_size", UITokens.fs(9))
		cell.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))
		var cell_bg := UIStyles.flat(UITokens.CLR_CELL_EMPTY, 2)
		cell_bg.set_content_margin_all(1)
		cell.add_theme_stylebox_override("normal", cell_bg)
		grid.add_child(cell)
		cells.append(cell)

	return count_lbl


func _update_pallet_grids(eur: int, plastic: int, magnums: int) -> void:
	_set_grid_fill(_eur_grid_cells, eur, UITokens.CLR_EUR)
	_set_grid_fill(_plastic_grid_cells, plastic, UITokens.CLR_PLASTIC)
	_set_grid_fill(_magnum_grid_cells, magnums, UITokens.CLR_MAGNUM)
	if _eur_count_label != null: _eur_count_label.text = str(eur)
	if _plastic_count_label != null: _plastic_count_label.text = str(plastic)
	if _magnum_count_label != null: _magnum_count_label.text = str(magnums)


func _set_grid_fill(cells: Array[Label], filled: int, color: Color) -> void:
	for i: int in range(cells.size()):
		if not is_instance_valid(cells[i]): continue
		var cell: Label = cells[i]
		var is_filled: bool = i < filled
		if cell.has_theme_stylebox_override("normal"):
			var sb: StyleBoxFlat = cell.get_theme_stylebox("normal") as StyleBoxFlat
			if sb != null:
				sb.bg_color = color if is_filled else UITokens.CLR_CELL_EMPTY
		cell.add_theme_color_override("font_color", Color.WHITE if is_filled else UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM))


func _reset_pallet_grids() -> void:
	if _eur_grid_cells.is_empty(): return
	_set_grid_fill(_eur_grid_cells, 0, UITokens.CLR_EUR)
	_set_grid_fill(_plastic_grid_cells, 0, UITokens.CLR_PLASTIC)
	_set_grid_fill(_magnum_grid_cells, 0, UITokens.CLR_MAGNUM)
	if _eur_count_label != null: _eur_count_label.text = "0"
	if _plastic_count_label != null: _plastic_count_label.text = "0"
	if _magnum_count_label != null: _magnum_count_label.text = "0"


# ==========================================
# AUTO-CONTENT REFRESH
# ==========================================

func _refresh_ls_auto_content() -> void:
	if ls_auto_label == null: return
	if _ui._session == null: return

	# Filter pallets by active_dest for co-loading
	var is_co: bool = _ui._session.is_co_load
	var loaded_source: Array = _ui._session.inventory_loaded
	var avail_source: Array = _ui._session.inventory_available
	if is_co:
		loaded_source = _ui._session.inventory_loaded.filter(
			func(p: Dictionary) -> bool: return p.get("dest", 1) == active_dest)
		avail_source = _ui._session.inventory_available.filter(
			func(p: Dictionary) -> bool: return p.get("dest", 1) == active_dest)

	var eur_count: int = 0
	var plastic_count: int = 0
	var magnum_count: int = 0
	var cc_count: int = 0
	var sc_count: int = 0
	var bikes_count: int = 0
	var bulky_count: int = 0
	var mecha_count: int = 0
	var _total_uats: int = 0
	var _total_collis: int = 0

	for p: Dictionary in loaded_source:
		var base: String = p.get("pallet_base", "euro")
		if base == "euro": eur_count += 1
		elif base == "plastic": plastic_count += 1
		elif base == "magnum": magnum_count += 1
		var ptype: String = p.get("type", "")
		if ptype == "C&C": cc_count += 1
		elif ptype == "ServiceCenter": sc_count += 1
		elif ptype == "Bikes": bikes_count += 1
		elif ptype == "Bulky": bulky_count += 1
		elif ptype == "Mecha": mecha_count += 1
		_total_uats += 1
		_total_collis += p.get("collis", 0)

	# RAQ left-behind: pallets NOT loaded for this dest
	var raq_left_uats: int = 0
	var raq_left_collis: int = 0
	for p: Dictionary in avail_source:
		raq_left_uats += 1
		raq_left_collis += p.get("collis", 0)

	var cc_checked: bool = "Call departments (C&C check)" in _ui._session._manual_decisions
	var transit_count: int = _ui._session.transit_loose_entries.size() + _ui._session.transit_items.size()
	var transit_done: bool = _ui._session.transit_collected
	var adr_done: bool = _ui._session.adr_collected

	var start_str: String = ""
	var finish_str: String = ""
	if _ui._session.loading_started:
		start_str = format_clock_time(_ui._session.loading_start_time)
		if not _ui._session.is_active:
			finish_str = format_clock_time(_ui._session.total_time)

	# Dest-specific display
	var dest_name: String = _ui.current_dest_name
	var _dest_code: String = _ui.current_dest_code
	if active_dest == 2 and _ui.current_dest2_name != "":
		dest_name = _ui.current_dest2_name
		_dest_code = _ui.current_dest2_code
	var carrier_label: String = _ui._session.carrier_name
	var seq_label: String = "1"
	if _ui.current_dest2_name != "":
		seq_label = str(active_dest) + " / 2"

	# --- TOP section: date, carrier, checks ---
	var bb_w: String = UITokens.BB_WARNING
	var bb_l: String = UITokens.BB_LIGHT
	var bb_d: String = UITokens.BB_DIM
	var bb_s: String = UITokens.BB_SUCCESS
	var bb_m: String = UITokens.BB_MUTED
	var bb_b: String = UITokens.BB_BLUE
	var bb_e: String = UITokens.BB_END
	var t: String = "[font_size=13]"
	t += bb_d + "────────────────────────────────────" + bb_e + "\n"
	t += bb_w + "STORE:" + bb_e + " " + bb_l + dest_name + bb_e + "\n"
	t += bb_w + "DATE:" + bb_e + "  " + bb_l + UITokens.LOADING_DATE + bb_e + "   " + bb_w + "CARRIER:" + bb_e + " " + bb_l + carrier_label + bb_e + "\n"
	t += bb_w + "SEQ:" + bb_e + " " + bb_l + seq_label + bb_e + "\n"
	var start_val: String = start_str if start_str != "" else "—"
	var finish_val: String = finish_str if finish_str != "" else "—"
	t += bb_w + "START:" + bb_e + " " + bb_l + start_val + bb_e + "   " + bb_w + "FINISH:" + bb_e + " " + bb_l + finish_val + bb_e + "\n"
	t += bb_d + "────────────────────────────────────" + bb_e + "\n"

	t += bb_l + "[b]CHECK[/b]" + bb_e + "\n"
	var cc_mark: String = bb_s + "✓" + bb_e if cc_checked else bb_m + "☐" + bb_e
	var transit_mark: String = bb_s + "✓" + bb_e if transit_done else bb_m + "☐" + bb_e
	var adr_mark: String = bb_s + "✓" + bb_e if adr_done else bb_m + "☐" + bb_e
	t += "  " + bb_l + "C&C" + bb_e + " " + cc_mark + "   " + bb_l + "Transit" + bb_e + " " + transit_mark + " " + bb_l + "[" + str(transit_count) + "]" + bb_e + "   " + bb_l + "Yellow Cab" + bb_e + " " + adr_mark + "\n"
	t += bb_d + "────────────────────────────────────" + bb_e
	t += "[/font_size]"
	ls_auto_label.text = t

	# --- LIVE PALLET GRID UPDATE ---
	_update_pallet_grids(eur_count, plastic_count, magnum_count)

	# --- BOTTOM section: service center, RAQ, departments ---
	var sc_str: String = str(sc_count) if sc_count > 0 else "—"
	var b: String = "[font_size=13]"
	b += bb_d + "────────────────────────────────────" + bb_e + "\n"
	b += bb_l + "[b]1.[/b] Service Center: " + sc_str + bb_e + "\n"
	b += bb_l + "[b]2.[/b] Inter Store: —" + bb_e + "\n"
	b += bb_l + "[b]3.[/b] Mainetti / Seasonal: —" + bb_e + "\n"
	b += bb_l + "[b]4.[/b] Second Chance / Circular: —" + bb_e + "\n"
	b += bb_l + "[b]5.[/b] Others: —" + bb_e + "\n"
	b += bb_d + "────────────────────────────────────" + bb_e + "\n"

	if _ui._session.loading_started:
		b += bb_w + "RAQ UATs:" + bb_e + " " + bb_l + str(raq_left_uats) + bb_e + "   " + bb_w + "RAQ Collis:" + bb_e + " " + bb_l + str(raq_left_collis) + bb_e + "\n"
	else:
		b += bb_w + "RAQ UATs:" + bb_e + " " + bb_l + "—" + bb_e + "   " + bb_w + "RAQ Collis:" + bb_e + " " + bb_l + "—" + bb_e + "\n"
	b += bb_d + "────────────────────────────────────" + bb_e + "\n"

	b += bb_l + "[b]DEPARTMENTS[/b]" + bb_e + "\n"
	b += "  " + bb_l + "Bikes" + bb_e + " " + bb_b + str(bikes_count) + bb_e + "  " + bb_l + "Bulky" + bb_e + " " + bb_b + str(bulky_count) + bb_e + "  " + bb_l + "Mecha" + bb_e + " " + bb_b + str(mecha_count) + bb_e + "  " + bb_l + "C&C" + bb_e + " " + bb_b + str(cc_count) + bb_e + "\n"
	b += "[/font_size]"
	if ls_auto_label_bottom != null:
		ls_auto_label_bottom.text = b
