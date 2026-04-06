class_name TrainerDashboard
extends RefCounted

# ==========================================
# TRAINER DASHBOARD — Item 18
# Full-screen overlay showing aggregated training records.
# Reads from TrainingRecord persistence layer.
# ==========================================

var _ui: BayUI

# --- UI nodes ---
var overlay: ColorRect
var _body_rtl: RichTextLabel
var _btn_close: Button
var _cached_records: Array[Dictionary] = []

# Mistake category display names (EN only — operational data, not trainee-facing)
const MISTAKE_LABELS: Dictionary = {
	"sequence_errors": "Sequence Errors",
	"co_interleave_errors": "Co-Load Interleave",
	"rework_penalized": "Rework (Penalized)",
	"rework_forgiven": "Rework (Forgiven)",
	"cc_left_behind": "C&C Left Behind",
	"cc_not_investigated": "C&C Not Investigated",
	"priority_left_behind": "Priority Left Behind",
	"transit_missed": "Transit Missed",
	"adr_missed": "ADR Missed",
	"as400_not_validated": "AS400 Not Validated",
	"paperwork_errors": "Paperwork Errors",
}


func _init(ui: BayUI) -> void:
	_ui = ui


func _build(root: Node) -> void:
	overlay = ColorRect.new()
	overlay.color = UITokens.CLR_OVERLAY_DARK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(780, 640)
	UIStyles.apply_panel(pnl, UIStyles.modal(UITokens.CLR_MODAL_BG, 10, 40, 0.6))
	center.add_child(pnl)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 24)
	pnl.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# --- Header row ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	vbox.add_child(header_row)

	var hdr := Label.new()
	hdr.text = Locale.t("trainer.title")
	hdr.add_theme_font_size_override("font_size", UITokens.fs(16))
	hdr.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_BLUE)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(hdr)

	var btn_export := Button.new()
	btn_export.text = Locale.t("trainer.export")
	btn_export.custom_minimum_size = Vector2(90, 30)
	btn_export.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn_auto(btn_export, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4, 1, UITokens.CLR_SURFACE_MID)
	btn_export.pressed.connect(func() -> void: _on_export_pressed())
	header_row.add_child(btn_export)

	_btn_close = Button.new()
	_btn_close.text = Locale.t("btn.close_app")
	_btn_close.custom_minimum_size = Vector2(80, 30)
	_btn_close.add_theme_font_size_override("font_size", UITokens.fs(12))
	UIStyles.apply_btn_auto(_btn_close, UITokens.CLR_BG_DARK,
			UITokens.CLR_TEXT_SECONDARY, UITokens.CLR_WHITE, 4, 1, UITokens.CLR_SURFACE_MID)
	_btn_close.pressed.connect(func() -> void: hide())
	header_row.add_child(_btn_close)

	# --- Divider ---
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UITokens.CLR_PANEL_BORDER
	vbox.add_child(div)

	# --- Scrollable body ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_body_rtl = RichTextLabel.new()
	_body_rtl.bbcode_enabled = true
	_body_rtl.fit_content = true
	_body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_rtl.add_theme_color_override("default_color", UITokens.CLR_TEXT_SECONDARY)
	_body_rtl.add_theme_font_size_override("normal_font_size", UITokens.fs(13))
	_body_rtl.meta_clicked.connect(_on_meta_clicked)
	scroll.add_child(_body_rtl)


func show() -> void:
	if overlay == null:
		return
	refresh()
	overlay.visible = true


func hide() -> void:
	if overlay != null:
		overlay.visible = false


func refresh() -> void:
	if _body_rtl == null:
		return
	var all: Array[Dictionary] = TrainingRecord.load_all_records()
	_cached_records = all
	if all.is_empty():
		_body_rtl.text = "[center]\n\n" + UITokens.BB_DIM + Locale.t("trainer.no_data") + UITokens.BB_END + "[/center]"
		return

	var bb: String = ""
	bb += _build_summary_section(all)
	bb += "\n"
	bb += _build_scenario_breakdown(all)
	bb += "\n"
	bb += _build_mistake_section(all)
	bb += "\n"
	bb += _build_recent_table(all)
	_body_rtl.text = bb


