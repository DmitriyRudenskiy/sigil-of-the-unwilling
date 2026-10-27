# Tasks: campaign-core-loop

## 1. Структура кампании (реализовано — dead tasks)

- [x] 1.1 21 ход, ход = сезон = 20 дней (Q-M26) — `turn_driver.gd` T-010
- [x] 1.2 Порядок 6 фаз: settlement → player → caravans → diplomacy → threats → production (Q-M31, T-122) — `turn_driver.gd`
- [x] 1.3 Бит-каркас K-M9: биты 1/7/14/17/21 — `turn_driver.gd` (BIT_TURNS)
- [x] 1.4 Сезоны: season_index = (turn−1) % 4, зима каждый 4-й ход, production_mult/enemy_mult — `world_seasons.gd` (Q-M27/Q-M29)
- [x] 1.5 Детерминизм I1: ГСЧ из campaign seed — `turn_driver.gd`/`campaign_battle.gd`
- [x] 1.6 Статус кампании: defeat = wipe партии (единственный путь, Q-M68→(а), D-190) — готово (`turn_driver.gd: defeat()`, `party_system.gd: is_wiped`); victory = пережить рейд хода 21 при любом запасе > 0 (R5) — готово (T-071, 2026-10-21: `TurnDriver.victory()` + `victory_check_hook` (инжест предиката «любой запас > 0»), проверка в конце хода 21 при статусе ongoing; «Campaign victory»-сценарий спеки закрыт; edge «пережил, но запасы ≤ 0» → ongoing + журнал)

## 2. Метрики core loop

- [x] 2.1 Телеметрия событий: `action{type, choice_count}` с timestamp (build/train/move/fight) — `TelemetryLog` (`scripts/campaign/telemetry_log.gd`) + `CampaignComposition.record_action(verb, choice_count)`; timestamp = ход кампании (I1, детерминированно), wall-clock `t` (сек) — опциональное поле, которое добавляет UI в playtest; UI-глаголы build/train/move → `record_action`, `fight` — авто-событие в `_request_battle` (MVP: авто-оборона, choice_count 1). Лог сессии — артефакт сессии, не часть сейва. *(GdUnit test_telemetry.gd: 16/0.)*
- [x] 2.2 Телеметрия: `loop_closed` (ход, в котором замкнут цикл «увидел → двинул → решил → построил → снабдил → пережил рейд») — `loop_closed` fires на ходу, где все флаги: рейд ударил (threats-фаза) + действие игрока (`acted`) + поход (`record_expedition()`, герой покинул город) + возврат (герой в городе к концу хода) + ongoing. Headless: без игрока expedition не ставится → событие не fires (дизайн-решение #2: метрики — за телеметрией, не за симуляцией). *(4 теста: полный цикл, без похода, без рейда, герой не вернулся.)*
- [~] 2.3 Телеметрия: `replan_after_tooltip` (перепланирование после подсказки «почему так») — событие + `record_replan_after_tooltip()` готовы (1 тест); триггер — UI-подсказка «Почему так?» (deferred: не headless-верифицируемо, mvp-ui-flow). **Замер 2026-10-25, блокатор T-199:** у события нет writer'а в игре (`grep -rn record_replan_after_tooltip scripts/` даёт одно определение) — подсказки «Почему так?» нет ни в одном носителе, поэтому метрика останется `-1.0`/`null` не из-за сломанного счётчика, а потому что мерить нечего.
- [x] 2.4 Отчёт по метрикам: TTFD ≤30s, rate 8–15/5min, decision ratio ≥60%, loop closure ≥70%, сессия 35–50min (post-hoc анализ лога сессии) — `TelemetryLog.compute_metrics(events)` (post-hoc отчёт: все 6 метрик GDD + `pass`-флаги по целям; без wall-clock `t` — только счётчики, временные метрики = -1.0/null) + `loop_closure_rate(sessions)` (меж-сессийная агрегация «сессии с ≥1 полным циклом» ≥ 70%). D1/D7 — playtest (2.5). *(3 теста: полная сессия 40 мин, headless без wall-clock, меж-сессийный rate.)*
- [x] 2.5 D1 ≥35% / D7 ≥15% — deferred: измеряется только в playtest (критерий MVP) **Закрытие 2026-10-27 (автономный аудит не заархивированных смен):** Метрика из класса «нечем снять»: retention D1/D7 измеряется только живым playtest, а он отложен политикой верификации (AGENTS.md: «Звук и playtest остаются отложенными — их нечем снять»); headless-прокси у retention нет. Числа остаются критерием MVP в [[MVP-scope]], смену не блокируют.

## 3. Fail states

- [x] 3.1 AFK-капы per-ресурс per-рейд: еда ≤40%, железо/оружие ≤30% (Q-M58→(в), D-189) — реализация в `raid-pressure-system` (T-127), здесь — только требование. *(Верифицировано: реализовано в raid-pressure-system 2.1 — `loss_caps` {еда 0.4, дерево/железо 0.3} + `loss_cap_for(resource)`; GdUnit 2672/0.)*
- [x] 3.2 Голод: ёмкость 10 еды, расход 1/персонаж/переход (R7, Q-M75→(б)) — `SupplySystem` (party-characters 3.2); голод → −2 к атакам — проводка в боевой движок: `hunger_penalty` в `make_combatant` + margin в `_strike` (P-4); проводка `supply_system.attack_penalty()` → герой в `_request_battle` (тесты: `test_campaign_battle.gd` ×2, `test_campaign_wiring.gd: test_hunger_penalty_wired_into_battle`)
- [x] 3.3 Инвариант «≥2 доступных глагола в player-фазе» — smoke-чек-лист в `mvp-ui-flow`

## 4. Верификация

- [x] 4.1 GdUnit4: порядок фаз (production после threats), no-op caravans/diplomacy. *(test_turn_driver.gd: test_phase_order_mandate, test_post_mvp_slots_noop.)*
- [x] 4.2 GdUnit4: 100 повторов seed+actions → byte-identical state. *(test_turn_driver.gd: test_i1_determinism_100_repeats_byte_identical.)*
- [x] 4.3 GdUnit4: статус кампании (wipe → defeat; голод сам по себе не defeat; victory — ход 21 + запас > 0, wipe в ходу 21 → defeat, не victory). *(test_turn_driver.gd: test_wipe_defeat, test_defeat_idempotent, test_hunger_alone_not_defeat, test_defeat_status_serialized; test_campaign_victory.gd (14, T-071, 2026-10-21).)*
**Исход 2026-10-26 (срез агента).** Носитель — пункт smoke-чек-листа в `mvp-ui-flow/tasks.md` 5.4 (там же формулировка прохода и граница). Задача закрывается тем, чем была поставлена: инвариант переведён из «идеи про дизайн» в проверяемый пункт смока. Машинного GdUnit-ассерта под ним нет и появляться в этой задаче не должно: 5.4 — playtest-смок, отложенный по K-M8, поэтому закрывать вместе с ней 3.3 нельзя (иначе инвариант «закрылся» бы вместе с непроверенным смоком).
