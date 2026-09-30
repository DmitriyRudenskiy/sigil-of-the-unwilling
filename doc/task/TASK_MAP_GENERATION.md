# Карта: генерация и тюнинг

## Порядок генерации (`MapGenerator.generate()`)

1. `MapModel.generate_noise()` — 3 шума (высота/температура/влажность) → базовые биомы
2. `smooth_invalid_adjacencies()` — горы/снег у воды → песок
3. `MapMountainGenerator` — разломы, uplift, эрозия, снежные шапки
4. `MapRiverGenerator` — источники на высотах, сток по градиенту, слияния
5. `MapForestGenerator` — кластеры леса (~25% карты), DENSE_FOREST в ядре
6. Рендер + спавн деревень/ресурсов/врагов
7. `MapRoadGenerator` — MST между деревнями, A* с costs, мосты через реки

## Ключевые параметры

| Файл | Параметр | Значение | Эффект |
|---|---|---|---|
| MapModel | WATER/SAND/GRASS/FOREST/MOUNTAIN_THRESHOLD | 0.35/0.40/0.65/0.75/0.85 | границы биомов по высоте |
| MapMountainGenerator | FAULT_COUNT | 5 | число разломов (хребтов) |
| MapMountainGenerator | UPLIFT_INTENSITY | 0.4 | высота хребтов |
| MapMountainGenerator | SNOW_ELEVATION | 0.9 | порог снежных шапок |
| MapRiverGenerator | MIN_ELEVATION | 0.75 | минимум высоты для источника |
| MapRiverGenerator | SOURCE_SPACING | 8 | мин. расстояние между источниками |
| MapRiverGenerator | MIN_LENGTH | 5 | реки короче отбрасываются |
| MapForestGenerator | FOREST_COVERAGE | 0.25 | целевая доля лесных тайлов |
| MapForestGenerator | CLUSTER_SIZE_MIN/MAX | 5/20 | размер кластера |
| MapRoadGenerator | TERRAIN_COSTS | grass 1.0 … mountain 999 | предпочтения A* |
| TerrainCostTable | ROAD / RIVER / DENSE_FOREST | 0.5 / 2.0 / 2.0 | стоимость шага для юнитов |

## Правила проходимости

- WATER, MOUNTAIN — непроходимы всегда
- RIVER — непроходима **без моста**; мосты создаёт MapRoadGenerator и хранит в `model.bridge_cells`
- Levitation (артефакт) — проходимость по WATER и RIVER
- Дорога (ROAD) — не меняет проходимость, только стоимость 0.5

## Тесты

`game/tests/unit/world/test_map_generators.gd` — 9 тестов:
сток рек вниз по градиенту, связность дорог между деревнями, хребты гор,
покрываемость леса, время генерации < 2с, рендер, предпочтение дорог,
река без моста / с мостом, согласованность мостов.

## Известные отклонения

- Debug-визуализация генераторов (реки/разломы/кластеры) не реализована —
  добавить при необходимости (отрисовка линий по river_grid/faults).
- Playtester-фидбек по качеству карт не собран.
