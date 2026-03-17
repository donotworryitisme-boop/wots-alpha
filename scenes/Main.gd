extends Control

# --- CONSTANTS ---
const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const TRUST_CONTRACT_SCENE: PackedScene = preload("res://ui/TrustContract.tscn")
const BAY_UI_SCENE: PackedScene = preload("res://ui/BayUI.tscn")
# We load the script directly instead of a scene
const SessionManagerScript = preload("res://core/session/SessionManager.gd")

# --- VARIABLES ---
var _session = null
var _ui: CanvasLayer = null
var _trust_contract = null

func _ready() -> void:
	# 1. Boot in Fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# 2. Debug overlay
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# 3. Setup the Session (as a Node) and UI
	_session = SessionManagerScript.new()
	_session.name = "SessionManager"
	add_child(_session)

	_ui = BAY_UI_SCENE.instantiate()
	_ui.name = "BayUI"
	add_child(_ui)
	_ui.set_session(_session)
	
	# Connect the UI's request signal
	_ui.connect("trust_contract_requested", _on_trust_contract_requested)

	# 4. STARTUP: Force the Trust Contract to show immediately
	_ui.set_enabled(false) 
	_on_trust_contract_requested()

func _on_trust_contract_requested() -> void:
	if _trust_contract != null: return 

	_trust_contract = TRUST_CONTRACT_SCENE.instantiate()
	add_child(_trust_contract)
	
	if _trust_contract.has_signal("accepted"):
		_trust_contract.connect("accepted", _on_trust_contract_confirmed)

func _on_trust_contract_confirmed() -> void:
	if _trust_contract != null:
		_trust_contract.queue_free()
		_trust_contract = null
	
	# Enable the UI
	if _ui != null:
		_ui.set_enabled(true)
