## Context

The 11 headless `.gd` tools under `game/tools/` (compile check, scene refs, tileset, unit dump, spell-validation CLI, benchmarks, memory profile, four generators, `run_scene`) were, in the first revision of this change, routed through `mcp_interaction_server.gd` behind an `McpRouter`/`McpToolsHandler`. That was the wrong layer: the MCP server is a **runtime** interface into a *live* process (TCP 127.0.0.1:9090, arbitrary-GDScript execution, dev-only, machine-checked OFF in CI/release). Deterministic invariant checks belong in CI (GUT); file-producing tools belong in build scripts.

Repo facts the design relies on:

- `.gutconfig.json`: `dirs: ["res://tests/"]`, `include_subdirs: true` — new tests under `tests/functional/` are auto-discovered; no config change.
- `tests/test_spells_json.gd` **already** preloads `res://tools/spell_validation/SpellValidator.gd` and uses the validator as a library; `tests/test_unit_registry.gd` already exists.
- Orphan `.uid` files: `tests/spell_validation/{SpellValidator,validate_spells,ValidationReport}.gd.uid` and `tests/test_tile_atlas.gd.uid` (left by a previous partial move).
- Current CI (`run_all_ci_checks.sh`): class-registry bootstrap → 4 `godot -s tools/...` checks (compile, refs, `validate_spells --strict --json`, tileset) → GUT (`-gdir=res://tests -ginclude_subdirs`) → console clean. `--fast` = steps 1–4 only.
- `run_operability.sh:131` boots four scenes via `run_godot ... -s tools/run_scene.gd <scene>`.
- `tools/gen_runner.tscn` has an `ext_resource` → `res://tools/gen_inventory_scene.gd`.
- `UNITS_BASE` defines 142 units; spell data lives at `res://assets/data/spells.json`; CI validates it with `--strict` (warnings fail) against `baseline.json`.

## Goals / Non-Goals

**Goals**

- Deterministic invariants (compile, scene refs, tileset, units, spells-strict, scene boot) fail CI as GUT tests.
- Generators/tuner stay runnable headless with identical behavior, from `scripts/build/`.
- Delete the standalone `.gd` tools, the vendored `godot-mcp` tree, and the dead `.mcp.json`.

**Non-Goals**

- No changes to `mcp_interaction_server.gd` (no router, no `tools_*` commands).
- No changes to `tools/shell/`, `tools/scenarios/`, `tools/comfy/`, `tools/archived/`, `tools/lint.sh`, or the `.py` tools.
- No new MCP stdio client in the repo.

## Decisions

**D1 — Invariants → GUT tests in `tests/functional/`.**
Each ported check becomes an asserting test; a broken invariant = red CI. Rationale: deterministic, needs no live process/TCP, fatal instead of advisory. Ports keep the old scan scope and skip rules verbatim (compile: skip `.git/.godot/addons/tools/tests`, `can_instantiate()` gate; refs: `res://scenes` + `res://tools`, `path="(res://[^"]+)"` regex + `PackedScene` load).

**D2 — Generators → `scripts/build/`, faithful ports.**
`gen_artifact_icons.gd`, `gen_sound_wav.gd` (was `sound_synth.gd`), `gen_inventory_scene.gd`, `tune_city_arena.gd`. No fidelity loss: all five WAVs incl. 4.0 s `bgm_loop`, real per-slot/per-rarity icon rendering, real hill-climber with `--dry-run`/`--report`. Entry: `godot --headless -s scripts/build/<name>.gd` (self-contained `extends SceneTree`, `quit(0)` on completion); `gen_runner.tscn` is no longer needed and is deleted.

**D3 — MCP stays a runtime interface; the duplicate client goes.**
`mcp_interaction_server.gd` untouched — it remains the optional dev-only TCP autoload (AGENT.md §10; gate 8.2 keeps checking it is OFF). `game/tools/godot-mcp/` and root `.mcp.json` are deleted (the file's only entry pointed at the vendored bridge). If an MCP client is needed later, install one externally and re-point `.mcp.json` — out of scope.

**D4 — Extend, don't duplicate, existing tests.**
`tests/test_unit_registry.gd` gains the `dump_unit_report.gd` assertions (count > 100 — registry has 142 — plus per-unit stat validity); no `UNIT_REPORT.txt` written from tests. `tests/test_spells_json.gd` gains a strict-parity test reproducing the old `--strict` CI semantics (warnings → fail). The validator logic (`SpellValidator.gd`, `ValidationReport.gd`, `baseline.json`) moves to `tests/spell_validation/` — its only consumer is the GUT test, and the move repairs `test_spells_json.gd`'s `res://tools/...` preload. `validate_spells.gd` (the CLI wrapper) is deleted; its `_load_src` absolute-path loading trick disappears with it (the files are now under `res://`).

**D5 — CI fold.**
The four per-tool `godot -s` steps are removed from `run_all_ci_checks.sh`; the invariants run inside the existing GUT step. Registry bootstrap and console-clean steps are unchanged. `--fast` is redefined: GUT only (no console clean) — the old "checks without tests" split no longer exists.

**D6 — `run_scene.gd` → `test_scene_boot.gd`.**
The four-scene boot check (MainMenu, CityArena, World, Battle) becomes a GUT test; `run_operability.sh` invokes it via `gut_cmdln.gd -gtest=res://tests/functional/test_scene_boot.gd -gexit`.

**D7 — `tools/` is not literally emptied.**
`shell/`, `scenarios/`, `comfy/`, `archived/`, `lint.sh`, and the `.py` tools stay: CI and AGENT.md reference them, and they are not the migrated tools.

## Risks / Trade-offs

- **Perf tests flake on slow CI runners** → reuse the old tool's threshold constants (they carry built-in headroom); if a specific benchmark proves flaky in practice, drop that single assertion behind a GUT selection (`-gselect`) so `--fast` stays green — an upgrade path, not pre-empted.
- **Memory deltas are noisy** → `test_memory_profile.gd` asserts direction/sanity per operation (delta finite and > 0), not exact KB values.
- **Losing the MCP stdio bridge** → `mcp_interaction_server.gd` still covers in-game dev interaction; AGENT.md §13 documents that any external client is re-added out of repo.
- **Validator move changes import paths** → the only in-repo consumer is `tests/test_spells_json.gd` (verified by grep); updated in the same change.
- **`gen_runner.tscn` deletion** → its only consumer was `gen_inventory_scene.gd`; the build script is self-contained, and the new scene-refs test would have flagged the stale reference otherwise.

## Migration Plan

1. GUT tests first (D1/D4/D6) — while old tools still exist, port and run side-by-side against the old outputs.
2. Build scripts (D2) — port, run once headless, diff outputs (WAV list, icon set, generated `.tscn`, tuner report).
3. CI/operability rewiring (D5/D6).
4. Deletions (`.gd` tools, `spell_validation/` after the move, `gen_runner.tscn`, `godot-mcp/`, `.mcp.json`, orphan `tests/test_tile_atlas.gd.uid`).
5. Docs (AGENT.md §8/§13, `docs/howto/TOOLS.md`).
6. Verify: full GUT green, `run_all_ci_checks.sh --fast` green, build scripts smoke-run, `openspec validate dev-tooling-rebuild`.

## Open Questions

- None blocking. (If perf tests flake in CI, see the D1 risk note above.)
