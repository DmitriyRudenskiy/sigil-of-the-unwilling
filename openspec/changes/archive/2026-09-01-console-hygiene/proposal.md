---
description: "Make live gameplay console-clean: capture the baseline across 5 socket scenarios (menu → world → movement → capture → spells), fix every script error, triage every warning (fix or documented allowlist), and add a one-command gate that fails on any error or un-allowed warning."
---

## Why

The unit suite is green (4802 tests) and CI passes 5/5, but **live gameplay console output has never been verified**. The socket scenario harness (`game/tools/shell/play_scenario.sh` + `game/tools/scenarios/scenario_1..7_*.py`) drives the *real* game — main menu, world entry, hero movement, resource capture, battles, spells — and its server log is the only place where runtime errors, `ObjectDB` leaks, deprecated-API warnings, and missing-resource noise actually surface during real play. Today that log is disposable (`/tmp/godot_scenario.log`, overwritten per run) and nobody checks it:

- Runtime `SCRIPT ERROR`s in gameplay code paths that unit tests don't exercise (scene lifecycle, signal handlers, battle overlay) can be sitting in the log unnoticed.
- Warnings (leaks, deprecated calls, failed resource loads) accumulate and mask the one real error that matters.
- Known suspect: `core/SocketController.gd` emits `Failed to listen: 22` at boot (disabled autoload still attempts to bind) — exactly the class of noise this cycle must eliminate or explicitly allow.

The repo already ships the tooling for this: the `godot-run-and-fix` skill defines the error/warning marker set (`SCRIPT ERROR`, `E 0:`, `W 0:`, `WARNING`, `NOTICE`, `LEAK`, `ObjectDB.*leak`, `deprecated`), and `play_scenario.sh` already captures each scenario's log. What is missing is the *loop*: baseline → fix → gate.

## Proposed Change

1. **Baseline capture (5 scenarios).** Run scenarios 1–5 (`collect`, `flee`, `explore`, `endure`, `spells`) through `play_scenario.sh`, each with its own log file (`/tmp/godot_console_<N>.log`). Parse each log with the skill's marker set; produce a unique-message table (message, count, first occurrence site).
2. **Error pass — target: zero.** Every error-class line (`SCRIPT ERROR`, `Parse error`, `Invalid call`, `Nonexistent function/member/class`, `Invalid get/set`, `Too many arguments`, `Cannot infer`, `E 0:`) is fixed at the source. No suppression, no swallowing.
3. **Warning pass — target: zero un-allowed.** Every warning-class line is either fixed or enters a documented allowlist. Blanket suppression (silencing the warning engine, deleting `push_warning`s to hide state) is forbidden.
4. **Allowlist.** `docs/CONSOLE_ALLOWLIST.md`: one row per allowed warning — exact pattern, reason, owner, date, removal plan. Anything on the list is a tracked debt item, not a silent ignore.
5. **One-command gate.** `game/tools/shell/check_console_clean.sh [scenario...]`: boots the game, runs the named scenarios (default 1–5), and exits non-zero on any error-class line or any warning not in the allowlist. Wire it into `run_all_ci_checks.sh` as a new CI step.

## Scope

- **In:** baseline capture + parsing, all console fixes inside `game/` (scripts, scenes, autoloads), `docs/CONSOLE_ALLOWLIST.md`, `check_console_clean.sh`, CI step, re-run verification.
- **Out:** scenarios 6–7 (`battle`, `battle_spells`) — they extend the same gate and can be enabled by one argument later; gameplay/balance changes unrelated to console output; new features; audio content (covered by archived `audio-pass`).

## Dependencies

- None hard. Uses existing harness (`play_scenario.sh`, scenarios 1–5, `run_all_ci_checks.sh`).
- Benefits from archived `audio-pass` (audio call sites must now be warning-free in live runs).
- `agent-run-and-debug` and `auto-game-scenarios` cycles share this harness; the gate script should be left compatible with their plans.
