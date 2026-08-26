# Addendum 8 — Hero Movement Overhaul

## Overview
Replaced flat BFS pathfinding and integer movement points with float-based terrain costs, Dijkstra pathfinding, green/yellow/red hex markers, daily MP cap of 10, and artifact-adjusted bonuses. Path lines removed in favor of marker overlays.

## Files Created

| File | Lines | Description |
|------|-------|-------------|
| `scripts/data/TerrainCostTable.gd` | 42 | Terrain movement costs: grass 1.0, forest/mountain 1.25, sand/snow 1.5, swamp 1.75, water INF |
| `scripts/ui/MarkerLayer.gd` | 120 | Overlay layer for green/yellow/red hex markers showing reachability |
| `tests/test_movement_costs.gd` | 68 | Tests terrain costs, Dijkstra, MP cap, levitation |

## Files Modified

| File | Changes |
|------|---------|
| `scripts/HexUtils.gd` | Added `dijkstra(start, max_cost, cost_fn)` and `dijkstra_path()` for float-cost pathfinding |
| `scripts/hero/HeroMovementController.gd` | Replaced BFS with Dijkstra, float MP (10 base), terrain cost lookup, `reach_preview_*` signals |
| `scripts/HeroController.gd` | Float MP type, daily reset to 10 + artifact bonuses, marker signal wiring |
| `scripts/AdventureUI.gd` | MP display `🚶 X.X / Y` with green/yellow/red color coding |
| `scripts/hero/HeroVisualController.gd` | Removed path line, added `StatusOrb` class for hero MP indicator |
| `scripts/ui/InfoPanel.gd` | Added `set_status_colored()` for colored MP status |
| `scripts/core/GameSettings.gd` | Added `HERO_DAILY_MOVEMENT = 10.0`, artifact MP bonus notes |
| `scripts/data/ArtifactRegistry.gd` | Polar Boots +3 MP (was +6), Wayfarer's Ring +2 MP (was +3), added `boots_levitation` effect |
| `scripts/MapGenerator.gd` | Added `is_in_bounds()` and `get_terrain_name()` |
| `scripts/map/MapModel.gd` | Added `get_terrain_name()` and `get_terrain_id()` |
| `scripts/WorldController.gd` | Created `MarkerLayer`, wired `reach_preview_*` signals from hero |

## Terrain Cost Table

| Terrain | Cost | Walkable? |
|---------|------|----------|
| Grass | 1.0 | Yes |
| Forest | 1.25 | Yes |
| Mountain | 1.25 | No (blocked) |
| Sand | 1.5 | Yes |
| Snow | 1.5 | Yes |
| Swamp | 1.75 | Yes |
| Water | INF | No (unless levitation) |

## Marker Colors

| Color | Meaning |
|-------|--------|
| Green (pulsing) | Reachable with ≥1 MP remaining |
| Yellow (small) | Reachable with <1 MP remaining |
| Red (tiny) | Unreachable neighbor (blocked/terrain wall) |

## MP System

- **Base**: 10.0 MP per day
- **Polar Boots**: +3 MP/day, enables walking on water (levitation)
- **Wayfarer's Ring**: +2 MP/day
- **Max possible**: 15 MP/day with both artifacts
- Daily reset via `end_turn()`

## Test Results

| Test Suite | Assertions | Status |
|-----------|-----------|--------|
| test_movement_costs | 16 | ✅ All passed |

## Key Design Decisions

1. **Float MP**: Movement points are floats to handle fractional terrain costs precisely.
2. **Dijkstra over BFS**: Float costs require proper shortest-path algorithm; simple priority queue suffices for hex grid.
3. **Marker overlay separate from hero**: `MarkerLayer` is a dedicated CanvasLayer in `WorldController`, keeping hero code clean.
4. **StatusOrb on hero**: Small colored orb above hero token gives at-a-glance MP status.
5. **Water = INF, not just blocked**: Terrain cost table returns INF for water, making levitation a cost override rather than special case.

