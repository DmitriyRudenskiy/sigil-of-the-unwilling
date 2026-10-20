# settlement-buildings Specification

> **Синк 2026-10-20 (campaign-city-building-economy).** Pre-pivot требования
> (Hearth/Warehouse, лагеря, жильё, сервис/Unified и др.) **REMOVED**
> (Reason/Migration — в дельте change); pre-pivot контент — носитель правила
> для 1.0 (доки 02e*, git-история). Пост-пивот требования ниже — текущий
> контракт capability.

## Purpose
Определяет здания кампании: единый source-traceable каталог зданий,
размещение и взаимодействие с TerraScape, сохранение состояния города при
мержах каталога, военные здания как источники class-based обучения и
защитные здания как вклад в оборону кампании.
## Requirements

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
