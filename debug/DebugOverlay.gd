extends Control

@onready var log_text: TextEdit = $Panel/Margin/VBox/LogText

func _ready() -> void:
	add_to_group("wots_debug_overlay")
	# Start with a small boot line so you know it is active.
	append_line("[DEBUG] Overlay active")

func append_line(line: String) -> void:
	if log_text == null:
		return
	if log_text.text.is_empty():
		log_text.text = line
	else:
		log_text.text += "\n" + line

	# Keep scrolled to bottom
	log_text.scroll_vertical = log_text.get_line_count()
