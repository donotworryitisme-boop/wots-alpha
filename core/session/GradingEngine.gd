class_name GradingEngine
extends RefCounted

# ==========================================
# GRADING ENGINE — extracted from SessionManager.end_session()
# Scores a completed session and builds the debrief payload.
# All methods are static — no instance needed.
# All feedback text lives in Locale (grade.* keys).
# ==========================================


static func get_load_rank(p: Dictionary) -> int:
	if p.type == "ServiceCenter": return 0
	if p.type == "C&C": return 99
	var promise_tier: int = 0
	if p.promise == "D+":
		promise_tier = 1
	var type_rank: int = 3
	match p.type:
		"Bikes": type_rank = 1
		"Bulky": type_rank = 2
		"Mecha": type_rank = 3
		"ADR":   type_rank = 4
	return promise_tier * 10 + type_rank


static func grade(sm: SessionManager) -> Dictionary:
	var seq_errors: int = 0
	var co_interleave_errors: int = 0

	if sm.is_co_load:
		var first_dest2_pos: int = sm.inventory_loaded.size()
		for i: int in range(sm.inventory_loaded.size()):
			if sm.inventory_loaded[i].get("dest", 1) == 2:
				first_dest2_pos = i
				break
		for i: int in range(first_dest2_pos + 1, sm.inventory_loaded.size()):
			if sm.inventory_loaded[i].get("dest", 1) == 1:
				if sm.inventory_loaded[i].id not in sm._reworked_pallet_ids:
					co_interleave_errors += 1
					seq_errors += 1
		for dest_id: int in [1, 2]:
			var highest_rank: int = -1
			var co_seq_exempt_used: int = 0
			for p: Dictionary in sm.inventory_loaded:
				if p.get("dest", 1) != dest_id:
					continue
				var rank: int = get_load_rank(p)
				if rank < highest_rank:
					if p.id in sm._wave_pallet_ids:
						pass
					elif p.id in sm._combine_source_ids and co_seq_exempt_used < 4 and p.type != "C&C":
						co_seq_exempt_used += 1
					else:
						seq_errors += 1
				else:
					highest_rank = rank
	else:
		var highest_rank: int = -1
		var seq_exempt_used: int = 0
		for p: Dictionary in sm.inventory_loaded:
			var rank: int = get_load_rank(p)
			if rank < highest_rank:
				if p.id in sm._wave_pallet_ids:
					pass
				elif p.id in sm._combine_source_ids and seq_exempt_used < 4 and p.type != "C&C":
					seq_exempt_used += 1
				else:
					seq_errors += 1
			else:
				highest_rank = rank

	var did_validate: bool = false
	if sm.is_co_load:
		did_validate = ("Confirm AS400 Dest 1" in sm._manual_decisions) and ("Confirm AS400 Dest 2" in sm._manual_decisions)
	else:
		did_validate = "Confirm AS400 Dest 1" in sm._manual_decisions
	var called_departments: bool = "Call departments (C&C check)" in sm._manual_decisions

	var tutorial_rework_forgiven: bool = false
	if sm.current_scenario == "0. Tutorial" and sm.unload_count > 0:
		sm.unload_count -= 1
		sm.total_time -= 66.0
		tutorial_rework_forgiven = true

	var forgiven_rework: int = mini(sm._required_rework_ids.size(), sm.unload_count)
	var penalized_unloads: int = sm.unload_count - forgiven_rework

	var score: int = 100
	var feedback: Array = []
	var critical_fail: bool = false

	if tutorial_rework_forgiven:
		feedback.append(Locale.t("grade.tutorial_rework"))

	# --- Sequence errors ---
	var type_seq_errors: int = seq_errors - co_interleave_errors
	if type_seq_errors > 0:
		score -= (type_seq_errors * 10)
		if sm.current_scenario == "2. Priority Loading":
			feedback.append(Locale.t("grade.seq_priority") % [str(type_seq_errors)])
		elif type_seq_errors <= 2:
			feedback.append(Locale.t("grade.seq_minor") % [str(type_seq_errors)])
		else:
			feedback.append(Locale.t("grade.seq_major") % [str(type_seq_errors), str(type_seq_errors)])
	if co_interleave_errors > 0:
		score -= (co_interleave_errors * 10)
		feedback.append(Locale.t("grade.co_interleave") % [str(co_interleave_errors)])

	# --- Rework ---
	if sm.unload_count > 0:
		score -= (penalized_unloads * 5)
		if forgiven_rework > 0:
			feedback.append(Locale.t("grade.rework_smart") % [str(forgiven_rework)])
		if penalized_unloads > 0:
			if penalized_unloads <= 2:
				feedback.append(Locale.t("grade.rework_minor") % [str(penalized_unloads)])
			else:
				feedback.append(Locale.t("grade.rework_major") % [str(penalized_unloads), str(penalized_unloads)])

	# --- AS400 Validation ---
	if not did_validate:
		if sm.is_co_load:
			var missing_dests: Array[String] = []
			if "Confirm AS400 Dest 1" not in sm._manual_decisions:
				missing_dests.append("Store 1")
			if "Confirm AS400 Dest 2" not in sm._manual_decisions:
				missing_dests.append("Store 2")
			score -= (missing_dests.size() * 10)
			feedback.append(Locale.t("grade.as400_co_missing") % [", ".join(missing_dests)])
		else:
			score -= 20
			feedback.append(Locale.t("grade.as400_missing"))

	# --- Left-behind pallets ---
	var left_behind_cc: int = 0
	var left_behind_cc_uncalled: int = 0
	var left_behind_priority: int = 0
	for p: Dictionary in sm.inventory_available:
		if p.type == "C&C":
			if p.missing:
				left_behind_cc_uncalled += 1
			else:
				left_behind_cc += 1
		elif not p.missing and (p.promise == "D" or p.promise == "D-"):
			left_behind_priority += 1

	if left_behind_cc > 0:
		critical_fail = true
		score -= (left_behind_cc * 25)
		feedback.append(Locale.t("grade.cc_left_behind") % [str(left_behind_cc)])

	if left_behind_cc_uncalled > 0 and not called_departments:
		critical_fail = true
		score -= 20
		feedback.append(Locale.t("grade.cc_not_investigated") % [str(left_behind_cc_uncalled)])

	if left_behind_priority > 0 and sm.current_scenario == "2. Priority Loading":
		score -= (left_behind_priority * 15)
		feedback.append(Locale.t("grade.priority_left_behind") % [str(left_behind_priority)])

	# --- Transit rack ---
	var had_transit_items: bool = (sm.transit_loose_entries.size() > 0 or sm.transit_items.size() > 0)
	var transit_missed: bool = had_transit_items and not sm.transit_collected
	if transit_missed:
		score -= 10
		feedback.append(Locale.t("grade.transit_not_checked"))

	# --- ADR ---
	var adr_missed: bool = sm.has_adr and not sm.adr_collected
	if adr_missed:
		score -= 25
		critical_fail = true
		feedback.append(Locale.t("grade.adr_not_collected"))
	if sm.has_adr and sm.adr_collected:
		var adr_on_dock: bool = false
		for p: Dictionary in sm.inventory_available:
			if p.get("has_adr", false):
				adr_on_dock = true
				break
		if adr_on_dock:
			score -= 15
			feedback.append(Locale.t("grade.adr_left_on_dock"))

	# --- Paperwork ---
	var paperwork_error_count: int = 0
	if sm.current_scenario != "0. Tutorial":
		var pw_result: Dictionary = _grade_paperwork_fields(sm, score, feedback)
		score = int(pw_result.get("score", score))
		paperwork_error_count = int(pw_result.get("error_count", 0))

	score = clampi(score, 0, 100)
	var passed: bool = score >= 85 and not critical_fail

	# Build mistake categories for TrainingRecord persistence
	var mistakes: Dictionary = {
		"sequence_errors": type_seq_errors,
		"co_interleave_errors": co_interleave_errors,
		"rework_penalized": penalized_unloads,
		"rework_forgiven": forgiven_rework,
		"cc_left_behind": left_behind_cc,
		"cc_not_investigated": left_behind_cc_uncalled if not called_departments else 0,
		"priority_left_behind": left_behind_priority,
		"transit_missed": transit_missed,
		"adr_missed": adr_missed,
		"as400_not_validated": not did_validate,
		"paperwork_errors": paperwork_error_count,
	}

	return _build_payload(sm, score, passed, critical_fail, feedback,
			penalized_unloads, left_behind_cc, left_behind_cc_uncalled,
			left_behind_priority, had_transit_items, mistakes)


