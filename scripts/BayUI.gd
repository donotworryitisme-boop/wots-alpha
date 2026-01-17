extends Control

# Handles UI interactions for BayUI, including showing the Trust Contract.

func _ready() -> void:
	var trust_button := $TrustButton
	if trust_button:
		trust_button.connect("pressed", Callable(self, "_on_trust_button_pressed"))

func _on_trust_button_pressed() -> void:
	# Find the Main node and call its show_trust_contract_again() method if available.
	var main_node := get_tree().get_root().get_node("Main")
	if main_node and main_node.has_method("show_trust_contract_again"):
		main_node.show_trust_contract_again()
