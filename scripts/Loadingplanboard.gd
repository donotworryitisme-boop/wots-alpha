class_name LoadingPlanBoard
extends RefCounted

var _ui: BayUI
var _container: VBoxContainer = null

# Field colors centralized in UITokens (CLR_STORE, CLR_STORE_DIM, CLR_SEAL, CLR_DOCK, CLR_DOCK_DIM)

const CTX: Array = [
	{"t":"07:30","s":"", "ty":"SOLO","r":"YES","st":"Den Bosch 3619",       "tr":"8.5m", "ca":"DHL",       "dk":13,"in":"LIVE LOADING","sp":""},
	{"t":"08:30","s":"1","ty":"CO",  "r":"YES","st":"Bilderdijkstraat 2682","tr":"8.5m", "ca":"DHL",       "dk":12,"in":"LIVE LOADING","sp":""},
	{"t":"08:30","s":"2","ty":"CO",  "r":"YES","st":"Wibautstraat 2678",    "tr":"8.5m", "ca":"DHL",       "dk":12,"in":"LIVE LOADING","sp":""},
	{"t":"11:00","s":"", "ty":"SOLO","r":"NO", "st":"Utrecht The Wall 2095","tr":"13.6m","ca":"DHL",       "dk":10,"in":"",            "sp":""},
	{"t":"14:00","s":"", "ty":"SOLO","r":"YES","st":"Kerkrade 346",         "tr":"13.6m","ca":"DHL",       "dk":11,"in":"LIVE LOADING","sp":""},
	{"t":"14:00","s":"", "ty":"SOLO","r":"YES","st":"Arnhem 1089",          "tr":"13.6m","ca":"SCHOTPOORT","dk":24,"in":"",            "sp":""},
	{"t":"15:00","s":"", "ty":"SOLO","r":"YES","st":"Eindhoven 1185",       "tr":"8.5m", "ca":"P&M",       "dk":13,"in":"LIVE LOADING","sp":""},
	{"t":"15:30","s":"", "ty":"SOLO","r":"YES","st":"Tilburg 2013",         "tr":"8.5m", "ca":"P&M",       "dk":13,"in":"LIVE LOADING","sp":""},
	{"t":"16:00","s":"", "ty":"SOLO","r":"YES","st":"Best 664",             "tr":"13.6m","ca":"SCHOTPOORT","dk":23,"in":"Has emballage","sp":"emb"},
	{"t":"17:00","s":"", "ty":"SOLO","r":"NO", "st":"Breda 1088",           "tr":"13.6m","ca":"DHL",       "dk":14,"in":"",            "sp":""},
	{"t":"19:00","s":"", "ty":"SOLO","r":"NO", "st":"Arena 256",            "tr":"13.6m","ca":"DHL",       "dk":11,"in":"",            "sp":""},
]

const SEAL_ART: Array[String] = [
	"..XXXXXXXXXXXXXXXX..................................................................................",
	".XXXXXXXXXXXXXXXXXX.................................................................................",
	"XXXXXXXXXXXXXXXXXXXX................................................................................",
	"XXXXXXXXXXXXXXXXXXXX..XXXX..........................................................................",
	"XXXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX....",
	"XXXXXXXXXXXXXXXXXXXX.XXOOXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX..",
	"XXXXXXXXXXXXXXXXXXXX.XXOOXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX..",
	"XXXXXXXXXXXXXXXXXXXX.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX....",
	"XXXXXXXXXXXXXXXXXXXX..XXXX..........................................................................",
	"XXXXXXXXXXXXXXXXXXXX................................................................................",
	".XXXXXXXXXXXXXXXXXX.................................................................................",
	"..XXXXXXXXXXXXXXXX..................................................................................",
]
const SEAL_SCALE: int = 4
const SEAL_TAG_W: int = 20


func _init(ui: BayUI) -> void:
	_ui = ui


