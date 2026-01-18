extends CanvasLayer

signal trust_contract_requested

@onready var scenario_dropdown: OptionButton = $Root/SetupPanel/SetupMargin/SetupVBox/ScenarioRow/ScenarioDropdown
@onready var role_dropdown: OptionButton = $Root/SetupPanel/SetupMargin/SetupVBox/RoleRow/RoleDropdown
@onready var start_button: Button = $Root/SetupPanel/SetupMargin/SetupVBox/ButtonsRow/StartButton
@onready var end_button: Button = $Root/SetupPanel/SetupMargin/SetupVBox/ButtonsRow/EndButton
@onready var trust_button: Button = $Root/SetupPanel/SetupMargin/SetupVBox/TrustContractButton
@onready var what_to_do_label: Label = $Root/SetupPanel/SetupMargin/SetupVBox/WhatToDoPanel/WhatToDoMargin/WhatToDoLabel

@onready var hint_label: Label = $Root/HintLabel

@onready var situation_panel: PanelContainer = $Root/SituationPanel
@onready var time_label: Label = $Root/SituationPanel/SituationMargin/SituationVBox/TimeLabel
@onready var objective_label: Label = $Root/SituationPanel/SituationMargin/SituationVBox/ObjectiveLabel

@onready var check_button: Button = $Root/SituationPanel/SituationMargin/SituationVBox/DecisionRow/CheckButton
@onready var escalate_button: Button = $Root/SituationPanel/SituationMargin/SituationVBox/DecisionRow/EscalateButton
@onready var proceed_button: Button = $Root/SituationPanel/SituationMargin/SituationVBox/DecisionRow/ProceedButton

@onready var log_title: Label = $Root/LogPanel/LogMargin/LogVBox/LogTitle
@onready var explain_toggle: CheckButton = $Root/LogPanel/LogMargin/LogVBox/ExplainWhyToggle
@onready var log_text: RichTextLabel = $Root/LogPanel/LogMargin/LogVBox/LogText

var _enabled: bool = false
var _session: SessionManager = null

var _is_active: bool = false
var _debrief_what_happened: String = ""
var _debrief_why_it_mattered: String = ""

func _ready() -> void:
	# Default UI state: disabled until trust contract accepted.
	set_enabled(false)

	if trust_button != null:
		trust_button.pressed.connect(func() -> void:
			trust_contract_requested.emit()
		)

	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if end_button != null:
		end_button.pressed.connect(_on_end_pressed)

	# Action buttons (renamed; no logic change—still just a manual decision event)
	if check_button != null:
		check_button.pressed.connect(func() -> void: _on_decision_pressed("Check transit / lines"))
	if escalate_button != null:
		escalate_button.pressed.connect(func() -> void: _on_decision_pressed("Call captain"))
	if proceed_button != null:
		# Use plain ASCII apostrophe in the action label for safety.
		proceed_button.pressed.connect(func() -> void: _on_decision_pressed("Load what's available"))

	# Explain-why toggle (only shown on end screen)
	if explain_toggle != null:
		explain_toggle.toggled.connect(_on_explain_toggled)

	_set_setup_guidance()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

	# Keep trust button available even when disabled.
	if trust_button != null:
		trust_button.disabled = false

	if start_button != null:
		start_button.disabled = not enabled
	if scenario_dropdown != null:
		scenario_dropdown.disabled = not enabled
	if role_dropdown != null:
		role_dropdown.disabled = not enabled

	if end_button != null:
		end_button.disabled = true

	if situation_panel != null:
		situation_panel.visible = false

	_is_active = false
	_set_setup_guidance()

	if hint_label != null:
		hint_label.text = ""

	if log_title != null:
		log_title.text = "Learning summary"
	if log_text != null:
		log_text.text = ""
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false

func set_session(session: SessionManager) -> void:
	_session = session
	_populate_scenarios()
	_populate_roles()

	# Connect learning signals (hints + time + situation + end + action feedback).
	if _session != null:
		if _session.has_signal("hint_updated"):
			_session.connect("hint_updated", Callable(self, "_on_hint_updated"))
		if _session.has_signal("time_updated"):
			_session.connect("time_updated", Callable(self, "_on_time_updated"))
		if _session.has_signal("situation_updated"):
			_session.connect("situation_updated", Callable(self, "_on_situation_updated"))
		if _session.has_signal("session_ended"):
			_session.connect("session_ended", Callable(self, "_on_session_ended"))
		if _session.has_signal("action_registered"):
			_session.connect("action_registered", Callable(self, "_on_action_registered"))

