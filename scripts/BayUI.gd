extends CanvasLayer

const PANEL_NAMES: Array[String] = [
	"Dock View", "Shift Board", "AS400", "Trailer Capacity", "Phone", "Notes"
]

@onready var top_time_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/TopTimeLabel
@onready var role_strip_label: Label = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox/RoleStripLabel
@onready var workspace_vbox: VBoxContainer = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox

@onready var btn_shift_board: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/ShiftBoardBtn
@onready var btn_loading_plan: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/LoadingPlanBtn
@onready var btn_as400: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/AS400Btn
@onready var btn_trailer_capacity: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/TrailerCapacityBtn
@onready var btn_phone: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PhoneBtn
@onready var btn_notes: Button = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/NotesBtn

@onready var pnl_shift_board: PanelContainer = $Root/PanelOverlayLayer/ShiftBoardPanel
@onready var pnl_loading_plan: PanelContainer = $Root/PanelOverlayLayer/LoadingPlanPanel
@onready var pnl_trailer_capacity: PanelContainer = $Root/PanelOverlayLayer/TrailerCapacityPanel
@onready var pnl_phone: PanelContainer = $Root/PanelOverlayLayer/PhonePanel
@onready var pnl_notes: PanelContainer = $Root/PanelOverlayLayer/NotesPanel

var _enabled: bool = false
var _session = null
var _is_active: bool = false
var _strip_assignment: String = "Unassigned"
var _strip_window_active: bool = false
var _panel_state: Dictionary = {} 
var _panel_nodes: Dictionary = {} 
var panels_ever_opened: Dictionary = {} 

var _current_scenario_name: String = ""
var _current_scenario_index: int = 0
var highest_unlocked_scenario: int = 0

# --- PORTAL & STAGE CONTAINERS ---
var _portal: PortalScreen
var _dock: DockView
var _debrief: DebriefScreen
var _tut: TutorialOverlay

var top_actions_hbox: HBoxContainer
var _top_bar_hbox: HBoxContainer
var stage_hbox: HBoxContainer
var lbl_standby: Label 
var pnl_as400_stage: PanelContainer

# GLOBAL BUTTON REFS FOR SPOTLIGHT
var btn_start_load: Button
var btn_call: Button
var btn_seal: Button
var btn_transit: Button = null
var btn_adr: Button = null
var btn_combine: Button = null


# Phone notification system
var phone_messages: Array = []
var phone_flash_active: bool = false
var _phone_flash_timer: Timer = null
var _phone_seen_count: int = 0
var _load_cooldown: bool = false  # Prevents spam-clicking pallets
var btn_sop: Button
var btn_dock_view: Button

# --- SIDEBAR COLLAPSE/EXPAND ---
const SIDEBAR_COLLAPSED_W: float = 52.0
const SIDEBAR_EXPANDED_W: float = 190.0
const SIDEBAR_ANIM_DURATION: float = 0.2
const SIDEBAR_HOVER_DELAY: float = 0.15
const SIDEBAR_COLLAPSE_DELAY: float = 0.25
var _sidebar_expanded: bool = true
var _sidebar_tween: Tween = null
var _sidebar_btn_labels: Dictionary = {}
var _sidebar_pin_btn: Button
var _sidebar_panels_lbl: Label
var _btn_abandon: Button
var _abandon_overlay: ColorRect

# --- FADE TRANSITIONS ---
const FADE_DURATION: float = 0.855
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null




# --- AS400 TERMINAL (extracted to AS400Terminal.gd) ---
var _as400: AS400Terminal

var store_destinations: Array = [
	{"name": "ALEXANDRIUM", "code": "2093", "co_partner": "2226"},
	{"name": "ALKMAAR", "code": "1570", "co_partner": ""},
	{"name": "AMSTERDAM NOORD", "code": "2226", "co_partner": "2093"},
	{"name": "APELDOORN", "code": "896", "co_partner": ""},
	{"name": "ARENA", "code": "256", "co_partner": ""},
	{"name": "ARNHEM", "code": "1089", "co_partner": ""},
	{"name": "BEST", "code": "664", "co_partner": ""},
	{"name": "BREDA", "code": "1088", "co_partner": ""},
	{"name": "COOLSINGEL", "code": "1161", "co_partner": "1186"},
	{"name": "DEN BOSCH", "code": "3619", "co_partner": ""},
	{"name": "DEN HAAG", "code": "1186", "co_partner": "1161"},
	{"name": "EINDHOVEN", "code": "1185", "co_partner": ""},
	{"name": "ENSCHEDE", "code": "2092", "co_partner": "2225"},
	{"name": "GRONINGEN", "code": "2224", "co_partner": "897"},
	{"name": "KERKRADE", "code": "346", "co_partner": "2094"},
	{"name": "LEEUWARDEN", "code": "897", "co_partner": "2224"},
	{"name": "NIJMEGEN", "code": "2225", "co_partner": "2092"},
	{"name": "ROERMOND", "code": "2094", "co_partner": "346"},
]

var co_pairs: Array = [
	{"store1": "KERKRADE", "code1": "346", "store2": "ROERMOND", "code2": "2094"},
	{"store1": "COOLSINGEL", "code1": "1161", "store2": "DEN HAAG", "code2": "1186"},
	{"store1": "GRONINGEN", "code1": "2224", "store2": "LEEUWARDEN", "code2": "897"},
	{"store1": "ENSCHEDE", "code1": "2092", "store2": "NIJMEGEN", "code2": "2225"},
	{"store1": "ALEXANDRIUM", "code1": "2093", "store2": "AMSTERDAM NOORD", "code2": "2226"},
]
var current_dest_name: String = "ALKMAAR"
var current_dest_code: String = "1570"
var current_dest2_name: String = ""
var current_dest2_code: String = ""
var seal_number_1: String = ""  # Seal for store 1 (co-loading)
var seal_number_2: String = ""  # Seal for store 2 (co-loading)

var _sop: SOPModal


var tutorial_active: bool = false
var tutorial_step: int = -1


