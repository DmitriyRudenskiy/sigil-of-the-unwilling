## 1. Планирование маршрута (HeroMovementController)

- [ ] 1.1 Добавить поле `planned_path: Array[Vector2i]` и сигнал `planned_route_changed(committed: bool)`.
- [ ] 1.2 В `on_map_clicked` сделать 2-й клик состоятельным: если `planned_path` пуст — фиксировать `planned_path = _full_path(target)` (необрезанный, size >= 2), эмитировать `planned_route_changed(true)`; если не пуст — немедленное движение (`_start_moving()`).
- [ ] 1.3 Реализовать отмену маршрута (`cancel_planned_path`): очистка `planned_path`, эмитировать `planned_route_changed(false)`, привязать к ПКМ / существующему `cancel_pending`.

## 2. Автоход в начале хода

- [ ] 2.1 Добавить `auto_follow_at_turn_start()`: если `planned_path.size() >= 2` и `current_cell` не в цели — `path = planned_path.duplicate()`, `_start_moving()`; в цели — очистить `planned_path`.
- [ ] 2.2 В `HeroController._reset_time_and_movement()` после сброса `move_points` вызвать `movement.auto_follow_at_turn_start()`; исправить `end_turn_movement()`, чтобы не очищать зафиксированный маршрут.
- [ ] 2.3 Синхронизировать остаток: в `_on_step_complete` при остановке по `move_points <= 0` и при достижении цели записывать `planned_path` (остаток `path` без головы) или очищать его.

## 3. Подсветка доступности (MarkerLayer)

- [ ] 3.1 В `show_markers` расширить красный фронталь: клетки-соседи достижимых, в которые нельзя попасть за бюджет (непроходимы ИЛИ `_dist > mp`), а не только непроходимые.
- [ ] 3.2 Проверить, что зелёный/жёлтый (по остатку ≥ 1.0) и логика `_unhandled_input` не сломаны.

## 4. Save / Load

- [ ] 4.1 Включить `planned_path` в сериализацию/загрузку героя (HeroController → persistence).

## 5. Верификация

- [ ] 5.1 Прогнать `game/tools/shell/run_operability.sh`; убедиться, что вердикт `CLEAN`.
- [ ] 5.2 Добавить новые предупреждения консоли (если есть) в `docs/CONSOLE_ALLOWLIST.md`, если они безобидны.

## 6. Документация

- [ ] 6.1 Обновить `docs/world_adventure.md` (и связанные) поведением: планирование траектории, автоход в начале хода, подсветка ходов.

## 7. Коммит

- [ ] 7.1 Закоммитить только файлы текущего цикла (`hero-path-planning`), с актом по задачам.
