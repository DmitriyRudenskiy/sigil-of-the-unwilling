## Context

Scenarios live in `game/tools/scenarios/scenario_{1..7}_*.py` and are orchestrated by `game/tools/shell/play_scenario.sh` (starts the Godot test server on port 9095, waits for the socket, runs the scenario Python, kills the server). The protocol is newline-delimited JSON over TCP (`localhost:9095`), action-based. `SocketController` (game/core/SocketController.gd) handles: `START_GAME`, `GET_STATE`, `MOVE_TO`, `END_TURN`, `COLLECT_HERE`, `RETREAT`, `FORCE_RETREAT`, `GET_SPELLS`, `CAST_SPELL`, `EMULATE_BATTLE`, `CAST_IN_BATTLE`, `SEQUENCE_BATTLE`, `BATTLE_SPELL`, `SPELL_REGISTRY`, `GET_METRICS`. `GET_STATE` returns world state (`hero_pos`, `moving`, resources, enemy stacks, …); `GET_METRICS` returns metrics.

Current scenarios: collect, flee, explore, endure, spells, battle, battle_spells. They drive commands and poll `GET_STATE` but have little structured pass/fail and no console-log analysis. `play_scenario.sh` runs one scenario and returns its exit code; there is no aggregate runner.

## Design

**Shared helper module.** Extract the socket/client boilerplate (`send_cmd`, `wait_arrival`, server start/stop, log capture) into a shared `game/tools/scenarios/scenario_lib.py` so all scenarios assert + analyze consistently. `play_scenario.sh` already starts/stops the server; extend it (or the runner) to also capture the server log to `/tmp/godot_scenario.log` and pass it to the scenario for analysis.

**Harden existing scenarios.** Each scenario:
- asserts flow invariants via `GET_STATE`/`GET_METRICS` (hero exists after START_GAME, resource count increased after COLLECT_HERE, enemy stack count == 0 after the finishing blow);
- on completion, greps the captured server log for `SCRIPT ERROR`/`Parse error`/`Invalid call`/`Nonexistent function`/`Cannot find`/`LEAK`/`leaked`/`WARNING`/`deprecated` and exits non-zero if found;
- prints `PASS`/`FAIL <name>` and exits 0/1.

**New scenarios.** Add `scenario_economy.py` (build structures, check `storage`/`boroughs`), `scenario_succession.py` (hero death → successor — depends on succession-sigil), `scenario_race_class.py` (hero born from a combo — depends on race-class-matrix), `scenario_sacrifice.py` (finish off a strong enemy — depends on sacrifice-mechanic). Each guarded so it is skipped (not failed) if its system is absent, until the corresponding cycle lands.

**Aggregate runner.** Add `game/tools/shell/run_all_scenarios.sh` (or a Python orchestrator) that runs each scenario in isolation (fresh server per scenario), collects pass/fail, prints a report, and exits non-zero if any fail.

**Grounding facts (files):**
- `game/core/SocketController.gd` — protocol/actions/`GET_STATE`/`GET_METRICS`.
- `game/tools/scenarios/scenario_{1..7}_*.py` — existing scenarios.
- `game/tools/shell/play_scenario.sh` — orchestrator (port 9095).

## Risks / Trade-offs

- **New scenarios depend on other cycles** (succession/race-class/sacrifice). Guard them as skip-until-present so the runner stays green before those cycles land.
- **Console-log analysis is strict** (warnings fail) — may conflict with benign import warnings. Align with the agent-run-and-debug gate's "clean" definition; allow only import warnings.
- **One server per scenario** is slower than reusing one; correctness (isolation) is worth the cost for a CI-style harness.
