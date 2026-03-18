extends Node
class_name ScenarioLoader

var scenarios: Dictionary = {
	"0. Tutorial": {
		"description": "Guided onboarding. Learn how to open the AS400, scan pallets, and load the truck in the correct sequence.",
		"scaffold_source": "scenario",
		"scaffold_tier": 1
	},
	"1. Standard Loading": {
		"description": "A standard day on the dock. Use the AS400 to verify your UATs and load the truck in the correct sequence.",
		"scaffold_source": "role",
		"scaffold_tier": 2
	},
	"2. Priority Loading": {
		"description": "High volume day. You have more pallets than truck capacity. Pay strict attention to Promise Dates (D, D+, D-).",
		"scaffold_source": "role",
		"scaffold_tier": 3
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
