extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const SessionManager = preload("res://core/session/SessionManager.gd")

var session_manager: SessionManager

func _ready() -> void:
	# Bay B2B Alpha: debug overlay only in debug builds
	if OS.is_debug_build():
		var overlay = DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Create and start session manager
	session_manager = SessionManager.new()
	add_child(session_manager)
	session_manager.start_session()
