## 1. Baseline scan (triage pre-existing console state)
- [x] Run `bash tools/shell/run_all_ci_checks.sh` through the wrapper; capture `/tmp/godot_run.log`.
- [x] Scan for error + warning patterns; record the baseline count (for triage).

## 2. Harden AGENT.md rule 8.1
- [x] Rewrite rule 8.1 wording to a mandate: every Godot run MUST use `run_godot` / `run_and_fix.sh` / `run_all_ci_checks.sh`; bare `godot --scene`/`godot -s` is forbidden.
- [x] Add a small "allowed vs forbidden runners" table.

## 3. New «End-of-cycle run-and-debug gate» section (8.2)
- [x] Define the procedure: run CI + relevant smoke scenario through the wrapper; capture log; scan for error + warning patterns; fix; re-run until clean; do not commit until clean.
- [x] Define "clean" (no SCRIPT ERROR / Parse error / Invalid call / Nonexistent function / Cannot find / LEAK / leaked; only benign import warnings allowed).
- [x] List the exact scan patterns.

## 4. Wire the godot-run-and-fix skill
- [x] Reference the skill and `scripts/run_and_fix.sh` capture files in 8.2.
- [x] Standardize the "run-and-fix until clean" iteration in the gate.

## 5. Extend run_all_ci_checks.sh (additive)
- [x] Add an optional final step that greps captured logs, prints `⚠️ WARNINGS: N` / `❌ ERRORS: N`, and exits non-zero on errors.
- [x] Keep `--fast`/`--tests` behavior unchanged (guard the new step).

## 6. Verify the gate works
- [x] Run the gate on the current tree; confirm the summary step reports counts (baseline: ERRORS:4 from pre-existing locked-object SCRIPT ERROR).
- [x] Confirm a deliberately-introduced error is caught (sanity check: injected `nonexistent_method_sanity_probe()` -> step 2 FAIL, ERRORS 4->6), then revert.

## 7. Docs + commit
- [x] Update `docs/howto/TOOLS.md` cross-reference (gate + summary step).
- [x] Commit scoped to `AGENT.md`, `run_all_ci_checks.sh` (ded62ee).
