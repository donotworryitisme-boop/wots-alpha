class_name CMRForm
extends RefCounted

## CMR document state, actions, dest switching, and field write-through.
## Form UI construction is delegated to CMRFormBuilder (static methods).
## Lives as `_paper.cmr` inside PaperworkForms.

var _ui: BayUI

# --- Build state ---
var form_built: bool = false

# --- Input fields (set by CMRFormBuilder) ---
var _input_expedition: LineEdit = null
var _input_weight: LineEdit = null
var _input_dm3: LineEdit = null
var _lbl_consignee: Label = null
var _lbl_consignee2: Label = null
var _lbl_carrier: Label = null
var _input_uats: LineEdit = null
var _input_collis: LineEdit = null
var _input_eur: LineEdit = null
var _input_plastic: LineEdit = null
var _input_magnum: LineEdit = null
var _input_cc: LineEdit = null
var _input_seal: LineEdit = null
var _input_dock: LineEdit = null

# --- Stamp system ---
var _stamp_top_label: Label = null
var _stamp_top_btn: Button = null
var stamp_top_stamped: bool = false
var _stamp_bot_label: Label = null
var _stamp_bot_btn: Button = null
var stamp_bot_stamped: bool = false

# --- Franco radio ---
var _franco_btn: Button = null
var _non_franco_btn: Button = null
var franco_selected: String = ""

# --- X mark ---
var x_marked: bool = false
var _x_label: Label = null

# --- Co-loading: per-dest state ---
var active_dest: int = 1
var _stamps_top: Array[bool] = [false, false]
var _stamps_bot: Array[bool] = [false, false]
var _x_marks: Array[bool] = [false, false]
var _francos: Array[String] = ["", ""]
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
		_build_form()
	elif _input_expedition != null and is_instance_valid(_input_expedition):
		return  # Already built and valid
	else:
		_build_form()  # Controls freed — rebuild


func clear_fields() -> void:
	_reset_input(_input_expedition)
	_reset_input(_input_weight)
	_reset_input(_input_dm3)
	_reset_input(_input_uats)
	_reset_input(_input_collis)
	_reset_input(_input_eur)
	_reset_input(_input_plastic)
	_reset_input(_input_magnum)
	_reset_input(_input_cc)
	_reset_input(_input_seal)
	_reset_input(_input_dock)
	stamp_top_stamped = false
	stamp_bot_stamped = false
	if _stamp_top_label != null: _stamp_top_label.visible = false
	if _stamp_top_btn != null: _stamp_top_btn.visible = true
	if _stamp_bot_label != null: _stamp_bot_label.visible = false
	if _stamp_bot_btn != null: _stamp_bot_btn.visible = true
	franco_selected = ""
	if _franco_btn != null:
		_franco_btn.button_pressed = false
		_franco_btn.text = "○ Franco / Frei"
	if _non_franco_btn != null:
		_non_franco_btn.button_pressed = false
		_non_franco_btn.text = "○ Non-Franco / Non-Frei"
	x_marked = false
	if _x_label != null: _x_label.visible = false
	active_dest = 1
	_stamps_top = [false, false]
	_stamps_bot = [false, false]
	_x_marks = [false, false]
	_francos = ["", ""]
	if _dest_sub_tabs != null: _dest_sub_tabs.visible = false


func refresh_auto_content() -> void:
	if _lbl_consignee == null: return
	if _ui._session == null: return

	var dest_name: String = _ui.current_dest_name
	if active_dest == 2 and _ui.current_dest2_name != "":
		dest_name = _ui.current_dest2_name

	var store_addr: Dictionary = WarehouseData.get_store_address(dest_name)
	if _lbl_consignee != null:
		_lbl_consignee.text = store_addr.get("cmr_name", dest_name) + "\n" + store_addr.get("street", "") + "\n" + store_addr.get("postcode_city", "")

	if _lbl_consignee2 != null:
		if _ui.current_dest2_name != "" and not _ui._session.is_co_load:
			var s2: Dictionary = WarehouseData.get_store_address(_ui.current_dest2_name)
			_lbl_consignee2.text = "+ " + s2.get("cmr_name", _ui.current_dest2_name) + "\n" + s2.get("street", "") + "\n" + s2.get("postcode_city", "")
			_lbl_consignee2.visible = true
		else:
			_lbl_consignee2.visible = false

	if _lbl_carrier != null:
		var dock_num: int = _ui._session.dock_number
		_lbl_carrier.text = WarehouseData.get_carrier(dock_num)