static func _grade_paperwork_fields(sm: SessionManager, score: int, feedback: Array) -> Dictionary:
	var fb_before: int = feedback.size()
	if not sm.paperwork_ls_opened and not sm.paperwork_cmr_opened:
		score -= 10
		feedback.append(Locale.t("grade.paperwork_both_missing"))
	elif not sm.paperwork_cmr_opened:
		score -= 5
		feedback.append(Locale.t("grade.cmr_not_reviewed"))
	elif not sm.paperwork_ls_opened:
		score -= 5
		feedback.append(Locale.t("grade.ls_not_reviewed"))

	if sm.paperwork_ls_opened and sm.typed_store_code != "" and sm.typed_store_code != sm.store_code:
		score -= 10
		feedback.append(Locale.t("grade.wrong_store_code") % [sm.typed_store_code, sm.store_code])
	if sm.paperwork_ls_opened and sm.typed_seal != "" and sm.typed_seal != sm.seal_number:
		score -= 10
		feedback.append(Locale.t("grade.wrong_seal_ls") % [sm.typed_seal, sm.seal_number])
	if sm.paperwork_ls_opened and sm.typed_dock != "" and sm.typed_dock != str(sm.dock_number):
		score -= 5
		feedback.append(Locale.t("grade.wrong_dock_ls") % [sm.typed_dock, str(sm.dock_number)])
	if sm.paperwork_ls_opened and sm.typed_expedition_ls != "" and sm.typed_expedition_ls != sm.expedition_number_1:
		score -= 10
		feedback.append(Locale.t("grade.wrong_expedition_ls") % [sm.typed_expedition_ls, sm.expedition_number_1])
	if sm.paperwork_cmr_opened and sm.typed_expedition_cmr != "" and sm.typed_expedition_cmr != sm.expedition_number_1:
		score -= 10
		feedback.append(Locale.t("grade.wrong_expedition_cmr") % [sm.typed_expedition_cmr, sm.expedition_number_1])
	if sm.paperwork_cmr_opened and sm.typed_weight != "":
		var pw_weight_source: Array = sm.inventory_loaded
		if sm.is_co_load:
			pw_weight_source = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 1)
		var pw_actual_weight: float = 0.0
		for pw_p: Dictionary in pw_weight_source:
			pw_actual_weight += pw_p.get("weight_kg", 0.0)
		var pw_typed_w: float = sm.typed_weight.to_float()
		if pw_actual_weight > 0.0 and absf(pw_typed_w - pw_actual_weight) > pw_actual_weight * 0.05:
			score -= 10
			feedback.append(Locale.t("grade.wrong_weight_cmr") % [str(int(pw_typed_w)), str(int(pw_actual_weight))])
	if sm.paperwork_cmr_opened and sm.typed_dm3 != "":
		var pw_dm3_source: Array = sm.inventory_loaded
		if sm.is_co_load:
			pw_dm3_source = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 1)
		var pw_actual_dm3: int = 0
		for pw_p: Dictionary in pw_dm3_source:
			pw_actual_dm3 += pw_p.get("dm3", 0)
		var pw_typed_v: float = sm.typed_dm3.to_float()
		if pw_actual_dm3 > 0 and absf(pw_typed_v - float(pw_actual_dm3)) > float(pw_actual_dm3) * 0.05:
			score -= 10
			feedback.append(Locale.t("grade.wrong_volume_cmr") % [str(int(pw_typed_v)), str(pw_actual_dm3)])

	if sm.paperwork_ls_opened:
		var ls_source: Array = sm.inventory_loaded
		if sm.is_co_load:
			ls_source = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 1)
		var actual_uats: int = ls_source.size()
		var actual_collis: int = 0
		var actual_eur: int = 0
		var actual_plastic: int = 0
		var actual_magnum: int = 0
		for fc_p: Dictionary in ls_source:
			actual_collis += fc_p.get("collis", 0)
			var fc_base: String = fc_p.get("pallet_base", "euro")
			if fc_base == "euro": actual_eur += 1
			elif fc_base == "plastic": actual_plastic += 1
			elif fc_base == "magnum": actual_magnum += 1
		if sm.typed_uat_count != "" and int(sm.typed_uat_count) != actual_uats:
			score -= 5
			feedback.append(Locale.t("grade.wrong_uat_ls") % [sm.typed_uat_count, str(actual_uats)])
		if sm.typed_collis_count != "" and int(sm.typed_collis_count) != actual_collis:
			score -= 5
			feedback.append(Locale.t("grade.wrong_collis_ls") % [sm.typed_collis_count, str(actual_collis)])
		if sm.typed_eur_count != "" and int(sm.typed_eur_count) != actual_eur:
			score -= 5
			feedback.append(Locale.t("grade.wrong_eur_ls") % [sm.typed_eur_count, str(actual_eur)])
		if sm.typed_plastic_count != "" and int(sm.typed_plastic_count) != actual_plastic:
			score -= 5
			feedback.append(Locale.t("grade.wrong_plastic_ls") % [sm.typed_plastic_count, str(actual_plastic)])
		if sm.typed_magnum_count != "" and int(sm.typed_magnum_count) != actual_magnum:
			score -= 5
			feedback.append(Locale.t("grade.wrong_magnum_ls") % [sm.typed_magnum_count, str(actual_magnum)])

	if sm.paperwork_cmr_opened:
		var cmr_source: Array = sm.inventory_loaded
		if sm.is_co_load:
			cmr_source = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 1)
		var cmr_actual_uats: int = cmr_source.size()
		var cmr_actual_collis: int = 0
		var cmr_actual_eur: int = 0
		var cmr_actual_plastic: int = 0
		var cmr_actual_magnum: int = 0
		var cmr_actual_cc: int = 0
		for cmr_p: Dictionary in cmr_source:
			cmr_actual_collis += cmr_p.get("collis", 0)
			var cmr_base: String = cmr_p.get("pallet_base", "euro")
			if cmr_base == "euro": cmr_actual_eur += 1
			elif cmr_base == "plastic": cmr_actual_plastic += 1
			elif cmr_base == "magnum": cmr_actual_magnum += 1
			if cmr_p.get("type", "") == "C&C": cmr_actual_cc += 1
		if sm.typed_cmr_uats != "" and int(sm.typed_cmr_uats) != cmr_actual_uats:
			score -= 5
			feedback.append(Locale.t("grade.wrong_uat_cmr") % [sm.typed_cmr_uats, str(cmr_actual_uats)])
		if sm.typed_cmr_collis != "" and int(sm.typed_cmr_collis) != cmr_actual_collis:
			score -= 5
			feedback.append(Locale.t("grade.wrong_collis_cmr") % [sm.typed_cmr_collis, str(cmr_actual_collis)])
		if sm.typed_cmr_eur != "" and int(sm.typed_cmr_eur) != cmr_actual_eur:
			score -= 5
			feedback.append(Locale.t("grade.wrong_eur_cmr") % [sm.typed_cmr_eur, str(cmr_actual_eur)])
		if sm.typed_cmr_plastic != "" and int(sm.typed_cmr_plastic) != cmr_actual_plastic:
			score -= 5
			feedback.append(Locale.t("grade.wrong_plastic_cmr") % [sm.typed_cmr_plastic, str(cmr_actual_plastic)])
		if sm.typed_cmr_magnum != "" and int(sm.typed_cmr_magnum) != cmr_actual_magnum:
			score -= 5
			feedback.append(Locale.t("grade.wrong_magnum_cmr") % [sm.typed_cmr_magnum, str(cmr_actual_magnum)])
		if sm.typed_cmr_cc != "" and int(sm.typed_cmr_cc) != cmr_actual_cc:
			score -= 5
			feedback.append(Locale.t("grade.wrong_cc_cmr") % [sm.typed_cmr_cc, str(cmr_actual_cc)])
		if sm.typed_cmr_seal != "" and sm.typed_cmr_seal != sm.seal_number:
			score -= 10
			feedback.append(Locale.t("grade.wrong_seal_cmr") % [sm.typed_cmr_seal, sm.seal_number])
		if sm.typed_cmr_dock != "" and sm.typed_cmr_dock != str(sm.dock_number):
			score -= 5
			feedback.append(Locale.t("grade.wrong_dock_cmr") % [sm.typed_cmr_dock, str(sm.dock_number)])
		if not sm.cmr_franco_selected:
			score -= 5
			feedback.append(Locale.t("grade.franco_not_selected"))
		elif not sm.cmr_franco_correct:
			score -= 10
			feedback.append(Locale.t("grade.franco_wrong"))

	# --- CMR 2 grading (co-loading only) ---
	if sm.is_co_load:
		if not sm.paperwork_cmr2_opened:
			score -= 10
			feedback.append(Locale.t("grade.cmr2_not_opened"))
		else:
			score = _grade_cmr2_fields(sm, score, feedback)

	# --- LS 2 grading (co-loading only) ---
	if sm.is_co_load:
		score = _grade_ls2_fields(sm, score, feedback)

	return {"score": score, "error_count": feedback.size() - fb_before}


