---
description: "Develop and harden the auto-game scenarios: extend coverage across game systems, add pass/fail assertions and log analysis, and a runner that runs all scenarios and reports."
---

## Why

The project ships **7 auto-game scenarios** (`game/tools/scenarios/scenario_{1..7}_*.py`: collect, flee, explore, endure, spells, battle, battle_spells) driven through a live socket server (`play_scenario.sh`, port 9095, action-based newline-delimited JSON). They exercise the real game end-to-end, which is exactly the kind of integration signal the cycles need (succession, race-class, sacrifice, economy). But:
- **Coverage gaps:** no scenario exercises economy/city-building, succession, race-class creation, or the sacrifice mechanic — so new cycles have no integration harness.
- **Weak assertions:** scenarios mostly drive commands and rely on `GET_STATE`; there is little structured pass/fail checking, and no analysis of the captured console log for errors/warnings.
- **No aggregate runner:** `play_scenario.sh` runs one scenario; there is no "run all and report" harness.

This change develops the auto-game scenarios: harden the existing ones with assertions + log analysis, add scenarios for the remaining systems, and provide a runner that runs all and reports pass/fail.

## Proposed Change

- **Harden existing scenarios:** each scenario asserts key invariants (e.g. after START_GAME the hero exists and is at the capital; after COLLECT the resource count increased; after a battle the enemy stack is dead) and, at the end, greps the captured console log for `SCRIPT ERROR`/`Parse error`/`Invalid call`/`LEAK` and fails the scenario if found.
- **Add scenarios** for the systems the cycles introduce: economy/city (build structures, check `storage`/`boroughs` progression), succession (hero death → successor), race-class (hero born from a combo), and the sacrifice mechanic (finish off a strong monster).
- **Add a runner** `tools/shell/run_all_scenarios.sh` (or a Python orchestrator) that runs each scenario in isolation, collects pass/fail + a short report, and exits non-zero if any fail.

## Scope

- **In:** assertions + log analysis for existing scenarios, new scenario files, the aggregate runner.
- **Out:** the game systems the scenarios exercise (those are other cycles) — the scenarios are a *harness* for them.
