# asset-archiver Specification

## Purpose

Detects which assets under `game/assets/` are referenced by the game and moves
only the confirmed-unused ones to `_archive`, with a manifest for rollback and a
post-archive operability check.

## Requirements

### Requirement: Reference detection covers static and data-driven paths
The detector SHALL compute the set of "used" asset paths by combining:
- Static `res://assets/...` literals found in `.gd`, `.tscn`, `.tres`, and `.json` files.
- Dynamic paths built via `%`-formatting from in-game data keys (e.g. `res://assets/units/<key>.png`, `res://assets/units/<key>_s.png`, icon paths keyed by artifact/stat id).

The detector MUST know the universe of valid data keys (from the unit/artifact/icon data layer) so that a path built from a real key is treated as used. A path built from a key that does not exist in the data layer is NOT counted as used.

#### Scenario: Dynamic unit path counts as used
- **WHEN** `UnitSprites` builds `res://assets/units/archers.png` from a runtime key, and `archers` is a valid unit key in the data layer
- **THEN** the detector marks `archers.png` as used and never lists it as unused

#### Scenario: Format-string key not in data is not a reference
- **WHEN** the data layer contains no key named `nonexistent_unit`
- **THEN** the detector does NOT treat the template `res://assets/units/%s.png` as a reference to `nonexistent_unit.png`

### Requirement: Unused classification
The detector SHALL treat an asset as unused only when no used path resolves to its exact `res://` path. It SHALL ignore `.import` sidecar files (they always accompany a source asset and are not references). The set of used paths SHALL be deterministic and reproducible across runs.

#### Scenario: Orphan asset is flagged
- **WHEN** no static or data-driven reference resolves to `res://assets/cursors/cursor_32.png`
- **THEN** the detector lists `cursor_32.png` as unused

#### Scenario: Imported sidecars are not reported
- **WHEN** `foo.png` is used but `foo.png.import` also exists on disk
- **THEN** the detector reports only `foo.png` as used and does not flag `foo.png.import` as unused

### Requirement: Dry-run report by default
Running the detector WITHOUT an explicit archive flag SHALL NOT move, rename, or delete any file. It SHALL output a report listing each unused asset with its category (audio / units / artifacts / cursors / textures / tiles / ui / raw / other) and the reason it was considered unused.

#### Scenario: Dry-run is non-destructive
- **WHEN** the detector is run in default mode
- **THEN** no file under `game/assets/` is modified, and the report is printed (and/or written to a file)

### Requirement: Archive with manifest for rollback
When archiving is explicitly requested, the detector SHALL move each confirmed-unused asset into the archive location and write a `manifest.json` recording, for every moved asset: its original `res://` path, the archive destination path, the category, and the detection reason. The manifest SHALL be the single source of truth for rollback. Moving a file SHALL move its `.import` sidecar together.

#### Scenario: Archive moves files and records manifest
- **WHEN** archiving is requested and `cursor_32.png` is confirmed unused
- **THEN** `cursor_32.png` (and `cursor_32.png.import`) is moved to the archive location, and `manifest.json` records its original and destination paths

#### Scenario: Manifest enables rollback
- **WHEN** the manifest is present
- **THEN** every entry can be restored to its original `res://` path, returning the asset tree to the pre-archive state

### Requirement: Post-archive operability verification
After assets are moved, the change SHALL verify the game still runs by reusing the existing `game/tools/shell/run_operability.sh` runner. The run SHALL complete with verdict `CLEAN` (no console errors, no unallowlisted warnings). If the verdict is `DIRTY`, the move SHALL be considered failed and the affected assets SHALL be restored from the manifest before the change is accepted.

#### Scenario: No regression after archiving
- **WHEN** unused assets have been moved and `run_operability.sh` is run
- **THEN** the verdict is `CLEAN`

#### Scenario: Regression triggers rollback
- **WHEN** `run_operability.sh` returns `DIRTY` after an archive
- **THEN** the moved assets are restored from `manifest.json` and the change is not accepted

### Requirement: Safety and confidence gate
The detector SHALL refuse to archive anything it cannot classify with high confidence. Assets referenced only from tool scripts that *generate* assets (e.g. an icon generator writing to `assets/artifacts/`) SHALL NOT by themselves mark those assets used or unused — their status is decided by the real gameplay data layer, and ambiguity SHALL resolve to "keep" (do not archive).

#### Scenario: Ambiguity resolves to keep
- **WHEN** an asset's only references come from a generation tool, not from gameplay data or runtime paths
- **THEN** the detector keeps the asset (does not archive it)
