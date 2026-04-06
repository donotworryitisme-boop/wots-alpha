class_name PaperworkForms
extends RefCounted

## Thin coordinator for Loading Sheet + CMR.
## LS is delegated to LoadingSheetForm, CMR to CMRForm.
## Lives inside BayUI as `_paper`.

var _ui: BayUI

# --- Loading Sheet (extracted) ---
var ls: LoadingSheetForm

# --- CMR (extracted) ---
var cmr: CMRForm


func _init(ui: BayUI) -> void:
	_ui = ui
	ls = LoadingSheetForm.new(ui)
	cmr = CMRForm.new(ui)


# ==========================================
# PUBLIC API
# ==========================================

func clear_paperwork_fields() -> void:
	ls.clear_fields()
	cmr.clear_fields()


func update_loading_sheet() -> void:
	if _ui._session == null: return
	ls.build_if_needed()
	ls.refresh()


func update_cmr() -> void:
	if _ui._session == null: return
	cmr.build_if_needed()
	cmr.refresh_auto_content()


func check_ls_preload_done() -> void:
	## When store + seal + dock all have text, unlock the CMR tab.
	var office: OfficeManager = _ui._office as OfficeManager
	if office.cmr_revealed: return
	if ls.are_preload_fields_filled():
		office.cmr_revealed = true
		if office.paperwork_tab_bar != null: office.paperwork_tab_bar.visible = true
		office.style_paperwork_tabs()
		if _ui.pnl_loading_plan != null:
			update_cmr()
		if office.paperwork_hint_label != null:
			office.paperwork_hint_label.text = "Loading Sheet done — now click the CMR tab to fill in the CMR"
			office.paperwork_hint_label.visible = true
			_ui.get_tree().create_timer(4.0).timeout.connect(func() -> void:
				if office.paperwork_hint_label != null:
					office.paperwork_hint_label.visible = false
			)
		if _ui.tutorial_active:
			_ui._tc.try_advance_panel("CMR", true)


func find_panel_body(panel: PanelContainer) -> RichTextLabel:
	if panel == null: return null
	var margin: Node = panel.get_child(0) if panel.get_child_count() > 0 else null
	if margin == null: return null
	var vbox: Node = margin.get_child(0) if margin.get_child_count() > 0 else null
	if vbox == null: return null
	if vbox.get_child_count() > 1:
		var body_node: Node = vbox.get_child(1)
		if body_node is RichTextLabel: return body_node as RichTextLabel
	return null
