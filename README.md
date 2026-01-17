# WOTS Bay B2B Alpha

Bay B2B Alpha is the first module for the **Warehouse Operations & Training Simulator (WOTS)**. It focuses on the Bay B2B loading area and provides a training environment with simulated roles, events, scoring, and feedback.

## Features

- **SimClock & Event Queue:** A custom time system that drives events relative to simulation time.
- **Rule Engine & Waste Tracking:** Rules are identified by IDs; waste events are recorded and attributed.
- **Scenario Loader:** Loads scenario seeds and schedules events into the session.
- **Domain Models:** Includes SorterModel and LoadingModel for dock availability and sorter downtime.
- **Role Management & Zero‑Score Mode:** Assign roles (Operator, Captain, Trainer) with capability locking; enable zero‑score mode for practice sessions.
- **Scoring Engine & Run Board:** Scores sessions, assigns points per rule, and records runs in `user://run_board.json` (auto‑cleans after 30 days).
- **Feedback Layer:** A UI overlay that logs rule events, distinguishes waste vs. good events, and optionally explains why waste occurred.
- **Debug Overlay:** Enabled only in debug builds for quick logging.

## Setup & Running

1. **Requirements:** Godot v4.5.1 (or later minor release).
2. Clone or download this repository and open the project in Godot.
3. Ensure `scenes/Main.tscn` is set as the main scene (Project Settings → Application → Run).
4. Press **F5** (Play) to start. The session will begin automatically, and the feedback overlay will show event logs.
5. To view or reset the run board, inspect the file at `user://run_board.json` (created after the first completed session).

## Development Notes

- Scripts live in the `core/` folder; scenes in `scenes/`; UI in `ui/`.
- Modify or extend scenarios in `core/scenarios/ScenarioLoader.gd`.
- Additional rules can be registered in `core/rules/RuleEngine.gd`.
- Debug overlay appears only in debug builds (`OS.is_debug_build()`).

## License

This project is provided for internal training purposes only and is not licensed for external distribution.
