class_name AS400Terminal
extends RefCounted

# ==========================================
# AS400 TERMINAL — extracted from BayUI.gd Session 10
# Owns: state machine, screen rendering, input handling, tab system
# ==========================================

signal raq_opened

var _ui: Node  # BayUI reference — for accessing session, tutorial, stores, seals, hover
var _parent: Control  # stage_hbox — where panel is added

# Terminal UI nodes
var panel: PanelContainer
var _display: RichTextLabel
var _input_field: LineEdit
var _tab_bar: HBoxContainer

# State
var state: int = 0
var error: bool = false
var _badge_target: int = 18
var _tabs: Array = []
var _active_tab: int = 0
var wrong_store_scans: int = 0
var last_avail_cache: Array = []
var last_loaded_cache: Array = []

func _init(ui: Node, parent: Control) -> void:
	_ui = ui
	_parent = parent

func _build_as400_stage() -> void:
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	panel.visible = false 
	
	var as400_sb = StyleBoxFlat.new()
	as400_sb.bg_color = Color(0, 0, 0) 
	panel.add_theme_stylebox_override("panel", as400_sb)
	_parent.add_child(panel)
	
	var as400_vbox = VBoxContainer.new()
	panel.add_child(as400_vbox)

	# --- Tab bar (browser-style tabs, shown for all sessions) ---
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	_tab_bar.custom_minimum_size = Vector2(0, 30)
	var tab_bar_bg := StyleBoxFlat.new()
	tab_bar_bg.bg_color = Color(0.02, 0.06, 0.02)
	tab_bar_bg.border_width_bottom = 1
	tab_bar_bg.border_color = Color(0.0, 0.4, 0.0)
	_tab_bar.add_theme_stylebox_override("panel", tab_bar_bg)
	as400_vbox.add_child(_tab_bar)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	as400_vbox.add_child(scroll)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var center_hbox = HBoxContainer.new()
	center_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center_hbox)

	# Left spacer pushes text block right to visually center it
	var left_spacer = Control.new()
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
	var mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	_display.add_theme_font_override("normal_font", mono_font)
	_display.add_theme_font_override("bold_font", mono_font)
	center_hbox.add_child(_display)

	# Right spacer balances the left spacer for true centering
	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hbox.add_child(right_spacer)

	var input_bg = ColorRect.new()
	input_bg.color = Color(0, 0, 0)
	input_bg.custom_minimum_size = Vector2(0, 40)
	as400_vbox.add_child(input_bg)
	
	var input_hbox = HBoxContainer.new()
	input_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_bg.add_child(input_hbox)
	
	var prompt = Label.new()
	prompt.text = " > "
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0))
	var prompt_mono = SystemFont.new()
	prompt_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	prompt.add_theme_font_override("font", prompt_mono)
	input_hbox.add_child(prompt)
	
	_input_field = LineEdit.new()
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_sb = StyleBoxEmpty.new()
	_input_field.add_theme_stylebox_override("normal", input_sb)
	_input_field.add_theme_stylebox_override("focus", input_sb)
	_input_field.add_theme_color_override("font_color", Color(0, 1, 0))
	_input_field.add_theme_font_size_override("font_size", 18)
	var input_mono = SystemFont.new()
	input_mono.font_names = PackedStringArray(["Courier New", "Consolas", "Liberation Mono", "monospace"])
	_input_field.add_theme_font_override("font", input_mono)
	
	_input_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_on_as400_input_submitted(_input_field.text)
			_input_field.accept_event() 
	)
	_input_field.text_changed.connect(_on_as400_text_changed)
	input_hbox.add_child(_input_field)

	var btn_hbox = HBoxContainer.new()
	as400_vbox.add_child(btn_hbox)
	
	var btn_confirm = Button.new()
	btn_confirm.text = Locale.t("btn.confirm_raq")
	btn_confirm.custom_minimum_size = Vector2(0, 40)
	btn_confirm.focus_mode = Control.FOCUS_NONE 
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.2, 0.2, 0.2)
	btn_confirm.add_theme_stylebox_override("normal", btn_sb)
	btn_confirm.pressed.connect(_confirm_as400_raq)
	btn_hbox.add_child(btn_confirm)
	
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if _input_field != null:
				_input_field.call_deferred("grab_focus")
	)

	_render_as400_screen()

func _confirm_as400_raq() -> void:
	if _ui.tutorial_active:
		if _ui.tutorial_step < 14:
			_ui._tut.flash_warning(Locale.t("warn.finish_loading_first"))
			return
		elif _ui.tutorial_step == 14:
			_ui.tutorial_step = 15
			_ui._tut.update_ui()

	if _ui._session != null:
		var confirm_dest: int = _get_tab_dest_seq(_active_tab)
		if confirm_dest == 0:
			confirm_dest = 1
		_ui._session.call("manual_decision", "Confirm AS400 Dest %d" % confirm_dest)
	if state == 8 or state == 18:
		state = 9
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_seal_confirm(_ui)

# ==========================================
# AS400 TAB SYSTEM
# ==========================================
func _init_tabs() -> void:
	_tabs.clear()
	_active_tab = 0
	_tabs.append({"state": 0, "badge_target": 18, "dest_code": "", "dest_name": "", "seal_entered": "", "error": false})
	_rebuild__tab_bar()

func _save_tab_state() -> void:
	if _tabs.is_empty(): return
	_tabs[_active_tab]["state"] = state
	_tabs[_active_tab]["badge_target"] = _badge_target
	_tabs[_active_tab]["error"] = error

func _load_tab_state() -> void:
	if _tabs.is_empty(): return
	state = _tabs[_active_tab].get("state", 0)
	_badge_target = _tabs[_active_tab].get("badge_target", 18)
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
	_tabs.append({"state": 0, "badge_target": 18, "dest_code": "", "dest_name": "", "seal_entered": "", "error": false})
	_active_tab = _tabs.size() - 1
	_load_tab_state()
	_rebuild__tab_bar()
	_render_as400_screen()
	WOTSAudio.play_as400_key(_ui)

