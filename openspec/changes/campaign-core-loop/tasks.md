# Tasks: campaign-core-loop

## 1. Структура кампании (реализовано — dead tasks)

- [x] 1.1 21 ход, ход = сезон = 20 дней (Q-M26) — `turn_driver.gd` T-010
- [x] 1.2 Порядок 6 фаз: settlement → player → caravans → diplomacy → threats → production (Q-M31, T-122) — `turn_driver.gd`
- [x] 1.3 Бит-каркас K-M9: биты 1/7/14/17/21 — `turn_driver.gd` (BIT_TURNS)
- [x] 1.4 Сезоны: season_index = (turn−1) % 4, зима каждый 4-й ход, production_mult/enemy_mult — `world_seasons.gd` (Q-M27/Q-M29)
- [x] 1.5 Детерминизм I1: ГСЧ из campaign seed — `turn_driver.gd`/`campaign_battle.gd`
- [x] 1.6 Статус кампании: defeat = wipe партии (единственный путь, Q-M68→(а), D-190); victory = пережить рейд хода 21 (R5) — `turn_driver.gd:76`, `party_system.gd:108`, T-071

## 2. Метрики core loop

- [ ] 2.1 Телеметрия событий: `action{type, choice_count}` с timestamp (build/train/move/fight)
- [ ] 2.2 Телеметрия: `loop_closed` (ход, в котором замкнут цикл «увидел → двинул → решил → построил → снабдил → пережил рейд»)
- [ ] 2.3 Телеметрия: `replan_after_tooltip` (перепланирование после подсказки «почему так»)
- [ ] 2.4 Отчёт по метрикам: TTFD ≤30s, rate 8–15/5min, decision ratio ≥60%, loop closure ≥70%, сессия 35–50min (post-hoc анализ лога сессии)
- [ ] 2.5 D1 ≥35% / D7 ≥15% — deferred: измеряется только в playtest (критерий MVP)

## 3. Fail states

- [ ] 3.1 AFK-капы per-ресурс per-рейд: еда ≤40%, железо/оружие ≤30% (Q-M58→(в), D-189) — реализация в `raid-pressure-system` (T-127), здесь — только требование
- [ ] 3.2 Голод: ёмкость 10 еды, расход 1/персонаж/переход (R7, Q-M75→(б)), голод → −2 к атакам — реализация в `party-characters`/`dnd-battle-ladder`
- [ ] 3.3 Инвариант «≥2 доступных глагола в player-фазе» — smoke-чек-лист в `mvp-ui-flow`

## 4. Верификация

- [x] 4.1 GdUnit4: порядок фаз (production после threats), no-op caravans/diplomacy. *(test_turn_driver.gd: test_phase_order_mandate, test_post_mvp_slots_noop.)*
- [x] 4.2 GdUnit4: 100 повторов seed+actions → byte-identical state. *(test_turn_driver.gd: test_i1_determinism_100_repeats_byte_identical.)*
- [x] 4.3 GdUnit4: статус кампании (wipe → defeat; голод сам по себе не defeat). *(test_turn_driver.gd: test_wipe_defeat, test_defeat_idempotent, test_hunger_alone_not_defeat, test_defeat_status_serialized. **victory (рейд 21) — T-071, post-MVP.)*
