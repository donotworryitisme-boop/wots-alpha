extends Node
class_name WOTSLogger

static func log_info(message: String) -> void:
	_emit("INFO", message)

static func log_warn(message: String) -> void:
	_emit("WARN", message)

static func log_error(message: String) -> void:
	_emit("ERROR", message)

static func _emit(level: String, message: String) -> void:
	var ts := Time.get_time_string_from_system()
	var line := "[%s] [%s] %s" % [ts, level, message]

	# Always print to output as baseline
	print(line)

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	# If overlay exists (debug build), forward logs to it.
	var overlays := tree.get_nodes_in_group("wots_debug_overlay")
	for o in overlays:
		if o != null and o.has_method("append_line"):
			o.call("append_line", line)
