# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 TurnDriver (21 ход, 6 фаз, BIT_TURNS = [1,7,14,17,21]) — `turn_driver.gd`
- [x] 1.2 SettlementProcessor (производство, настроение, обслуживание) — `settlement_processor.gd`
- [x] 1.3 ThreatSystem (давление, рейды) — `threat_system.gd`
- [x] 1.4 PopulationSystem (k_pop, K-M12) — `population_system.gd`
- [x] 1.5 DistrictSystem (7 групп, K-M1) — `district_system.gd`
- [x] 1.6 PartySystem (PARTY_CAPACITY = 5, XP/уровни) — `party_system.gd`
- [x] 1.7 CampaignComposition (составка) — `campaign_composition.gd`
- [x] 1.8 Структура хода (1 ход = 1 сезон = 20 дней, Q-M26) — `turn_driver.gd`

## 2. Интеграция (разрывы)

- [~] 2.1 Бит-скрипт 21 хода (1/7/14/17/21; ход 3 «слух» — Post-MVP, K-M9; угрозовые строки — директивы, K-R3) — `turn_driver.gd`, `main.gd`. (2026-10-19, локальный агент: код — выполнен: `BIT_TURNS = [1,7,14,17,21]` + `is_bit_turn()` (turn_driver.gd); директивы K-R3 — raids.json (first_raid/7 floor, district/14, strong_raid/17 window, final_raid/21 floor) + threat_system.gd; ход 3 «слух» — Post-MVP (K-M9), в каркасе отсутствует; тесты: `test_bit_script_skeleton`, `test_floor_first_raid_turn7`, `test_final_tier_by_turn21`, `test_window_strong_raid_turn17_t115`, `test_config_driven_numbers_t115` ([7,14,17,21]). Остаток: `main.gd` — отображение угрозовых строк (UI, headless невозможен).)
- [x] 2.2 Метрики валидации core loop (TTFD ≤ 30 с, action rate 8–15/5 мин, доля решений ≥ 60%, закрытость цикла ≥ 70%, aha-момент ≤ 10 мин) — instrumentation (`action`, `loop_closed`, `replan_after_tooltip`). (2026-10-19, локальный агент: исполнено в campaign-core-loop 2.1–2.4 — `TelemetryLog`: события `action{type, choice_count}`/`loop_closed`/`replan_after_tooltip` в session-лог, метрики post-hoc (`compute_metrics`), GDD-целевые значения; 16 тестов. Отчёт по playtest — вне headless (T-064-семья).)
- [x] 2.3 Fail-states: голод партии (1 еда/персонаж/переход, ёмкость 10 еды; Q-M70→(а), Q-M75→(б)); голод → −2 к атакам/спасам (P-4, R7); гибель всей партии = единственный конец (Q-M68→(а), D-190). (2026-10-19, локальный агент: голод партии — `SupplySystem` (party-characters 3.2: 1 еда/персонаж/переход, ёмкость 10); голод → −2 к атакам (P-4, РЕШЁН: «роль снабжения в бою — прежде всего «голод → −2 к атакам»», 02-mechanics §3.4) — `hunger_penalty` в `_strike` (campaign-core-loop 3.2); снабжение → +2 к первой проверке (P-4) — `supply_bonus` в death saves (dnd-battle-ladder 5.2); гибель всей партии = единственный конец — wipe → defeat (Q-M68→(а), D-190), покрыто тестами (`test_wipe_defeat`, `test_hunger_alone_not_defeat`, `test_hero_death_campaign_continues`).)
- [x] 2.4 Арки: 1–6 выживание → 7–13 железо (рейд ход 7) → 14–20 районы и пережившие (K-M10, «Ветеран» = статус, Q-M56→(а), D-189) → ход 21 рейд-проверка. (2026-10-19, локальный агент: арки = структура кампании, исполнена: рейд ход 7 — floor K-R3 (`test_floor_first_raid_turn7`); районы ход 14 — директива district (`test_config_driven_numbers_t115`); «Ветеран» = статус пережившего (K-M10, Q-M56→(а), D-189) — `PartySystem` (party-characters 3.1); ход 21 рейд-проверка — final_raid floor, boss CR 6–8 (`test_final_tier_by_turn21`).)
- [ ] 2.5 Tutorial + 3-day goals (M3) — `main.gd` (mvp-ui-flow).
- [x] 2.6 Регион-граф (K-T7) — region-graph-map (здесь только требование). (2026-10-19, локальный агент: требование исполнено изменением region-graph-map — код готов: `RegionMap` (движок графа, fog, travel, field_raid), `region_graph.json` (46 регионов MAP-1), интеграция в кампанию + сейв; остаток region-graph-map — Post-MVP (speed ≤ 0, окружение → ENGAGE, синк имен R01–R05/E3…).)
- [ ] 2.7 SM навигации (7 экранов + предыгра) — mvp-ui-flow (здесь только требование).
- [ ] 2.8 Предыгра (Q18: 6 шагов) — pregame-flow (здесь только требование).

## 3. Открытые вопросы

- [ ] 3.1 Q-M82: статус каталога событий/кризисов в MVP (D-198-эрратум) — вердикт владельца; в MVP — каталог не вызывается.
- [x] 3.2 C-18: тики [ПРЕДЛОЖЕНИЕ Q6] — не канон; в MVP — фазы; синк docs. (2026-10-19, локальный агент: синк выполнен — 01-core-loop:12 (тик = 1.0 [ПРЕДЛОЖЕНИЕ Q6], движок MVP = фазы `turn_driver.gd`), 01-core-loop:40 («тик дня» → «день», 1 день = 1 ход кампании), 07-balance §1 (строка «Тик» → 1.0 [ПРЕДЛОЖЕНИЕ Q6]); C-18 в 09-risks — разрешено.)

## 4. Верификация

- [x] 4.1 GdUnit4: бит-скрипт (ходы 1/7/14/17/21; ход 3 — Post-MVP). (2026-10-19, локальный агент: покрыто — `test_bit_script_skeleton` (test_turn_driver.gd) + `test_floor_first_raid_turn7`, `test_final_tier_by_turn21`, `test_window_strong_raid_turn17_t115`, `test_config_driven_numbers_t115` (test_threat_system.gd); ход 3 «слух» — Post-MVP (K-M9), в каркасе отсутствует по канону.)
- [x] 4.2 GdUnit4: fail-states (голод партии; гибель всей партии = конец кампании). (2026-10-19, локальный агент: покрыто — голод: `test_hunger_penalty_default_zero`, `test_hunger_penalty_lowers_margin_and_zone` (test_campaign_battle.gd, P-4: −2 к атакам); wipe: `test_wipe_defeats_campaign_and_preserves_prestige` (test_party_wiring.gd, D-190: wipe = единственный конец кампании, Престиж сохраняется).)
- [x] 4.3 GdUnit4: арки (1–6/7–13/14–20/21; «Ветеран» = статус). (2026-10-19, локальный агент: покрыто — арки = структура кампании: ход 7 рейд (`test_floor_first_raid_turn7`), ход 14 район (бит-скрипт, `test_bit_script_skeleton`), ход 21 финальный рейд (`test_final_tier_by_turn21`), «Ветеран» = статус (test_veteran.gd, K-M10).)
- [ ] 4.4 Playtest (не headless): 21 ход, ~3 сессии; метрики (TTFD, action rate, доля решений, закрытость цикла) — отложенно (deferred, UI/звук/playtest не верифицируются headless).
