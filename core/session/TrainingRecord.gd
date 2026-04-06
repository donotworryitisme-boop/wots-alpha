class_name TrainingRecord
extends RefCounted

## Persists training session results as JSON files in user://training_records/{trainee}/.
## Each completed session writes one timestamped file.
## Provides static helpers to load history for the portal screen.
## Supports multiple trainees on the same machine (Item 54).

const RECORDS_BASE: String = "user://training_records"
const MAX_HISTORY: int = 50  # Keep at most 50 records per trainee

## Active trainee ID — all reads/writes use this.
## Set via set_trainee() which also persists to preferences.
static var active_trainee: String = "default"


static func _trainee_dir() -> String:
	## Returns the per-trainee records directory.
	return RECORDS_BASE + "/" + active_trainee


static func set_trainee(name: String) -> void:
	## Switch active trainee. Sanitise the name for filesystem safety.
	var safe: String = name.strip_edges()
	if safe == "":
		safe = "default"
	# Remove filesystem-unsafe characters
	safe = safe.replace("/", "_").replace("\\", "_").replace(":", "_")
	safe = safe.replace("\"", "").replace("'", "").replace(".", "_")
	active_trainee = safe
	_ensure_dir()


static func get_trainee_display_name() -> String:
	## Returns the active trainee name for display (capitalised).
	if active_trainee == "default":
		return "Trainee"
	return active_trainee


static func load_trainee_list() -> Array[String]:
	## Returns all trainee IDs that have records on disk.
	var trainees: Array[String] = []
	if not DirAccess.dir_exists_absolute(RECORDS_BASE):
		DirAccess.make_dir_recursive_absolute(RECORDS_BASE)
		return trainees
	var dir: DirAccess = DirAccess.open(RECORDS_BASE)
	if dir == null:
		return trainees
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			trainees.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	trainees.sort()
	return trainees


static func save_record(payload: Dictionary, scenario_name: String, total_time: float, seed_value: int = 0) -> void:
	_ensure_dir()
	var record: Dictionary = {
		"scenario": scenario_name,
		"score": int(payload.get("score", 0)),
		"passed": bool(payload.get("passed", false)),
		"critical_fail": bool(payload.get("critical_fail", false)),
		"time_seconds": total_time,
		"date": Time.get_datetime_string_from_system(true, true),
		"seed": seed_value,
		"weight_kg": float(payload.get("total_weight_kg", 0.0)),
		"dm3": int(payload.get("total_dm3", 0)),
		"combine_count": int(payload.get("combine_count", 0)),
		"mistakes": payload.get("mistakes", {}),
		"action_log": payload.get("action_log", []),
		"trainee": active_trainee,
	}
	var ts: String = str(Time.get_unix_time_from_system()).replace(".", "_")
	var path: String = _trainee_dir() + "/record_" + ts + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "\t"))
		file.close()
	_prune_old_records()


static func load_all_records() -> Array[Dictionary]:
	_ensure_dir()
	var records: Array[Dictionary] = []
	var tdir: String = _trainee_dir()
	var dir: DirAccess = DirAccess.open(tdir)
	if dir == null:
		return records
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var path: String = tdir + "/" + fname
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file != null:
				var text: String = file.get_as_text()
				file.close()
				var json := JSON.new()
				if json.parse(text) == OK and json.data is Dictionary:
					records.append(json.data as Dictionary)
		fname = dir.get_next()
	dir.list_dir_end()
	# Sort newest first by date string (ISO format sorts lexicographically)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("date", "")) > str(b.get("date", ""))
	)
	return records


static func get_recent(count: int) -> Array[Dictionary]:
	var all: Array[Dictionary] = load_all_records()
	var result: Array[Dictionary] = []
	var limit: int = mini(count, all.size())
	for i: int in range(limit):
		result.append(all[i])
	return result


static func get_best_per_scenario() -> Dictionary:
	## Returns { "scenario_name": { "score": int, "date": String } }
	var all: Array[Dictionary] = load_all_records()
	var bests: Dictionary = {}
	for r: Dictionary in all:
		var scen: String = str(r.get("scenario", ""))
		var score: int = int(r.get("score", 0))
		if not bests.has(scen) or score > int(bests[scen].get("score", 0)):
			bests[scen] = {"score": score, "date": str(r.get("date", ""))}
	return bests


static func get_scenario_history(scenario_name: String, count: int) -> Array[Dictionary]:
	var all: Array[Dictionary] = load_all_records()
	var result: Array[Dictionary] = []
	for r: Dictionary in all:
		if str(r.get("scenario", "")) == scenario_name:
			result.append(r)
			if result.size() >= count:
				break
	return result


static func _ensure_dir() -> void:
	var tdir: String = _trainee_dir()
	if not DirAccess.dir_exists_absolute(tdir):
		DirAccess.make_dir_recursive_absolute(tdir)