func show_dest_tabs(is_co_load: bool) -> void:
	if _dest_sub_tabs == null: return
	_dest_sub_tabs.visible = is_co_load
	if is_co_load:
		if _btn_dest1 != null:
			_btn_dest1.text = "  CMR — " + _ui.current_dest_name + "  "
		if _btn_dest2 != null:
			_btn_dest2.text = "  CMR — " + _ui.current_dest2_name + "  "
		active_dest = 1
		_style_dest_tabs()


# ==========================================
# DEST SWITCHING (co-loading)
# ==========================================

func switch_dest(dest: int) -> void:
	if dest == active_dest: return
	if _ui._session == null: return

	# Save current dest state
	_stamps_top[active_dest - 1] = stamp_top_stamped
	_stamps_bot[active_dest - 1] = stamp_bot_stamped
	_x_marks[active_dest - 1] = x_marked
	_francos[active_dest - 1] = franco_selected

	active_dest = dest
	_style_dest_tabs()

	if dest == 2:
		_ui._session.manual_decision("Open CMR 2")
	else:
		_ui._session.manual_decision("Open CMR")

	# Restore fields for new dest
	_restore_inputs(_ui._session, dest)

	# Restore stamp/franco/x state
	stamp_top_stamped = _stamps_top[dest - 1]
	stamp_bot_stamped = _stamps_bot[dest - 1]
	x_marked = _x_marks[dest - 1]
	franco_selected = _francos[dest - 1]

	if _stamp_top_btn != null: _stamp_top_btn.visible = not stamp_top_stamped
	if _stamp_top_label != null: _stamp_top_label.visible = stamp_top_stamped
	if _stamp_bot_btn != null: _stamp_bot_btn.visible = not stamp_bot_stamped
	if _stamp_bot_label != null: _stamp_bot_label.visible = stamp_bot_stamped
	if _x_label != null: _x_label.visible = x_marked

	_restore_franco_ui()
	refresh_auto_content()

	if _scroll_ref != null:
		_scroll_ref.scroll_vertical = 0

	WOTSAudio.play_panel_click(_ui)


# ==========================================
# FORM BUILDER WRAPPER
# ==========================================

func _build_form() -> void:
	var body: RichTextLabel = _find_panel_body(_ui.pnl_loading_plan)
	if body == null: return
	var parent_vbox: VBoxContainer = body.get_parent() as VBoxContainer
	if parent_vbox == null: return
	parent_vbox.remove_child(body)
	body.queue_free()

	# Dest sub-tabs (co-loading only)
	_dest_sub_tabs = HBoxContainer.new()
	_dest_sub_tabs.add_theme_constant_override("separation", 4)
	_dest_sub_tabs.visible = false
	parent_vbox.add_child(_dest_sub_tabs)
	_btn_dest1 = Button.new()
	_btn_dest1.text = "  CMR — Store 1  "
	_btn_dest1.add_theme_font_size_override("font_size", UITokens.fs(11))
	_btn_dest1.pressed.connect(func() -> void: switch_dest(1))
	_dest_sub_tabs.add_child(_btn_dest1)
	_btn_dest2 = Button.new()
	_btn_dest2.text = "  CMR — Store 2  "
	_btn_dest2.add_theme_font_size_override("font_size", UITokens.fs(11))
	_btn_dest2.pressed.connect(func() -> void: switch_dest(2))
	_dest_sub_tabs.add_child(_btn_dest2)
	_style_dest_tabs()

	# Scroll container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent_vbox.add_child(scroll)
	_scroll_ref = scroll

	# Page container
	var page: PanelContainer = CMRFormBuilder.bp(
			UITokens.CLR_CMR_BORDER, UITokens.CLR_CMR_PAPER, 2, 2, 2, 2, 0)
	scroll.add_child(page)
	var pv: VBoxContainer = VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 0)
	page.add_child(pv)

	# Delegate UI construction to builder
	CMRFormBuilder.build_all(self, pv)

	form_built = true


