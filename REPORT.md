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
| Sand    | 1  | Water         |
| Grass   | 2  | Sand          |
| Forest  | 3  | Grass         |
| Mountain| 4  | Forest        |
| Snow    | 5  | Mountain      |

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
