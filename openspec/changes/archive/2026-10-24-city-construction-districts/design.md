# Design

## Context

Город post-pivot реализован в основном: `district_system.gd` (T-030: 7 групп, эмерджентность), `worker_assignment.gd` (Y7: авто-назначение), `population_system.gd` (T-040: k_pop = 0.1/день, K-M12), 52-hex city (`CampaignBuildingPlacement`, `CityData`), каталог 23 зданий (`campaign_building_catalog.json`), construction queue (`campaign-city-construction-queue`), экономика (`campaign-city-building-economy`), баланс (`campaign-city-balance-tuning`). GDD-канон как единой спеки нет; main spec `campaign-city-level-progression` противоречит K-M3 (C-2).

## Goals / Non-Goals

**Goals:** формализовать GDD-канон города (02 §3.5 + 02g) как OpenSpec-требования; закрыть разрывы: SM здание (DISABLED/RUINED/REPAIRING), распад района (3 дня), «район создан» без Престижа (K-M16); зафиксировать C-2/C-9/C-11.

**Non-Goals:** каталог/стоимость/очередь (active changes), караваны (Post-MVP, Ф3), стены (Post-MVP), камень/кузница/оружие (Post-MVP, K-R2), ручное назначение рабочих (1.0), 3-й биом (горы, 1.0, K-M2), каталог 54 рас (1.0, K-M5).

## Decisions

- **Это канон-спека, не реализация**: требования описывают GDD-канон; реализация живёт в active changes (building-economy, construction-queue, balance-tuning) и коде (T-030/T-040). Дублирование реализации запрещено — здесь только требования + dead tasks.
- **Районы (K-M1)**: эмерджентные, не здание; 7 групп; «район создан» — не источник Престижа и не XP (K-M16, самокоррекция K-M1; C-11: строка MVP-scope.md устарела). Распад: теги ниже порога 3 дня → район снимается (событие в хронику).
- **SM здание**: GHOST→BUILDING→WORKING→(DISABLED/RUINED→REPAIRING); ауры — только от WORKING (construction-queue использует `inactive`/`construction_turns_remaining` — маппинг в tasks). 1 правило соседства MVP (ферма у леса +15%, 02g = синергии §3).
- **Рабочие (Y7)**: авто-назначение на min(запас/7 дней); ручное — Post-MVP.
- **Население (K-M12, R3)**: population = min(жильё, floor(прод_сутки / k_pop)), k_pop = 0.1/день; от производства, не от запаса (рейд по еде → дни DEFICIT, не демографический обвал).
- **Биомы (K-M2)**: 2 регулярных (равнина/лес) + босс; terrain_preference — жёсткая привязка (P-3); горы — 1.0.
- **Без уровней (K-M3)**: лимиты = административные здания; «городская слава» = персональная. C-2: main spec `campaign-city-level-progression` — вердикт владельца.

## Risks / Trade-offs

- [C-2: уровни 1–11 в main spec vs K-M3] → до вердикта владельца: код не вводит уровни (legacy `city.level` — не campaign-механика); spec помечается superseded или остаётся как 1.0 — решение владельца.
- [C-11: MVP-scope.md «район создан — источник Престижа»] → канон = K-M16; синк docs (реестр TBD).
- [SM здание vs construction-queue `inactive`] → маппинг: BUILDING = `construction_turns_remaining > 0`; RUINED = `state == "ruined"`; REPAIRING — новая задача (реализация в construction-queue или здесь — по вердикту).
- [Распад района (3 дня) не реализован] → задача 2.2; таймер на районе (district_system.gd). Уточнено 2026-10-24: «таймер на районе» не строится на текущем носителе — у района нет ни собственного содержания (оно у зданий), ни состояния между ходами (район пересчитывается из города каждый ход, в сейв не пишется), ни перечня тегов и числа порога; вопрос носителя — **Q-M99**.

## Маппинг SM здания (2.3, 2026-10-24)

