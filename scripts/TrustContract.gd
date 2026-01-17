extends Control
class_name TrustContract

signal accepted

# Handles the Trust Contract overlay: shows text and emits when accepted.

func _ready() -> void:
	# Connect the accept button signal
	$AcceptButton.connect("pressed", Callable(self, "_on_accept_pressed"))

func _on_accept_pressed() -> void:
	# Save a file to indicate the contract has been seen
	var path := "user://trust_contract_seen.dat"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("1")
	file.close()
	# Emit acceptance and remove self
	emit_signal("accepted")
	queue_free()
