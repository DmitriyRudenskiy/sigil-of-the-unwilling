# Spec Delta

## REMOVED Requirements

### Requirement: Семь видов с полной статистикой
**Reason**: The fixed human/beaver/lizard/harpy/fox/frog/bat roster is an older source-game settlement model, not the campaign's population taxonomy.
**Migration**: Simulated residents use the seven campaign economic archetypes; source-game species statistics are inspiration only and are not copied as a competing roster.

### Requirement: Определения статистик
**Reason**: Base Resolve, Demand, Decadence, Hunger Tolerance, and Break Interval are coupled to the removed species/reputation loop.
**Migration**: Group needs, production preferences, and satisfaction parameters are defined in the campaign-city population and economy capabilities.

### Requirement: Караван не более чем из трёх видов
**Reason**: The source game's three-species settlement cap does not fit the campaign city, where races/groups are not selected through an Against the Storm caravan.
**Migration**: Campaign scenario and migration rules determine which archetypes can be present; this capability does not impose a three-group cap.

### Requirement: Специализации поселенцев
**Reason**: The source-specific 10% double-yield roll is incompatible with the deterministic campaign economy.
**Migration**: Work preferences and specialization effects are deterministic modifiers defined by archetype/building data; no random double-production roll is used.

## ADDED Requirements

### Requirement: Seven economic archetypes drive population simulation
The city SHALL simulate residents by the seven canonical economic archetypes: Инженеры & Строители, Земледельцы & Пивовары, Алхимики & Хранители Пламени, Ткачи & Ремесленники, Торговцы & Дипломаты, Охотники & Следопыты, Металлурги & Техники. A resident's ancestry MAY be retained as identity metadata but SHALL NOT create a parallel needs, housing, or production simulation.

#### Scenario: Resident archetype is resolved
- **WHEN** a resident with a known ancestry enters the city
- **THEN** the city assigns or receives the resident's canonical economic archetype
- **AND** city simulation uses that archetype while preserving ancestry for display or narrative

#### Scenario: Unknown ancestry mapping
- **WHEN** a resident's ancestry has no configured archetype mapping
- **THEN** the resident receives the configured neutral/fallback archetype or is rejected by scenario validation
- **AND** the choice is explicit and deterministic

#### Scenario: Ancestry does not duplicate mechanics
- **WHEN** two residents share an archetype but have different ancestry metadata
- **THEN** their group-level city needs and work preferences are evaluated by the same archetype rules
- **AND** ancestry-specific effects apply only when separately declared as campaign character data

### Requirement: Archetypes define needs and work preferences, not hard job locks
Each archetype SHALL declare its city needs, eligible/specialized building roles, and deterministic production or satisfaction modifiers. A resident SHALL remain assignable outside its preferred role unless a building or scenario explicitly defines a hard requirement.

#### Scenario: Preferred work role
- **WHEN** a resident works in a building role preferred by its archetype
- **THEN** the declared deterministic work modifier applies to that building's production
- **AND** the modifier is visible in the production breakdown

#### Scenario: Non-preferred work role
- **WHEN** a resident works in another eligible building role
- **THEN** the assignment remains valid
- **AND** only explicitly declared preference modifiers differ

#### Scenario: No random output bonus
- **WHEN** a specialization modifies production
- **THEN** the output is computed deterministically from state and declared modifiers
- **AND** no chance-based double-yield roll is performed