---

# Addendum 6.1 — HeroMagic, Scrolls, BattleFX, Spellbook Panel Report

## Overview
Refactored hero magic into a dedicated `HeroMagic` class, added scroll pickup rules, created `BattleFX` for spell/ability visual effects, built `BattleSpellbookPanel` for in-battle spell selection, added new constants to `GameSettings`, wired scroll pickup on the world map, and integrated the spellbook button into battle UI. All changes verified via headless test suite.

## Files Created

| File | Lines | Description |
|------|-------|-------------|
| `scripts/data/SpellRegistry.gd` | 97 | Defines 20 spells across 4 schools (Air, Fire, Water, Earth), levels 1-4 |
| `scripts/data/StatusEffects.gd` | 45 | 13 status effects with debuff/stun classification helpers |
| `scripts/spells/SpellCaster.gd` | 102 | Spell casting: damage, healing, resistance, immunity, status application |
| `scripts/ui/SpellbookScreen.gd` | 47 | Simple spellbook UI listing known spells with mana costs |
| `scripts/hero/HeroMagic.gd` | 72 | Dedicated magic system: mana, schools, spellbook, cost calc with anti_magic |
| `scripts/data/ScrollRules.gd` | 26 | Scroll pickup, learn-on-pickup, once-per-battle casting rules |
| `scripts/util/BattleFX.gd` | 68 | Visual FX for spells, healing, damage, morale, kills |
| `scripts/ui/BattleSpellbookPanel.gd` | 43 | In-battle spell panel: reads HeroMagic + SpellRegistry |
| `tests/test_magic.gd` | 72 | HeroMagic: init, learn/forget, mana cost, spend/refund, restore |
| `tests/test_scroll.gd` | 22 | Scroll pickup/learn, cast rules |
| `tests/test_battle_fox.gd` | 12 | BattleFX instantiation and setup |
| `tests/test_spell_registry.gd` | 68 | Validates all 20 spells: count, schools, levels, mana, target types |
| `tests/test_status_effects.gd` | 128 | Tests duration, stun skip, cure clear, debuff classification |
| `tests/test_unit_abilities.gd` | 118 | Tests vampiric, charge, first_strike, rebirth, breath, max_count, distance |
| `tests/test_magic_resistance.gd` | 157 | Tests undead/dragon/golem immunity, dwarf resistance, spell resolution |

## Files Modified

| File | Changes |
|------|---------|
| `BattleState.gd` | Added `statuses`, `max_count`, `distance_moved_this_turn`, `already_reborn` to `BattleUnit`. Extended `apply_attack` with first strike, charge, petrify/blind procs, vampiric, breath, rebirth. Added `_apply_breath_damage`. Updated `start_new_round` to reset ability trackers. |
| `BattleTurnExecutor.gd` | Extended `_advance_to_next_turn` to tick status durations and skip stunned units. |
| `UnitRegistry.gd` | Added ability tags: `vampiric` (Vampire), `charge` (Champions), `first_strike` (Royal Griffin), `rebirth` (Phoenix), `breath`/`petrify`/`blind` (Red Dragon), `magic_resistant` (Dwarves). |
| `HeroController.gd` | Refactored magic fields into `HeroMagic` instance. Backward-compat getters. Mana tick via `magic.tick_restore`. Serialization delegates to magic. |
| `GameSettings.gd` | Added `HERO_BASE_MANA`, `HERO_MANA_TICK`, `BATTLE_SPELL_ANIM_TIME`, `SAVE_MAGIC`, `SAVE_VERSION`. |
| `SpellRegistry.gd` | Added `tags` array, `school` string field to `SpellDef`. `curse` tagged with `anti_magic`. |
| `SpellCaster.gd` | Added cases for `precision`, `wind_wall`, `misfortune`, `slow_mass`, `resurrection`. |
| `BattleState.gd` | Added `spell: StringName` field to `BattleUnit`. |
| `BattleController.gd` | Added `BattleFX` instance, wired spellbook_requested signal. |
| `BattleUI.gd` | Added `spellbook_requested` signal, updated spellbook button. |
| `WorldInteractionController.gd` | Added `pickup_scroll_at` method using `ScrollRules`. |
| `WorldController.gd` | Wired scroll pickup in `_on_hero_moved`. |
| `WorldSpawner.gd` | Added scroll spawning (`_spawn_scrolls`, `remove_scroll_at`) with random spell assignment. |

