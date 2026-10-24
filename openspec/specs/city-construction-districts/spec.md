# city-construction-districts Specification

## Purpose

GDD-канон города post-pivot (02-mechanics §3.5, 02g): 52 hex, районы (K-M1), SM здания, рабочие (Y7), население (K-M12), биомы (K-M2), без уровней города (K-M3). Источник: GDD 02-mechanics §3.5, 02g (городской слой), MVP-scope (Город), K-канон (K-M1, K-M2, K-M3, K-M12, K-M16, K-R2), решения (R3, Y7, P-3).

## Requirements

### Requirement: City is a 52-hex grid
The city SHALL be a 52-hex grid (core 4 + rings I-III, 02g §2.1). One cell SHALL host at most one building. The city SHALL NOT use city levels for limits (K-M3); limits SHALL be administrative buildings.

#### Scenario: One cell one building
- **WHEN** the player attempts to place a second building on an occupied cell
- **THEN** the placement is rejected
- **AND** the cell's current building is unchanged

### Requirement: Districts are emergent
Districts SHALL be emergent, not buildings (K-M1, MVP core). There SHALL be 7 district groups. A district SHALL appear when the required tags are gathered within its radius. "District created" SHALL NOT be a source of prestige or XP (K-M16, K-M1 self-correction). A district SHALL disband if its tags fall below the threshold for 3 days (D-235: мерой «теги собраны» в носителе служит наличие у экономической группы хотя бы одного здания — радиуса и перечня тегов у проекции нет, расхождение зафиксировано в Carrier notes).

#### Scenario: District creation
- **WHEN** the required tags for a district are gathered within its radius
- **THEN** the district appears
- **AND** no prestige or XP is granted

#### Scenario: District disband
- **WHEN** a district's tags fall below the threshold for 3 consecutive days
- **THEN** the district is removed
- **AND** the event is logged in the chronicle
- **AND** the district's accumulated mood is destroyed (reset to `mood_start`), so a
  district refounded later starts with a fresh mood, while a district brought back
  inside the 3-day window keeps it

### Requirement: Building state machine
A building SHALL follow the state machine GHOST → BUILDING → WORKING → (DISABLED/RUINED → REPAIRING). Auras SHALL only come from WORKING buildings. The MVP SHALL have 1 adjacency rule (farm next to forest +15%).

#### Scenario: Aura only from working
- **WHEN** a building is under construction (BUILDING state)
- **THEN** its aura is not active
- **AND** the aura activates only when the building reaches WORKING

#### Scenario: Farm adjacency bonus
- **WHEN** a farm is placed next to a forest
- **THEN** the farm gets +15% output
- **AND** the bonus is visible in the tooltip

### Requirement: Worker auto-assignment
Workers SHALL be auto-assigned to the most scarce building (min stock/7 days) (Y7). Manual assignment SHALL be Post-MVP.

#### Scenario: Auto-assignment
- **WHEN** a new worker becomes available
- **THEN** the worker is assigned to the building with the lowest stock/7 days
- **AND** the assignment is deterministic

### Requirement: Population formula
Population SHALL be `min(housing, floor(daily_food_production / k_pop))` with `k_pop = 0.1/day` (K-M12, R3). Population SHALL depend on production, not on stock.

#### Scenario: Population from production
- **WHEN** daily food production is 20 and housing is 25
- **THEN** population is min(25, floor(20 / 0.1)) = 25
- **AND** a raid reducing food stock does not instantly collapse population

### Requirement: City biomes
The city SHALL have 2 regular biomes (plain, forest) plus 1 boss biome (K-M2). Mountains SHALL be 1.0. `terrain_preference` SHALL be a hard constraint for building placement in MVP (P-3).

#### Scenario: Biome constraint
- **WHEN** a building with `terrain_preference = forest` is placed on plain
- **THEN** the placement is rejected
- **AND** the constraint is enforced by the placement service

### Requirement: No city levels
The city SHALL NOT use city levels (K-M3). Limits SHALL be administrative buildings. "City glory" SHALL be personal only (no city-wide glory).

#### Scenario: No level gate
- **WHEN** the player attempts to build a building
- **THEN** the only gates are prerequisites, resources, and placement
- **AND** no city level check is performed

## Carrier notes (агент, 2026-10-24)

Термины требований → имена в коде (полная таблица — `design.md` § «Carrier notes», маппинг состояний — § «Маппинг SM здания»), чтобы при синке в main spec текст читался вместе с носителем:

- `terrain_preference` (P-3) → `placement.terrain_tags` + `placement.requires_special_site`; жёсткость держит `CampaignBuildingPlacement.explain_placement`. Поля с именем `terrain_preference` в репо нет.
- «ферма у леса +15%» → соседняя лесопилка: `campaign_sawmill.adjacency[0]` = `forest_edge_farm`, `target_role: food_production`, `radius: 1`, `output_bp: 1500`. Леса как размещаемого объекта городской сетки нет; расхождение формулировки с носителем осознанно и заперто тестами переписи каталога.
- SM здания → пара полей `state` (`inactive`/`active`/`ruined`) + `construction_turns_remaining`; GHOST — инстанса ещё нет (превью размещения), DISABLED — вакансия рабочих, REPAIRING — носителя нет (чинящего в кампанийном слое нет).
- «район» → группа `DistrictSystem` (7 + без группы): проекция города, своего upkeep не имеет.
  Между ходами хранится только гистерезис распада `district_state` (Q-M99 → (б), D-235):
  `present` + `below_days` на группу, персистится `to_dict()` в секции `city.districts`.
  «Теги собраны» = в группе ≥1 здания; «район снят» = запись о районе уничтожена
  (настроение сброшено к `mood_start`), событие `district_disbanded` идёт в хронику
  (`TelemetryLog`, T-158). «Upkeep останавливается» при пустой группе верно тривиально
  (у группы содержания нет, upkeep числится по зданиям в `economic_turn_processor`),
  «destruction_penalty не применяется» — нечего применять. Радиуса у проекции нет: в
  отличие от канона 02-mechanics §3.5, близость зданий не мерится — это осознанное
  упрощение носителя, а не покрытие требования.
- Строка «Без группы» (UNGROUPED) районом не считается и из отчёта не снимается.
- UI-списка районов в MVP нет: `report["districts"]` читают тесты и хроника, экран
  города строится по зданиям. Поэтому «район снят» наблюдаемо в отчёте слоя и в
  хронике (`TelemetryLog`), но не в кадре: отдельного списка районов на экране нет.