static func _prune_old_records() -> void:
	var tdir: String = _trainee_dir()
	var dir: DirAccess = DirAccess.open(tdir)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if files.size() <= MAX_HISTORY:
		return
	files.sort()
	var to_delete: int = files.size() - MAX_HISTORY
	for i: int in range(to_delete):
		dir.remove(files[i])


static func migrate_flat_records() -> void:
	## One-time migration: moves any .json files from the flat RECORDS_BASE
	## into RECORDS_BASE/default/. Called on startup.
	if not DirAccess.dir_exists_absolute(RECORDS_BASE):
		return
	var dir: DirAccess = DirAccess.open(RECORDS_BASE)
	if dir == null:
		return
	var files_to_move: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			files_to_move.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	if files_to_move.is_empty():
		return
	var dest: String = RECORDS_BASE + "/default"
	if not DirAccess.dir_exists_absolute(dest):
		DirAccess.make_dir_recursive_absolute(dest)
	for fname: String in files_to_move:
		dir.rename(fname, "default/" + fname)


static func load_all_records_all_trainees() -> Array[Dictionary]:
	## Returns records from ALL trainees, with a "trainee" field added.
	## Used by the trainer dashboard for cross-trainee overview.
	var all: Array[Dictionary] = []
	var trainees: Array[String] = load_trainee_list()
	for tid: String in trainees:
		var tdir: String = RECORDS_BASE + "/" + tid
		var dir: DirAccess = DirAccess.open(tdir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".json"):
				var path: String = tdir + "/" + fname
				var file: FileAccess = FileAccess.open(path, FileAccess.READ)
				if file != null:
					var text: String = file.get_as_text()
					file.close()
					var json := JSON.new()
					if json.parse(text) == OK and json.data is Dictionary:
						var rec: Dictionary = json.data as Dictionary
						if not rec.has("trainee"):
							rec["trainee"] = tid
						all.append(rec)
			fname = dir.get_next()
		dir.list_dir_end()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("date", "")) > str(b.get("date", ""))
	)
	return all


# ==========================================
# EXPORT / IMPORT — Item 55
# ==========================================

const EXPORT_DIR: String = "user://exports"

static func export_records(trainee_id: String = "") -> String:
	## Exports all records for the given trainee (or active trainee) as a
	## single JSON file in user://exports/. Returns the file path on success.
	var tid: String = trainee_id if trainee_id != "" else active_trainee
	if not DirAccess.dir_exists_absolute(EXPORT_DIR):
		DirAccess.make_dir_recursive_absolute(EXPORT_DIR)

	# Temporarily switch to target trainee to load their records
	var prev: String = active_trainee
	active_trainee = tid
	var records: Array[Dictionary] = load_all_records()
	active_trainee = prev

	var payload: Dictionary = {
		"trainee": tid,
		"exported_at": Time.get_datetime_string_from_system(true, true),
		"record_count": records.size(),
		"records": records,
	}

	var ts: String = str(Time.get_unix_time_from_system()).replace(".", "_")
	var path: String = EXPORT_DIR + "/export_" + tid + "_" + ts + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return path


static func export_all_trainees() -> String:
	## Exports all records from all trainees as a single JSON file.
	## Returns the file path on success.
	if not DirAccess.dir_exists_absolute(EXPORT_DIR):
		DirAccess.make_dir_recursive_absolute(EXPORT_DIR)

	var all_records: Array[Dictionary] = load_all_records_all_trainees()
	var payload: Dictionary = {
		"trainee": "_all",
		"exported_at": Time.get_datetime_string_from_system(true, true),
		"record_count": all_records.size(),
		"trainees": load_trainee_list(),
		"records": all_records,
	}

	var ts: String = str(Time.get_unix_time_from_system()).replace(".", "_")
	var path: String = EXPORT_DIR + "/export_all_" + ts + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return path


static func import_records(path: String) -> int:
	## Imports records from an export JSON file. Records are added to the
	## appropriate trainee's directory. Returns the number of records imported.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return 0
	var payload: Dictionary = json.data as Dictionary
	var records: Array = payload.get("records", []) as Array
	var imported: int = 0
	for entry: Variant in records:
		if not (entry is Dictionary):
			continue
		var rec: Dictionary = entry as Dictionary
		var tid: String = str(rec.get("trainee", "default"))
		if tid == "":
			tid = "default"
		# Write to that trainee's directory
		var dest_dir: String = RECORDS_BASE + "/" + tid
		if not DirAccess.dir_exists_absolute(dest_dir):
			DirAccess.make_dir_recursive_absolute(dest_dir)
		var ts: String = str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(imported)
		var rec_path: String = dest_dir + "/record_" + ts + ".json"
		var out: FileAccess = FileAccess.open(rec_path, FileAccess.WRITE)
		if out != null:
			out.store_string(JSON.stringify(rec, "\t"))
			out.close()
			imported += 1
	return imported