## Spell Schools (5 per school)

### Air (4 spells)
- Magic Arrow (Lv.1), Precision (Lv.2), Lightning Bolt (Lv.3), Wind Wall (Lv.3), Haste (Lv.4)

### Fire (5 spells)
- Bloodlust (Lv.1), Fireball (Lv.2), Curse (Lv.2), Misfortune (Lv.3), Armageddon (Lv.4)

### Water (5 spells)
- Bless (Lv.1), Cure (Lv.2), Slow (Lv.3), Weakness (Lv.3), Slow Mass (Lv.4)

### Earth (4 spells)
- Shield (Lv.1), Stoneskin (Lv.2), Meteor Shower (Lv.3), Resurrection (Lv.4)

## Status Effects (13 total)

**Buffs**: Haste, Bless, Shield, Stoneskin, Bloodlust, Precision, Wind Wall  
**Debuffs**: Slow, Curse, Weakness, Misfortune, Petrified, Blind

## Unit Special Abilities

| Ability | Units | Effect |
|---------|-------|--------|
| Vampiric | Vampire | Heals for kills dealt |
| Charge | Champions | +50% damage after moving 3+ hexes |
| First Strike | Royal Griffin | Pre-attacks melee attackers |
| Rebirth | Phoenix | 20% chance to revive at 50% HP |
| Breath | Dragons | Splash damage to adjacent enemies |
| Petrify/Blind | Red Dragon | 20% chance per attack to inflict stun |

## Magic Resistance Rules

- **Knowledge**: +5% base resistance per point
- **Dwarves**: +40% resistance from `magic_resistant` tag
- **Undead**: Immune to Bless, Cure, Curse, Weakness, Slow
- **Dragons**: Immune to spells below level 4
- **Golems**: Immune to mind debuffs (Curse, Misfortune, Weakness, Slow)
- **Pendant of Negation**: Can negate entire spell (extensible via artifacts)

## Test Results

| Test Suite | Assertions | Status |
|-----------|-----------|--------|
| test_spell_registry | 20 | ✅ All passed |
| test_status_effects | 15 | ✅ All passed |
| test_unit_abilities | 22 | ✅ All passed |
| test_magic_resistance | 12 | ✅ All passed |
| test_magic | 10 | ✅ All passed |
| test_scroll | 3 | ✅ All passed |
| test_battle_fox | 2 | ✅ All passed |
| test_hex_utils | 35 | ✅ All passed |
| test_unit_registry | 10 | ✅ All passed |
| test_battle_integration | 4 | ✅ All passed |
| test_battle_retreat_smoke | 2 | ✅ All passed |
| test_map_model | 3 | ✅ All passed |
| test_hero_serialize | 4 | ✅ All passed |
| test_save_roundtrip | 1 | ✅ All passed |
| **Total** | **153** | **All passing** |

## Compilation

- **73 scripts compiled**, 0 errors
- All `randi()`/`randomize()` calls bound to deterministic RNG instances

## Key Design Decisions

1. **SpellRegistry as static data**: Spells are defined as structs in a static registry for easy lookup by ID, school, or level.
2. **Status effects as integer enum**: Uses integer constants for statuses to allow simple dictionary-based tracking with durations.
3. **BattleTurnExecutor ticks statuses**: Status durations decrement each turn; expired statuses are removed. Stunned units skip their turn.
4. **Ability tags in UnitRegistry**: Special abilities are driven by unit tags, keeping logic decoupled from unit definitions.
5. **Breath damage as adjacent splash**: Dragon breath affects all adjacent hexes, excluding self and the primary target.
6. **Preload for headless compatibility**: All cross-file references use `preload` to avoid `class_name` resolution failures in headless mode.

