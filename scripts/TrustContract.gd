extends CanvasLayer

signal accepted

const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

@onready var body: RichTextLabel = $Root/Center/Panel/Margin/VBox/BodyPanel/BodyMargin/Body
@onready var accept_button: Button = $Root/Center/Panel/Margin/VBox/Buttons/AcceptButton

func _ready() -> void:
	# Ensure we are above normal UI.
	layer = 10
	add_to_group("wots_trust_contract")

	# Belt + suspenders: connect in code (scene also has a connection).
	if accept_button != null and not accept_button.pressed.is_connected(_on_accept_pressed):
		accept_button.pressed.connect(_on_accept_pressed)

	if body != null:
		body.bbcode_enabled = true
		body.text = _build_contract_text()

func _build_contract_text() -> String:
	return """[b]Before you start:[/b]

• This simulation is for learning and coaching only; it will never be used for discipline or ranking.
• Scores are private to you; managers and captains cannot see individual runs.
• No personal data is collected; only aggregated metrics are used to improve training.
• Your role determines what you see; fairness is built into the system.

Press [b]I Understand[/b] to continue."""

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
