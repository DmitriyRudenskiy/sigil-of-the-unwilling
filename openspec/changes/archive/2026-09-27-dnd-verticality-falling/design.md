# Design: dnd-verticality-falling

## 0.1 Маппинг battle-клетка → высота

**Решение: локальная таблица боя — `DNDElevationSystem`.**

- D&D-боевая доска самодостаточна: `DNDElevationSystem` (5-футовые уровни на
  клетку, доска 17×11 по умолчанию) конструируется per-battle и хранит высоту
  каждой клетки.
- `DNDVerticalMovement` / `DNDFallingDamage` принимают только
  `DNDElevationSystem` (или уровни from/to) — **нет зависимости от карты мира**.
- Live-wiring (заполнение таблицы из heightmap карты мира, привязка к
  `BattleState`-сетке) — Phase 6 `dnd-battle-system` (scope-out, не блокирует
  данный цикл). Модули чистые и тестируемые сейчас.
- Прецедент: весь D&D-слой (`elevation_system`, `height_modifier`,
  `line_of_sight`, `cover_calculator`) уже живёт так же — отдельно от
  live-боя.

## 0.2 «Быстрое уменьшение высоты» (порог падения vs контролируемый спуск)

**Решение: порог — 1 уровень (5 футов) на один шаг.**

| Перепад за шаг | Классификация | Эффект |
|---|---|---|
| 0 | плоскость | cost 1 |
| −1 уровень (спуск ≤5фт) | контролируемый спуск | cost 1, без урона (5e: добровольный спуск до 5фт) |
| ≥1 уровень (подъём) | лазание | cost ×2 за уровень; ≥2 уровней — Athletics DC 10–15; прыжок (3+STR mod футов) отменяет проверку |
| ≤−2 уровня (>5фт) | **падение** | cost 1 + урон 1d6/10фт (кап 20d6) + prone, DEX save DC 15 |

- Существо **не может** добровольно переместиться на клетку ниже чем на 1
  уровень — такой шаг всегда падение (даже «намеренный» спуск с обрыва).
- Push (shove, `PUSH_DISTANCE_FEET = 5` горизонтально): если клетка назначения
  ниже исходной на ≥2 уровней — толчаемое существо падает с перепадом, равным
  разнице уровней × 5 футов.
- Полёт (тег `flying`): любой перепад — cost 1, без лазания/проверок/падения.

## Формулы (5e PHB)

- Лазание: difficult terrain → ×2 cost. DC сложного подъёма:
  `clamp(10 + 5×(levels−1), 10, 15)` (1 уровень → 10, ≥2 → 15).
- Прыжок: вертикаль `3 + STR mod` футов; горизонт `10 + STR mod` футов.
  Подъём на N уровней прыжком без проверки, если `5×N ≤ 3 + STR mod`.
- Падение: `floor(feet/10)` d6, кап 20d6, bludgeoning; prone при провале
  DEX save DC 15 (natural 20/1 — авто-успех/провал через `DNDSavingThrow`).

## Архитектура (файлы)

- `scripts/battle/dnd/vertical_movement.gd` — `DNDVerticalMovement`
  (static: step cost, Athletics DC, прыжок; `resolve_step`).
- `scripts/battle/dnd/falling_damage.gd` — `DNDFallingDamage`
  (static: порог, feet, dice, `resolve` с save + ConditionManager).
- `scripts/battle/dnd/shove.gd` — `push_fall_feet()` (триггер падения при push).
- `scripts/battle/dnd/battle_bridge.gd` — `resolve_fall(profile, ...)`
  (единая точка входа для боевого фреймворка; инициатива не затрагивается —
  падение резолвится в момент перемещения/толчка, до следующего хода).
- Тесты: `tests/unit/battle/test_dnd_verticality.gd` (1.5, 2.5),
  `tests/unit/battle/test_dnd_fall_integration.gd` (3.3: push → fall →
  damage → prone).