func _ready() -> void:
	_sop = SOPModal.new(self)
	Locale.register_sop_database(_sop.sop_database)
	_debrief = DebriefScreen.new(self)
	_tut = TutorialOverlay.new(self)
	_dock = DockView.new(self)
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16) 
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Root.add_child(bg)
	$Root.move_child(bg, 0)
	
	var old_setup = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SetupPanel
	if old_setup: old_setup.visible = false
	var old_sit = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/SituationPanel
	if old_sit: old_sit.visible = false
	var old_log = $Root/FrameVBox/MainHBox/Workspace/WorkspaceVBox/LogPanel
	if old_log: old_log.visible = false

	var old_raq_btn = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/RAQBtn
	if old_raq_btn:
		old_raq_btn.get_parent().remove_child(old_raq_btn)
		old_raq_btn.queue_free()

	# --- STYLE: Top bar ---
	var top_bar = $Root/FrameVBox/TopBar
	if top_bar:
		var tb_sb = StyleBoxFlat.new()
		tb_sb.bg_color = Color(0.08, 0.09, 0.11)
		tb_sb.border_width_bottom = 1
		tb_sb.border_color = Color(0.2, 0.22, 0.25)
		top_bar.add_theme_stylebox_override("panel", tb_sb)
	if top_time_label:
		top_time_label.add_theme_font_size_override("font_size", 15)
		top_time_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	if role_strip_label:
		role_strip_label.add_theme_font_size_override("font_size", 13)
		role_strip_label.add_theme_color_override("font_color", Color(0.5, 0.54, 0.58))

	# Audio toggle in top bar
	_top_bar_hbox = $Root/FrameVBox/TopBar/TopBarMargin/TopBarHBox
	var top_bar_hbox = _top_bar_hbox
	if top_bar_hbox:
		var audio_btn = Button.new()
		audio_btn.text = "🔊"
		audio_btn.custom_minimum_size = Vector2(36, 28)
		audio_btn.focus_mode = Control.FOCUS_NONE
		audio_btn.add_theme_font_size_override("font_size", 16)
		var ab_sb = StyleBoxFlat.new()
		ab_sb.bg_color = Color(0.15, 0.16, 0.18)
		ab_sb.corner_radius_top_left = 4; ab_sb.corner_radius_top_right = 4
		ab_sb.corner_radius_bottom_left = 4; ab_sb.corner_radius_bottom_right = 4
		audio_btn.add_theme_stylebox_override("normal", ab_sb)
		var ab_h = ab_sb.duplicate()
		ab_h.bg_color = Color(0.22, 0.24, 0.28)
		audio_btn.add_theme_stylebox_override("hover", ab_h)
		audio_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		audio_btn.pressed.connect(func() -> void:
			var enabled = not WOTSAudio._enabled
			WOTSAudio.set_enabled(enabled)
			audio_btn.text = "🔊" if enabled else "🔇"
		)
		top_bar_hbox.add_child(audio_btn)

	# --- STYLE: Panel toggle bar ---
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar:
		var ptb_sb := StyleBoxFlat.new()
		ptb_sb.bg_color = Color(0.1, 0.11, 0.13)
		ptb_sb.border_width_left = 1
		ptb_sb.border_color = Color(0.2, 0.22, 0.25)
		toggle_bar.add_theme_stylebox_override("panel", ptb_sb)
		toggle_bar.mouse_entered.connect(_on_sidebar_mouse_entered)
		toggle_bar.mouse_exited.connect(_on_sidebar_mouse_exited)

	# Remove Trailer Capacity from sidebar entirely — capacity is shown in the dock view
	if btn_trailer_capacity != null:
		btn_trailer_capacity.get_parent().remove_child(btn_trailer_capacity)
		btn_trailer_capacity.queue_free()
		btn_trailer_capacity = null
	# Remove Loading Plan button — content merged into Shift Board
	if btn_loading_plan != null:
		btn_loading_plan.get_parent().remove_child(btn_loading_plan)
		btn_loading_plan.queue_free()
		btn_loading_plan = null

	# Style the Panels header label
	_sidebar_panels_lbl = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox/PanelsLabel
	if _sidebar_panels_lbl:
		_sidebar_panels_lbl.text = Locale.t("btn.panels")
		_sidebar_panels_lbl.add_theme_font_size_override("font_size", 12)
		_sidebar_panels_lbl.add_theme_color_override("font_color", Color(0.4, 0.43, 0.47))
		_sidebar_panels_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- PIN BUTTON (top of sidebar) ---
	var toggle_vbox: VBoxContainer = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox
	if toggle_vbox and _sidebar_panels_lbl:
		_sidebar_pin_btn = Button.new()
		_sidebar_pin_btn.text = "<<"
		_sidebar_pin_btn.tooltip_text = "Collapse sidebar"
		_sidebar_pin_btn.focus_mode = Control.FOCUS_NONE
		_sidebar_pin_btn.add_theme_font_size_override("font_size", 11)
		_sidebar_pin_btn.add_theme_color_override("font_color", Color(0.5, 0.53, 0.57))
		_sidebar_pin_btn.add_theme_color_override("font_hover_color", Color(0.8, 0.85, 0.9))
		var pin_n := StyleBoxFlat.new()
		pin_n.bg_color = Color(0.13, 0.14, 0.16)
		pin_n.corner_radius_top_left = 3; pin_n.corner_radius_top_right = 3
		pin_n.corner_radius_bottom_left = 3; pin_n.corner_radius_bottom_right = 3
		pin_n.content_margin_top = 2; pin_n.content_margin_bottom = 2
		_sidebar_pin_btn.add_theme_stylebox_override("normal", pin_n)
		var pin_h := pin_n.duplicate()
		pin_h.bg_color = Color(0.2, 0.22, 0.26)
		_sidebar_pin_btn.add_theme_stylebox_override("hover", pin_h)
		var pin_p := pin_n.duplicate()
		pin_p.bg_color = Color(0.1, 0.11, 0.13)
		_sidebar_pin_btn.add_theme_stylebox_override("pressed", pin_p)
		_sidebar_pin_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_sidebar_pin_btn.pressed.connect(_on_sidebar_pin_pressed)
		toggle_vbox.add_child(_sidebar_pin_btn)
		toggle_vbox.move_child(_sidebar_pin_btn, 0)
		toggle_vbox.move_child(_sidebar_panels_lbl, 0)

	# --- REGISTER BUTTON ICON MAPPINGS ---
	_sidebar_btn_labels[btn_shift_board] = {"icon": "SB", "label": Locale.t("btn.shift_board")}
	_sidebar_btn_labels[btn_as400] = {"icon": "AS", "label": "AS400"}
	_sidebar_btn_labels[btn_phone] = {"icon": "PH", "label": Locale.t("btn.phone")}
	_sidebar_btn_labels[btn_notes] = {"icon": "NT", "label": Locale.t("btn.notes")}

	var toggle_buttons: Array = [btn_shift_board, btn_as400, btn_phone, btn_notes]
	for tb: Button in toggle_buttons:
		if tb == null: continue
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_size_override("font_size", 13)
		tb.clip_text = true
		var tb_n := StyleBoxFlat.new()
		tb_n.bg_color = Color(0.15, 0.16, 0.18)
		tb_n.corner_radius_top_left = 4; tb_n.corner_radius_top_right = 4
		tb_n.corner_radius_bottom_left = 4; tb_n.corner_radius_bottom_right = 4
		tb_n.border_width_left = 1; tb_n.border_width_top = 1; tb_n.border_width_right = 1; tb_n.border_width_bottom = 1
		tb_n.border_color = Color(0.25, 0.27, 0.3)
		tb.add_theme_stylebox_override("normal", tb_n)
		var tb_h := tb_n.duplicate()
		tb_h.bg_color = Color(0.2, 0.22, 0.26)
		tb_h.border_color = Color(0.0, 0.51, 0.76)
		tb.add_theme_stylebox_override("hover", tb_h)
		var tb_p := tb_n.duplicate()
		tb_p.bg_color = Color(0.12, 0.13, 0.15)
		tb.add_theme_stylebox_override("pressed", tb_p)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		tb.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		tb.mouse_entered.connect(_on_sidebar_btn_hover_entered.bind(tb))
		tb.mouse_exited.connect(_on_sidebar_btn_hover_exited.bind(tb))

	# --- END SHIFT BUTTON (bottom of sidebar) ---
	var toggle_vbox_ref: VBoxContainer = $Root/FrameVBox/MainHBox/PanelToggleBar/ToggleMargin/ToggleVBox
	if toggle_vbox_ref:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		toggle_vbox_ref.add_child(spacer)
		_btn_abandon = Button.new()
		_btn_abandon.text = Locale.t("btn.abandon_shift")
		_btn_abandon.clip_text = true
		_btn_abandon.focus_mode = Control.FOCUS_NONE
		_btn_abandon.add_theme_font_size_override("font_size", 12)
		var ab_n := StyleBoxFlat.new()
		ab_n.bg_color = Color(0.18, 0.08, 0.08)
		ab_n.corner_radius_top_left = 4; ab_n.corner_radius_top_right = 4
		ab_n.corner_radius_bottom_left = 4; ab_n.corner_radius_bottom_right = 4
		ab_n.border_width_left = 1; ab_n.border_width_top = 1
		ab_n.border_width_right = 1; ab_n.border_width_bottom = 1
		ab_n.border_color = Color(0.4, 0.15, 0.15)
		_btn_abandon.add_theme_stylebox_override("normal", ab_n)
		var ab_h := ab_n.duplicate()
		ab_h.bg_color = Color(0.28, 0.1, 0.1)
		ab_h.border_color = Color(0.7, 0.2, 0.2)
		_btn_abandon.add_theme_stylebox_override("hover", ab_h)
		var ab_p := ab_n.duplicate()
		ab_p.bg_color = Color(0.14, 0.06, 0.06)
		_btn_abandon.add_theme_stylebox_override("pressed", ab_p)
		_btn_abandon.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_btn_abandon.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		_btn_abandon.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
		_btn_abandon.visible = false
		_btn_abandon.pressed.connect(_show_abandon_confirm)
		_btn_abandon.mouse_entered.connect(_on_sidebar_btn_hover_entered.bind(_btn_abandon))
		_btn_abandon.mouse_exited.connect(_on_sidebar_btn_hover_exited.bind(_btn_abandon))
		toggle_vbox_ref.add_child(_btn_abandon)
		_sidebar_btn_labels[_btn_abandon] = {"icon": "X", "label": Locale.t("btn.abandon_shift")}

	# --- ABANDON CONFIRM OVERLAY ---
	_abandon_overlay = ColorRect.new()
	_abandon_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_abandon_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_abandon_overlay.visible = false
	_abandon_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(_abandon_overlay)
	var confirm_center := CenterContainer.new()
	confirm_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_abandon_overlay.add_child(confirm_center)
	var confirm_panel := PanelContainer.new()
	var cp_sb := StyleBoxFlat.new()
	cp_sb.bg_color = Color(0.1, 0.11, 0.14)
	cp_sb.border_width_left = 2; cp_sb.border_width_top = 2
	cp_sb.border_width_right = 2; cp_sb.border_width_bottom = 2
	cp_sb.border_color = Color(0.5, 0.15, 0.15)
	cp_sb.corner_radius_top_left = 10; cp_sb.corner_radius_top_right = 10
	cp_sb.corner_radius_bottom_left = 10; cp_sb.corner_radius_bottom_right = 10
	confirm_panel.add_theme_stylebox_override("panel", cp_sb)
	confirm_center.add_child(confirm_panel)
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 32)
	confirm_margin.add_theme_constant_override("margin_top", 24)
	confirm_margin.add_theme_constant_override("margin_right", 32)
	confirm_margin.add_theme_constant_override("margin_bottom", 24)
	confirm_panel.add_child(confirm_margin)
	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 20)
	confirm_margin.add_child(confirm_vbox)
	var confirm_lbl := Label.new()
	confirm_lbl.text = Locale.t("btn.abandon_confirm")
	confirm_lbl.add_theme_font_size_override("font_size", 16)
	confirm_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_lbl.custom_minimum_size = Vector2(420, 0)
	confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_vbox.add_child(confirm_lbl)
	var confirm_btns := HBoxContainer.new()
	confirm_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_btns.add_theme_constant_override("separation", 16)
	confirm_vbox.add_child(confirm_btns)
	var btn_yes := Button.new()
	btn_yes.text = Locale.t("btn.abandon_yes")
	btn_yes.focus_mode = Control.FOCUS_NONE
	btn_yes.add_theme_font_size_override("font_size", 14)
	var yes_sb := StyleBoxFlat.new()
	yes_sb.bg_color = Color(0.6, 0.15, 0.15)
	yes_sb.corner_radius_top_left = 6; yes_sb.corner_radius_top_right = 6
	yes_sb.corner_radius_bottom_left = 6; yes_sb.corner_radius_bottom_right = 6
	yes_sb.content_margin_left = 20; yes_sb.content_margin_right = 20
	yes_sb.content_margin_top = 8; yes_sb.content_margin_bottom = 8
	btn_yes.add_theme_stylebox_override("normal", yes_sb)
	var yes_h := yes_sb.duplicate()
	yes_h.bg_color = Color(0.8, 0.2, 0.2)
	btn_yes.add_theme_stylebox_override("hover", yes_h)
	btn_yes.add_theme_color_override("font_color", Color.WHITE)
	btn_yes.pressed.connect(_do_abandon_shift)
	confirm_btns.add_child(btn_yes)
	var btn_no := Button.new()
	btn_no.text = Locale.t("btn.abandon_no")
	btn_no.focus_mode = Control.FOCUS_NONE
	btn_no.add_theme_font_size_override("font_size", 14)
	var no_sb := StyleBoxFlat.new()
	no_sb.bg_color = Color(0.15, 0.16, 0.18)
	no_sb.corner_radius_top_left = 6; no_sb.corner_radius_top_right = 6
	no_sb.corner_radius_bottom_left = 6; no_sb.corner_radius_bottom_right = 6
	no_sb.content_margin_left = 20; no_sb.content_margin_right = 20
	no_sb.content_margin_top = 8; no_sb.content_margin_bottom = 8
	btn_no.add_theme_stylebox_override("normal", no_sb)
	var no_h := no_sb.duplicate()
	no_h.bg_color = Color(0.22, 0.24, 0.28)
	btn_no.add_theme_stylebox_override("hover", no_h)
	btn_no.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	btn_no.pressed.connect(func() -> void: _abandon_overlay.visible = false)
	confirm_btns.add_child(btn_no)

	_build_start_portal()
	_build_operational_layout()
	_debrief._build($Root)
	_sop._build_sop_modal()
	_tut._build()
	_style_overlay_panels()

	_update_top_time(0.0)
	_update_strip_text()
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.0)

