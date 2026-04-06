# WOTS CODEBASE MAP
**Last updated:** Session 42 (2026-04-05)
**Read this first.** Then read the latest HANDOFF_S*.md for task context.

---

## FILE → RESPONSIBILITY → KEY PUBLIC API

### Orchestrator
| File | Lines | Does what |
|------|-------|-----------|
| `scripts/BayUI.gd` | ~837 | **ORCHESTRATOR.** Workspace tabs, portal, phone, session flow, fade/crossfade transitions. Owns all extracted classes. |
| → `_paper` | PaperworkForms | LS + CMR forms |
| → `_office` | OfficeManager | Desk, phases, wrapup, tabs |
| → `_lp_board` | LoadingPlanBoard | Shift board table + seal art |
| → `_as400` | AS400Terminal | Terminal state machine |
| → `_dock` | DockView | Dock floor, lanes, truck |
| → `_sop` | SOPModal | SOP articles |
| → `_portal` | PortalScreen | Start screen overlay |
| → `_tut` | TutorialOverlay | Tutorial canvas |
| → `_debrief` | DebriefScreen | End-of-shift modal |

### Extracted Classes (all `extends RefCounted`, receive BayUI via `_init(ui: Node)`)
| File | Lines | Key methods |
|------|-------|-------------|
| `scripts/PaperworkForms.gd` | ~936 | `update_loading_sheet()`, `update_cmr()`, `check_ls_preload_done()`, `clear_paperwork_fields()` |
| `scripts/OfficeManager.gd` | ~562 | `build_workspace()`, `refresh_office_phase_ui()`, `switch_paperwork_tab()`, `advance_wrapup()`, `reset_for_new_session()` |
| `scripts/LoadingPlanBoard.gd` | ~349 | `populate()`, `reset()` |
| `scripts/As400terminal.gd` | ~619 | `_render_as400_screen()`, `_handle_input()`, `_init_tabs()` |
| `scripts/DockView.gd` | ~533 | `populate()`, `rebuild_lanes()`, `close_dock()`, `open_dock()` |
| `scripts/SOPModal.gd` | ~506 | `_open_sop_modal()`, `sop_database` |
| `scripts/PortalScreen.gd` | ~568 | `overlay`, `btn_start`, `scenario_dropdown`, `language_dropdown` |
| `scripts/TutorialOverlay.gd` | ~214 | `update_ui()`, `flash_warning()`, `canvas` |
| `scripts/DebriefScreen.gd` | ~366 | `store_payload()`, `render()`, `overlay` |
| `scripts/WorkspaceController.gd` | ~535 | `switch_workspace()`, `toggle_panel()`, `build_dock_paperwork_overlay()` |
| `scripts/PhoneSystem.gd` | ~268 | `on_notification()`, `on_panel_opened()`, `update_content()` |
| `scripts/InterruptionManager.gd` | ~252 | `setup_for_session()`, `tick()`, `is_blocking()` |
| `scripts/PalletQuiz.gd` | ~334 | `start_quiz()`, `close_quiz()` |
| `scripts/DrillManager.gd` | ~586 | `open_selection()`, `start_drill()`, `tick()` |
| `scripts/GhostReplay.gd` | ~584 | `start_replay()`, `stop_replay()`, `tick()` |
| `scripts/SessionFlow.gd` | ~432 | `on_portal_start_pressed()`, `on_session_ended()`, `populate_scenarios()` |
| `scripts/TutorialController.gd` | ~300 | `try_advance_*()`, `check_panel_gate()` |
| `scripts/LoadingSheetForm.gd` | ~456 | `_refresh_ls_auto_content()`, pallet grids, final counts |

