# Spec Delta

## REMOVED Requirements

### Requirement: Стартовые здания
**Reason**: The fixed Ancient Hearth/Main Warehouse opening belongs to the older standalone settlement model and does not define the canonical campaign city's building roster.
**Migration**: Start-city buildings and stocks are declared by campaign scenario data; equivalent hearth, storage, housing, or administration buildings may remain in the unified catalog when source inventory and campaign role justify them.

### Requirement: Лагеря сбора
**Reason**: The old requirement hard-codes a small Against the Storm camp list and its nearest-node behavior, excluding the requested unified roster and campaign map model.
**Migration**: Gathering buildings are catalog entries whose valid node types, radius, inputs, and outputs are explicit data; campaign map-node semantics remain owned by the map capability.

### Requirement: Производство с одним рецептом
**Reason**: The old requirement hard-codes a small roster and source-specific recipe variants. It is replaced by a shared, source-traceable recipe contract.
**Migration**: Each production building may expose one or more explicit recipes; the active recipe and all costs/outputs are visible and deterministic under `campaign-city-economy`.

### Requirement: Жильё с ценами и улучшениями
**Reason**: The old requirement hard-codes individual Against the Storm species, DLC gates, and house prices.
**Migration**: Housing capacity and archetype compatibility are data-driven; ancestry is not a housing gate. Preserve only campaign-approved upgrade rules in the new catalog.

### Requirement: Сервис и Unified
**Reason**: The old requirement depends on a source-specific DLC building and Amber-like settlement vocabulary.
**Migration**: Service buildings provide declared group needs using registered goods; any combined service building trades off capacity or effectiveness according to its data.

### Requirement: Стройка свободными поселенцами
**Reason**: The source-specific builder-worker cycle is not an established campaign-city rule and would duplicate campaign construction state.
**Migration**: Use the campaign construction contract; this catalog defines construction cost, duration, and prerequisites but does not create a second worker-time system.

### Requirement: Продвинутые здания
**Reason**: The list mixes source-specific Trading Post, Amber, and Rainpunk mechanics with a partial building roster.
**Migration**: Retain adapted building functions only as catalog entries backed by registered resources, campaign needs, and deterministic effects.

## ADDED Requirements

### Requirement: Unified source-traceable building catalog
The source inventory SHALL maintain a version-bounded public-reference manifest. Each observed row SHALL preserve its source name/ID, category, URL, source snapshot, confidence, and disposition. The inventory SHALL distinguish confirmed, candidate, and unknown evidence; it SHALL record unobserved roster areas as coverage gaps instead of fabricating entries. Campaign catalog inclusion SHALL require a confirmed row and an approved campaign role. Candidate/unknown rows remain non-admitted until evidence is added.

#### Scenario: Source coverage audit
- **WHEN** the source manifest and campaign catalog are validated
- **THEN** every observed source row has provenance, confidence, and exactly one disposition
- **AND** every confirmed in-scope row maps to a canonical catalog entry or a documented exclusion
- **AND** candidate/unknown rows remain identified as non-admitted with a reason
- **AND** unobserved source coverage is reported as unknown, not as a completed roster count

#### Scenario: Duplicate source buildings
- **WHEN** two source entries perform the same adapted role
- **THEN** they map to one canonical building or an explicitly data-driven variant
- **AND** the mapping preserves distinct effects only when they change player-visible behavior

#### Scenario: Out-of-scope AoE IV structure
- **WHEN** an AoE IV source entry is a dock, naval producer, landmark/wonder without an eligible campaign class-training or defensive role, or a non-building unit
- **THEN** it is excluded with a recorded reason

### Requirement: Building placement and TerraScape interactions
Buildings SHALL use the campaign city's canonical hex layout. Each building definition SHALL declare its footprint, placement constraints, role, costs, upkeep, jobs, production/service effects, and applicable neighbor interactions. TerraScape-inspired synergies and penalties SHALL be computed from explicit data and shown with their causes. Adjacency values SHALL be signed basis points; aggregated effects SHALL be clamped to ±10,000 basis points.

#### Scenario: Place a compatible building
- **WHEN** the player selects a building and a legal unoccupied site
- **THEN** the building is placed if its cost and prerequisites are satisfied
- **AND** its effects on itself and affected neighbors are recalculated

#### Scenario: Placement is blocked
- **WHEN** the chosen site violates footprint, terrain, district, or prerequisite rules
- **THEN** placement is rejected without changing city state
- **AND** the blocking reason is shown

#### Scenario: Neighbor effect explanation
- **WHEN** a building receives or causes a synergy or penalty
- **THEN** the UI can identify the neighboring building, rule, and resulting value

### Requirement: Building merges preserve city state
A merge SHALL be available only when its declared recipe and spatial conditions are met. Merging SHALL produce the declared resulting building and preserve or explicitly resolve constituent costs, workers, residents, stock, and effects without duplicating value.

#### Scenario: Valid merge
- **WHEN** all required component buildings satisfy the merge recipe and placement conditions
- **THEN** they are replaced by the merged building as one atomic operation
- **AND** the resulting building has the declared footprint and effects

#### Scenario: Invalid merge
- **WHEN** a merge is missing a component or spatial condition
- **THEN** no building or city stock changes
- **AND** the unmet condition is identified

### Requirement: Military buildings support campaign character training
Military buildings SHALL enable only training actions explicitly supported by the campaign's approved class-based character/party model. They SHALL NOT create generic `UnitRegistry` stacks or import AoE IV troop stats. Training SHALL consume registered goods and respect existing party/capacity rules; buildings without an approved training mapping MAY remain infrastructure-only.

#### Scenario: Train an approved campaign class
- **WHEN** a military building's training role is active and its declared prerequisites, costs, and party capacity are satisfied
- **THEN** the canonical campaign character/party pipeline performs the training action
- **AND** the city ledger records the cost and training cause

#### Scenario: Unsupported source troop
- **WHEN** a source building trains a troop role that has no approved campaign class mapping
- **THEN** that troop does not appear as a training choice
- **AND** the source building is either adapted as support infrastructure or explicitly excluded

#### Scenario: Naval unit is not trainable
- **WHEN** a source template represents a naval unit or requires a naval producer
- **THEN** it is absent from the campaign training choices
- **AND** it adds no naval stock, capacity, or battle behavior

### Requirement: Defensive buildings contribute to campaign defense
Static defensive buildings SHALL contribute their declared protection, coverage, or fortification effects to the existing city defense and pressure-based raid resolution. They SHALL NOT resolve as a separate real-time combat mode.

#### Scenario: Raid against fortified city
- **WHEN** a pressure-generated raid targets a city with working defensive buildings
- **THEN** the existing raid resolver applies their declared defense effects
- **AND** the ledger/chronicle identifies which defenses modified the outcome

#### Scenario: Defense building is disabled
- **WHEN** a defensive building is ruined, unstaffed, or otherwise inactive under its data rules
- **THEN** only its declared inactive-state effects apply
- **AND** it provides no active defense bonus
