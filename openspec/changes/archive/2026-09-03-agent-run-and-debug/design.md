## Context

`AGENT.md` (367 lines) already contains rule 8 (headless commands incl. `run_all_ci_checks.sh`) and rule 8.1 (⚠️ CRITICAL: run Godot scenes/scripts only with a hard timeout, with the `run_godot` wrapper: background process + `sleep` + `kill`). The `godot-run-and-fix` skill (`.pi/skills/godot-run-and-fix/`) provides `scripts/run_and_fix.sh` which captures errors/warnings to `/tmp/godot_errors_<PID>.txt`, `/tmp/godot_warnings_<PID>.txt`, `/tmp/godot_full_<PID>.txt`. `run_all_ci_checks.sh` runs compile → scene-refs → spell validation → tileset → unit tests.

What is **missing**:
- No requirement that the wrapper is *mandatory* for every run (rule 8.1 exists but reads as guidance, not a gate).
- No **end-of-cycle gate**: nothing forces the agent to run+scan the console before committing.
- The skill is documented but not wired into the per-cycle workflow.
- No standardized scan pattern / "clean log" definition.

## Design

Edit `AGENT.md` only (this change is about agent workflow, not game code):

1. **Harden rule 8.1.** Change wording from guidance to mandate ("MUST", "forbidden"). Add a short table: allowed runners (`run_godot`, `scripts/run_and_fix.sh`, `run_all_ci_checks.sh`) vs forbidden (bare `godot --scene`/`godot -s`).

2. **New section «End-of-cycle run-and-debug gate» (8.2).** Define the procedure:
   - Run `bash tools/shell/run_all_ci_checks.sh` (and any smoke scenario the cycle touches) through the wrapper.
   - Capture the log; scan for the error patterns + warning patterns (list them).
   - Fix every finding; re-run until clean.
   - "Clean" = no `SCRIPT ERROR`/`Parse error`/`Invalid call`/`Nonexistent function`/`Cannot find`/`LEAK`/`leaked`; only benign import warnings allowed.
   - The cycle is not committed until the gate passes.

3. **Wire the skill.** Point 8.2 at the `godot-run-and-fix` skill and its `run_and_fix.sh` capture files; standardize the scan patterns.

4. **Extend `run_all_ci_checks.sh`** (small, additive): add an optional final step that greps the captured logs and prints a summary (`⚠️ WARNINGS: N`, `❌ ERRORS: N`) and exits non-zero if errors are found — so the gate is a single command. Guard behind a flag to avoid changing the existing pipeline for `--fast`/`--tests`.

**Grounding facts (files):**
- `AGENT.md` rules 8, 8.1, section 9 (tests), section 10 (autoloads).
- `game/tools/shell/run_all_ci_checks.sh` — CI pipeline.
- `game/tools/shell/play_scenario.sh` — scenario orchestrator (port 9095).
- `.pi/skills/godot-run-and-fix/SKILL.md` + `scripts/run_and_fix.sh` — capture+fix.

## Risks / Trade-offs

- **Strict "no warnings" gate** may be noisy against pre-existing warnings (e.g. deprecations, import warnings). Define "clean" to allow only benign import warnings; run a baseline scan first to triage.
- **Extending `run_all_ci_checks.sh`** must not break existing `--fast`/`--tests` usage; keep the scan step additive and opt-in where possible.
- **Scope discipline:** this change edits workflow docs; it does not itself fix game-code warnings (those are the gate's *output*).