func _process(_delta: float) -> void:
	if tutorial_active and _tut._target_node != null and is_instance_valid(_tut._target_node) and _tut._target_node.visible:
		_tut.highlight_box.visible = true
		var pos: Vector2 = _tut._target_node.global_position - Vector2(4, 4)
		pos.x = maxf(pos.x, 0.0)
		pos.y = maxf(pos.y, 0.0)
		_tut.highlight_box.global_position = pos
		_tut.highlight_box.size = _tut._target_node.size + Vector2(8, 8)
	elif _tut.highlight_box != null:
		_tut.highlight_box.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _abandon_overlay != null and _abandon_overlay.visible:
				_abandon_overlay.visible = false
			elif _sop.overlay != null and _sop.overlay.visible:
				_sop._close_sop_modal()
			elif _debrief.overlay != null and _debrief.overlay.visible:
				pass  # Don't close debrief with Escape
			elif _portal.overlay != null and _portal.overlay.visible:
				pass  # Portal has its own close button
			else:
				# Close any open overlay panel (Shift Board, Phone, Notes, etc.)
				var closed_one: bool = false
				for panel_name: String in PANEL_NAMES:
					if panel_name == "Dock View" or panel_name == "AS400":
						continue  # These are workspace panels, not overlays
					if bool(_panel_state.get(panel_name, false)):
						_set_panel_visible(panel_name, false, false)
						closed_one = true
				if closed_one:
					WOTSAudio.play_panel_click(self)
		elif event.keycode in [KEY_F3, KEY_F10, KEY_F6, KEY_F13] or (event.keycode == KEY_F1 and event.shift_pressed):
			if _as400 != null and _as400.handle_fkey(event.keycode, event.shift_pressed):
				return

# ==========================================
# THE SPOTLIGHT TUTORIAL SYSTEM
func _build_start_portal() -> void:
	_portal = PortalScreen.new(self)
	_portal._build($Root)
	_portal.scenario_dropdown.item_selected.connect(_on_portal_scenario_changed)
	_portal.language_dropdown.item_selected.connect(_on_portal_language_changed)
	_portal.btn_start.pressed.connect(_on_portal_start_pressed)
	_portal.btn_dev.pressed.connect(func() -> void:
		highest_unlocked_scenario = 3
		_populate_scenarios()
	)

