# Мир и приключения (World / Adventure)

Мир на карте мира — координатор, на котором живут герой, города, спавнер врагов,
ресурсы, камера и UI.

**Корневой узел:** `scripts/world/WorldController.gd` (`class_name WorldController`).
Он не держит состояние сам — запускает **bootstrap** (`WorldBootstrap`) и
подписывает подсистемы через **WorldEventRouter**. Цикл хода (`execute_turn` →
`TurnScheduler`) запускается из `WorldEventRouter._on_end_turn()` **после**
монолита `City.process_turn`; детали фаз/приоритетов/контекста — в
[`CORE_TURN_PIPELINE.md`](../architecture/CORE_TURN_PIPELINE.md).

## Bootstrap (`WorldBootstrap.run`)

Одноразовая инициализация мира. Порядок шагов:

1. `_init_services` — `SaveManager`, `WorldPersistenceScript`, `ResourceChainService`.
2. `_resolve_session` — определяет `SaveData` (загрузка из `pending_save` или новый
   seed), создаёт пустой `WorldStateDelta` (нужен для save).
3. `_create_map` — `MapGenerator` (seed = `rng.randi() % 999999`).
4. `_create_hero` — `HeroController.new()`.
5. `_init_hero` — `hero.setup(map_gen)`, затем `deserialize(save)` — если загрузка.
6. `_create_camera` — `WorldCamera`.
7. `_create_input` — `WorldInput`.
8. `_create_spawner` — `WorldSpawner` → `spawn_all()`.
9. `_create_cities` — `CityManager`.
10. `_create_resource_nodes` — `ResourceNodeManager`.

Результат — `BootstrapResult` (структура с 20+ полями). В `_ready()` контроллер
ждёт `process_frame` (карта должна собраться), потом `_finit_hero` и
`_finit_subsystems` (координатор боя, interaction), создаёт `WorldEventRouter`.

## Карта (`MapGenerator` / `MapModel`)

- **`MapModel`** — чистые данные: шум, биомы, проходимость. Генерация через
  `generate_noise()`; биом выбирается по высоте/температуре/влажности с порогами
  (`WATER`, `SAND`, `GRASS`, `FOREST`, `MOUNTAIN`, `SWAMP` + температурные сдвиги
  `TEMP_SNOW_*`).
- **`MapGenerator`** — координатор: держит `model`, `renderer`, `spawner`, таймапы
  (`_tile_map`, `_decor_layer`, `_resource_layer`), сетки (`terrain_grid`,
  `height_grid`, `village_cells`, `resource_cells`, `enemy_stacks`).
- `is_walkable` / `is_walkable_with_effects` (с учётом levitation),
  `world_to_map` / `local_to_map` / `map_to_local`, `_compute_reachable_cells`.

## Герой на карте

`HeroController` — фасад (см. [`hero_system.md`](hero_system.md)) с движением по
клеткам (Dijkstra), preview достижимости и боем по контакту. На карте он
управляется `WorldInput` + `WorldInteractionController` (лeft-click /右键,
сундуки, деревни).

### Планирование траектории и автоход (`HeroMovementController`)

Движение по клеткам живёт в `HeroMovementController` (`move_to`, `_move_next_step`,
`on_map_clicked`). Введено понятие **зафиксированного маршрута** — `planned_path:
Array[Vector2i]` (ячейки в мировых координатах, голова = текущая клетка) и сигнал
`planned_route_changed(committed: bool)`.

- **Двуклик с состоянием (D1).** Второй клик по `cell` в `on_map_clicked`: если
  `planned_path` пуст — маршрут не фиксирован, поэтому ставим
  `planned_path = _full_path(cell)` (необрезанный путь, `size >= 2`), эмитируем
  `planned_route_changed(true)` и **не двигаемся** (ждём проверки доступности
  цели/пути). Если `planned_path` не пуст — маршрут уже зафиксирован, поэтому
  сразу `_start_moving()` с `path = planned_path.duplicate()`.
