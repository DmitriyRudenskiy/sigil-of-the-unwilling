# Terrain Enhancement Specification: Mountains and Forests

## Overview
Improves mountain range formation and forest distribution for realistic biome patterns.

## Mountain Range Generation

### 1. Fault Line Simulation
```gdscript
func generate_fault_lines(count: int) -> Array[FaultLine]:
    var faults = []
    for i in count:
        var start = random_edge_point()
        var direction = random_direction()
        var fault = trace_fault_line(start, direction)
        faults.append(fault)
    return faults
```

### 2. Uplift Along Faults
```gdscript
func apply_uplift(fault: FaultLine, intensity: float) -> void:
    for cell in get_nearby_cells(fault.path, radius=4):
        var distance = hex_distance(cell, fault.path)
        var uplift = intensity * (1.0 - distance / 4.0)
        height_grid[cell] += uplift
```

### 3. Erosion Smoothing
- Apply hydraulic erosion simulation
- Smooth sharp peaks into rounded mountains
- Create foothills transition zones (elevation 0.6-0.75)

### 4. Snow Cap Calculation
```gdscript
func apply_snow_caps() -> void:
    for cell in mountain_cells:
        if elevation > 0.9 and temperature < 0.3:
            terrain_grid[cell] = SNOW
        elif elevation > 0.85:
            terrain_grid[cell] = MOUNTAIN
```

## Forest Distribution

### 1. Biome Suitability Map
```gdscript
const FOREST_SUITABILITY = {
    GRASS: 0.6,    # Moderate chance
    SAND: 0.0,     # No forests
    SWAMP: 0.3,    # Sparse mangroves
    SNOW: 0.1,     # Boreal forests only
    MOUNTAIN: 0.0  # Too high
}
```

### 2. Clustering Algorithm
```gdscript
func generate_forest_clusters() -> void:
    var seeds = select_cluster_seeds()
    for seed in seeds:
        grow_forest_cluster(seed, size=random(5, 20))
```

### 3. Growth Simulation
```gdscript
func grow_forest_cluster(seed: Vector2i, size: int) -> void:
    var cluster = [seed]
    while cluster.size() < size:
        var edge = pick_random_edge(cluster)
        var neighbor = find_suitable_neighbor(edge)
        if neighbor and suitability > random():
            cluster.append(neighbor)
```

### 4. Density Variation
- Core tiles: DENSE_FOREST (movement cost 2x)
- Edge tiles: SPARSE_FOREST (movement cost 1.5x)
- Clearings: Preserve 10-20% open space within clusters

## Data Structure
```gdscript
class FaultLine:
    var path: Array[Vector2i]
    var uplift: float
    var length: int

class ForestCluster:
    var center: Vector2i
    var tiles: Array[Vector2i]
    var density: float  # 0.0-1.0
    var type: String    # "dense", "sparse", "boreal"
```

## Integration Points
- Mountain generation: Before `generate_noise()` biome assignment
- Forest generation: After biome assignment, before resource placement
- Modifies `height_grid` and `terrain_grid` in MapModel

## Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| FAULT_COUNT | 5 | Number of fault lines |
| UPLIFT_INTENSITY | 0.4 | Height increase along faults |
| FOREST_COVERAGE | 0.25 | Target forest % of map |
| CLUSTER_SIZE_MIN | 5 | Minimum forest cluster size |
| CLUSTER_SIZE_MAX | 20 | Maximum forest cluster size |
| CLEARING_RATIO | 0.15 | Open space within forests |