# ==========================================
# DEBRIEF MODAL
func _build_operational_layout() -> void:
	top_actions_hbox = HBoxContainer.new()
	top_actions_hbox.add_theme_constant_override("separation", 10)
	top_actions_hbox.visible = false 
	workspace_vbox.add_child(top_actions_hbox)

	# Helper for styled action buttons
	var make_action_btn = func(text: String, accent: bool) -> Button:
		var b = Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 13)
		var n_sb = StyleBoxFlat.new()
		n_sb.corner_radius_top_left = 4; n_sb.corner_radius_top_right = 4
		n_sb.corner_radius_bottom_left = 4; n_sb.corner_radius_bottom_right = 4
		if accent:
			n_sb.bg_color = Color(0.15, 0.16, 0.19)
			n_sb.border_width_bottom = 2
			n_sb.border_color = Color(0.0, 0.51, 0.76)
		else:
			n_sb.bg_color = Color(0.15, 0.16, 0.19)
			n_sb.border_width_left = 1; n_sb.border_width_top = 1
			n_sb.border_width_right = 1; n_sb.border_width_bottom = 1
			n_sb.border_color = Color(0.25, 0.27, 0.3)
		b.add_theme_stylebox_override("normal", n_sb)
		var h_sb = n_sb.duplicate()
		h_sb.bg_color = Color(0.22, 0.24, 0.28)
		b.add_theme_stylebox_override("hover", h_sb)
		var p_sb = n_sb.duplicate()
		p_sb.bg_color = Color(0.1, 0.12, 0.15)
		b.add_theme_stylebox_override("pressed", p_sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color(0.5, 0.55, 0.6))
		b.focus_mode = Control.FOCUS_NONE
		return b

	btn_start_load = make_action_btn.call(Locale.t("btn.start_loading"), false)
	btn_start_load.pressed.connect(func() -> void: _on_decision_pressed("Start Loading"))
	top_actions_hbox.add_child(btn_start_load)

	btn_call = make_action_btn.call(Locale.t("btn.call_depts"), true)
	btn_call.pressed.connect(func() -> void: _on_decision_pressed("Call departments (C&C check)"))
	top_actions_hbox.add_child(btn_call)

	btn_seal = make_action_btn.call(Locale.t("btn.seal_truck"), false)
	btn_seal.pressed.connect(func() -> void: _on_decision_pressed("Seal Truck"))
	top_actions_hbox.add_child(btn_seal)

	btn_transit = make_action_btn.call(Locale.t("btn.check_transit"), false)
	btn_transit.pressed.connect(func() -> void: _on_decision_pressed("Check Transit"))
	btn_transit.visible = false
	btn_transit.disabled = true
	top_actions_hbox.add_child(btn_transit)

	btn_adr = make_action_btn.call(Locale.t("btn.check_adr"), true)
	btn_adr.pressed.connect(func() -> void: _on_decision_pressed("Check Yellow Lockers"))
	btn_adr.visible = false
	btn_adr.disabled = true
	var adr_sb := StyleBoxFlat.new()
	adr_sb.bg_color = Color(0.18, 0.08, 0.04)
	adr_sb.border_color = Color(0.9, 0.4, 0.0)
	adr_sb.set_border_width_all(2)
	adr_sb.set_corner_radius_all(4)
	btn_adr.add_theme_stylebox_override("normal", adr_sb)
	btn_adr.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	top_actions_hbox.add_child(btn_adr)

	btn_combine = make_action_btn.call(Locale.t("btn.combine"), false)
	btn_combine.pressed.connect(func() -> void: _on_decision_pressed("Combine Pallets"))
	btn_combine.visible = false
	btn_combine.disabled = true
	var combine_sb := StyleBoxFlat.new()
	combine_sb.bg_color = Color(0.05, 0.18, 0.08)
	combine_sb.border_color = Color(0.18, 0.8, 0.44)
	combine_sb.set_border_width_all(2)
	combine_sb.set_corner_radius_all(4)
	btn_combine.add_theme_stylebox_override("normal", combine_sb)
	btn_combine.add_theme_color_override("font_color", Color(0.18, 0.9, 0.5))
	top_actions_hbox.add_child(btn_combine)

	btn_sop = Button.new()
	btn_sop.text = Locale.t("btn.help_sops")
	btn_sop.custom_minimum_size = Vector2(110, 28)
	btn_sop.add_theme_font_size_override("font_size", 12)
	var sop_sb = StyleBoxFlat.new()
	sop_sb.bg_color = Color(0.12, 0.3, 0.55)
	sop_sb.corner_radius_top_left = 4; sop_sb.corner_radius_top_right = 4
	sop_sb.corner_radius_bottom_left = 4; sop_sb.corner_radius_bottom_right = 4
	btn_sop.add_theme_stylebox_override("normal", sop_sb)
	var sop_h = sop_sb.duplicate()
	sop_h.bg_color = Color(0.0, 0.51, 0.76)
	btn_sop.add_theme_stylebox_override("hover", sop_h)
	var sop_p = sop_sb.duplicate()
	sop_p.bg_color = Color(0.08, 0.2, 0.4)
	btn_sop.add_theme_stylebox_override("pressed", sop_p)
	btn_sop.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_sop.focus_mode = Control.FOCUS_NONE
	btn_sop.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	btn_sop.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_sop.pressed.connect(_sop._open_sop_modal)
	if _top_bar_hbox != null:
		_top_bar_hbox.add_child(btn_sop)

	stage_hbox = HBoxContainer.new()
	stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	stage_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_hbox.add_theme_constant_override("separation", 0)
	stage_hbox.visible = false
	workspace_vbox.add_child(stage_hbox)
	
	lbl_standby = Label.new()
	lbl_standby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_standby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_standby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_standby.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_standby.text = Locale.t("standby.message")
	lbl_standby.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	lbl_standby.add_theme_font_size_override("font_size", 22)
	stage_hbox.add_child(lbl_standby)

	_dock._build(stage_hbox)
	_build_as400_stage()
	
	btn_dock_view = Button.new()
	btn_dock_view.text = Locale.t("btn.dock_view")
	btn_dock_view.clip_text = true
	btn_shift_board.get_parent().add_child(btn_dock_view)
	btn_shift_board.get_parent().move_child(btn_dock_view, 2)

	# Style the dock view button to match others
	btn_dock_view.add_theme_font_size_override("font_size", 13)
	var dv_n := StyleBoxFlat.new()
	dv_n.bg_color = Color(0.15, 0.16, 0.18)
	dv_n.corner_radius_top_left = 4; dv_n.corner_radius_top_right = 4
	dv_n.corner_radius_bottom_left = 4; dv_n.corner_radius_bottom_right = 4
	dv_n.border_width_left = 1; dv_n.border_width_top = 1; dv_n.border_width_right = 1; dv_n.border_width_bottom = 1
	dv_n.border_color = Color(0.25, 0.27, 0.3)
	btn_dock_view.add_theme_stylebox_override("normal", dv_n)
	var dv_h := dv_n.duplicate()
	dv_h.bg_color = Color(0.2, 0.22, 0.26)
	dv_h.border_color = Color(0.0, 0.51, 0.76)
	btn_dock_view.add_theme_stylebox_override("hover", dv_h)
	var dv_p := dv_n.duplicate()
	dv_p.bg_color = Color(0.12, 0.13, 0.15)
	btn_dock_view.add_theme_stylebox_override("pressed", dv_p)
	btn_dock_view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_dock_view.focus_mode = Control.FOCUS_NONE
	btn_dock_view.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	btn_dock_view.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn_dock_view.mouse_entered.connect(_on_sidebar_btn_hover_entered.bind(btn_dock_view))
	btn_dock_view.mouse_exited.connect(_on_sidebar_btn_hover_exited.bind(btn_dock_view))
	_sidebar_btn_labels[btn_dock_view] = {"icon": "DV", "label": Locale.t("btn.dock_view")}
	
	_init_panel_nodes_and_buttons(btn_dock_view)
	_build_fade_overlay()

# ==========================================
# DOCK VIEW — CONCRETE FLOOR + OVERHEAD SIGNS
func _build_as400_stage() -> void:
	_as400 = AS400Terminal.new(self, stage_hbox)
	_as400._build_as400_stage()
	pnl_as400_stage = _as400.panel
	_as400.raq_opened.connect(_on_raq_opened)

# ==========================================
# FADE TRANSITION SYSTEM
# ==========================================
func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 19
	_fade_layer.name = "BayFadeOverlay"
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func _fade_transition(mid_callback: Callable) -> void:
	if _fade_rect == null:
		if mid_callback.is_valid():
			mid_callback.call()
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void:
		if mid_callback.is_valid():
			mid_callback.call()
	)
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


# ==========================================
# FLOW LOGIC & DATA UPDATES
# ==========================================
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled: return
	if _portal.overlay != null: _portal.overlay.visible = true

func _on_portal_start_pressed() -> void:
	if _session == null:
		return
	if _portal.btn_start != null:
		_portal.btn_start.disabled = true
	_fade_transition(_execute_session_start)


