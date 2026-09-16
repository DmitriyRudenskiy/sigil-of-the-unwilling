# Road Network System Specification

## Overview
Creates road networks connecting villages, resources, and key strategic points.

## Algorithm

### 1. Primary Roads (Village Connections)
```gdscript
func connect_villages(villages: Array[Vector2i]) -> void:
    # Build minimum spanning tree between villages
    var mst = build_mst(villages)
    for edge in mst:
        var path = find_path(edge.start, edge.end)
        paint_road(path, RoadType.PRIMARY)
```

### 2. Secondary Roads (Resource Connections)
```gdscript
func connect_resources(resources: Dictionary) -> void:
    for resource_cell in resources.keys():
        var nearest_village = find_nearest_village(resource_cell)
        var path = find_path(resource_cell, nearest_village)
        paint_road(path, RoadType.SECONDARY)
```

### 3. Pathfinding with Terrain Costs
```gdscript
const TERRAIN_COSTS = {
    GRASS: 1.0,
    SAND: 1.2,
    FOREST: 1.5,
    SWAMP: 3.0,  # Avoid swamps
    MOUNTAIN: 999.0,  # Impassable
    RIVER: 2.0  # Requires bridge
}
```

### 4. River Crossing Detection
- When road path intersects river, place bridge tile
- Bridge renders differently than normal road

## Data Structure
```gdscript
enum RoadType { PRIMARY, SECONDARY, TRAIL }

class RoadSegment:
    var start: Vector2i
    var end: Vector2i
    var type: RoadType
    var path: Array[Vector2i]
    var bridges: Array[Vector2i]
```

## Integration Points
- Called after `place_villages()` and `place_resources()`
- Modifies terrain_grid to set ROAD terrain type
- Does not block movement (roads are walkable)

## Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| PRIMARY_WIDTH | 1 | Tiles wide for primary roads |
| AVOID_SWAMP | true | Prefer non-swamp paths |
| BRIDGE_ON_RIVER | true | Auto-place bridges |
| MAX_PATH_COST | 50 | Maximum detour multiplier |
