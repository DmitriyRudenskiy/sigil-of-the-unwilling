# Changelog

Формат: записи по завершённым OpenSpec-циклам. Детали — в `openspec/changes/archive/`.

## 2026-09-25

### dnd-battle-system — Phase 3: Action Economy (TASK_13–15)
- `action_economy.gd` — `DNDActionEconomy`: 1 action/turn, bonus action (only if source allows), 1 reaction/round (resets at turn start), 10 standard actions enum, validation (no same action twice), `available_actions()`, save/load
- `opportunity_attack.gd` — `DNDOpportunityAttack`: trigger logic (leaves reach, not Disengage, not forced/teleport, has sight + reaction), single attack
- Тесты: `tests/unit/battle/test_dnd_actions.gd` (14 тестов)
- Отложено (Phase 6): per-action runtime effects (Dash/Dodge/Help/Hide/Ready/Search/Use Object), integration tests с живой battle state

### dnd-battle-system — Phase 2: Height & Positioning (TASK_07–10)
- `elevation_system.gd` — `DNDElevationSystem`: дискретные уровни (5-фут. инкременты), set/get, `height_feet()`, `is_high_ground()`, сериализация `to_dict`/`from_dict`
- `height_modifier.gd` — `DNDHeightModifier`: бонусы высокой точки (ranged +1/+2/+3, melee +1/+2), штрафы снизу (ranged −1/−2, melee 0/−1/−2/−3), `range_bonus()`, `describe()`
- `line_of_sight.gd` — `DNDLineOfSight`: 3D LoS (Брезенхэм + интерполяция высоты линии огня), `min_clearance()` для расчёта укрытия
- `cover_calculator.gd` — `DNDCoverCalculator`: 4 уровня укрытия (none/half/three-quarters/full), half = +2 AC/+2 DEX, full = немишень, `describe()`
- Тесты: `tests/unit/battle/test_dnd_height.gd` (20 тестов) — elevation, таблицы бонусов, LoS (стена/через стену/диагональ), укрытия, интеграция с `DNDAttackRoll`
- Отложено (не в height-system spec): TASK_11 vertical movement, TASK_12 falling damage, soft cover от существ, debug-визуализация, creature size в LoS, UI-индикаторы (Phase 6)

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