func _execute_session_start() -> void:
	_current_scenario_index = _portal.scenario_dropdown.get_selected_id()
	if _current_scenario_index == 0: _current_scenario_name = "0. Tutorial"
	elif _current_scenario_index == 1: _current_scenario_name = "1. Standard Loading"
	elif _current_scenario_index == 2: _current_scenario_name = "2. Priority Loading"
	elif _current_scenario_index == 3: _current_scenario_name = "3. Co-Loading"

	_session.set_role(WOTSConfig.Role.OPERATOR)
	_is_active = true

	var dest: Dictionary = store_destinations.pick_random()
	current_dest_name = dest.name
	current_dest_code = dest.code
	current_dest2_name = ""
	current_dest2_code = ""

	# For co-loading, pick a CO pair
	if _current_scenario_index == 3:
		var pair: Dictionary = co_pairs.pick_random()
		current_dest_name = pair.store1
		current_dest_code = pair.code1
		current_dest2_name = pair.store2
		current_dest2_code = pair.code2

	# Generate seal numbers for every scenario (realistic 6-digit from seal booklet)
	# Real seals at Bay B2B: 865xxx or 866xxx range
	var seal_prefix: int = 865 if randf() < 0.85 else 866
	var seal_suffix: int = 700 + (hash(current_dest_name + str(randi())) % 300)
	seal_number_1 = str(seal_prefix * 1000 + seal_suffix)
	if current_dest2_name != "":
		var seal_suffix_2: int = 700 + (hash(current_dest2_name + str(randi())) % 300)
		while seal_suffix_2 == seal_suffix:
			seal_suffix_2 = 700 + (randi() % 300)
		seal_number_2 = str(seal_prefix * 1000 + seal_suffix_2)
	else:
		seal_number_2 = ""

	# Rebuild dock lanes for current scenario type
	_dock.rebuild_lanes(_current_scenario_index == 3)
	phone_messages.clear()
	_phone_seen_count = 0
	_clear_phone_flash()
	_load_cooldown = false

	_portal.overlay.visible = false
	top_actions_hbox.visible = true
	stage_hbox.visible = true
	if _btn_abandon != null: _btn_abandon.visible = true

	_reset_panel_state()
	_close_all_panels(true)

	_as400.state = 0
	_as400.wrong_store_scans = 0
	_as400._init_tabs()
	_as400._render_as400_screen()

	if _current_scenario_index == 0:
		tutorial_active = true
		tutorial_step = 0
		_tut.canvas.visible = true
		_tut.update_ui()
		lbl_standby.text = Locale.t("standby.tutorial")
		lbl_standby.visible = true
		# Keep sidebar expanded during tutorial so labels are visible
		if _sidebar_pin_btn:
			_sidebar_pin_btn.text = "<<"
		_expand_sidebar()
	else:
		tutorial_active = false
		if _tut.canvas != null: _tut.canvas.visible = false
		lbl_standby.visible = true

	_session.call("start_session_with_scenario", _current_scenario_name)
	# Transit: visible for Standard onwards, enabled once player opens the RAQ
	if btn_transit != null:
		btn_transit.visible = (_current_scenario_index >= 1)
		btn_transit.disabled = true
	# ADR: visible for Standard onwards (always check lockers), enabled once player opens the RAQ
	if btn_adr != null:
		btn_adr.visible = (_current_scenario_index >= 1)
		btn_adr.disabled = true
	# Combine: visible for Standard onwards, enabled only after Start Loading
	if btn_combine != null:
		btn_combine.visible = (_current_scenario_index >= 1)
		btn_combine.disabled = true
	_populate_overlay_panels()
	if _portal.btn_start != null:
		_portal.btn_start.disabled = false

func _on_session_ended(debrief_payload: Dictionary) -> void:
	_is_active = false
	_debrief.store_payload(debrief_payload)

	var passed: bool = debrief_payload.get("passed", false)
	if passed:
		if _current_scenario_index == highest_unlocked_scenario and highest_unlocked_scenario < 3:
			highest_unlocked_scenario += 1

	if tutorial_active: _tut.canvas.visible = false

	_populate_scenarios()
	_fade_transition(_show_debrief_mid)


func _show_debrief_mid() -> void:
	_debrief.render()

func _on_debrief_closed() -> void:
	_fade_transition(_return_to_portal_from_debrief)


func _return_to_portal_from_debrief() -> void:
	_debrief.overlay.visible = false
	top_actions_hbox.visible = false
	stage_hbox.visible = false
	_close_all_panels(true)
	if btn_transit != null: btn_transit.visible = false
	if btn_adr != null: btn_adr.visible = false
	if btn_combine != null: btn_combine.visible = false
	if _btn_abandon != null: _btn_abandon.visible = false
	_portal.overlay.visible = true

func _show_abandon_confirm() -> void:
	if _abandon_overlay != null:
		_abandon_overlay.visible = true

func _do_abandon_shift() -> void:
	_abandon_overlay.visible = false
	_fade_transition(_execute_abandon_shift)


func _execute_abandon_shift() -> void:
	# Stop the session
	if _session != null:
		_session.is_active = false
		_session.is_paused = false
	_is_active = false
	tutorial_active = false
	tutorial_step = -1
	if _tut.canvas != null: _tut.canvas.visible = false
	# Clean up UI — same as debrief close
	_debrief.overlay.visible = false
	top_actions_hbox.visible = false
	stage_hbox.visible = false
	_close_all_panels(true)
	if btn_transit != null: btn_transit.visible = false
	if btn_adr != null: btn_adr.visible = false
	if btn_combine != null: btn_combine.visible = false
	if _btn_abandon != null: _btn_abandon.visible = false
	phone_messages.clear()
	_phone_seen_count = 0
	_clear_phone_flash()
	# Return to portal
	_portal.overlay.visible = true

func _refresh_combine_btn() -> void:
	if btn_combine == null or _session == null: return
	if not btn_combine.visible: return
	var has_pair: bool = _session.call("has_combine_pair")
	btn_combine.disabled = not has_pair

func _on_raq_opened() -> void:
	# RAQ has been viewed — enable pre-loading action buttons
	# Determine which dest sequence this tab represents
	var dest_seq: int = _as400._get_tab_dest_seq(_as400._active_tab)
	if _session != null:
		_session.call("mark_raq_viewed", dest_seq)
	# Enable transit and call buttons (ADR always visible from session start if applicable)
	if btn_transit != null and btn_transit.visible:
		btn_transit.disabled = false
	if btn_adr != null and btn_adr.visible:
		btn_adr.disabled = false
	# btn_call is always enabled — no gate needed
func set_session(session) -> void:
	_session = session
	_populate_scenarios()
	
	if _session != null:
		if _session.has_signal("time_updated"): _session.connect("time_updated", Callable(self, "_on_time_updated"))
		if _session.has_signal("session_ended"): _session.connect("session_ended", Callable(self, "_on_session_ended"))
		if _session.has_signal("role_updated"): _session.connect("role_updated", Callable(self, "_on_role_updated"))
		if _session.has_signal("responsibility_boundary_updated"): _session.connect("responsibility_boundary_updated", Callable(self, "_on_boundary_updated"))
		if _session.has_signal("inventory_updated"): _session.connect("inventory_updated", Callable(self, "_on_inventory_updated"))
		if _session.has_signal("phone_notification"): _session.connect("phone_notification", Callable(self, "_on_phone_notification"))
		if _session.has_signal("phone_pallets_delivered"): _session.connect("phone_pallets_delivered", Callable(self, "_on_phone_pallets_delivered"))

func _populate_scenarios() -> void:
	if _portal == null: return
	_portal.populate_scenarios(highest_unlocked_scenario)
	_on_portal_scenario_changed(highest_unlocked_scenario)

func _on_portal_scenario_changed(idx: int) -> void:
	if _portal == null: return
	_portal.update_scenario_desc(idx)

func _on_portal_language_changed(idx: int) -> void:
	Locale.current_lang = idx
	if _portal != null: _portal.refresh_language_labels()
	_populate_scenarios()
	_refresh_ui_locale()

func _refresh_ui_locale() -> void:
	# Sidebar button labels
	if btn_shift_board != null:
		_sidebar_btn_labels[btn_shift_board]["label"] = Locale.t("btn.shift_board")
	if btn_phone != null:
		_sidebar_btn_labels[btn_phone]["label"] = Locale.t("btn.phone")
	if btn_notes != null:
		_sidebar_btn_labels[btn_notes]["label"] = Locale.t("btn.notes")
	if btn_dock_view != null:
		_sidebar_btn_labels[btn_dock_view]["label"] = Locale.t("btn.dock_view")
	_update_sidebar_button_text(_sidebar_expanded)
	# Panels header
	if _sidebar_panels_lbl != null:
		_sidebar_panels_lbl.text = Locale.t("btn.panels")
	# Action buttons
	if btn_start_load != null: btn_start_load.text = Locale.t("btn.start_loading")
	if btn_call != null: btn_call.text = Locale.t("btn.call_depts")
	if btn_seal != null: btn_seal.text = Locale.t("btn.seal_truck")
	if btn_transit != null: btn_transit.text = Locale.t("btn.check_transit")
	if btn_adr != null: btn_adr.text = Locale.t("btn.check_adr")
	if btn_combine != null: btn_combine.text = Locale.t("btn.combine")
	if btn_sop != null: btn_sop.text = Locale.t("btn.help_sops")
	if _btn_abandon != null:
		_btn_abandon.text = Locale.t("btn.abandon_shift")
		_sidebar_btn_labels[_btn_abandon]["label"] = Locale.t("btn.abandon_shift")

