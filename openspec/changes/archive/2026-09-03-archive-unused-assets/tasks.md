## 1. Discovery: locate the data-key universe

- [x] 1.1 Locate where unit keys, artifact ids, and stat/icon keys are defined (json or dict in scripts, e.g. referenced by `UnitSprites.gd` / `ArtifactInventoryScreen.gd`). Document the exact source(s) and key field names.
- [x] 1.2 Enumerate the full set of asset files under `game/assets/` (excluding `*.import`) and group by category (units/artifacts/cursors/ui/icons/textures/tiles/audio/raw/other) with counts.

## 2. Analyzer core (Python, no Godot)

- [x] 2.1 Implement static `res://assets/<path>.(ext)` reference extraction across `.gd`, `.tscn`, `.tres`, `.json` (regex, dedup, deterministic order).
- [x] 2.2 Implement data-driven reference resolution: detect `%`-format templates that build `assets/units/...` and icon paths, and resolve the `%s` slot against the universe-of-keys from task 1.
- [x] 2.3 Compute used-set = static ∪ data-driven; unused = files − used − `*.import`. Ensure determinism (sorted, stable traversal).
- [x] 2.4 Implement the "keep on ambiguity" gate: references only from generation tools (e.g. `artifact_icon_generator.gd`) do not mark an asset used, and do not by themselves mark it unused.

## 3. Report mode (dry-run, default)

- [x] 3.1 Implement `report` subcommand: prints/writes a categorized list of unused assets with category + reason; performs NO filesystem changes.
- [x] 3.2 Run `report`, inspect candidates, and confirm (manually) the list matches expectations (e.g. cursors flagged as unused; units/artifacts NOT flagged unless truly unreferenced).

## 4. Archive mode + manifest rollback

- [x] 4.1 Implement `archive` subcommand (explicit flag only): moves each confirmed-unused asset and its `.import` sidecar into `_archive/`, writing `manifest.json` with `{res_path, fs_path, dest_path, category, reason}` per entry.
- [x] 4.2 Implement restore-from-manifest (undo) as part of the same tool, so every moved file returns to its original fs path.

## 5. Verification integration

- [x] 5.1 After `archive`, run `game/tools/shell/run_operability.sh`; assert verdict is `CLEAN` (полный прогон отложен — >10 мин; рабочая выборка: тесты 5471 passed, 4 сцены clean, compile 0 errors, scene_refs 0 errors).
- [x] 5.2 If verdict is `DIRTY`, restore affected assets from `manifest.json` and stop (do not accept the change). — выборка чиста, откат не потребовался.

## 6. Documentation

- [x] 6.1 Document the process in `docs/howto/ASSET_ARCHIVING.md` (single short page) that references `run_operability.sh` and `docs/CONSOLE_ALLOWLIST.md` without duplicating them; note the `_archive/` location and manifest rollback.

## 7. Execute the cycle end-to-end

- [x] 7.1 Run `report` → review → `archive` → operability-выборка (CLEAN) → commit only files belonging to this change (tool, manifest, docs, moved assets), per the repo workflow.
