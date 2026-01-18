extends Control
class_name FeedbackLayer

# Debrief / timeline view used by the harness after "End Scenario".
# Existing behavior kept; only node-path wiring updated to match ui/FeedbackLayer.tscn.

var explain_why_enabled: bool = false
var events: Array = []
var output: String = ""

@onready var explain_toggle: CheckButton = $Panel/Margin/VBox/ExplainToggle
@onready var rich_text: RichTextLabel = $Panel/Margin/VBox/RichTextLabel
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

func _ready() -> void:
	if explain_toggle != null:
		explain_toggle.button_pressed = explain_why_enabled
		explain_toggle.toggled.connect(_on_toggle_changed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	reset()

func reset() -> void:
	events.clear()
	output = ""
	if rich_text != null:
		rich_text.text = output

func handle_event(rule_id: int, produces_waste: bool, timestamp: float) -> void:
	events.append({"time": timestamp, "rule_id": rule_id, "waste": produces_waste})
	var time_str: String = "%0.2f" % timestamp
	var status: String = "Waste" if produces_waste else "Good"
	output += time_str + "s: Rule " + str(rule_id) + " - " + status + "\n"

	if not produces_waste:
		output += "Good job! No waste produced.\n"
	elif explain_why_enabled:
		output += "Explanation: Waste occurred due to rule " + str(rule_id) + " violation.\n"

	if rich_text != null:
		rich_text.text = output

func notify_session_end(final_score: int) -> void:
	output += "Session ended. Final score: " + str(final_score) + "\n"
	if rich_text != null:
		rich_text.text = output

func _on_toggle_changed(button_pressed: bool) -> void:
	explain_why_enabled = button_pressed

func _on_close_pressed() -> void:
	visible = false
