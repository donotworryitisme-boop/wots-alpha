extends Node
class_name RoleManager

# Manages the active role and checks capabilities based on WOTSConfig.Role.

# Active role (default to OPERATOR)
var current_role: int = WOTSConfig.Role.OPERATOR

# Map roles to capabilities. Extend this dictionary per your roadmap.
var capabilities: Dictionary = {
	WOTSConfig.Role.OPERATOR: ["operate_loading", "use_sorter", "view_logs"],
	WOTSConfig.Role.CAPTAIN:  ["operate_loading", "use_sorter", "view_logs", "manage_scenarios"],
	WOTSConfig.Role.TRAINER:  ["operate_loading", "use_sorter", "view_logs", "manage_scenarios", "trainer_tools"]
}

func set_role(role: int) -> void:
	current_role = role

func get_role() -> int:
	return current_role

func has_capability(capability: String) -> bool:
	if not capabilities.has(current_role):
		return false
	return capabilities[current_role].has(capability)