func _rebuild__tab_bar() -> void:
	if _tab_bar == null: return
	for child in _tab_bar.get_children():
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
		var tab_sb := StyleBoxFlat.new()
		tab_sb.bg_color = Color(0.05, 0.25, 0.05) if is_active else Color(0.02, 0.08, 0.02)
		tab_sb.border_width_bottom = 0 if is_active else 1
		tab_sb.border_color = Color(0.0, 0.55, 0.0)
		tab_sb.corner_radius_top_left = 4
		tab_sb.corner_radius_top_right = 4
		tab_btn.add_theme_stylebox_override("normal", tab_sb)
		tab_btn.add_theme_stylebox_override("hover", tab_sb)
		tab_btn.add_theme_stylebox_override("pressed", tab_sb)
		tab_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0) if is_active else Color(0.0, 0.65, 0.0))
		tab_btn.add_theme_font_size_override("font_size", 13)
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
		var plus_sb := StyleBoxFlat.new()
		plus_sb.bg_color = Color(0.03, 0.1, 0.03)
		plus_sb.border_width_bottom = 1
		plus_sb.border_color = Color(0.0, 0.4, 0.0)
		plus_btn.add_theme_stylebox_override("normal", plus_sb)
		plus_btn.add_theme_stylebox_override("hover", plus_sb)
		plus_btn.add_theme_stylebox_override("pressed", plus_sb)
		plus_btn.add_theme_color_override("font_color", Color(0.0, 0.85, 0.0))
		plus_btn.add_theme_font_size_override("font_size", 13)
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

# Converts "DD/MM/YYYY" → "DDMMYY" for compact AS400 display
func _date_compact(ddate: String) -> String:
	if ddate == "": return "250326"
	var parts: PackedStringArray = ddate.split("/")
	if parts.size() == 3:
		return parts[0] + parts[1] + parts[2].right(2)
	return ddate

func _build_deca_art(art_rows: Array, fg_color: String) -> String:
	var bg_c := "[color=#000000]"
	var fg_c := fg_color
	var E := "[/color]"
	# Single-width pixels at large font, each row rendered twice for vertical thickness
	var out := "[center][font_size=36]"
	for row in art_rows:
		for _dup in range(2):
			var i := 0
			while i < row.length():
				var ch: String = row[i]
				var run := 1
				while i + run < row.length() and row[i + run] == ch:
					run += 1
				if ch == "1":
					out += fg_c + "█".repeat(run) + E
				else:
					out += bg_c + "█".repeat(run) + E
				i += run
			out += "\n"
	out += "[/font_size][/center]"
	return out

# Pixel-art digit patterns (5 wide x 5 tall, using * like real AS400)
const DIGIT_ART: Dictionary = {
	"0": [" *** ","*   *","*   *","*   *"," *** "],
	"1": ["  *  ","  *  ","  *  ","  *  ","  *  "],
	"2": [" *** ","    *"," *** ","*    "," *** "],
	"3": [" *** ","    *"," *** ","    *"," *** "],
	"4": ["*   *","*   *"," *** ","    *","    *"],
	"5": [" *** ","*    "," *** ","    *"," *** "],
	"6": [" *** ","*    "," *** ","*   *"," *** "],
	"7": [" *** ","    *","    *","    *","    *"],
	"8": [" *** ","*   *"," *** ","*   *"," *** "],
	"9": [" *** ","*   *"," *** ","    *"," *** "],
}

func _build_number_art(num: int, _digits: int, color: String) -> Array:
	var s := str(num)
	var rows: Array = ["", "", "", "", ""]
	for i in range(s.length()):
		if i > 0:
			for r in range(5): rows[r] += " "
		var d: String = s[i]
		var art: Array = DIGIT_ART.get(d, DIGIT_ART["0"])
		for r in range(5):
			rows[r] += art[r]
	var result: Array = []
	for row in rows:
		var line := ""
		for ch in row:
			if ch == "*":
				line += color + "*[/color]"
			else:
				line += " "
		result.append(line)
	return result

