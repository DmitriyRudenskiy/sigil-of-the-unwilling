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
