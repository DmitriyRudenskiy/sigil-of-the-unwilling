# Spec Delta

## Purpose

Defines the campaign city's shared resource ledger and deterministic production contract. It ensures that buildings, population needs, class-based character training, upkeep, and raids consume or produce values in one traceable economy rather than separate game-mode currencies.

## ADDED Requirements

### Requirement: Campaign city uses the canonical resource ledger
The campaign city SHALL store resources and goods as natural quantities in the canonical Layer-1 / Layer-2 registry. The MVP SHALL use the declared registry subset; a building SHALL NOT introduce score, Amber, Resolve, or an unregistered item as a spendable currency. Analytical values MAY be derived from stock and flow but SHALL NOT be used in transactions or unlock checks.

#### Scenario: Valid production transaction
- **WHEN** a city building completes a production cycle
- **THEN** registered inputs are subtracted and registered outputs are added as natural quantities
- **AND** the transaction records its source building and cycle

#### Scenario: Unknown resource in building data
- **WHEN** a building definition references an item absent from the active resource registry
- **THEN** the catalog reports the invalid reference and the definition is unavailable
- **AND** no substitute currency is silently created

#### Scenario: Derived wealth is displayed
- **WHEN** the UI or pressure system requests a wealth metric
- **THEN** the value is derived from traceable stock and flow data
- **AND** it cannot be spent or used as a building prerequisite

### Requirement: Production chains resolve deterministically
Production SHALL resolve from the current city state, assigned workers, available inputs, building condition, and declared modifiers. Identical state and actions SHALL produce identical resource flows; random production rolls SHALL NOT be used.

#### Scenario: Recipe completes
- **WHEN** a working building has sufficient registered inputs and assigned workers
- **THEN** it consumes the recipe inputs and adds the declared outputs for the cycle
- **AND** the flow report identifies the recipe and all applied modifiers

#### Scenario: Input shortage
- **WHEN** a building lacks one or more required inputs
- **THEN** it produces no output requiring those inputs
- **AND** the shortage and blocked recipe are visible to the player

#### Scenario: Repeatable turn
- **WHEN** two simulations start from the same city state and receive the same player actions
- **THEN** both produce identical ordered city flows for every turn

### Requirement: Economy effects are auditable
Every resource change caused by a building, citizen need, construction, character training, upkeep, trade, or raid SHALL be attributable to a named cause and source entity. A transaction that cannot be paid SHALL leave all participating stocks unchanged.

#### Scenario: Insufficient construction stock
- **WHEN** the city attempts to construct a building without enough of any required input
- **THEN** construction does not begin and no resource is deducted
- **AND** the missing quantities are reported

#### Scenario: Turn ledger
- **WHEN** a city turn resolves
- **THEN** the ledger exposes production, consumption, upkeep, training, and raid losses separately
- **AND** the ending stock equals starting stock plus all recorded flows
