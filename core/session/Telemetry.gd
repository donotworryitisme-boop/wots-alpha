class_name Telemetry
extends RefCounted

# ==========================================
# TELEMETRY — Item 53
# Opt-in anonymous telemetry logging.
# Stores aggregate usage data locally in user://telemetry.json.
# No network calls — data is available for manual export or
# future REST endpoint integration.
# ==========================================

const TELEMETRY_PATH: String = "user://telemetry.json"

## Opt-in flag — persisted via UITokens preferences.
static var enabled: bool = false

## In-memory aggregate data, loaded from disk on startup.
static var _data: Dictionary = {}


static func load_data() -> void:
	## Load telemetry data from disk. Called once at startup.
	var file: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.READ)
	if file == null:
		_data = _empty_data()
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		_data = json.data as Dictionary
	else:
		_data = _empty_data()


static func save_data() -> void:
	## Persist telemetry data to disk.
	var file: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


static func _empty_data() -> Dictionary:
	return {
		"version": 1,
		"first_session": Time.get_datetime_string_from_system(true, true),
		"last_session": "",
		"sessions_started": 0,
		"sessions_completed": 0,
		"score_buckets": {"0_50": 0, "50_70": 0, "70_85": 0, "85_100": 0},
		"scenarios": {},
		"failure_categories": {},
		"total_training_minutes": 0,
		"trainee_count": 0,
		"trainees_seen": [],
	}


static func log_session_start(scenario: String) -> void:
	## Called when a session begins.
	if not enabled:
		return
	if _data.is_empty():
		load_data()
	_data["sessions_started"] = int(_data.get("sessions_started", 0)) + 1
	_data["last_session"] = Time.get_datetime_string_from_system(true, true)

	# Track per-scenario starts
	var scenarios: Dictionary = _data.get("scenarios", {}) as Dictionary
	if not scenarios.has(scenario):
		scenarios[scenario] = {"started": 0, "completed": 0, "total_score": 0, "best": 0}
	var entry: Dictionary = scenarios[scenario] as Dictionary
	entry["started"] = int(entry.get("started", 0)) + 1
	_data["scenarios"] = scenarios

	# Track trainee
	var trainee: String = TrainingRecord.active_trainee
	var seen: Array = _data.get("trainees_seen", []) as Array
	if trainee not in seen:
		seen.append(trainee)
		_data["trainees_seen"] = seen
		_data["trainee_count"] = seen.size()

	save_data()


static func log_session_complete(scenario: String, score: int, time_seconds: float, mistakes: Dictionary) -> void:
	## Called when a session ends with grading.
	if not enabled:
		return
	if _data.is_empty():
		load_data()

	_data["sessions_completed"] = int(_data.get("sessions_completed", 0)) + 1
	_data["last_session"] = Time.get_datetime_string_from_system(true, true)
	@warning_ignore("integer_division")
	_data["total_training_minutes"] = int(_data.get("total_training_minutes", 0)) + int(time_seconds) / 60

	# Score bucket
	var buckets: Dictionary = _data.get("score_buckets", {}) as Dictionary
	if score < 50:
		buckets["0_50"] = int(buckets.get("0_50", 0)) + 1
	elif score < 70:
		buckets["50_70"] = int(buckets.get("50_70", 0)) + 1
	elif score < 85:
		buckets["70_85"] = int(buckets.get("70_85", 0)) + 1
	else:
		buckets["85_100"] = int(buckets.get("85_100", 0)) + 1
	_data["score_buckets"] = buckets

	# Per-scenario completion
	var scenarios: Dictionary = _data.get("scenarios", {}) as Dictionary
	if not scenarios.has(scenario):
		scenarios[scenario] = {"started": 0, "completed": 0, "total_score": 0, "best": 0}
	var entry: Dictionary = scenarios[scenario] as Dictionary
	entry["completed"] = int(entry.get("completed", 0)) + 1
	entry["total_score"] = int(entry.get("total_score", 0)) + score
	if score > int(entry.get("best", 0)):
		entry["best"] = score
	_data["scenarios"] = scenarios

	# Failure category tracking
	var cats: Dictionary = _data.get("failure_categories", {}) as Dictionary
	for key: String in mistakes.keys():
		var val: Variant = mistakes[key]
		var triggered: bool = false
		if val is bool:
			triggered = val as bool
		elif val is int or val is float:
			triggered = int(val) > 0
		if triggered:
			cats[key] = int(cats.get(key, 0)) + 1
	_data["failure_categories"] = cats

	save_data()


static func get_summary() -> Dictionary:
	## Returns a copy of the aggregate telemetry data for display.
	if _data.is_empty():
		load_data()
	return _data.duplicate(true)


static func reset() -> void:
	## Clears all telemetry data.
	_data = _empty_data()
	save_data()
