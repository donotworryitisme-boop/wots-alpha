class_name AS400Terminal
extends RefCounted

# ==========================================
# AS400 TERMINAL — extracted from BayUI.gd Session 10
# Owns: state machine, screen rendering, input handling, tab system
# ==========================================

# AS400 state machine — maps 1:1 with real AS400 navigation screens
enum S {
	SIGN_ON = 0,           # Username entry
	PASSWORD = 1,          # Password entry
	MENU_MAIN = 2,         # Simplified Menu (PSIP0120)
	MENU_SHIP_DOCK = 3,    # Menu des Applications (after 50)
	MENU_PARCEL = 4,       # Send International Parcel (after 01)
	MENU_OPERATION = 5,    # Menu : Operation (after 02)
	BADGE_LOGIN = 6,       # Badge login popup
	BADGE_PASSWORD = 7,    # Badge password popup
	RAQ = 8,               # DSPF COLIS RAQ/RAC screen
	VALIDATION = 9,        # F10 confirmation screen
	RECEP_DOCK = 15,       # Easter egg: Recep Dock
	IMPRESSION = 16,       # Easter egg: Impression
	RAQ_PAR_MAGASIN = 17,  # Easter egg: RAQ Par Magasin
	SCANNING = 18,         # Scanning screen (primary after badge)
	SAISIE_EXPEDITION = 19, # Saisie d'une expedition (co-loading)
	GE_MENU = 20,          # Easter egg: GE Menu
	AIDE_DECISION = 21,    # Easter egg: Aide a la Decision
	EXPEDITION_EN_COURS = 22, # Expedition en cours (from menu 06)
}

signal raq_opened

var _ui: BayUI  # BayUI reference — for accessing session, tutorial, stores, seals, hover
var _parent: Control  # stage_hbox — where panel is added

# Terminal UI nodes
var panel: PanelContainer
var _display: RichTextLabel
var _input_field: LineEdit
var _tab_bar: HBoxContainer

# State
var state: int = S.SIGN_ON
var error: bool = false
var _badge_target: int = S.SCANNING
var _tabs: Array = []
var _active_tab: int = 0
var wrong_store_scans: int = 0
var last_avail_cache: Array = []
var last_loaded_cache: Array = []
@warning_ignore("unused_private_class_variable")  # Accessed by AS400Screens._term._prev_logged_state
var _prev_logged_state: int = -1
var _screens: AS400Screens

# S61 Fix #4: pinned per-session operator name (was randomized per-render
# from a hash of dest_name, causing the SAISIE operator to flip mid-session).
var session_operator: String = "BENANCIO"

func _init(ui: BayUI, parent: Control) -> void:
	_ui = ui
	_parent = parent
	_screens = AS400Screens.new(self)
	var operators: Array[String] = ["BENANCIO", "LYDIA", "LORENA", "ZUZANNA", "GEORGIOS", "DAMIAN"]
	session_operator = operators[randi() % operators.size()]

