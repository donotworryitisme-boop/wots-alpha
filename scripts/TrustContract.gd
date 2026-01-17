extends Control
class_name TrustContract

signal accepted

# Handles the Trust Contract overlay: emits when accepted.

func _ready() -> void:
	# Find the AcceptButton anywhere in this scene and connect its signal.
	var accept_button := find_node("AcceptButton", recursive=true)
	if accept_button:
		accept_button.connect("pressed", Callable(self, "_on_accept_pressed"))

func _on_accept_pressed() -> void:
	# Save a file to indicate the contract has been seen
	var path := "user://trust_contract_seen.dat"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("1")
	file.close()
	# Emit acceptance and remove self
	emit_signal("accepted")
	queue_free()
