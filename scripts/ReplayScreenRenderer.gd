class_name ReplayScreenRenderer
extends RefCounted

# ==========================================
# REPLAY SCREEN RENDERER — Ghost Replay helper
# Builds visual pallet block Control nodes for the truck
# cross-section and provides AS400 state name mapping.
# ==========================================

## Type colors shared with GhostReplay.
const TYPE_COLORS: Dictionary = {
	"ServiceCenter": Color(0.18, 0.80, 0.44),
	"Bikes": Color(0.20, 0.60, 0.86),
	"Bulky": Color(0.90, 0.49, 0.13),
	"Mecha": Color(0.56, 0.27, 0.68),
	"ADR": Color(1.0, 0.3, 0.3),
	"C&C": Color(0.95, 0.77, 0.06),
}


## Creates a visual pallet block (PanelContainer) for the truck grid.
## Shows: sequence number, type abbreviation, promise date, D2 indicator.
static func make_pallet_block(
		index: int,
		ptype: String,
		pallet: Dictionary,
) -> PanelContainer:
	var clr: Color = TYPE_COLORS.get(ptype, Color(0.4, 0.42, 0.45))
	var block := PanelContainer.new()
	block.custom_minimum_size = Vector2(72, 0)
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyles.apply_panel(block, UIStyles.flat(clr.darkened(0.3), 6, 2, clr))

	var bmargin := MarginContainer.new()
	bmargin.add_theme_constant_override("margin_left", 4)
	bmargin.add_theme_constant_override("margin_top", 4)
	bmargin.add_theme_constant_override("margin_right", 4)
	bmargin.add_theme_constant_override("margin_bottom", 4)
	block.add_child(bmargin)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 2)
	bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bmargin.add_child(bvbox)

	# Sequence number
	var num_lbl := Label.new()
	num_lbl.text = str(index + 1)
	num_lbl.add_theme_font_size_override("font_size", UITokens.fs(18))
	num_lbl.add_theme_color_override("font_color", Color.WHITE)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvbox.add_child(num_lbl)

	# Type abbreviation
	var type_lbl := Label.new()
	type_lbl.text = _type_abbr(ptype)
	type_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	type_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvbox.add_child(type_lbl)

	# Promise date
	var promise: String = str(pallet.get("promise", ""))
	if promise != "":
		var prom_lbl := Label.new()
		prom_lbl.text = promise
		prom_lbl.add_theme_font_size_override("font_size", UITokens.fs(9))
		prom_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.5))
		prom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bvbox.add_child(prom_lbl)

	# Co-loading dest indicator
	var dest: int = int(pallet.get("dest", 1))
	if dest == 2:
		var dest_lbl := Label.new()
		dest_lbl.text = "D2"
		dest_lbl.add_theme_font_size_override("font_size", UITokens.fs(9))
		dest_lbl.add_theme_color_override("font_color", UITokens.CLR_STORE)
		dest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bvbox.add_child(dest_lbl)

	return block


## Type abbreviation for display.
static func _type_abbr(ptype: String) -> String:
	match ptype:
		"ServiceCenter": return "SC"
		"Bikes": return "BK"
		"Bulky": return "BU"
		"Mecha": return "ME"
		"ADR": return "AD"
		"C&C": return "CC"
	return ptype.left(2).to_upper()


## Maps AS400 state integer to a human-readable screen name.
static func _as400_state_name(state_id: int) -> String:
	match state_id:
		0:  return "Sign On"
		1:  return "Password"
		2:  return "Main Menu"
		3:  return "Ship/Dock Menu"
		4:  return "Parcel Menu"
		5:  return "Operation Menu"
		6:  return "Badge Login"
		7:  return "Badge Password"
		8:  return "RAQ"
		9:  return "Validation"
		15: return "Recep Dock"
		16: return "Impression"
		17: return "RAQ Par Magasin"
		18: return "Scanning"
		19: return "Saisie Expedition"
		20: return "GE Menu"
		21: return "Aide Decision"
		22: return "Expedition En Cours"
	return "State " + str(state_id)
