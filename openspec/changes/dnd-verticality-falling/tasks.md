# Tasks: dnd-verticality-falling

> **Status (2026-09-27):** propose готов; apply не начинался. Блокировка: определение cell↔elevation маппинга (задача 0.1) до начала фазы 1.

## 0. Дизайн-решения

- [ ] 0.1 Определить маппинг battle-клетка → высота (наследуется из карты мира или локальная таблица боя?) — зафиксировать в design.md
- [ ] 0.2 Определить «быстрое уменьшение высоты» (порог падения vs контролируемый спуск)

## 1. Вертикальное движение (бывш. TASK_11 dnd-battle-system)

- [ ] 1.1 `vertical_movement.gd`: лазание ×2 стоимость движения через `action_economy.gd`
- [ ] 1.2 Athletics check для сложных подъёмов (DC 10–15) через `DNDAbilityCheck`
- [ ] 1.3 Полёт: тег flying игнорирует elevation-штрафы и стоимость лазания
- [ ] 1.4 Прыжок: дальность по STR; высота прыжка = 3 + STR mod футов
- [ ] 1.5 Unit-тесты: каждая ветка movement-cost, DC-границы, полёт

## 2. Урон от падения (бывш. TASK_12 dnd-battle-system)

- [ ] 2.1 `falling_damage.gd`: 1d6 за каждые 10 футов, кап 20d6, через `DNDDamageCalculator`
- [ ] 2.2 Приземление → prone через `DNDConditionManager`
- [ ] 2.3 DEX-save DC 15 против prone через `DNDSavingThrow`
- [ ] 2.4 Триггер: быстрое уменьшение высоты при перемещении/выталкивании
- [ ] 2.5 Unit-тесты: все дистанции 0–250+ футов, границы кэпа, save-исходы

## 3. Интеграция

- [ ] 3.1 `shove.gd`/push: толчок с обрыва → падение с `PUSH_DISTANCE_FEET` перепадом
- [ ] 3.2 `battle_bridge.gd`: подключение resolution порядка (инициатива не ломается)
- [ ] 3.3 Integration-тест: бой на возвышенности — push → fall → damage → prone

## 4. Верификация и закрытие цикла

- [ ] 4.1 Полный прогон `run_all.sh` зелёный
- [ ] 4.2 Обновить Notes в `dnd-battle-system/tasks.md` (TASK_11/12 → DONE here) перед его архивацией
- [ ] 4.3 `/opsx-sync` verticality → main specs
- [ ] 4.4 Архивация `dnd-verticality-falling`