Состояние здания в кампанийном носителе — **пара полей** инстанса в `city.campaign_buildings`, отдельного перечисления нет и вводить его нечем (единственный читатель — проверки ниже). GHOST — не состояние инстанса: это превращение превью размещения до создания инстанса (`explain_request` → `explain_placement`), инстанс с этим состоянием не существует.

| Состояние GDD | Носитель (поля инстанса) | Кто пишет | Кто читает |
| --- | --- | --- | --- |
| GHOST | инстанса нет; превью по `explain_request`/`explain_placement` | `city_screen`/`campaign_city_board` | та же проверка при подтверждении |
| BUILDING | `state == "inactive"` при установке; далее `construction_turns_remaining > 0` | `campaign_building_construction_service.request` | `campaign_construction_processor` (тик), `economic_turn_processor`, `campaign_defense_resolver`, `CampaignBuildingPlacement` |
| WORKING | `state == "active"` и `construction_turns_remaining == 0` | `campaign_construction_processor` (по окончании стройки) | все потребители выше + `campaign_training_service` |
| DISABLED | отдельного значения нет: вакансия рабочих (`assigned_workers < jobs`) при active-состоянии | `worker_assignment`, `DistrictSystem.process_turn` | эконом-процессор (рецепт не крутится без рабочих) |
| RUINED | `state == "ruined"` | `campaign_building_merger` (хотя бы один компонент разрушен) | `campaign_training_service`, `CampaignBuildingPlacement`, `city_screen` («разрушено») |
| REPAIRING | **носителя нет** | — | — |

`REPAIRING` кодом не вводится: write-точек `ruined → *` в кампанийном слое нет — мерж только сохраняет `ruined`, если хоть один компонент разрушен, то есть чинящего нет. Вводить состояние раньше носителя — писатель без читателя (прецедент Q-M79/Q-M81).

Ауры (соседство) берутся только от WORKING и применяются только к WORKING: `CampaignBuildingPlacement._evaluate_one` отсевает и источник, и цель по признаку `state != "active" || construction_turns_remaining > 0` — обе половины заперты тестами (`test_inactive_or_ruined_buildings_do_not_supply_adjacency_effects`, `test_shipped_forest_edge_rule_needs_working_source_at_radius_one`).

## Carrier notes (термин спеки → имя в коде)

| Термин спеки | Носитель |
| --- | --- |
| `terrain_preference` (жёсткая привязка, P-3) | `placement.terrain_tags` + `placement.requires_special_site` в каталоге; проверка — `CampaignBuildingPlacement.explain_placement` (жёсткая: несовпадение → `ok = false`, не штраф). Ключа с именем `terrain_preference` в репо нет. |
| «ферма у леса +15%» | `campaign_sawmill.adjacency[0]`: `id: forest_edge_farm`, `target_role: food_production`, `radius: 1`, `effect: output_bp`, `value: 1500` (1500 б.п. = +15%). Самого леса как размещаемого объекта городской сетки нет — роль леса играет соседнее лесозаготовительное здание; ни ферма, ни лесопилка terrain-ограничений не имеют (`terrain_tags: []`). |
| «1 клетка = 1 здание» | `footprint` ровно из одной клетки у всех 98 зданий каталога (тест `test_mvp_catalog_one_cell_per_building`) + `_occupied_cells` при размещении. |
| «район» | группа `SettlementProcessor.GROUPS` в `DistrictSystem` (7 + без группы): проекция текущего города, свой upkeep не имеет, между ходами состояния не хранит → распад (2.2) блокирован Q-M99. |
| «событие в хронику» | `GameEventBus.chronicle_entry_added` / `chronicle` носителя (`endgame_controller._append_chronicle_entry` — единственный писатель на сегодня). |

Каталог в Context указан как «23 здания» — с тех пор вырос до 98 (основная масса — переносные карточки AOE4/TerraScape, `campaign_*` — MVP-ядро); число не является мерой скоупа этой спеки и оставлено как история.
