## 1. Поле 11×9 = 99 гексов

- [ ] 1.1 `scripts/constants/game_numbers_battle.gd`: `BATTLE_BOARD_W` 17 → 11, `BATTLE_BOARD_H` 11 → 9
- [ ] 1.2 Пройти потребителей `BattleState.BW/BH` (`battle_state_builder.gd` — линии размещения у колонок 0 и `BW-1`; `battle_ai.gd` — BFS и радиусы; `battle_view.gd` — обводка `±RING`; кэш дистанций `battle_state.gd:590`) и убедиться, что нигде не осталось литералов 17/11 в обход констант (`grep -n "\b17\b\|\b11\b" scripts/**/battle*.gd`)
- [ ] 1.3 Проверить `_resolve_blocked_placement()` на максимальном для носителя составе: все стартовые позиции внутри 99 гексов (доказательство — кадр 5.3)

## 2. Снять лимит хода (D-214 §3 теряет силу)

- [ ] 2.1 `battle_state.gd`: удалить `turn_time_limit`, `turn_time_left`, `arm_turn_timer`, `disarm_turn_timer`, `tick_turn_timer`; убедиться, что ни одно из них не сериализуется в сейв (`grep -rn "turn_time" scripts/systems/save* scripts/**/save*.gd`)
- [ ] 2.2 `battle_turn_executor.gd`: убрать тик часов в `WAITING_INPUT` и автопропуск по истечении; `battle_controller.gd`: убрать взвод таймера и паузу при открытой книге заклинаний
- [ ] 2.3 Удалить `tests/unit/systems/test_turn_timer.gd` вместе с поведением; в отчёте — леджер вида `+0 / −N / quarantine 0 / нетто −N`, причина «удалённое поведение»
- [ ] 2.4 `grep -rn "turn_time\|таймер хода" game/scripts game/tests docs` — следы не остаются (архивы `openspec/changes/archive/` не правятся)

## 3. Освободить верх экрана

- [ ] 3.1 `scenes/ui/battle_ui.tscn`: удалить `initiative_bar` (с `init_col`/`init_box`) и `turn_ring`; `hero_cards` не трогать (скрыт)
- [ ] 3.2 `scripts/ui/battle_ui.gd`: удалить `@onready`-ссылки на удалённые узлы, `update_initiative()` и все её вызовы; удалить `scripts/ui/widgets/turn_ring.gd` и его регистрацию/предзагрузку
- [ ] 3.3 `hud_bands()`: убрать удалённые полосы из списка (резерв камеры = нижняя панель), проверить, что `reserve_hud_bands` (D-279) кадрирует поле без верхних полос
- [ ] 3.4 Удалить мёртвые приёмники ленты (например, приёмы `unit_card.gd`, использовавшиеся только ей)
- [ ] 3.5 `grep -rn "initiative_bar\|turn_ring\|update_initiative" game/scripts game/tests docs` — пусто, кроме архивов

## 4. Задний план по местности врага

- [ ] 4.1 `battle_state.gd`: поле `background_terrain` (значение по умолчанию — местность луга) + сеттер; поведение боя от него не зависит
- [ ] 4.2 `battle_handoff.gd`: взять мировую местность `enemy_cell` и положить в handoff
- [ ] 4.3 `battle_flow.gd` → `battle_controller.gd`: необязательный параметр, пробрасывающий местность в `BattleState.background_terrain` (старшие вызывающие не ломаются)
- [ ] 4.4 Таблица «местность → фон» (`snow`, `swamp`) с явным fallback на текущий вид; ключ — имя мировой местности, не `BattleTerrain`
- [ ] 4.5 `scenes/battle_view.tscn` + `battle_view.gd`: `Sprite2D` фона под `Terrain`, позиция и масштаб по границам поля, совместимость с `fit_camera`/`reserve_hud_bands`
- [ ] 4.6 Два канон-кадра владельца → `game/assets/ui/backgrounds/` (в git) + строки в `reference/INDEX.md` (путь источника, md5, статус канона) по D-185

## 5. Кадры и ux-review (носителем приёмки, тестов не писать)

- [ ] 5.1 `game/tools/capture/battle_background.gd` — состояние съёмки (бой со снегом под врагом), кадр «до» на текущей сборке
- [ ] 5.2 Съёмка «после»: снег, болото, неопознанная местность (fallback), максимальный состав; канал `CAPTURE_SCENE`/`CAPTURE_SETUP` по [[CAPTURE-HELPER]], кадры в `~/.local/share/sigil-reserve/` (пиксели не в git)
- [ ] 5.3 `ui-grid-review` (`.pi/skills/ui-grid-review`): кадр против референса по ячейкам, кроп спорной ячейки, владелец прямоугольника, дельта «до/после»
- [ ] 5.4 Вердикт в треде: кадр-доказательство + путь к макету + список расхождений с диспозицией + PASS/FAIL по каждой AC; push — только после вердикта и явного «мержи»

## 6. Замена старых правил в документации

- [ ] 6.1 `docs/07-balance.md` §4: строка «Боевая сетка 17×11» → 11×9 (99 гексов), пометка Q-M47 приведена в соответствие
- [ ] 6.2 `docs/14-ux-battle-hud.md`: зоны «инициатива» и кольцо удалены, раскладка верха кадра, правило выбора фона по местности врага
- [ ] 6.3 `docs/DECISIONS.md`: новая запись D-### — снятие лимита хода (D-214 §3 аннулирован), поле 11×9, фон по местности, директива «приёмка кадром без тестов» (2026-10-27)
- [ ] 6.4 `docs/mvp/GAP-LIST.md` (B-15, C-5, S-4) и `docs/mvp/TICKETS.md` (AC T-050): 17×11 → 11×9
- [ ] 6.5 `python3 scripts/check_docs_links.py` — exit 0; повторный grep `17×11` по `docs/` — только исторические цитаты в архивах
