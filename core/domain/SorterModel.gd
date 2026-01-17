extends Node
class_name SorterModel

# Represents the status of the sorter. When unavailable, loading docks cannot be used.

signal availability_changed(is_available: bool)

var is_available: bool = true

func set_available(value: bool) -> void:
	if is_available == value:
		return
	is_available = value
	emit_signal("availability_changed", is_available)

func toggle_available() -> void:
	# Convenience method to flip availability.
	set_available(not is_available)
