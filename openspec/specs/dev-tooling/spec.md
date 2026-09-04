# dev-tooling Specification

## Purpose

Deterministic dev-tooling for the Godot project: invariant checks (compilation, scene references, tileset, unit registry, spell data, scene boot, performance) as GUT tests that fail CI, and asset/balance generation as headless `scripts/build/` build scripts — replacing the standalone `game/tools/*.gd` scripts, `gen_runner.tscn`, and the vendored `godot-mcp` client. `mcp_interaction_server.gd` remains a dev-only runtime interface and is unchanged.

## Requirements

### Requirement: GUT invariant tests
The GUT suite SHALL include tests, auto-discovered from `res://tests`, that fail CI when a project invariant is broken:
- `tests/functional/test_compile_all.gd` — every `res://` GDScript compiles (skipping `.git`, `.godot`, `addons`, `tools`, `tests`).
- `tests/functional/test_scene_refs.gd` — no broken `ext_resource`/preload paths under `res://scenes` and `res://tools`.
- `tests/functional/test_tileset_integrity.gd` — the world tile texture loads and `TileAtlas.build_hex_tileset()` yields at least one TileSet source.
- `tests/functional/test_scene_boot.gd` — the `MainMenu`, `CityArena`, `World`, and `Battle` scenes instantiate headless without script errors.
- `tests/test_unit_registry.gd` — the unit registry contains more than 100 units and every unit has valid stats (hp > 0, spd ≥ 1, atk ≥ 0, dmg ≥ 0, non-empty string tags).
- `tests/test_spells_json.gd` — `res://assets/data/spells.json` validates with no structural/type errors and, in strict mode, no warnings.

#### Scenario: a script fails to compile
- WHEN a `.gd` file under `res://scripts` contains a parse error
- THEN `test_compile_all.gd` fails CI

#### Scenario: a scene references a missing resource
- WHEN a scene under `res://scenes` has an `ext_resource` pointing at a non-existent path
- THEN `test_scene_refs.gd` fails CI

#### Scenario: spell data regresses
- WHEN `spells.json` validation produces an error, or a warning in strict mode
- THEN the spell-validation GUT test fails CI

### Requirement: Performance and memory GUT tests
The GUT suite SHALL include a performance test asserting the ported benchmark thresholds (map generation, spell registry, serialization, placeholder texture, JSON parse) and a memory test asserting each profiled operation's allocation delta is finite and positive.

#### Scenario: map generation exceeds its threshold
- WHEN map generation at the benchmark map size exceeds the ported time threshold
- THEN the performance GUT test fails

### Requirement: Build scripts
The project SHALL provide headless build scripts under `res://scripts/build/`, runnable as `godot --headless -s scripts/build/<name>.gd`, with behavior identical to the old `game/tools/` scripts:
- `gen_artifact_icons.gd` — 64×64 per-slot/per-rarity PNG icons for all artifacts into `res://assets/artifacts/`.
- `gen_sound_wav.gd` — five 16-bit WAV placeholder sounds (incl. 4.0 s `bgm_loop`) into `res://assets/audio/`.
- `gen_inventory_scene.gd` — regenerates the structural `res://scenes/ui/ArtifactInventoryScreen.tscn` skeleton.
- `tune_city_arena.gd` — hill-climbing balance tuner for `scripts/city/ArenaBalance.gd` with `--evals`, `--seed`, `--turns`, `--dry-run`, `--report` options; `--dry-run` suppresses the file write.

#### Scenario: sound placeholder regeneration
- WHEN `gen_sound_wav.gd` is run headless
- THEN all five WAV files exist under `res://assets/audio/`

#### Scenario: dry-run tuning
- WHEN `tune_city_arena.gd` is run with `--dry-run`
- THEN the best tables and score are reported but `ArenaBalance.gd` is not modified

### Requirement: Removal of standalone tools and vendored MCP client
The standalone tooling SHALL be removed: the 11 `game/tools/*.gd` scripts (incl. `run_scene.gd`), `game/tools/gen_runner.tscn`, `game/tools/spell_validation/` (logic moved to `res://tests/spell_validation/`), the vendored `game/tools/godot-mcp/` tree, and root `.mcp.json`. `game/tools/shell/`, `game/tools/scenarios/`, `game/tools/comfy/`, `tools/lint.sh`, and the Python tools SHALL remain. `mcp_interaction_server.gd` SHALL remain unchanged: the dev-only runtime TCP interaction server (loopback:9090, enabled autoload by design per its code comments); no build/CI tooling may route through it.

#### Scenario: old tool paths are gone
- WHEN the repository is checked after the change
- THEN `game/tools/` contains no migrated `.gd` tool, `game/tools/godot-mcp/` does not exist, and root `.mcp.json` does not exist

#### Scenario: MCP autoload untouched
- WHEN the change is applied
- THEN `mcp_interaction_server.gd` has no new commands or router and remains disabled in `project.godot`

### Requirement: CI runs invariants through GUT
`tools/shell/run_all_ci_checks.sh` SHALL run the invariant checks via the GUT step instead of per-tool `godot -s` invocations, and `--fast` SHALL mean "GUT only, no console clean". `tools/shell/run_operability.sh` SHALL use `tests/functional/test_scene_boot.gd` instead of `tools/run_scene.gd`.

#### Scenario: CI gate on a broken invariant
- WHEN an invariant is broken (e.g. a parse error in a script)
- THEN `run_all_ci_checks.sh` fails on the GUT step, including in `--fast` mode

#### Scenario: fast mode on a healthy tree
- WHEN `run_all_ci_checks.sh --fast` is run on a healthy tree
- THEN the GUT step (invariants included) passes and the console-clean step is skipped
