extends Node
class_name UITokens

# Neutral naming; no gameplay implications.
# Colors - ALIGNED WITH WOTS UI/UX COUNCIL (Light Industrial Theme)
const COLOR_BG: Color = Color(0.96, 0.96, 0.95, 1.0)          # Warm light gray
const COLOR_SURFACE: Color = Color(1.0, 1.0, 1.0, 1.0)        # Off-white / Pure white panels
const COLOR_BORDER: Color = Color(0.85, 0.86, 0.88, 1.0)      # Soft divider lines
const COLOR_TEXT_PRIMARY: Color = Color(0.12, 0.13, 0.15, 1.0) # Near black
const COLOR_TEXT_META: Color = Color(0.45, 0.48, 0.52, 1.0)    # Muted gray
const COLOR_ACCENT_BLUE: Color = Color(0.0, 0.51, 0.76, 1.0)  # Decathlon Blue (#0082C3)

# Operational colours (used in dock, debrief, panels)
const CLR_ERROR: Color = Color(0.91, 0.27, 0.24)              # Red #e74c3c
const CLR_SUCCESS: Color = Color(0.18, 0.80, 0.44)            # Green #2ecc71
const CLR_WARNING: Color = Color(0.95, 0.77, 0.06)            # Yellow #f1c40f
const CLR_MUTED: Color = Color(0.75, 0.78, 0.82)              # Sidebar muted text
const CLR_PANEL_BG: Color = Color(0.1, 0.11, 0.13)            # Dark panel background
const CLR_PANEL_BORDER: Color = Color(0.25, 0.27, 0.32)       # Panel border
const CLR_CHARCOAL: Color = Color(0.07, 0.08, 0.09)           # Start screen / dark backgrounds

# --- Field identification colours (consistent across board, LS labels, tutorial) ---
const CLR_STORE: Color = Color(1.0, 0.6, 0.0)                 # Orange — store code #ff9900
const CLR_STORE_DIM: Color = Color(0.75, 0.5, 0.1)            # Dim orange for context rows
const CLR_SEAL: Color = Color(0.18, 0.8, 0.44)                # Green — seal number #2ecc71
const CLR_DOCK: Color = Color(0.0, 0.51, 0.76)                # Blue — dock number #0082c3
const CLR_DOCK_DIM: Color = Color(0.0, 0.38, 0.58)            # Dim blue for context rows

# --- Pallet grid colours (live counter on Loading Sheet) ---
const CLR_EUR: Color = Color(0.16, 0.50, 0.72)                # Blue #2980b9
const CLR_PLASTIC: Color = Color(0.83, 0.33, 0.0)             # Orange #d35400
const CLR_MAGNUM: Color = Color(0.56, 0.27, 0.68)             # Purple #8e44ad
const CLR_CELL_EMPTY: Color = Color(0.18, 0.20, 0.24)         # Unfilled grid cell bg
const CLR_CELL_TEXT_DIM: Color = Color(0.35, 0.38, 0.42)      # Unfilled grid cell text

# --- Extended palette: dark-theme surfaces (deepest → lightest) ---
const CLR_BG_DARK: Color = Color(0.14, 0.15, 0.18)            # Dark surface for buttons/inputs
const CLR_SURFACE_DIM: Color = Color(0.22, 0.24, 0.28)        # Dim surface
const CLR_SURFACE_MID: Color = Color(0.3, 0.32, 0.35)         # Mid surface / lighter border
const CLR_SURFACE_RAISED: Color = Color(0.33, 0.37, 0.42)     # Raised surface / button bg

# --- Extended palette: text grays (darkest → lightest) ---
const CLR_TEXT_MID: Color = Color(0.5, 0.54, 0.58)            # Mid-brightness text
const CLR_TEXT_SECONDARY: Color = Color(0.6, 0.63, 0.67)      # Secondary text / labels
const CLR_TEXT_HINT: Color = Color(0.53, 0.6, 0.67)           # Hint text / subtle labels
const CLR_LIGHT_GRAY: Color = Color(0.85, 0.85, 0.85)         # Light gray text / separators
const CLR_BORDER_LIGHT: Color = Color(0.78, 0.8, 0.84)        # Light border / dividers
const CLR_WHITE: Color = Color(1.0, 1.0, 1.0)                 # Pure white

