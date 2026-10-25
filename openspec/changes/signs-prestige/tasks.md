# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 Каталог 8 знаков (этика-векторы) — `signs.json` (T-002, T-124, T-129)
- [x] 1.2 Выбор из 8 на старте — `sign_choice_ui.gd` (T-002)
- [x] 1.3 Престиж-ledger (K-M16) — `CampaignComposition`
- [x] 1.4 Ранги (пороги 0/200/500/1000/2000) — `prestige.json` (D-133)
- [x] 1.5 Этика-векторы знаков — `ethics_system.gd` (T-124/T-129)
- [x] 1.6 Все 8 знаков играбельны (Q-M32) — `sign_choice_ui.gd`

## 2. Разрывы

- [x] 2.1 SM знака: DORMANT→ACTIVE (выбор); ACTIVE→SLEEPING (Престиж ≤ 0); SLEEPING→ACTIVE (Престиж > 0); SLEEPING ≠ game over. (`sign_system.gd`)
- [x] 2.2 Фракционные действия: ≤12 за кампанию; штраф стиля только за повтор; 13-е → без начисления; счётчик в сейве (`faction_actions_used`). (`sign_system.gd`)
- [ ] 2.3 Косметические ранги в UI: титул/рамка (5 рангов) — mvp-ui-flow.
- [ ] 2.4 UI-счётчик «N осталось» (фракционные действия) — mvp-ui-flow.
- [x] 2.5 Хроника: события знака (выбор, SLEEPING/ACTIVE, ранги) — mvp-ui-flow. **Сделано (T-187, 2026-10-24, D-244):** четыре ключа в закрытом наборе `ChronicleLog.KNOWN_KEYS` (`chronicle.sign_chosen` {sign}, `chronicle.sign_sleeping`, `chronicle.sign_awakened`, `chronicle.rank_changed` {rank}) + переводы в `ru`/`en`; писатели — в `CampaignComposition` (паттерн D-240): выбор при смене `"" → id`, сон/пробуждение на переходе SM, титул одним нейтральным ключом. Ранг нельзя сравнить «до/после» внутри синка (`_add_ledger` меняет ledger раньше) — держится полем `_chronicle_rank`. Загрузка сейва не пишет (`record_events = false`). Понижения ранга и сон в MVP нечем произвести (`_add_ledger` отбрасывает `amount <= 0`), поэтому обратный ключ и писатель смерти носителя не заводились. 9 юнит- + 1 функциональный кейс (строки доходят до отрисованной ленты), 4 мутационные проверки, ux-review кадр 1080p/720p — `docs/mvp/TICKETS.md` (Т-187).
- [x] 2.6 Якорь кампании: ход 21 = «Почитаемый» (500–999) — баланс-проверка в `prestige.json`. (`test_t041_anchors.gd::test_prestige_corridor_turn21`)

## 3. Синк (C-16, C-11)

- [x] 3.1 C-16: синк MVP-scope («MVP берёт подмножество — TBD» → «все 8, Q-M32»). (2026-10-19)
- [x] 3.2 C-11: синк MVP-scope («район создан — источник Престижа (500)» → «не источник», K-M16) — дублируется city-construction-districts. (2026-10-19)

## 4. Верификация

- [x] 4.1 GdUnit4: SM знака (DORMANT→ACTIVE→SLEEPING→ACTIVE; SLEEPING ≠ game over). (`test_sign_system.gd`)
- [x] 4.2 GdUnit4: фракционные действия (12-е — начисление, 13-е — без; штраф стиля за повтор). (`test_sign_system.gd`)
- [x] 4.3 GdUnit4: ранги (пороги 0/200/500/1000/2000; понижение при падении). (`test_sign_system.gd::test_rank_thresholds/test_rank_demotion`)
- [x] 4.4 GdUnit4: косметика (S2: притока населения нет). (`test_sign_system.gd::test_prestige_no_population_inflow`)
- [x] 4.5 GdUnit4: смерть носителя → «утрата» (−2 к спасам), кампания продолжается (R1, K-M11). (`test_sign_system.gd::test_bearer_death_*`)
