extends CanvasLayer

signal trust_contract_requested

@onready var trust_button: Button = $Root/TrustContractButton

func _ready() -> void:
	if trust_button != null:
		trust_button.pressed.connect(_on_trust_contract_button_pressed)

func _on_trust_contract_button_pressed() -> void:
	trust_contract_requested.emit()
