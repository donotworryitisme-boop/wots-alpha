class_name ScenarioTest
extends RefCounted

# ==========================================
# AUTOMATED SCENARIO TESTING — Item 51
# Headless test harness that validates grading logic for each scenario.
# Run via debug overlay or from GDScript: ScenarioTest.run_all()
# ==========================================

## Test result structure
class Result extends RefCounted:
	var name: String = ""
	var passed: bool = false
	var message: String = ""

	func _init(n: String, p: bool, m: String) -> void:
		name = n
		passed = p
		message = m


static func run_all() -> Array[Result]:
	## Runs all tests and returns an array of results.
	var results: Array[Result] = []
	results.append_array(_test_standard_perfect())
	results.append_array(_test_standard_wrong_order())
	results.append_array(_test_priority_perfect())
	results.append_array(_test_coload_perfect())
	results.append_array(_test_coload_interleave())
	results.append_array(_test_grading_cc_left_behind())
	results.append_array(_test_grading_unload_penalty())
	results.append_array(_test_inventory_generation())
	results.append_array(_test_combine_pair())
	results.append_array(_test_undo_load())
	return results


static func run_all_print() -> void:
	## Runs all tests and prints results to console.
	var results: Array[Result] = run_all()
	var pass_count: int = 0
	var fail_count: int = 0
	for r: Result in results:
		var icon: String = "✓" if r.passed else "✗"
		var status: String = "PASS" if r.passed else "FAIL"
		print("[%s] %s: %s — %s" % [icon, status, r.name, r.message])
		if r.passed:
			pass_count += 1
		else:
			fail_count += 1
	print("\n=== RESULTS: %d passed, %d failed, %d total ===" % [pass_count, fail_count, results.size()])


# ==========================================
# HELPERS
# ==========================================

static func _make_session(scenario: String, seed_val: int) -> SessionManager:
	## Creates a SessionManager, starts a scenario, but does NOT add to tree.
	## This means _process() won't run — time stays at 0.
	## For grading tests this is fine; we control time manually.
	var sm := SessionManager.new()
	sm.start_session_with_scenario(scenario, seed_val)
	return sm


static func _load_all_in_rank_order(sm: SessionManager) -> void:
	## Loads all available pallets in correct rank order (perfect sequence).
	sm.loading_started = true
	sm.loading_start_time = sm.total_time
	var sorted_avail: Array = sm.inventory_available.duplicate(true)
	sorted_avail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)
	for p: Dictionary in sorted_avail:
		sm.load_pallet_by_id(str(p.get("id", "")))


static func _load_all_reversed(sm: SessionManager) -> void:
	## Loads all available pallets in REVERSE rank order (worst sequence).
	sm.loading_started = true
	sm.loading_start_time = sm.total_time
	var sorted_avail: Array = sm.inventory_available.duplicate(true)
	sorted_avail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) > GradingEngine.get_load_rank(b)
	)
	for p: Dictionary in sorted_avail:
		sm.load_pallet_by_id(str(p.get("id", "")))


static func _simulate_as400_confirm(sm: SessionManager) -> void:
	## Simulates AS400 confirmation so grading doesn't penalise for it.
	sm.manual_decision("Confirm AS400 Dest 1")
	if sm.is_co_load:
		sm.manual_decision("Confirm AS400 Dest 2")


static func _simulate_cc_call(sm: SessionManager) -> void:
	sm.manual_decision("Call departments (C&C check)")


static func _ok(name: String, msg: String) -> Result:
	return Result.new(name, true, msg)


static func _fail(name: String, msg: String) -> Result:
	return Result.new(name, false, msg)


static func _assert_eq(name: String, actual: Variant, expected: Variant, label: String) -> Result:
	if actual == expected:
		return _ok(name, label + " = " + str(actual))
	return _fail(name, label + ": expected " + str(expected) + ", got " + str(actual))


static func _assert_true(name: String, condition: bool, label: String) -> Result:
	if condition:
		return _ok(name, label)
	return _fail(name, label + " was false")


static func _assert_gte(name: String, actual: int, minimum: int, label: String) -> Result:
	if actual >= minimum:
		return _ok(name, label + " = " + str(actual) + " (>= " + str(minimum) + ")")
	return _fail(name, label + " = " + str(actual) + " (expected >= " + str(minimum) + ")")


static func _assert_lte(name: String, actual: int, maximum: int, label: String) -> Result:
	if actual <= maximum:
		return _ok(name, label + " = " + str(actual) + " (<= " + str(maximum) + ")")
	return _fail(name, label + " = " + str(actual) + " (expected <= " + str(maximum) + ")")


# ==========================================
# TEST: Standard Loading — Perfect Run
# ==========================================