### Core
| File | Lines | Key data |
|------|-------|----------|
| `core/session/SessionManager.gd` | ~472 | `inventory_available[]`, `inventory_loaded[]`, `load_pallet_by_id()`, `TIME_SPEED=1.3`, signals: `inventory_updated`, `time_updated`, `phone_notification` |
| `core/session/InventoryManager.gd` | ~789 | `generate_inventory()`, `load_pallet()`, `check_wave_trigger()`, pallet factories |
| `core/session/GradingEngine.gd` | ~502 | `grade()` static, `_build_payload()`, `_grade_paperwork_fields()` |
| `data/WarehouseData.gd` | ~149 | `get_dock_number()`, `get_carrier()`, `get_store_address()`, store CMR addresses |
| `core/config.gd` | ~32 | `WOTSConfig.Role`, `WOTSConfig.Difficulty` enums |
| `ui/ui_tokens.gd` | ~46 | `UITokens.CLR_*` colors, `LOADING_DATE`, spacing/font constants |

### Localization
| File | Lines | Notes |
|------|-------|-------|
| `i18n/Locale.gd` | ~2856 | 8 languages (EN/NL/FR/DE/ES/PT/PL/TR). `Locale.t("key")` for translations. Pure data — exempt from 800-line rule. |

---

## DATA FLOW (loading a pallet)

```
User clicks pallet in DockView
  → BayUI._on_pallet_clicked(id)
    → SessionManager.load_pallet_by_id(id)
      → inventory_available.erase(p), inventory_loaded.append(p)
      → emit_signal("inventory_updated", avail, loaded, cap_used, cap_max)
        → BayUI._on_inventory_updated()
          → _paper.update_loading_sheet()  ← pallet grid + auto-content refresh
          → _paper.update_cmr()
          → _dock.populate()               ← redraw dock floor
          → _as400._render_as400_screen()  ← if on scanning screen
```

## TRANSITION SYSTEM

| Transition | Method | Target |
|------------|--------|--------|
| Portal → Session | `_fade_transition()` | Full-screen black (0.855s) |
| Session → Debrief | `_fade_transition()` | Full-screen black |
| DOCK ↔ OFFICE | `crossfade(workspace_vbox)` | Quick 0.15s per direction |
| Desk → Paperwork | `crossfade(office_vbox_ref)` | Quick 0.15s per direction |
| LS ↔ CMR tab | `crossfade(paperwork_panels_ref)` | Quick 0.15s per direction |
| PREP → WRAPUP | `crossfade(office_vbox_ref)` | Quick 0.15s per direction |

## TUTORIAL STEPS (0-23)

| Step | What happens | Advance trigger |
|------|-------------|-----------------|
| 0 | Welcome screen (dock hidden) | Switch to OFFICE |
| 1 | Collect desk items | All 3 collected |
| 2 | Fill LS pre-load fields | Store+Seal+Dock filled |
| 3 | Switch to dock | Switch to DOCK |
| 4-8 | AS400 login flow | AS400 state machine |
| 9 | Call departments | Click Call Departments |
| 10 | Start loading | Click Start Loading |
| 11 | Load Mecha (deliberate mistake) | Mecha loaded |
| 12 | Unload Mecha | Mecha unloaded |
| 13 | Load Service Center | SC loaded |
| 14 | Load Bikes | Bikes loaded |
| 15 | Load all remaining | avail empty |
| 16 | Switch to LS tab | Click LS tab |
| 17 | Review LS | (manual advance) |
| 18 | Switch to CMR tab | Click CMR tab |
| 19 | Switch to dock | Switch to DOCK |
| 20 | Close dock | Click Close Dock |
| 21 | Hand CMR | Click Hand CMR |
| 22 | Archive | Click Archive → LS/CMR panels hide |
| 23 | Seal truck | Click Seal Truck → seal btn hides → session ends |

## ARCHITECTURE RULES (from WOTS_ARCHITECTURE_RULES.md)

1. **800-line max per file** — extract before adding features
2. **Zero warnings** — typed vars, `-> void` lambdas, `_` prefix unused params
3. **Full file delivery** — never snippets or diffs
4. **Read uploaded code first** — never assume from memory
