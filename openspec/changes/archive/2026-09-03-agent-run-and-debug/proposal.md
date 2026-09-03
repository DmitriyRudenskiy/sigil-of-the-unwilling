---
description: "Standardize Godot runs in a hang-preventing wrapper and add an end-of-cycle 'run and debug' gate that scans the console for warnings/errors and fixes them before committing."
---

## Why

Every Godot invocation (`--scene`, `-s script.gd`) spins a main-loop that can hang forever; on macOS there is no `timeout`, and a hung command can tie up the harness for ~5000 s and lose all progress. `AGENT.md` already documents a `run_godot` wrapper (rule 8.1) and a `run_all_ci_checks.sh` pipeline, and the `godot-run-and-fix` skill captures errors/warnings — but these are **ad hoc**, not a hard workflow requirement, and there is **no explicit end-of-cycle gate** that runs the build in debug mode and verifies the console is clean before a cycle is committed. As a result a cycle can be committed while leaving `SCRIPT ERROR` / `Parse Error` / `Invalid call` / `LEAK` / warnings in the console.

This change makes the hang-preventing wrapper a **hard rule**, and adds a mandatory **«запусти и отладь» (run-and-debug) gate** at the end of every cycle: run the relevant Godot entry points through the wrapper, capture the console, scan for errors and warnings, fix until clean, and only then commit.

## Proposed Change

Edit `AGENT.md` to:
1. **Mandate the wrapper.** Every Godot run in any cycle MUST go through a hang-preventing wrapper (`run_godot`, or `scripts/run_and_fix.sh` from the `godot-run-and-fix` skill). Bare `godot --scene` / `godot -s` without a timeout is forbidden.
2. **Add the end-of-cycle run-and-debug gate.** Define a repeatable procedure: after implementing a cycle, run the full CI (`run_all_ci_checks.sh`) plus the relevant smoke scenario, capture `/tmp/godot_run.log`, scan it for `SCRIPT ERROR`, `Parse error`, `Invalid call`, `Nonexistent function`, `Cannot find`, `LEAK`/`leaked`, and `WARNING`/`deprecated`; fix every finding and re-run until the log is clean (only import warnings, if any, are acceptable); the cycle is **not committed** until the gate passes.
3. **Wire in the skill.** Reference the `godot-run-and-fix` skill as the tool that performs capture+fix, and standardize the scan patterns.

## Scope

- **In:** edits to `AGENT.md` (rule 8 / 8.1 additions, a new "End-of-cycle run-and-debug gate" section), the `godot-run-and-fix` skill's usage guidance, and the `run_all_ci_checks.sh` (add an optional console-scan summary step).
- **Out:** fixing pre-existing warnings/errors found during the gate (that is the *output* of running the gate, not the change itself — though the change should include a baseline scan as a task).