static func _grade_cmr2_fields(sm: SessionManager, score: int, feedback: Array) -> int:
	## Grade the second CMR for co-loading (dest 2 pallets).
	var src: Array = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 2)
	var c2_uats: int = src.size()
	var c2_collis: int = 0
	var c2_eur: int = 0
	var c2_plastic: int = 0
	var c2_magnum: int = 0
	var c2_cc: int = 0
	var c2_weight: float = 0.0
	var c2_dm3: int = 0
	for p: Dictionary in src:
		c2_collis += p.get("collis", 0)
		c2_weight += p.get("weight_kg", 0.0)
		c2_dm3 += p.get("dm3", 0)
		var b: String = p.get("pallet_base", "euro")
		if b == "euro": c2_eur += 1
		elif b == "plastic": c2_plastic += 1
		elif b == "magnum": c2_magnum += 1
		if p.get("type", "") == "C&C": c2_cc += 1

	# Expedition
	if sm.typed_cmr2_expedition != "" and sm.typed_cmr2_expedition != sm.expedition_number_2:
		score -= 10
		feedback.append(Locale.t("grade.wrong_expedition_cmr") % [sm.typed_cmr2_expedition, sm.expedition_number_2])
	# Weight
	if sm.typed_cmr2_weight != "":
		var tw: float = sm.typed_cmr2_weight.to_float()
		if c2_weight > 0.0 and absf(tw - c2_weight) > c2_weight * 0.05:
			score -= 10
			feedback.append(Locale.t("grade.wrong_weight_cmr") % [str(int(tw)), str(int(c2_weight))])
	# Volume
	if sm.typed_cmr2_dm3 != "":
		var tv: float = sm.typed_cmr2_dm3.to_float()
		if c2_dm3 > 0 and absf(tv - float(c2_dm3)) > float(c2_dm3) * 0.05:
			score -= 10
			feedback.append(Locale.t("grade.wrong_volume_cmr") % [str(int(tv)), str(c2_dm3)])
	# Counts
	if sm.typed_cmr2_uats != "" and int(sm.typed_cmr2_uats) != c2_uats:
		score -= 5
		feedback.append(Locale.t("grade.wrong_uat_cmr") % [sm.typed_cmr2_uats, str(c2_uats)])
	if sm.typed_cmr2_collis != "" and int(sm.typed_cmr2_collis) != c2_collis:
		score -= 5
		feedback.append(Locale.t("grade.wrong_collis_cmr") % [sm.typed_cmr2_collis, str(c2_collis)])
	if sm.typed_cmr2_eur != "" and int(sm.typed_cmr2_eur) != c2_eur:
		score -= 5
		feedback.append(Locale.t("grade.wrong_eur_cmr") % [sm.typed_cmr2_eur, str(c2_eur)])
	if sm.typed_cmr2_plastic != "" and int(sm.typed_cmr2_plastic) != c2_plastic:
		score -= 5
		feedback.append(Locale.t("grade.wrong_plastic_cmr") % [sm.typed_cmr2_plastic, str(c2_plastic)])
	if sm.typed_cmr2_magnum != "" and int(sm.typed_cmr2_magnum) != c2_magnum:
		score -= 5
		feedback.append(Locale.t("grade.wrong_magnum_cmr") % [sm.typed_cmr2_magnum, str(c2_magnum)])
	if sm.typed_cmr2_cc != "" and int(sm.typed_cmr2_cc) != c2_cc:
		score -= 5
		feedback.append(Locale.t("grade.wrong_cc_cmr") % [sm.typed_cmr2_cc, str(c2_cc)])
	# Seal (against seal_number_2)
	if sm.typed_cmr2_seal != "" and sm.typed_cmr2_seal != sm.seal_number_2:
		score -= 10
		feedback.append(Locale.t("grade.wrong_seal_cmr") % [sm.typed_cmr2_seal, sm.seal_number_2])
	# Dock
	if sm.typed_cmr2_dock != "" and sm.typed_cmr2_dock != str(sm.dock_number):
		score -= 5
		feedback.append(Locale.t("grade.wrong_dock_cmr") % [sm.typed_cmr2_dock, str(sm.dock_number)])
	# Franco
	if not sm.cmr2_franco_selected:
		score -= 5
		feedback.append(Locale.t("grade.franco_not_selected"))
	elif not sm.cmr2_franco_correct:
		score -= 10
		feedback.append(Locale.t("grade.franco_wrong"))
	return score