func _build_as400_stage() -> void:
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	panel.visible = false

	UIStyles.apply_panel(panel, UIStyles.flat(Color(0, 0, 0)))
	_parent.add_child(panel)

	var as400_vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(as400_vbox)

	# --- Tab bar (browser-style tabs, shown for all sessions) ---
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	_tab_bar.custom_minimum_size = Vector2(0, 30)
	var tab_bar_bg := UIStyles.flat(Color(0.02, 0.06, 0.02))
	tab_bar_bg.border_width_bottom = 1
	tab_bar_bg.border_color = Color(0.0, 0.4, 0.0)
	_tab_bar.add_theme_stylebox_override("panel", tab_bar_bg)
	as400_vbox.add_child(_tab_bar)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	as400_vbox.add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var center_hbox: HBoxContainer = HBoxContainer.new()
	center_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center_hbox)

	# Left spacer pushes text block right to visually center it
	var left_spacer: Control = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(left_spacer)

	_display = RichTextLabel.new()
	_display.bbcode_enabled = true
	_display.fit_content = true
	_display.autowrap_mode = TextServer.AUTOWRAP_OFF
	_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_display.text = ""
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.focus_mode = Control.FOCUS_NONE
	# Use monospace font for authentic AS400 terminal look
	var mono_font: SystemFont = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	_display.add_theme_font_override("normal_font", mono_font)
	_display.add_theme_font_override("bold_font", mono_font)
	center_hbox.add_child(_display)

	# Right spacer balances the left spacer for true centering
	var right_spacer: Control = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(right_spacer)

	var input_bg: ColorRect = ColorRect.new()
	input_bg.color = Color(0, 0, 0)
	input_bg.custom_minimum_size = Vector2(0, 40)
	as400_vbox.add_child(input_bg)

	var input_hbox: HBoxContainer = HBoxContainer.new()
	input_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_bg.add_child(input_hbox)

	var prompt: Label = Label.new()
	prompt.text = " > "
	prompt.add_theme_font_size_override("font_size", UITokens.fs(18))
	prompt.add_theme_color_override("font_color", Color(0, 1, 0))
	var prompt_mono: SystemFont = SystemFont.new()
	prompt_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	prompt.add_theme_font_override("font", prompt_mono)
	input_hbox.add_child(prompt)

	_input_field = LineEdit.new()
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_sb: StyleBoxEmpty = StyleBoxEmpty.new()
	_input_field.add_theme_stylebox_override("normal", input_sb)
	_input_field.add_theme_stylebox_override("focus", input_sb)
	_input_field.add_theme_color_override("font_color", Color(0, 1, 0))
	_input_field.add_theme_font_size_override("font_size", UITokens.fs(18))
	var input_mono: SystemFont = SystemFont.new()
	input_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	_input_field.add_theme_font_override("font", input_mono)

	_input_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_on_as400_input_submitted(_input_field.text)
			_input_field.accept_event()
	)
	_input_field.text_changed.connect(_on_as400_text_changed)
	input_hbox.add_child(_input_field)

	var btn_hbox: HBoxContainer = HBoxContainer.new()
	as400_vbox.add_child(btn_hbox)

	var btn_confirm: Button = Button.new()
	btn_confirm.text = Locale.t("btn.confirm_raq")
	btn_confirm.custom_minimum_size = Vector2(0, 40)
	btn_confirm.focus_mode = Control.FOCUS_NONE
	btn_confirm.add_theme_stylebox_override("normal", UIStyles.flat(Color(0.2, 0.2, 0.2)))
	btn_confirm.pressed.connect(_confirm_as400_raq)
	btn_hbox.add_child(btn_confirm)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if _input_field != null:
				_input_field.call_deferred("grab_focus")
	)

	_render_as400_screen()

func _confirm_as400_raq() -> void:
	if _ui._tc.is_as400_confirm_blocked():
		_ui._tc.try_advance_as400_confirm()
		return
	if _ui.tutorial_active:
		_ui._tc.try_advance_as400_confirm()

	if _ui._session != null:
		var confirm_dest: int = _get_tab_dest_seq(_active_tab)
		if confirm_dest == 0:
			confirm_dest = 1
		_ui._session.manual_decision("Confirm AS400 Dest %d" % confirm_dest)
	if state == S.RAQ or state == S.SCANNING:
		state = S.VALIDATION
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_seal_confirm(_ui)
		# Notify BayUI that AS400 is confirmed — enables close dock
		_ui._as400_confirmed = true
		if _ui.btn_close_dock != null:
			_ui.btn_close_dock.visible = true

# ==========================================
# AS400 TAB SYSTEM
# ==========================================
func _init_tabs() -> void:
	_tabs.clear()
	_active_tab = 0
	_tabs.append({"state": S.SIGN_ON, "badge_target": S.SCANNING, "dest_code": "", "dest_name": "", "seal_entered": "", "error": false})
	_rebuild__tab_bar()

func _save_tab_state() -> void:
	if _tabs.is_empty(): return
	_tabs[_active_tab]["state"] = state
	_tabs[_active_tab]["badge_target"] = _badge_target
	_tabs[_active_tab]["error"] = error

func _load_tab_state() -> void:
	if _tabs.is_empty(): return
	state = _tabs[_active_tab].get("state", S.SIGN_ON)
	_badge_target = _tabs[_active_tab].get("badge_target", S.SCANNING)
	error = _tabs[_active_tab].get("error", false)

