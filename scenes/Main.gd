extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const TRUST_CONTRACT_SCENE: PackedScene = preload("res://ui/trust_contract.tscn") # lowercase, deterministic
const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

var _trust_ok: bool = false

func _ready() -> void:
	# Debug overlay only in debug builds.
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Ensure BayUI is present and hook its signal.
	var bay_ui := get_node_or_null("BayUI")
	if bay_ui != null and bay_ui.has_signal("trust_contract_requested"):
		bay_ui.connect("trust_contract_requested", Callable(self, "_on_trust_contract_requested"))

	# First-run gate behind trust contract.
	if _trust_contract_seen():
		_trust_ok = true
		_start_session_if_ready()
	else:
		_show_trust_contract()

func _on_trust_contract_requested() -> void:
	_show_trust_contract()

func _show_trust_contract() -> void:
	# Prevent duplicates.
	if get_tree().get_nodes_in_group("wots_trust_contract").size() > 0:
		return

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
	if not _trust_ok:
		return
	# No-op here (do not add new session logic in this fix).
	pass
