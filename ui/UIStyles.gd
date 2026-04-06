class_name UIStyles
extends RefCounted

## Centralized style factory — replaces inline StyleBoxFlat construction.
## Every method returns a fresh instance; safe to modify per-widget.


# ═══════════════════════════════════════════════════════════════════
# CORE STYLEBOX BUILDERS
# ═══════════════════════════════════════════════════════════════════

## Flat StyleBox with optional corner radius and border.
static func flat(bg: Color, corner_r: int = 0, border_w: int = 0,
		border_c: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if corner_r > 0:
		sb.set_corner_radius_all(corner_r)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border_c
	return sb


## Flat StyleBox with content margins.
static func flat_m(bg: Color, ml: float, mt: float, mr: float, mb: float,
		corner_r: int = 0, border_w: int = 0,
		border_c: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := flat(bg, corner_r, border_w, border_c)
	sb.content_margin_left = ml
	sb.content_margin_top = mt
	sb.content_margin_right = mr
	sb.content_margin_bottom = mb
	return sb


## Modal panel: dark bg, blue top accent border, rounded corners, shadow.
## Used by Portal, Briefing, Debrief, TrustContract.
static func modal(bg: Color = Color(0.12, 0.13, 0.16), corner_r: int = 8,
		shadow_sz: int = 30, shadow_a: float = 0.5) -> StyleBoxFlat:
	var sb := flat(bg, corner_r)
	sb.border_width_top = 3
	sb.border_color = UITokens.COLOR_ACCENT_BLUE
	sb.shadow_color = Color(0.0, 0.0, 0.0, shadow_a)
	sb.shadow_size = shadow_sz
	return sb


# ═══════════════════════════════════════════════════════════════════
# BUTTON STYLING
# ═══════════════════════════════════════════════════════════════════

## Full button quartet (normal / hover / pressed / focus) + font colors.
## Sets focus to StyleBoxEmpty and focus_mode to NONE.
static func apply_btn(btn: Button, n_bg: Color, h_bg: Color, p_bg: Color,
		font_clr: Color, font_h_clr: Color = Color.WHITE,
		corner_r: int = 6, border_w: int = 0,
		border_c: Color = Color.TRANSPARENT) -> void:
	btn.add_theme_stylebox_override("normal", flat(n_bg, corner_r, border_w, border_c))
	btn.add_theme_stylebox_override("hover", flat(h_bg, corner_r, border_w, border_c))
	btn.add_theme_stylebox_override("pressed", flat(p_bg, corner_r, border_w, border_c))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", font_clr)
	btn.add_theme_color_override("font_hover_color", font_h_clr)
	btn.focus_mode = Control.FOCUS_NONE


## Auto-derive hover (+15% lighter) and pressed (-10% darker) from base.
static func apply_btn_auto(btn: Button, bg: Color, font_clr: Color,
		font_h_clr: Color = Color.WHITE, corner_r: int = 6,
		border_w: int = 0, border_c: Color = Color.TRANSPARENT) -> void:
	apply_btn(btn, bg, bg.lightened(0.15), bg.darkened(0.1),
			font_clr, font_h_clr, corner_r, border_w, border_c)


## Blue accent primary button — Portal Start, Trust Accept, Briefing Continue.
## Normal: Decathlon Blue.  Hover: lighter + vivid border.  Pressed: deep dock.
static func apply_btn_primary(btn: Button, corner_r: int = 6,
		ml: float = 0.0, mt: float = 0.0,
		mr: float = 0.0, mb: float = 0.0) -> void:
	var n := flat(UITokens.COLOR_ACCENT_BLUE, corner_r)
	if ml > 0.0 or mt > 0.0 or mr > 0.0 or mb > 0.0:
		n.content_margin_left = ml
		n.content_margin_top = mt
		n.content_margin_right = mr
		n.content_margin_bottom = mb
	btn.add_theme_stylebox_override("normal", n)
	var h := flat(UITokens.CLR_BLUE_LIGHT, corner_r, 1, UITokens.CLR_BLUE_VIVID)
	if ml > 0.0 or mt > 0.0 or mr > 0.0 or mb > 0.0:
		h.content_margin_left = ml
		h.content_margin_top = mt
		h.content_margin_right = mr
		h.content_margin_bottom = mb
	btn.add_theme_stylebox_override("hover", h)
	var p := flat(UITokens.CLR_DOCK_DIM, corner_r)
	if ml > 0.0 or mt > 0.0 or mr > 0.0 or mb > 0.0:
		p.content_margin_left = ml
		p.content_margin_top = mt
		p.content_margin_right = mr
		p.content_margin_bottom = mb
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", UITokens.CLR_LANE_BG_ALT)
	btn.focus_mode = Control.FOCUS_NONE


## Blue accent primary with border (Trust / StartScreen variant).
static func apply_btn_primary_bordered(btn: Button, corner_r: int = 6,
		ml: float = 24.0, mt: float = 12.0,
		mr: float = 24.0, mb: float = 12.0) -> void:
	var n := flat_m(UITokens.COLOR_ACCENT_BLUE, ml, mt, mr, mb,
			corner_r, 2, Color(0.0, 0.41, 0.62))
	btn.add_theme_stylebox_override("normal", n)
	var h := flat_m(UITokens.CLR_BLUE_LIGHT, ml, mt, mr, mb,
			corner_r, 2, UITokens.CLR_BLUE_VIVID)
	btn.add_theme_stylebox_override("hover", h)
	var p := flat_m(UITokens.CLR_DOCK_DIM, ml, mt, mr, mb,
			corner_r, 2, Color(0.0, 0.30, 0.48))
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", UITokens.CLR_LANE_BG_ALT)
	btn.focus_mode = Control.FOCUS_NONE


## Transparent / ghost button — only hover shows a tinted bg.
static func apply_btn_ghost(btn: Button, hover_bg: Color,
		font_clr: Color, font_h_clr: Color,
		corner_r: int = 0) -> void:
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", flat(hover_bg, corner_r))
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", font_clr)
	btn.add_theme_color_override("font_hover_color", font_h_clr)
	btn.focus_mode = Control.FOCUS_NONE


# ═══════════════════════════════════════════════════════════════════
# PANEL STYLING
# ═══════════════════════════════════════════════════════════════════

## Apply a single StyleBox to a PanelContainer.
static func apply_panel(pnl: PanelContainer, sb: StyleBoxFlat) -> void:
	pnl.add_theme_stylebox_override("panel", sb)


# ═══════════════════════════════════════════════════════════════════
# DROPDOWN / OPTIONBUTTON
# ═══════════════════════════════════════════════════════════════════

## Standard dark dropdown (portal language/scenario pickers).
static func apply_dropdown(dd: OptionButton, left_margin: float = 12.0) -> void:
	var n := flat(Color(0.18, 0.19, 0.22), 4, 1, UITokens.CLR_SURFACE_MID)
	n.content_margin_left = left_margin
	dd.add_theme_stylebox_override("normal", n)
	var h := flat(UITokens.CLR_SURFACE_DIM, 4, 1, UITokens.COLOR_ACCENT_BLUE)
	h.content_margin_left = left_margin
	dd.add_theme_stylebox_override("hover", h)
	var p := flat(UITokens.CLR_BG_DARK, 4, 1, UITokens.COLOR_ACCENT_BLUE)
	p.content_margin_left = left_margin
	dd.add_theme_stylebox_override("pressed", p)
	dd.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	dd.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	dd.add_theme_color_override("font_hover_color", Color.WHITE)
	dd.add_theme_color_override("font_pressed_color", Color(0.7, 0.73, 0.77))
	dd.focus_mode = Control.FOCUS_NONE


## Standard dark popup menu for dropdowns.
static func apply_dropdown_popup(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel",
			flat(UITokens.CLR_BG_DARK, 4, 1, UITokens.CLR_SURFACE_MID))
	popup.add_theme_stylebox_override("hover", flat(UITokens.CLR_BLUE_DEEP))
	popup.add_theme_color_override("font_color", UITokens.CLR_PALLET_BORDER)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_selected_color", Color.WHITE)


# ═══════════════════════════════════════════════════════════════════
# FORM FIELDS
# ═══════════════════════════════════════════════════════════════════

## Dark form field with blue focus border (Loading Sheet inputs).
static func apply_field_dark(input: LineEdit) -> void:
	var bg := flat(UITokens.CLR_BG_DARK, 3, 1, Color(0.3, 0.32, 0.38))
	bg.set_content_margin_all(4)
	input.add_theme_stylebox_override("normal", bg)
	var bg_f := flat(UITokens.CLR_BG_DARK, 3, 1, UITokens.COLOR_ACCENT_BLUE)
	bg_f.set_content_margin_all(4)
	input.add_theme_stylebox_override("focus", bg_f)
	input.add_theme_color_override("font_color", Color.WHITE)
	input.add_theme_color_override("font_placeholder_color", UITokens.COLOR_TEXT_META)


## Light form field with focus border (CMR inputs).
static func apply_field_light(inp: Control, bg_c: Color = Color(0.95, 0.96, 1.0),
		border_c: Color = Color(0.7, 0.75, 0.85),
		focus_c: Color = Color(0.0, 0.3, 0.7)) -> void:
	var bg := flat(bg_c, 2, 1, border_c)
	bg.set_content_margin_all(3)
	inp.add_theme_stylebox_override("normal", bg)
	var bg_f := flat(bg_c, 2, 1, focus_c)
	bg_f.set_content_margin_all(3)
	inp.add_theme_stylebox_override("focus", bg_f)