- **Отмена (`cancel_planned_path`, ПКМ).** Очищает `planned_path` и эмитирует
  `planned_route_changed(false)`. Привязан к правому клику в `WorldInput` +
  `HeroController.cancel_planned_path()` (цепочка: `hero.cancel_planned_path()` →
  `movement.cancel_planned_path()`).
- **Автоход в начале хода (D2).** `auto_follow_at_turn_start()`: если
  `planned_path.size() >= 2` и `current_cell` ≠ цель — кладём `path =
  planned_path.duplicate()` и `_start_moving()`. В цели — очищаем `planned_path`.
  Если цель недостижима (`_full_path(goal).size() < 2`) — маршрут не трогаем
  (D5, защита от бесконечного цикла). Вызывается в `HeroController._reset_time_and_movement()`
  после `end_turn_movement()` и сброса `move_points`.
- **Синхронизация остатка (D2/D3).** `end_turn_movement()` сбрасывает `path`/`pending`,
  но **не** `planned_path` — маршрут переживает сброс хода. В `_on_step_complete`
  при остановке по `move_points <= 0` пишем `planned_path = path.duplicate()`
  (остаток без головы); при достижении цели в `_move_next_step` (`path.size() < 2`)
  очищаем `planned_path`.
- **Подсветка ходов (D3 / MarkerLayer 3.1).** Красный фронталь расширен: сосед
  красный, если достижим за бюджет (`_dist <= mp`), но войти в него за текущий
  `move_points` нельзя ( непроходим ИЛИ `_dist > mp`):
  `can_enter_within_budget = is_walkable(nb) and dist.get(nb, INF) <= mp + 0.001`.
  Зелёный/жёлтый (по остатку ≥ 1.0) и логика `_unhandled_input` не затронуты.
- **Save / Load (D4).** `planned_path` сериализуется в `HeroController._planned_path_data()`
  ({`x`,`y`} словари) и восстанавливается в `_planned_path_from()`, поэтому маршрут
  переживает сохранение/загрузку игры.

> В headless-режиме (см. «Headless-safe» ниже) `_tween_to` вызывает callback
> мгновенно, поэтому движение в тестах проходит синхронно внутри
> `auto_follow_at_turn_start()` / `on_map_clicked`.

## Города на карте

`CityManager` (см. [`city_system.md`](city_system.md)): `cities`, `capital`,
`glory` (`GloryTracker`), `on_turn_ended(month)` — обработка всех городов и
циклический приток в столицу.

## Оркестрация хода (`TurnScheduler`)

`scripts/core/TurnScheduler.gd` (`class_name TurnScheduler`) — оркестратор фаз хода
(M0: Ядро):

- Процессоры (`TurnPhaseProcessor`) регистрируются по **приоритету**;
  `execute_turn(ctx)` пробегает их по возрастанию приоритета и собирает отчёт
  `{"turn": n, "phases": {}}`.
- Подсистемы M1 (экономика), M2 (демография), M3 (город) подключаются как
  независимые процессоры — вместо разрозненных ручных вызовов.
- `WorldEventRouter` вызывает `execute_turn()` **после** монолита
  `City.process_turn` (через `GameEventBus.turn_ended → CityManager.on_turn_ended`),
  чтобы новые фазы видели уже актуальное состояние.

## Центр событий (`WorldEventRouter`)

`scripts/world/WorldEventRouter.gd` (`class_name WorldEventRouter`) — хаб событий мира.
Принимает все подсистемы в `setup(...)` и эмитит сигналы для UI/персистенса:
`end_turn_requested`, `hero_moved_to`, `village_captured`, `battle_won_at`,
`resource_extracted_at`, `reach_preview_changed`, `marker_clicked`.

## Headless-safe

В headless-режиме UI не создаётся (`_init_ui` пропускается → `_ui_manager == null`);
`is_world_visible()` возвращает `true`. Твены движения и рендер отключены на уровне
подсистем.

## Тесты

`tests/unit/test_world_persistence.gd`, а также тесты героев/городов/боёв,
затрагивающие мир (`test_hero_movement.gd`, `test_city_system.gd`).
