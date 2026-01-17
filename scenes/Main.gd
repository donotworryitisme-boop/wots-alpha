extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const TRUST_CONTRACT_SCENE: PackedScene = preload("res://ui/TrustContract.tscn")
const TRUST_FILE_PATH: String = "user://trust_contract_seen.dat"

var _trust_ok: bool = false

func _ready() -> void:
	if OS.is_debug_build():
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	var bay_ui := get_node_or_null("BayUI")
	if bay_ui != null and bay_ui.has_signal("trust_contract_requested"):
		bay_ui.connect("trust_contract_requested", Callable(self, "_on_trust_contract_requested"))

	# If a SessionManager exists in-scene, connect its hint signal to BayUI.
	var session := get_node_or_null("SessionManager")
	if session != null and bay_ui != null and session.has_signal("hint_updated") and bay_ui.has_method("set_hint_text"):
		session.connect("hint_updated", Callable(bay_ui, "set_hint_text"))

	if _trust_contract_seen():
		_trust_ok = true
		_start_session_if_ready()
	else:
		_show_trust_contract()

func _on_trust_contract_requested() -> void:
	_show_trust_contract()

func _show_trust_contract() -> void:
	if get_tree().get_nodes_in_group("wots_trust_contract").size() > 0:
		return

	var tc := TRUST_CONTRACT_SCENE.instantiate()
	add_child(tc)

	if tc.has_method("add_to_group"):
		tc.add_to_group("wots_trust_contract")

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

	# Start the session only if a SessionManager exists (no new UI screens; no forced instancing here).
	var session := get_node_or_null("SessionManager")
	if session != null and session.has_method("start_session"):
		session.call("start_session")
