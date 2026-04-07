class_name PalletQuiz
extends RefCounted

## Pallet identification matching exercise — shows 6 pallet images in a grid
## and the trainee assigns a type to each. "Check Answers" scores the round.

var _ui: BayUI

# --- OVERLAY ---
var overlay: ColorRect = null
var _grid: GridContainer = null
var _header_label: Label = null
var _score_label: Label = null
var _btn_check: Button = null
var _btn_restart: Button = null
var _btn_close: Button = null
var _result_label: RichTextLabel = null

# --- QUIZ STATE ---
const ROUND_SIZE: int = 6
var _round_items: Array[Dictionary] = []  # 6 items for current round
var _dropdowns: Array[OptionButton] = []  # One per cell
var _cell_panels: Array[PanelContainer] = []  # For border feedback
var _photo_rects: Array[TextureRect] = []  # Photo nodes
var _feedback_labels: Array[Label] = []  # Correct answer shown on error
var _is_active: bool = false
var _checked: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- PALLET DATA ---
var _pallet_data: Array[Dictionary] = [
	{"photo": "res://ui/images/mecha_pallet_photo.png", "answer": "Mecha"},
	{"photo": "res://ui/images/mecha_pallet_uat.png", "answer": "Mecha"},
	{"photo": "res://ui/images/bulky_pallet_photo.png", "answer": "Bulky"},
	{"photo": "res://ui/images/bulky_pallet_uat.png", "answer": "Bulky"},
	{"photo": "res://ui/images/bikes_pallet_photo.png", "answer": "Bikes"},
	{"photo": "res://ui/images/bikes_pallet_uat.png", "answer": "Bikes"},
	{"photo": "res://ui/images/uat_click_collect.png", "answer": "C&C"},
	{"photo": "res://ui/images/sc_bike_stand_photo.png", "answer": "Service Center"},
	{"photo": "res://ui/images/sc_magnum_photo.png", "answer": "Service Center"},
]
var _type_options: Array[String] = ["—", "Mecha", "Bulky", "Bikes", "C&C", "Service Center"]


func _init(ui: BayUI) -> void:
	_ui = ui


func build(root: Control) -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(820, 620)
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)

	# --- HEADER ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	_header_label = Label.new()
	_header_label.text = Locale.t("quiz.title")
	_header_label.add_theme_font_size_override("font_size", UITokens.fs(20))
	_header_label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_label)

	_score_label = Label.new()
	_score_label.text = ""
	_score_label.add_theme_font_size_override("font_size", UITokens.fs(16))
	_score_label.add_theme_color_override("font_color", UITokens.CLR_AMBER)
	header.add_child(_score_label)

	# --- INSTRUCTION ---
	var instr := Label.new()
	instr.text = Locale.t("quiz.match_instruction")
	instr.add_theme_font_size_override("font_size", UITokens.fs(13))
	instr.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(instr)

	# --- IMAGE GRID: 3 columns × 2 rows ---
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_grid)

	# Pre-build 6 cells (populated on start_quiz)
	_dropdowns.clear()
	_cell_panels.clear()
	_photo_rects.clear()
	_feedback_labels.clear()
	for i: int in range(ROUND_SIZE):
		var cell := _build_cell(i)
		_grid.add_child(cell)

	# --- BOTTOM BAR ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(bottom)

	_btn_check = Button.new()
	_btn_check.text = Locale.t("quiz.check")
	_btn_check.custom_minimum_size = Vector2(200, 42)
	_btn_check.add_theme_font_size_override("font_size", UITokens.fs(15))
	UIStyles.apply_btn_primary(_btn_check)
	_btn_check.pressed.connect(func() -> void: _check_answers())
	bottom.add_child(_btn_check)

	_btn_restart = Button.new()
	_btn_restart.text = Locale.t("quiz.restart")
	_btn_restart.custom_minimum_size = Vector2(160, 42)
	_btn_restart.add_theme_font_size_override("font_size", UITokens.fs(15))
	UIStyles.apply_btn_auto(_btn_restart, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, Color.WHITE, 6, 1, UITokens.CLR_SURFACE_MID)
	_btn_restart.visible = false
	_btn_restart.pressed.connect(func() -> void: start_quiz())
	bottom.add_child(_btn_restart)

	# --- RESULT LABEL (shows after check) ---
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.scroll_active = false
	_result_label.custom_minimum_size = Vector2(0, 30)
	_result_label.add_theme_font_size_override("normal_font_size", UITokens.fs(14))
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false
	outer.add_child(_result_label)

	# --- CLOSE BUTTON ---
	_btn_close = Button.new()
	_btn_close.text = "✕"
	_btn_close.custom_minimum_size = Vector2(36, 36)
	_btn_close.add_theme_font_size_override("font_size", UITokens.fs(18))
	UIStyles.apply_btn_auto(_btn_close, Color(0.3, 0.1, 0.1),
			Color(0.9, 0.4, 0.4), Color.WHITE, 4)
	_btn_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_close.offset_left = -48
	_btn_close.offset_right = -12
	_btn_close.offset_top = 12
	_btn_close.offset_bottom = 48
	_btn_close.pressed.connect(func() -> void: close_quiz())
	overlay.add_child(_btn_close)


