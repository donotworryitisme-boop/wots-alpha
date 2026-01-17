extends Control
class_name FeedbackLayer

# Overlay that displays the waste timeline and good-failure recognition,
# with a toggle to explain the cause of waste.

var explain_why_enabled: bool = false
var events: Array = []

func _ready() -> void:
	# Initialize toggle state and connect the signal.
	$ExplainToggle.button_pressed = explain_why_enabled
	$ExplainToggle.connect("toggled", Callable(self, "_on_toggle_changed"))
	reset()

func reset() -> void:
	# Clear the timeline and stored events.
	events.clear()
	$RichTextLabel.clear()

func handle_event(rule_id: int, produces_waste: bool, timestamp: float) -> void:
	# Record and display an event in the timeline.
	events.append({"time": timestamp, "rule_id": rule_id, "waste": produces_waste})
	var time_str: String = "%0.2f" % timestamp
	var status: String = "Waste" if produces_waste else "Good"
	$RichTextLabel.append_bbcode("[b]" + time_str + "s[/b]: Rule " + str(rule_id) + " - " + status + "\n")
	if not produces_waste:
		$RichTextLabel.append_bbcode("[color=green]Good job! No waste produced.[/color]\n")
	elif explain_why_enabled:
		# Provide a simple explanation for waste. This can be expanded later.
		$RichTextLabel.append_bbcode("[color=yellow]Explanation: Waste occurred due to rule "
			+ str(rule_id) + " violation.[/color]\n")

func notify_session_end(final_score: int) -> void:
	# Add a cue when the session ends.
	$RichTextLabel.append_bbcode("[color=cyan]Session ended. Final score: "
		+ str(final_score) + "[/color]\n")

func _on_toggle_changed(button_pressed: bool) -> void:
	# Update the explain‑why toggle state.
	explain_why_enabled = button_pressed
