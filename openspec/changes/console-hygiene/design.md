# Design: console-hygiene

## Context

- **Active project root is `game/`** — `res://` = `game/`. Scenarios and CI scripts live in `game/tools/`.
- **Scenario harness**: `game/tools/shell/play_scenario.sh [N] [--log <file>]` boots
  `Godot --path game --headless --test-server --scene scenes/MainMenu.tscn`, waits for the socket on
  `localhost:9095` (action-based, newline-delimited JSON), runs
  `game/tools/scenarios/scenario_<N>_{collect,flee,explore,endure,spells,battle,battle_spells}.py`,
  kills the server, and exits with the scenario's exit code.
- **Scenarios in scope (5)**: `1_collect`, `2_flee`, `3_explore`, `4_endure`, `5_spells`.
  Scenarios 6–7 (`battle`, `battle_spells`) exist and are the natural next enablement.
- **Console marker set** (from the `godot-run-and-fix` skill):
  - error-class: `SCRIPT ERROR`, `Parse error`, `Invalid call`, `Nonexistent function`,
    `Nonexistent class`, `Nonexistent base`, `Too many arguments`, `Cannot infer`,
    `Invalid get/set`, `E 0:`
  - warning-class: `WARNING`, `NOTICE`, `LEAK`/`leaked`, `ObjectDB.*leak`, `deprecated`, `W 0:`
- **Known pre-existing noise**: `core/SocketController.gd` logs `Failed to listen: 22` at boot
  (observed in earlier headless runs; the autoload is disabled by design, but the failure message
  still reaches the console). This is the canonical candidate for either a source fix or the first
  allowlist row.
- **CI**: `game/tools/shell/run_all_ci_checks.sh` runs 5 steps (compile, scene refs, spell
  validation, tileset integrity, unit tests) with `set -uo pipefail` and per-step PASS/FAIL
  markers; a console-clean step slots in as step 6.
- **Test suite**: 4802 passed / 0 failed (76 files) as of the `audio-pass` gate — the baseline the
  console fixes must not regress.

## Design

### 1. Capture protocol

- One Godot process per scenario (the harness already does this — no process reuse, so per-run
  `ObjectDB` leak reports stay attributable).
- Logs: `/tmp/godot_console_<N>.log` via `play_scenario.sh N --log ...`.
- Parsing is marker-based (grep over the skill's sets), producing a **unique-message table**:
  normalized message (script names/line numbers collapsed), class (error/warning), count, first
  occurrence (file:line if present).
- Baseline output is recorded in `tasks.md` under section 1 so later re-runs diff against a
  committed artifact, not a memory.

### 2. Triage model

| Class | Definition | Disposition |
|---|---|---|
| error | any error-class marker | **fix at source; target 0** |
| warning (fixable) | leak, deprecated call, failed resource load, bad API use | **fix at source** |
| warning (allowed) | engine noise we cannot or should not remove (documented) | **allowlist row** |

Rules:
- No suppression: deleting a `push_warning`/`push_error` to silence the console while keeping the
  faulty state is forbidden; the state itself must be fixed.
- No blanket silencing: the warning engine stays on; `check_console_clean.sh` must not filter
  error-class lines.
- Every allowlist row carries: exact grep pattern, reason, owner, date, removal plan.

### 3. Fix policy

- Errors: read the script at the reported line, fix semantics (not the symptom). Typical cases per
  the skill: missing preload, variant inference, nonexistent member, await-in-match.
- Warnings: prefer engine-correct fixes (typed inference, proper signal disconnection on
  `queue_free`, `ResourceLoader` checks) over workarounds.
- Each fix is covered by an existing or new test where the code path is unit-testable; pure
  scene-lifecycle fixes rely on the scenario gate itself.

### 4. Gate: `check_console_clean.sh`

```
usage: game/tools/shell/check_console_clean.sh [N ...]     # default: 1 2 3 4 5
```

1. For each scenario N: run `play_scenario.sh N --log /tmp/godot_console_N.log`; a non-zero scenario
   exit fails the gate (gameplay must complete, not just be quiet).
2. Scan the log: any error-class marker → FAIL (print offending lines).
3. Scan the log for warning-class markers; a warning FAILs only if its normalized pattern is not in
   `docs/CONSOLE_ALLOWLIST.md` (patterns are read from the file's table, one regex per row).
4. Exit 0 only when all scenarios pass and the console is clean; print a per-scenario summary.

CI wiring: add as step `[6] Console clean (5 scenarios)` in `run_all_ci_checks.sh` (it inherits
`set -uo pipefail` and the PASS/FAIL reporting).

### 5. Verification order

1. Baseline (section 1) → 2. error pass → 3. warning pass + allowlist → 4. gate script + CI step →
   5. full re-run of the 5 scenarios + unit suite + CI to prove no regressions.

## Grounding facts (files)

- `game/tools/shell/play_scenario.sh` — harness: Godot boot flags, port 9095, `--log`, exit-code
  propagation, scenario-name fallback chain.
- `game/tools/scenarios/scenario_{1_collect,2_flee,3_explore,4_endure,5_spells}.py` — the five
  scenario drivers (socket JSON protocol, `HOST, PORT = "localhost", 9095`).
- `game/tools/shell/run_all_ci_checks.sh` — 5-step CI pipeline, per-step markers, Godot
  resolution, `_godot_script` log-based failure detection.
- `game/core/SocketController.gd` — source of the known `Failed to listen: 22` boot warning.
- `game/core/SoundManager.gd` — audio call sites added by `audio-pass`; live runs must not warn on
  cue playback (graceful degradation is a spec requirement of the archived `audio` capability).
- `.pi/skills/godot-run-and-fix/SKILL.md` — error/warning marker taxonomy and fix templates this
  design reuses.
- `openspec/changes/archive/2026-08-31-audio-pass/` — precedent for the task/gate format used here.
