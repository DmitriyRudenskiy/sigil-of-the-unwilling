# settlement-species Specification

> **Синк 2026-10-20 (campaign-city-building-economy).** Pre-pivot требования
> (7 видов со статистикой, караван ≤3 видов, специализации) **REMOVED**
> (Reason/Migration — в дельте change); pre-pivot контент — носитель
> правила для 1.0 (доки 02e*, git-история). Пост-пивот требования ниже —
> текущий контракт capability.

## Purpose
Определяет население города кампании: семь канонических экономических
архетипов ведут симуляцию населения; архетипы задают потребности и
предпочтения работы, а не жёсткие job locks (жители = расы кампании, K-M3).
## Requirements

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