# ==========================================
# FIELD WRITE-THROUGH
# ==========================================

func _write_field(field: String, value: String) -> void:
	if _ui._session == null: return
	var sm: SessionManager = _ui._session
	if active_dest == 1:
		match field:
			"uats": sm.typed_cmr_uats = value
			"collis": sm.typed_cmr_collis = value
			"eur": sm.typed_cmr_eur = value
			"plastic": sm.typed_cmr_plastic = value
			"magnum": sm.typed_cmr_magnum = value
			"cc": sm.typed_cmr_cc = value
			"weight": sm.typed_weight = value
			"dm3": sm.typed_dm3 = value
			"expedition": sm.typed_expedition_cmr = value
			"seal": sm.typed_cmr_seal = value
			"dock": sm.typed_cmr_dock = value
	else:
		match field:
			"uats": sm.typed_cmr2_uats = value
			"collis": sm.typed_cmr2_collis = value
			"eur": sm.typed_cmr2_eur = value
			"plastic": sm.typed_cmr2_plastic = value
			"magnum": sm.typed_cmr2_magnum = value
			"cc": sm.typed_cmr2_cc = value
			"weight": sm.typed_cmr2_weight = value
			"dm3": sm.typed_cmr2_dm3 = value
			"expedition": sm.typed_cmr2_expedition = value
			"seal": sm.typed_cmr2_seal = value
			"dock": sm.typed_cmr2_dock = value
	# Log for ghost replay
	sm.log_action("cmr_field", field + ":" + value)
	# Tutorial: advance step 16/17/19 and reset hint timer
	_ui._tc.try_advance_cmr_filled()
	if _ui.tutorial_active:
		_ui._tut.reset_hint_timer()


# ==========================================
# CMR ACTIONS
# ==========================================

func _apply_stamp_top() -> void:
	if stamp_top_stamped: return
	stamp_top_stamped = true
	_stamps_top[active_dest - 1] = true
	if _stamp_top_btn != null: _stamp_top_btn.visible = false
	if _stamp_top_label != null: _stamp_top_label.visible = true
	WOTSAudio.play_scan_beep(_ui)
	if _ui._session != null:
		_ui._session.manual_decision("CMR Stamp Top")
	_ui._tc.try_advance_cmr_filled()


func _mark_x() -> void:
	if x_marked: return
	x_marked = true
	_x_marks[active_dest - 1] = true
	if _x_label != null: _x_label.visible = true
	WOTSAudio.play_scan_beep(_ui)
	if _ui._session != null:
		_ui._session.manual_decision("Mark CMR")


func _apply_stamp_bot() -> void:
	if stamp_bot_stamped: return
	stamp_bot_stamped = true
	_stamps_bot[active_dest - 1] = true
	if _stamp_bot_btn != null: _stamp_bot_btn.visible = false
	if _stamp_bot_label != null: _stamp_bot_label.visible = true
	WOTSAudio.play_scan_beep(_ui)
	if _ui._session != null:
		_ui._session.manual_decision("CMR Stamp & Sign")
	_ui._tc.try_advance_cmr_filled()


func _select_franco(choice: String) -> void:
	franco_selected = choice
	_francos[active_dest - 1] = choice
	if choice == "franco":
		if _franco_btn != null:
			_franco_btn.text = "● Franco / Frei"
			_franco_btn.button_pressed = true
		if _non_franco_btn != null:
			_non_franco_btn.text = "○ Non-Franco / Non-Frei"
			_non_franco_btn.button_pressed = false
	else:
		if _non_franco_btn != null:
			_non_franco_btn.text = "● Non-Franco / Non-Frei"
			_non_franco_btn.button_pressed = true
		if _franco_btn != null:
			_franco_btn.text = "○ Franco / Frei"
			_franco_btn.button_pressed = false
	if _ui._session != null:
		if active_dest == 1:
			_ui._session.cmr_franco_correct = (choice == "franco")
			_ui._session.cmr_franco_selected = true
		else:
			_ui._session.cmr2_franco_correct = (choice == "franco")
			_ui._session.cmr2_franco_selected = true
		_ui._session.log_action("cmr_franco", choice)
	_ui._tc.try_advance_cmr_filled()


