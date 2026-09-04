## 1. GUT invariant tests (`game/tests/functional/`)

- [x] 1.1 Create `tests/functional/test_compile_all.gd` — port `tools/compile_all.gd`: compile every `res://` GDScript (skip `.git`, `.godot`, `addons`, `tools`, `tests`; `can_instantiate()` gate); assert zero errors, list failing files in the assertion message.
- [x] 1.2 Create `tests/functional/test_scene_refs.gd` — port `tools/check_scene_refs.gd`: ext_resource regex `path="(res://[^"]+)"`, scan `res://scenes` + `res://tools`, `PackedScene` load + path-existence check; assert zero broken refs.
- [x] 1.3 Create `tests/functional/test_tileset_integrity.gd` — port `tools/check_tileset.gd`: load `world_tiles.jpeg`, `TileAtlas.build_hex_tileset()`, assert texture present and `source_count > 0`.
- [x] 1.4 Create `tests/functional/test_scene_boot.gd` — port `tools/run_scene.gd`: headless-boot `MainMenu`, `CityArena`, `World`, `Battle` scenes; assert each instantiates without script errors.
- [x] 1.5 Create `tests/functional/test_benchmarks.gd` — port `tools/benchmark_all.gd` (five benchmarks: map gen, spell registry, serialization, placeholder texture, JSON parse) with the old threshold constants as assertions.
- [x] 1.6 Create `tests/functional/test_memory_profile.gd` — port `tools/memory_profile.gd` (five operations); assert each memory delta is finite and > 0 (direction/sanity, not exact KB).
- [x] 1.7 Extend `tests/test_unit_registry.gd` — add the `dump_unit_report.gd` assertions: unit count > 100 (registry has 142), every unit hp > 0, spd ≥ 1, atk ≥ 0, dmg ≥ 0, tags are non-empty strings. No `UNIT_REPORT.txt` side effect.
- [x] 1.8 Move `game/tools/spell_validation/{SpellValidator.gd,ValidationReport.gd,baseline.json}` → `game/tests/spell_validation/`; update `tests/test_spells_json.gd` preload to `res://tests/spell_validation/SpellValidator.gd`.
- [x] 1.9 Extend `tests/test_spells_json.gd` — strict-parity test: validate `res://assets/data/spells.json`, fail on any error **or** warning (old CI `--strict` semantics).

## 2. Build scripts (`game/scripts/build/`)

- [x] 2.1 Create `scripts/build/gen_artifact_icons.gd` — faithful port of `tools/artifact_icon_generator.gd` (64×64, per-`Artifact.Slot`/`Artifact.Rarity` drawing, PNG per artifact → `res://assets/artifacts/`, count printed); `extends SceneTree`, `quit(0)` on completion.
- [x] 2.2 Create `scripts/build/gen_sound_wav.gd` — faithful port of `tools/sound_synth.gd` (five 16-bit WAVs incl. 4.0 s `bgm_loop` → `res://assets/audio/`).
- [x] 2.3 Create `scripts/build/gen_inventory_scene.gd` — faithful port of `tools/gen_inventory_scene.gd` (structural `ArtifactInventoryScreen.tscn` skeleton, doll-slot offsets, script ext_resource); self-contained `extends SceneTree` entry.
- [x] 2.4 Create `scripts/build/tune_city_arena.gd` — faithful port of `tools/tune_city_arena.gd` (hill-climber over `ArenaBalance`, `--evals/--seed/--turns/--dry-run/--report`, file write suppressed by `--dry-run`).

## 3. CI / operability

- [x] 3.1 `tools/shell/run_all_ci_checks.sh`: remove the four `godot -s tools/{compile_all,check_scene_refs,spell_validation/validate_spells,check_tileset}.gd` steps (invariants now run in the GUT step); redefine `--fast` as "GUT only, no console clean" and update its comment.
- [x] 3.2 `tools/shell/run_operability.sh`: replace the `-s tools/run_scene.gd` scene launches with a GUT run of `res://tests/functional/test_scene_boot.gd` (`gut_cmdln.gd -gtest=res://tests/functional/test_scene_boot.gd -gexit`).

## 4. Deletions

- [x] 4.1 Delete the 11 `game/tools/*.gd` tools: `artifact_icon_generator.gd`, `benchmark_all.gd`, `check_scene_refs.gd`, `check_tileset.gd`, `compile_all.gd`, `dump_unit_report.gd`, `gen_inventory_scene.gd`, `memory_profile.gd`, `run_scene.gd`, `sound_synth.gd`, `tune_city_arena.gd` (+ their `.uid` files).
- [x] 4.2 Delete `game/tools/gen_runner.tscn` (after 2.3 — its `ext_resource` pointed at the old tool path).
- [x] 4.3 Delete `game/tools/spell_validation/` (after the 1.8 move; the `validate_spells.gd` CLI wrapper is not ported — strict semantics live in the 1.9 test).
- [x] 4.4 Delete `game/tools/godot-mcp/` (build/, src/, package.json, package-lock.json, server.json, SETUP.md) and root `.mcp.json` (only entry was the vendored bridge).
- [x] 4.5 Delete orphan `game/tests/test_tile_atlas.gd.uid`; confirm `tools/shell/`, `tools/scenarios/`, `tools/comfy/`, `tools/archived/`, `tools/lint.sh`, and the `.py` tools remain intact.

## 5. Docs

- [x] 5.1 `AGENT.md` §8: remove the `tools/compile_all.gd`, `tools/check_scene_refs.gd`, `validate_spells.gd --strict --json`, `tools/check_tileset.gd` command blocks; note that invariants run as GUT tests under `res://tests/functional/`; update the `--fast` semantics line.
- [x] 5.2 `AGENT.md` §13: remove the vendored godot-mcp "Full Control" section; keep `mcp_interaction_server.gd` documented as the optional dev-only TCP runtime interface (remote GDScript execution, 127.0.0.1:9090, never in CI/release).
- [x] 5.3 `docs/howto/TOOLS.md`: point references at the new entry points (`scripts/build/` scripts, GUT invariant tests) instead of the deleted `tools/*.gd` paths.
- [x] 5.4 Confirm `docs/CONSOLE_ALLOWLIST.md` needs no change (it references `tools/shell/` only).

## 6. Verify

- [x] 6.1 Full GUT run green (`godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`): all previous tests plus the new ones, marker `All tests passed!`.
- [x] 6.2 `bash game/tools/shell/run_all_ci_checks.sh --fast` green (GUT step covers the invariants).
- [x] 6.3 Smoke-run each build script once headless (2.1–2.4): verify WAV files, icon PNGs, generated `.tscn`, tuner `--dry-run` report.
- [x] 6.4 `openspec validate dev-tooling-rebuild` → valid.
