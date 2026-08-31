# Мир и приключения (World / Adventure)

Мир на карте мира — координатор, на котором живут герой, города, спавнер врагов,
ресурсы, камера и UI.

**Корневой узел:** `world/WorldController.gd` (`class_name WorldController`).
Он не держит состояние сам — запускает **bootstrap** (`WorldBootstrap`) и
подписывает подсистемы через **WorldEventRouter**.

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

## Города на карте

`CityManager` (см. [`city_system.md`](city_system.md)): `cities`, `capital`,
`glory` (`GloryTracker`), `on_turn_ended(month)` — обработка всех городов и
циклический приток в столицу.

## Оркестрация хода (`TurnScheduler`)

`core/TurnScheduler.gd` (`class_name TurnScheduler`) — оркестратор фаз хода
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

`world/WorldEventRouter.gd` (`class_name WorldEventRouter`) — хаб событий мира.
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
