extends Control

const DEBUG_OVERLAY_SCENE: PackedScene    = preload("res://debug/DebugOverlay.tscn")
const SessionManagerClass                 = preload("res://core/session/SessionManager.gd")
const FeedbackLayerScene: PackedScene     = preload("res://ui/FeedbackLayer.tscn")

var session_manager: SessionManager
var feedback_layer: FeedbackLayer

func _ready() -> void:
	# Show debug overlay in debug builds only
	if OS.is_debug_build():
		var overlay = DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Instantiate session manager and feedback layer
	session_manager = SessionManagerClass.new()
	add_child(session_manager)

	feedback_layer = FeedbackLayerScene.instantiate()
	add_child(feedback_layer)
	session_manager.feedback_layer = feedback_layer

	# Show trust contract if needed
	show_trust_contract_if_needed()

func show_trust_contract_if_needed() -> void:
	var path := "user://trust_contract_seen.dat"
	if FileAccess.file_exists(path):
		# Already accepted; start the session
		start_training_session()
	else:
		show_trust_contract()

func show_trust_contract() -> void:
	# Use AcceptDialog for the trust contract overlay
	var dialog := AcceptDialog.new()
	dialog.name = "TrustContractDialog"
	dialog.dialog_text = "- This simulation is for learning and coaching only; it will never be used for discipline or ranking.\n- Scores are private to you; managers and captains cannot see individual runs.\n- No personal data is collected; only aggregated metrics are used to improve training.\n- Your role determines what you see; fairness is built into the system."
	dialog.get_ok_button().text = "I Understand"
	dialog.connect("confirmed", Callable(self, "_on_trust_contract_confirmed"))
	add_child(dialog)
	dialog.popup_centered()  # Center the dialog on screen

func _on_trust_contract_confirmed() -> void:
	# Persist acceptance so the contract isn’t shown again
	var file := FileAccess.open("user://trust_contract_seen.dat", FileAccess.WRITE)
	file.store_string("1")
	file.close()
	# Start the session
	start_training_session()

func start_training_session() -> void:
	session_manager.start_session()

func show_trust_contract_again() -> void:
	# Allows re-opening the trust contract from the UI
	show_trust_contract()
