# Tasks: dnd-verticality-falling

> **Status (2026-09-27):** done; Phase 0–4 закрыты.

## 0. Дизайн-решения

- [x] 0.1 Определить маппинг battle-клетка → высота — зафиксировать в design.md
  - Локальная таблица боя `DNDElevationSystem` (5-футовые уровни); без
    зависимости от карты мира. Live-wiring из heightmap — Phase 6
    dnd-battle-system (scope-out).
- [x] 0.2 Определить «быстрое уменьшение высоты»
  - Порог: перепад > 1 уровня (5 футов) за шаг = падение; ≤1 уровня =
    контролируемый спуск. Push: клетка назначения ниже на ≥2 уровней →
    падение с перепадом = разница уровней × 5 футов.

## 1. Вертикальное движение (бывш. TASK_11 dnd-battle-system)

- [x] 1.1 `vertical_movement.gd`: лазание ×2 стоимость движения
  - `DNDVerticalMovement.step_cost`: ×2 за уровень подъёма; спуск ≤1 уровня — 1;
    полёт — всегда 1.
- [x] 1.2 Athletics check для сложных подъёмов (DC 10–15) через `DNDAbilityCheck`
  - ≥2 уровней за шаг: DC `clamp(10 + 5×(levels−1), 10, 15)`; провал —
    `allowed=false`, cost списан.
- [x] 1.3 Полёт: тег flying игнорирует elevation-штрафы и стоимость лазания
- [x] 1.4 Прыжок: дальность по STR; высота прыжка = 3 + STR mod футов
  - `jump_height_feet`/`jump_distance_feet`; прыжок отменяет Athletics-проверку
    при достаточной высоте.
- [x] 1.5 Unit-тесты: каждая ветка movement-cost, DC-границы, полёт
  - `tests/unit/battle/test_dnd_verticality.gd` (12 тестов фазы 1).

## 2. Урон от падения (бывш. TASK_12 dnd-battle-system)

- [x] 2.1 `falling_damage.gd`: 1d6 за каждые 10 футов, кап 20d6
  - `DNDFallingDamage.dice_count/roll_damage` (bludgeoning).
- [x] 2.2 Приземление → prone через `DNDConditionManager`
- [x] 2.3 DEX-save DC 15 против prone через `DNDSavingThrow`
  - natural 20/1 — авто-успех/провал.
- [x] 2.4 Триггер: быстрое уменьшение высоты при перемещении/выталкивании
  - `is_fall` (>1 уровня за шаг); `resolve_step` помечает `fell`/`fall_feet`.
- [x] 2.5 Unit-тесты: все дистанции 0–250+ футов, границы кэпа, save-исходы
  - `test_dnd_verticality.gd` (10 тестов фазы 2).

## 3. Интеграция

- [x] 3.1 `shove.gd`/push: толчок с обрыва → падение
  - `DNDShove.push_fall_feet(from, to)` = `DNDFallingDamage.fall_feet`
    (0 при безопасном push).
- [x] 3.2 `battle_bridge.gd`: подключение resolution порядка
  - `DnDBattleBridge.resolve_fall(profile, from, to, rng, cond)` — единая точка
    входа; падение резолвится в момент перемещения/толчка, инициатива не
    затрагивается (тест `test_fall_resolution_does_not_disturb_initiative`).
- [x] 3.3 Integration-тест: бой на возвышенности — push → fall → damage → prone
  - `tests/unit/battle/test_dnd_fall_integration.gd` (6 тестов).

## 4. Верификация и закрытие цикла

- [x] 4.1 Полный прогон зелёный
  - 1830 тестов (1802 baseline + 28 новых) | 62 errors + 4 failures =
    baseline (test_spells_json, test_crisis_events — pre-existing). 0 регрессий.
- [x] 4.2 Обновить Notes в `dnd-battle-system/tasks.md` (TASK_11/12 → DONE here)
  - Архивный `2026-09-27-dnd-battle-system/tasks.md`: TASK_11/12 → DONE
    (2026-09-27, `dnd-verticality-falling`).
- [x] 4.3 `/opsx-sync` verticality → main specs
  - `openspec/specs/verticality/spec.md` (5 requirements).
- [x] 4.4 Архивация `dnd-verticality-falling`
