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

- [ ] 2.1 Бит-скрипт 21 хода (1/7/14/17/21; ход 3 «слух» — Post-MVP, K-M9; угрозовые строки — директивы, K-R3) — `turn_driver.gd`, `main.gd`.
- [ ] 2.2 Метрики валидации core loop (TTFD ≤ 30 с, action rate 8–15/5 мин, доля решений ≥ 60%, закрытость цикла ≥ 70%, aha-момент ≤ 10 мин) — instrumentation (`action`, `loop_closed`, `replan_after_tooltip`).
- [ ] 2.3 Fail-states: голод партии (1 еда/персонаж/переход, ёмкость 10 еды; Q-M70→(а), Q-M75→(б)); голод → −2 к атакам/спасам (P-4, R7); гибель всей партии = единственный конец (Q-M68→(а), D-190).
- [ ] 2.4 Арки: 1–6 выживание → 7–13 железо (рейд ход 7) → 14–20 районы и пережившие (K-M10, «Ветеран» = статус, Q-M56→(а), D-189) → ход 21 рейд-проверка.
- [ ] 2.5 Tutorial + 3-day goals (M3) — `main.gd` (mvp-ui-flow).
- [ ] 2.6 Регион-граф (K-T7) — region-graph-map (здесь только требование).
- [ ] 2.7 SM навигации (7 экранов + предыгра) — mvp-ui-flow (здесь только требование).
- [ ] 2.8 Предыгра (Q18: 6 шагов) — pregame-flow (здесь только требование).

## 3. Открытые вопросы

- [ ] 3.1 Q-M82: статус каталога событий/кризисов в MVP (D-198-эрратум) — вердикт владельца; в MVP — каталог не вызывается.
- [ ] 3.2 C-18: тики [ПРЕДЛОЖЕНИЕ Q6] — не канон; в MVP — фазы; синк docs.

## 4. Верификация

- [ ] 4.1 GdUnit4: бит-скрипт (ходы 1/7/14/17/21; ход 3 — Post-MVP).
- [ ] 4.2 GdUnit4: fail-states (голод партии; гибель всей партии = конец кампании).
- [ ] 4.3 GdUnit4: арки (1–6/7–13/14–20/21; «Ветеран» = статус).
- [ ] 4.4 Playtest (не headless): 21 ход, ~3 сессии; метрики (TTFD, action rate, доля решений, закрытость цикла) — отложенно (deferred, UI/звук/playtest не верифицируются headless).
