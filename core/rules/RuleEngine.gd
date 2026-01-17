extends Node
class_name RuleEngine

# Manages rules, evaluates events, and tracks waste occurrences.

# Dictionary mapping rule IDs to handler callables.
var rules: Dictionary = {}
# Array storing waste events with timestamp, rule_id, and payload.
var waste_log: Array = []

func _ready() -> void:
	# Register default rules. Expand per locked roadmap.
	register_rule(1, Callable(self, "_rule_emplacement_time_over"))
	register_rule(2, Callable(self, "_rule_missing_scan"))

func register_rule(rule_id: int, handler: Callable) -> void:
	rules[rule_id] = handler

func evaluate_event(rule_id: int, payload: Dictionary, current_time: float) -> void:
	# Invoke the handler for the given rule ID. If the handler returns true, record waste.
	if rules.has(rule_id):
		var handler: Callable = rules[rule_id]
		var produces_waste: bool = handler.call(payload)
		if produces_waste:
			waste_log.append({
				"timestamp": current_time,
				"rule_id": rule_id,
				"payload": payload
			})

func get_waste_timeline() -> Array:
	return waste_log

# -------------------------------------------------------------------
# Example rule handlers. Replace/expand these with real logic later.
# Each handler returns true if it produces waste, false otherwise.

func _rule_emplacement_time_over(payload: Dictionary) -> bool:
	# Example: always produces waste
	WOTSLogger.log_info("Rule 1: emplacement time exceeded.")
	return true

func _rule_missing_scan(payload: Dictionary) -> bool:
	# Example: triggers but does not produce waste
	WOTSLogger.log_info("Rule 2: missing scan detected.")
	return false
