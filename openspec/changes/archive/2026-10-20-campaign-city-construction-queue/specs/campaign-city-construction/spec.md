# Spec Delta

## Purpose

Provides deterministic construction for audited campaign buildings in the existing 52-hex city. Construction uses the unified building catalog, current resource ledger, existing placement rules, and city save state rather than adding another settlement or currency system.

## ADDED Requirements

### Requirement: Campaign construction validates and pays atomically
The system SHALL accept a construction request only for an audited catalog entry whose prerequisites are met and whose footprint is valid and unoccupied in the 52-hex city. The system SHALL spend only registered catalog costs through the city's shared `ResourceContext`; a rejected request SHALL leave resources, ledger, and city buildings unchanged.

#### Scenario: Valid construction request
- **WHEN** the requested catalog building has satisfied prerequisites, a valid site, and sufficient registered stock
- **THEN** the declared costs are committed once to the city ledger
- **AND** one construction instance is created at that site

#### Scenario: Rejected request
- **WHEN** prerequisites, placement, catalog data, or resource stock are invalid
- **THEN** the request is rejected with a reason
- **AND** no stock is deducted and no construction instance is added

### Requirement: Construction resolves by declared duration
The system SHALL use only the catalog entry's non-negative `construction_turns`. A zero-turn building SHALL activate when the request succeeds; a positive-duration building SHALL remain non-producing, non-trainable, and non-defensive until its progress reaches zero. Each established campaign turn SHALL advance progress exactly once, and a completed building SHALL activate exactly once.

#### Scenario: Immediate building
- **WHEN** a valid building declares zero construction turns
- **THEN** it is active after the request
- **AND** it may participate in later eligible phases of that turn

#### Scenario: Multi-turn building
- **WHEN** a valid building declares a positive duration
- **THEN** it cannot produce, charge upkeep, train characters, or contribute defense while construction is incomplete
- **AND** it becomes active after the declared number of turn advances

### Requirement: In-progress construction survives save/load
The system SHALL persist each construction instance's identity, site, paid costs, and remaining turns in the existing city save. Loading a legacy save without construction progress SHALL preserve its current buildings without inventing an unfinished job; repeated load/migration SHALL not spend costs again or advance time.

#### Scenario: Resume construction
- **WHEN** a city is saved with an in-progress construction and loaded again
- **THEN** the same instance resumes with the same remaining turns and location
- **AND** only a later campaign turn advances its progress

#### Scenario: Legacy city save
- **WHEN** a pre-construction city save is loaded
- **THEN** existing buildings and stocks remain unchanged
- **AND** no construction costs or progress are synthesized
