extends Node
class_name ScoreEngine

# Simple scoring engine to track session score and manage the run board.

var current_score: int = 0

# Points awarded (or deducted) by rule ID. Adjust according to the roadmap.
var points_by_rule_id: Dictionary = {
	1: -10,  # Emplacement time exceeded
	2: 0     # Missing scan
}

func start_session() -> void:
	# Reset the score at the start of each session.
	current_score = 0

func apply_rule(rule_id: int, produces_waste: bool) -> void:
	# Adjust score based on the rule ID. Additional logic could use produces_waste.
	if points_by_rule_id.has(rule_id):
		current_score += points_by_rule_id[rule_id]

func end_session(session: SessionManager) -> void:
	# Record the run unless zero-score mode is enabled.
	if session.is_zero_score_mode():
		return
	record_run(current_score)

# -------------------------------------------------------------------
# Run board persistence

func record_run(score: int) -> void:
	var board: Array = load_run_board()
	var timestamp: float = Time.get_unix_time_from_system()
	board.append({"timestamp": timestamp, "score": score})
	# Keep only runs from the last 30 days.
	board = cleanup_board(board, 30)
	save_run_board(board)

func load_run_board() -> Array:
	var path: String = "user://run_board.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var text: String = file.get_as_text()
		file.close()
		# Create a JSON object and parse the text.
		var json := JSON.new()
		var parse_err := json.parse(text)
		if parse_err == OK and json.data is Array:
			return json.data
	return []

func save_run_board(board: Array) -> void:
	var path: String = "user://run_board.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(board))
	file.close()

func cleanup_board(board: Array, keep_days: int) -> Array:
	var cutoff: float = Time.get_unix_time_from_system() - float(keep_days) * 24.0 * 3600.0
	var new_board: Array = []
	for entry in board:
		if entry is Dictionary and entry.has("timestamp") and entry["timestamp"] >= cutoff:
			new_board.append(entry)
	return new_board

func get_run_board() -> Array:
	return load_run_board()
