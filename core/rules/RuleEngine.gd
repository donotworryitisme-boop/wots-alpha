extends Node
class_name RuleEngine

# Manages rules, evaluates events, and tracks waste occurrences.
#
# Pressure knobs affect decision context (passed into evaluate_event),
# allowing rules to behave differently under time pressure, ambiguity, and interruptions.

var rules: Dictionary = {}
var waste_log: Array = []

func _ready() -> void:
	register_rule(1, Callable(self, "_rule_emplacement_time_over"))
	register_rule(2, Callable(self, "_rule_missing_scan"))

func register_rule(rule_id: int, handler: Callable) -> void:
	rules[rule_id] = handler

func evaluate_event(rule_id: int, payload: Dictionary, decision_context: Dictionary, current_time: float) -> bool:
	var produces_waste: bool = false
	if rules.has(rule_id):
		var handler: Callable = rules[rule_id]

		# Updated contract: handlers accept (payload, decision_context).
		produces_waste = bool(handler.call(payload, decision_context))

		if produces_waste:
			waste_log.append({
				"timestamp": current_time,
				"rule_id": rule_id,
				"payload": payload,
				"decision_context": decision_context
			})
	return produces_waste

func get_waste_timeline() -> Array:
	return waste_log

# -------------------------------------------------------------------
# Example rule handlers (pressure-aware)
# NOTE: These are still scaffolds, but they now react to decision context.

func _rule_emplacement_time_over(payload: Dictionary, ctx: Dictionary) -> bool:
	# Inline behavior:
	# - Under higher time pressure + interruptions, waste becomes more likely.
	# - Under low pressure and no interruptions, allow a "good outcome" sometimes.
	var tp: float = float(ctx.get("time_pressure", 0.0))
	var intr: int = int(ctx.get("interruptions", 0))
	var ambiguous: bool = bool(ctx.get("ambiguous", false))

	# Base chance of waste for this rule scaffold.
	var waste_chance: float = 0.35

	# Pressure increases waste chance.
	waste_chance += tp * 0.45
	waste_chance += min(float(intr) * 0.10, 0.30)
	if ambiguous:
		waste_chance += 0.10

	waste_chance = clamp(waste_chance, 0.0, 0.95)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var produces_waste := rng.randf() < waste_chance

	WOTSLogger.log_info("Rule 1 eval: waste_chance=%0.2f (tp=%0.2f intr=%d amb=%s) payload=%s"
		% [waste_chance, tp, intr, str(ambiguous), str(payload)]
	)

	return produces_waste

func _rule_missing_scan(payload: Dictionary, ctx: Dictionary) -> bool:
	# Inline behavior:
	# - If scan_required is missing due to ambiguity, decision context is degraded.
	# - Interruptions + ambiguity increases chance of missing scan.
	var intr: int = int(ctx.get("interruptions", 0))
	var ambiguous: bool = bool(ctx.get("ambiguous", false))

	# IMPORTANT: payload.get(..., null) returns a Variant (can be null).
	# Use Variant typing to avoid "Variant inferred" warnings treated as errors.
	var scan_required: Variant = payload.get("scan_required", null)

	var waste_chance: float = 0.05
	if scan_required == null:
		# Missing/withheld info increases likelihood of error.
		waste_chance += 0.20
	if ambiguous:
		waste_chance += 0.10
	waste_chance += min(float(intr) * 0.08, 0.24)

	waste_chance = clamp(waste_chance, 0.0, 0.85)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var produces_waste := rng.randf() < waste_chance

	WOTSLogger.log_info("Rule 2 eval: waste_chance=%0.2f (intr=%d amb=%s scan_required=%s) payload=%s"
		% [waste_chance, intr, str(ambiguous), str(scan_required), str(payload)]
	)

	return produces_waste
