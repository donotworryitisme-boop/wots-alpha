# WOTS — Warehouse Operations Training Simulator

**Bay B2B Alpha** | Godot 4.5 | GDScript | 1920×1080

WOTS is a cognitive and procedural training simulator for warehouse operators. It teaches decision-making under incomplete information — prioritisation, responsibility boundaries, escalation timing, and the consequences of operational mistakes.

WOTS is designed to be anti-blame, anti-surveillance, non-gamified, and safe for trainees. It deliberately allows mistakes so operators can understand *why* things go wrong.

---

## Scenarios

| # | Name | What it trains |
|---|------|----------------|
| 0 | Tutorial | Guided walkthrough of the full loading cycle (24 steps) |
| 1 | Standard Loading | Solo store, basic pallet types, no surprises |
| 2 | Priority Loading | D/D-/D+ priority dates, late-arriving waves, rework decisions |
| 3 | Co-Loading | Two stores on one truck — sequencing and dual paperwork |

---

## Architecture

### Orchestrator

`BayUI.gd` is the central coordinator. It owns all extracted classes and manages workspace switching (DOCK / OFFICE), portal flow, phone notifications, and session lifecycle.

### Extracted Classes (all `extends RefCounted`)

| Class | File | Responsibility |
|-------|------|---------------|
| PaperworkForms | `scripts/PaperworkForms.gd` | Loading Sheet + CMR form building, field validation |
| OfficeManager | `scripts/OfficeManager.gd` | Desk view, item collection, office phases, paperwork tabs |
| LoadingPlanBoard | `scripts/Loadingplanboard.gd` | Shift board table, seal art display |
| AS400Terminal | `scripts/As400terminal.gd` | AS400 terminal state machine (sign-on → scanning → confirmation) |
| DockView | `scripts/DockView.gd` | Dock floor, lanes, truck grid, pallet interaction |
| SOPModal | `scripts/SOPModal.gd` | SOP article viewer with tags and search |
| PortalScreen | `scripts/PortalScreen.gd` | Start screen, scenario selection, language picker |
| TutorialOverlay | `scripts/TutorialOverlay.gd` | Tutorial canvas layer with step labels |
| DebriefScreen | `scripts/DebriefScreen.gd` | End-of-shift debrief modal |

### Core

| File | Responsibility |
|------|---------------|
| `core/session/SessionManager.gd` | Session lifecycle, inventory management, grading, time tracking |
| `data/WarehouseData.gd` | Store addresses, dock assignments, carrier data |
| `core/config.gd` | Role enum, shared constants |
| `ui/ui_tokens.gd` | Centralised color constants, date, spacing |
| `i18n/Locale.gd` | 8-language translation system (EN/NL/FR/DE/ES/PT/PL/TR) |

### Data Flow (loading a pallet)

```
User clicks pallet in DockView
  → BayUI._on_pallet_clicked(id)
    → SessionManager.load_pallet_by_id(id)
      → inventory_available.erase(p), inventory_loaded.append(p)
      → signal: inventory_updated
        → PaperworkForms.update_loading_sheet()
        → PaperworkForms.update_cmr()
        → DockView.populate()
        → AS400Terminal._render_as400_screen()
```

### Transition System

| Transition | Method | Duration |
|------------|--------|----------|
| Portal → Session | `_fade_transition()` | 0.855s full-screen black |
| Session → Debrief | `_fade_transition()` | 0.855s full-screen black |
| DOCK ↔ OFFICE | `crossfade(workspace_vbox)` | 0.3s (0.15s per direction) |
| Desk → Paperwork | `crossfade(office_vbox_ref)` | 0.3s |
| LS ↔ CMR tab | `crossfade(paperwork_panels_ref)` | 0.3s |
| PREP → WRAPUP | `crossfade(office_vbox_ref)` | 0.3s |

---

## Running the Project

1. Open `project.godot` in Godot 4.5
2. Run the project (F5)
3. Accept the Trust Contract → Start Screen → Portal → Select scenario → Play

Export presets exist for Windows and macOS.

---

## Development Rules

1. **800-line max per file** — extract before adding features
2. **Zero warnings** — typed vars, `-> void` lambdas, `_` prefix unused params
3. **Full file delivery** — always send complete files, never partial snippets
4. **Read uploaded code first** — never assume from memory
5. **8-language support** — translation changes propagated across all languages in Locale.gd
