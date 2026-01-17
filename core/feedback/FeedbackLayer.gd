extends Control
class_name FeedbackLayer

# Overlay that displays the waste timeline and good-failure recognition,
# with a toggle to explain the cause of waste.

var explain_why_enabled: bool = false
var events: Array = []
var output: String = ""

func _ready() -> void:
	# Initialize toggle state and connect the signal.
	$ExplainToggle.button_pressed = explain_why_enabled
	$ExplainToggle.connect("toggled", Callable(self, "_on_toggle_changed"))
	reset()

func reset() -> void:
	# Clear the timeline, stored events, and output.
	events.clear()
	output = ""
	if $RichTextLabel:
		$RichTextLabel.text = output

func handle_event(rule_id: int, produces_waste: bool, timestamp: float) -> void:
	# Record and display an event in the timeline.
	events.append({"time": timestamp, "rule_id": rule_id, "waste": produces_waste})
	var time_str: String = "%0.2f" % timestamp
	var status: String = "Waste" if produces_waste else "Good"
	output += time_str + "s: Rule " + str(rule_id) + " - " + status + "\n"
	if not produces_waste:
		output += "Good job! No waste produced.\n"
	elif explain_why_enabled:
		# Provide a simple explanation for waste. This can be expanded later.
		output += "Explanation: Waste occurred due to rule " + str(rule_id) + " violation.\n"
	if $RichTextLabel:
		$RichTextLabel.text = output

func notify_session_end(final_score: int) -> void:
	# Add a cue when the session ends.
	output += "Session ended. Final score: " + str(final_score) + "\n"
	if $RichTextLabel:
		$RichTextLabel.text = output

func _on_toggle_changed(button_pressed: bool) -> void:
	# Update the explain‑why toggle state.
	explain_why_enabled = button_pressed
