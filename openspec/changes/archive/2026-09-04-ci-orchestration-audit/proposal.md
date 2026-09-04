## Why

An audit of `game/tools/shell/*` proposed replacing the five CI bash scripts with
GUT tests and extracting error markers into a GDScript `ConsoleScanner`. Reviewing
the actual scripts and tool interfaces shows the rewrite is neither feasible nor
beneficial — the shell scripts orchestrate Godot-external concerns (registry
bootstrap, subprocess log scanning, bash+python+godot multi-language runs,
marker-based pass/fail) that GUT cannot perform, and the audit's "После"
pseudocode references methods (`compile_all()`, `check_all()`) that do not exist
on the `SceneTree` tool scripts.

## What Changes

- **Nothing is removed or added.** The shell scripts in `game/tools/shell/*` stay.
- No GUT integration tests are created (`game/tests/integration/` is not created).
- No GDScript `ConsoleScanner` helper is created.
- No changes to `AGENT.md` or `docs/howto/TESTING.md` (their references to
  `run_all_ci_checks.sh` remain valid).
- Optional, non-required cleanup: a one-line comment in `play_scenario.sh`
  pointing at `SocketController.gd` as the source of the `PORT=9095` constant.

## Capabilities

- No capabilities. This change introduces no behavior change; it records the
  audit assessment and recommends against the rewrite.

## Impact

- Affected systems: none. Only documentation of a rejected refactor.