func _build_cell(idx: int) -> PanelContainer:
	## Builds one matching cell: photo + type dropdown + feedback label.
	var pnl := PanelContainer.new()
	pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyles.apply_panel(pnl, UIStyles.flat(UITokens.CLR_INPUT_BG, 6, 2,
			UITokens.CLR_SURFACE_DIM))
	_cell_panels.append(pnl)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pnl.add_child(vbox)

	# Photo
	var photo := TextureRect.new()
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	photo.custom_minimum_size = Vector2(0, 130)
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(photo)
	_photo_rects.append(photo)

	# Type selector dropdown
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(margin)

	var dd := OptionButton.new()
	dd.custom_minimum_size = Vector2(0, 30)
	dd.add_theme_font_size_override("font_size", UITokens.fs(12))
	for opt: String in _type_options:
		dd.add_item(opt)
	dd.select(0)  # Default: "—"
	UIStyles.apply_dropdown(dd, 8.0)
	var dd_popup := dd.get_popup()
	if dd_popup:
		UIStyles.apply_dropdown_popup(dd_popup)
	var cell_idx: int = idx
	dd.item_selected.connect(func(_item_idx: int) -> void: _on_type_selected(cell_idx))
	margin.add_child(dd)
	_dropdowns.append(dd)

	# Feedback label (shown after check)
	var fb_lbl := Label.new()
	fb_lbl.text = ""
	fb_lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	fb_lbl.add_theme_color_override("font_color", UITokens.CLR_SUCCESS)
	fb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb_lbl.visible = false
	vbox.add_child(fb_lbl)
	_feedback_labels.append(fb_lbl)

	return pnl


func start_quiz() -> void:
	_rng.randomize()
	_is_active = true
	_checked = false

	# Select 6 random images ensuring type variety (at least 3 different types)
	_round_items.clear()
	var pool: Array[Dictionary] = []
	for item: Dictionary in _pallet_data:
		pool.append(item.duplicate())

	# Ensure at least one of each available type, then fill randomly
	var by_type: Dictionary = {}
	for item: Dictionary in pool:
		var t: String = item.answer
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(item)

	# Pick one random from each type first
	var type_keys: Array = by_type.keys()
	type_keys.shuffle()
	for tk: Variant in type_keys:
		var items: Array = by_type[tk]
		items.shuffle()
		if _round_items.size() < ROUND_SIZE:
			_round_items.append(items[0] as Dictionary)

	# Fill remaining slots from unused pool
	var used_photos: Array[String] = []
	for ri: Dictionary in _round_items:
		used_photos.append(ri.photo)
	pool.shuffle()
	for item: Dictionary in pool:
		if _round_items.size() >= ROUND_SIZE:
			break
		if item.photo not in used_photos:
			_round_items.append(item)
			used_photos.append(item.photo)

	# Final shuffle of positions
	var shuffled: Array[Dictionary] = []
	for item: Dictionary in _round_items:
		shuffled.append(item)
	shuffled.shuffle()
	_round_items = shuffled

	# Populate cells
	for i: int in range(ROUND_SIZE):
		var item: Dictionary = _round_items[i]
		var tex: Texture2D = load(item.photo) as Texture2D
		if tex != null and i < _photo_rects.size():
			_photo_rects[i].texture = tex
		if i < _dropdowns.size():
			_dropdowns[i].select(0)
			_dropdowns[i].disabled = false
		if i < _cell_panels.size():
			UIStyles.apply_panel(_cell_panels[i], UIStyles.flat(
					UITokens.CLR_INPUT_BG, 6, 2, UITokens.CLR_SURFACE_DIM))
		if i < _feedback_labels.size():
			_feedback_labels[i].text = ""
			_feedback_labels[i].visible = false

	_btn_check.visible = true
	_btn_check.disabled = true
	_btn_restart.visible = false
	_result_label.visible = false
	_score_label.text = ""
	# S61 Fix #6: portal rebuild re-parents the portal overlay as the last
	# child of $Root, covering this quiz overlay. Move ourselves to the top
	# of the sibling stack so the quiz is visible and clickable.
	var parent_node: Node = overlay.get_parent()
	if parent_node != null:
		parent_node.move_child(overlay, parent_node.get_child_count() - 1)
	overlay.visible = true