# --- Extended palette: blue spectrum ---
const CLR_BLUE_DEEP: Color = Color(0.0, 0.35, 0.55)           # Deep blue (hover states)
const CLR_BLUE_MID: Color = Color(0.2, 0.5, 0.8)              # Mid blue
const CLR_BLUE_LIGHT: Color = Color(0.0, 0.60, 0.88)          # Light blue
const CLR_BLUE_VIVID: Color = Color(0.0, 0.70, 1.0)           # Vivid blue / highlights
const CLR_BLUE_PETER: Color = Color(0.20, 0.60, 0.86)         # Peter River #3498db

# --- Extended palette: operational accents ---
const CLR_AMBER: Color = Color(0.94, 0.76, 0.2)               # Amber / gold
const CLR_ORANGE: Color = Color(0.9, 0.45, 0.15)              # Orange for type badges
const CLR_ORANGE_SOFT: Color = Color(0.9, 0.5, 0.15)          # Soft orange
const CLR_RED_DIM: Color = Color(0.8, 0.2, 0.2)               # Dim red
const CLR_RED_BRIGHT: Color = Color(1.0, 0.3, 0.3)            # Bright red
const CLR_CYAN: Color = Color(0.0, 0.70, 1.0)                 # Cyan / transit
const CLR_TRANSPARENT: Color = Color(0, 0, 0, 0)              # Fully transparent

# --- Extended palette: dock-specific ---
const CLR_DOCK_FLOOR: Color = Color(0.45, 0.46, 0.44)         # Dock floor concrete
const CLR_LANE_BG: Color = Color(0.85, 0.87, 0.9)             # Lane background
const CLR_LANE_BG_ALT: Color = Color(0.85, 0.90, 0.95)        # Lane background alternate
const CLR_PALLET_HOVER: Color = Color(0.9, 0.93, 1.0)         # Pallet hover highlight
const CLR_PALLET_BORDER: Color = Color(0.8, 0.82, 0.85)       # Pallet border

# --- CMR document colours (used by CMRForm for the paper replica) ---
const CLR_CMR_BORDER: Color = Color(0.6, 0.1, 0.08)           # CMR red border/header text
const CLR_CMR_PAPER: Color = Color(1.0, 0.99, 0.97)           # CMR parchment background
const CLR_CMR_INK: Color = Color(0.12, 0.12, 0.12)            # CMR black ink
const CLR_CMR_STAMP: Color = Color(0.0, 0.2, 0.6)             # CMR blue stamp/sign
const CLR_CMR_XMARK: Color = Color(0.1, 0.1, 0.8)             # CMR X-mark blue
const CLR_CMR_DEST2: Color = Color(0.0, 0.45, 0.0)            # CMR second-dest green text
const CLR_CMR_SECTION_BG: Color = Color(0.9, 0.93, 1.0)       # CMR section light-blue bg
const CLR_CMR_SECTION_BORDER: Color = Color(0.6, 0.7, 0.9)    # CMR section blue border
const CLR_CMR_SECTION_BG_ALT: Color = Color(0.85, 0.88, 1.0)  # CMR section alt bg (hover)

# --- Extended palette: modal / overlay ---
const CLR_MODAL_BG: Color = Color(0.10, 0.11, 0.14)           # Modal panel background
const CLR_OVERLAY_DARK: Color = Color(0.04, 0.05, 0.08)       # Near-black overlay (add alpha)
const CLR_SURFACE_DEEP: Color = Color(0.18, 0.19, 0.22)       # Deep dark surface / card bg
const CLR_INPUT_BG: Color = Color(0.13, 0.14, 0.17)           # Dark input / bar background
const CLR_TOGGLE_OFF: Color = Color(0.2, 0.21, 0.24)          # Toggle off / switch off bg
const CLR_TITLE_TEXT: Color = Color(0.92, 0.93, 0.95)          # Bright title text
const CLR_LABEL_DIM: Color = Color(0.55, 0.58, 0.62)          # Dim label / subtitle text
const CLR_TAB_INACTIVE: Color = Color(0.15, 0.2, 0.28)        # Inactive tab background