func _switch_as400_tab(idx: int) -> void:
	if idx < 0 or idx >= _tabs.size(): return
	if idx == _active_tab: return
	_save_tab_state()
	_active_tab = idx
	_load_tab_state()
	_rebuild__tab_bar()
	_render_as400_screen()
	WOTSAudio.play_as400_key(_ui)

func _add_as400_tab() -> void:
	if _tabs.size() >= 2: return
	if _ui.current_dest2_name == "": return
	_save_tab_state()
	_tabs.append({"state": S.SIGN_ON, "badge_target": S.SCANNING, "dest_code": "", "dest_name": "", "seal_entered": "", "error": false})
	_active_tab = _tabs.size() - 1
	_load_tab_state()
	_rebuild__tab_bar()
	_render_as400_screen()
	WOTSAudio.play_as400_key(_ui)

func _rebuild__tab_bar() -> void:
	if _tab_bar == null: return
	for child: Node in _tab_bar.get_children():
		child.queue_free()

	for i: int in range(_tabs.size()):
		var tab_dict: Dictionary = _tabs[i]
		var tab_btn := Button.new()
		var dest_code_str: String = tab_dict.get("dest_code", "")
		var tab_label: String
		if dest_code_str != "":
			var dname: String = tab_dict.get("dest_name", dest_code_str)
			tab_label = " %s %s " % [dname, dest_code_str]
		else:
			tab_label = " Tab %d " % (i + 1)
		tab_btn.text = tab_label
		tab_btn.focus_mode = Control.FOCUS_NONE
		var is_active: bool = (i == _active_tab)
		var tab_sb := UIStyles.flat(Color(0.05, 0.25, 0.05) if is_active else Color(0.02, 0.08, 0.02))
		tab_sb.border_width_bottom = 0 if is_active else 1
		tab_sb.border_color = Color(0.0, 0.55, 0.0)
		tab_sb.corner_radius_top_left = 4
		tab_sb.corner_radius_top_right = 4
		tab_btn.add_theme_stylebox_override("normal", tab_sb)
		tab_btn.add_theme_stylebox_override("hover", tab_sb)
		tab_btn.add_theme_stylebox_override("pressed", tab_sb)
		tab_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0) if is_active else Color(0.0, 0.65, 0.0))
		tab_btn.add_theme_font_size_override("font_size", UITokens.fs(13))
		var cap_i: int = i
		tab_btn.pressed.connect(func() -> void: _switch_as400_tab(cap_i))
		_tab_bar.add_child(tab_btn)

	# Spacer to push "New Tab" button to right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.add_child(spacer)

	# "New Tab" arrow button — only for co-loading with room for a second tab
	if _ui.current_dest2_name != "" and _tabs.size() < 2:
		var plus_btn := Button.new()
		plus_btn.text = Locale.t("btn.new_tab")
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.tooltip_text = "Open a second tab for %s %s" % [_ui.current_dest2_name, _ui.current_dest2_code]
		var plus_sb := UIStyles.flat(Color(0.03, 0.1, 0.03))
		plus_sb.border_width_bottom = 1
		plus_sb.border_color = Color(0.0, 0.4, 0.0)
		plus_btn.add_theme_stylebox_override("normal", plus_sb)
		plus_btn.add_theme_stylebox_override("hover", plus_sb)
		plus_btn.add_theme_stylebox_override("pressed", plus_sb)
		plus_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 0.0))
		plus_btn.add_theme_font_size_override("font_size", UITokens.fs(13))
		plus_btn.pressed.connect(_add_as400_tab)
		_tab_bar.add_child(plus_btn)

func _get_tab_dest_seq(tab_idx: int) -> int:
	# Returns 1 or 2 (which sequence this tab is scanning for), or 0 if undetermined
	if tab_idx >= _tabs.size(): return 0
	var code: String = _tabs[tab_idx].get("dest_code", "")
	if code == "": return 0
	if code == _ui.current_dest_code: return 1
	if _ui.current_dest2_code != "" and code == _ui.current_dest2_code: return 2
	return 0


func _render_as400_screen() -> void:
	_screens.render()


