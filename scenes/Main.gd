extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const SessionManagerClass               = preload("res://core/session/SessionManager.gd")
const FeedbackLayerScene: PackedScene   = preload("res://ui/FeedbackLayer.tscn")

var session_manager: SessionManager
var feedback_layer: FeedbackLayer

func _ready() -> void:
    # Load debug overlay only in debug builds
    if OS.is_debug_build():
        var overlay = DEBUG_OVERLAY_SCENE.instantiate()
        add_child(overlay)

    # Create and start session manager
    session_manager = SessionManagerClass.new()
    add_child(session_manager)

    # Instantiate and add the feedback layer overlay
    feedback_layer = FeedbackLayerScene.instantiate()
    add_child(feedback_layer)
    # Assign feedback layer to session manager
    session_manager.feedback_layer = feedback_layer

    # Start the training session
    session_manager.start_session()