func close_quiz() -> void:
	overlay.visible = false
	_is_active = false


func _on_type_selected(_cell_idx: int) -> void:
	## Called when a dropdown changes. Enable Check if all cells assigned.
	if _checked:
		return
	var all_assigned: bool = true
	for dd: OptionButton in _dropdowns:
		if dd.selected == 0:
			all_assigned = false
			break
	_btn_check.disabled = not all_assigned


func _check_answers() -> void:
	if _checked:
		return
	_checked = true
	var correct_count: int = 0

	for i: int in range(ROUND_SIZE):
		if i >= _round_items.size():
			break
		var expected: String = _round_items[i].answer
		var selected_idx: int = _dropdowns[i].selected
		var selected: String = _type_options[selected_idx] if selected_idx > 0 else ""
		var is_correct: bool = (selected == expected)

		# Lock dropdown
		_dropdowns[i].disabled = true

		# Color the cell border
		if is_correct:
			correct_count += 1
			UIStyles.apply_panel(_cell_panels[i], UIStyles.flat(
					Color(0.08, 0.18, 0.08), 6, 2, UITokens.CLR_SUCCESS))
			_feedback_labels[i].text = "✓"
			_feedback_labels[i].add_theme_color_override("font_color", UITokens.CLR_SUCCESS)
		else:
			UIStyles.apply_panel(_cell_panels[i], UIStyles.flat(
					Color(0.2, 0.08, 0.08), 6, 2, UITokens.CLR_RED_BRIGHT))
			_feedback_labels[i].text = "✗ " + expected
			_feedback_labels[i].add_theme_color_override("font_color", UITokens.CLR_RED_BRIGHT)
		_feedback_labels[i].visible = true

	# Score display
	var pct: float = float(correct_count) / float(ROUND_SIZE) * 100.0
	var clr: String = UITokens.BB_SUCCESS if pct >= 80.0 else (UITokens.BB_WARNING if pct >= 50.0 else UITokens.BB_ERROR)
	_score_label.text = "%d / %d" % [correct_count, ROUND_SIZE]
	_score_label.add_theme_color_override("font_color",
			UITokens.CLR_SUCCESS if pct >= 80.0 else (UITokens.CLR_AMBER if pct >= 50.0 else UITokens.CLR_RED_BRIGHT))

	# Result text
	var grade: String = Locale.t("quiz.grade_excellent") if pct >= 90.0 else (Locale.t("quiz.grade_good") if pct >= 67.0 else Locale.t("quiz.grade_practice"))
	_result_label.text = "[center]" + clr + "[b]" + grade + "[/b]" + UITokens.BB_END + "[/center]"
	_result_label.visible = true

	_btn_check.visible = false
	_btn_restart.visible = true

	if pct >= 80.0:
		WOTSAudio.play_success_chime(_ui)
	elif correct_count > 0:
		WOTSAudio.play_scan_beep(_ui)
	else:
		WOTSAudio.play_error_buzz(_ui)