static func _grade_ls2_fields(sm: SessionManager, score: int, feedback: Array) -> int:
	## Grade the second Loading Sheet for co-loading (dest 2 pallets).
	var src: Array = sm.inventory_loaded.filter(func(p: Dictionary) -> bool: return p.get("dest", 1) == 2)
	# Store code
	if sm.typed_store_code_2 != "" and sm.typed_store_code_2 != sm.store_code_2:
		score -= 10
		feedback.append(Locale.t("grade.wrong_store_code") % [sm.typed_store_code_2, sm.store_code_2])
	# Seal
	if sm.typed_seal_2 != "" and sm.typed_seal_2 != sm.seal_number_2:
		score -= 10
		feedback.append(Locale.t("grade.wrong_seal_ls") % [sm.typed_seal_2, sm.seal_number_2])
	# Dock (co-loading shares dock)
	if sm.typed_dock_2 != "" and sm.typed_dock_2 != str(sm.dock_number):
		score -= 5
		feedback.append(Locale.t("grade.wrong_dock_ls") % [sm.typed_dock_2, str(sm.dock_number)])
	# Expedition
	if sm.typed_expedition_ls_2 != "" and sm.typed_expedition_ls_2 != sm.expedition_number_2:
		score -= 10
		feedback.append(Locale.t("grade.wrong_expedition_ls") % [sm.typed_expedition_ls_2, sm.expedition_number_2])
	# Counts
	var ls2_uats: int = src.size()
	var ls2_collis: int = 0
	var ls2_eur: int = 0
	var ls2_plastic: int = 0
	var ls2_magnum: int = 0
	for p: Dictionary in src:
		ls2_collis += p.get("collis", 0)
		var b: String = p.get("pallet_base", "euro")
		if b == "euro": ls2_eur += 1
		elif b == "plastic": ls2_plastic += 1
		elif b == "magnum": ls2_magnum += 1
	if sm.typed_uat_count_2 != "" and int(sm.typed_uat_count_2) != ls2_uats:
		score -= 5
		feedback.append(Locale.t("grade.wrong_uat_ls") % [sm.typed_uat_count_2, str(ls2_uats)])
	if sm.typed_collis_count_2 != "" and int(sm.typed_collis_count_2) != ls2_collis:
		score -= 5
		feedback.append(Locale.t("grade.wrong_collis_ls") % [sm.typed_collis_count_2, str(ls2_collis)])
	if sm.typed_eur_count_2 != "" and int(sm.typed_eur_count_2) != ls2_eur:
		score -= 5
		feedback.append(Locale.t("grade.wrong_eur_ls") % [sm.typed_eur_count_2, str(ls2_eur)])
	if sm.typed_plastic_count_2 != "" and int(sm.typed_plastic_count_2) != ls2_plastic:
		score -= 5
		feedback.append(Locale.t("grade.wrong_plastic_ls") % [sm.typed_plastic_count_2, str(ls2_plastic)])
	if sm.typed_magnum_count_2 != "" and int(sm.typed_magnum_count_2) != ls2_magnum:
		score -= 5
		feedback.append(Locale.t("grade.wrong_magnum_ls") % [sm.typed_magnum_count_2, str(ls2_magnum)])
	return score


