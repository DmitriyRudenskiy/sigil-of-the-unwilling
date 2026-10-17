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
- [Распад района (3 дня) не реализован] → задача 2.2; таймер на районе (district_system.gd).
