# Proposal: dnd-verticality-falling

**Status:** Done (2026-09-27, archived)
**Scope-out from:** `dnd-battle-system` (TASK_11 Vertical Movement, TASK_12 Falling Damage — помечены `[~] scope-out 2026-09-27`)

## Why

`dnd-battle-system` закрыт без TASK_11/TASK_12: боевая модель клеток ещё не имеет pipeline стоимости движения по клеткам, а высота реализована только как статический модификатор (`elevation_system.gd`, `height_modifier.gd`). Строительные блоки уже готовы — остаётся связка «движение ↔ высота ↔ падение». Вынос в отдельный цикл позволяет заархивировать dnd-battle-system и вести реализацию вертикального перемещения собственным propose→apply контуром.

## What Changes

- **NEW capability `verticality`:** вертикальное перемещение и урон от падения поверх существующих модулей.
- `game/scripts/battle/dnd/vertical_movement.gd`: лазание = ×2 стоимость движения; Athletics-проверка для сложных подъёмов (DC 10–15); полёт игнорирует штрафы рельефа; прыжок по STR (дальность 3 + STR mod футов в высоту).
- `game/scripts/battle/dnd/falling_damage.gd`: 1d6 за 10 футов, максимум 20d6; приземление → prone; опциональный DEX-save DC 15 против prone; триггер — быстрое уменьшение высоты (в т.ч. `PUSH_DISTANCE_FEET` из shove/push — толчок с обрыва уже запланирован в dnd-battle-system).
- Интеграция: `battle_bridge.gd`, `initiative_tracker.gd` (порядок resolution), `action_economy.gd` (стоимость действий).

## Capabilities

### New Capabilities
- `verticality`: правила вертикального движения и падения в бою.

### Modified Capabilities
- `height-system` (delta из dnd-battle-system): добавляется требование разрешения изменения высоты *(уточнить при sync)*.

## Impact

- Новые файлы: `vertical_movement.gd`, `falling_damage.gd` (+ тесты в `game/tests/`)
- Изменяемые: `battle_bridge.gd`, `action_economy.gd`, `shove.gd` (триггер падения при push)
- Готовые зависимости: `DNDAbilityCheck`, `DNDSavingThrow`, `DNDConditionManager(PRONE)`, `DNDDamageCalculator`
- Блокирующий вопрос дизайна: отображение battle-клеток на высоту решается в Phase 6 dnd-battle-system (live-wiring) — см. open questions

## Acceptance Criteria

- [x] 1. Лазание ×2 и Athletics DC 10–15 работают, тесты зелёные
- [x] 2. Прыжок/высота прыжка по STR формуле, тесты границ
- [x] 3. Урон падения 1d6/10фт, кап 20d6, prone + DEX-save DC 15 — unit-тесты всех дистанций
- [x] 4. Push с обрыва наносит урон падения (интеграция shove → falling_damage)
- [x] 5. Полёт игнорирует elevation-штрафы
- [x] 6. Полный прогон зелёный; delta synced; cycle archived
