extends Control

const DEBUG_OVERLAY_SCENE: PackedScene   = preload("res://debug/DebugOverlay.tscn")
const SessionManagerClass                = preload("res://core/session/SessionManager.gd")
const FeedbackLayerScene: PackedScene    = preload("res://ui/FeedbackLayer.tscn")

var session_manager: SessionManager
var feedback_layer: FeedbackLayer

func _ready() -> void:
	# Debug overlay (only in debug builds)
	if OS.is_debug_build():
		var overlay = DEBUG_OVERLAY_SCENE.instantiate()
		add_child(overlay)

	# Create the session manager
	session_manager = SessionManagerClass.new()
	add_child(session_manager)

	# Create the feedback layer and assign it
	feedback_layer = FeedbackLayerScene.instantiate()
	add_child(feedback_layer)
	session_manager.feedback_layer = feedback_layer

	# Show Trust Contract if not yet accepted
	show_trust_contract_if_needed()

func show_trust_contract_if_needed() -> void:
	var path := "user://trust_contract_seen.dat"
	if FileAccess.file_exists(path):
		# Already accepted: start session immediately
		start_training_session()
	else:
		show_trust_contract()

func show_trust_contract() -> void:
	# Create a modal popup panel with the contract text
	var popup := PopupPanel.new()
	popup.name = "TrustContractPopup"
	popup.anchor_right = 1.0
	popup.anchor_bottom = 1.0
	popup.popup_centered_ratio = 0.8  # Makes the popup fill most of the screen

	# Add the explanatory text
	var label := Label.new()
	label.autowrap = true
	label.text = "- This simulation is for learning and coaching only; it will never be used for discipline or ranking.\n- Scores are private to you; managers and captains cannot see individual runs.\n- No personal data is collected; only aggregated metrics are used to improve training.\n- Your role determines what you see; fairness is built into the system."
	label.anchor_left = 0.05
	label.anchor_top = 0.05
	label.anchor_right = 0.95
	label.anchor_bottom = 0.75
	popup.add_child(label)

	# Add the acceptance button
	var button := Button.new()
	button.text = "I Understand"
	button.anchor_left = 0.35
	button.anchor_top = 0.8
	button.anchor_right = 0.65
	button.anchor_bottom = 0.9
	popup.add_child(button)
	button.connect("pressed", Callable(self, "_on_trust_contract_button_pressed"), [popup])

	# Add the popup to the scene and show it
	add_child(popup)
	popup.popup_centered()

func _on_trust_contract_button_pressed(popup: PopupPanel) -> void:
	# Persist acceptance so the contract isn’t shown again
	var file := FileAccess.open("user://trust_contract_seen.dat", FileAccess.WRITE)
	file.store_string("1")
	file.close()
	# Remove the popup
	popup.queue_free()
	# Start the training session
	start_training_session()

func start_training_session() -> void:
	session_manager.start_session()

# Exposed method to reopen the Trust Contract from BayUI
func show_trust_contract_again() -> void:
	show_trust_contract()
