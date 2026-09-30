# Proposal: dnd-live-battle-wiring

**Status:** Open (propose)
**Depends on:** `dnd-battle-system` (archive/2026-09-27-dnd-battle-system) — мост `DnDBattleBridge` + seam `BattleUnit.dnd_profile` + `DnDCombatantProfile` готовы и протестированы; `tactical-combat-implementation` (archive/2026-09-28) — живой цикл боя (инициатива, местность, фланги, ИИ, эмулятор) стабилен.

## Why

Цикл `dnd-battle-system` закрыл все D&D-механики (характеристики, AC, броски атаки, урон, спасброски, условия, вертикальность) и построил мост `DnDBattleBridge.resolve_attack` (d20 vs AC, крит, кубики урона) + seam `BattleUnit.dnd_profile`. Но **живой цикл боя** (`BattleActionResolver.apply_attack`) мост не использует: он работает в stack-модели (count × per-unit hp, kills = damage/hp), где у юнита нет пула HP персонажа. TASK_21 («BattleController uses DnDMechanics») осознанно отложен как архитектурное изменение.

Результат: D&D-бой существует только как изолированные юнит-тесты моста, а не как играбельный режим. Персонажи с D&D-профилями не могут сражаться в живом цикле (BattleTurnExecutor / BattleAI / BattleEmulator).

## What Changes

**Вертикальный срез: D&D-персонажи сражаются в живом цикле боя.**

D&D-персонаж = `UnitStack` (speed для движения) + `DnDCombatantProfile` (пул HP, AC, характеристика атаки, оружие). Профиль несётся на стэке (опциональный поле, default null — backward compatible). Боевой цикл ветвится: когда **обе** стороны пары атаки — D&D-персонажи, атака резолвится через `DnDBattleBridge.resolve_attack` (d20 vs AC, кубики урона), урон применяется к пулу HP цели, персонаж умирает при HP ≤ 0. Чистые stack-бои не меняются.

1. **Пул HP персонажа** — `DnDCombatantProfile.max_hp` (сериализуемо); `BattleUnit.dnd_current_hp` + `is_dnd_character()`/`init_dnd_hp()`; `is_alive()`/`get_hp()` учитывают пул HP для D&D-персонажей.
2. **Профиль на стэке** — `UnitStack.dnd_profile` (опционально), `duplicate_stack()` копирует, `to_dict`/`from_dict` включают.
3. **Инициализация в бою** — `BattleStateBuilder._build_units` переносит профиль на юнит и инициализирует HP.
4. **Резолв атаки** — `BattleActionResolver.apply_attack`: ветка «обе стороны D&D» → `DnDBattleBridge.resolve_attack` + урон в пул HP + смерть при HP ≤ 0.
5. **Живой цикл** — BattleTurnExecutor / BattleAI / BattleEmulator работают с D&D-боями без изменений (через apply_attack + is_alive/get_hp); resurrection D&D-персонажа восстанавливает пул HP.

## Capabilities

### Modified Capabilities
- `tactical-combat`: добавлено требование «D&D-персонажный бой» (ADDED Requirement в delta) — боевой цикл поддерживает персонную D&D-модель поверх stack-модели.

## Impact

- `game/scripts/battle/dnd/combatant_profile.gd` (+max_hp)
- `game/scripts/entities/unit_stack.gd` (+dnd_profile)
- `game/scripts/systems/battle_state.gd` (BattleUnit: пул HP, is_alive/get_hp)
- `game/scripts/systems/battle_state_builder.gd` (инициализация профиля/HP)
- `game/scripts/systems/battle_action_resolver.gd` (ветка D&D-атаки, resurrection)
- Тесты: `game/tests/unit/battle/test_dnd_live_battle.gd` (новый), backward-compat через существующий зелёный набор
- **Не затрагивает**: stack-модель, hero battle stack, save-систему (D&D-бои пока вне сохранения — follow-up), UI (headless-верификации нет)

## Acceptance Criteria

- [ ] 1. D&D-персонаж (стэк + профиль) инициализируется с пулом HP из профиля; is_alive/get_hp корректны
- [ ] 2. Атака D&D vs D&D резолвится через мост (d20 vs AC, урон в пул HP); детерминированные тесты (экстремальный AC)
- [ ] 3. Персонаж умирает при HP ≤ 0; бой завершается уничтожением стороны
- [ ] 4. Полный D&D-бой через BattleEmulator (2+ персонажа) завершается победой одной стороны
- [ ] 5. Backward-compat: чистые stack-бои не меняются (существующий набор зелёный)
- [ ] 6. Полный прогон: 0 новых ошибок/провалов