func populate() -> void:
	var panel: PanelContainer = _ui.pnl_shift_board
	if panel == null: return
	var margin_n: Node = panel.get_child(0) if panel.get_child_count() > 0 else null
	if margin_n == null: return
	var vbox_n: Node = margin_n.get_child(0) if margin_n.get_child_count() > 0 else null
	if vbox_n == null: return
	var sb_body: RichTextLabel = _ui._paper.find_panel_body(panel)
	if sb_body != null:
		sb_body.visible = false
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
		_container = null
	_container = VBoxContainer.new()
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_theme_constant_override("separation", 0)
	vbox_n.add_child(_container)
	vbox_n.move_child(_container, 1)

	var hdr: Label = Label.new()
	hdr.text = "OFFICE \u2014 Bay B2B   %s   SHIFT: AM" % UITokens.LOADING_DATE
	hdr.add_theme_font_size_override("font_size", UITokens.fs(13))
	hdr.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	_container.add_child(hdr)
	var plan_m: MarginContainer = MarginContainer.new()
	plan_m.add_theme_constant_override("margin_top", 4)
	plan_m.add_theme_constant_override("margin_bottom", 2)
	var plan_lbl: Label = Label.new()
	plan_lbl.text = "LOADING PLAN"
	plan_lbl.add_theme_font_size_override("font_size", UITokens.fs(12))
	plan_lbl.add_theme_color_override("font_color", UITokens.CLR_BORDER_LIGHT)
	plan_m.add_child(plan_lbl)
	_container.add_child(plan_m)
	_container.add_child(_header_row())

	var tbody: VBoxContainer = VBoxContainer.new()
	tbody.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbody.add_theme_constant_override("separation", 0)
	_container.add_child(tbody)
	var rows: Array = []
	for ctx: Dictionary in CTX:
		rows.append({"d": ctx, "a": false})
	rows.append({"d": _player_load(), "a": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["d"] as Dictionary)["t"] < (b["d"] as Dictionary)["t"])
	var idx: int = 0
	for entry: Dictionary in rows:
		tbody.add_child(_data_row(entry["d"] as Dictionary, entry["a"] as bool, idx))
		idx += 1

	_container.add_child(_seal_visual(_ui.seal_number_1))
	if _ui.seal_number_2 != "" and _ui.current_dest2_name != "":
		_container.add_child(_seal_visual(_ui.seal_number_2))
	_container.add_child(_footer())


func reset() -> void:
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
		_container = null


func _player_load() -> Dictionary:
	var lt: String = "SOLO"
	var sq: String = ""
	if _ui.current_dest2_name != "":
		lt = "CO"; sq = "1"
	var st: String = "%s %s" % [_ui.current_dest_name, _ui.current_dest_code]
	if _ui.current_dest2_name != "":
		st = "%s %s / %s %s" % [_ui.current_dest_name, _ui.current_dest_code, _ui.current_dest2_name, _ui.current_dest2_code]
	var ca: String = _ui._session.carrier_name if _ui._session != null else ""
	var dk: int = _ui._session.dock_number if _ui._session != null else 0
	return {"t":"09:00","s":sq,"ty":lt,"r":"YES","st":st,"tr":"13.6m","ca":ca,"dk":dk,"in":"LIVE LOADING","sp":""}


func _header_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var names: Array[String] = ["TIME","SEQ","TYPE","RET","STORE NAME AND NUMBER","TRUCK","CARRIER","DOCK","INFO"]
	var widths: Array[int] = [52, 28, 44, 38, 0, 46, 62, 36, 0]
	# Tint headers to match field colors
	var hdr_colors: Array[Color] = [
		UITokens.CLR_SURFACE_RAISED, UITokens.CLR_SURFACE_RAISED, UITokens.CLR_SURFACE_RAISED, UITokens.CLR_SURFACE_RAISED,
		UITokens.CLR_STORE_DIM,  # STORE header
		UITokens.CLR_SURFACE_RAISED, UITokens.CLR_SURFACE_RAISED,
		UITokens.CLR_DOCK_DIM,   # DOCK header
		UITokens.CLR_SURFACE_RAISED,
	]
	for i: int in range(names.size()):
		var lbl: Label = Label.new()
		lbl.text = names[i]
		lbl.add_theme_font_size_override("font_size", UITokens.fs(9))
		lbl.add_theme_color_override("font_color", hdr_colors[i])
		if widths[i] > 0:
			lbl.custom_minimum_size.x = widths[i]
			if i > 0: lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if i == 4: lbl.size_flags_stretch_ratio = 1.5
		row.add_child(lbl)
	return row


