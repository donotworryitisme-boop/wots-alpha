extends CanvasLayer

signal accepted

const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

@onready var body: RichTextLabel = $Root/Panel/Margin/VBox/Body
@onready var accept_button: Button = $Root/Panel/Margin/VBox/Buttons/AcceptButton

func _ready() -> void:
	# Ensure we are above normal UI.
	layer = 10

	if accept_button != null:
		accept_button.pressed.connect(_on_accept_pressed)

	# Text is set here to avoid relying on scene text state.
	if body != null:
		body.text = _build_contract_text()

func _build_contract_text() -> String:
	# Keep it short and explicit; bullet points via BBCode.
	return (
		"[b]Before you start:[/b]\n\n"
		"• This is a training simulator — not a discipline or ranking tool.\n"
		"• Scores are for your feedback and learning; no automatic sharing.\n"
		"• No personal data is collected by this simulator.\n"
		"• Scoring aims for consistency and fairness across scenarios.\n\n"
		"Press [b]I Understand[/b] to continue."
	)

func _on_accept_pressed() -> void:
	_write_trust_file()
	accepted.emit()
	queue_free()

func _write_trust_file() -> void:
	var f := FileAccess.open(TRUST_FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("seen=1\n")
	f.flush()