# ==========================================================================
# BBCode colour strings — use in RichTextLabel content
# Pattern: BB_NAME opens the tag; always close with [/color]
# ==========================================================================
const BB_ERROR: String = "[color=#e74c3c]"
const BB_SUCCESS: String = "[color=#2ecc71]"
const BB_WARNING: String = "[color=#f1c40f]"
const BB_ACCENT: String = "[color=#0082c3]"
const BB_WHITE: String = "[color=#ffffff]"
const BB_MUTED: String = "[color=#c0c8d0]"
const BB_LIGHT: String = "[color=#d0d4da]"
const BB_DIM: String = "[color=#8899aa]"
const BB_BLUE: String = "[color=#3498db]"
const BB_RED_BRIGHT: String = "[color=#ff4444]"
const BB_ORANGE: String = "[color=#e67e22]"
const BB_GRAY: String = "[color=#95a5a6]"
const BB_CYAN: String = "[color=#00ffff]"
const BB_META: String = "[color=#7f8fa6]"
const BB_STORE: String = "[color=#ff9900]"
const BB_HINT: String = "[color=#8a9aaa]"
const BB_GOLD: String = "[color=#c8a860]"
const BB_MAGNUM: String = "[color=#8e44ad]"
const BB_DOCK_HINT: String = "[color=#7a8a9a]"
const BB_SUBDUED: String = "[color=#b0b8c0]"
const BB_END: String = "[/color]"

# Spacing / radii (Strict 8px Grid)
const SPACING_8: int = 8
const SPACING_16: int = 16
const SPACING_24: int = 24
const RADIUS: int = 6 # Slightly tighter radius for a more professional/industrial feel

# Fonts
const FONT_BODY_SIZE: int = 16
const FONT_BODY_MEDIUM_SIZE: int = 16
const FONT_META_SIZE: int = 13

# Centralised loading date — single source of truth
const LOADING_DATE_D: int = 25
const LOADING_DATE_M: int = 3
const LOADING_DATE_Y: int = 2026
const LOADING_DATE: String = "25/03/2026"
const LOADING_DATE_DDMMYY: String = "250326"


# ==========================================================================
# HIGH-CONTRAST ACCESSIBILITY MODE
# ==========================================================================

## When true, fonts are larger (+4px), text colours are brighter, and
## borders are thicker / more visible. Toggled from portal settings.
## Persisted to user://wots_prefs.cfg.
static var high_contrast: bool = false

## Font size helper — returns base + 4 in high-contrast mode.
## Use everywhere instead of raw int literals for font_size overrides.
static func fs(base: int) -> int:
	return base + 4 if high_contrast else base

## Text colour helper — returns a noticeably brighter version in HC mode.
## Pass any dim/secondary text colour to get a readable HC alternative.
static func hc_text(normal: Color) -> Color:
	return normal.lightened(0.35) if high_contrast else normal

## Background colour helper — slightly lighter surfaces in HC mode
## so panel edges and depth are more visible.
static func hc_bg(normal: Color) -> Color:
	return normal.lightened(0.08) if high_contrast else normal

## Border width helper — returns thicker borders in HC mode.
static func hc_border(normal: int) -> int:
	return normal + 1 if high_contrast else normal

## Panel border colour — significantly brighter in HC mode.
static func hc_panel_border() -> Color:
	return Color(0.5, 0.53, 0.58) if high_contrast else CLR_PANEL_BORDER

## Disabled text — brighter in HC so disabled controls are still readable.
static func hc_disabled() -> Color:
	return Color(0.55, 0.57, 0.6) if high_contrast else CLR_CELL_TEXT_DIM


# ==========================================================================
# PREFERENCES PERSISTENCE
# ==========================================================================

const _PREFS_PATH: String = "user://wots_prefs.cfg"

static func load_preferences() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(_PREFS_PATH)
	if err != OK:
		return
	high_contrast = cfg.get_value("accessibility", "high_contrast", false)
	var saved_trainee: String = cfg.get_value("user", "active_trainee", "default")
	TrainingRecord.set_trainee(saved_trainee)
	Telemetry.enabled = cfg.get_value("telemetry", "enabled", false)
	if Telemetry.enabled:
		Telemetry.load_data()

static func save_preferences() -> void:
	var cfg := ConfigFile.new()
	# Load existing to preserve other sections
	var _err: Error = cfg.load(_PREFS_PATH)
	cfg.set_value("accessibility", "high_contrast", high_contrast)
	cfg.set_value("user", "active_trainee", TrainingRecord.active_trainee)
	cfg.set_value("telemetry", "enabled", Telemetry.enabled)
	cfg.save(_PREFS_PATH)

static func toggle_high_contrast() -> void:
	high_contrast = not high_contrast
	save_preferences()
