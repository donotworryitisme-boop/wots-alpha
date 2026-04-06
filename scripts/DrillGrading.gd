class_name DrillGrading
extends RefCounted

# ==========================================
# DRILL GRADING — extracted from DrillManager
# All static methods for scoring micro-drills.
# ==========================================


static func grade_as400(elapsed: float, wrong_scans: int) -> Dictionary:
	@warning_ignore("integer_division")
	var time_pen: int = maxi(0, int((elapsed - 60.0) / 10.0))
	var scan_pen: int = wrong_scans * 5
	var score: int = clampi(100 - time_pen - scan_pen, 0, 100)
	var fb: String = grade_label(score)
	if scan_pen > 0:
		fb += "\n" + Locale.t("drill.as400_wrong_scans") % [str(wrong_scans)]
	fb += "\n" + time_line(elapsed)
	return {"score": score, "feedback": fb}


static func grade_sequencing(sm: SessionManager, elapsed: float) -> Dictionary:
	var seq_errors: int = 0
	var highest_rank: int = -1
	for p: Dictionary in sm.inventory_loaded:
		var rank: int = GradingEngine.get_load_rank(p)
		if rank < highest_rank:
			seq_errors += 1
		else:
			highest_rank = rank
	@warning_ignore("integer_division")
	var time_pen: int = maxi(0, int((elapsed - 180.0) / 15.0))
	var score: int = clampi(100 - (seq_errors * 15) - time_pen, 0, 100)
	var fb: String = ""
	if seq_errors == 0:
		fb = Locale.t("drill.seq_perfect")
	else:
		fb = Locale.t("drill.seq_errors") % [str(seq_errors)]

	# Transit rack penalty
	var had_transit: bool = not sm.transit_items.is_empty() or not sm.transit_loose_entries.is_empty() or sm.transit_collected
	if had_transit and not sm.transit_collected:
		score = clampi(score - 10, 0, 100)
		fb += "\n" + UITokens.BB_WARNING + Locale.t("drill.seq_transit_missed") + UITokens.BB_END

	# ADR / yellow locker penalty
	if sm.has_adr and not sm.adr_collected:
		score = clampi(score - 15, 0, 100)
		fb += "\n" + UITokens.BB_ERROR + Locale.t("drill.seq_adr_missed") + UITokens.BB_END

	fb += "\n" + time_line(elapsed)

	# Visual truck comparison: actual vs ideal
	if seq_errors > 0:
		fb += "\n\n" + build_seq_comparison(sm.inventory_loaded)
	return {"score": score, "feedback": fb}


static func grade_paperwork(sm: SessionManager, elapsed: float) -> Dictionary:
	var score: int = 100
	var errors: Array[String] = []

	# --- Loading Sheet fields ---
	score = check_field(sm.typed_store_code, sm.store_code, "Store Code", 10, score, errors)
	score = check_field(sm.typed_seal, sm.seal_number, "Seal", 10, score, errors)
	score = check_field(sm.typed_dock, str(sm.dock_number), "Dock", 10, score, errors)
	score = check_field(sm.typed_expedition_ls, sm.expedition_number_1, "Expedition (LS)", 10, score, errors)

	# --- CMR fields ---
	if not sm.paperwork_cmr_opened:
		score -= 15
		errors.append(Locale.t("drill.cmr_not_opened"))
	else:
		var exp_w: float = 0.0
		var exp_dm3: int = 0
		var exp_collis: int = 0
		var _exp_eur: int = 0
		var _exp_plastic: int = 0
		var _exp_magnum: int = 0
		var _exp_cc: int = 0
		for p: Dictionary in sm.inventory_loaded:
			exp_w += float(p.get("weight_kg", 0.0))
			exp_dm3 += int(p.get("dm3", 0))
			exp_collis += int(p.get("collis", 0))
			var base: String = str(p.get("pallet_base", "euro"))
			if base == "euro": _exp_eur += 1
			elif base == "plastic": _exp_plastic += 1
			elif base == "magnum": _exp_magnum += 1
			if str(p.get("type", "")) == "C&C": _exp_cc += 1
		score = check_numeric(sm.typed_weight, exp_w, 0.05, "Weight", 5, score, errors)
		score = check_numeric(sm.typed_dm3, float(exp_dm3), 0.05, "Volume (dm³)", 5, score, errors)
		score = check_field(sm.typed_cmr_uats, str(sm.inventory_loaded.size()), "UATs", 5, score, errors)
		score = check_field(sm.typed_cmr_collis, str(exp_collis), "Collis", 5, score, errors)
		score = check_field(sm.typed_cmr_seal, sm.seal_number, "CMR Seal", 10, score, errors)
		score = check_field(sm.typed_cmr_dock, str(sm.dock_number), "CMR Dock", 5, score, errors)
		if not sm.cmr_franco_selected:
			score -= 5
			errors.append("Franco")

	score = clampi(score, 0, 100)
	var fb: String = grade_label(score)
	if not errors.is_empty():
		fb += "\n\n" + UITokens.BB_ERROR + Locale.t("drill.incorrect_fields") + UITokens.BB_END
		for e: String in errors:
			fb += "\n  • " + e
	fb += "\n\n" + time_line(elapsed)
	return {"score": score, "feedback": fb}


