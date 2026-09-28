# Proposal: tactical-combat-implementation

**Status:** Open (propose)
**Depends on:** архивированный спецификационный цикл `tactical-battle-system` (archive/2026-09-27-tactical-battle-system) (спека синхронизирована в `openspec/specs/tactical-combat/spec.md`, задачи 3.x–9.x осознанно вынесены сюда)

## Why

Изменение архивированный спецификационный цикл `tactical-battle-system` (archive/2026-09-27-tactical-battle-system) закрыто как **documentation-only цикл**: main-spec `tactical-combat` описывает целевое тактическое поведение, которого нет в текущей реализации (`BattleTurnExecutor` — партии сторон без инициативы; `BattleDamageResolver` не учитывает местность/фланги; нет LOS для дальнего боя). Чтобы цикл спецификации не оставался вечно «открытым» из-за кода, реализация вынесена в отдельное изменение со своим propose→apply→archive контуром.

## What Changes

Реализация целевого поведения из `specs/tactical-combat/spec.md` (строки Implementation Status = NOT IMPLEMENTED):

1. **Инициатива** — очерёдность по ловкости + класс/раса модификаторы, детерминизм по seed (`BattleTurnExecutor`).
2. **Дальний бой** — линия видимости, штрафы дистанции, препятствия (`BattleActionResolver`/LOS из `game/scripts/battle/dnd/line_of_sight.gd` — переиспользовать).
3. **Бонусы местности** — лес/холм/укрепление/вода в `BattleDamageResolver` + отображение в `BattleView`; данные брать из `TerrainCostTable` (map-generation-improvement).
4. **Фланговые атаки** — направление юнита, бонусы фланга/тыла, UI-подсветка.
5. **ИИ-доктрина** — приоритеты целей, укрытия, концентрация огня, отступление, агрессия по типам (`battle_ai.gd`).
6. **Исход боя расширения** — трофеи, ранения выживших.
7. **Ожидание (defend+)** — бонус защиты +20%, контратака.

## Capabilities

### Modified Capabilities
- `tactical-combat`: строки таблицы Implementation Status переходят NOT IMPLEMENTED → IMPLEMENTED (delta через MODIFIED Requirements при sync).

## Impact

- `game/scripts/systems/battle_turn_executor.gd`, `battle_action_resolver.gd`, `battle_damage_resolver.gd`, `battle_state.gd`, `battle_ai.gd`, `battle_view.gd`
- Данные: таблица местности боя (новая, поверх `TerrainCostTable`)
- Тесты: `game/tests/systems/` battle-набор; калибровка `balance_probe` обязана остаться в допусках (риски баланса — см. design)
- UI: индикатор инициативы, подсветка флангов (headless-верификации нет → отдельные критерии)

## Acceptance Criteria

- [ ] 1. Инициатива считается и детерминирована по seed; тесты порядка ходов зелёные
- [ ] 2. Местность влияет на урон/защиту согласно спеке; тесты по каждому типу
- [ ] 3. Фланги/тыл дают бонусы согласно спеке; тесты направлений
- [ ] 4. ИИ-доктрина покрыта сценарными тестами (цели, отступление)
- [ ] 5. balance_probe: дельта win-rate в допуске ±5% или пересмотренная калибровка задокументирована
- [ ] 6. Полный прогон тестов зелёный; delta синхронизирована в main spec; архивированный спецификационный цикл `tactical-battle-system` (archive/2026-09-27-tactical-battle-system) архивируется