static func _build_payload(sm: SessionManager, score: int, passed: bool, critical_fail: bool, feedback: Array, penalized_unloads: int, left_behind_cc: int, left_behind_cc_uncalled: int, left_behind_priority: int, had_transit_items: bool, mistakes: Dictionary) -> Dictionary:
	var what_happened: String = ""
	@warning_ignore("integer_division")
	var mins: int = int(sm.total_time) / 60
	var secs: int = int(sm.total_time) % 60
	var time_str: String = "%02d:%02d" % [mins, secs]
	what_happened += Locale.t("grade.shift_duration") % [time_str]

	if feedback.size() > 0:
		what_happened += Locale.t("grade.story_title")
		for f: String in feedback:
			what_happened += f + "\n\n"
	else:
		what_happened += Locale.t("grade.clean_shift")

	if passed:
		what_happened += Locale.t("grade.passed")
	else:
		what_happened += Locale.t("grade.failed")

	var why_it_mattered: String = ""
	if score < 100 or critical_fail:
		why_it_mattered += Locale.t("grade.conditions_title")
		why_it_mattered += Locale.t("grade.conditions_truck") % [str(int(sm.capacity_used)), str(int(sm.capacity_max))]
		why_it_mattered += Locale.t("grade.conditions_pallets") % [str(sm.inventory_loaded.size()), str(sm.inventory_available.size())]
		if sm._waves_delivered > 0:
			why_it_mattered += Locale.t("grade.conditions_waves") % [str(sm._waves_delivered)]
		if sm.raq_viewed_dests.size() > 0:
			why_it_mattered += Locale.t("grade.conditions_raq_checked")
		else:
			why_it_mattered += Locale.t("grade.conditions_raq_not_checked")
		if sm.combine_count > 0:
			why_it_mattered += Locale.t("grade.conditions_combines") % [str(sm.combine_count)]
		why_it_mattered += "\n"
		if sm._waves_delivered > 0 and (penalized_unloads > 0 or left_behind_priority > 0):
			why_it_mattered += Locale.t("grade.conditions_pressure")
		if sm.raq_viewed_dests.size() == 0 and (left_behind_cc > 0 or left_behind_cc_uncalled > 0 or had_transit_items):
			why_it_mattered += Locale.t("grade.conditions_raq_miss")
	else:
		why_it_mattered = Locale.t("grade.conditions_sop_followed")

	if sm.combine_count > 0:
		what_happened += Locale.t("grade.combine_summary") % [str(sm.combine_count)]

	var total_weight_kg: float = 0.0
	var total_dm3: int = 0
	for p: Dictionary in sm.inventory_loaded:
		total_weight_kg += p.get("weight_kg", 0.0)
		total_dm3 += p.get("dm3", 0)

	# Build lightweight load-order snapshots for debrief comparison (Item 20)
	var loaded_order: Array = []
	for p: Dictionary in sm.inventory_loaded:
		loaded_order.append({"type": str(p.get("type", "")), "dest": int(p.get("dest", 1))})
	var ideal_order: Array = sm.inventory_loaded.duplicate(true)
	ideal_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_load_rank(a) < get_load_rank(b)
	)
	var ideal_slim: Array = []
	for p: Dictionary in ideal_order:
		ideal_slim.append({"type": str(p.get("type", "")), "dest": int(p.get("dest", 1))})

	return {
		"what_happened": what_happened,
		"why_it_mattered": why_it_mattered,
		"passed": passed,
		"critical_fail": critical_fail,
		"score": score,
		"total_weight_kg": total_weight_kg,
		"total_dm3": total_dm3,
		"combine_count": sm.combine_count,
		"mistakes": mistakes,
		"action_log": sm._action_log.duplicate(),
		"loaded_order": loaded_order,
		"ideal_order": ideal_slim,
		"time_breakdown": sm._time_breakdown.duplicate(),
	}
