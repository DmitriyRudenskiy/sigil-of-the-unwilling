## Context

The audit (`/opsx:propose` paste) flagged `game/tools/shell/*` (5 scripts, 798
lines) as duplicating logic that GUT should own, and proposed replacing them with
GUT tests plus a shared `ConsoleScanner` GDScript. Before acting, the actual
scripts and tool interfaces were inspected.

## Why the shell scripts cannot become GUT tests

1. **GUT runs inside Godot.** The shell scripts spawn Godot as an *external*
   process and scan its stdout for error markers, because Godot returns exit 0
   even when a script fails to load (`Can't load script`). Re-creating that from
   inside a GUT test via `OS.execute` is fragile and fights the framework.

2. **class_name registry bootstrap needs `--editor`.** `run_all_ci_checks.sh`
   builds `.godot/global_script_class_cache.cfg` by running `godot --editor`
   once (headless `-s`/imports do not write it). A GUT test cannot do this.

3. **Multi-language orchestration.** `run_all_scenarios.sh` / `run_operability.sh`
   drive Python socket scenarios (`scenario_*.py`) plus Godot plus bash. That is a
   shell/CI concern, not a GDScript unit test.

4. **No existing GUT integration pattern.** `game/tests/integration/` does not
   exist; GUT is only ever run via `-gdir=res://tests -ginclude_subdirs` from the
   shell scripts. The rewrite would invent a new, untested pattern.

5. **The proposed pseudocode is non-functional.** `compile_all.gd` and
   `check_scene_refs.gd` both `extends SceneTree` with `_process`/`_scan`; they
   expose no `compile_all()` / `check_all()` method returning the `{error_count}`
   / `errors` the audit's "После" block assumes. It would not compile.

## Why the "dedup" is not worth it

The only legitimate nit is duplicated error-marker regexes across
`check_console_clean.sh`, `run_operability.sh`, `run_all_ci_checks.sh`. A
GDScript `ConsoleScanner` cannot be consumed by shell scripts; a shell-level
`source` include is possible but the patterns are already tuned slightly
differently per script (CI gate vs operability gate), so deduping would be lossy.
The regexes are ~4 lines each with explanatory comments. Not worth the
indirection.

## Decision

Keep the shell scripts as-is. No code or docs change beyond the optional port
comment. The assessment is recorded here so the rewrite is not proposed again.
