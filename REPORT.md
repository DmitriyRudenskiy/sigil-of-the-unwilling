# Project Report: HoMM3 Clone

## Decisions
- **Hex Grid**: Pointy-top, odd-r offset.
- **Architecture**: Decoupled controllers (World, Battle, Hero) with signals for communication.
- **Rendering**: TileMapLayer for terrains and decor.

## Deviations
- Explicit typing used instead of type inference (:=) for pop_front(), Dictionary access, and .get() due to strict-warnings mode in Godot.


## Terrain Mask Table
| Terrain | ID | Neighbor Rule |
|---------|----|---------------|
| Water   | 0  | -             |
| Swamp   | 1  | Water         |
| Sand    | 2  | Water/Swamp   |
| Grass   | 3  | Sand           |
| Forest  | 4  | Grass         |
| Mountain| 5  | Forest        |
| Snow    | 6  | Mountain      |

## Synthesis
- Integrated noise-based generation with biome logic.
- Implemented BFS for movement and reachability.

## Orientation
- Pointy-top hexes.
- Godot 4.7 GL Compatibility.

## Checklist
- [x] Project Structure
- [x] Project.godot
- [x] Hex Normalizer tool
- [x] Map Generation
- [x] Hero Movement
- [x] Adventure UI
- [x] Battle Prototype
- [x] Main Menu

## Bugs
- None reported.

## Missing Assets/Features (Stage 3.5)
- High-quality water, mountain, and forest tiles in the new "binom" style.
- Transition tiles (peering masks) for the new "binom" textures.
- Specific decor for swamp biome.

## Launch Instructions
1. Open project in Godot 4.7.
2. Run `tools/hex_normalizer.gd` (Ctrl+Shift+X).
3. Create TileSet atlas and configure terrains based on REPORT.md.
4. Run project.

## Commits
- Initial setup and implementation of provided package.

## Приложение A: Stage 1 (автоназначение, tileset_builder v2)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_corner | (0,0) | water | 0b111000 |
| water_base | (1,0) | water | 0b000000 |
| sand_base | (2,0) | sand | 0b000000 |
| sand_grass | (3,0) | sand | 0b000011 |
| grass_base | (4,0) | grass | 0b000000 |
| grass_dry | (5,0) | grass | 0b000000 |
| forest_shrub | (6,0) | grass | 0b000000 |
| forest_1tree | (7,0) | forest | 0b000000 |
| mountain_1 | (8,0) | mountain | 0b100001 |
| mountain_3a | (9,0) | mountain | 0b000001 |
| mountain_3b | (10,0) | mountain | 0b100000 |
| snow_base | (11,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- water_base (заливка из палитры river_straight)
- snow_base (модуляция grass_base в бело-синий)

Вариативность: тайлы с одинаковой маской (sand_base/dunes/pebbles, forest_1tree/2trees, mountain_*) движок выбирает случайно по probability.

## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)

Ориентация: pointy-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.
Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).

| Тайл | Atlas | Террейн | Маска |
|---|---|---|---|
| water_corner | (0,0) | water | 0b111000 |
| water_base | (1,0) | water | 0b000000 |
| sand_base | (2,0) | sand | 0b000000 |
| sand_grass | (3,0) | sand | 0b000011 |
| grass_base | (4,0) | grass | 0b000000 |
| grass_dry | (5,0) | grass | 0b000000 |
| forest_shrub | (6,0) | grass | 0b000000 |
| forest_1tree | (7,0) | forest | 0b000000 |
| mountain_1 | (8,0) | mountain | 0b100001 |
| mountain_3a | (9,0) | mountain | 0b000001 |
| mountain_3b | (10,0) | mountain | 0b100000 |
| snow_base | (11,0) | snow | 0b000000 |

Синтезированные временные тайлы:
- нет

## Приложение C: Asset Mapping (Stage 4.5)

