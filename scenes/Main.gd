extends Control

# --- CONSTANTS ---
const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const START_SCREEN_SCENE: PackedScene = preload("res://ui/StartScreen.tscn")
const TRUST_CONTRACT_SCENE: PackedScene = preload("res://ui/TrustContract.tscn")
const BAY_UI_SCENE: PackedScene = preload("res://ui/BayUI.tscn")
const SessionManagerScript = preload("res://core/session/SessionManager.gd")

const FADE_IN_SLOW: float = 1.33
const FADE_OUT: float = 0.855
const FADE_IN: float = 0.855
const TRUST_FILE: String = "user://trust_contract_seen.dat"

# --- VARIABLES ---
var _session: Node = null
var _ui: CanvasLayer = null
var _start_screen: CanvasLayer = null
var _trust_contract: CanvasLayer = null
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null


func _ready() -> void:
	# 0. Load user preferences (high-contrast, etc.) before building any UI
	UITokens.load_preferences()
	TrainingRecord.migrate_flat_records()

	# 1. Boot in Fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# 2. Debug overlay
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# 3. Build the fade overlay (sits on top of everything)
	_build_fade_overlay()
	_fade_rect.color.a = 1.0

	# 4. Setup the Session and UI (hidden behind black overlay)
	_session = SessionManagerScript.new()
	_session.name = "SessionManager"
	add_child(_session)

	_ui = BAY_UI_SCENE.instantiate()
	_ui.name = "BayUI"
	add_child(_ui)
	_ui.set_session(_session)
	_ui.set_enabled(false)

	# 5. Show Start Screen, then fade from black
	_start_screen = START_SCREEN_SCENE.instantiate()
	add_child(_start_screen)
	if _start_screen.has_signal("begin_pressed"):
		_start_screen.connect("begin_pressed", _on_start_begin)

	# Small delay before the first fade-in so the scene tree is ready
	await get_tree().create_timer(0.15).timeout
	_fade_to(0.0, FADE_IN_SLOW, Callable())


func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 20
	_fade_layer.name = "FadeOverlay"
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func _fade_to(target_alpha: float, duration: float, on_complete: Callable) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", target_alpha, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if on_complete.is_valid():
		_fade_tween.tween_callback(on_complete)


func _on_start_begin() -> void:
	if FileAccess.file_exists(TRUST_FILE):
		# Trust contract already seen — go straight to portal
		_fade_to(1.0, FADE_OUT, _swap_to_portal)
	else:
		# First launch — show trust contract over portal
		_fade_to(1.0, FADE_OUT, _swap_to_trust_contract)


func _swap_to_trust_contract() -> void:
	# Remove start screen
	if _start_screen != null:
		_start_screen.queue_free()
		_start_screen = null

	# Enable BayUI so the portal is visible behind the trust contract
	if _ui != null:
		_ui.set_enabled(true)

	# Add trust contract overlay (layer 10, on top of BayUI layer 5)
	_trust_contract = TRUST_CONTRACT_SCENE.instantiate()
	add_child(_trust_contract)
	if _trust_contract.has_signal("accepted"):
		_trust_contract.connect("accepted", _on_trust_accepted)

	# Fade from black to reveal trust contract over portal, then cleanup fade
	_fade_to(0.0, FADE_IN, _cleanup_fade_overlay)


func _on_trust_accepted() -> void:
	# Trust contract already faded itself out — just clean up the node
	if _trust_contract != null:
		_trust_contract.queue_free()
		_trust_contract = null


func _swap_to_portal() -> void:
	# Remove start screen
	if _start_screen != null:
		_start_screen.queue_free()
		_start_screen = null

	# Remove trust contract if somehow still present
	if _trust_contract != null:
		_trust_contract.queue_free()
		_trust_contract = null

	# Enable the UI
	if _ui != null:
		_ui.set_enabled(true)

	# Fade from black, then remove the overlay
	_fade_to(0.0, FADE_IN, _cleanup_fade_overlay)


func _cleanup_fade_overlay() -> void:
	if _fade_layer != null:
		_fade_layer.queue_free()
		_fade_layer = null
		_fade_rect = null
