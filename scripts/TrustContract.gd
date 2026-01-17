extends CanvasLayer

signal accepted

const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

@onready var body: RichTextLabel = $Root/Center/Panel/Margin/VBox/BodyPanel/BodyMargin/Body
@onready var accept_button: Button = $Root/Center/Panel/Margin/VBox/ButtonCenter/AcceptButton

var _is_hovered: bool = false
var _normal_modulate: Color = Color(1, 1, 1, 1)

# We override the BUTTON'S NORMAL stylebox when hovered so it always shows,
# even if the project theme doesn't render hover states.
var _normal_stylebox: StyleBox = null
var _hover_stylebox: StyleBox = null

func _ready() -> void:
	layer = 10
	add_to_group("wots_trust_contract")

	if body != null:
		body.bbcode_enabled = true
		body.text = _build_contract_text()

	if accept_button == null:
		print("[TrustContract] ERROR: AcceptButton not found (scene mismatch).")
		return

	_normal_modulate = accept_button.modulate
	_normal_stylebox = accept_button.get_theme_stylebox("normal")
	_hover_stylebox = accept_button.get_theme_stylebox("hover")

	# Cursor hint (even if hover visuals fail, cursor should change)
	accept_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Click handling
	if not accept_button.pressed.is_connected(_on_accept_pressed):
		accept_button.pressed.connect(_on_accept_pressed)

func _process(_delta: float) -> void:
	# Deterministic hover: poll mouse position every frame.
	if accept_button == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var hovered_now := accept_button.get_global_rect().has_point(mouse_pos)

	if hovered_now != _is_hovered:
		_is_hovered = hovered_now
		_apply_hover_state(_is_hovered)

func _apply_hover_state(hovered: bool) -> void:
	if accept_button == null:
		return

	if hovered:
		# Force a visible hover even if theme doesn't show it.
		accept_button.modulate = Color(1.18, 1.18, 1.18, 1.0)

		# Also force style change by overriding "normal" with "hover" if available.
		if _hover_stylebox != null:
			accept_button.add_theme_stylebox_override("normal", _hover_stylebox)
	else:
		accept_button.modulate = _normal_modulate

		# Restore original normal stylebox.
		if _normal_stylebox != null:
			accept_button.add_theme_stylebox_override("normal", _normal_stylebox)

func _build_contract_text() -> String:
	return """[b]Before you start:[/b]

• This simulation is for learning and coaching only; it will never be used for discipline or ranking.
• Scores are private to you; managers and captains cannot see individual runs.
• No personal data is collected; only aggregated metrics are used to improve training.
• Your role determines what you see; fairness is built into the system.

Press [b]I Understand[/b] to continue."""

func _input(event: InputEvent) -> void:
	# Hard fallback: accept by rect hit test.
	if accept_button == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var r := accept_button.get_global_rect()
		if r.has_point(event.position):
			_on_accept_pressed()
			get_viewport().set_input_as_handled()

func _on_accept_pressed() -> void:
	print("[TrustContract] Accepted")
	_write_trust_file()
	accepted.emit()
	queue_free()

func _write_trust_file() -> void:
	var f := FileAccess.open(TRUST_FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("seen=1\n")
	f.flush()