func _build_summary_section(records: Array[Dictionary]) -> String:
	var total: int = records.size()
	var passed_count: int = 0
	var total_score: int = 0
	var total_time: float = 0.0
	for r: Dictionary in records:
		if bool(r.get("passed", false)):
			passed_count += 1
		total_score += int(r.get("score", 0))
		total_time += float(r.get("time_seconds", 0.0))
	@warning_ignore("integer_division")
	var avg_score: int = total_score / maxi(total, 1)
	@warning_ignore("integer_division")
	var pass_rate: int = (passed_count * 100) / maxi(total, 1)
	@warning_ignore("integer_division")
	var avg_time_m: int = int(total_time / float(maxi(total, 1))) / 60
	@warning_ignore("integer_division")
	var avg_time_s: int = int(total_time / float(maxi(total, 1))) % 60

	var bb: String = ""
	bb += UITokens.BB_ACCENT + "[b]" + Locale.t("trainer.summary") + "[/b]" + UITokens.BB_END + "\n"
	bb += UITokens.BB_WHITE + "[b]" + str(total) + "[/b]" + UITokens.BB_END
	bb += " " + UITokens.BB_DIM + Locale.t("trainer.sessions") + UITokens.BB_END + "    "

	var rate_clr: String = UITokens.BB_SUCCESS if pass_rate >= 70 else (UITokens.BB_WARNING if pass_rate >= 50 else UITokens.BB_ERROR)
	bb += rate_clr + "[b]" + str(pass_rate) + "%[/b]" + UITokens.BB_END
	bb += " " + UITokens.BB_DIM + Locale.t("trainer.pass_rate") + UITokens.BB_END + "    "

	var score_clr: String = UITokens.BB_SUCCESS if avg_score >= 85 else (UITokens.BB_WARNING if avg_score >= 70 else UITokens.BB_ERROR)
	bb += score_clr + "[b]" + str(avg_score) + "[/b]" + UITokens.BB_END
	bb += " " + UITokens.BB_DIM + Locale.t("trainer.avg_score") + UITokens.BB_END + "    "

	bb += UITokens.BB_WHITE + "[b]" + str(avg_time_m) + ":" + "%02d" % avg_time_s + "[/b]" + UITokens.BB_END
	bb += " " + UITokens.BB_DIM + Locale.t("trainer.avg_time") + UITokens.BB_END + "\n"
	return bb


func _build_scenario_breakdown(records: Array[Dictionary]) -> String:
	var scenarios: Dictionary = {}
	for r: Dictionary in records:
		var scen: String = str(r.get("scenario", ""))
		if not scenarios.has(scen):
			scenarios[scen] = {"count": 0, "passed": 0, "total_score": 0, "best": 0}
		var entry: Dictionary = scenarios[scen]
		entry["count"] = int(entry["count"]) + 1
		if bool(r.get("passed", false)):
			entry["passed"] = int(entry["passed"]) + 1
		var score: int = int(r.get("score", 0))
		entry["total_score"] = int(entry["total_score"]) + score
		if score > int(entry["best"]):
			entry["best"] = score

	var bb: String = ""
	bb += UITokens.BB_ACCENT + "[b]" + Locale.t("trainer.by_scenario") + "[/b]" + UITokens.BB_END + "\n"

	var scenario_order: Array[String] = [
		"0. Tutorial", "1. Standard Loading", "2. Priority Loading", "3. Co-Loading"
	]
	for scen: String in scenario_order:
		if not scenarios.has(scen):
			continue
		var entry: Dictionary = scenarios[scen]
		var count: int = int(entry["count"])
		var passed: int = int(entry["passed"])
		@warning_ignore("integer_division")
		var avg: int = int(entry["total_score"]) / maxi(count, 1)
		var best: int = int(entry["best"])
		@warning_ignore("integer_division")
		var rate: int = (passed * 100) / maxi(count, 1)

		var short: String = _short_name(scen)
		var rate_clr: String = UITokens.BB_SUCCESS if rate >= 70 else (UITokens.BB_WARNING if rate >= 50 else UITokens.BB_ERROR)

		bb += UITokens.BB_WHITE + "[b]" + short + "[/b]" + UITokens.BB_END + "  "
		bb += UITokens.BB_DIM + str(count) + "x" + UITokens.BB_END + "  "
		bb += rate_clr + str(rate) + "% pass" + UITokens.BB_END + "  "
		bb += UITokens.BB_DIM + "avg " + str(avg) + UITokens.BB_END + "  "
		bb += UITokens.BB_GOLD + "best " + str(best) + UITokens.BB_END + "\n"
	return bb


func _build_mistake_section(records: Array[Dictionary]) -> String:
	var totals: Dictionary = {}
	for r: Dictionary in records:
		var mistakes: Dictionary = r.get("mistakes", {}) as Dictionary
		for key: String in mistakes.keys():
			var val: Variant = mistakes[key]
			var numeric: int = 0
			if val is bool:
				numeric = 1 if bool(val) else 0
			elif val is int or val is float:
				numeric = int(val)
			if numeric > 0:
				if not totals.has(key):
					totals[key] = 0
				totals[key] = int(totals[key]) + numeric

	if totals.is_empty():
		return ""

	# Sort by frequency descending
	var sorted_keys: Array[String] = []
	for k: String in totals.keys():
		sorted_keys.append(k)
	sorted_keys.sort_custom(func(a: String, b: String) -> bool:
		return int(totals.get(a, 0)) > int(totals.get(b, 0))
	)

	var max_val: int = 1
	for k: String in sorted_keys:
		var v: int = int(totals.get(k, 0))
		if v > max_val:
			max_val = v

	var bb: String = ""
	bb += UITokens.BB_ACCENT + "[b]" + Locale.t("trainer.common_mistakes") + "[/b]" + UITokens.BB_END + "\n"

	var shown: int = 0
	for key: String in sorted_keys:
		if shown >= 8:
			break
		var count: int = int(totals.get(key, 0))
		if count == 0:
			continue
		var label: String = MISTAKE_LABELS.get(key, key)
		@warning_ignore("integer_division")
		var bar_len: int = maxi(1, (count * 20) / max_val)
		var bar: String = ""
		for _i: int in range(bar_len):
			bar += "█"

		var bar_clr: String = UITokens.BB_ERROR if count >= 5 else (UITokens.BB_WARNING if count >= 2 else UITokens.BB_DIM)
		bb += UITokens.BB_DIM + label + UITokens.BB_END + " "
		bb += bar_clr + bar + " " + str(count) + UITokens.BB_END + "\n"
		shown += 1

	return bb