func _on_decision_pressed(action: String) -> void:
	if tutorial_active:
		if tutorial_step < 6:
			_tut.flash_warning(Locale.t("warn.not_ready"))
			return
		if tutorial_step == 6:
			if action != "Call departments (C&C check)":
				_tut.flash_warning(Locale.t("warn.call_depts"))
				return
			else:
				tutorial_step = 7
				_tut.update_ui()
		elif tutorial_step == 7:
			if action != "Start Loading":
				_tut.flash_warning(Locale.t("warn.start_loading"))
				return
			else:
				tutorial_step = 8
				_tut.update_ui()
		elif tutorial_step < 15 and action == "Seal Truck":
			_tut.flash_warning(Locale.t("warn.not_finished"))
			return
			
	if _session == null: return
	_session.call("manual_decision", action)
	if action == "Seal Truck":
		WOTSAudio.play_seal_confirm(self)
	elif action == "Call departments (C&C check)":
		WOTSAudio.play_scan_beep(self)
	elif action == "Start Loading":
		WOTSAudio.play_panel_click(self)
		# Combine is the only button gated behind Start Loading
		if btn_combine != null and btn_combine.visible:
			_refresh_combine_btn()
	elif action == "Check Transit":
		if btn_transit != null:
			btn_transit.disabled = true
	elif action == "Check Yellow Lockers":
		if btn_adr != null:
			btn_adr.disabled = true
	elif action == "Combine Pallets":
		WOTSAudio.play_scan_beep(self)
		_refresh_combine_btn()

func _on_time_updated(total_time: float, _loading_time: float) -> void:
	_update_top_time(total_time)

func _update_top_time(total_time: float) -> void:
	if top_time_label == null: return
	# Clock starts at 09:00 and only advances once loading has started
	var base_hour: int = 9
	if _session != null and not _session.loading_started:
		top_time_label.text = "09:00:00"
		return
	var total_secs: int = int(total_time)
	@warning_ignore("integer_division")
	var hours: int = base_hour + (total_secs / 3600)
	@warning_ignore("integer_division")
	var mins: int = (total_secs % 3600) / 60
	var secs: int = total_secs % 60
	top_time_label.text = "%02d:%02d:%02d" % [hours, mins, secs]

func _on_role_updated(_role_id: int) -> void:
	_update_strip_text()

func _on_boundary_updated(_role_id: int, assignment_text: String, window_active: bool) -> void:
	_strip_assignment = assignment_text
	_strip_window_active = window_active
	_update_strip_text()

func _update_strip_text() -> void:
	if role_strip_label == null: return
	var window_text := "Not Active"
	if _strip_window_active: window_text = "Active"
	role_strip_label.text = Locale.t("dock.assignment") % [_strip_assignment, window_text]

func _on_inventory_updated(avail: Array, loaded: Array, cap_used: float, cap_max: float) -> void:
	_as400.last_avail_cache = avail.duplicate(true)
	_as400.last_loaded_cache = loaded.duplicate(true)
	_refresh_combine_btn()
	
	if _as400.state == 8 or _as400.state == 18:
		_as400._render_as400_screen() 

	_dock.populate(avail, loaded, cap_used, cap_max)
	
	if tutorial_active:
		if tutorial_step == 8:
			for p in loaded:
				if p.type == "Mecha":
					tutorial_step = 9
					_tut.update_ui()
					break
		elif tutorial_step == 9:
			var has_mecha = false
			for p in loaded:
				if p.type == "Mecha": has_mecha = true
			if not has_mecha:
				tutorial_step = 10
				_tut.update_ui()
		elif tutorial_step == 10:
			for p in loaded:
				if p.type == "ServiceCenter":
					tutorial_step = 11
					_tut.update_ui()
					break
		elif tutorial_step == 11:
			for p in loaded:
				if p.type == "Bikes":
					tutorial_step = 12
					_tut.update_ui()
					break
		elif tutorial_step == 13:
			if avail.is_empty():
				tutorial_step = 14
				_tut.update_ui()

# ==========================================
# PHONE NOTIFICATION SYSTEM
# ==========================================
func _clear_phone_flash() -> void:
	phone_flash_active = false
	if _phone_flash_timer != null:
		_phone_flash_timer.stop()
		_phone_flash_timer.queue_free()
		_phone_flash_timer = null
	if btn_phone != null:
		btn_phone.text = (" " + Locale.t("btn.phone") + " ") if _sidebar_expanded else "PH"
		btn_phone.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))

func _on_phone_pallets_delivered() -> void:
	_update_phone_content()
	if _dock.lbl_hover_info:
		_dock.lbl_hover_info.text = "[font_size=15][color=#2ecc71][b]" + Locale.t("dock.pallets_arrived") + "[/b][/color][/font_size]"

func _on_phone_notification(message: String, _pallets_added: int) -> void:
	phone_messages.append(message)
	phone_flash_active = true
	WOTSAudio.play_error_buzz(self)

	# Update phone panel content live
	_update_phone_content()

	# Kill any existing flash timer before starting a new one
	if _phone_flash_timer != null:
		_phone_flash_timer.stop()
		_phone_flash_timer.queue_free()
		_phone_flash_timer = null

	if btn_phone != null:
		# Set text immediately (no toggling — prevents width jitter)
		btn_phone.text = (" " + Locale.t("btn.phone") + " (!) ") if _sidebar_expanded else "PH"
		var flash_state := {"count": 0}
		var timer := Timer.new()
		timer.wait_time = 0.4
		timer.one_shot = false
		add_child(timer)
		_phone_flash_timer = timer
		timer.timeout.connect(func() -> void:
			if not phone_flash_active:
				timer.stop()
				timer.queue_free()
				if _phone_flash_timer == timer:
					_phone_flash_timer = null
				return
			flash_state.count += 1
			# Only flash the color — text stays fixed
			if flash_state.count % 2 == 0:
				btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			else:
				btn_phone.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
			if flash_state.count >= 10:
				timer.stop()
				timer.queue_free()
				if _phone_flash_timer == timer:
					_phone_flash_timer = null
				# Stay in red after flashing ends
				if phone_flash_active and btn_phone != null:
					btn_phone.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		)
		timer.start()

	# Phone just flashes — user opens it manually

func _update_phone_content() -> void:
	var ph_body: RichTextLabel = _find_panel_body(pnl_phone)
	if ph_body == null: return
	var t: String = "[font_size=14]"
	t += "[color=#0082c3][b]PHONE[/b][/color]\n"
	t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	# Show delivery-in-progress banner if pallets are on their way
	if _session != null and _session._phone_deliver_timer > 0.0:
		t += "[color=#f1c40f][b]⏳ Pallets on the way — arriving in ~10 seconds.[/b][/color]\n\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	if phone_messages.size() > 0:
		for i: int in range(phone_messages.size() - 1, -1, -1):
			# Messages at original index < _phone_seen_count have been answered
			if i < _phone_seen_count:
				t += "[color=#2ecc71]✓ Answered[/color]\n"
			else:
				t += "[color=#f1c40f]⬤ NEW[/color]\n"
			t += phone_messages[i] + "\n\n"
			if i > 0:
				t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
	else:
		t += "[color=#95a5a6]No incoming calls.\n\n"
		t += "Departments will call about late pallets\n"
		t += "and priority changes during loading.\n\n"
		t += "[b]Quick dial:[/b]\n"
		t += "  DOUBLON: 1003\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001[/color]\n"
	t += "[/font_size]"
	ph_body.text = t
