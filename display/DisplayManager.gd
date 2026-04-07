class_name DisplayManager
extends RefCounted

# ============================================================
# DISPLAY MANAGER — Resolution autodetect + manual override
# ============================================================
# Picks an appropriate window size and content_scale_factor based
# on the user's screen, with optional manual overrides stored in
# user prefs (display.* keys).
#
# Base canvas is 1280x1024 (set in project.godot). On screens larger
# than that, content_scale_factor is bumped up so text and panels
# have breathing room. The scale_override defaults to "auto" so
# the work PC at 1280x1024 gets 1.0x and a 1440p home setup gets
# ~1.4x without any user action.
#
# Public entry points:
#   apply_initial(node)        — call once at startup (Main.gd._ready)
#   apply(node)                — re-apply current state to the window
#   set_scale_override(v, n)   — UI calls when user picks a scale
#   set_size_override(w, h, n) — UI calls when user picks a window size
#   reset_to_auto(node)        — UI calls when user clicks Reset
#
# All state is static, so DisplayManager does NOT need to be an
# autoload — call the static methods from anywhere.
# ============================================================


# --- Sentinel values --------------------------------------------------
const SCALE_AUTO: float = -1.0
const SIZE_AUTO_X: int = -1
const SIZE_AUTO_Y: int = -1
const SIZE_FULLSCREEN_X: int = 0
const SIZE_FULLSCREEN_Y: int = 0

# --- Base canvas (matches project.godot viewport_width/height) --------
const BASE_WIDTH: int = 1280
const BASE_HEIGHT: int = 1024

# --- Prefs file -------------------------------------------------------
const PREFS_PATH: String = "user://wots_prefs.cfg"
const PREFS_SECTION: String = "display"

# --- Manual override state (loaded from prefs at startup) -------------
static var scale_override: float = SCALE_AUTO
static var size_override_x: int = SIZE_AUTO_X
static var size_override_y: int = SIZE_AUTO_Y


# ============================================================
# PUBLIC API
# ============================================================

static func apply_initial(node: Node) -> void:
	## Loads saved overrides from prefs and applies them. Call once
	## at startup from Main.gd._ready() before any UI is shown.
	load_prefs()
	apply(node)


static func apply(node: Node) -> void:
	## Re-applies the current scale/size state to the window.
	## Call after changing any override.
	##
	## EDITOR CAVEAT (S61): when running from the Godot editor "Run Project"
	## button, window size changes may not visibly take effect because the
	## editor manages the play window. To verify size dropdown changes, test
	## with an EXPORTED binary (Windows .exe / macOS .app), not the editor
	## preview. The scale_factor change DOES apply in editor preview.
	if node == null:
		return
	var win: Window = node.get_window()
	if win == null:
		return

	var screen_idx: int = win.current_screen
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_idx)
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2i(BASE_WIDTH, BASE_HEIGHT)

	# --- Window mode + size ---
	if size_override_x == SIZE_FULLSCREEN_X and size_override_y == SIZE_FULLSCREEN_Y:
		# Fullscreen explicitly requested
		if win.mode != Window.MODE_FULLSCREEN:
			win.mode = Window.MODE_FULLSCREEN
	else:
		var target: Vector2i
		if size_override_x == SIZE_AUTO_X or size_override_y == SIZE_AUTO_Y:
			target = _compute_auto_size(screen_size)
		else:
			target = Vector2i(
				clampi(size_override_x, BASE_WIDTH, maxi(BASE_WIDTH, screen_size.x)),
				clampi(size_override_y, BASE_HEIGHT, maxi(BASE_HEIGHT, screen_size.y)),
			)
		if win.mode == Window.MODE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
		win.size = target
		_center_window(win, screen_size)

	# --- Content scale factor ---
	var scale_val: float = scale_override
	if scale_val <= 0.0:
		scale_val = _compute_auto_scale(screen_size)
	win.content_scale_factor = scale_val


static func set_scale_override(value: float, node: Node) -> void:
	scale_override = value
	save_prefs()
	apply(node)


static func set_size_override(width: int, height: int, node: Node) -> void:
	size_override_x = width
	size_override_y = height
	save_prefs()
	apply(node)