# ==========================================
# DEST TAB STYLING
# ==========================================

func _style_dest_tabs() -> void:
	if _btn_dest1 == null or _btn_dest2 == null: return
	var active_sb := UIStyles.flat(Color(0.18, 0.35, 0.55), 4, 2, Color(0.0, 0.51, 0.76))
	active_sb.set_content_margin_all(4)
	var inactive_sb := UIStyles.flat(Color(0.15, 0.17, 0.20), 4, 1, Color(0.25, 0.28, 0.32))
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
# HELPERS
# ==========================================

func _reset_input(inp: LineEdit) -> void:
	if inp != null:
		inp.text = ""
		inp.editable = true


func _find_panel_body(panel: PanelContainer) -> RichTextLabel:
	if panel == null: return null
	var margin: Node = panel.get_child(0) if panel.get_child_count() > 0 else null
	if margin == null: return null
	var vbox: Node = margin.get_child(0) if margin.get_child_count() > 0 else null
	if vbox == null: return null
	if vbox.get_child_count() > 1:
		var body_node: Node = vbox.get_child(1)
		if body_node is RichTextLabel: return body_node as RichTextLabel
	return null


func _restore_inputs(sm: SessionManager, dest: int) -> void:
	var d1: bool = (dest == 1)
	if _input_uats != null: _input_uats.text = sm.typed_cmr_uats if d1 else sm.typed_cmr2_uats
	if _input_collis != null: _input_collis.text = sm.typed_cmr_collis if d1 else sm.typed_cmr2_collis
	if _input_eur != null: _input_eur.text = sm.typed_cmr_eur if d1 else sm.typed_cmr2_eur
	if _input_plastic != null: _input_plastic.text = sm.typed_cmr_plastic if d1 else sm.typed_cmr2_plastic
	if _input_magnum != null: _input_magnum.text = sm.typed_cmr_magnum if d1 else sm.typed_cmr2_magnum
	if _input_cc != null: _input_cc.text = sm.typed_cmr_cc if d1 else sm.typed_cmr2_cc
	if _input_weight != null: _input_weight.text = sm.typed_weight if d1 else sm.typed_cmr2_weight
	if _input_dm3 != null: _input_dm3.text = sm.typed_dm3 if d1 else sm.typed_cmr2_dm3
	if _input_expedition != null: _input_expedition.text = sm.typed_expedition_cmr if d1 else sm.typed_cmr2_expedition
	if _input_seal != null: _input_seal.text = sm.typed_cmr_seal if d1 else sm.typed_cmr2_seal
	if _input_dock != null: _input_dock.text = sm.typed_cmr_dock if d1 else sm.typed_cmr2_dock


func _restore_franco_ui() -> void:
	if franco_selected == "franco":
		if _franco_btn != null:
			_franco_btn.text = "● Franco / Frei"
			_franco_btn.button_pressed = true
		if _non_franco_btn != null:
			_non_franco_btn.text = "○ Non-Franco / Non-Frei"
			_non_franco_btn.button_pressed = false
	elif franco_selected == "non_franco":
		if _non_franco_btn != null:
			_non_franco_btn.text = "● Non-Franco / Non-Frei"
			_non_franco_btn.button_pressed = true
		if _franco_btn != null:
			_franco_btn.text = "○ Franco / Frei"
			_franco_btn.button_pressed = false
	else:
		if _franco_btn != null:
			_franco_btn.text = "○ Franco / Frei"
			_franco_btn.button_pressed = false
		if _non_franco_btn != null:
			_non_franco_btn.text = "○ Non-Franco / Non-Frei"
			_non_franco_btn.button_pressed = false
