# Height and Elevation System Specification

## Overview
This document specifies the height and elevation mechanics for D&D-style combat, including high ground advantages, vertical positioning, and ranged attack modifiers based on elevation differences.

## 1. Elevation System

### 1.1 Height Levels
The battlefield uses discrete elevation levels:
- **Level 0**: Ground level (default)
- **Level 1**: Low elevation (1-5 feet) - small rocks, shallow water
- **Level 2**: Medium elevation (6-10 feet) - low walls, platforms
- **Level 3**: High elevation (11-20 feet) - second floor, high walls
- **Level 4**: Very High elevation (21-30 feet) - towers, cliffs
- **Level 5+**: Extreme elevation (31+ feet) - mountains, flying

### 1.2 Height Data Structure
```gdscript
class CombatantPosition:
    var grid_x: int = 0
    var grid_y: int = 0
    var elevation: int = 0  # in 5-foot increments
    var is_flying: bool = false
    var is_climbing: bool = false
    var is_prone: bool = false
    
    func get_total_height() -> int:
        return elevation * 5  # Convert to feet
```

### 1.3 Terrain Height Map
```gdscript
class BattleMap:
    var width: int
    var height: int
    var elevation_map: Array  # 2D array of elevation values
    var terrain_types: Array  # 2D array of terrain type enums
    
    func get_elevation(x: int, y: int) -> int:
        if x < 0 or x >= width or y < 0 or y >= height:
            return -1  # Out of bounds
        return elevation_map[y][x]
    
    func set_elevation(x: int, y: int, elevation: int):
        if x >= 0 and x < width and y >= 0 and y < height:
            elevation_map[y][x] = max(0, elevation)
    
    func get_line_of_sight(start: Vector2, end: Vector2) -> bool:
        # Implement Bresenham's line algorithm with height checks
        pass
```

## 2. High Ground Advantage

### 2.1 Melee Attack Bonuses
When attacking from higher elevation:

| Height Difference | Melee Bonus | Condition |
|------------------|-------------|-----------|
| 1 level (5 ft)   | +0          | No bonus  |
| 2 levels (10 ft) | +1          | Reach weapon or adjacent |
| 3+ levels (15+ ft) | +2        | Must have reach or be adjacent |

### 2.2 Ranged Attack Bonuses
When attacking from higher elevation with ranged weapons:

| Height Difference | Ranged Bonus | Range Increase |
|------------------|--------------|----------------|
| 1 level (5 ft)   | +0           | +0 ft          |
| 2 levels (10 ft) | +1           | +10 ft         |
| 3 levels (15 ft) | +2           | +20 ft         |
| 4+ levels (20+ ft) | +3         | +30 ft         |

### 2.3 Attacking Uphill Penalties
When attacking from lower elevation:

| Height Difference | Melee Penalty | Ranged Penalty |
|------------------|---------------|----------------|
| 1 level (5 ft)   | +0            | +0             |
| 2 levels (10 ft) | -1            | +0             |
| 3 levels (15 ft) | -2            | -1             |
| 4+ levels (20+ ft) | -3          | -2             |

### 2.4 Implementation
```gdscript
func calculate_height_modifier(attacker_pos: CombatantPosition, 
                                defender_pos: CombatantPosition,
                                is_ranged: bool) -> Dictionary:
    var height_diff: int = attacker_pos.elevation - defender_pos.elevation
    var distance: float = calculate_grid_distance(attacker_pos, defender_pos)
    
    var result := {
        "attack_bonus": 0,
        "range_bonus": 0,
        "has_high_ground": height_diff > 0,
        "height_difference": abs(height_diff)
    }
    
    if height_diff > 0:  # Attacker is higher
        if is_ranged:
            if height_diff >= 4:
                result.attack_bonus = 3
                result.range_bonus = 30
            elif height_diff >= 3:
                result.attack_bonus = 2
                result.range_bonus = 20
            elif height_diff >= 2:
                result.attack_bonus = 1
                result.range_bonus = 10
        else:  # Melee
            if height_diff >= 3 and distance <= get_reach():
                result.attack_bonus = 2
            elif height_diff >= 2 and distance <= get_reach():
                result.attack_bonus = 1
    
    elif height_diff < 0:  # Attacker is lower (uphill attack)
        if is_ranged:
            if abs(height_diff) >= 4:
                result.attack_bonus = -2
            elif abs(height_diff) >= 3:
                result.attack_bonus = -1
        else:  # Melee
            if abs(height_diff) >= 4:
                result.attack_bonus = -3
            elif abs(height_diff) >= 3:
                result.attack_bonus = -2
            elif abs(height_diff) >= 2:
                result.attack_bonus = -1
    
    return result
```

