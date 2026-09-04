## Purpose

Represent building definitions as data so that adding or editing a building requires no code change, while preserving the existing definition data and the `BuildingDefs` public API.

## ADDED Requirements

### Requirement: Building definitions load from a data file

`BuildingDefs` SHALL load every building definition from a data file instead of hardcoding `static func` builders, exposing the same `def_by_id` and `all` behavior.

#### Scenario: Existing buildings resolve as before
- **WHEN** `def_by_id(&"farm")` is called
- **THEN** it returns the same definition (id, display name, levels, production chain, followers) as before the change

#### Scenario: Adding a building needs no code edit
- **WHEN** a new building entry is added to the data file
- **THEN** it becomes available through `def_by_id` and `all` without modifying any `.gd` file

### Requirement: Definition fields are preserved

Each loaded definition SHALL expose the same fields (`id`, `display_name`, `levels`, `production_chain`, `followers`, `requires_site`) with the same values as the previous hardcoded definitions.

#### Scenario: Production chain data survives the move
- **WHEN** a building's `production_chain` is read
- **THEN** its id, worker count, inputs and outputs match the previous definition
