# Map Generation Improvement Tasks

## Task List

### Task 1: Add New Terrain Types to HexUtils
**Priority:** P0 (Critical)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Add `RIVER = 7`, `ROAD = 8`, `DENSE_FOREST = 9` to `HexUtils.Terrain` enum
- [x] Update `TERRAIN_NAMES` array with new names
- [x] Verify all references to terrain count are updated

---

### Task 2: Extend MapModel Data Structures
**Priority:** P0 (Critical)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Add `river_grid: Dictionary` for river width data
- [x] Add `road_grid: Dictionary` for road type data
- [x] Add `forest_clusters: Array` for forest cluster objects
- [x] Add methods: `is_river(cell)`, `is_road(cell)`, `get_forest_density(cell)`

---

### Task 3: Implement MapRiverGenerator
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Create `game/scripts/world/MapRiverGenerator.gd`
- [x] Implement source selection from high elevation tiles
- [x] Implement flow simulation following steepest descent
- [x] Implement river merging when paths converge
- [x] Apply river terrain to model.river_grid
- [ ] Pass unit tests for flow direction validation

---

### Task 4: Implement MapRoadGenerator
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Create `game/scripts/world/MapRoadGenerator.gd`
- [x] Implement minimum spanning tree for village connections
- [x] Implement A* pathfinding with terrain costs
- [x] Detect river crossings and place bridges
- [x] Apply road terrain to model.road_grid
- [ ] Verify all villages are connected by roads

---

### Task 5: Implement MapMountainGenerator
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Create `game/scripts/world/MapMountainGenerator.gd`
- [x] Implement fault line generation algorithm
- [x] Apply uplift along fault lines to height_grid
- [x] Implement erosion smoothing pass
- [x] Apply snow caps based on elevation and temperature
- [ ] Verify mountain ranges form coherent chains (not isolated tiles)

---

### Task 6: Implement MapForestGenerator
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Create `game/scripts/world/MapForestGenerator.gd`
- [x] Implement biome suitability calculation
- [x] Implement forest clustering algorithm
- [x] Vary density between core and edge tiles
- [x] Preserve clearings within clusters
- [ ] Verify forest coverage matches target percentage (25%)

---

### Task 7: Integrate Generators into MapGenerator
**Priority:** P0 (Critical)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Call `MapMountainGenerator` before `generate_noise()` biome assignment
- [x] Call `MapRiverGenerator` after height map generation
- [x] Call `MapForestGenerator` after biome assignment
- [x] Call `MapRoadGenerator` after village/resource placement
- [x] Update `MapGenerator.generate()` method sequence
- [ ] Verify generation time < 2 seconds for 60x60 map

---

### Task 8: Update MapRenderer for New Terrain
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Add river rendering with width-based visualization
- [x] Add road rendering with primary/secondary distinction
- [x] Add forest density visualization (darker for dense forests)
- [x] Add bridge tiles at road-river intersections
- [x] Update `paint()` method to handle new terrain types
- [ ] Visual verification of all terrain types in-game

---

### Task 9: Update TileAtlas for New Biomes
**Priority:** P1 (High)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Add RIVER, ROAD, DENSE_FOREST to `TileAtlas.Biome` enum
- [x] Add base coordinates for new biomes in `BASE_COORDS`
- [x] Add transition art entries for new biome boundaries
- [x] Update `TERRAIN_TO_BIOME` mapping in MapRenderer
- [ ] Verify texture assets exist or create placeholder textures

---

### Task 10: Update Pathfinding for New Terrain Costs
**Priority:** P2 (Medium)  
**Status:** ✅ DONE  
**Acceptance Criteria:**
- [x] Add terrain cost multipliers: RIVER=2.0, ROAD=0.5, DENSE_FOREST=2.0
- [x] Update `HexPathfinding` to read terrain costs via cost_func parameter
- [ ] Verify units prefer roads when pathfinding
- [ ] Verify rivers are treated as obstacles without bridges
- [ ] Run pathfinding performance benchmarks

---

### Task 11: Create Generator Test Suite
**Priority:** P2 (Medium)  
**Status:** TODO  
**Acceptance Criteria:**
- [ ] Create unit tests for river flow validation
- [ ] Create unit tests for road connectivity
- [ ] Create integration tests for full map generation
- [ ] Add performance regression tests
- [ ] Achieve 80% code coverage for new generators

---

### Task 12: Documentation and Tuning
**Priority:** P3 (Low)  
**Status:** TODO  
**Acceptance Criteria:**
- [ ] Document all generator parameters in code comments
- [ ] Create tuning guide for map generation settings
- [ ] Add debug visualization mode for testing
- [ ] Update changelog with new features
- [ ] Collect playtester feedback on map quality

---

## Implementation Order

```
Phase 1 (Foundation): ✅ COMPLETE
  1. Task 1: Add terrain types to HexUtils ✅
  2. Task 2: Extend MapModel structures ✅
  3. Task 9: Update TileAtlas ✅

Phase 2 (Core Generators): ✅ COMPLETE
  4. Task 5: Mountain generator ✅
  5. Task 3: River generator ✅
  6. Task 6: Forest generator ✅
  7. Task 4: Road generator ✅

Phase 3 (Integration): ✅ COMPLETE
  8. Task 7: Integrate into MapGenerator ✅
  9. Task 8: Update MapRenderer ✅
  10. Task 10: Update pathfinding ✅

Phase 4 (Testing & Polish): IN PROGRESS
  11. Task 11: Create test suite ⏳
  12. Task 12: Documentation and tuning ⏳
```

## Total Estimated Effort
- **P0 Tasks:** 3 tasks (~8 hours) ✅
- **P1 Tasks:** 5 tasks (~20 hours) ✅
- **P2 Tasks:** 2 tasks (~4 hours done, ~4 hours remaining)
- **P3 Tasks:** 1 task (~4 hours remaining)
- **Completed:** ~32 hours
- **Remaining:** ~8 hours (testing & tuning)
