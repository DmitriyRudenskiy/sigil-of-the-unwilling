## Why

The project's 11 standalone `extends SceneTree` headless tools under `game/tools/` (plus the `spell_validation/` CLI and `run_scene.gd`) are invoked ad hoc via `godot --headless -s tools/<tool>.gd`. The first revision of this change routed them through the MCP server — the wrong layer: `mcp_interaction_server.gd` is a **runtime** interaction interface into a *live* process (TCP 127.0.0.1:9090, arbitrary GDScript execution, dev-only, must stay out of CI). Compile / scene-ref / tileset / unit / spell checks are **deterministic static analysis** — they should fail CI, not return `{"ok": false}` over a socket. Asset generators and the balance tuner produce files — they are **build scripts**, not tests, not MCP.

Correct home for each tool:

| Old tool | New home | Why |
|---|---|---|
| `compile_all.gd` | GUT test `tests/functional/test_compile_all.gd` | Deterministic compile check → CI must fail |
| `check_scene_refs.gd` | GUT test `tests/functional/test_scene_refs.gd` | Broken `ext_resource` → CI must fail |
| `check_tileset.gd` | GUT test `tests/functional/test_tileset_integrity.gd` | Deterministic tileset integrity check |
| `dump_unit_report.gd` | GUT test (extends existing `tests/test_unit_registry.gd`) | Count/status assertions, no file side effect |
| `spell_validation/` (validator + `validate_spells.gd` CLI) | Logic → `tests/spell_validation/`; CLI replaced by GUT test (extends existing `tests/test_spells_json.gd`) | Strict-mode parity with current CI |
| `benchmark_all.gd`, `memory_profile.gd` | GUT perf tests | Thresholds / deltas as assertions |
| `run_scene.gd` | GUT test `tests/functional/test_scene_boot.gd` | Scene-boot invariant; `run_operability.sh` updated |
| `sound_synth.gd` | `scripts/build/gen_sound_wav.gd` | File generation |
| `artifact_icon_generator.gd` | `scripts/build/gen_artifact_icons.gd` | File generation |
| `gen_inventory_scene.gd` (+ `gen_runner.tscn`) | `scripts/build/gen_inventory_scene.gd` | File generation |
| `tune_city_arena.gd` | `scripts/build/tune_city_arena.gd` | Hill-climbing balance tuner, file write |

The vendored `game/tools/godot-mcp/` tree (TS/Node stdio bridge, `build/index.js` — the only entry in root `.mcp.json`) duplicates what an external MCP client provides and is deleted. `mcp_interaction_server.gd` itself stays a dev-only runtime interface, **unchanged**.

## What Changes

- **New GUT invariant tests in `game/tests/functional/`** (auto-discovered — `.gutconfig.json` already has `dirs: ["res://tests/"]` + `include_subdirs: true`, no config change):
  - `test_compile_all.gd` — port of `compile_all.gd`: compile every `res://` GDScript (skip `.git`, `.godot`, `addons`, `tools`, `tests`), fail on any parse/preload error.
  - `test_scene_refs.gd` — port of `check_scene_refs.gd`: scan `res://scenes` + `res://tools` for broken `ext_resource`/preload paths, fail on any miss.
  - `test_tileset_integrity.gd` — port of `check_tileset.gd`: load `world_tiles.jpeg`, `TileAtlas.build_hex_tileset()`, assert texture present and `source_count > 0`.
  - `test_scene_boot.gd` — port of `run_scene.gd`: headless-boot `MainMenu`, `CityArena`, `World`, `Battle` scenes, assert no script errors.
  - `test_benchmarks.gd` + `test_memory_profile.gd` — ports of `benchmark_all.gd` / `memory_profile.gd`: thresholds / deltas as assertions.
- **Extend existing tests (no duplicates):**
  - `tests/test_unit_registry.gd` — add `dump_unit_report.gd` assertions: registry count > 100 (142 units) and valid per-unit stats (hp > 0, spd ≥ 1, atk/dmg ≥ 0, non-empty string tags). No `UNIT_REPORT.txt` side effect in tests.
  - `tests/test_spells_json.gd` — add strict-mode parity test (current CI runs `--strict`: warnings fail the gate).
