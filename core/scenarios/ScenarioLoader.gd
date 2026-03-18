extends Node
class_name ScenarioLoader

var scenarios: Dictionary = {
	"Standard Loading": {
		"description": "Standard loading workflow. Quick load pallets to fit exactly 36 capacity. No tricky priority dates.",
		"scaffold_tier": 1,
		"scaffold_source": "scenario"
	},
	"Promise Loading": {
		"description": "Priority Trap! You have more pallets than the truck can hold. Check promise dates (D-, D, D+) carefully.",
		"scaffold_tier": 1,
		"scaffold_source": "scenario"
	}
}

func get_scenario_names() -> Array[String]:
	var names: Array[String] = []
	for k in scenarios.keys(): names.append(str(k))
	names.sort()
	return names

func get_scenario_description(scenario_name: String) -> String:
	if not scenarios.has(scenario_name): return ""
	return str(scenarios[scenario_name].get("description", ""))

func load_scenario(scenario_name: String, session, _rule_engine) -> void:
	if not scenarios.has(scenario_name): return
	var scenario_data: Dictionary = scenarios[scenario_name]

	session.set_scaffolding(str(scenario_data.get("scaffold_source", "scenario")), int(scenario_data.get("scaffold_tier", 1)))
	session.set_assignment("Bay B2B — " + scenario_name)
	session.set_responsibility_window(true)
	# The auto-end timer is officially dead! The scenario only ends when you Seal the Truck.