func _render_as400_screen() -> void:
	if _display == null: return
	# --- DECATHLON pixel art (all chars are █, color switches between filled and bg) ---
	# This guarantees alignment regardless of proportional/monospace font
	var _deca_art := [
		"11100111100111001100111101001010000011001001",
		"10010100001000010010011001001010000100101101",
		"10010111001000011110011001111010000100101011",
		"10010100001000010010011001001010000100101001",
		"11100111100111010010011001001011110011001001",
	]
	var t = "[font_size=24]"
	var d = "19/03/26"
	var H = "[color=#00ff00]"
	var C = "[color=#00ffff]"
	var Y = "[color=#ffff00]"
	var W = "[color=#ffffff]"
	var R = "[color=#ff0000]"
	var P = "[color=#ff88aa]"
	var B = "[color=#8888ff]"
	var E = "[/color]"
	
	# State 0: Sign On — DECATHLON
	if state == 0:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %s_________%s[/center]\n" % [P, E, Y, E]
		t += "[center]%sPassword  . . . . . . . . . .%s[/center]\n\n" % [P, E]
		t += "[/font_size]" + _build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		_input_field.placeholder_text = "Type 'BAYB2B' and press Enter"

	# State 1: Sign On password
	elif state == 1:
		t += "[center]%sSign On%s[/center]\n\n" % [W, E]
		t += "[center]%sSystem . . . . . :   NLDKL01%s[/center]\n" % [H, E]
		t += "[center]%sSub-system . . . :   QINTER%s[/center]\n" % [H, E]
		t += "[center]%sScreen . . . . . :   TILBN1117%s[/center]\n\n" % [H, E]
		t += "[center]%sUser  . . . . . . . . . . . .%s   %sBAYB2B%s[/center]\n" % [P, E, H, E]
		t += "[center]%sPassword  . . . . . . . . . .%s   %s______%s[/center]\n\n" % [P, E, Y, E]
		t += "[/font_size]" + _build_deca_art(_deca_art, B) + "[font_size=24]\n"
		t += "[center]%s(C) COPYRIGHT IBM CORP. 1980, 2018.%s[/center]\n" % [W, E]
		_input_field.placeholder_text = "Type '123456' and press Enter"

	# State 2: Simplified Menu (PSIP0120) — all right items start at col 48
	elif state == 2:
		t += "%s%s%s   %s***%s       %s[u]Simplified Men[/u]%s        %s***%s %sDKOSUT01%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:16:23%s                    %sPSIP0120%s           %sENTER%s   %sSOHKPVR%s\n" % [H, E, Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                      %sProfession Opt%s\n" % [C, E]
		t += "                                                %s10  Change%s\n" % [H, E]
		t += "                                                    %sPassword%s\n" % [H, E]
		t += "  %s 1%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 2%s  %s-%s                                         %s20  GE Menu%s\n" % [Y, E, H, E, H, E]
		t += "  %s 3%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s 4%s  %s-%s                                         %s30  PARCELx%s\n" % [Y, E, H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n" % [H, E]
		t += "                  %sOwn Options%s                   %s40  Recep Dock%s  %s390%s\n\n" % [C, E, H, E, Y, E]
		t += "  %s11%s  %s-%s                                         %s50  Ship Dock%s   %s390%s\n" % [Y, E, H, E, H, E, Y, E]
		t += "  %s12%s  %s-%s\n" % [Y, E, H, E]
		t += "  %s13%s  %s-%s                                         %s80  Modification%s\n" % [Y, E, H, E, H, E]
		t += "  %s14%s  %s-%s                                             %sOwn Options%s\n" % [Y, E, H, E, H, E]
		t += "  %s15%s  %s-%s\n" % [Y, E, H, E]
		t += "                                                %s90  End of cession%s\n\n" % [H, E]
		t += "                %sYour Choice%s %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Exit  F10=Reinit Docks%s\n" % [C, E]
		_input_field.placeholder_text = "Type '50' for Ship Dock"

	# State 3: MENU DES APPLICATIONS (after typing 50 — Ship Dock)
	elif state == 3:
		t += "%s19:29:15%s              %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   EXPEDITION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "      %s2%s  %s-   RECEPTION COLIS INTERNATIONAL%s\n" % [Y, E, H, E]
		t += "\n\n\n\n\n\n\n\n\n\n"
		t += "              %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]
		_input_field.placeholder_text = "Type '01' for Expedition"

	# State 4: SEND AN INTERNATIONAL PARCEL / MENU01 (after typing 01)
	elif state == 4:
		t += "%s19:29:26%s          %s[u]SEND AN INTERNATIONAL PARCEL[/u]%s       %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s1%s                                                     %sMENU01%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s  %s-   Param{trage%s\n\n" % [Y, E, H, E]
		t += "      %s2%s  %s-%s   %s[u]: menu : Operation[/u]%s\n\n" % [Y, E, H, E, C, E]
		t += "      %s3%s  %s-   Menu : Export%s\n\n" % [Y, E, H, E]
		t += "      %s4%s  %s-   : menu : Utilities%s\n\n" % [Y, E, H, E]
		t += "      %s5%s  %s-   Piloting Parcel%s\n\n" % [Y, E, H, E]
		t += "      %s6%s  %s-   Enter a Transit Flow 4%s\n\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "                                           %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]
		_input_field.placeholder_text = "Type '02' for Operation menu"

	# State 5: MENU : OPERATION / MENU03 (after typing 02)
	elif state == 5:
		t += "%s19:29:36%s              %s[u]: MENU : OPERATION[/u]%s              %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "  %s2%s                                                     %sMENU03%s\n\n" % [Y, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1%s   %s-   Delete UAT%s\n" % [Y, E, H, E]
		t += "      %s2%s   %s-   Create UAT (regroup parcels)%s\n" % [Y, E, H, E]
		t += "      %s3%s   %s-   CFP : Control UAT%s\n" % [Y, E, H, E]
		t += "      %s4%s   %s-   : Menu : Addressing UAT%s\n" % [Y, E, H, E]
		t += "      %s5%s   %s-   Create shipment%s\n" % [Y, E, H, E]
		t += "      %s6%s   %s-   Manage shipping%s\n\n" % [Y, E, H, E]
		t += "      %s7%s   %s-   Visualize left on loading bay%s\n" % [Y, E, H, E]
		t += "      %s8%s   %s-   Visualize RAQ Worldwide Warehouse%s\n" % [Y, E, H, E]
		t += "      %s9%s   %s-   Visualize a parcel%s\n\n" % [Y, E, H, E]
		t += "      %s10%s  %s-   Menu : dangerous substances%s\n" % [Y, E, H, E]
		t += "      %s11%s  %s-   Transport schedule%s\n\n" % [Y, E, H, E]
		t += "              %sVotre choix :%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent F16=Premier menu%s\n" % [C, E]
		_input_field.placeholder_text = "Type '05' for Create shipment, or '06' for Manage shipping"

	# State 6: Badge login popup (overlaying EXPEDITION EN COURS)
	elif state == 6:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s_______%s               │\n" % [H, E, Y, E]
		t += "         │ %sNom            :%s                         │\n" % [H, E]
		t += "         │ %sPrénom         :%s                         │\n" % [H, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		var exp_dest = _ui.current_dest_name
		if _ui.current_dest2_name != "":
			exp_dest = _ui.current_dest_name + "/" + _ui.current_dest2_name
		t += "%s__  06948174 XXXXXXXX    7 %5s %-18s   EN COURS%s\n" % [H, _ui.current_dest_code, exp_dest, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB EN COURS%s\n" % [H, E]
		t += "\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Créer%s                                                %sAIDE%s\n" % [C, E, C, E]
		_input_field.placeholder_text = "Type '8600555' (your badge code)"

	# State 7: Badge password (overlaying EXPEDITION EN COURS)
	elif state == 7:
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur :   14    390 CAR%s\n" % [H, E]
		t += "         ┌─────────────────────────────────────────┐\n"
		t += "         │ %sCode opé/badge:%s  %s8600555%s               │\n" % [H, E, H, E]
		t += "         │ %sMot de passe  :%s  %s______%s                │\n" % [H, E, Y, E]
		t += "         │                                         │\n"
		t += "         │ %sF3:Retour   F6:Chgt Mot Passe%s          │\n" % [H, E]
		t += "         └─────────────────────────────────────────┘\n"
		_input_field.placeholder_text = "Type '123456' (your password)"

	# State 8: RAQ screen (DSPF COLIS RAQ/RAC) — matches real AS400 layout
	elif state == 8:
		_input_field.placeholder_text = "N° Colis ou UAT — F10 to confirm, F3=Back to Scanning"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:25%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		# Filter RAQ to active tab's destination sequence (0 = no filter for single-store)
		var raq_seq_filter: int = _get_tab_dest_seq(_active_tab)
		# Combine all pallets (loaded + available) — RAQ is the full shipment manifest
		var all_raq_pallets: Array = []
		for p: Dictionary in last_avail_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
			if p.is_uat: all_raq_pallets.append(p)
		for p: Dictionary in last_loaded_cache:
			if raq_seq_filter > 0 and p.get("dest", 1) != raq_seq_filter: continue
			all_raq_pallets.append(p)
		var total_colis: int = 0
		for p: Dictionary in all_raq_pallets:
			total_colis += p.collis
		t += "%sExp{diteur   :   14    390   CAR TILBURG EXPE%s       %sTotal colis :   %d%s\n" % [H, E, H, total_colis, E]
		if _ui.current_dest2_name != "":
			var raq_tab_code: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
			var raq_tab_name: String = _tabs[_active_tab].get("dest_name", "") if not _tabs.is_empty() else ""
			if raq_tab_code != "":
				var raq_seq: int = _get_tab_dest_seq(_active_tab)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, raq_tab_code, raq_tab_name, Y, raq_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, _ui.current_dest_code, _ui.current_dest_name, E]
		t += "%s5=D{tail Colis/UAT   7=Validation UAT transit vocal%s\n\n" % [C, E]
		t += "%s? N{ U.A.T                  Flx Uni NBC SE EM Colis                  Dt Col  CCC/%s\n" % [H, E]
		t += "%s                              CFP     CD                       Dt Exp Adresse%s\n" % [H, E]
		var se_map: Dictionary = {"Mecha": "86", "Bulky": "90", "Bikes": "89", "ServiceCenter": "86", "C&C": "86", "ADR": "86"}
		var uni_map: Dictionary = {"Mecha": "62*", "Bulky": "10 ", "Bikes": "63*", "ServiceCenter": "02*", "C&C": "61*", "ADR": "62*"}
		var em_map: Dictionary = {"Mecha": "11", "Bulky": "11", "Bikes": "11", "ServiceCenter": "11", "C&C": "11", "ADR": "11"}
		# --- Build all RAQ rows, then sort: scanned (with time) on top, unscanned below ---
		# Check if everything is scanned (all pallets loaded, transit collected, ADR collected)
		var has_unscanned: bool = false
		for p: Dictionary in all_raq_pallets:
			if p.get("scan_time", "") == "":
				has_unscanned = true
				break
		var transit_pending: bool = (_ui._session != null and not _ui._session.transit_collected and (_ui._session.transit_loose_entries.size() > 0 or _ui._session.transit_items.size() > 0))
		var adr_in_locker: bool = (_ui._session != null and _ui._session.has_adr and _ui._session.adr_items.size() > 0)
		var all_cleared: bool = (not has_unscanned and not transit_pending and not adr_in_locker)
		if all_cleared:
			t += "\n%s  [SHIPMENT COMPLETE — ALL ITEMS SCANNED]%s\n\n" % [Y, E]
		else:
			# Separate scanned and unscanned pallets (excluding ADR — handled separately)
			# Within each group, C&C always goes to the bottom (last loaded = near doors)
			var scanned_regular: Array = []
			var scanned_cc: Array = []
			var unscanned_regular: Array = []
			var unscanned_cc: Array = []
			for p: Dictionary in all_raq_pallets:
				if p.type == "ADR": continue
				var stime: String = p.get("scan_time", "")
				if stime != "":
					if p.type == "C&C": scanned_cc.append(p)
					else: scanned_regular.append(p)
				else:
					if p.type == "C&C": unscanned_cc.append(p)
					else: unscanned_regular.append(p)
			# Render scanned pallets first (at top, with scan time) — C&C at bottom of scanned group
			for p: Dictionary in scanned_regular:
				var stime: String = p.get("scan_time", "")
				var se: String = se_map.get(p.type, "86")
				var uni: String = uni_map.get(p.type, "02*")
				var em: String = em_map.get(p.type, "11")
				var date_col: String = _date_compact(p.get("delivery_date", ""))
				t += "%s  %-20s  MAG %s   0 %s %s %-20s %s %s%s\n" % [H, p.id, uni, se, em, p.get("colis_id", "N/A"), date_col, stime, E]
			for p: Dictionary in scanned_cc:
				var stime: String = p.get("scan_time", "")
				t += "%s  %-20s  MAP 10    0 86 11 %-20s 250326 %s%s\n" % [H, p.id, p.get("colis_id", "N/A"), stime, E]
			# Render unscanned pallets below (no time) — C&C at bottom of unscanned group
			for p: Dictionary in unscanned_regular:
				var se: String = se_map.get(p.type, "86")
				var uni: String = uni_map.get(p.type, "02*")
				var em: String = em_map.get(p.type, "11")
				var date_col: String = _date_compact(p.get("delivery_date", ""))
				t += "%s  %-20s  MAG %s   0 %s %s %-20s %s%s\n" % [C, p.id, uni, se, em, p.get("colis_id", "N/A"), date_col, E]
			for p: Dictionary in unscanned_cc:
				var row_color: String = W if not p.get("missing", false) else R
				t += "%s  %-20s  MAP 10    0 86 11 %-20s 250326%s\n" % [row_color, p.id, p.get("colis_id", "N/A"), E]
			# Transit: loose collis entries — no UAT number, no label (user identifies by missing UAT)
			if _ui._session != null and not _ui._session.transit_collected:
				for entry: Dictionary in _ui._session.transit_loose_entries:
					var e_dest: int = entry.get("dest", 1)
					if raq_seq_filter > 0 and e_dest != raq_seq_filter: continue
					t += "%s  %-20s  MAG ---   -- -- -- %-20s%s\n" % [C, "", entry.get("colis_id", "N/A"), E]
			# Transit UATs not yet collected — no label
			if _ui._session != null and not _ui._session.transit_collected:
				for p_tr: Dictionary in _ui._session.transit_items:
					var p_tr_dest: int = p_tr.get("dest", 1)
					if _ui.current_dest2_name != "":
						var tr_seq: int = _get_tab_dest_seq(_active_tab)
						if tr_seq > 0 and p_tr_dest != tr_seq:
							continue
					t += "%s  %-20s  MAP ---   0 86 -- %-20s%s\n" % [C, p_tr.id, p_tr.get("colis_id", ""), E]
			# ADR rows — always red; in locker until collected, then on dock or loaded
			if _ui._session != null and _ui._session.has_adr:
				for p_adr: Dictionary in _ui._session.adr_items:
					var p_adr_dest: int = p_adr.get("dest", 1)
					if _ui.current_dest2_name != "":
						var adr_seq: int = _get_tab_dest_seq(_active_tab)
						if adr_seq > 0 and p_adr_dest != adr_seq:
							continue
					t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s 250326 LOCKER%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), E]
				for p_adr: Dictionary in _ui._session.inventory_available:
					if p_adr.get("type", "") == "ADR":
						var p_adr_dest: int = p_adr.get("dest", 1)
						if _ui.current_dest2_name != "":
							var adr_seq: int = _get_tab_dest_seq(_active_tab)
							if adr_seq > 0 and p_adr_dest != adr_seq:
								continue
						t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s 250326%s\n" % [R, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), E]
				for p_adr: Dictionary in last_loaded_cache:
					if p_adr.get("type", "") == "ADR":
						var p_adr_dest: int = p_adr.get("dest", 1)
						if raq_seq_filter > 0 and p_adr_dest != raq_seq_filter: continue
						var adr_stime: String = p_adr.get("scan_time", "")
						t += "%s  %-20s  MAP ADR  %2d 86 11 %-20s 250326 %s%s\n" % [H, p_adr.id, p_adr.collis, p_adr.get("colis_id", ""), adr_stime, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie  F5=Ttes UAT  F7=UAT non Adress{es  F8=UAT Adress{es  F9=CCC/ADR%s\n" % [C, E]
		t += "%sF10=NBC/CFP   F11=EM/CD   F15=Tri F&R%s\n" % [C, E]

	# State 9: Validation
	elif state == 9:
		_input_field.placeholder_text = "F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]DSPF COLIS RAQ/RAC[/u]%s     %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:01:00%s                                    %sAFFICH.%s  %sPJJIDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExpéditeur   :   14    390   CAR TILBURG EXPE%s\n" % [H, E]
		if _ui.current_dest2_name != "":
			var s9_tab_code: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
			var s9_tab_name: String = _tabs[_active_tab].get("dest_name", "") if not _tabs.is_empty() else ""
			if s9_tab_code != "":
				var s9_seq: int = _get_tab_dest_seq(_active_tab)
				t += "%sDestinataire :    7  %5s   %s  %s(Seq.%d — CO LOADING)%s\n\n" % [H, s9_tab_code, s9_tab_name, Y, s9_seq, E]
			else:
				t += "%sDestinataire :    7  %s[NON DEFINI]%s  %s(CO LOADING)%s\n\n" % [H, R, E, Y, E]
		else:
			t += "%sDestinataire :    7  %5s   %s%s\n\n" % [H, _ui.current_dest_code, _ui.current_dest_name, E]
		t += "%s╔══════════════════════════════════════════════════╗%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s║     VALIDATION EFFECTUEE                         ║%s\n" % [Y, E]
		t += "%s║     (RAQ CONFIRMED)                              ║%s\n" % [Y, E]
		t += "%s║                                                  ║%s\n" % [Y, E]
		t += "%s╚══════════════════════════════════════════════════╝%s\n\n" % [Y, E]
		t += "%sYou may now physically Seal the Truck.%s\n" % [C, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie%s\n" % [C, E]

	# === EASTER EGG: Recep Dock (state 15) ===
	elif state == 15:
		_input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RECEP DOCK 390[/u]%s        %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIRCDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Réception — Gestion des arrivages%s\n\n" % [H, E]
		t += "%s  Aucune réception en cours.%s\n\n" % [H, E]
		t += "%s  (Ce module n'est pas actif dans cette version de la simulation.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: Impression (state 16) ===
	elif state == 16:
		_input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]IMPRESSION[/u]%s            %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:18%s                                    %sAFFICH.%s  %sPIEMIFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  01 - Imprimer CMR%s\n" % [H, E]
		t += "%s  02 - Imprimer Bordereau%s\n" % [H, E]
		t += "%s  03 - Imprimer Etiquettes%s\n\n" % [H, E]
		t += "%s  (Les impressions ne sont pas actives dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === EASTER EGG: RAQ Par Magasin (state 17) ===
	elif state == 17:
		_input_field.placeholder_text = "F3=Retour"
		t += "%s%s%s   %s***%s      %s[u]RAQ PAR MAGASIN[/u]%s       %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s09:00:30%s                                    %sAFFICH.%s  %sPIEHMFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%s  Entrez le code magasin :%s %s_____%s\n\n" % [H, E, Y, E]
		t += "%s  (La consultation par magasin n'est pas active dans cette version.)%s\n" % [Y, E]
		t += "\n\n\n\n\n\n\n\n"
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Retour  F12=Annuler%s\n" % [C, E]

	# === SCANNING SCREEN (state 18) — Primary view after badge login ===
	elif state == 18:
		_input_field.placeholder_text = "N° Colis ou UAT — Shift+F1 or F13=RAQ"
		t += "%s%s%s   %s***%s      %s[u]SCANNING QUAI[/u]%s          %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:32:02%s                                    %sENTRER%s   %sPII1PVR%s\n\n" % [H, E, H, E, H, E]
		# Co-loading: show which store this tab is for
		if _ui.current_dest2_name != "" and not _tabs.is_empty():
			var tab_code: String = _tabs[_active_tab].get("dest_code", "")
			var tab_name: String = _tabs[_active_tab].get("dest_name", "")
			if tab_code != "":
				var tab_seq: int = _get_tab_dest_seq(_active_tab)
				var seq_color: String = Y if tab_seq == 1 else "[color=#e67e22]"
				t += "  %sDESTINATAIRE ACTIF:%s %s%s %s (Seq.%d)%s\n\n" % [H, E, seq_color, tab_name, tab_code, tab_seq, E]
			else:
				t += "  %sDESTINATAIRE ACTIF:%s %s[NON DEFINI — Allez sur SAISIE d'abord]%s\n\n" % [H, E, R, E]
		var colis_remaining: int = 0
		var uat_remaining: int = 0
		var colis_loaded: int = 0
		var uat_loaded: int = 0
		var scan_seq_filter: int = _get_tab_dest_seq(_active_tab)
		for p: Dictionary in last_avail_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
			if p.is_uat and not p.missing:
				uat_remaining += 1
				colis_remaining += p.collis
		for p: Dictionary in last_loaded_cache:
			if scan_seq_filter > 0 and p.get("dest", 1) != scan_seq_filter: continue
			if p.is_uat:
				uat_loaded += 1
				colis_loaded += p.collis
		var G := "[color=#00ff00]"
		t += "  %sCOLIS EN RESTE A CHARGER%s    %sUAT VOCAL%s    %sUAT EN RESTE A CHARGER%s\n" % [H, E, H, E, H, E]
		# Render numbers at larger font
		t += "[/font_size][font_size=28]"
		var cr_art: Array = _build_number_art(colis_remaining, 4, G)
		var ur_art: Array = _build_number_art(uat_remaining, 4, G)
		for r in range(5):
			t += "    %s              %s\n" % [cr_art[r], ur_art[r]]
		t += "[/font_size][font_size=24]\n"
		# Loading time
		var load_mins: int = 0
		var load_secs: int = 0
		if _ui._session != null:
			var t_total: float = _ui._session.total_time
			load_mins = int(t_total / 60.0)
			load_secs = int(t_total) % 60
		t += "%s------------------------------]TEMPS CHARGEMENT]------------------------------%s\n" % [C, E]
		t += "  %sCOLIS CHARGES%s              %s]   %02d:%02d:%02d   ]%s      %sUAT CHARGEES%s\n" % [H, E, H, load_mins, load_secs, 0, E, H, E]
		t += "[/font_size][font_size=28]\n"
		var cl_art: Array = _build_number_art(colis_loaded, 4, G)
		var ul_art: Array = _build_number_art(uat_loaded, 4, G)
		for r in range(5):
			t += "    %s              %s\n" % [cl_art[r], ul_art[r]]
		t += "[/font_size][font_size=24]\n"
		t += "    %sN° Colis ou UAT%s %s_________________________%s\n" % [H, E, Y, E]
		t += "    %sMode%s %s+%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie F5=R@J F13=RAQ (or Shift+F1)  F10=Valider F14=UAT/Colis Charg{s%s\n" % [C, E]
		t += "%sF6=Toisage F7=EXPE colis sans flux F8=UAT normal/vrac F9=Modif support UAT%s\n" % [C, E]

	# === SAISIE D'UNE EXPEDITION (state 19) — destinataire typed by user for co-loading ===
	elif state == 19:
		var tab_dest_code: String = _tabs[_active_tab].get("dest_code", "") if not _tabs.is_empty() else ""
		var tab_dest_name: String = _tabs[_active_tab].get("dest_name", "") if not _tabs.is_empty() else ""
		var tab_seal: String = _tabs[_active_tab].get("seal_entered", "") if not _tabs.is_empty() else ""
		var dest_filled: bool = tab_dest_code != ""
		var seal_filled: bool = tab_seal != ""
		# All scenarios require manual destination entry (like tutorial)
		# Set placeholder based on current stage
		if not dest_filled:
			_input_field.placeholder_text = "Enter store destination code, then press Enter"
		elif not seal_filled:
			_input_field.placeholder_text = "Enter seal number, then press Enter"
		else:
			_input_field.placeholder_text = "F10=Valider (proceed to scanning) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]SAISIE D'UNE EXPEDITION[/u]%s  %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:30:24%s                                    %sAJOUTER%s  %sPID2E1R%s\n\n" % [H, E, R, E, H, E]
		t += "%sN{exp{dition    :%s  %s06948174%s              %sExp{diteur camion:%s %s[u]14    390[/u]%s\n\n" % [H, E, Y, E, H, E, Y, E]
		t += "%sExpediteur       :   14    390%s %sCAR TILBURG EXPE%s\n\n" % [H, E, H, E]
		if dest_filled:
			t += "%sDestinataire     :%s  %s 7  %s%s   %s%s%s\n\n" % [H, E, Y, tab_dest_code, E, H, tab_dest_name, E]
		else:
			t += "%sDestinataire     :%s  %s 7  ________%s   %s" % [H, E, Y, E, R] + Locale.t("as400.saisie_dest_hint") + "%s\n\n" % E
		# Seal number display
		if seal_filled:
			t += "%sSEAL number 1    :%s  %s[u]%s[/u]%s\n" % [H, E, Y, tab_seal, E]
		elif dest_filled:
			t += "%sSEAL number 1    :%s  %s________%s   %s" % [H, E, Y, E, R] + Locale.t("as400.saisie_seal_hint") + "%s\n" % E
		else:
			t += "%sSEAL number 1    :%s  %s________%s\n" % [H, E, Y, E]
		t += "%sSEAL number 2    :%s  %s________%s\n\n" % [H, E, Y, E]
		t += "%sType transport :%s %s1%s\n" % [H, E, Y, E]
		t += "%sPrestataire    :%s %sDHL%s\n" % [H, E, Y, E]
		t += "%sType exp{dition :%s %s[u]C[/u]%s %s(C=Classical / S=Specific)%s\n\n\n" % [H, E, Y, E, H, E]
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian"]
		var op_name: String = operators[hash(tab_dest_name if dest_filled else "default") % operators.size()]
		t += "%sOp{rateur        :%s                  %s%s%s\n" % [H, E, R, op_name.to_upper(), E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F4=Invite    F10=Valider%s                            %sAIDE%s\n" % [C, E, C, E]

	# === EXPEDITION EN COURS (state 22) — accessible from Operation menu via 06 ===
	elif state == 22:
		_input_field.placeholder_text = "F6=Créer (opens badge login) — F3=Sortie"
		t += "%s%s%s   %s***%s    %s[u]EXPEDITION EN COURS[/u]%s    %s***%s  %sQUAI390%s    %sNLDKL01%s\n" % [H, d, E, H, E, C, E, H, E, H, E, H, E]
		t += "%s19:29:57%s                                    %sAFFICH.%s  %sPIEHDFR%s\n\n" % [H, E, Y, E, H, E]
		t += "%sExp{diteur :   14    390 CAR TILBURG EXPE%s\n\n" % [H, E]
		t += "%sAfficher @ partir de : N{ exp{dition :%s %s________%s\n\n" % [H, E, Y, E]
		t += "%sIndiquez vos options, puis appuyez sur Entr{e.%s\n" % [H, E]
		t += "%s2=Compl{ter    4=Supprimer%s\n\n" % [H, E]
		t += "%sOpt N{Exp{  Plb n{1     Code destinataire          Par        Etat%s\n" % [H, E]
		var exp_dest: String = _ui.current_dest_name
		if _ui.current_dest2_name != "":
			exp_dest = _ui.current_dest_name + "/" + _ui.current_dest2_name
		t += "%s__  06948174 XXXXXXXX    7 %5s %-20s Georgios   EN COURS%s\n" % [H, _ui.current_dest_code, exp_dest, E]
		t += "%s__  06947961 XXXXXXXX   14    63 CAR HOUPLINES (quai  Artemios   EN COURS%s\n" % [H, E]
		t += "%s__  06938346 XXXXXXXX    7  2680 CIRCULAR CENTER TILB JAKUB      EN COURS%s\n" % [H, E]
		t += "%s__  06929233 00873747    7  1570 ALKMAAR              Georgios   EN COURS%s\n" % [H, E]
		t += "%s__  06845806 XXXXXXXX    7  2680 CIRCULAR CENTER TILB DANIEL     EN COURS%s\n" % [H, E]
		t += "\n\n\n                                                                      %s+%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "%sF3=Sortie    F6=Cr{er%s                                                %sAIDE%s\n" % [C, E, C, E]
		t += "%sFin de balayage; utilisez la touche D{filH afin d'explorer davantage d'enreg%s\n" % [H, E]

	# === EASTER EGG: MENU DES APPLICATIONS (GE Menu, state 20) ===
	elif state == 20:
		_input_field.placeholder_text = "Votre choix ==> (1-8, or F3)"
		t += "%s19:17:20%s                  %s[u]MENU DES APPLICATIONS[/u]%s             %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "                                                          %sGDMRVIS1%s\n\n" % [H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Outils d'aides @ la décision%s\n" % [H, E]
		t += "      %s2  -   GESTION ENTREPOT OXYLANE%s\n" % [H, E]
		t += "      %s3  -   Remise en fonction des écrans%s\n" % [H, E]
		t += "      %s4  -   Gestion des factures%s\n" % [H, E]
		t += "      %s5  -   Menu Radio%s\n" % [H, E]
		t += "      %s6  -   Adressage dirigé par les ORGANISATEUR%s\n" % [H, E]
		t += "      %s7  -   HUB MENU%s\n" % [H, E]
		t += "      %s8  -   Gestion des Profils utilisateurs%s\n" % [H, E]
		t += "\n\n\n\n\n"
		t += "                    %sVotre choix ==>%s  %s__%s\n" % [H, E, Y, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF3  Fin de travail   F4  Give my feedback about AS400%s\n" % [C, E]

	# === EASTER EGG: AIDE A LA DECISION (state 21) ===
	elif state == 21:
		_input_field.placeholder_text = "Votre choix : (1-5, or F3)"
		t += "%s19:17:38%s       %s[u]AIDE A LA DECISION   D E C A T H L O N[/u]%s     %s%s NLDKL01%s\n" % [H, E, C, E, H, d, E]
		t += "    %s1%s                                                     %sDECINIT%s\n\n" % [H, E, H, E]
		t += "%s─────────────────────────────────────────────────────────────────────────────%s\n\n" % [H, E]
		t += "      %s1  -   Query/400%s\n\n" % [H, E]
		t += "      %s2  -   Tableaux de pilotage%s\n\n" % [H, E]
		t += "      %s3  -   Accès aux autres ordinateurs%s\n\n" % [H, E]
		t += "      %s4  -   REACTIVATION DES ECRANS%s\n\n" % [H, E]
		t += "      %s5  -   WORK WTR%s\n\n\n" % [H, E]
		t += "              %sVotre choix :%s  %s_%s\n" % [H, E, Y, E]
		t += "                                               %s(C)  INFO3D    1989,1990%s\n" % [H, E]
		t += "\n%s─────────────────────────────────────────────────────────────────────────────%s\n" % [C, E]
		t += "  %sF1=Aide       F3=Exit                          F12=Précédent%s\n" % [C, E]

	t += "[/font_size]"
	# Error overlay — shown at bottom when wrong input was entered (F3 to clear)
	if error:
		t += "\n[font_size=16][color=#ff4444][b]  *** Choix non valide — F3 pour revenir ***[/b][/color][/font_size]"
	_display.text = t

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
	if state == 2 and input in ["50", "40", "20"]: auto_submit = true
	elif state == 3 and input == "01": auto_submit = true
	elif state == 4 and input == "02": auto_submit = true
	elif state == 5 and input in ["05", "06"]: auto_submit = true
	elif state == 20 and input == "1": auto_submit = true
	if auto_submit:
		# Defer so the text_changed signal finishes cleanly
		(func() -> void: _on_as400_input_submitted(new_text)).call_deferred()
		return
	# Wrong input at expected length → error state (like real AS400)
	var expected_len: int = -1
	if state in [2, 3, 4, 5]: expected_len = 2
	elif state == 20: expected_len = 1
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

	if state == 0:
		if input == "BAYB2B": state = 1
	elif state == 1:
		if input == "123456": state = 2
	elif state == 2:
		if input == "50": state = 3
		elif input == "40": state = 15
		elif input == "20": state = 20
	elif state == 3:
		if input == "01": state = 4
	elif state == 4:
		if input == "02": state = 5
	elif state == 5:
		if input == "05": state = 22
		elif input == "06": state = 22
	elif state == 22:
		if input == "F6":
			_badge_target = 19
			state = 6
		elif input == "F3":
			state = 5
	elif state == 6:
		if input == "8600555": state = 7
	elif state == 7:
		if input == "123456": state = _badge_target
	elif state == 19:
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
			state = 18
		elif input == "F3":
			state = 22
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
	elif state == 18:
		if input == "F3": state = 5
		elif input == "F13" or input == "SHIFT+F1":
			state = 8
			raq_opened.emit()
	elif state == 8:
		if input == "F3": state = 18
		elif input == "F13": state = 18
	elif state == 9 and input == "F3": state = 22
	elif state == 15 and input == "F3": state = 2
	elif state == 16 and input == "F3": state = 5
	elif state == 17 and input == "F3": state = 5
	elif state == 20:
		if input == "1": state = 21
		elif input == "F3": state = 2
	elif state == 21 and input == "F3": state = 20

	# Wrong input on login or menu states → error lock (like real AS400)
	# If state didn't change and we're on a screen that expects specific input, it's an error
	if state == state_before and state in [0, 1, 2, 3, 4, 5, 6, 7, 20, 21, 22]:
		error = true
		_save_tab_state()
		_render_as400_screen()
		WOTSAudio.play_error_buzz(_ui)
		return

	_save_tab_state()
	_render_as400_screen()
	WOTSAudio.play_as400_key(_ui)

	if _ui.tutorial_active:
		if _ui.tutorial_step == 1 and state == 2:
			_ui.tutorial_step = 2
			_ui._tut.update_ui()
		elif _ui.tutorial_step == 2 and state == 19:
			_ui.tutorial_step = 3
			_ui._tut.update_ui()
		elif _ui.tutorial_step == 5 and state == 8:
			_ui.tutorial_step = 6
			_ui._tut.update_ui()

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
		elif state == 9: state = 22; _save_tab_state(); _render_as400_screen()
		elif state == 8: state = 18; _save_tab_state(); _render_as400_screen()
		elif state == 15: state = 2; _save_tab_state(); _render_as400_screen()
		elif state == 16: state = 5; _save_tab_state(); _render_as400_screen()
		elif state == 17: state = 5; _save_tab_state(); _render_as400_screen()
		elif state == 18: state = 5; _save_tab_state(); _render_as400_screen()
		elif state == 19: state = 22; _save_tab_state(); _render_as400_screen()
		elif state == 20: state = 2; _save_tab_state(); _render_as400_screen()
		elif state == 21: state = 20; _save_tab_state(); _render_as400_screen()
		elif state == 22: state = 5; _save_tab_state(); _render_as400_screen()
		elif state > 2: state -= 1; _save_tab_state(); _render_as400_screen()
		return true

	elif keycode == KEY_F10:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == 19:
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
			state = 18
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
			if _ui.tutorial_active and _ui.tutorial_step == 3:
				_ui.tutorial_step = 4
				_ui._tut.update_ui()
		else:
			_confirm_as400_raq()
		return true

	elif keycode == KEY_F6:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == 22:
			_badge_target = 19
			state = 6
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
		return true

	elif keycode == KEY_F13:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == 18:
			state = 8
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
			raq_opened.emit()
			if _ui.tutorial_active and _ui.tutorial_step == 5:
				_ui.tutorial_step = 6
				_ui._tut.update_ui()
		return true

	elif keycode == KEY_F1 and shift_pressed:
		if error:
			WOTSAudio.play_error_buzz(_ui)
			return true
		if state == 18:
			state = 8
			_save_tab_state()
			_render_as400_screen()
			WOTSAudio.play_as400_key(_ui)
			raq_opened.emit()
			if _ui.tutorial_active and _ui.tutorial_step == 5:
				_ui.tutorial_step = 6
				_ui._tut.update_ui()
		return true

	return false

func grab_input_focus() -> void:
	if _input_field != null:
		_input_field.call_deferred("grab_focus")