static func grade_label(score: int) -> String:
	if score >= 90:
		return Locale.t("drill.grade_excellent")
	if score >= 70:
		return Locale.t("drill.grade_good")
	return Locale.t("drill.grade_practice")


static func time_line(elapsed: float) -> String:
	@warning_ignore("integer_division")
	var mins: int = int(elapsed) / 60
	var secs: int = int(elapsed) % 60
	return Locale.t("drill.time_taken") % ["%d:%02d" % [mins, secs]]


static func build_seq_comparison(loaded: Array) -> String:
	## Renders actual vs ideal truck rows using colored type abbreviations.
	if loaded.is_empty():
		return ""

	var ideal: Array = loaded.duplicate(true)
	ideal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)

	var bb: String = "[font_size=14][b]" + Locale.t("debrief.load_comparison") + "[/b][/font_size]\n"
	bb += "[font_size=12]" + UITokens.BB_HINT + Locale.t("debrief.your_truck") + UITokens.BB_END + "[/font_size]\n"
	bb += render_truck_row(loaded) + "\n"
	bb += "[font_size=12]" + UITokens.BB_HINT + Locale.t("debrief.ideal_truck") + UITokens.BB_END + "[/font_size]\n"
	bb += render_truck_row(ideal) + "\n"
	bb += "[font_size=10]" + UITokens.BB_DIM
	bb += "SC=ServiceCenter  BK=Bikes  BU=Bulky  ME=Mecha  CC=C&C"
	bb += UITokens.BB_END + "[/font_size]"
	return bb


static func render_truck_row(order: Array) -> String:
	## Renders a single truck as a row of colored type abbreviations.
	var bb: String = "[font_size=11]"
	for i: int in range(order.size()):
		var entry: Dictionary = order[i] as Dictionary
		var ptype: String = str(entry.get("type", ""))
		var abbr: String = DebriefScreen._type_abbr(ptype)
		var clr: String = DebriefScreen._type_bb_color(ptype)
		bb += clr + "[" + str(i + 1) + ":" + abbr + "]" + UITokens.BB_END + " "
	bb += "[/font_size]"
	return bb


static func check_field(typed: String, expected: String, label: String,
		penalty: int, score: int, errors: Array[String]) -> int:
	if typed == "":
		errors.append(label + " (empty)")
		return score - penalty
	if typed != expected:
		errors.append(label)
		return score - penalty
	return score


static func check_numeric(typed: String, expected: float, tolerance: float,
		label: String, penalty: int, score: int, errors: Array[String]) -> int:
	if typed == "":
		errors.append(label + " (empty)")
		return score - penalty
	if expected > 0.0 and absf(typed.to_float() - expected) > expected * tolerance:
		errors.append(label)
		return score - penalty
	return score
