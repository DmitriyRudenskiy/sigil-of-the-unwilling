# Map Generation Improvement: Rivers, Roads, Mountains, Forests

## Status
**Draft** → **Proposed**

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
- [ ] Rivers flow continuously from source to sink
- [ ] All villages connected by road network
- [ ] Mountain ranges form coherent chains (not isolated tiles)
- [ ] Forests appear in clusters with natural edges
- [ ] Performance: generation time < 2 seconds for 60x60 map
- [ ] Visual distinction between terrain types in renderer
- [ ] Pathfinding correctly handles new terrain costs

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