func _init_panel_nodes_and_buttons(dock_view_button: Button) -> void:
	_panel_nodes.clear()
	_panel_nodes["Dock View"] = _dock.panel
	_panel_nodes["AS400"] = pnl_as400_stage
	
	_panel_nodes["Shift Board"] = pnl_shift_board
	_panel_nodes["Trailer Capacity"] = pnl_trailer_capacity
	_panel_nodes["Phone"] = pnl_phone
	_panel_nodes["Notes"] = pnl_notes
	
	if dock_view_button != null: dock_view_button.pressed.connect(func() -> void: _toggle_panel("Dock View"))
	if btn_shift_board != null: btn_shift_board.pressed.connect(func() -> void: _toggle_panel("Shift Board"))
	if btn_as400 != null: btn_as400.pressed.connect(func() -> void: _toggle_panel("AS400"))
	if btn_trailer_capacity != null: btn_trailer_capacity.pressed.connect(func() -> void: _toggle_panel("Trailer Capacity"))
	if btn_phone != null: btn_phone.pressed.connect(func() -> void: _toggle_panel("Phone"))
	if btn_notes != null: btn_notes.pressed.connect(func() -> void: _toggle_panel("Notes"))

func _reset_panel_state() -> void:
	_panel_state.clear()
	panels_ever_opened.clear()
	for panel_name in PANEL_NAMES: _panel_state[panel_name] = false

# ==========================================
# SIDEBAR COLLAPSE / EXPAND
# ==========================================

func _on_sidebar_pin_pressed() -> void:
	if _sidebar_expanded:
		_sidebar_pin_btn.text = ">>"
		_sidebar_pin_btn.tooltip_text = "Expand sidebar"
		_collapse_sidebar()
	else:
		_sidebar_pin_btn.text = "<<"
		_sidebar_pin_btn.tooltip_text = "Collapse sidebar"
		_expand_sidebar()

func _on_sidebar_mouse_entered() -> void:
	pass

func _on_sidebar_mouse_exited() -> void:
	pass

func _expand_sidebar() -> void:
	if _sidebar_expanded:
		return
	_sidebar_expanded = true
	_animate_sidebar_expand()
	_reposition_overlay_panels()
	# Reset button scales to full
	for btn: Button in _sidebar_btn_labels:
		btn.pivot_offset = Vector2.ZERO
		btn.scale = Vector2.ONE

func _collapse_sidebar() -> void:
	if not _sidebar_expanded:
		return
	_sidebar_expanded = false
	_animate_sidebar_collapse()
	_reposition_overlay_panels()
	# Apply small scale to collapsed buttons after animation
	(func() -> void:
		await get_tree().create_timer(SIDEBAR_ANIM_DURATION + 0.15).timeout
		if not _sidebar_expanded:
			for btn: Button in _sidebar_btn_labels:
				btn.pivot_offset = btn.size * 0.5
				btn.scale = Vector2(0.85, 0.85)
	).call()

func _animate_sidebar_expand() -> void:
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar == null: return
	if _sidebar_tween != null and _sidebar_tween.is_valid():
		_sidebar_tween.kill()
	_set_sidebar_buttons_alpha(1.0)
	_sidebar_tween = create_tween()
	_sidebar_tween.set_ease(Tween.EASE_IN)
	_sidebar_tween.set_trans(Tween.TRANS_SINE)
	_sidebar_tween.tween_method(_set_sidebar_buttons_alpha, 1.0, 0.0, 0.1)
	_sidebar_tween.tween_callback(_update_sidebar_button_text.bind(true))
	_sidebar_tween.set_ease(Tween.EASE_OUT)
	_sidebar_tween.set_trans(Tween.TRANS_CUBIC)
	_sidebar_tween.tween_property(
		toggle_bar, "custom_minimum_size:x", SIDEBAR_EXPANDED_W, SIDEBAR_ANIM_DURATION
	)
	_sidebar_tween.set_ease(Tween.EASE_OUT)
	_sidebar_tween.set_trans(Tween.TRANS_SINE)
	_sidebar_tween.tween_method(_set_sidebar_buttons_alpha, 0.0, 1.0, 0.12)

func _animate_sidebar_collapse() -> void:
	var toggle_bar: PanelContainer = $Root/FrameVBox/MainHBox/PanelToggleBar
	if toggle_bar == null: return
	if _sidebar_tween != null and _sidebar_tween.is_valid():
		_sidebar_tween.kill()
	_set_sidebar_buttons_alpha(1.0)
	_sidebar_tween = create_tween()
	_sidebar_tween.set_ease(Tween.EASE_IN)
	_sidebar_tween.set_trans(Tween.TRANS_SINE)
	_sidebar_tween.tween_method(_set_sidebar_buttons_alpha, 1.0, 0.0, 0.1)
	_sidebar_tween.tween_callback(_update_sidebar_button_text.bind(false))
	_sidebar_tween.set_ease(Tween.EASE_OUT)
	_sidebar_tween.set_trans(Tween.TRANS_CUBIC)
	_sidebar_tween.tween_property(
		toggle_bar, "custom_minimum_size:x", SIDEBAR_COLLAPSED_W, SIDEBAR_ANIM_DURATION
	)
	_sidebar_tween.set_ease(Tween.EASE_OUT)
	_sidebar_tween.set_trans(Tween.TRANS_SINE)
	_sidebar_tween.tween_method(_set_sidebar_buttons_alpha, 0.0, 1.0, 0.12)

func _set_sidebar_buttons_alpha(alpha: float) -> void:
	for btn: Button in _sidebar_btn_labels:
		btn.modulate.a = alpha
	if _sidebar_panels_lbl != null:
		_sidebar_panels_lbl.modulate.a = alpha
	if _sidebar_pin_btn != null:
		_sidebar_pin_btn.modulate.a = alpha

func _on_sidebar_btn_hover_entered(btn: Button) -> void:
	if _sidebar_expanded: return
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	btn.pivot_offset = btn.size * 0.5
	tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.12)

func _on_sidebar_btn_hover_exited(btn: Button) -> void:
	if _sidebar_expanded: return
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.1)

func _update_sidebar_button_text(expanded: bool) -> void:
	for btn: Button in _sidebar_btn_labels:
		var data: Dictionary = _sidebar_btn_labels[btn]
		if expanded:
			btn.text = data["label"]
		else:
			btn.text = data["icon"]
	if _sidebar_panels_lbl:
		_sidebar_panels_lbl.visible = expanded
	if _sidebar_pin_btn:
		_sidebar_pin_btn.text = "<<" if expanded else ">>"
		_sidebar_pin_btn.visible = true

func _close_all_panels(silent: bool) -> void:
	for panel_name in PANEL_NAMES: _set_panel_visible(panel_name, false, silent)

func _toggle_panel(panel_name: String) -> void:
	var is_open: bool = bool(_panel_state.get(panel_name, false))
	# Tutorial gates only block OPENING panels, never closing
	if tutorial_active and not is_open:
		if tutorial_step < 3 and panel_name != "AS400":
			_tut.flash_warning(Locale.t("warn.open_as400_first"))
			return
		if tutorial_step == 3 and panel_name != "AS400" and panel_name != "Shift Board":
			_tut.flash_warning(Locale.t("warn.check_shift_board_seal"))
			return
		if tutorial_step == 4 and panel_name != "Dock View" and panel_name != "AS400":
			_tut.flash_warning(Locale.t("warn.open_dock_view"))
			return
		if tutorial_step == 5 and panel_name != "AS400" and panel_name != "Dock View":
			_tut.flash_warning(Locale.t("warn.open_as400_f13"))
			return

	_set_panel_visible(panel_name, not is_open, false)
	WOTSAudio.play_panel_click(self)