func _populate_scenarios() -> void:
	if scenario_dropdown == null or _session == null:
		return
	scenario_dropdown.clear()

	var names: Array[String] = []
	if _session.scenario_loader != null and _session.scenario_loader.has_method("get_scenario_names"):
		names = _session.scenario_loader.call("get_scenario_names")
	else:
		names = ["default"]

	for n in names:
		scenario_dropdown.add_item(n)

func _populate_roles() -> void:
	if role_dropdown == null:
		return
	role_dropdown.clear()
	role_dropdown.add_item("Operator", WOTSConfig.Role.OPERATOR)
	role_dropdown.add_item("Captain", WOTSConfig.Role.CAPTAIN)
	role_dropdown.add_item("Trainer", WOTSConfig.Role.TRAINER)
	role_dropdown.select(0)

func _on_start_pressed() -> void:
	if not _enabled or _session == null:
		return

	var scenario_name: String = "default"
	if scenario_dropdown != null:
		scenario_name = scenario_dropdown.get_item_text(scenario_dropdown.get_selected_id())

	var role_id: int = WOTSConfig.Role.OPERATOR
	if role_dropdown != null:
		role_id = role_dropdown.get_selected_id()

	_session.set_role(role_id)

	_is_active = true
	_set_active_guidance()

	if situation_panel != null:
		situation_panel.visible = true

	if end_button != null:
		end_button.disabled = false
	if start_button != null:
		start_button.disabled = true

	# Reset log area for this run
	if log_title != null:
		log_title.text = "Learning summary"
	if log_text != null:
		log_text.text = "[b]What to do:[/b]\nStart the scenario, use actions, then end to review.\n"
	if explain_toggle != null:
		explain_toggle.visible = false
		explain_toggle.button_pressed = false

	if _session.has_method("start_session_with_scenario"):
		_session.call("start_session_with_scenario", scenario_name)
	else:
		_session.start_session()

func _on_end_pressed() -> void:
	if _session == null:
		return
	_session.end_session()

func _on_decision_pressed(action: String) -> void:
	if _session == null:
		return
	# Manual decision event pushed into existing rule pipeline.
	if _session.has_method("manual_decision"):
		_session.call("manual_decision", action)

func _on_hint_updated(hint_text: String) -> void:
	if hint_label != null:
		hint_label.text = hint_text

func _on_time_updated(total_time: float, loading_time: float) -> void:
	if time_label != null:
		time_label.text = "Time: %0.2fs (Loading: %0.2fs)" % [total_time, loading_time]

func _on_situation_updated(objective_text: String) -> void:
	if objective_label != null:
		objective_label.text = "Objective: " + objective_text

func _on_action_registered(one_line: String) -> void:
	# Immediate feedback after each action: one-line with timestamp.
	if log_text == null:
		return
	log_text.text += one_line + "\n"

func _on_session_ended(debrief_payload: Dictionary) -> void:
	# End screen: show clear structure
	_is_active = false
	_set_setup_guidance()

	if situation_panel != null:
		situation_panel.visible = false

	if start_button != null:
		start_button.disabled = false
	if end_button != null:
		end_button.disabled = true

	_debrief_what_happened = str(debrief_payload.get("what_happened", ""))
	_debrief_why_it_mattered = str(debrief_payload.get("why_it_mattered", ""))

	if log_title != null:
		log_title.text = "Learning summary"

	if explain_toggle != null:
		# Only show if we actually have a "why" section
		explain_toggle.visible = _debrief_why_it_mattered.strip_edges() != ""
		explain_toggle.button_pressed = false

	# FIX: GDScript does not support := named-arg syntax here; call with a plain bool.
	_render_debrief(false)

func _on_explain_toggled(pressed: bool) -> void:
	_render_debrief(pressed)

func _render_debrief(show_why: bool) -> void:
	if log_text == null:
		return

	var bb := "[b]Learning summary[/b]\n\n"
	bb += "[b]What happened[/b]\n"
	bb += _debrief_what_happened + "\n"

	if show_why and _debrief_why_it_mattered.strip_edges() != "":
		bb += "\n[b]Why it mattered[/b]\n"
		bb += _debrief_why_it_mattered + "\n"

	log_text.text = bb

func _set_setup_guidance() -> void:
	if what_to_do_label != null:
		what_to_do_label.text = "Pick a scenario and role, then start."

func _set_active_guidance() -> void:
	if what_to_do_label != null:
		what_to_do_label.text = "Use actions to manage priorities and uncertainty. End to review learning summary."
