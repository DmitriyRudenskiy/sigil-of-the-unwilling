# Map Generation Improvement: Rivers, Roads, Mountains, Forests

## Status
**Implemented & verified (2026-09-27)** — цикл закрыт для headless-верифицируемого скоупа; debug-визуализация и плейтест-фидбек отложены (вне автоматической проверки). Next step: `/opsx-sync` (rivers/roads/terrain в main specs) → archive. См. CHANGELOG 2026-02-22 и tasks.md (9 зелёных тестов генерации).

## Summary
Enhance the procedural map generation system to add realistic rivers, roads connecting settlements, proper mountain ranges, and forest distribution. This improves visual variety, strategic gameplay, and world immersion.

## Motivation
Current map generation uses basic noise-based terrain distribution but lacks:
- **Rivers**: No water flow paths between terrain features
- **Roads**: No connections between villages/cities for trade and movement
- **Mountain Ranges**: Mountains are scattered randomly instead of forming realistic chains
- **Forest Distribution**: Forests lack clustering and biome-appropriate placement

These features are critical for:
1. Strategic depth (roads reduce movement cost, rivers create barriers)
2. Visual coherence (realistic geography)
3. Gameplay balance (natural chokepoints, resource distribution)

## Scope
### In Scope
- River generation using flow simulation from mountains to water bodies
- Road network connecting villages and key resources
- Mountain range formation using tectonic plate simulation
- Forest clustering with biome-aware distribution
- Integration with existing `MapModel`, `MapGenerator`, `MapRenderer`
- New terrain types: `RIVER`, `ROAD`, `DENSE_FOREST`

### Out of Scope
- Dynamic river changes during gameplay
- Player-built roads (future feature)
- Underground cave systems
- Ocean depth simulation

## Design Overview

### River System
- Rivers spawn from mountain/snow tiles (elevation > 0.8)
- Flow downhill following steepest descent
- Merge into larger rivers when converging
- Terminate at water bodies (ocean/lake) or map edge
- Width varies based on flow accumulation

### Road Network
- Connect all village cells with primary roads
- Secondary roads to major resource nodes
- Follow terrain preferences (avoid steep slopes, swamps)
- Use A* pathfinding with terrain cost weights

### Mountain Ranges
- Replace single-tile mountains with clustered ranges
- Use fault line simulation for realistic chains
- Create foothills transition zones
- Add elevation-based snow caps

### Forest Distribution
- Cluster forests around grass/temperate zones
- Avoid high elevations and swamp edges
- Vary density (sparse woodland → dense forest)
- Preserve clearings for gameplay

## Technical Approach

### Modified Files
1. `MapModel.gd`: Add river/road grids, mountain range data
2. `MapGenerator.gd`: Integrate new generation steps
3. `MapRenderer.gd`: Render rivers, roads, forest variations
4. `HexUtils.gd`: Add terrain constants for new types
5. `tile_atlas.gd`: Add biome mappings for new terrain

### New Files
1. `MapRiverGenerator.gd`: River flow simulation
2. `MapRoadGenerator.gd`: Road network construction
3. `MapMountainGenerator.gd`: Mountain range formation
4. `MapForestGenerator.gd`: Forest clustering algorithm

### Data Structures
```gdscript
# MapModel additions
var river_grid: Dictionary = {}  # cell -> river_width
var road_grid: Dictionary = {}   # cell -> road_type
var mountain_ranges: Array = []  # Array of mountain range objects
var forest_clusters: Dictionary = {}  # cell -> forest_density
```

## Acceptance Criteria
- [x] Rivers flow continuously from source to sink *(test_rivers_flow_downhill, 3 seeds)*
- [x] All villages connected by road network *(test_villages_connected_by_roads, BFS)*
- [x] Mountains form clustered ranges with snow caps *(map_mountain_generator.gd: fault lines + erosion + elevation-based snow; тесты Task 5)*
- [x] Forests cluster realistically across biomes *(map_forest_generator.gd: density/biome-aware; тесты Task 6)*
- [x] Terrain costs affect pathfinding *(TerrainCostTable + A* в road generator; мосты на пересечениях с реками)*
- [x] Generation performance acceptable across map sizes *(регрессионные тайминги в тестах генерации; полный сьют зелёный)*
- [~] Debug visualization of generation layers *(отложено: dev-only визуал, не верифицируется headless)*
- [~] Playtester feedback on world coherence *(отложено: требует GUI-сессий)*

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| River generation creates loops | Medium | Implement flow direction tracking |
| Roads intersect rivers incorrectly | Low | Add bridge detection logic |
| Mountain ranges too uniform | Medium | Add noise variation to fault lines |
| Performance degradation | High | Use spatial partitioning for clustering |

## Dependencies
- Existing noise generation (`FastNoiseLite`)
- Hex grid utilities (`HexUtils`)
- Tile atlas for rendering (`TileAtlas`)
- Pathfinding system (`HexPathfinding`)

## Testing Strategy
1. **Unit Tests**: Verify river flow direction, road connectivity
2. **Integration Tests**: Full map generation with all features
3. **Visual Tests**: Screenshot comparison for terrain coherence
4. **Performance Tests**: Measure generation time across map sizes

## Future Enhancements
- Dynamic erosion simulation for river valleys
- Seasonal river flooding mechanics
- Player-controlled road construction
- Trade route bonuses along roads
- Bridge building over rivers
