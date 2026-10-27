# races-cultures Specification

## Purpose
Канон рас и культур post-pivot (02-mechanics §3.6): раса D&D-персонажа = культура (маппинг), одна таблица расовых коэффициентов, race_affinity (6.5), особые выходы (6.6), гибриды (9.3), водные расы = флаг происхождения (K-A6). Источник: GDD 02-mechanics §3.6, 02e3 (модификаторы), 02g (группы), MVP-scope (Расы), K-канон (K-M5, K-A6).
## Requirements
### Requirement: Race equals culture
A D&D character's race SHALL be a culture (mapping). There SHALL be one table of race coefficients for both buildings and characters (02e3 modifiers). The term "culture" in this spec SHALL mean the D&D race of the character; "group" SHALL mean the city's cultural group (02g).

#### Scenario: Single coefficient table
- **WHEN** a building's race affinity is computed
- **AND** a character's race modifier is computed
- **THEN** both use the same coefficient table
- **AND** no separate "building race" table exists

### Requirement: MVP playable races
The MVP SHALL have a playable slice of 3 cultures (humans, half-orcs, elves) per K-M5 revision and owner decision 2026-10-04. The full catalog SHALL be 7 first-tier races (K-M5). The 54-race catalog SHALL be 1.0.

#### Scenario: Playable slice
- **WHEN** the player creates a character in MVP
- **THEN** only humans, half-orcs, and elves are selectable
- **AND** the other 4 catalog races are hidden or marked 1.0

### Requirement: Race affinity for buildings
Buildings SHALL get a bonus from the city's culture (race_affinity, 6.5). A character SHALL NOT change the city's race (EC2).

#### Scenario: Affinity bonus
- **WHEN** a city's dominant culture matches a building's preferred race
- **THEN** the building gets the affinity bonus
- **AND** the bonus is visible in the tooltip

#### Scenario: Character does not change city race
- **WHEN** a character of a different race joins the city
- **THEN** the city's dominant culture is unchanged
- **AND** the character's race only affects their own modifiers

### Requirement: Special outputs
Special outputs (6.6) SHALL be unconditional when the city is 100% one culture. In a hybrid city, the threshold SHALL be 70% [proposal].

#### Scenario: 100% culture unlocks special
- **WHEN** a city is 100% one culture
- **THEN** the special output for that culture is active
- **AND** no threshold check is needed

#### Scenario: Hybrid threshold
- **WHEN** a hybrid city has 70% of one culture
- **THEN** the special output for that culture is active
- **AND** the 70% threshold is a proposal pending owner confirmation

### Requirement: Hybrid cultural tension
A hybrid city SHALL have cultural tension: a penalty for conflicting culture pairs. The tension SHALL be cured by services (tavern, temple) (9.3).

#### Scenario: Tension penalty
- **WHEN** a city has two conflicting cultures above the tension threshold
- **THEN** the city gets a tension penalty
- **AND** the penalty is visible in the city screen

#### Scenario: Service cures tension
- **WHEN** a tavern or temple is built in a tense city
- **THEN** the tension penalty is reduced or removed
- **AND** the effect is deterministic

### Requirement: Aquatic races are an origin flag
Aquatic races SHALL be an origin flag (K-A6), not a separate economy. Aquatic races SHALL NOT have a distinct production or resource system.

#### Scenario: Aquatic flag
- **WHEN** a character is of an aquatic race
- **THEN** the character has an origin flag
- **AND** no separate aquatic economy is triggered