static func reset_to_auto(node: Node) -> void:
	scale_override = SCALE_AUTO
	size_override_x = SIZE_AUTO_X
	size_override_y = SIZE_AUTO_Y
	save_prefs()
	apply(node)


# ============================================================
# PERSISTENCE
# ============================================================

static func load_prefs() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(PREFS_PATH)
	if err != OK:
		return
	scale_override = float(cfg.get_value(PREFS_SECTION, "scale_override", SCALE_AUTO))
	size_override_x = int(cfg.get_value(PREFS_SECTION, "size_override_x", SIZE_AUTO_X))
	size_override_y = int(cfg.get_value(PREFS_SECTION, "size_override_y", SIZE_AUTO_Y))


static func save_prefs() -> void:
	var cfg := ConfigFile.new()
	# Load existing first so other sections (accessibility, account, ...) survive
	var _load_err: Error = cfg.load(PREFS_PATH)
	cfg.set_value(PREFS_SECTION, "scale_override", scale_override)
	cfg.set_value(PREFS_SECTION, "size_override_x", size_override_x)
	cfg.set_value(PREFS_SECTION, "size_override_y", size_override_y)
	var _save_err: Error = cfg.save(PREFS_PATH)


# ============================================================
# UI HELPERS — used by PortalScreen dropdowns
# ============================================================

static func get_scale_options() -> Array[float]:
	return [SCALE_AUTO, 0.75, 1.0, 1.25, 1.5, 2.0]


static func get_scale_label(value: float) -> String:
	if value <= 0.0:
		return Locale.t("display.scale_auto")
	return "%d%%" % int(round(value * 100.0))


static func get_size_options() -> Array[Vector2i]:
	return [
		Vector2i(SIZE_AUTO_X, SIZE_AUTO_Y),
		Vector2i(1280, 1024),
		Vector2i(1600, 1200),
		Vector2i(1920, 1440),
		Vector2i(SIZE_FULLSCREEN_X, SIZE_FULLSCREEN_Y),
	]


static func get_size_label(value: Vector2i) -> String:
	if value.x == SIZE_AUTO_X:
		return Locale.t("display.size_auto")
	if value.x == SIZE_FULLSCREEN_X and value.y == SIZE_FULLSCREEN_Y:
		return Locale.t("display.size_fullscreen")
	return "%d × %d" % [value.x, value.y]


static func get_current_scale_index() -> int:
	var opts: Array[float] = get_scale_options()
	for i: int in range(opts.size()):
		if absf(opts[i] - scale_override) < 0.001:
			return i
	return 0


static func get_current_size_index() -> int:
	var opts: Array[Vector2i] = get_size_options()
	for i: int in range(opts.size()):
		if opts[i].x == size_override_x and opts[i].y == size_override_y:
			return i
	return 0


# ============================================================
# INTERNAL HELPERS
# ============================================================

static func _compute_auto_size(screen_size: Vector2i) -> Vector2i:
	## 90% of screen, never below base canvas, never larger than screen.
	var max_w: int = maxi(BASE_WIDTH, screen_size.x)
	var max_h: int = maxi(BASE_HEIGHT, screen_size.y)
	var w: int = clampi(int(round(float(screen_size.x) * 0.9)), BASE_WIDTH, max_w)
	var h: int = clampi(int(round(float(screen_size.y) * 0.9)), BASE_HEIGHT, max_h)
	return Vector2i(w, h)


static func _compute_auto_scale(screen_size: Vector2i) -> float:
	## Picks a sensible content_scale_factor based on how much
	## bigger the screen is than the base canvas. Uses the smaller
	## of the width/height ratios so we never overscale on a tall
	## but narrow screen.
	var ratio_w: float = float(screen_size.x) / float(BASE_WIDTH)
	var ratio_h: float = float(screen_size.y) / float(BASE_HEIGHT)
	var ratio: float = minf(ratio_w, ratio_h)
	if ratio < 1.05:
		return 1.0
	elif ratio < 1.4:
		return 1.15
	elif ratio < 1.8:
		return 1.4
	elif ratio < 2.4:
		return 1.7
	else:
		return 2.0


static func _center_window(win: Window, screen_size: Vector2i) -> void:
	var pos := Vector2i(
		maxi(0, (screen_size.x - win.size.x) / 2),
		maxi(0, (screen_size.y - win.size.y) / 2),
	)
	win.position = pos
