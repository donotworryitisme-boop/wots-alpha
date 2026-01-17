extends Control
class_name TrustContract

signal accepted

# Connect the AcceptButton when the scene is ready.
func _ready() -> void:
	var accept_button = find_child("AcceptButton", true, false)
	if accept_button:
		accept_button.connect("pressed", Callable(self, "_on_accept_pressed"))

func _on_accept_pressed() -> void:
	# Persist acceptance to prevent re-showing on next launch
	var path = "user://trust_contract_seen.dat"
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("1")
	file.close()

	emit_signal("accepted")
	queue_free()
