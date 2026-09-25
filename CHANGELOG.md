# Changelog

Формат: записи по завершённым OpenSpec-циклам. Детали — в `openspec/changes/archive/`.

## 2026-09-25

### map-generation-improvement — верификация, фиксы, тесты
- Фикс: `MapMountainGenerator` вызывался до `generate_noise()` и не работал — порядок исправлен (`MapGenerator.gd`)
- Фикс: лес давал 1.5% карты вместо 25% — сиды кластеров теперь с любого подходящего биома, spacing 4, убран двойной случайный гейт роста (`MapForestGenerator.gd`)
- Реки — препятствие без моста: `model.bridge_cells` сохраняется `MapRoadGenerator`, `is_walkable()` учитывает мосты и levitation (`MapModel.gd`)
- Pathfinding юнитов: `HeroMovementController` передаёт cost_func через `TerrainCostTable` (ROAD 0.5, RIVER/DENSE_FOREST 2.0); `HexPathfinding.find_path` получил параметр `cost_func`
- Тесты: `tests/unit/world/test_map_generators.gd` (9 тестов) — сток рек, связность дорог, хребты, покрываемость леса, время генерации, рендер, предпочтение дорог, мосты
- Документация: `doc/task/TASK_MAP_GENERATION.md` (порядок генерации, параметры, правила проходимости)

## 2026-02-22

### ui-icons-cursors-improvement — завершение
- `game_theme.tres`: кнопки/панели/слоты на 9-slice `StyleBoxTexture`, стили `Button` (normal/hover/pressed/disabled) и `ProgressBar` (background/fill)
- `ThemeConfig.icon_texture()` — кэшированная загрузка иконок с fallback (`assets/ui/icons/fallback.png`)
- `ResourceRegistry.get_icon()` / `BuildingDefs.get_icon()` — текстуры по id
- UI: ResourceBar, ResourcesPanel, CityScreen, HeroStatusPanel, BattleSpellbookPanel используют PNG-иконки вместо эмодзи
- Тесты: `tests/unit/theme/` (14 тестов) — загрузка, курсоры, кэш, fallback

### dnd-battle-system — Phase 1 + фикс брони
- Фикс: тяжёлая броня (max_dex=0) полностью игнорирует DEX (`scripts/battle/dnd/armor_class.gd`)
- Тесты ядра D&D: `tests/unit/battle/test_dnd_core.gd` (27 тестов)
