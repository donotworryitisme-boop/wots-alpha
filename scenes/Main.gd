extends Control

const DEBUG_OVERLAY_SCENE: PackedScene = preload("res://debug/DebugOverlay.tscn")
const SessionManagerClass               = preload("res://core/session/SessionManager.gd")
const FeedbackLayerScene: PackedScene   = preload("res://ui/FeedbackLayer.tscn")
const TrustContractScene: PackedScene   = preload("res://ui/TrustContract.tscn")

var session_manager: SessionManager
var feedback_layer: FeedbackLayer

func _ready() -> void:
	# Load debug overlay only in debug builds
	if OS.is_debug_build():
		var overlay = DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Create session manager
	session_manager = SessionManagerClass.new()
	add_child(session_manager)

	# Create feedback layer and assign it to the session manager
	feedback_layer = FeedbackLayerScene.instantiate()
	add_child(feedback_layer)
	session_manager.feedback_layer = feedback_layer

	# Show trust contract on first launch or start the session directly
	show_trust_contract_if_needed()

func show_trust_contract_if_needed() -> void:
	var path := "user://trust_contract_seen.dat"
	if FileAccess.file_exists(path):
		# Already accepted; start the session
		start_training_session()
	else:
		show_trust_contract()

func show_trust_contract() -> void:
	# Instantiate the Trust Contract overlay and connect its signal
	var contract := TrustContractScene.instantiate()
	add_child(contract)
	if contract.has_signal("accepted"):
		contract.connect("accepted", Callable(self, "_on_trust_contract_accepted"))
	contract.visible = true

func _on_trust_contract_accepted() -> void:
	# User accepted the contract; start the session
	start_training_session()

func start_training_session() -> void:
	# Begin the training session
	session_manager.start_session()

# Method exposed to show the contract again from the UI
func show_trust_contract_again() -> void:
	show_trust_contract()
