class_name AccountManager
extends RefCounted

## Local account management for WOTS.
## Stores accounts as JSON files in user://accounts/.
## Passwords are salted + SHA-256 hashed — never stored in plain text.
## Roles use WOTSConfig.Role enum (OPERATOR, TRAINER).

const ACCOUNTS_DIR: String = "user://accounts"
const SALT_PREFIX: String = "wots_bay_b2b_"

## Currently logged-in account data (empty dict when logged out).
static var current_account: Dictionary = {}


# ==========================================
# PUBLIC API
# ==========================================

static func is_logged_in() -> bool:
	return not current_account.is_empty()


static func current_username() -> String:
	return str(current_account.get("username", ""))


static func current_display_name() -> String:
	var display: String = str(current_account.get("display_name", ""))
	if display == "":
		return current_username()
	return display


static func current_role() -> int:
	return int(current_account.get("role", WOTSConfig.Role.OPERATOR))


static func is_trainer() -> bool:
	return current_role() == WOTSConfig.Role.TRAINER


static func create_account(
		username: String,
		password: String,
		display_name: String,
		role: int,
) -> String:
	## Creates a new account. Returns "" on success or an error message.
	var clean_user: String = _sanitize_username(username)
	if clean_user == "":
		return "Username must be at least 2 characters."
	if password.length() < 4:
		return "Password must be at least 4 characters."
	if _account_exists(clean_user):
		return "Username already taken."

	_ensure_dir()
	var clean_display: String = display_name.strip_edges()
	if clean_display == "":
		clean_display = clean_user

	var account: Dictionary = {
		"username": clean_user,
		"display_name": clean_display,
		"password_hash": _hash_password(clean_user, password),
		"role": role,
		"created_at": Time.get_datetime_string_from_system(true, true),
	}

	var path: String = _account_path(clean_user)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Failed to write account file."
	file.store_string(JSON.stringify(account, "\t"))
	file.close()
	return ""


static func authenticate(username: String, password: String) -> String:
	## Attempts login. Returns "" on success or an error message.
	## On success, sets current_account.
	var clean_user: String = _sanitize_username(username)
	if clean_user == "":
		return "Invalid username."

	var account: Dictionary = _load_account(clean_user)
	if account.is_empty():
		return "Account not found."

	var expected_hash: String = str(account.get("password_hash", ""))
	var provided_hash: String = _hash_password(clean_user, password)
	if expected_hash != provided_hash:
		return "Incorrect password."

	current_account = account
	# Sync with TrainingRecord so records are stored under this user
	TrainingRecord.set_trainee(clean_user)
	return ""


static func logout() -> void:
	current_account = {}


static func list_accounts() -> Array[Dictionary]:
	## Returns all accounts (without password hashes) sorted by username.
	_ensure_dir()
	var accounts: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(ACCOUNTS_DIR)
	if dir == null:
		return accounts
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			var path: String = ACCOUNTS_DIR + "/" + entry
			var data: Dictionary = _read_json(path)
			if not data.is_empty():
				# Strip password hash before returning
				var safe: Dictionary = data.duplicate()
				safe.erase("password_hash")
				accounts.append(safe)
		entry = dir.get_next()
	dir.list_dir_end()
	accounts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("username", "")) < str(b.get("username", ""))
	)
	return accounts


static func delete_account(username: String) -> bool:
	## Deletes an account. Returns true on success.
	var clean_user: String = _sanitize_username(username)
	if clean_user == "":
		return false
	var path: String = _account_path(clean_user)
	if not FileAccess.file_exists(path):
		return false
	var dir: DirAccess = DirAccess.open(ACCOUNTS_DIR)
	if dir == null:
		return false
	dir.remove(clean_user + ".json")
	# Log out if deleting current user
	if current_username() == clean_user:
		logout()
	return true


static func role_name(role: int) -> String:
	match role:
		WOTSConfig.Role.OPERATOR: return "Operator"
		WOTSConfig.Role.TRAINER: return "Trainer"
	return "Unknown"


static func restore_session(saved_username: String) -> void:
	## Restores a previously saved login session (called on startup).
	## Does NOT require a password — trusts the saved preference.
	if saved_username == "":
		return
	var acct: Dictionary = _load_account(saved_username)
	if not acct.is_empty():
		current_account = acct
		TrainingRecord.set_trainee(saved_username)


static func has_any_accounts() -> bool:
	_ensure_dir()
	var dir: DirAccess = DirAccess.open(ACCOUNTS_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			dir.list_dir_end()
			return true
		entry = dir.get_next()
	dir.list_dir_end()
	return false


# ==========================================
# INTERNAL HELPERS
# ==========================================

static func _sanitize_username(raw: String) -> String:
	## Cleans and validates a username. Returns "" if invalid.
	var clean: String = raw.strip_edges().to_lower()
	# Remove unsafe filesystem characters
	clean = clean.replace("/", "").replace("\\", "").replace(":", "")
	clean = clean.replace("\"", "").replace("'", "").replace(".", "")
	clean = clean.replace(" ", "_")
	if clean.length() < 2:
		return ""
	if clean.length() > 32:
		clean = clean.left(32)
	return clean


static func _hash_password(username: String, password: String) -> String:
	## Salted SHA-256 hash. Not cryptographically hardened (bcrypt etc.)
	## but sufficient for a local training tool.
	var salted: String = SALT_PREFIX + username + ":" + password
	return salted.sha256_text()


static func _account_path(username: String) -> String:
	return ACCOUNTS_DIR + "/" + username + ".json"


static func _account_exists(username: String) -> bool:
	return FileAccess.file_exists(_account_path(username))


static func _load_account(username: String) -> Dictionary:
	var path: String = _account_path(username)
	return _read_json(path)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data as Dictionary
	return {}


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ACCOUNTS_DIR):
		DirAccess.make_dir_recursive_absolute(ACCOUNTS_DIR)
