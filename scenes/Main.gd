extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const TRUST_CONTRACT_SCENE: PackedScene = preload("res://ui/TrustContract.tscn")
const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

var _trust_ok: bool = false

func _ready() -> void:
	# Debug overlay only in debug builds.
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Hook BayUI request button (if present).
	var bay_ui := get_node_or_null("BayUI")
	if bay_ui != null and bay_ui.has_signal("trust_contract_requested"):
		bay_ui.connect("trust_contract_requested", Callable(self, "_on_trust_contract_requested"))

	# Gate start behind trust contract on first launch.
	if _trust_contract_seen():
		_trust_ok = true
		_start_session_if_ready()
	else:
		_show_trust_contract()

func _on_trust_contract_requested() -> void:
	# Manual reopen from UI (does not depend on file existing).
	_show_trust_contract()

func _show_trust_contract() -> void:
	var tc := TRUST_CONTRACT_SCENE.instantiate()
	add_child(tc)
	if tc.has_signal("accepted"):
		tc.connect("accepted", Callable(self, "_on_trust_contract_accepted"))

func _on_trust_contract_accepted() -> void:
	_trust_ok = true
	_start_session_if_ready()

func _trust_contract_seen() -> bool:
	return FileAccess.file_exists(TRUST_FILE_PATH)

func _start_session_if_ready() -> void:
	# Placeholder gate. Real session start (if/when present in this project)
	# must only be triggered after _trust_ok is true.
	if not _trust_ok:
		return
	# No-op for now (Bay B2B Alpha: no new session logic added here).
	pass