func _data_row(d: Dictionary, active: bool, idx: int) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat
	if active:
		sb = UIStyles.flat(Color(UITokens.COLOR_ACCENT_BLUE, 0.12))
		sb.border_color = UITokens.CLR_WARNING
		sb.border_width_left = 3
	elif idx % 2 == 1:
		sb = UIStyles.flat(Color(1.0, 1.0, 1.0, 0.02))
	else:
		sb = UIStyles.flat(Color.TRANSPARENT)
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	pc.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	pc.add_child(row)
	var tv: String = d.get("t", "") as String
	var sv: String = d.get("s", "") as String
	var ty: String = d.get("ty", "") as String
	var rv: String = d.get("r", "") as String
	var st: String = d.get("st", "") as String
	var trv: String = d.get("tr", "") as String
	var ca: String = d.get("ca", "") as String
	var dk: int = d.get("dk", 0) as int
	var inf: String = d.get("in", "") as String
	var sp: String = d.get("sp", "") as String
	var fs: int = UITokens.fs(13) if active else UITokens.fs(12)

	var t_l: Label = _sized(52, false)
	t_l.text = ("\u25B6 " + tv) if active else tv
	t_l.add_theme_font_size_override("font_size", fs)
	t_l.add_theme_color_override("font_color", UITokens.CLR_WARNING if active else UITokens.CLR_BORDER_LIGHT)
	row.add_child(t_l)
	var s_l: Label = _sized(28, true)
	s_l.text = sv if sv != "" else "\u2014"
	s_l.add_theme_font_size_override("font_size", UITokens.fs(11))
	s_l.add_theme_color_override("font_color", Color(0.33, 0.4, 0.47))
	row.add_child(s_l)
	var ty_c: Array = _type_colors(ty)
	row.add_child(_badge(44, ty, ty_c[0] as Color, ty_c[1] as Color))
	var rt_c: Array = _ret_colors(rv)
	row.add_child(_badge(38, rv, rt_c[0] as Color, rt_c[1] as Color))

	# STORE — always orange-tinted
	var st_l: Label = Label.new()
	st_l.text = st
	st_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_l.size_flags_stretch_ratio = 1.5
	st_l.add_theme_font_size_override("font_size", fs)
	st_l.add_theme_color_override("font_color", UITokens.CLR_STORE if active else UITokens.CLR_STORE_DIM)
	st_l.clip_text = true
	row.add_child(st_l)

	var tr_l: Label = _sized(46, true)
	tr_l.text = trv
	tr_l.add_theme_font_size_override("font_size", UITokens.fs(11))
	tr_l.add_theme_color_override("font_color", Color(0.53, 0.56, 0.6) if trv != "xxx" else Color(0.2, 0.22, 0.25))
	row.add_child(tr_l)
	if ca == "xxx" or ca == "":
		var cl: Label = _sized(62, true)
		cl.text = "\u2014"
		cl.add_theme_font_size_override("font_size", UITokens.fs(11))
		cl.add_theme_color_override("font_color", Color(0.2, 0.22, 0.25))
		row.add_child(cl)
	else:
		var cc: Array = _carrier_colors(ca)
		row.add_child(_badge(62, cc[2] as String, cc[0] as Color, cc[1] as Color))

	# DOCK — always blue-tinted
	var dk_l: Label = _sized(36, true)
	dk_l.text = str(dk) if dk > 0 else "\u2014"
	dk_l.add_theme_font_size_override("font_size", UITokens.fs(13) if active else UITokens.fs(12))
	dk_l.add_theme_color_override("font_color", UITokens.CLR_DOCK if active else UITokens.CLR_DOCK_DIM)
	row.add_child(dk_l)

	var in_l: Label = Label.new()
	in_l.text = inf if inf != "" else "\u2014"
	in_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	in_l.add_theme_font_size_override("font_size", UITokens.fs(11))
	in_l.clip_text = true
	if sp == "emb":
		in_l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.0))
	elif active:
		in_l.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	else:
		in_l.add_theme_color_override("font_color", Color(0.47, 0.5, 0.55))
	row.add_child(in_l)
	return pc