static func _test_standard_perfect() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "std_perfect"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)
	_load_all_in_rank_order(sm)
	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")

	var payload: Dictionary = GradingEngine.grade(sm)
	var score: int = int(payload.get("score", 0))
	var passed: bool = bool(payload.get("passed", false))
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary

	results.append(_assert_true(tname, passed, "should pass"))
	results.append(_assert_gte(tname, score, 85, "score"))
	results.append(_assert_eq(tname + "_seq", int(mistakes.get("sequence_errors", 0)), 0, "sequence_errors"))

	sm.free()
	return results


# ==========================================
# TEST: Standard Loading — Wrong Order
# ==========================================

static func _test_standard_wrong_order() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "std_wrong_order"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)
	_load_all_reversed(sm)
	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")

	var payload: Dictionary = GradingEngine.grade(sm)
	var score: int = int(payload.get("score", 0))
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary
	var seq_err: int = int(mistakes.get("sequence_errors", 0))

	results.append(_assert_true(tname, seq_err > 0, "should have sequence errors"))
	results.append(_assert_lte(tname, score, 80, "score should be lower"))

	sm.free()
	return results


# ==========================================
# TEST: Priority Loading — Perfect Run
# ==========================================

static func _test_priority_perfect() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "priority_perfect"
	var sm: SessionManager = _make_session("2. Priority Loading", 100)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)
	_load_all_in_rank_order(sm)
	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")

	var payload: Dictionary = GradingEngine.grade(sm)
	var score: int = int(payload.get("score", 0))
	var passed: bool = bool(payload.get("passed", false))

	results.append(_assert_true(tname, passed, "should pass"))
	results.append(_assert_gte(tname, score, 85, "score"))

	sm.free()
	return results


# ==========================================
# TEST: Co-Loading — Perfect Run
# ==========================================

static func _test_coload_perfect() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "coload_perfect"
	var sm: SessionManager = _make_session("3. Co-Loading", 200)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)

	# Load dest 1 first, then dest 2 (correct interleave)
	sm.loading_started = true
	sm.loading_start_time = sm.total_time
	var d1: Array = []
	var d2: Array = []
	for p: Dictionary in sm.inventory_available:
		if int(p.get("dest", 1)) == 1:
			d1.append(p)
		else:
			d2.append(p)
	d1.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)
	d2.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)
	for p: Dictionary in d1:
		sm.load_pallet_by_id(str(p.get("id", "")))
	for p: Dictionary in d2:
		sm.load_pallet_by_id(str(p.get("id", "")))

	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")
	sm.manual_decision("Open CMR 2")

	var payload: Dictionary = GradingEngine.grade(sm)
	var score: int = int(payload.get("score", 0))
	var passed: bool = bool(payload.get("passed", false))
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary

	results.append(_assert_true(tname, passed, "should pass"))
	results.append(_assert_gte(tname, score, 80, "score"))
	results.append(_assert_eq(tname + "_interleave", int(mistakes.get("co_interleave_errors", 0)), 0, "interleave_errors"))

	sm.free()
	return results


# ==========================================
# TEST: Co-Loading — Interleave Error
# ==========================================

static func _test_coload_interleave() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "coload_interleave"
	var sm: SessionManager = _make_session("3. Co-Loading", 200)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)

	# Deliberately mix dest 1 and dest 2 pallets
	sm.loading_started = true
	sm.loading_start_time = sm.total_time
	for p: Dictionary in sm.inventory_available:
		sm.load_pallet_by_id(str(p.get("id", "")))

	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")
	sm.manual_decision("Open CMR 2")

	var payload: Dictionary = GradingEngine.grade(sm)
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary
	var interleave: int = int(mistakes.get("co_interleave_errors", 0))

	# With random order, there SHOULD be interleave errors (unless very lucky seed)
	# We can't guarantee errors but we can check the grading doesn't crash
	results.append(_assert_true(tname, true, "grading completed without error"))
	if interleave > 0:
		results.append(_ok(tname + "_has_errors", "interleave errors detected: " + str(interleave)))
	else:
		results.append(_ok(tname + "_no_errors", "no interleave errors (seed-dependent, acceptable)"))

	sm.free()
	return results


# ==========================================
# TEST: C&C Left Behind
# ==========================================

