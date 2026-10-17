## 1. Мана персонажа из Intelligence

- [x] 1.1 `DnDCombatantProfile`: `mana_max` (вычисляется из INT-модификатора по формуле `maxi(5, 5 * (2 + mod))`), `mana_current`, `to_dict/from_dict`.
- [x] 1.2 `BattleState.BattleUnit`: `has_mana()`, `get_mana()`, `get_mana_max()`, `spend_mana(n)`, `refund_mana(n)` — для юнита без профиля возвращают «маны нет».
- [x] 1.3 Оплата заклинаний: персонаж платит из личного пула, стек — из `HeroMagic` (существующий путь); возврат при неудаче — в тот же пул (`battle_controller.gd`, `spell_caster.gd`).
- [x] 1.4 Тесты: формула (INT 16 → 25, INT 8 → 5), отсутствие маны у стека, списание/возврат в оба пула.

## 2. Уровень персонажа

- [x] 2.1 `DnDCharacterDef.level` → `DnDCombatantProfile.level` (default 1) в `battle_factory.gd`; сериализация профиля.
- [x] 2.2 Тесты: уровень из определения, default, round-trip, «уровень не меняет боевые числа».

## 3. Таймер игрокового хода

- [x] 3.1 `BattleState`: `turn_time_limit = 30`, `turn_time_left`, `turn_timer_running`; константа `TURN_TIME_LIMIT`.
- [x] 3.2 `battle_turn_executor.gd`: вооружение таймера на старте игрокового хода, снятие на конце, `tick_turn_timer(delta)`, истечение → путь `do_skip`; ходы ИИ таймер не вооружают.
- [x] 3.3 Пауза при модальном окне (книга заклинаний, настройки, результат) в `battle_controller.gd` / `battle_ui.gd`.
- [x] 3.4 Тесты: истечение пропускает ход, ИИ без таймера, пауза не тратит время, остаток после 10 с.

## 4. Умирающее состояние вместо мгновенной смерти

- [ ] 4.1 `BattleState.BattleUnit`: `death_saves: DNDDeathSaves`, `is_dying()`, `is_stable()`, `can_act()`.
- [ ] 4.2 `battle_action_resolver.kill_unit`: ветка `is_dnd_character()` → `down_unit()` (HP 0, DYING, остаётся в сетке и очереди); stack-юниты — прежний путь.
- [ ] 4.3 Начало хода умирающего: спасброски вместо действия (`battle_turn_executor.gd`), 3 провала → обычная гибель через `kill_unit`.
- [ ] 4.4 Цель атаки: умирающий/стабилизированный не может быть обычной целью; `check_end()` → «нечем действовать».
- [ ] 4.5 Тесты: 0 HP → умирающий, спасброски, стабилизация, гибель, победа по «нечем действовать», stack-ветка без изменений.

## 5. Действие Rescue

- [ ] 5.1 `battle_action_resolver.rescue_unit(state, rescuer, target)`: смежность, цель — умирающий союзник, проверка характеристики DC 10 (`ability_check.gd`), успех → `stabilize()`, nat 20 → `heal(1)`; тратит действие.
- [ ] 5.2 `battle_turn_executor.request_rescue(target)` + сигнал UI (`rescue_requested`) + `battle_input`-выбор цели; медальон — в шаге 5 UI-паритета.
- [ ] 5.3 Строки `game_text` + `locale/` (en/ru) для действия и его статуса.
- [ ] 5.4 Тесты: успех стабилизирует, nat 20 даёт 1 HP, провал не меняет состояние, недоступно без умирающего/смежности, чужой ход запрещён.

## 6. Документация и реестры

- [ ] 6.1 `docs/DECISIONS.md`: мана из INT, уровень display-only, таймер 30 с, DYING+Rescue, победа по «нечем действовать».
- [ ] 6.2 `docs/mvp/TICKETS.md` + зеркало: тикеты на таймер хода и Rescue; связь с шагом 5 UI.
- [ ] 6.3 `docs/CHANGELOG.md`; `python3 scripts/check_docs_links.py` чисто.

## 7. Верификация

- [ ] 7.1 `game/run_tests.sh` локально зелёный (GdUnit4 0/101 + MCP e2e), тестовый леджер +/−/quarantine.
- [ ] 7.2 `python3 -m gdtoolkit.linter` по изменённым файлам чисто.
- [ ] 7.3 Сводка в PR; мерж только по «мержи» владельца после ux-review шага 5.
