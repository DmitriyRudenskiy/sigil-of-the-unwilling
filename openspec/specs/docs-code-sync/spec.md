# docs-code-sync Specification

## Purpose

Определяет, как документация `docs/` сверяется с кодом: расхождения обнаруживаются
машиной, а не чтением; разделы про управление, формат сохранений и карта систем
выводятся из фактического кода и ссылаются на него; обратная документация не тянет
код за собой.

## Requirements

### Requirement: Divergence check is a machine gate

Documentation-to-code divergence SHALL be detected by `scripts/audit_docs_vs_code.py`, not by reading. The tool SHALL read facts from `project.godot`, `game/scenes/`, `game/scripts/` and the save schema, and SHALL exit non-zero when a documented reference resolves to no code, or when an autoload, input action, scene or save key is absent from `docs/`.

#### Scenario: Broken reference in docs reddens the gate
- **WHEN** a doc mentions `SomeScreen.gd` and no such file exists in `game/`
- **THEN** the tool exits non-zero
- **AND** it prints the doc path and the unresolved name

#### Scenario: Vendor addons are not game facts
- **WHEN** the tool collects `class_name` declarations
- **THEN** files under `game/addons/` are excluded
- **AND** references to vendored scripts (GdUnit4, godot-mcp) do not count as broken

### Requirement: Control scheme is documented from the input map

The controls section SHALL be derived from `[input]` in `game/project.godot`. Every action name in the map SHALL appear in the docs next to its binding and the screen that consumes it.

#### Scenario: Input map action is named in docs
- **WHEN** `project.godot` declares `camera_up`
- **THEN** a doc names `camera_up` together with its key binding
- **AND** the gate counts the action as documented

#### Scenario: Undocumented action fails the gate
- **WHEN** an action is added to `[input]` and no doc names it
- **THEN** the gate exits non-zero

### Requirement: Save format is documented from the save schema

The save section SHALL describe the format produced by the actual save code (`scripts/campaign/save/mvp_save_schema.gd`, `mvp_save_manager.gd`), listing the top-level keys the schema writes and their writers.

#### Scenario: Schema key is described
- **WHEN** the schema writes a top-level key such as `population`
- **THEN** the docs name the key and the system that owns it
- **AND** no doc describes a key the schema never writes

### Requirement: System map is the shared basis

A system map document SHALL list autoloads with responsibilities, layer boundaries, signal channels and the save pipeline. Other docs SHALL link to it instead of restating the same inventory.

#### Scenario: Autoload appears once
- **WHEN** an autoload is added to `project.godot`
- **THEN** the system map lists it with its responsibility and file path
- **AND** other notes link to the map rather than duplicating the list

### Requirement: Reverse documentation cites its source

Every restored section SHALL name the code it was derived from — script, class or scene path — so a later reader can re-verify without re-deriving.

#### Scenario: Claim carries a source
- **WHEN** a section describes how the battle field is fitted to the window
- **THEN** it names `scripts/systems/battle_view.gd` as the source

#### Scenario: Documented behaviour absent from code is registered
- **WHEN** a doc describes a system the code does not contain
- **THEN** the claim is marked and a ticket is registered
- **AND** the code is not changed to match the doc

### Requirement: Documentation work is recorded

Every documentation change SHALL be recorded in `docs/CHANGELOG.md` with the audit numbers before and after the change.

#### Scenario: Changelog carries measured deltas
- **WHEN** the docs are updated for a slice
- **THEN** the changelog entry states the gate counts before and after
- **AND** lists which sections were rewritten and why