func _on_as400_text_changed(new_text: String) -> void:
	var input: String = new_text.strip_edges().to_upper()
	if input.is_empty():
		return
	# While in error state, reject all input with buzz until F3
	if error:
		_input_field.text = ""
		WOTSAudio.play_error_buzz(_ui)
		return
	# Auto-advance for menu states — no Enter needed, just type the number
	var auto_submit: bool = false
	if state == S.MENU_MAIN and input in ["50", "40", "20"]: auto_submit = true
	elif state == S.MENU_SHIP_DOCK and input == "01": auto_submit = true
	elif state == S.MENU_PARCEL and input == "02": auto_submit = true
	elif state == S.MENU_OPERATION and input in ["05", "06"]: auto_submit = true
	elif state == S.GE_MENU and input == "1": auto_submit = true
	if auto_submit:
		# Defer so the text_changed signal finishes cleanly
		(func() -> void: _on_as400_input_submitted(new_text)).call_deferred()
		return
	# Wrong input at expected length → error state (like real AS400)
	var expected_len: int = -1
	if state in [S.MENU_MAIN, S.MENU_SHIP_DOCK, S.MENU_PARCEL, S.MENU_OPERATION]: expected_len = 2
	elif state == S.GE_MENU: expected_len = 1
	if expected_len > 0 and input.length() >= expected_len:
		_input_field.text = ""
		error = true
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_error_buzz(_ui)

func _on_as400_input_submitted(text: String) -> void:
	var input: String = text.strip_edges().to_upper()
	_input_field.text = ""

	# While in error state, reject all input with buzz until F3
	if error:
		WOTSAudio.play_error_buzz(_ui)
		return

	if input.is_empty():
		return

	var state_before: int = state

	if state == S.SIGN_ON:
		if input == "BAYB2B": state = S.PASSWORD
	elif state == S.PASSWORD:
		if input == "123456": state = S.MENU_MAIN
	elif state == S.MENU_MAIN:
		if input == "50": state = S.MENU_SHIP_DOCK
		elif input == "40": state = S.RECEP_DOCK
		elif input == "20": state = S.GE_MENU
	elif state == S.MENU_SHIP_DOCK:
		if input == "01": state = S.MENU_PARCEL
	elif state == S.MENU_PARCEL:
		if input == "02": state = S.MENU_OPERATION
	elif state == S.MENU_OPERATION:
		if input == "05": state = S.EXPEDITION_EN_COURS
		elif input == "06": state = S.EXPEDITION_EN_COURS
	elif state == S.EXPEDITION_EN_COURS:
		if input == "F6":
			_badge_target = S.SAISIE_EXPEDITION
			state = S.BADGE_LOGIN
		elif input == "F3":
			state = S.MENU_OPERATION
	elif state == S.BADGE_LOGIN:
		if input == "8600555": state = S.BADGE_PASSWORD
	elif state == S.BADGE_PASSWORD:
		if input == "123456": state = _badge_target
	elif state == S.SAISIE_EXPEDITION:
		if input == "F10":
			# For co-loading or tutorial: require destinataire first
			# Require dest for ALL scenarios
			var tab_code: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
			if tab_code == "":
				if _ui._dock.lbl_hover_info:
					_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire requis![/b] " + Locale.t("as400.dest_required") + "[/color][/font_size]"
				_save_tab_state()
				_render_as400_screen()
				return
			# Require seal to be entered for ALL scenarios
			var tab_seal: String = _tabs[_active_tab].get("seal_entered", "") if not _tabs.is_empty() else ""
			if tab_seal == "":
				if _ui._dock.lbl_hover_info:
					_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Seal number requis![/b] " + Locale.t("as400.seal_required") + "[/color][/font_size]"
				_save_tab_state()
				_render_as400_screen()
				return
			state = S.SCANNING
		elif input == "F3":
			state = S.EXPEDITION_EN_COURS
		else:
			# Determine what the user is entering based on current stage
			var tab_code_cur: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
			var tab_seal_cur: String = _tabs[_active_tab].get("seal_entered", "") if not _tabs.is_empty() else ""
			# Dest first for all scenarios, then seal
			if tab_code_cur == "":
				_handle_saisie_dest_input(input)
				_save_tab_state()
				_render_as400_screen()
				WOTSAudio.play_as400_key(_ui)
				return
			# All scenarios: seal entry after dest is set
			if tab_seal_cur == "":
				_handle_saisie_seal_input(input)
				_save_tab_state()
				_render_as400_screen()
				WOTSAudio.play_as400_key(_ui)
				return
	elif state == S.SCANNING:
		if input == "F3": state = S.MENU_OPERATION
		elif input == "SHIFT+F1":
			state = S.RAQ
			raq_opened.emit()
	elif state == S.RAQ:
		if input == "F3": state = S.SCANNING
	elif state == S.VALIDATION and input == "F3": state = S.EXPEDITION_EN_COURS
	elif state == S.RECEP_DOCK and input == "F3": state = S.MENU_MAIN
	elif state == S.IMPRESSION and input == "F3": state = S.MENU_OPERATION
	elif state == S.RAQ_PAR_MAGASIN and input == "F3": state = S.MENU_OPERATION
	elif state == S.GE_MENU:
		if input == "1": state = S.AIDE_DECISION
		elif input == "F3": state = S.MENU_MAIN
	elif state == S.AIDE_DECISION and input == "F3": state = S.GE_MENU

	# Wrong input on login or menu states → error lock (like real AS400)
	# If state didn't change and we're on a screen that expects specific input, it's an error
	if state == state_before and state in [S.SIGN_ON, S.PASSWORD, S.MENU_MAIN, S.MENU_SHIP_DOCK, S.MENU_PARCEL, S.MENU_OPERATION, S.BADGE_LOGIN, S.BADGE_PASSWORD, S.GE_MENU, S.AIDE_DECISION, S.EXPEDITION_EN_COURS]:
		error = true
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_error_buzz(_ui)
		return

	_save_tab_state()
	_render_as400_screen()
	WOTSAudio.play_as400_key(_ui)

	if _ui.tutorial_active:
		_ui._tc.try_advance_as400_state(state)

