class_name LoginPanel
extends RefCounted

# ==========================================
# LOGIN PANEL — Local account login / registration
# Shows inside the PortalScreen panel area.
# On successful login, calls _ui._on_login_success().
# ==========================================

var _ui: BayUI

# --- UI nodes ---
var container: VBoxContainer
var _username_input: LineEdit
var _password_input: LineEdit
var _confirm_input: LineEdit
var _display_input: LineEdit
var _role_dropdown: OptionButton
var _error_label: Label
var _btn_submit: Button
var _btn_toggle: Button
var _btn_guest: Button

# --- State ---
var _is_register_mode: bool = false


func _init(ui: BayUI) -> void:
	_ui = ui


func build(parent: Control) -> void:
	container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(container)

	# --- Header ---
	var hdr := Label.new()
	hdr.text = Locale.t("login.title")
	hdr.add_theme_font_size_override("font_size", UITokens.fs(15))
	hdr.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(hdr)

	# --- Username ---
	_build_label(Locale.t("login.username"))
	_username_input = _build_input(Locale.t("login.username_hint"))

	# --- Password ---
	_build_label(Locale.t("login.password"))
	_password_input = _build_input(Locale.t("login.password_hint"))
	_password_input.secret = true

	# --- Confirm password (register only, starts hidden) ---
	_build_label(Locale.t("login.confirm_password"))
	_confirm_input = _build_input(Locale.t("login.confirm_hint"))
	_confirm_input.secret = true
	# The label above the confirm input is at index container.get_child_count() - 2
	_set_register_fields_visible(false)

	# --- Display name (register only) ---
	var dn_lbl := Label.new()
	dn_lbl.text = Locale.t("login.display_name")
	dn_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	dn_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	dn_lbl.name = "DisplayNameLabel"
	container.add_child(dn_lbl)

	_display_input = _build_input(Locale.t("login.display_hint"))
	_display_input.name = "DisplayNameInput"

	# --- Role dropdown (register only) ---
	var role_lbl := Label.new()
	role_lbl.text = Locale.t("login.role")
	role_lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	role_lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	role_lbl.name = "RoleLabel"
	container.add_child(role_lbl)

	_role_dropdown = OptionButton.new()
	_role_dropdown.custom_minimum_size = Vector2(0, 32)
	_role_dropdown.add_item("Operator", WOTSConfig.Role.OPERATOR)
	_role_dropdown.add_item("Trainer", WOTSConfig.Role.TRAINER)
	_role_dropdown.select(0)
	_role_dropdown.name = "RoleDropdown"
	UIStyles.apply_dropdown(_role_dropdown)
	var popup: PopupMenu = _role_dropdown.get_popup()
	if popup != null:
		UIStyles.apply_dropdown_popup(popup)
	container.add_child(_role_dropdown)

	# Initially hide register-only fields
	_set_register_extras_visible(false)

	# --- Error message ---
	_error_label = Label.new()
	_error_label.text = ""
	_error_label.add_theme_font_size_override("font_size", UITokens.fs(11))
	_error_label.add_theme_color_override("font_color", UITokens.CLR_ERROR)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(_error_label)

	# --- Submit button ---
	_btn_submit = Button.new()
	_btn_submit.text = Locale.t("login.sign_in")
	_btn_submit.custom_minimum_size = Vector2(0, 42)
	UIStyles.apply_btn_primary(_btn_submit, 6)
	_btn_submit.add_theme_font_size_override("font_size", UITokens.fs(14))
	_btn_submit.pressed.connect(_on_submit)
	container.add_child(_btn_submit)

	# --- Toggle login/register link ---
	_btn_toggle = Button.new()
	_btn_toggle.text = Locale.t("login.switch_to_register")
	_btn_toggle.custom_minimum_size = Vector2(0, 28)
	UIStyles.apply_btn_ghost(_btn_toggle, Color(0.1, 0.1, 0.1, 0.0),
			UITokens.hc_text(UITokens.CLR_TEXT_HINT), UITokens.COLOR_ACCENT_BLUE)
	_btn_toggle.add_theme_font_size_override("font_size", UITokens.fs(11))
	_btn_toggle.pressed.connect(_on_toggle_mode)
	container.add_child(_btn_toggle)

	# --- Guest button (skip login) ---
	_btn_guest = Button.new()
	_btn_guest.text = Locale.t("login.guest")
	_btn_guest.custom_minimum_size = Vector2(0, 26)
	UIStyles.apply_btn_ghost(_btn_guest, Color(0.1, 0.1, 0.1, 0.0),
			UITokens.hc_text(UITokens.CLR_CELL_TEXT_DIM), Color(0.55, 0.57, 0.6))
	_btn_guest.add_theme_font_size_override("font_size", UITokens.fs(10))
	_btn_guest.pressed.connect(_on_guest)
	container.add_child(_btn_guest)

	# --- Connect Enter key on password field ---
	_password_input.text_submitted.connect(func(_text: String) -> void:
		if not _is_register_mode:
			_on_submit()
	)
	_confirm_input.text_submitted.connect(func(_text: String) -> void:
		if _is_register_mode:
			_on_submit()
	)