func _sized(min_w: int, centered: bool) -> Label:
	var lbl: Label = Label.new()
	lbl.custom_minimum_size.x = min_w
	if centered: lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _badge(min_w: int, text: String, bg: Color, fg: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", UITokens.fs(10))
	lbl.add_theme_color_override("font_color", fg)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bsb := UIStyles.flat_m(bg, 4, 1, 4, 1, 3)
	lbl.add_theme_stylebox_override("normal", bsb)
	return lbl


func _type_colors(t: String) -> Array:
	if t == "SOLO": return [UITokens.CLR_STORE, Color.WHITE]
	if t == "CO": return [Color(0.83, 0.83, 0.83), Color(0.13, 0.13, 0.13)]
	return [Color(0.4, 0.4, 0.4), Color(0.67, 0.67, 0.67)]

func _ret_colors(r: String) -> Array:
	if r == "YES": return [Color(0.0, 0.8, 0.27), Color.BLACK]
	if r == "NO": return [Color(0.47, 0.47, 0.47), UITokens.CLR_LIGHT_GRAY]
	return [Color(0.33, 0.33, 0.33), UITokens.CLR_LIGHT_GRAY]

func _carrier_colors(c: String) -> Array:
	var cu: String = c.to_upper()
	if cu == "DHL": return [Color(1.0, 0.8, 0.0), Color(0.8, 0.0, 0.0), "DHL"]
	if cu == "SCHOTPOORT": return [Color(0.4, 0.2, 0.8), Color.WHITE, "SCHOT"]
	if cu.begins_with("P"): return [Color(0.8, 0.2, 0.4), Color.WHITE, "P&M"]
	return [Color(0.33, 0.33, 0.33), Color(0.55, 0.55, 0.55), c]


func _seal_visual(seal_number: String) -> CenterContainer:
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art_w: int = SEAL_ART[0].length()
	var art_h: int = SEAL_ART.size()
	var sc: int = SEAL_SCALE
	var seal_ctrl: Control = Control.new()
	seal_ctrl.custom_minimum_size = Vector2(art_w * sc, art_h * sc)
	center.add_child(seal_ctrl)
	var img: Image = Image.create(art_w, art_h, false, Image.FORMAT_RGBA8)
	var yellow: Color = Color(0.95, 0.82, 0.08)
	var edge_clr: Color = Color(0.72, 0.62, 0.04)
	var hole_clr: Color = Color(0.15, 0.14, 0.12)
	for y: int in range(art_h):
		var row_str: String = SEAL_ART[y]
		for x: int in range(art_w):
			var ch: String = row_str[x]
			if ch == "X":
				var edge: bool = false
				if x > 0 and row_str[x - 1] == ".": edge = true
				elif x < art_w - 1 and row_str[x + 1] == ".": edge = true
				elif y > 0 and SEAL_ART[y - 1][x] == ".": edge = true
				elif y < art_h - 1 and SEAL_ART[y + 1][x] == ".": edge = true
				img.set_pixel(x, y, edge_clr if edge else yellow)
			elif ch == "O":
				img.set_pixel(x, y, hole_clr)
			else:
				img.set_pixel(x, y, Color.TRANSPARENT)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.texture = tex
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal_ctrl.add_child(tex_rect)
	# Seal number stamped on tag — green to match SEAL field color
	var num_lbl: Label = Label.new()
	num_lbl.text = seal_number
	num_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	num_lbl.add_theme_color_override("font_color", Color(0.08, 0.35, 0.15))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag_screen_w: float = SEAL_TAG_W * sc
	num_lbl.position = Vector2(2, 2)
	num_lbl.size = Vector2(tag_screen_w - 4, art_h * sc - 4)
	seal_ctrl.add_child(num_lbl)
	return center


func _footer() -> VBoxContainer:
	var ft: VBoxContainer = VBoxContainer.new()
	ft.add_theme_constant_override("separation", 1)
	ft.add_child(HSeparator.new())
	var ops: Array = ["Benancio","Lydia","Lorena","Zuzanna","Georgios","Damian","Juan","Jakub","Camilo","Vasco"]
	ops.shuffle()
	var lines: Array[String] = [
		"EMBALLAGE  Dock 12 \u2014 non-live (night shift)",
		"TEAM  %s" % ", ".join(ops.slice(0, 5)),
		"CONTACTS  DOUBLON 1003 \u00B7 DUTY 1002 \u00B7 DESK 1001",
		"Live: ARENA, BREDA \u00B7 Non-live: all others  |  Sorter maintenance 14:00\u201315:00",
	]
	var clrs: Array[Color] = [UITokens.CLR_TEXT_HINT, UITokens.CLR_TEXT_HINT, UITokens.CLR_TEXT_HINT, Color(0.27, 0.3, 0.33)]
	for i: int in range(lines.size()):
		var lbl: Label = Label.new()
		lbl.text = lines[i]
		lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
		lbl.add_theme_color_override("font_color", clrs[i])
		ft.add_child(lbl)
	return ft
