class_name ReplayScreenRenderer
extends RefCounted

# ==========================================
# REPLAY SCREEN RENDERER — Ghost Replay helper
# Renders BBCode "mini screen preview" panels showing
# what the user was seeing at a given moment during
# the replayed session: AS400 state, LS/CMR progress,
# workspace, dock status, and key decisions.
# ==========================================


## Renders the full screen context BBCode block.
## [param state]    Current snapshot dict from log_action (keys: ls, cmr, cf, ld, av, st)
## [param as400]    Current AS400 state integer (-1 = unknown)
## [param workspace] "DOCK" or "OFFICE"
## [param dock_open] Whether the dock is open
## [param decisions] Array of decision strings made so far
static func render(
		state: Dictionary,
		as400: int,
		workspace: String,
		dock_open: bool,
		decisions: Array[String],
) -> String:
	var bb: String = "[font_size=13]"
	bb += UITokens.BB_DIM + "─────────────────────" + UITokens.BB_END + "\n"

	# --- Workspace + dock row ---
	bb += _render_workspace_row(workspace, dock_open)

	# --- AS400 state ---
	if as400 >= 0:
		bb += _render_as400_state(as400)

	# --- LS progress ---
	bb += _render_field_progress("LS", state)

	# --- CMR progress ---
	bb += _render_cmr_progress(state)

	# --- Loaded / Available counts ---
	bb += _render_inventory_counts(state)

	# --- Decision checklist ---
	bb += _render_decisions(decisions)

	bb += UITokens.BB_DIM + "─────────────────────" + UITokens.BB_END + "\n\n"
	bb += "[/font_size]"
	return bb


static func _render_workspace_row(workspace: String, dock_open: bool) -> String:
	var ws_clr: String = UITokens.BB_ACCENT if workspace == "DOCK" else UITokens.BB_WARNING
	var ws_icon: String = "🏗" if workspace == "DOCK" else "🗂"
	var line: String = ws_icon + " " + ws_clr + "[b]" + workspace + "[/b]" + UITokens.BB_END

	if workspace == "DOCK":
		if dock_open:
			line += "  " + UITokens.BB_SUCCESS + "▸ Dock Open" + UITokens.BB_END
		else:
			line += "  " + UITokens.BB_DIM + "▸ Dock Closed" + UITokens.BB_END

	line += "\n"
	return line


static func _render_as400_state(state_id: int) -> String:
	var sname: String = _as400_state_name(state_id)
	var clr: String = UITokens.BB_HINT
	# Highlight key operational screens
	match state_id:
		8:  clr = UITokens.BB_ACCENT    # RAQ
		9:  clr = UITokens.BB_SUCCESS   # Validation
		18: clr = UITokens.BB_WARNING   # Scanning
		19: clr = UITokens.BB_ACCENT    # Saisie Expedition
	return "💻 " + clr + "AS400: " + sname + UITokens.BB_END + "\n"


static func _render_field_progress(label: String, state: Dictionary) -> String:
	var filled: int = int(state.get("ls", 0))
	var total: int = int(state.get("ls_max", 9))
	if total <= 0:
		total = 9
	var bar: String = _progress_bar(filled, total)
	var clr: String = UITokens.BB_SUCCESS if filled == total else UITokens.BB_HINT
	return "📋 " + clr + label + " " + bar + " " + str(filled) + "/" + str(total) + UITokens.BB_END + "\n"


static func _render_cmr_progress(state: Dictionary) -> String:
	var filled: int = int(state.get("cmr", 0))
	var total: int = int(state.get("cmr_max", 11))
	if total <= 0:
		total = 11
	var franco: bool = bool(state.get("cf", false))
	var bar: String = _progress_bar(filled, total)
	var clr: String = UITokens.BB_SUCCESS if filled == total else UITokens.BB_HINT
	var extras: String = ""
	if franco:
		extras += " ☑Franco"
	return "📄 " + clr + "CMR " + bar + " " + str(filled) + "/" + str(total) + extras + UITokens.BB_END + "\n"


static func _render_inventory_counts(state: Dictionary) -> String:
	var loaded: int = int(state.get("ld", 0))
	var avail: int = int(state.get("av", 0))
	var started: bool = bool(state.get("st", false))
	if not started and loaded == 0:
		return "📦 " + UITokens.BB_DIM + "Loading not started" + UITokens.BB_END + "\n"
	return "📦 " + UITokens.BB_HINT + "Loaded " + str(loaded) + "  Available " + str(avail) + UITokens.BB_END + "\n"


static func _render_decisions(decisions: Array[String]) -> String:
	if decisions.is_empty():
		return ""
	var checks: Array[String] = []
	for d: String in decisions:
		if d == "Call departments (C&C check)":
			checks.append("C&C ✓")
		elif d == "Start Loading":
			checks.append("Loading ✓")
		elif d == "Hand CMR to Driver":
			checks.append("CMR ✓")
		elif d == "Archive Papers":
			checks.append("Archived ✓")
		elif d == "Seal Truck":
			checks.append("Sealed ✓")
	if checks.is_empty():
		return ""
	return UITokens.BB_HINT + "  " + "  ".join(PackedStringArray(checks)) + UITokens.BB_END + "\n"


## Build a simple text progress bar: [████░░░░]
static func _progress_bar(filled: int, total: int) -> String:
	var bar_width: int = mini(total, 10)
	var filled_chars: int = 0
	if total > 0:
		@warning_ignore("integer_division")
		filled_chars = (filled * bar_width) / total
	var empty_chars: int = bar_width - filled_chars
	return "[" + "█".repeat(filled_chars) + "░".repeat(empty_chars) + "]"


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
