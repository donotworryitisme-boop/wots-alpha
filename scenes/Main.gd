extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")

func _ready() -> void:
	# Bay B2B Alpha: debug overlay only in debug builds
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)
