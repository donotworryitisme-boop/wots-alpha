class_name ScenarioConfig
extends RefCounted

## Defines scenario parameters as data-driven configs.
## Replaces hardcoded values in InventoryManager.generate_inventory().
## Supports adaptive difficulty by reading TrainingRecord history.

# --- Difficulty tiers ---
enum Tier { EASY, NORMAL, HARD }


static func get_config(scenario_name: String) -> Dictionary:
	## Returns the base configuration dictionary for a given scenario.
	## Call apply_adaptive() on the result to adjust for player performance.
	if scenario_name == "0. Tutorial":
		return _tutorial_config()
	elif scenario_name == "1. Standard Loading" or scenario_name == "4. Free Play":
		return _standard_config()
	elif scenario_name == "2. Priority Loading":
		return _priority_config()
	elif scenario_name == "3. Co-Loading":
		return _co_loading_config()
	return _standard_config()


static func apply_adaptive(config: Dictionary, scenario_name: String) -> Dictionary:
	## Reads TrainingRecord for the last 3 scores of this scenario.
	## Adjusts config parameters based on average performance.
	## Free Play (4) and Tutorial (0) skip adaptive adjustments.
	if scenario_name == "0. Tutorial" or scenario_name == "4. Free Play":
		return config

	var recent: Array[Dictionary] = TrainingRecord.get_scenario_history(scenario_name, 3)
	if recent.size() < 3:
		return config

	var total_score: int = 0
	for r: Dictionary in recent:
		total_score += int(r.get("score", 0))
	@warning_ignore("integer_division")
	var avg: int = total_score / recent.size()

	var tier: Tier = Tier.NORMAL
	if avg >= 90:
		tier = Tier.HARD
	elif avg < 70:
		tier = Tier.EASY

	if tier == Tier.NORMAL:
		return config

	var adjusted: Dictionary = config.duplicate(true)

	if tier == Tier.HARD:
		# More challenge: extra pallets, more waves, higher transit/ADR chance
		adjusted.mecha_count = int(adjusted.mecha_count) + 3
		adjusted.wave_count_min = int(adjusted.wave_count_min) + 1
		adjusted.wave_count_max = int(adjusted.wave_count_max) + 1
		adjusted.transit_probability = minf(float(adjusted.transit_probability) + 0.25, 0.80)
		adjusted.adr_probability = minf(float(adjusted.adr_probability) + 0.20, 0.75)
		adjusted.emballage_fractions = [0.25, 0.33, 0.40]
		adjusted.difficulty_label = "hard"
	elif tier == Tier.EASY:
		# Less challenge: fewer pallets, no waves, no transit/ADR, no emballage
		adjusted.mecha_count = maxi(int(adjusted.mecha_count) - 4, 4)
		adjusted.bulky_count = maxi(int(adjusted.bulky_count) - 3, 3)
		adjusted.wave_count_min = 0
		adjusted.wave_count_max = 0
		adjusted.transit_probability = 0.0
		adjusted.adr_probability = 0.0
		adjusted.emballage_fractions = []
		adjusted.difficulty_label = "easy"

	return adjusted


# ==========================================
# BASE CONFIGURATIONS
# ==========================================

static func _tutorial_config() -> Dictionary:
	return {
		"bikes_count": 2,
		"bulky_count": 10,
		"mecha_count": 16,
		"cc_count_min": 2,
		"cc_count_max": 4,
		"cc_force_missing_idx": 0,
		"use_random_promise": false,
		"wave_count_min": 0,
		"wave_count_max": 0,
		"wave_pool": [] as Array[String],
		"wave_batch_count_min": 0,
		"wave_batch_count_max": 0,
		"wave_times": [] as Array[float],
		"transit_probability": 0.0,
		"adr_probability": 0.0,
		"emballage_fractions": [] as Array[float],
		"emballage_thresholds": [] as Array[float],
		"is_co_load": false,
		"difficulty_label": "tutorial",
	}


static func _standard_config() -> Dictionary:
	return {
		"bikes_count": 2,
		"bulky_count": 10,
		"mecha_count": 12,
		"cc_count_min": 2,
		"cc_count_max": 4,
		"cc_force_missing_idx": -1,
		"use_random_promise": false,
		"wave_count_min": 2,
		"wave_count_max": 3,
		"wave_pool": ["Mecha", "Mecha", "Bulky", "Bikes"] as Array[String],
		"wave_batch_count_min": 1,
		"wave_batch_count_max": 2,
		"wave_times": [400.0, 700.0, 1000.0] as Array[float],
		"transit_probability": 0.35,
		"adr_probability": 0.40,
		"emballage_fractions": [0.20, 0.25, 0.33] as Array[float],
		"emballage_thresholds": [0.20, 0.55] as Array[float],
		"is_co_load": false,
		"difficulty_label": "normal",
	}


static func _priority_config() -> Dictionary:
	return {
		"bikes_count": 2,
		"bulky_count": 15,
		"mecha_count": 20,
		"cc_count_min": 2,
		"cc_count_max": 4,
		"cc_force_missing_idx": -1,
		"use_random_promise": true,
		"wave_count_min": 5,
		"wave_count_max": 5,
		"wave_pool": ["Mecha", "Mecha", "Bikes", "Bulky", "Mecha"] as Array[String],
		"wave_batch_count_min": 2,
		"wave_batch_count_max": 2,
		"wave_times": [550.0, 850.0, 1100.0] as Array[float],
		"wave_promise": "D-",
		"transit_probability": 0.35,
		"adr_probability": 0.40,
		"emballage_fractions": [0.20, 0.25, 0.33] as Array[float],
		"emballage_thresholds": [0.20, 0.55] as Array[float],
		"is_co_load": false,
		"difficulty_label": "normal",
	}


static func _co_loading_config() -> Dictionary:
	return {
		# Store 1 (dest=1, deeper in truck)
		"s1_bikes_count": 1,
		"s1_bulky_count": 5,
		"s1_mecha_count": 8,
		"s1_cc_count": 2,
		# Store 2 (dest=2, near doors)
		"s2_bikes_count": 1,
		"s2_bulky_count": 4,
		"s2_mecha_count": 5,
		"s2_cc_count": 2,
		# Shared settings
		"cc_count_min": 2,
		"cc_count_max": 4,
		"cc_force_missing_idx": -1,
		"use_random_promise": true,
		"wave_count_min": 1,
		"wave_count_max": 3,
		"wave_pool": ["Mecha", "Bulky", "Bikes", "Mecha"] as Array[String],
		"wave_batch_count_min": 1,
		"wave_batch_count_max": 1,
		"wave_times": [450.0, 700.0, 950.0] as Array[float],
		"transit_probability": 0.35,
		"adr_probability": 0.40,
		"emballage_fractions": [0.20, 0.25, 0.33] as Array[float],
		"emballage_thresholds": [0.20, 0.55] as Array[float],
		"is_co_load": true,
		"difficulty_label": "normal",
	}
