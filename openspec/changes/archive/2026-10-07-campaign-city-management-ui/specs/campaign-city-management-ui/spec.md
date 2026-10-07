# Spec Delta

## Purpose

Defines the player-facing management surface for the canonical campaign city. The screen makes the existing 52-hex layout, audited building catalog, construction status, and shared resource flows inspectable and actionable without adding a second city mode or economy.

## ADDED Requirements

### Requirement: Campaign city overview renders canonical city state
The management screen SHALL render the selected campaign city using its existing 52-cell geometry, terrain, building instances, and current selection. It SHALL distinguish the four-cell core from rings I–III and SHALL show occupied, empty, and currently selected cells without changing city state during inspection. It SHALL NOT present a separate score mode or city-tier progression.

#### Scenario: Open the campaign city
- **WHEN** the player opens management for a city
- **THEN** the screen shows that city's existing hex layout, buildings, and selected-city identity
- **AND** building and cell visuals correspond to the current saved/runtime state
- **AND** no additional city instance or progression state is created

#### Scenario: Inspect a cell without building
- **WHEN** the player selects or hovers an empty or occupied cell
- **THEN** the screen identifies its available terrain/site state and relevant building, if any
- **AND** merely inspecting it does not change resources, buildings, or turn state

### Requirement: Resource and population HUD uses live campaign values
The HUD SHALL display only registered MVP campaign resources (`food`, `wood`, and `iron`) and live city population/housing values. It SHALL show per-turn net changes and a breakdown only when those values can be derived from the shared ledger or existing city reports. It MAY show satisfaction per populated campaign group from persisted group state, but SHALL NOT synthesize a single happiness percentage when the simulation does not define one. It SHALL NOT represent Gold, Stone, score, or guessed values as campaign resources or currencies. Values unavailable from the current city state SHALL be omitted or explicitly marked unavailable, never filled with mock defaults.

#### Scenario: Display city economy
- **WHEN** the management screen opens for a city with campaign resources and a turn report
- **THEN** the HUD shows current registered resource balances and the corresponding reported net flows
- **AND** selecting a resource explains its contributing ledger flows

#### Scenario: A value has no canonical source
- **WHEN** a prototype label or value has no corresponding registered resource or campaign state
- **THEN** it is not shown as a live game value
- **AND** the screen does not substitute a hard-coded or source-game value

#### Scenario: Group satisfaction display
- **WHEN** the city has persisted satisfaction values for populated campaign groups
- **THEN** the HUD or society inspector displays them per group with their group labels
- **AND** it does not combine them into an unapproved city-wide happiness score

### Requirement: Building catalog cards reflect validated campaign definitions
The build panel SHALL list only entries admitted by the validated campaign building catalog. Category filters SHALL be displayed as keyboard-accessible horizontal tabs above the cards and SHALL group only roles present in the validated catalog. Each card SHALL establish a clear typographic hierarchy among building name, role, effects, requirements, and status; construction cost SHALL receive the strongest secondary emphasis using registered resource icons, clear quantities, and a distinct but accessible treatment. The card SHALL still show campaign-authored cost, role/effect summary, prerequisites, and construction duration from the definition. Locked, blocked, affordable, and unaffordable states SHALL be distinguishable by text/icon as well as color, with a clear reason for any blocked selection.

#### Scenario: Browse available buildings
- **WHEN** the player opens a build category
- **THEN** cards are populated from validated catalog entries in that category
- **AND** no `candidate`, `unknown`, placeholder, or source-only balance row appears

#### Scenario: Building is unavailable
- **WHEN** a catalog building cannot be constructed because of a prerequisite, site, or resource shortage
- **THEN** its card remains inspectable
- **AND** the unmet condition and exact missing resource quantity are shown
- **AND** the build action cannot commit

### Requirement: Placement preview and confirmation use the construction contract
Selecting a build card SHALL enter placement preview on the existing city grid. The preview SHALL distinguish valid and invalid footprints, identify the blocking reason, and preserve the selected building until placement succeeds or the player cancels. Confirmation SHALL submit one request to the campaign construction service; the interface SHALL NOT debit resources, append buildings, advance construction, or resolve adjacency independently.

