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

	var bay_ui := get_node_or_null("BayUI")
	var session := get_node_or_null("SessionManager")

	# Wire session into BayUI harness (no new systems).
	if bay_ui != null and session != null and bay_ui.has_method("set_session"):
		bay_ui.call("set_session", session)

	# Allow reopening trust contract from BayUI.
	if bay_ui != null and bay_ui.has_signal("trust_contract_requested"):
		bay_ui.connect("trust_contract_requested", Callable(self, "_on_trust_contract_requested"))

	# Gate interaction behind trust contract on first launch.
	if _trust_contract_seen():
		_trust_ok = true
		_enable_bay_ui()
	else:
		_show_trust_contract()

func _enable_bay_ui() -> void:
	# BayUI harness is interactive only after trust contract acceptance.
	var bay_ui := get_node_or_null("BayUI")
	if bay_ui != null and bay_ui.has_method("set_enabled"):
		bay_ui.call("set_enabled", true)

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
	_enable_bay_ui()

func _trust_contract_seen() -> bool:
	return FileAccess.file_exists(TRUST_FILE_PATH)