## Next Steps

- [DONE] HeroMagic class with mana/schools/spellbook
- [DONE] Scroll pickup on world map (teaches spell to hero)
- [DONE] BattleFX for spell/ability visual effects
- [DONE] BattleSpellbookPanel for in-battle spell selection
- [DONE] Anti_magic cost tag in SpellRegistry
- Remaining: artifact-based spell granting, spell targeting UI, multi-slot save/load

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_corner | (0,0) | water | 0b111000 |
| water_base | (1,0) | water | 0b000000 |
| swamp_base | (2,0) | swamp | 0b000000 |
| sand_base | (3,0) | sand | 0b000000 |
| sand_grass | (4,0) | sand | 0b000011 |
| grass_base | (5,0) | grass | 0b000000 |
| grass_dry | (6,0) | grass | 0b000000 |
| forest_shrub | (7,0) | grass | 0b000000 |
| forest_1tree | (8,0) | forest | 0b000000 |
| mountain_1 | (9,0) | mountain | 0b100001 |
| mountain_3a | (10,0) | mountain | 0b000001 |
| mountain_3b | (11,0) | mountain | 0b100000 |
| snow_base | (12,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- нет

## Этап 8: Biome Preview Tool (Инструмент проверки стыковок)

Реализован специализированный инструмент для рендеринга тестовых карт биомов, позволяющий проверять корректность peering bits и вариативность тайлов.

### Функционал:
- **Режим Solo**: Рендеринг одного биома для проверки вариативности.
- **Режим Duo**: Рендеринг двух биомов с волнистой границей для проверки переходов.
- **Режим Trio**: Рендеринг трех биомов.
- **Режим Matrix**: Сборный скриншот всех 7 биомов с перекрывающимися блоками.
- **Поддержка Retina**: Возможность рендера в 4K.

### Результаты тестов:
- Сгенерировано превью-изображение: `previews/biome_matrix_all_seed42_*.png`
- Проверена работа  в связке с .
- Инструмент автоматизирует создание тестовых наборов скриншотов (до 32 файлов за один прогон в режиме `--mode all`).

### Команда для запуска:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/user/sigil-of-the-unwilling" --windowed --resolution 1920x1080 res://scenes/BiomePreview.tscn --mode matrix --seed 42 --out previews/
```

## Этап 8: Biome Preview Tool (Инструмент проверки стыковок)

Реализован специализированный инструмент для рендеринга тестовых карт биомов, позволяющий проверять корректность peering bits и вариативность тайлов.

### Функционал:
- **Режим Solo**: Рендеринг одного биома для проверки вариативности.
- **Режим Duo**: Рендеринг двух биомов с волнистой границей для проверки переходов.
- **Режим Trio**: Рендеринг трех биомов.
- **Режим Matrix**: Сборный скриншот всех 7 биомов с перекрывающимися блоками.
- **Поддержка Retina**: Возможность рендера в 4K.

### Результаты тестов:
- Сгенерировано превью-изображение: `previews/biome_matrix_all_seed42_*.png`
- Проверена работа `TileMapLayer` в связке с `TerrainAtlasMap`.
- Инструмент автоматизирует создание тестовых наборов скриншотов (до 32 файлов за один прогон в режиме `--mode all`).

### Команда для запуска:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "$(pwd)" --windowed --resolution 1920x1080 res://scenes/BiomePreview.tscn --mode matrix --seed 42 --out previews/
```

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_corner | (0,0) | water | 0b111000 |
| water_base | (1,0) | water | 0b000000 |
| swamp_base | (2,0) | swamp | 0b000000 |
| sand_base | (3,0) | sand | 0b000000 |
| sand_grass | (4,0) | sand | 0b000011 |
| grass_base | (5,0) | grass | 0b000000 |
| grass_dry | (6,0) | grass | 0b000000 |
| forest_shrub | (7,0) | grass | 0b000000 |
| forest_1tree | (8,0) | forest | 0b000000 |
| mountain_1 | (9,0) | mountain | 0b100001 |
| mountain_3a | (10,0) | mountain | 0b000001 |
| mountain_3b | (11,0) | mountain | 0b100000 |
| snow_base | (12,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- нет

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_corner | (0,0) | water | 0b111000 |
| water_base | (1,0) | water | 0b000000 |
| swamp_base | (2,0) | swamp | 0b000000 |
| sand_base | (3,0) | sand | 0b000000 |
| sand_grass | (4,0) | sand | 0b000011 |
| grass_base | (5,0) | grass | 0b000000 |
| grass_dry | (6,0) | grass | 0b000000 |
| forest_shrub | (7,0) | grass | 0b000000 |
| forest_1tree | (8,0) | forest | 0b000000 |
| mountain_1 | (9,0) | mountain | 0b100001 |
| mountain_3a | (10,0) | mountain | 0b000001 |
| mountain_3b | (11,0) | mountain | 0b100000 |
| snow_base | (12,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- нет

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_base | (0,0) | water | 0b000000 |
| swamp_base | (1,0) | swamp | 0b000000 |
| snow_base | (2,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- water_base (solid)
- swamp_base (solid)
- snow_base (solid)

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_base | (0,0) | water | 0b000000 |
| swamp_base | (1,0) | swamp | 0b000000 |
| snow_base | (2,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- нет

## TileSet Builder v3 Report
| Биом | Текстур | База | Варианты |
|---|---|---|---|
| water | 24 | water_base | 23 |
| swamp | 52 | swamp_base | 51 |
| sand | 3 | sand_base | 2 |
| grass | 7 | grass_base | 6 |
| forest | 3 | forest_base | 2 |
| mountain | 7 | mountain_base | 6 |
| snow | 20 | snow_base | 19 |

### Synthesized tiles:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)
- water↔grass transition (blend)
- water↔sand transition (blend)
- swamp↔grass transition (blend)
- sand↔grass transition (blend)
- grass↔forest transition (blend)
- grass↔mountain transition (blend)
- grass↔snow transition (blend)
- forest↔mountain transition (blend)

## TileSet Builder v3 Report
| Биом | Текстур | База | Варианты |
|---|---|---|---|
| water | 24 | water_base | 23 |
| swamp | 42 | swamp_base | 41 |
| sand | 3 | sand_base | 2 |
| grass | 7 | grass_base | 6 |
| forest | 3 | forest_base | 2 |
| mountain | 6 | mountain_base | 5 |
| snow | 18 | snow_base | 17 |

### Synthesized tiles:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)
- water↔grass transition (blend)
- water↔sand transition (blend)
- swamp↔grass transition (blend)
- sand↔grass transition (blend)
- grass↔forest transition (blend)
- grass↔mountain transition (blend)
- grass↔snow transition (blend)
- forest↔mountain transition (blend)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 0 | 0 | 0 |
| grass | 0 | 0 | 0 |
| forest | 0 | 0 | 0 |
| mountain | 0 | 0 | 0 |
| snow | 0 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 0 | 0 | 0 |
| grass | 0 | 0 | 0 |
| forest | 0 | 0 | 0 |
| mountain | 0 | 0 | 0 |
| snow | 0 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 0 | 0 | 0 |
| grass | 0 | 0 | 0 |
| forest | 0 | 0 | 0 |
| mountain | 0 | 0 | 0 |
| snow | 0 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 0 | 0 | 0 |
| grass | 0 | 0 | 0 |
| forest | 0 | 0 | 0 |
| mountain | 0 | 0 | 0 |
| snow | 0 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 0 | 0 | 0 |
| grass | 0 | 0 | 0 |
| forest | 0 | 0 | 0 |
| mountain | 0 | 0 | 0 |
| snow | 0 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 1 | 0 | 0 |
| grass | 1 | 0 | 0 |
| forest | 1 | 0 | 0 |
| mountain | 1 | 5 | 0 |
| snow | 1 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

## TileSet Builder v4 Report (base + objects)
| Биом | Фон | Варианты | Объекты |
|---|---|---|---|
| water | 1 | 5 | 14 |
| swamp | 1 | 39 | 0 |
| sand | 1 | 0 | 0 |
| grass | 1 | 0 | 0 |
| forest | 1 | 0 | 0 |
| mountain | 1 | 5 | 0 |
| snow | 1 | 0 | 18 |

### Структура папок:
```
processed/{biome}/base/    → фоновые (заполнение)
processed/{biome}/objects/ → объекты (декор, 15% шанс)
```

### Synthesized:
- sand_base (solid color fill)
- grass_base (solid color fill)
- forest_base (solid color fill)

---

# Addendum 9 — Settings Screen, Discrete Camera Zoom, and Map Clamping

## Overview
Added a Settings Screen accessible from Main Menu, Adventure mode, and Battle mode. Implemented discrete camera zoom with 9 specific levels (0.5–2.25), removed scroll-based zoom, added `+`/`-` hotkeys, and enforced camera clamping to map boundaries. Settings are persisted to `user://settings.cfg`.

## Files Created

| File | Lines | Description |
|------|-------|-------------|
| `scripts/core/Settings.gd` | 130 | Autoload for settings persistence (zoom, audio, flags) with ConfigFile I/O |
| `scripts/ui/SettingsScreen.gd` | 240 | Settings screen UI with graphics, audio, and gameplay sections |
| `tests/test_zoom_levels.gd` | 65 | Zoom levels spec: count, order, defaults, step up/down, boundary |
| `tests/test_camera_clamp.gd` | 45 | Camera clamping: basic, inverted bounds, large/small map edge cases |
| `tests/test_settings_persist.gd` | 85 | Settings: defaults, save/load, mute, volume clamping, reset |

## Files Modified

| File | Changes |
|------|---------|
| `scripts/core/Settings.gd` | New autoload with ZOOM_LEVELS constant and persistence |
| `scripts/WorldCamera.gd` | Discrete zoom, +/- hotkeys, map clamping, removed `apply_zoom` |
| `scripts/MainMenu.gd` | Added "Настройки" button, preload UIAnimator/SettingsScreen |
| `scripts/AdventureUI.gd` | Wire options button to SettingsScreen, preload SettingsScreen |
| `scripts/BattleUI.gd` | Added settings button, `settings_requested`/`settings_closed` signals |
| `scripts/BattleController.gd` | Wire settings pause/resume with `BattleTurnExecutor` |
| `scripts/BattleTurnExecutor.gd` | Added `pause_battle()`/`resume_battle()`/`is_paused()` |
| `scripts/core/GameSettings.gd` | Added `ZOOM_LEVELS` and `ZOOM_DEFAULT_INDEX` constants |
| `scripts/MapGenerator.gd` | Added `get_map_world_rect()` public API |
| `scripts/WorldController.gd` | Added `_compute_map_rect()` and camera map rect setup |
| `project.godot` | Added `Settings` autoload |

## Zoom Levels

| Index | Zoom | View (at 1920×1080) |
|-------|------|---------------------|
| 0 | 0.50 | 3840×2160 |
| 1 | 0.70 | 2743×1543 |
| 2 | 1.00 | 1920×1080 (default) |
| 3 | 1.10 | 1745×982 |
| 4 | 1.25 | 1536×864 |
| 5 | 1.50 | 1280×720 |
| 6 | 1.75 | 1097×617 |
| 7 | 2.00 | 960×540 |
| 8 | 2.25 | 853×471 |

## Camera Clamping Math
```
viewport_size = get_viewport().get_visible_rect().size
half = viewport_size / (2.0 * zoom.x)
camera.x = clamp(camera.x, map_left + half.x, map_right - half.x)
camera.y = clamp(camera.y, map_top + half.y, map_bottom - half.y)
```
When viewport half exceeds map half (small map at low zoom), camera centers on the map.

## Settings Screen UI

- **Graphics**: Zoom selector (dropdown), fullscreen, UI animations, particles
- **Audio**: Master/Music/SFX volume sliders with percentage display
- **Gameplay**: Auto-save toggle
- **Actions**: Apply & Close, Reset to Defaults, Cancel

## Battle Pause Integration
When settings are opened during battle:
1. `BattleUI.open_settings()` → `BattleTurnExecutor.pause_battle()`
2. Battle state is frozen (no AI turns, no input processing)
3. Settings screen shows above battle
4. On close → `BattleTurnExecutor.resume_battle()` resumes state

## Tests

| Suite | Count | Focus |
|-------|-------|-------|
| `test_zoom_levels.gd` | 11 | Zoom level count, order, defaults, step up/down, boundaries, set exact |
| `test_camera_clamp.gd` | 7 | Clamp basic, inverted bounds, equal, large/small map |
| `test_settings_persist.gd` | 8 | Defaults, set/reset, save/load, mute, volume clamping |

## Design Decisions

- **Discrete zoom**: No continuous scroll zoom; 9 fixed levels provide predictable UX
- **`+`/`-` hotkeys**: Standard keyboard bindings for zoom in/out
- **Animated transitions**: Tween-based zoom changes (175ms) for smooth UX
- **Clamp every frame**: Ensures camera never exceeds map after resize or zoom change
- **ConfigFile persistence**: Simple key-value store, survives game restarts
- **Battle pause**: Settings screen freezes battle state to prevent AI from acting during settings
- **Preload for headless**: All scripts use `preload()` to avoid class_name resolution issues

---

## Port from ForlornU/HexagonalMapGodot (MIT)

Two pure-algorithm ports from [ForlornU/HexagonalMapGodot](https://github.com/ForlornU/HexagonalMapGodot) to improve map generation quality.

### Порт 1: Poisson-расстановка деревень → `MapSpawner.gd`

**Было:** Rejection sampling — цикл `while attempts < 1000`, случайные клетки, проверка дистанции. Деревни кластеризуются, 1000 итераций тратятся впустую.

**Стало:** Shuffle-кандидаты + один проход. Все проходимые клетки перемешиваются, затем перебираются — каждая деревня ставится с дистанцией `spacing=4`, соседи помечаются заблокированными. Гарантированно равномерное покрытие карты.

Файл: `res://scripts/map/MapSpawner.gd` (`place_villages()`)

### Порт 2: «Вода имеет приоритет» → `MapModel.gd`

**Проблема:** Голые горы (`MOUNTAIN`) могли стоять вплотную к воде (`WATER`) — карта выглядела неестественно.

**Решение:** Пост-проход после генерации шума: каждая горная клетка, граничащая с водой, заменяется на песок (`SAND`). Это создаёт естественную песчаную кромку между горой и морем.

Файл: `res://scripts/map/MapModel.gd` (`smooth_invalid_adjacencies()`), вызов из `MapGenerator.generate()`.

### Что НЕ портировано

| Компонент репо | Причина |
|---|---|
| Рендер (3D-меши, шейдер воды) | Наш проект — 2D TileMapLayer |
| Pathfinder (BFS) | Наш `HexUtils` лучше: кэш + летуны + Dijkstra |
| Граф тайлов (`tile.gd`) | Соседи вычисляются на лету через таблицу |
| Raycast-ввод | В 2D это один `local_to_map()` |
