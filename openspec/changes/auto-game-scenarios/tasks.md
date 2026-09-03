## 1. Shared scenario library
- [ ] Create `game/tools/scenarios/scenario_lib.py` (socket client, `send_cmd`, polling, log capture, assertion helpers, console-log scan).
- [ ] Refactor existing `scenario_{1..7}_*.py` to use the shared library.

## 2. Harden existing scenarios (assertions + log analysis)
- [ ] Each scenario asserts key invariants via `GET_STATE`/`GET_METRICS` (hero exists after START_GAME, resource increased after COLLECT_HERE, enemy dead after battle).
- [ ] Each scenario greps the captured server log for error/warning patterns and exits non-zero if found.
- [ ] Each scenario prints `PASS/FAIL <name>` and exits 0/1.
- [ ] Verify: run each existing scenario via `play_scenario.sh`; all PASS.

## 3. Aggregate runner
- [ ] Add `game/tools/shell/run_all_scenarios.sh` (fresh server per scenario; per-scenario pass/fail; report; exit non-zero on any failure).
- [ ] Verify: runner reports all 7 scenarios and exits 0.

## 4. New scenarios (guarded until their cycle lands)
- [ ] `scenario_economy.py` — build structures, check `storage`/`boroughs` progression.
- [ ] `scenario_succession.py` — hero death → successor (skip if succession absent).
- [ ] `scenario_race_class.py` — hero born from a race×class combo (skip if absent).
- [ ] `scenario_sacrifice.py` — finish off a strong enemy via sacrifice (skip if absent).
- [ ] Wire each into `play_scenario.sh` fallback chain + the runner's discovery.

## 5. Tests + validation
- [ ] Run the full runner green.
- [ ] Run `run_all_ci_checks.sh` green.
- [ ] Add/adjust unit tests if the shared library has unit-testable helpers.

## 6. Docs + commit
- [ ] Document the harness in `docs/TOOLS.md`.
- [ ] Commit scoped to `game/tools/scenarios/` + `game/tools/shell/`.
