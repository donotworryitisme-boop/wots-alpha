extends CanvasLayer

signal trust_contract_requested

@onready var trust_button: Button = $Root/TrustContractButton
@onready var hint_label: Label = $Root/HintLabel

func _ready() -> void:
	if trust_button != null:
		trust_button.pressed.connect(_on_trust_contract_button_pressed)

	# Start with no hint text.
	if hint_label != null:
		hint_label.text = ""

func _on_trust_contract_button_pressed() -> void:
	trust_contract_requested.emit()

func set_hint_text(text: String) -> void:
	# UI-only: reflects scaffolding tier hints. No outcome revelation.
	if hint_label == null:
		return
	hint_label.text = text