#### Scenario: Valid placement preview
- **WHEN** the player hovers a legal unoccupied footprint for the selected building
- **THEN** the footprint is previewed as valid and the catalog-derived cost and effect summary remain visible

#### Scenario: Invalid placement preview
- **WHEN** the selected footprint violates city bounds, occupancy, terrain, prerequisites, or available resources
- **THEN** the preview is visibly invalid and states the blocking reason
- **AND** confirming it leaves city state and the shared ledger unchanged

#### Scenario: Confirm construction
- **WHEN** the player confirms a valid site
- **THEN** the construction service performs the existing atomic request
- **AND** the screen reflects the returned result and construction progress from city state
- **AND** the UI does not apply costs or effects a second time

### Requirement: Building inspection explains current effects
Selecting an existing campaign building SHALL show its current activity/construction state, catalog-defined role, costs/upkeep, and available production/service/training/defense effects. Where the simulation exposes a cause breakdown, the screen SHALL identify the contributing resource flows, prerequisite, adjacency rule, or state effect using that breakdown. The screen SHALL NOT offer manual worker assignment or source-game actions unless those are separately enabled by campaign rules.

#### Scenario: Inspect a working building
- **WHEN** the player selects an active campaign building
- **THEN** the inspector shows its live state and declared campaign effects
- **AND** available cause details match the current simulation report

#### Scenario: Inspect construction or inactive state
- **WHEN** the selected building is under construction, inactive, or ruined
- **THEN** the inspector shows that exact state and its applicable progress/effects
- **AND** it does not imply active production, training, or defense that the simulation suppresses

### Requirement: Prototype-matched, responsive city layout
At the supplied prototype viewport, the screen SHALL preserve its visual composition: compact category navigation and build catalog on the left, resource HUD across the top, central 52-hex city view, contextual selected-cell feedback, and terrain legend at lower right. The screen SHALL support the actual prototype image size (1920×1200), the written 1920×1080 design viewport, and a minimum of 1280×720; at narrow desktop sizes the catalog SHALL collapse to an icon rail without obscuring the selected city view. The world backdrop around the city SHALL remain subtly visible through a dark translucent overlay, not be replaced by solid black. Panels and labels SHALL not overlap, clip, or make required controls unreachable.

#### Scenario: Compare at prototype size
- **WHEN** a deterministic city state is displayed at 1920×1200
- **THEN** a captured screenshot can be compared side-by-side with the supplied prototype for region placement, proportions, palette, and visual hierarchy
- **AND** the visual-review sample displays every available source-backed building sprite without persisting showcase placements into game state
- **AND** canonical live labels and values replace prototype-only labels and values

#### Scenario: Minimum desktop size
- **WHEN** the viewport is 1280×720
- **THEN** the build catalog can collapse to its rail and be restored
- **AND** all required controls and the active city selection remain visible and operable

### Requirement: Calm, accessible interaction feedback
The interface SHALL provide distinct default, hover, pressed, selected, disabled, valid-placement, and invalid-placement states. Color SHALL be supplemented with text, icons, or shape cues; readable text SHALL meet WCAG AA contrast (4.5:1). Tooltips SHALL be available on pointer hover after the specified delay and by keyboard focus; primary interaction feedback SHALL complete within 150 ms, and information transitions SHALL not exceed 500 ms. All build, inspect, cancel, collapse, and turn-navigation actions available on this screen SHALL be keyboard reachable, with Escape cancelling placement or closing the relevant panel before leaving the city screen.

#### Scenario: Hover or keyboard focus
- **WHEN** a building card or resource control is hovered or keyboard-focused
- **THEN** its state is clearly indicated and its explanatory tooltip appears after the configured delay
- **AND** the same information is available without relying on color alone

#### Scenario: Cancel placement
- **WHEN** the player presses Escape during placement preview
- **THEN** preview is dismissed without changing city state
- **AND** the player returns to normal city inspection