## 3. Cover System

### 3.1 Cover Types Based on Height

**No Cover**: Target fully visible
- AC bonus: +0
- DEX save bonus: +0

**Half Cover**: Target partially obscured (low wall, furniture, creature of similar height)
- AC bonus: +2
- DEX save bonus: +2
- Examples: Behind 3-ft wall, behind counter, peeking around corner

**Three-Quarters Cover**: Target mostly obscured (arrow slit, thick tree trunk)
- AC bonus: +5
- DEX save bonus: +5
- Examples: Behind 5-ft wall with opening, narrow embrasure

**Full Cover**: Target completely obscured
- Cannot be targeted directly
- Must use area effects or move to line of sight

### 3.2 Height-Based Cover Calculation
```gdscript
func calculate_cover(attacker_pos: CombatantPosition, 
                     defender_pos: CombatantPosition,
                     map: BattleMap) -> Dictionary:
    var cover_level: String = "none"
    var ac_bonus: int = 0
    var dex_save_bonus: int = 0
    
    # Get line between attacker and defender
    var line: Array[Vector2] = get_line_cells(attacker_pos.grid_position, 
                                               defender_pos.grid_position)
    
    # Check for obstacles along the line
    var obstacles: Array = []
    for cell in line:
        var terrain = map.get_terrain(cell.x, cell.y)
        var elevation = map.get_elevation(cell.x, cell.y)
        
        # Obstacle must be between attacker and defender elevation-wise
        if terrain.is_obstacle and elevation > min(attacker_pos.elevation, defender_pos.elevation):
            obstacles.append({
                "position": cell,
                "height": terrain.height,
                "type": terrain.cover_type
            })
    
    # Determine cover level based on obstacles
    if not obstacles.is_empty():
        var max_obstacle_height = 0
        for obs in obstacles:
            max_obstacle_height = max(max_obstacle_height, obs.height)
        
        var relative_height = max_obstacle_height - min(attacker_pos.elevation, defender_pos.elevation)
        
        if relative_height >= defender_pos.elevation + 2:  # Full cover
            cover_level = "full"
        elif relative_height >= defender_pos.elevation + 1:  # Three-quarters
            cover_level = "three_quarters"
            ac_bonus = 5
            dex_save_bonus = 5
        elif relative_height >= 1:  # Half cover
            cover_level = "half"
            ac_bonus = 2
            dex_save_bonus = 2
    
    return {
        "cover_level": cover_level,
        "ac_bonus": ac_bonus,
        "dex_save_bonus": dex_save_bonus,
        "obstacles": obstacles
    }
```

### 3.3 Soft Cover (Creatures)
- Creatures provide half cover to targets behind them
- Does not stack with other half cover sources
- Implemented automatically when line passes through occupied cell

## 4. Vertical Movement

### 4.1 Climbing
- Speed costs double when climbing
- Must have hands free (no two-handed weapons)
- Requires Athletics check if surface is difficult (DC 10-15)
- Falling damage if climb fails

```gdscript
func attempt_climb(combatant: Character, difficulty: int) -> bool:
    var check_result: int = combatant.make_ability_check('STR', 'athletics')
    
    if check_result >= difficulty:
        return true
    else:
        # Fall and take damage
        var fall_distance: int = combatant.position.elevation * 5
        var damage: int = max(0, fall_distance / 10)  # 1d6 per 10 feet
        combatant.take_damage(damage, "bludgeoning")
        combatant.position.elevation = 0
        combatant.position.is_prone = true
        return false
```