func _handle_saisie_dest_input(input: String) -> void:
	if _tabs.is_empty(): return
	# Find store by code
	var matched_store: Dictionary = {}
	for s: Dictionary in _ui.store_destinations:
		if s.code == input:
			matched_store = s
			break
	if matched_store.is_empty():
		if _ui._dock.lbl_hover_info:
			_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire inconnu:[/b] " + (Locale.t("as400.dest_unknown") % input) + "[/color][/font_size]"
		return
	# For co-loading: must be one of the two assigned stores
	if _ui.current_dest2_name != "":
		if input != _ui.current_dest_code and input != _ui.current_dest2_code:
			if _ui._dock.lbl_hover_info:
				_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire incorrect:[/b] " + (Locale.t("as400.dest_wrong_truck") % input) + "[/color][/font_size]"
			return
		# Check if other tab already claimed this store
		for i: int in range(_tabs.size()):
			if i == _active_tab: continue
			if _tabs[i].get("dest_code", "") == input:
				if _ui._dock.lbl_hover_info:
					_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Already open:[/b] " + (Locale.t("as400.dest_already_open") % input) + "[/color][/font_size]"
				return
	else:
		# Solo loading (including tutorial): must match the assigned store
		if input != _ui.current_dest_code:
			if _ui._dock.lbl_hover_info:
				_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire incorrect:[/b] " + (Locale.t("as400.dest_wrong_truck") % input) + "[/color][/font_size]"
			return
	_tabs[_active_tab]["dest_code"] = matched_store.code
	_tabs[_active_tab]["dest_name"] = matched_store.name
	if _ui._session != null:
		_ui._session.log_action("as400_dest", "%d:%s:%s" % [_active_tab, matched_store.code, matched_store.name])
	_rebuild__tab_bar()
	if _ui._dock.lbl_hover_info:
		# Always show "enter seal" hint — seal is never auto-filled
		_ui._dock.lbl_hover_info.text = "[font_size=15][color=#2ecc71][b]Destinataire OK:[/b] %s %s — " % [matched_store.name, matched_store.code] + Locale.t("as400.dest_ok_enter_seal") + "[/color][/font_size]"

