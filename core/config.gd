extends Node
class_name WOTSConfig

# -------------------------------------------------------------------
# Single config file for constants used across Bay B2B Alpha.
# Keep this file limited to enums + constants only.
# -------------------------------------------------------------------

# Roles (expand only if already approved in locked roadmap/council decisions)
enum Role {
	OPERATOR = 0,
	CAPTAIN = 1,
	TRAINER = 2
}

# Difficulty levels (expand only if already approved in locked roadmap/council decisions)
enum Difficulty {
	EASY = 0,
	NORMAL = 1,
	HARD = 2
}

# Time limits (seconds) — adjust values only per locked roadmap
const SESSION_TIME_LIMIT_SECONDS_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY: 15 * 60,
	Difficulty.NORMAL: 10 * 60,
	Difficulty.HARD: 7 * 60
}

# Generic, shared constants (safe defaults)
const TARGET_FPS: int = 60
const FIXED_TIMESTEP_SECONDS: float = 1.0 / 60.0