### 4.2 Flying Movement
- Flying creatures ignore elevation penalties
- Can move vertically at normal speed (unless specified otherwise)
- Knocked prone while flying = fall unless has hover ability

### 4.3 Jumping
**Long Jump**: 
- Distance = STR score (in feet) with running start
- Half distance without running start
- Costs movement equal to distance jumped

**High Jump**:
- Height = 3 + STR modifier (in feet) with running start
- Half height without running start
- Can extend arms overhead: reach = height + 5 ft

```gdscript
func calculate_jump_distance(character: Character, has_running_start: bool) -> Dictionary:
    var str_score: int = character.abilities['STR']
    var str_mod: int = character.get_ability_modifier('STR')
    
    var long_jump: float = str_score if has_running_start else str_score / 2.0
    var high_jump: float = 3.0 + str_mod if has_running_start else (3.0 + str_mod) / 2.0
    high_jump = max(0, high_jump)  # Can't be negative
    
    return {
        "long_jump_feet": long_jump,
        "high_jump_feet": high_jump,
        "reach_while_jumping": high_jump + 5
    }
```

## 5. Line of Sight (LoS)

### 5.1 LoS Calculation Rules
1. Draw line from attacker's eye level to target's position
2. Eye level = creature height + elevation
3. Check for intersections with obstacles
4. Consider obstacle height vs line trajectory

### 5.2 Creature Heights
| Creature Size | Height (ft) | Eye Level (ft) |
|--------------|-------------|----------------|
| Tiny         | 1-2         | 1.5            |
| Small        | 2-4         | 3              |
| Medium       | 4-6         | 5              |
| Large        | 8-10        | 9              |
| Huge         | 12-16       | 14             |
| Gargantuan   | 20+         | varies         |

### 5.3 LoS Implementation
```gdscript
func has_line_of_sight(attacker: Character, target: Character, map: BattleMap) -> bool:
    var attacker_eye_level: float = attacker.position.elevation * 5 + attacker.eye_height
    var target_height: float = target.position.elevation * 5 + target.eye_height
    
    var start_pos: Vector3 = Vector3(
        attacker.position.grid_x * 5,
        attacker_eye_level,
        attacker.position.grid_y * 5
    )
    var end_pos: Vector3 = Vector3(
        target.position.grid_x * 5,
        target_height,
        target.position.grid_y * 5
    )
    
    # Raycast from attacker eyes to target
    var direction: Vector3 = (end_pos - start_pos).normalized()
    var distance: float = start_pos.distance_to(end_pos)
    
    var steps: int = ceil(distance)
    for i in range(steps):
        var check_pos: Vector3 = start_pos + direction * i
        var grid_x: int = floor(check_pos.x / 5)
        var grid_y: int = floor(check_pos.z / 5)
        
        var terrain_height: float = map.get_terrain_height(grid_x, grid_y)
        var terrain_elevation: int = map.get_elevation(grid_x, grid_y)
        var total_height: float = terrain_elevation * 5 + terrain_height
        
        # If terrain is higher than line of sight at this point, block LoS
        var line_height_at_point: float = start_pos.y + (end_pos.y - start_pos.y) * (i / float(steps))
        if total_height > line_height_at_point + 0.5:  # 0.5 ft tolerance
            return false
    
    return true
```

## 6. Ranged Attack Arcs

### 6.1 Projectile Trajectory
Ranged attacks from height follow parabolic arc:
- Higher elevation = flatter trajectory
- Lower elevation = steeper arc needed
- Extreme angles may impose disadvantage

### 6.2 Angle Penalties
```gdscript
func calculate_angle_penalty(attacker_pos: CombatantPosition, 
                             defender_pos: CombatantPosition,
                             horizontal_distance: float) -> int:
    var height_diff: float = (defender_pos.elevation - attacker_pos.elevation) * 5
    var angle: float = rad_to_deg(atan(abs(height_diff) / horizontal_distance))
    
    # Steep angles (> 60 degrees) impose disadvantage
    if angle > 75:
        return -5  # Severe penalty, effectively disadvantage
    elif angle > 60:
        return -2
    elif angle > 45:
        return -1
    
    return 0
```