func _handle_saisie_seal_input(input: String) -> void:
	if _tabs.is_empty(): return
	var tab_seq: int = _get_tab_dest_seq(_active_tab)
	var expected_seal: String = ""
	if tab_seq == 1:
		expected_seal = _ui.seal_number_1
	elif tab_seq == 2:
		expected_seal = _ui.seal_number_2
	elif tab_seq == 0:
		# Solo loading — always _ui.seal_number_1
		expected_seal = _ui.seal_number_1
	if input == expected_seal:
		_tabs[_active_tab]["seal_entered"] = input
		if _ui._session != null:
			_ui._session.log_action("as400_seal", "%d:%s" % [_active_tab, input])
		if _ui._dock.lbl_hover_info:
			_ui._dock.lbl_hover_info.text = "[font_size=15][color=#2ecc71][b]Seal OK:[/b] %s — " % input + Locale.t("as400.seal_ok") + "[/color][/font_size]"
	else:
		if _ui._dock.lbl_hover_info:
			_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Seal incorrect:[/b] " + (Locale.t("as400.seal_incorrect") % input) + "[/color][/font_size]"


# ==========================================
# F-KEY HANDLER — called from BayUI._input()
# Returns true if the key was handled
# ==========================================
func handle_fkey(keycode: int, shift_pressed: bool) -> bool:
	if panel == null or not panel.visible:
		return false

	if keycode == KEY_F3:
		if error:
			error = false
			_input_field.text = ""
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
		elif state == S.VALIDATION: state = S.EXPEDITION_EN_COURS; _save_tab_state(); _render_as400_screen()
		elif state == S.RAQ: state = S.SCANNING; _save_tab_state(); _render_as400_screen()
		elif state == S.RECEP_DOCK: state = S.MENU_MAIN; _save_tab_state(); _render_as400_screen()
		elif state == S.IMPRESSION: state = S.MENU_OPERATION; _save_tab_state(); _render_as400_screen()
		elif state == S.RAQ_PAR_MAGASIN: state = S.MENU_OPERATION; _save_tab_state(); _render_as400_screen()
		elif state == S.SCANNING: state = S.MENU_OPERATION; _save_tab_state(); _render_as400_screen()
		elif state == S.SAISIE_EXPEDITION: state = S.EXPEDITION_EN_COURS; _save_tab_state(); _render_as400_screen()
		elif state == S.GE_MENU: state = S.MENU_MAIN; _save_tab_state(); _render_as400_screen()
		elif state == S.AIDE_DECISION: state = S.GE_MENU; _save_tab_state(); _render_as400_screen()
		elif state == S.EXPEDITION_EN_COURS: state = S.MENU_OPERATION; _save_tab_state(); _render_as400_screen()
		elif state > 2: state -= 1; _save_tab_state(); _render_as400_screen()
		return true

	elif keycode == KEY_F10:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == S.SAISIE_EXPEDITION:
			# Require dest for ALL scenarios
			var tab_code: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
			if tab_code == "":
				if _ui._dock.lbl_hover_info:
					_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Destinataire requis![/b] " + Locale.t("as400.dest_required") + "[/color][/font_size]"
				return true
			# Require seal for ALL scenarios
			var tab_seal: String = _tabs[_active_tab].get("seal_entered", "") if not _tabs.is_empty() else ""
			if tab_seal == "":
				if _ui._dock.lbl_hover_info:
					_ui._dock.lbl_hover_info.text = "[font_size=15][color=#e74c3c][b]Seal number requis![/b] " + Locale.t("as400.seal_required") + "[/color][/font_size]"
				return true
			state = S.SCANNING
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
			if _ui.tutorial_active and _ui.tutorial_step == 7:
				_ui._tc.try_advance_as400_seal_entered()
		else:
			_confirm_as400_raq()
		return true

	elif keycode == KEY_F6:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == S.EXPEDITION_EN_COURS:
			_badge_target = S.SAISIE_EXPEDITION
			state = S.BADGE_LOGIN
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
		return true

	elif keycode == KEY_F1 and shift_pressed:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == S.SCANNING:
			state = S.RAQ
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
			raq_opened.emit()
			if _ui.tutorial_active:
				_ui._tc.try_advance_as400_raq_opened()
		return true

	return false

func grab_input_focus() -> void:
	if _input_field != null:
		_input_field.call_deferred("grab_focus")


func release_input_focus() -> void:
	if _input_field != null and _input_field.has_focus():
		_input_field.release_focus()
