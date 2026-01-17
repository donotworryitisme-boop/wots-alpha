extends Node
class_name LoadingModel

# Manages the availability of loading docks by type. Dock availability is influenced by the sorter status.

enum DockType {
	C_AND_C,
	D,
	D_MINUS,
	D_PLUS,
	RAQ,
	CO,
	FLOATING
}

# Define how many docks exist for each type (adjust per roadmap).
var dock_counts: Dictionary = {
	DockType.C_AND_C: 2,
	DockType.D:       3,
	DockType.D_MINUS: 1,
	DockType.D_PLUS:  1,
	DockType.RAQ:     2,
	DockType.CO:      1,
	DockType.FLOATING: 1
}

# Track availability of each dock. Each entry is an array of booleans.
var docks_available: Dictionary = {}

# Reference to the sorter controlling availability.
var sorter_model: SorterModel = null

func _ready() -> void:
	# Initialize dock availability arrays.
	for dock_type in dock_counts.keys():
		var count: int = dock_counts[dock_type]
		var arr: Array[bool] = []
		for i in range(count):
			arr.append(true)
		docks_available[dock_type] = arr

func set_sorter_model(sorter: SorterModel) -> void:
	# Assign the sorter and connect to its signal.
	if sorter_model != null:
		# Disconnect using the Callable signature, not separate target/method parameters.
		sorter_model.disconnect("availability_changed", Callable(self, "_on_sorter_availability_changed"))
	sorter_model = sorter
	if sorter_model != null:
		sorter_model.connect("availability_changed", Callable(self, "_on_sorter_availability_changed"))
		_on_sorter_availability_changed(sorter_model.is_available)

func _on_sorter_availability_changed(is_available: bool) -> void:
	# When the sorter is unavailable, mark all docks unavailable; otherwise restore them to free.
	for dock_type in docks_available.keys():
		var arr: Array = docks_available[dock_type]
		for i in range(arr.size()):
			arr[i] = is_available

func is_dock_available(dock_type: int, index: int) -> bool:
	# Check if a specific dock is available.
	if sorter_model != null and not sorter_model.is_available:
		return false
	if not docks_available.has(dock_type):
		return false
	var arr: Array = docks_available[dock_type]
	if index < 0 or index >= arr.size():
		return false
	return arr[index]

func reserve_dock(dock_type: int) -> int:
	# Reserve and return the first available dock of the requested type, or -1 if none.
	if sorter_model != null and not sorter_model.is_available:
		return -1
	if not docks_available.has(dock_type):
		return -1
	var arr: Array = docks_available[dock_type]
	for i in range(arr.size()):
		if arr[i]:
			arr[i] = false
			return i
	return -1

func release_dock(dock_type: int, index: int) -> void:
	# Release a previously reserved dock.
	if not docks_available.has(dock_type):
		return
	var arr: Array = docks_available[dock_type]
	if index >= 0 and index < arr.size():
		arr[index] = true
