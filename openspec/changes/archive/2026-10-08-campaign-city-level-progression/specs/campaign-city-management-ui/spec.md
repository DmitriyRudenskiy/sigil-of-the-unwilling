# Spec Delta

## MODIFIED Requirements

### Requirement: Campaign city overview renders canonical city state
The management screen SHALL render the selected campaign city using its existing 52-cell geometry, terrain, building instances, and current selection. It SHALL distinguish the four-cell core from rings I–III and SHALL show occupied, empty, and currently selected cells without changing city state during inspection. The screen SHALL display the campaign city level and occupied building-cell allowance without creating a separate score mode or city instance.

#### Scenario: Open the campaign city
- **WHEN** the player opens management for a city
- **THEN** the screen shows that city's existing hex layout, buildings, and selected-city identity
- **AND** building and cell visuals correspond to the current saved/runtime state
- **AND** the current campaign level and occupied-cell allowance are visible
- **AND** no additional city instance or progression state is created

#### Scenario: Inspect a cell without building
- **WHEN** the player selects or hovers an empty or occupied cell
- **THEN** the screen identifies its available terrain/site state and relevant building, if any
- **AND** merely inspecting it does not change resources, buildings, or turn state

## ADDED Requirements

### Requirement: Campaign level allowance and level-up are visible and actionable
The city HUD SHALL show the campaign city level, occupied city cells, and the allowance for that level. It SHALL provide an accessible level-up action when the current allowance is full and the city is below level 11. When level-up or construction is blocked by the allowance, the screen SHALL explain the current and required cell counts. A blocked action SHALL NOT change city state or the shared resource ledger.

#### Scenario: Level-up becomes available
- **WHEN** the campaign city fills its current occupied-cell allowance
- **THEN** the HUD enables the next-level action and shows the next allowance
- **AND** activating it advances the city by exactly one level

#### Scenario: Level-up is blocked by unused allowance
- **WHEN** the player requests a level-up before filling the current allowance
- **THEN** the HUD reports the remaining number of cells required
- **AND** the city level and resource ledger remain unchanged

#### Scenario: Construction exceeds the allowance
- **WHEN** a selected footprint would exceed the current-level allowance
- **THEN** the placement preview is shown as invalid with used/maximum city-cell counts
- **AND** confirmation does not spend resources or add a building
