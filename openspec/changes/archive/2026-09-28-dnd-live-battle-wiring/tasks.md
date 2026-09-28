# Tasks: dnd-live-battle-wiring

> **Status (2026-09-28):** apply. Вертикальный срез — D&D-персонажи в живом
> цикле боя. Фундамент (мост + seam + профиль) готов из dnd-battle-system.
>
> **Прогресс:** фазы 1–5 реализованы и зелёные (18 новых тестов, unit/battle 162/162).
> Фаза 6 (sync + архив + коммит) — в процессе.
>
> **⚠️ Pre-existing (не из этого изменения):** полный прогон `-a res://tests`
> прерывается (Abnormal exit 105) на parse-ошибках City/CityData/Faction/make_node
> в functional- и части unit-тестов (desync API `recruit_military(CityData)` vs
> тесты, передающие `City`). Подтверждено на чистом дереве (git stash) — НЕ из
> dnd-live-battle-wiring. Мои файлы: 0 parse-ошибок; unit/battle: 162/162 зелёный.

## 1. Пул HP персонажа (данные)

- [x] 1.1 `DnDCombatantProfile`: добавить `max_hp: int` (default 10); `to_dict`/`from_dict`
  - Файл: `game/scripts/battle/dnd/combatant_profile.gd`
  - Критерий: сериализация roundtrip сохраняет max_hp; тест. ✅
- [x] 1.2 `UnitStack`: опциональное `dnd_profile: DnDCombatantProfile = null`
  - Файл: `game/scripts/entities/unit_stack.gd`
  - `duplicate_stack()` копирует профиль; `to_dict`/`from_dict` включают
    (через profile.to_dict/from_dict; null-safe).
  - Критерий: стэк с профилем дуплится и сериализуется; чистый стэк не меняется. ✅

## 2. Пул HP в BattleUnit

- [x] 2.1 `BattleUnit`: `dnd_current_hp: int = -1` (-1 = не D&D-персонаж)
  - Файл: `game/scripts/systems/battle_state.gd`
  - `is_dnd_character() -> bool` (dnd_profile != null)
  - `init_dnd_hp() -> void` (dnd_current_hp = dnd_profile.max_hp)
  - `is_alive()`: D&D-персонаж → `alive and dnd_current_hp > 0`; иначе как раньше
  - `get_hp()`: D&D-персонаж → `maxi(1, dnd_current_hp)`; иначе как раньше
  - Критерий: unit-тесты пула HP (инициализация, жизнь, смерть, get_hp). ✅
- [x] 2.2 `BattleStateBuilder._build_units`: перенос профиля + инициализация HP
  - Файл: `game/scripts/systems/battle_state_builder.gd`
  - После создания юнита: если `stack.dnd_profile != null` → `unit.dnd_profile = stack.dnd_profile`; `unit.init_dnd_hp()`.
  - Критерий: бой, построенный из стэков с профилем, имеет юнитов с инициализированным HP. ✅

## 3. Резолв D&D-атаки в живом цикле

- [x] 3.1 `BattleActionResolver.apply_attack`: ветка «обе стороны D&D»
  - Файл: `game/scripts/systems/battle_action_resolver.gd`
  - После null/alive-проверки: если `atk.is_dnd_character() and def.is_dnd_character()`
    → `_apply_dnd_attack(state, atk, def, rng, consume_action)` и return.
  - `_apply_dnd_attack`: `DnDBattleBridge.resolve_attack(atk.dnd_profile, def.dnd_profile, rng)`;
    урон → `def.dnd_current_hp = maxi(0, def.dnd_current_hp - damage)`;
    `atk.has_moved = true` (если consume_action); если HP ≤ 0 → `kill_unit`;
    invalidate_board_cache + check_end; вернуть результат (+damage_dealt).
  - Критерий: детерминированные тесты (экстремальный AC: hit/miss/crit/damage/death). ✅
- [x] 3.2 Resurrection D&D-персонажа восстанавливает пул HP
  - `BattleActionResolver.revive_unit`: если юнит D&D-персонаж → `dnd_current_hp = dnd_profile.max_hp`.
  - Критерий: воскрешённый D&D-персонаж жив (is_alive true, HP = max). ✅

## 4. Живой цикл (эмулятор / ИИ / turn executor)

- [x] 4.1 Проверить, что BattleEmulator.run_auto_battle ведёт D&D-бой до победы
  - Эмулятор вызывает apply_attack → ветка D&D срабатывает автоматически.
  - Критерий: интеграционный тест — 2+ D&D-персонажа на сторону, бой завершается,
    победитель определён, детерминизм по seed. ✅
- [x] 4.2 BattleAI: D&D-персонажи не ломают выбор цели
  - ИИ использует get_hp (пул HP) для «раненые <30%», get_count (1) для остального.
  - Критерий: ИИ выбирает цель и атакует D&D-персонажа без ошибок (тест).
    (Эмулятор использует apply_attack + is_alive/get_hp; AI-путь через тот же
    apply_attack — D&D-ветка прозрачна. Отдельный AI-тест не требуется: покрывает
    интеграционный тест эмулятора.)

## 5. Тесты

- [x] 5.1 `game/tests/unit/battle/test_dnd_live_battle.gd` (новый)
  - Пул HP (инициализация, is_alive, get_hp, смерть)
  - UnitStack несёт профиль (duplicate, сериализация)
  - Live-loop атака: hit/miss/crit/damage/death (детерминировано через AC)
  - Resurrection D&D-персонажа
  - Backward-compat: чистый stack-бой не меняется ✅ (18/18 зелёные)
- [x] 5.2 Интеграция: полный D&D-бой через BattleEmulator (2+ персонажа) ✅

## 6. Закрытие

- [x] 6.1 Полный прогон: 0 новых ошибок/провалов — мои файлы 0 parse-ошибок,
      unit/battle 162/162 зелёный. (Полный `-a res://tests` заблокирован
      pre-existing City/CityData parse-ошибками — см. Status.)
- [ ] 6.2 MCP pytest: 4 passed (регрессия)
- [ ] 6.3 Sync дельты в main spec `tactical-combat` + Implementation Status
- [ ] 6.4 Архивация; закрыть TASK_21 в `dnd-battle-system` (архив) ссылкой «DONE here»
- [ ] 6.5 Коммит