- **Move** `game/tools/spell_validation/{SpellValidator.gd,ValidationReport.gd,baseline.json}` → `game/tests/spell_validation/`; update `tests/test_spells_json.gd`'s preload to the new path. (Orphan `.uid` files already sit there from a previous move.)
- **New `game/scripts/build/` build scripts**, each self-contained `extends SceneTree`, run as `godot --headless -s scripts/build/<name>.gd`, **faithful ports (no fidelity loss)**:
  - `gen_artifact_icons.gd` — 64×64 per-slot/per-rarity PNGs → `res://assets/artifacts/`.
  - `gen_sound_wav.gd` — five 16-bit WAVs incl. 4.0 s `bgm_loop` → `res://assets/audio/`.
  - `gen_inventory_scene.gd` — structural `ArtifactInventoryScreen.tscn` skeleton (self-contained entry; `tools/gen_runner.tscn` deleted).
  - `tune_city_arena.gd` — hill-climber over `city/ArenaBalance.gd` with `--evals/--seed/--turns/--dry-run/--report`; writes the file unless `--dry-run`.
- **CI:** `tools/shell/run_all_ci_checks.sh` drops the four per-tool `godot -s tools/...` steps — the invariants run inside the existing GUT step (`-gdir=res://tests -ginclude_subdirs`). `--fast` semantics change from "compile+validation without tests" to "GUT only (no console clean)".
- **Operability:** `tools/shell/run_operability.sh` swaps its `-s tools/run_scene.gd` scene launches for a GUT run of `tests/functional/test_scene_boot.gd`.
- **Delete:** the 11 `game/tools/*.gd` tools (incl. `run_scene.gd`), `game/tools/gen_runner.tscn`, `game/tools/spell_validation/` (after the move), `game/tools/godot-mcp/` (build/ + src/ + Node client), root `.mcp.json` (its only entry is the godot-mcp bridge), orphan `game/tests/test_tile_atlas.gd.uid`.
- **Keep:** `game/tools/shell/`, `game/tools/scenarios/`, `game/tools/comfy/`, `game/tools/archived/`, `game/tools/lint.sh`, and the `.py` tools — referenced by CI/AGENT.md, untouched.
- **Docs:** `AGENT.md` §8 (tool command blocks → GUT tests, `--fast` semantics), §13 (drop the vendored godot-mcp "Full Control" section; the in-game TCP dev server stays), `docs/howto/TOOLS.md` (new entry points). `docs/CONSOLE_ALLOWLIST.md` needs no change (references `tools/shell/` only).
- **MCP:** `mcp_interaction_server.gd` is **not modified** — no router, no new commands, no `tools_*` routing.

**BREAKING**: `run_all_ci_checks.sh` no longer calls `tools/compile_all.gd`, `tools/check_scene_refs.gd`, `tools/spell_validation/validate_spells.gd`, `tools/check_tileset.gd`, or `tools/run_scene.gd` — the invariants run as GUT tests and the operability boot check as `test_scene_boot.gd`. Anything invoking the old per-tool scripts by path, or the deleted `.mcp.json` stdio bridge, must switch to GUT / `scripts/build/`.

## Capabilities

### New Capabilities
- `dev-tooling`: invariant checks and asset/balance generation as GUT tests and `scripts/build/` build scripts; removal of the standalone `tools/*.gd` tooling, `gen_runner.tscn`, and the vendored `godot-mcp` client.

### Modified Capabilities
- (none — no existing spec requirement changes; the previous revision's `mcp-tools-handler` capability is replaced by `dev-tooling` and was never implemented.)

## Impact

- **Code (new):** `game/tests/functional/` (5 test files), `game/tests/spell_validation/` (moved validator + `baseline.json`), `game/scripts/build/` (4 build scripts).
- **Code (modified):** `game/tests/test_unit_registry.gd`, `game/tests/test_spells_json.gd` (preload path + strict test), `game/tools/shell/run_all_ci_checks.sh`, `game/tools/shell/run_operability.sh`.
- **Code (deleted):** 11 `game/tools/*.gd` files, `game/tools/gen_runner.tscn`, `game/tools/spell_validation/`, `game/tools/godot-mcp/`, root `.mcp.json`, `game/tests/test_tile_atlas.gd.uid`.
- **MCP:** none — `mcp_interaction_server.gd` untouched; remains the optional dev-only autoload (AGENT.md §10, machine-checked in gate 8.2).
- **CI/Docs:** `run_all_ci_checks.sh` (4 steps folded into GUT, `--fast` redefined), `run_operability.sh`, `AGENT.md` §8/§13, `docs/howto/TOOLS.md`.
