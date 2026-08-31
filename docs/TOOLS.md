# Development Tools

This document lists the scripts and tools available in the project for asset
processing, analysis, static checks, benchmarking, and development.

All tools live under `tools/` — the single home for the project's tooling.

## Layout

```
tools/
├── shell/                 # shell orchestrators (CI + scenario runners)
├── spell_validation/       # spell JSON validator + report model
├── texture_slicer/        # texture-slicer core (clustering + preview)
├── scenarios/             # Python scenario generators (collect / flee)
├── archived/              # retired builders + superseded asset/analysis drafts
└── *.py  /  *.gd  /  *.sh # flat, self-descriptive tool scripts
```

## Shell scripts (orchestration)

| Script | Purpose |
|---|---|
| `tools/shell/run_all_ci_checks.sh` | Full CI: compile-all → scene-refs → spell validation → tileset integrity → unit tests. `--fast` skips the unit-test step; `--tests` runs only the suite. **Auto-bootstraps the `class_name` registry** (`.godot/global_script_class_cache.cfg`) via `godot --editor` if missing, so a clean checkout runs out of the box. Failure is detected from the log (`SCRIPT ERROR:`, `Failed to load script`, `Could not find type`, `does not inherit from`, `RESULT: FAILED`, `SOME TESTS FAILED`), not the exit code (Godot returns 0 even when a script fails to load). |
| `tools/shell/play_scenario.sh` | Runs a scenario end-to-end over the live socket (default N=1). `--log <file>` sets the log path. |
| `tools/lint.sh` | Static linter: compile-all → scene-refs → grep regressions. `--runtime` adds a World.tscn smoke run. |

## Python scripts (asset pipeline & analysis)

| Script | Purpose |
|---|---|
| `process_assets.py` | Asset pipeline: biome classification, hexagon mask, resize, and categorize into `data/processed`. Superseded drafts (v2…v7) live in `archived/`. |
| `make_grid.py` | Builds sprite sheets by arranging images into a grid. |
| `organize_assets.py` | Color-based clustering that sorts raw textures into biome folders. |
| `compress_image.py` | Batch image compression / size reduction. |
| `asset_slicer.py` | Drives the texture slicer from Python. |
| `units_cutter_v2.py` | Splits unit sprite sheets into frames. |
| `extract_cursors.py` | Extracts cursor sprites from source art. |
| `generate_map_preview.py` | Renders a procedural map preview to validate biome distribution. |
| `biome_showcase.py` | Produces a visual showcase of processed biomes and their combinations. |
| `analyze_texture_pairs_v2.py` | Compares two textures for visual weight, color harmony, transition quality. (`analyze_texture_pairs.py` and per-image probes are in `archived/`). |
| `analyze_artifacts.py` | Analyzes artifact assets. |
| `ai_agent.py` | Socket-based Godot client (AI agent that talks to the game). |

## Godot CI / dev tools (GDScript)

| Tool | Purpose |
|---|---|
| `compile_all.gd` | Headless compile of every `.gd` — catches parse errors and broken `preload`s. |
| `check_scene_refs.gd` | Verifies all `ext_resource`/`sub_resource` paths in scenes resolve. |
| `check_tileset.gd` | Checks tileset integrity (`.tres`/`.atlas` consistency). |
| `spell_validation/validate_spells.gd` | Validates spell definitions against `data/` JSON (with `--strict --json`). |
| `spell_validation/SpellValidator.gd` | Validator logic used by `validate_spells.gd`. |
| `spell_validation/ValidationReport.gd` | Structured report model for the validator. |
| `benchmark_all.gd` | Profiler: map generation, spell registry, JSON stringify (run at 60×60). |
| `memory_profile.gd` | Captures resource/RID allocation stats at exit. |
| `dump_unit_report.gd` | Dumps a report of unit definitions. |
| `tune_city_arena.gd` | Tuning harness for the city arena. |

## Godot asset / texture tools (GDScript)

| Tool | Purpose |
|---|---|
| `tileset_builder.gd` | Main tool: generates Godot `.tres` tilesets from processed base + object textures. |
| `texture_slicer/BiomeClusterer.gd` | Groups textures into biome clusters by color similarity. |
| `texture_slicer/SlicerCore.gd` | Core slicing logic. |
| `texture_slicer/PreviewRenderer.gd` | Renders biome-transition and cluster-distribution previews. |
| `biome_preview_tool.gd` | In-editor biome preview tool. |
| `texture_preview_tool.gd` + `texture_preview_plugin.gd` + `texture_preview_dock.gd` (+ `.tscn`) | In-editor texture-preview plugin and dock UI. |
| `artifact_icon_generator.gd` | Generates artifact icons. |
| `sound_synth.gd` | Procedural sound synthesis. |
| `binom_cutter.gd` | Biome/cutter helper for sprite sheets. |
| `test_screenshot_extraction.gd` / `test_slicer.gd` | Test helpers for screenshot extraction and slicing. |

## Archived (`tools/archived/`)

Retired tileset-builder and normalizer scripts, plus superseded asset-pipeline
and analysis drafts, kept for reference and excluded from imports via `.gd.ignore`:

`hex_normalizer.gd`, `normalizer_runner.tscn`, `run_normalizer.gd`,
`run_tileset_builder.gd`, `run_tileset_builder_v2.gd`,
`tileset_builder_runner.tscn`, `tileset_builder_v2_runner.tscn`, `README.md`,
`process_assets_v2.py … v7.py`, `process_assets_final.py`,
`analyze_image.py`, `analyze_second_image.py`, `analyze_second_image_compressed.py`,
`analyze_texture_pairs.py`.

## Running

Most dev tools are run from the Godot project root `game/` (the `tools/`
folder below is `game/tools/`), e.g.:

```bash
cd game
bash tools/shell/run_all_ci_checks.sh        # full CI
bash tools/lint.sh                            # static analysis + runtime
python3 tools/process_assets.py               # asset pipeline
```

The Godot project root is `game/` (`game/project.godot`); all in-game
`res://` paths resolve against it, and dev tooling under `game/tools/`
is referenced relative to `game/`. Godot invocations that touch in-game
resources use `--path game` when run from the repository root.

### The `class_name` registry (read this before headless runs)

The project uses `class_name` heavily (~91 classes). GDScript resolves these names
against a **global registry** file `.godot/global_script_class_cache.cfg`.

- **Headless `-s` runs and plain imports do NOT write this registry** — it is built
  only by the **editor** (`godot --headless --path game --editor`). Without a
  pre-built registry every check fails with `SCRIPT ERROR: Parse Error: Could not
  find type "BattleState" in the current scope` and `Failed to instantiate an
  autoload … does not inherit from 'Node'`.
- **`run_all_ci_checks.sh` handles this automatically**: if the registry file is
  missing it runs the editor import once (with a 240 s timeout — the editor import
  is cut off while loading its UI layout, but the cache is written before that) and
  only then runs the checks. **A clean checkout works out of the box.**
- **Mandatory cache clearing:** if checks start failing with `Could not find type X`
  after file moves, renames, or `class_name` changes, run `rm -rf game/.godot` and
  re-run CI (it rebuilds the registry). Stale registry entries cause false errors.
- **Timeout everything:** macOS has no `timeout` command, and a hung scene/script
  spins the main loop forever. Always wrap Godot invocations in a background+kill
  wrapper (see `AGENT.md` §8.1 / the `runwt.sh` helper).
