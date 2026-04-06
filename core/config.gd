extends Node
class_name WOTSConfig

# -------------------------------------------------------------------
# Single config file for constants used across Bay B2B Alpha.
# Keep this file limited to enums + constants only.
# -------------------------------------------------------------------

# Roles (expand only if already approved in locked roadmap/council decisions)
# NOTE: CAPTAIN role removed — no captain training content planned.
# TRAINER value kept at 2 for backward compatibility with existing accounts.
enum Role {
	OPERATOR = 0,
	TRAINER = 2
}

# NOTE: Difficulty scaling is a future feature (Roadmap item 30).
# Do not add difficulty constants until that feature is implemented.