func show_error(msg: String) -> void:
	if _error_label != null:
		_error_label.text = msg


func clear_fields() -> void:
	if _username_input != null:
		_username_input.text = ""
	if _password_input != null:
		_password_input.text = ""
	if _confirm_input != null:
		_confirm_input.text = ""
	if _display_input != null:
		_display_input.text = ""
	if _error_label != null:
		_error_label.text = ""
	# Always reset to login mode (not register)
	_is_register_mode = false
	_set_register_fields_visible(false)
	_set_register_extras_visible(false)
	if _btn_submit != null:
		_btn_submit.text = Locale.t("login.sign_in")
	if _btn_toggle != null:
		_btn_toggle.text = Locale.t("login.switch_to_register")


# ==========================================
# INTERNAL
# ==========================================

func _build_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", UITokens.fs(11))
	lbl.add_theme_color_override("font_color", UITokens.hc_text(UITokens.CLR_TEXT_SECONDARY))
	container.add_child(lbl)


func _build_input(placeholder: String) -> LineEdit:
	var inp := LineEdit.new()
	inp.placeholder_text = placeholder
	inp.custom_minimum_size = Vector2(0, 32)
	inp.add_theme_font_size_override("font_size", UITokens.fs(13))
	UIStyles.apply_field_dark(inp)
	container.add_child(inp)
	return inp


func _set_register_fields_visible(vis: bool) -> void:
	## Show/hide the confirm password field + its label.
	## The confirm label is 2 children before _confirm_input.
	if _confirm_input == null:
		return
	_confirm_input.visible = vis
	var idx: int = _confirm_input.get_index()
	if idx > 0:
		var prev: Node = container.get_child(idx - 1)
		if prev is Label:
			prev.visible = vis


func _set_register_extras_visible(vis: bool) -> void:
	## Show/hide display name + role fields.
	if _display_input != null:
		_display_input.visible = vis
	if _role_dropdown != null:
		_role_dropdown.visible = vis
	# Hide their labels too
	var dn_lbl: Node = container.get_node_or_null("DisplayNameLabel")
	if dn_lbl != null:
		dn_lbl.visible = vis
	var role_lbl: Node = container.get_node_or_null("RoleLabel")
	if role_lbl != null:
		role_lbl.visible = vis


func _on_toggle_mode() -> void:
	_is_register_mode = not _is_register_mode
	_set_register_fields_visible(_is_register_mode)
	_set_register_extras_visible(_is_register_mode)
	if _error_label != null:
		_error_label.text = ""
	if _btn_submit != null:
		_btn_submit.text = Locale.t("login.create_account") if _is_register_mode else Locale.t("login.sign_in")
	if _btn_toggle != null:
		_btn_toggle.text = Locale.t("login.switch_to_login") if _is_register_mode else Locale.t("login.switch_to_register")


func _on_submit() -> void:
	if _error_label != null:
		_error_label.text = ""

	var username: String = _username_input.text.strip_edges() if _username_input != null else ""
	var password: String = _password_input.text if _password_input != null else ""

	if username == "" or password == "":
		show_error(Locale.t("login.error_empty"))
		return

	if _is_register_mode:
		_do_register(username, password)
	else:
		_do_login(username, password)


func _do_login(username: String, password: String) -> void:
	var err: String = AccountManager.authenticate(username, password)
	if err != "":
		show_error(err)
		return
	# Success — notify BayUI
	UITokens.save_preferences()
	_ui._on_login_success()


func _do_register(username: String, password: String) -> void:
	var confirm: String = _confirm_input.text if _confirm_input != null else ""
	if password != confirm:
		show_error(Locale.t("login.error_mismatch"))
		return

	var display: String = _display_input.text.strip_edges() if _display_input != null else ""
	var role: int = WOTSConfig.Role.OPERATOR
	if _role_dropdown != null:
		role = _role_dropdown.get_selected_id()

	var err: String = AccountManager.create_account(username, password, display, role)
	if err != "":
		show_error(err)
		return

	# Auto-login after registration
	var login_err: String = AccountManager.authenticate(username, password)
	if login_err != "":
		show_error(login_err)
		return

	UITokens.save_preferences()
	_ui._on_login_success()


func _on_guest() -> void:
	## Guest mode: set trainee to "guest", no account required.
	AccountManager.logout()
	TrainingRecord.set_trainee("guest")
	UITokens.save_preferences()
	_ui._on_login_success()
