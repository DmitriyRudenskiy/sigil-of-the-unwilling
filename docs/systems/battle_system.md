# Боевая система

Бой — пошаговое сражение двух армий (атакующий / защищающийся) на поле 17×11.
Разделён на **чистую логику** (без узлов Godot) и **представление** (визуал/ввод).

## Слои

| Слой | Класс | Ответственность |
| --- | --- | --- |
| Состояние | `scripts/systems/BattleState.gd` | Чистое состояние боя (юниты, очередь, bfs) |
| Логика | `scripts/systems/BattleActionResolver.gd` | Атака, заклинания, чардж, ребёрт, первый удар |
| Урон | `scripts/systems/BattleDamageResolver.gd` | Вычисление урона |
| Правила | `scripts/core/BattleRules.gd` | ATK/DEF-множитель, удача, мораль, ретрит, контратака |
| Порядок ходов | `scripts/systems/BattleTurnExecutor.gd` | State machine очередности (единственный мутант состояния) |
| AI | `scripts/systems/BattleAI.gd` | Чистая логика решений на основе BattleState |
| Поток | `scripts/systems/BattleFlow.gd` | Создание боя, ожидание, возврат результата |
| Координатор | `scripts/systems/BattleController.gd` | Инициализация, визуал, связка сигналов |
| Представление | `scripts/systems/BattleView.gd` | Поле, спрайты, подсветка, камера, курсор |
| Ввод | `scripts/systems/BattleInput.gd` | Клики, подсветка ходов/атак, выбор юнитов |
| Эффекты | `scripts/core/BattleFX.gd` | Визуальные эффекты |
| Мост в мир | `scripts/world/WorldBattleCoordinator.gd` | За бой из мира, применение результатов |

## BattleState (`scripts/systems/BattleState.gd`)

Чистое состояние, **не зависит от узлов Godot** (паттерн как у `City`):
- `attacker_units` / `defender_units: Array[BattleUnit]`
- `active_unit`, `turn_queue`, `turn_idx`, `is_player_turn`, `battle_over`
- `battle_winner` (`Side`), бонусы героев (`attacker_hero_bonus`, `defender_hero_bonus`)
- Кэш bfs (`_unit_grid`, `_reachable_cache`), поле `BW=17`, `BH=11`
- `place_army()`, `build_queue()`, `advance_turn()`, `get_reachable()` (BFS с учётом
  «кольца не хватает ходов»), `kill_unit`/`revive_unit`, `_apply_artifact_effects`.

## BattleActionResolver (вся боевая логика)

`extends RefCounted`, **не хранит состояние** — `BattleState` передаётся параметром.
- `apply_attack(state, atk, def, is_melee, rng)` — полный цикл: первый удар → урон →
  чардж → ребёрт (rebirth) → контратака. Возвращает `Dictionary` (damage, kills,
  first_strike, charge, rebirth, ...).
- `apply_spell(state, id, caster, target, ...)` — наложение заклинания.
- Отдельные хелперы: `_apply_first_strike`, `_get_charge_multiplier`, чардж, ребёрт.

## BattleRules (`extends RefCounted`)

Константы и формулы боя:
- `ATK_ADVANTAGE_PER_POINT = 0.05`, `DEF_ADVANTAGE_PER_POINT = 0.025`
- `MAX_DAMAGE_MULTIPLIER = 5.0`, `MIN_DAMAGE_MULTIPLIER = 0.3`
- `LUCK_CHANCE = 0.10`, `MORALE_CHANCE = 0.08`
- `RETREAT_SURVIVAL_RATIO = 0.5`, `DEFEND_DEFENSE_BONUS = 1.2`, `RANGED_MELEE_PENALTY = 0.5`
- `can_luck` / `can_morale` — учёт тегов (undead/elemental/mind_immune/dragon).

## Порядок ходов (BattleTurnExecutor)

State machine, **единственный, кто мутрует `BattleState`**. Состояния:
`IDLE → TURN_START → WAITING_INPUT → AI_THINKING → PLAYER_ANIMATING → AI_ANIMATING → BATTLE_OVER`.
Эмитит сигналы (`pulse_unit`, `phase_changed`, `active_unit_changed`, `execute_move`,
`spell_cast_executed`, `end_battle`); `_ai_think_time` из `GameSettings`.

## Поток боя (BattleFlow)

`start_battle(attacker_army, defender_army, attacker_bonus, defender_bonus,
attacker_artifact_mods, defender_artifact_mods, obstacle_seed, hero_magic)`:
создаёт `Battle.tscn`, добавляет в корень, ждёт `battle_finished`, эмитит
`battle_completed(winner, surviving_atk, surviving_def)`. Не прячет мир и не меняет
героя — это делает `WorldController`.

## Интеграция с миром

`WorldBattleCoordinator` запускает бой по контакту героя с врагом (см.
[`world_adventure.md`](world_adventure.md)) и применяет результаты обратно в
`HeroController` (`apply_battle_results`).

## Связь со spell-системой

Заклинания в бою — через `scripts/data/BattleSpellBridge.gd` (мост между spell-системой и
боевой логикой); панель — `scripts/ui/BattleSpellbookPanel.gd`. Подробности —
[`spells_system.md`](spells_system.md).

## Тесты

`tests/test_battle_state.gd`, `tests/test_battle_action_resolver.gd`,
`tests/test_battle_ai.gd`, `tests/test_battle_flow.gd`,
`tests/test_battle_integration.gd`, `tests/test_battle_coordinator.gd`,
`tests/test_battle_cursor.gd`, `tests/test_battle_retreat_queue.gd`,
`tests/test_battle_retreat_smoke.gd`, `tests/test_battle_spell_executor.gd`,
`tests/test_battle_spell_flow.gd`, `tests/test_battle_spell_targeting.gd`,
`tests/test_battle_fox.gd`.