## 7. Falling Damage

### 7.1 Falling Rules
- 1d6 bludgeoning damage per 10 feet fallen
- Maximum 20d6 damage
- Landing is difficult terrain
- Prone condition on landing

```gdscript
func calculate_falling_damage(fall_distance_feet: int) -> int:
    var damage_dice: int = min(20, fall_distance_feet / 10)
    var total_damage: int = 0
    
    for i in range(damage_dice):
        total_damage += randi_range(1, 6)
    
    return total_damage

func apply_falling(combatant: Character, from_elevation: int, to_elevation: int):
    var fall_distance: int = (from_elevation - to_elevation) * 5
    
    if fall_distance > 0:
        var damage: int = calculate_falling_damage(fall_distance)
        combatant.take_damage(damage, "bludgeoning")
        combatant.position.is_prone = true
        
        # Optional: DEX save to land on feet (DC 15)
        var save_result: int = combatant.make_saving_throw('DEX', 15)
        if save_result >= 15:
            combatant.position.is_prone = false
```

## 8. Special Height Scenarios

### 8.1 Charging Downhill
- Melee attacks from 2+ levels higher: +1 damage
- Must move at least 10 feet downhill
- Cannot charge uphill

### 8.2 Defensive Position on Height
- Ranged attackers on height gain +2 AC against melee (harder to reach)
- Melee attackers must climb or jump to engage

### 8.3 Knocking Creatures Off Edges
- Shove action can push creature off elevated position
- Requires successful Athletics vs Athletics/Acrobatics check
- Target falls and takes falling damage

```gdscript
func attempt_shove_off_edge(attacker: Character, target: Character, 
                            edge_direction: Vector2) -> bool:
    if not is_adjacent(attacker, target):
        return false
    
    if not is_edge_in_direction(target.position, edge_direction):
        return false  # No cliff/edge to push off
    
    var attacker_roll: int = attacker.make_ability_check('STR', 'athletics')
    var defender_choice: String = 'athletics' if target.skills['athletics'] > target.skills['acrobatics'] else 'acrobatics'
    var defender_roll: int = target.make_ability_check('STR' if defender_choice == 'athletics' else 'DEX', defender_choice)
    
    if attacker_roll > defender_roll:
        # Push off edge
        target.position.grid_x += edge_direction.x
        target.position.grid_y += edge_direction.y
        apply_falling(target, target.position.elevation, 0)
        return true
    
    return false
```

## 9. Integration with Existing Systems

### 9.1 Modified Systems
- `BattleMap.gd`: Add elevation data structure
- `Combatant.gd`: Add elevation property and height-related methods
- `AttackCalculator.gd`: Integrate height modifiers
- `MovementSystem.gd`: Handle vertical movement costs
- `LineOfSight.gd`: Implement 3D LoS checks

### 9.2 New Systems
- `HeightModifier.gd`: Calculate all height-based bonuses/penalties
- `CoverCalculator.gd`: Determine cover from elevation and obstacles
- `FallingDamage.gd`: Handle falling mechanics
- `ClimbingSystem.gd`: Manage climbing actions and checks

## 10. UI Considerations

### 10.1 Visual Indicators
- Show elevation numbers on grid cells
- Color-code different elevation levels
- Display height difference when targeting
- Show cover status icons

### 10.2 Tooltips
- Attack tooltip should show:
  - Height difference
  - High ground bonus/penalty
  - Cover bonus
  - Net modifier to attack roll

## Testing Requirements
- Test all elevation combinations (0-5 levels difference)
- Verify cover calculations with various obstacle heights
- Test line of sight with multiple obstacles
- Validate falling damage at various distances
- Test climbing success/failure rates
- Performance test with many elevated positions

## References
- D&D 5e Player's Handbook: Climbing, Flying, Falling
- D&D 5e Dungeon Master's Guide: Maps and Terrain
- System Reference Document 5.1: Cover, High Ground