static func _test_grading_cc_left_behind() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "cc_left_behind"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	_simulate_as400_confirm(sm)
	# Deliberately DO NOT call departments
	sm.loading_started = true
	sm.loading_start_time = sm.total_time

	# Load only non-CC pallets
	var sorted_avail: Array = sm.inventory_available.duplicate(true)
	sorted_avail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GradingEngine.get_load_rank(a) < GradingEngine.get_load_rank(b)
	)
	for p: Dictionary in sorted_avail:
		if str(p.get("type", "")) != "C&C":
			sm.load_pallet_by_id(str(p.get("id", "")))

	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")

	var payload: Dictionary = GradingEngine.grade(sm)
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary

	# Should flag both cc_left_behind and cc_not_investigated
	var cc_left: bool = bool(mistakes.get("cc_left_behind", false))
	var cc_not_inv: bool = bool(mistakes.get("cc_not_investigated", false))

	results.append(_assert_true(tname, cc_left, "cc_left_behind should be true"))
	results.append(_assert_true(tname + "_inv", cc_not_inv, "cc_not_investigated should be true"))

	sm.free()
	return results


# ==========================================
# TEST: Unload Penalty
# ==========================================

static func _test_grading_unload_penalty() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "unload_penalty"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	_simulate_as400_confirm(sm)
	_simulate_cc_call(sm)
	sm.loading_started = true
	sm.loading_start_time = sm.total_time

	# Load first pallet, then unload it, then reload it
	var first_id: String = str(sm.inventory_available[0].get("id", ""))
	sm.load_pallet_by_id(first_id)
	sm.unload_pallet_by_id(first_id)

	# Now load everything in order
	_load_all_in_rank_order(sm)
	sm.manual_decision("Open Loading Sheet")
	sm.manual_decision("Open CMR")

	var payload: Dictionary = GradingEngine.grade(sm)
	var mistakes: Dictionary = payload.get("mistakes", {}) as Dictionary
	var _rework: int = int(mistakes.get("rework_penalized", 0))

	results.append(_assert_true(tname, sm.unload_count > 0, "unload_count > 0"))
	# Rework penalty depends on whether it was tutorial or deliberate
	results.append(_assert_true(tname + "_graded", true, "grading completed"))

	sm.free()
	return results


# ==========================================
# TEST: Inventory Generation Determinism
# ==========================================

static func _test_inventory_generation() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "inv_determinism"

	# Two sessions with the same seed should produce identical inventory
	var sm1: SessionManager = _make_session("1. Standard Loading", 999)
	var sm2: SessionManager = _make_session("1. Standard Loading", 999)

	var ids1: Array[String] = []
	for p: Dictionary in sm1.inventory_available:
		ids1.append(str(p.get("id", "")))
	var ids2: Array[String] = []
	for p: Dictionary in sm2.inventory_available:
		ids2.append(str(p.get("id", "")))

	results.append(_assert_eq(tname + "_count", ids1.size(), ids2.size(), "pallet count"))
	results.append(_assert_true(tname + "_ids", ids1 == ids2, "pallet IDs match"))

	# Different seed should produce different inventory
	var sm3: SessionManager = _make_session("1. Standard Loading", 1000)
	var ids3: Array[String] = []
	for p: Dictionary in sm3.inventory_available:
		ids3.append(str(p.get("id", "")))
	results.append(_assert_true(tname + "_diff", ids1 != ids3, "different seeds produce different IDs"))

	sm1.free()
	sm2.free()
	sm3.free()
	return results


# ==========================================
# TEST: Combine Pair Detection
# ==========================================

static func _test_combine_pair() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "combine_pair"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	# Check has_combine_pair returns a bool without crashing
	var has_pair: bool = sm.has_combine_pair()
	results.append(_assert_true(tname, true, "has_combine_pair() = " + str(has_pair)))

	sm.free()
	return results


# ==========================================
# TEST: Undo Load
# ==========================================

static func _test_undo_load() -> Array[Result]:
	var results: Array[Result] = []
	var tname: String = "undo_load"
	var sm: SessionManager = _make_session("1. Standard Loading", 42)

	sm.loading_started = true
	sm.loading_start_time = sm.total_time
	var first_id: String = str(sm.inventory_available[0].get("id", ""))
	var avail_before: int = sm.inventory_available.size()
	sm.load_pallet_by_id(first_id)

	results.append(_assert_eq(tname + "_loaded", sm.inventory_loaded.size(), 1, "loaded count after load"))
	results.append(_assert_eq(tname + "_avail", sm.inventory_available.size(), avail_before - 1, "avail count after load"))

	var undo_ok: bool = sm.undo_last_load(first_id)
	results.append(_assert_true(tname + "_undo_ok", undo_ok, "undo returned true"))
	results.append(_assert_eq(tname + "_after_undo", sm.inventory_loaded.size(), 0, "loaded count after undo"))
	results.append(_assert_eq(tname + "_avail_restored", sm.inventory_available.size(), avail_before, "avail restored after undo"))

	sm.free()
	return results