func _build_recent_table(records: Array[Dictionary]) -> String:
	var bb: String = ""
	bb += UITokens.BB_ACCENT + "[b]" + Locale.t("trainer.recent_sessions") + "[/b]" + UITokens.BB_END + "\n"

	# Header
	bb += UITokens.BB_HINT + "Date                 Scenario       Score  Time     Result" + UITokens.BB_END + "\n"

	var limit: int = mini(records.size(), 20)
	for i: int in range(limit):
		var r: Dictionary = records[i]
		var date_str: String = _format_date(str(r.get("date", "")))
		var scen: String = _short_name(str(r.get("scenario", "")))
		var score: int = int(r.get("score", 0))
		var passed: bool = bool(r.get("passed", false))
		var time_s: float = float(r.get("time_seconds", 0.0))
		@warning_ignore("integer_division")
		var t_min: int = int(time_s) / 60
		var t_sec: int = int(time_s) % 60
		var time_str: String = str(t_min) + ":" + "%02d" % t_sec

		var score_clr: String = UITokens.BB_SUCCESS if passed else (UITokens.BB_WARNING if score >= 70 else UITokens.BB_ERROR)
		var icon: String = "✓" if passed else "✗"
		var icon_clr: String = UITokens.BB_SUCCESS if passed else UITokens.BB_ERROR

		# Pad columns with spaces for alignment
		var scen_pad: String = scen + "              "
		scen_pad = scen_pad.left(15)
		var score_pad: String = str(score)
		while score_pad.length() < 6:
			score_pad += " "
		var time_pad: String = time_str
		while time_pad.length() < 9:
			time_pad += " "

		var has_log: bool = not (r.get("action_log", []) as Array).is_empty()
		var row_text: String = ""
		row_text += UITokens.BB_DIM + date_str + UITokens.BB_END + "  "
		row_text += UITokens.BB_WHITE + scen_pad + UITokens.BB_END
		row_text += score_clr + score_pad + UITokens.BB_END
		row_text += UITokens.BB_DIM + time_pad + UITokens.BB_END
		row_text += icon_clr + icon + UITokens.BB_END

		if has_log:
			bb += "[url=replay:" + str(i) + "]" + row_text + "  ▶[/url]\n"
		else:
			bb += row_text + "\n"

	if records.size() > 20:
		bb += UITokens.BB_DIM + "… " + str(records.size() - 20) + " " + Locale.t("trainer.more_records") + UITokens.BB_END + "\n"

	return bb


static func _short_name(full: String) -> String:
	if full.begins_with("0"):
		return "Tutorial"
	if full.begins_with("1"):
		return "Standard"
	if full.begins_with("2"):
		return "Priority"
	if full.begins_with("3"):
		return "Co-Load"
	return full


static func _format_date(iso: String) -> String:
	## "2026-04-04T14:30:00" → "04 Apr 14:30"
	if iso.length() < 16:
		return iso
	var date_part: String = iso.substr(0, 10)
	var time_part: String = iso.substr(11, 5)
	var parts: PackedStringArray = date_part.split("-")
	if parts.size() < 3:
		return iso
	var months: Array[String] = [
		"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	]
	var m_idx: int = clampi(int(parts[1]) - 1, 0, 11)
	return parts[2] + " " + months[m_idx] + " " + time_part


func _on_meta_clicked(meta: Variant) -> void:
	var meta_str: String = str(meta)
	if meta_str.begins_with("replay:"):
		var idx: int = int(meta_str.substr(7))
		if idx >= 0 and idx < _cached_records.size():
			hide()
			_ui._replay.start_replay(_cached_records[idx])


func _on_export_pressed() -> void:
	var path: String = TrainingRecord.export_all_trainees()
	if path != "" and _body_rtl != null:
		var note: String = "\n\n" + UITokens.BB_SUCCESS + "[b]" + Locale.t("trainer.exported") + "[/b]" + UITokens.BB_END
		note += "\n" + UITokens.BB_DIM + path + UITokens.BB_END
		_body_rtl.text += note