func _set_panel_visible(panel_name: String, make_visible: bool, _silent: bool) -> void:
	_panel_state[panel_name] = make_visible
	if make_visible: panels_ever_opened[panel_name] = true 
	
	var node = _panel_nodes.get(panel_name, null)
	if node != null: node.visible = make_visible

	if lbl_standby != null:
		var any_open = false
		for p in _panel_state.keys():
			if _panel_state[p]: any_open = true
		lbl_standby.visible = not any_open

	if panel_name == "AS400" and make_visible and _as400 != null:
		_as400.grab_input_focus()
	
	# Clear phone flash when Phone panel is opened, and always refresh content
	if panel_name == "Phone":
		if make_visible:
			_clear_phone_flash()
			_phone_seen_count = phone_messages.size()
			_update_phone_content()
			# Tell SessionManager the phone was opened — starts pallet delivery timer
			if _session != null:
				_session.call("manual_decision", "Phone Opened")
		else:
			# On close, ensure button is in clean state
			if btn_phone != null and not phone_flash_active:
				btn_phone.text = (" " + Locale.t("btn.phone") + " ") if _sidebar_expanded else "PH"
				btn_phone.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
		
	if tutorial_active:
		if tutorial_step == 0 and panel_name == "AS400" and make_visible:
			tutorial_step = 1
			_tut.update_ui()
		elif tutorial_step == 4 and panel_name == "Dock View" and make_visible:
			tutorial_step = 5
			_tut.update_ui()

# ==========================================
# OVERLAY PANEL STYLING & CONTENT
# ==========================================
func _style_overlay_panels() -> void:
	var overlay_panels = [pnl_shift_board, pnl_phone, pnl_notes]
	for p in overlay_panels:
		if p == null: continue
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.13)
		sb.border_width_left = 1
		sb.border_color = Color(0.2, 0.22, 0.25)
		p.add_theme_stylebox_override("panel", sb)
	_reposition_overlay_panels_instant()
	# Style title labels inside each panel
	for p in overlay_panels:
		if p == null: continue
		var margin = p.get_child(0) if p.get_child_count() > 0 else null
		if margin == null: continue
		var vbox = margin.get_child(0) if margin.get_child_count() > 0 else null
		if vbox == null: continue
		var title_lbl = vbox.get_child(0) if vbox.get_child_count() > 0 else null
		if title_lbl and title_lbl is Label:
			title_lbl.add_theme_font_size_override("font_size", 16)
			title_lbl.add_theme_color_override("font_color", Color(0.0, 0.51, 0.76))
		var body = vbox.get_child(1) if vbox.get_child_count() > 1 else null
		if body and body is RichTextLabel:
			body.add_theme_color_override("default_color", Color(0.7, 0.73, 0.77))

func _reposition_overlay_panels() -> void:
	var sidebar_w: float = SIDEBAR_EXPANDED_W if _sidebar_expanded else SIDEBAR_COLLAPSED_W
	var right_offset: float = -(sidebar_w + 16.0)
	for p in [pnl_shift_board, pnl_phone, pnl_notes]:
		if p == null: continue
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(p, "offset_right", right_offset, SIDEBAR_ANIM_DURATION)

func _reposition_overlay_panels_instant() -> void:
	var sidebar_w: float = SIDEBAR_EXPANDED_W if _sidebar_expanded else SIDEBAR_COLLAPSED_W
	var right_offset: float = -(sidebar_w + 16.0)
	for p in [pnl_shift_board, pnl_phone, pnl_notes]:
		if p == null: continue
		p.offset_right = right_offset

func _populate_overlay_panels() -> void:
	# --- SHIFT BOARD (merged with Loading Plan) ---
	# Hide the now-unused loading plan panel
	if pnl_loading_plan != null: pnl_loading_plan.visible = false

	var sb_body: RichTextLabel = _find_panel_body(pnl_shift_board)
	if sb_body:
		var operators: Array = ["Benancio", "Lydia", "Lorena", "Zuzanna", "Georgios", "Damian", "Juan", "Jakub", "Camilo", "Vasco"]
		operators.shuffle()
		var team_str: String = ""
		for i: int in range(mini(operators.size(), 6)):
			team_str += "  %d. %s\n" % [i + 1, operators[i]]

		var t: String = "[font_size=14]"
		t += "[color=#0082c3][b]SHIFT BOARD — Bay B2B[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[color=#f1c40f][b]DATE:[/b][/color] 25/03/2026   [color=#f1c40f][b]SHIFT:[/b][/color] AM\n\n"

		t += "[b]TEAM TODAY:[/b]\n"
		t += team_str + "\n"

		# Loading schedule — full day plan
		t += "[b]LOADING PLAN — 25/03/2026[/b]\n"
		t += "[color=#5a6a7a]TIME    STORE                     TYPE   CARRIER    SIZE[/color]\n"
		t += "[color=#5a6a7a]──────────────────────────────────────────────────────[/color]\n"
		if current_dest2_name != "":
			t += "[color=#f1c40f]09:00   %s %s (Seq.1) /  CO     DHL        13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
			t += "[color=#f1c40f]        %s %s (Seq.2)[/color]\n" % [current_dest2_name, current_dest2_code]
			t += "[color=#f1c40f]        Seal Seq.1: [b]%s[/b]   Seal Seq.2: [b]%s[/b][/color]\n" % [seal_number_1, seal_number_2]
		else:
			# During tutorial, highlight the store code and seal in a vivid color
			if tutorial_active:
				t += "[color=#f1c40f]09:00   %-14s [/color][color=#ff44ff][b]%s[/b]  ← STORE CODE[/color][color=#f1c40f]  SOLO   DHL        13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
				t += "[color=#f1c40f]        Seal: [/color][color=#ff44ff][b]%s[/b]  ← SEAL NUMBER[/color]\n" % seal_number_1
			else:
				t += "[color=#f1c40f]09:00   %-14s %-5s  SOLO   DHL        13.6m  ← YOUR LOAD[/color]\n" % [current_dest_name, current_dest_code]
				t += "[color=#f1c40f]        Seal: [b]%s[/b][/color]\n" % seal_number_1
		t += "10:30   DEN BOSCH 3619             SOLO   DHL        13.6m\n"
		t += "11:00   ARENA 256                  SOLO   DHL        13.6m\n"
		t += "11:30   KERKRADE 346 /             CO     SCHOTPOORT 13.6m\n"
		t += "        ROERMOND 2094\n"
		t += "12:00   BREDA 1088                 SOLO   DHL        8.5m\n"
		t += "13:00   COOLSINGEL 1161 /          CO     P&M        13.6m\n"
		t += "        DEN HAAG 1186\n"
		t += "13:30   EINDHOVEN 1185             SOLO   DHL        13.6m\n"
		t += "14:30   TILBURG 2013               SOLO   DHL        8.5m\n"
		t += "[color=#5a6a7a]Live: ARENA 256, BREDA 1088  ·  Non-live: all others[/color]\n\n"

		t += "[b]EMBALLAGE:[/b]\n"
		t += "  Dock 12 — non-live (from night shift)\n\n"
		t += "[b]EMERGENCY CONTACTS:[/b]\n"
		t += "  [color=#e74c3c]DOUBLON: 1003[/color]\n"
		t += "  DUTY: 1002\n"
		t += "  WELCOME DESK: 1001\n\n"
		t += "[b]NOTES:[/b]\n"
		t += "  Sorter maintenance 14:00-15:00\n"
		t += "[/font_size]"
		sb_body.text = t

	# --- PHONE ---
	_update_phone_content()

	# --- NOTES ---
	var notes_body = _find_panel_body(pnl_notes)
	if notes_body:
		var t = "[font_size=14]"
		t += "[color=#0082c3][b]NOTES[/b][/color]\n"
		t += "[color=#5a6a7a]────────────────────────────────────────[/color]\n\n"
		t += "[color=#95a5a6]Jot down what you notice during the shift.\n\n"
		t += "In the real warehouse, operators keep a\n"
		t += "mental note of anomalies and flag them\n"
		t += "at shift handover.\n\n"
		t += "Things to watch for:\n"
		t += "• Missing pallets on dock vs AS400\n"
		t += "• Damaged goods\n"
		t += "• Capacity issues\n"
		t += "• Sorter delays[/color]\n"
		t += "[/font_size]"
		notes_body.text = t

func _find_panel_body(panel: PanelContainer) -> RichTextLabel:
	if panel == null: return null
	var margin = panel.get_child(0) if panel.get_child_count() > 0 else null
	if margin == null: return null
	var vbox = margin.get_child(0) if margin.get_child_count() > 0 else null
	if vbox == null: return null
	if vbox.get_child_count() > 1:
		var body = vbox.get_child(1)
		if body is RichTextLabel: return body
	return null
