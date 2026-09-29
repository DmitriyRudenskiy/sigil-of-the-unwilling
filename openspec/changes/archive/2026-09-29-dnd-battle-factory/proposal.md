# Proposal: dnd-battle-factory

**Status:** Open (propose)
**Depends on:** `dnd-live-battle-wiring` (archive/2026-09-28) — D&D-персонажи сражаются в живом цикле (пул HP, d20 vs AC); `dnd-class-race-tactical-bonuses` (archive/2026-09-29) — класс/расовые бонусы; `dnd-battle-system` (archive/2026-09-27) — мост + профиль.

## Why

D&D-бой (per-character модель: пул HP, d20 vs AC, класс/расовые бонусы) полностью реализован и протестирован — **но только в тестах**. Production-код не создаёт `UnitStack` с `dnd_profile`: реальный триггер боя (`WorldBattleCoordinator.start_enemy_attack` → `BattleFlow.start_battle`) работает в stack-модели (армии юнитов, surviving stacks), а `_apply_results` stack-ориентирован.

Результат: у игры нет **production-API для создания/разрешения D&D-боя**. Чтобы сценарий/событие могло запустить D&D-бой и получить результат (победитель + выжившие персонажи), нужен чистый entry point.

Привязка D&D-боя к `WorldBattleCoordinator` — большая задача (D&D-результат ≠ stack-результат; требует отдельной обработки результатов и плейтеста). Первый, bounded, testable шаг — **фабрика**: production-компонент, который строит D&D-бой из явных определений персонажей и разрешает его.

## What Changes

**`DnDBattleFactory` — production-API «построить и разрешить D&D-бой по определениям персонажей».**

Новый `class_name DnDBattleFactory` (battle/dnd/) + data-класс `DnDCharacterDef` (определение персонажа: id/name/class_id/race_id/weapon/is_ranged/max_hp/speed/abilities/ac_override). Методы:

1. **`build_profile(def) -> DnDCombatantProfile`** — профиль из определения (характеристики, class/race, оружие, max_hp; AC из DEX+доспех или `ac_override`).
2. **`build_stack(def) -> UnitStack`** — UnitStack с `dnd_profile` (count=1, speed).
3. **`build_battle(ally_defs, enemy_defs) -> BattleState`** — полный бой через `BattleStateBuilder` (профили переносятся, HP инициализируется).
4. **`simulate(ally_defs, enemy_defs, seed) -> Dictionary`** — разрешить бой через `BattleEmulator.run_auto_battle`; вернуть `{winner, atk_survivors, def_survivors}` (детерминировано по seed).

Сценарий/событие вызывает `DnDBattleFactory.simulate(...)` и получает результат D&D-боя — без правки `WorldBattleCoordinator` и stack-flow.

## Capabilities

### Modified Capabilities
- `tactical-combat`: добавлено требование «D&D-бой по определениям персонажей» (ADDED Requirement) — игра предоставляет production-API для построения и разрешения D&D-боя из явных определений персонажей.

## Impact

- `game/scripts/battle/dnd/battle_factory.gd` (новый — `DnDBattleFactory` + `DnDCharacterDef`)
- Тесты: `game/tests/unit/battle/test_dnd_battle_factory.gd` (новый)
- **Не затрагивает**: stack-модель, `WorldBattleCoordinator`, `BattleFlow`, `BattleStateBuilder` (используется как есть), hero, save-систему, UI

## Acceptance Criteria

- [ ] 1. `DnDCharacterDef` несёт class/race/abilities/HP/weapon/speed; `build_profile` корректен (abilities, class_id/race_id, max_hp, AC)
- [ ] 2. `build_stack` создаёт UnitStack с `dnd_profile` (count=1, speed из def)
- [ ] 3. `build_battle` строит BattleState: обе стороны — D&D-персонажи (is_dnd_character, HP инициализирован)
- [ ] 4. `simulate` разрешает бой до победы (winner = attacker/defender; у проигравших 0 выживших); детерминизм по seed
- [ ] 5. Класс/расовые бонусы применяются (персонаж с class_id получает бонус в бою)
- [ ] 6. Backward-compat: stack-модель и существующий набор не меняются (полный прогон зелёный)
