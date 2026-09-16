# River Generation System Specification

## Overview
Generates realistic river networks that flow from high elevation (mountains/snow) to low elevation (water bodies/map edges).

## Algorithm

### 1. River Source Selection
```gdscript
# Find potential river sources
- Elevation > 0.75 (mountain/snow biome)
- Not adjacent to existing water body
- Minimum distance between sources: 8 tiles
```

### 2. Flow Simulation
```gdscript
func trace_river(source: Vector2i) -> Array[Vector2i]:
    var path = [source]
    var current = source
    while true:
        var next = find_downhill_neighbor(current)
        if next == null or is_water(next):
            break
        path.append(next)
        current = next
    return path
```

### 3. River Merging
- When two rivers converge within 3 tiles, merge into wider river
- Width calculation: `base_width + sqrt(flow_accumulation)`

### 4. River Smoothing
- Apply Catmull-Rom spline smoothing to jagged paths
- Remove sharp 60-degree turns where possible

## Data Structure
```gdscript
class River:
    var source: Vector2i
    var path: Array[Vector2i]
    var width: float
    var tributaries: Array[River]
```

## Integration Points
- Called after `generate_noise()` in MapModel
- Modifies terrain_grid to set RIVER terrain type
- Updates blocked_cells for pathfinding

## Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| MIN_ELEVATION | 0.75 | Minimum height for river source |
| SOURCE_SPACING | 8 | Minimum tiles between sources |
| MERGE_DISTANCE | 3 | Tiles before rivers merge |
| MIN_LENGTH | 5 | Minimum river length before removal |