### Unit Portraits (res://assets/units/)
| Unit | Key | File |
|---|---|---|
| Swordsmen | swordsmen | `swordsmen.png` |
| Archers | archers | `archersers.png` |
| Cavalry | cavalry | `cavalry.png` |
| Mages | mages | `mages.png` |
| Guardians | guardians | `guardians.png` |
| Archmages | archmages | `archmages.png` |
| Champions | champions | `champions.png` |
| Knights | knights | `knights.png` |
| Goblins | goblins | `goblins.png` |
| Wolves | wolves | `wolves.png` |
| Trolls | trolls | `trolls.png` |

### UI Icons (res://assets/ui/icons/)
| Button | Icon File | Fallback |
|---|---|---|
| Замок | `treasure.png` | 🏰 |
| Флаг | `flag.png` | 🚩 |
| Лагерь | `battle_flag.png` | ⛺ |
| Конюшня | `horse.png` | 🐎 |
| Корабль | `ship.png` | 🚢 |
| Кузница | `swords.png` | ⚒️ |
| Разведка | `scout.png` | 🔍 |
| Армия | `army.png` | 🪖 |
| Журнал | `scroll.png` | 📜 |
| Конец хода | `hourglass.png` | ⏳ |
| Королевство | `gold.png` | 🏰 |
| Опции | `expand.png` | ⚙️ |
| Бой: Настройки | `expand.png` | ⚙️ |
| Бой: Отступление | `flag.png` | 🏕️ |
| Бой: Ждать | `horse4.png` | 🏃 |
| Бой: Атака | `atk_sword.png` | ⚔️ |
| Бой: Свернуть | `point.png` | ▲ |
| Бой: Книга | `spell.png` | 📖 |
| Бой: Пропуск | `hourglass2.png` | ⏳ |
| Бой: Защита | `helm.png` | 🛡️ |

---

## Приложение D: UnitRegistry (84 существ)

### Файлы → Ключи
| Файл | Ключи по порядку |
|---|---|
| `img_00017.jpeg` | pikeman, halberdier, lancer, alchemist, berserker, griffin, royal_griffin, pegasus, gargoyle, titan, dwarf, battle_dwarf |
| `img_00015.jpeg` | centaur, elf, grand_elf, druid, great_druid, unicorn, war_unicorn, treant, dryad, green_dragon, gold_dragon, black_dragon |
| `img_00016.jpeg` | skeleton, zombie, ghost, wraith, vampire, lich, orc, ogre, behemoth, harpy, minotaur, hydra |
| `img_00014.jpeg` | gremlin, master_gremlin, stone_golem, iron_golem, gold_golem, diamond_golem, magus, genie, master_genie, naga, naga_queen, giant |
| `img_00013.jpeg` | gnoll, gnoll_marauder, lizardman, lizard_warrior, serpent_fly, dragon_fly, basilisk, greater_basilisk, wyvern, wyvern_monarch, gorgon, mighty_gorgon |
| `img_00012.jpeg` | hobgoblin, wolf_rider, wolf_raider, orc_chieftain, ogre_mage, roc, thunderbird, cyclops, cyclops_king, air_elemental, fire_elemental, water_elemental |
| `img_00011.jpeg` | earth_elemental, storm_elemental, ice_elemental, magma_elemental, phoenix, firebird, troglodyte, beholder, medusa, manticore, red_dragon, rust_dragon |

### Статистика (UnitRegistry.UNITS)
Каждый ключ: `[Name, base_damage, hp, speed, defense]`.
Генерация отрядов: `UnitRegistry.make_stack(key, rng)` вычисляет количество по формуле `clampi(rand(30,80) * 6 / base_damage, 3, 120)`.

### Интеграция
- `MapGenerator._place_enemies()`: 15 стеков, 1-3 отряда из случайной фракции.
- `BattleController._place_army()`: дозаполнение статов из реестра по ключу.
- `AdventureUI.refresh_all()`: портреты `_s.png` для слотов армии.
- `WorldController._spawn_enemies()`: портрет `_s.png` первого юнита вместо эмодзи.
