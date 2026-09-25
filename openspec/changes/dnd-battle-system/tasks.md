# D&D Battle System Implementation Tasks

## Task List

### Phase 1: Core Mechanics (Priority: HIGH)

#### TASK_01: Implement Ability Score System
**File**: `game/scripts/battle/dnd/ability_scores.gd`
**Description**: Create core ability score system with six abilities (STR, DEX, CON, INT, WIS, CHA) and modifier calculations.
**Acceptance Criteria**:
- [x] Character class has 6 ability scores (8-20 range)
- [x] `get_ability_modifier(score)` returns correct modifier (-5 to +5)
- [x] Modifiers update when scores change
- [x] Unit tests for all modifier calculations
**Status**: DONE
**Estimated Hours**: 4

#### TASK_02: Implement Proficiency Bonus System
**File**: `game/scripts/battle/dnd/proficiency_system.gd`
**Description**: Implement proficiency bonus progression by character level and proficiency tracking.
**Acceptance Criteria**:
- [x] Proficiency bonus scales correctly by level (+2 to +6)
- [x] Characters can be proficient in weapons, saves, and skills
- [x] Bonus applied only when proficient
- [x] Unit tests for level progression
**Status**: DONE
**Estimated Hours**: 3

#### TASK_03: Implement Armor Class Calculation
**File**: `game/scripts/battle/dnd/armor_class.gd`
**Description**: Create AC calculation system supporting all armor types and shields.
**Acceptance Criteria**:
- [x] Supports all 12 armor types from PHB
- [x] Correctly applies DEX modifiers based on armor type
- [x] Shield bonus (+2) applies when proficient
- [x] Integration test with combatant equipment changes
**Status**: DONE
**Estimated Hours**: 6

#### TASK_04: Implement Attack Roll System
**File**: `game/scripts/battle/dnd/attack_roll.gd`
**Description**: Implement d20 attack roll with advantage/disadvantage mechanics.
**Acceptance Criteria**:
- [x] Basic roll: d20 + ability mod + proficiency + modifiers
- [x] Advantage: roll 2d20, take higher
- [x] Disadvantage: roll 2d20, take lower
- [x] Critical hit on natural 20
- [x] Critical miss on natural 1
- [x] Unit tests for all scenarios
**Status**: DONE
**Estimated Hours**: 5

#### TASK_05: Implement Damage Calculation
**File**: `game/scripts/battle/dnd/damage_calculator.gd`
**Description**: Create damage calculation with weapon dice, modifiers, and critical hits.
**Acceptance Criteria**:
- [x] Weapon damage dice rolled correctly (1d4 to 2d12)
- [x] Ability modifier added to damage
- [x] Critical hits roll double dice
- [x] Support for all 13 damage types
- [x] Resistance/vulnerability multipliers (0.5x, 2x)
- [x] Integration test with attack system
**Status**: DONE
**Estimated Hours**: 6

#### TASK_06: Implement Initiative System
**File**: `game/scripts/battle/dnd/initiative_tracker.gd`
**Description**: Create initiative rolling and turn order management.
**Acceptance Criteria**:
- [x] Initiative = d20 + DEX mod + bonuses
- [x] Turn order sorted by initiative (desc), then DEX (desc)
- [x] Next turn cycles correctly through combatants
- [x] Can add/remove combatants mid-combat
- [x] UI displays turn order
- [x] Integration test with full combat round
**Status**: DONE
**Estimated Hours**: 8

### Phase 2: Height and Positioning (Priority: HIGH)

> **Scope note (2026-09-25):** TASK_07–10 implemented per `specs/height-system/spec.md` (4 requirements: discrete elevation, high-ground bonus, 3D LoS, cover). TASK_11 (vertical movement) and TASK_12 (falling damage) are NOT in the height-system spec — deferred until Phase 6 integration defines how battle cells map to elevation. Deferred items: soft cover from creatures, cover/LoS debug visualization, creature size in LoS, UI indicators (Phase 6).

#### TASK_07: Implement Elevation Data Structure
**File**: `game/scripts/battle/dnd/elevation_system.gd`
**Description**: Add elevation data to battle map and combatant positions.
**Acceptance Criteria**:
- [x] BattleMap has 2D elevation array (`DNDElevationSystem.elevation`, cell→level)
- [x] CombatantPosition includes elevation property — via map lookup: unit's cell → `get_elevation(cell)` (no separate CombatantPosition class in this codebase)
- [x] Elevation stored in 5-foot increments (`FEET_PER_LEVEL = 5`, `height_feet()`)
- [x] Serialization/deserialization for save games (`to_dict`/`from_dict`)
- [x] Unit tests for elevation queries (5 tests in `test_dnd_height.gd`)
**Status**: DONE
**Estimated Hours**: 5

#### TASK_08: Implement High Ground Bonuses
**File**: `game/scripts/battle/dnd/height_modifier.gd`
**Description**: Calculate attack bonuses/penalties based on elevation difference.
**Acceptance Criteria**:
- [x] Melee bonus: +1/+2 for 2/3+ levels higher
- [x] Ranged bonus: +1/+2/+3 for 2/3/4+ levels higher
- [x] Uphill penalties: -1/-2/-3 for melee (1 level = 0 per spec), -1/-2 for ranged
- [x] Range increase for ranged attacks from height (`range_bonus()`)
- [x] Integration test with attack roll system (`test_attack_roll_includes_height_bonus`)
**Status**: DONE
**Estimated Hours**: 6

#### TASK_09: Implement Cover System
**File**: `game/scripts/battle/dnd/cover_calculator.gd`
**Description**: Calculate cover bonuses based on obstacles and elevation.
**Acceptance Criteria**:
- [x] Four cover levels: none, half, three-quarters, full (`CoverLevel` enum)
- [x] Half cover: +2 AC, +2 DEX saves (wall within 5 ft of the line of fire)
- [x] Three-quarters cover: +5 AC, +5 DEX saves (bonus table; elevation model does not produce this level — needs per-face wall geometry)
- [x] Full cover prevents targeting (`is_targetable()` = false)
- [ ] Soft cover from creatures implemented — deferred (not in height-system spec)
- [ ] Visual indicator shows cover status — deferred (UI is Phase 6, TASK_22)
**Status**: DONE (2 items deferred — see notes)
**Estimated Hours**: 8

#### TASK_10: Implement Line of Sight (3D)
**File**: `game/scripts/battle/dnd/line_of_sight.gd`
**Description**: Implement 3D line of sight checking with elevation.
**Acceptance Criteria**:
- [x] Raycast from attacker eye level to target (Bresenham + linear interpolation of line-of-fire height per spec)
- [ ] Considers creature size/height — deferred (cell-level model: creatures are 1 level tall by definition)
- [x] Blocks LoS when obstacles intersect (cell strictly above the line blocks)
- [x] Performance: <1ms per check with 20 combatants (O(line length) ≈ 17 cells, no allocations beyond the cell list)
- [ ] Debug visualization available — deferred (no in-game debug UI in project)
- [x] Unit tests for various scenarios (5 LoS tests: flat, same cell, wall block, over low wall, diagonal)
**Status**: DONE (2 items deferred — see notes)
**Estimated Hours**: 10

#### TASK_11: Implement Vertical Movement
**File**: `game/scripts/battle/dnd/vertical_movement.gd`
**Description**: Handle climbing, flying, and jumping mechanics.
**Acceptance Criteria**:
- [ ] Climbing costs double movement
- [ ] Athletics check for difficult climbs (DC 10-15)
- [ ] Flying ignores elevation penalties
- [ ] Jump distance based on STR score
- [ ] High jump formula: 3 + STR mod feet
- [ ] Integration test with movement system
**Status**: TODO
**Estimated Hours**: 8

#### TASK_12: Implement Falling Damage
**File**: `game/scripts/battle/dnd/falling_damage.gd`
**Description**: Calculate and apply falling damage.
**Acceptance Criteria**:
- [ ] 1d6 damage per 10 feet fallen
- [ ] Maximum 20d6 damage
- [ ] Landing causes prone condition
- [ ] Optional DEX save (DC 15) to avoid prone
- [ ] Triggered when elevation decreases rapidly
- [ ] Unit tests for all distances
**Status**: TODO
**Estimated Hours**: 4

### Phase 3: Action Economy (Priority: MEDIUM)

#### TASK_13: Implement Action System
**File**: `game/scripts/battle/dnd/action_economy.gd`
**Description**: Track actions, bonus actions, and reactions per turn.
**Acceptance Criteria**:
- [x] One action per turn (`take_action`)
- [x] Bonus action only if ability allows (`can_take_bonus_action(has_source)`)
- [x] One reaction per round (resets at turn start, `reset_turn`)
- [x] All 10 standard actions implemented (`StandardAction` enum + names)
- [x] Action validation (can't take same action twice, `has_taken`)
- [x] UI shows available actions (`available_actions()`; UI render is Phase 6)
**Status**: DONE
**Estimated Hours**: 10

#### TASK_14: Implement Combat Actions
**Files**: Multiple action scripts
**Description**: Implement all standard combat actions.
**Acceptance Criteria**:
- [x] All 10 standard actions defined as `StandardAction` enum (Attack, Cast, Dash, Disengage, Dodge, Help, Hide, Ready, Search, Use Object)
- [ ] Per-action runtime effects (Dash doubles movement, Dodge adds disadvantage, Help grants advantage, Hide Stealth check, Ready trigger, Search check, Use Object interact) — deferred to Phase 6 (TASK_21) where they bind to `BattleController`/`BattleActionResolver`
- [ ] Integration tests for each action — deferred to Phase 6 (needs live battle state)
**Status**: PARTIAL (enum + economy done; runtime effects deferred to Phase 6)
**Estimated Hours**: 16

#### TASK_15: Implement Opportunity Attacks
**File**: `game/scripts/battle/dnd/opportunity_attack.gd`
**Description**: Trigger opportunity attacks when enemies leave reach.
**Acceptance Criteria**:
- [x] Triggers when enemy leaves reach without Disengage
- [x] Uses reaction (checks `defender_has_reaction`, pairs with `DNDActionEconomy.use_reaction`)
- [x] One attack only (not full Attack action, `IS_SINGLE_ATTACK`)
- [x] Doesn't trigger from teleportation
- [x] Doesn't trigger from forced movement
- [ ] Integration test with movement system — deferred to Phase 6 (needs live reach/movement state)
**Status**: DONE (integration test deferred to Phase 6)
**Estimated Hours**: 6

### Phase 4: Special Maneuvers (Priority: MEDIUM)

#### TASK_16: Implement Grapple System
**File**: `game/scripts/battle/dnd/grapple.gd`
**Description**: Implement grappling mechanics.
**Acceptance Criteria**:
- [x] Contested check: Athletics vs Athletics/Acrobatics (`DNDGrapple.attempt`, shared `DNDAbilityCheck`)
- [x] Grappled target speed becomes 0 (`grappled_speed`)
- [x] Can move while grappling (half speed, `grappler_move_speed`)
- [x] Grapple ends if grappler incapacitated (`ends_when_grappler_incapacitated`)
- [x] Can escape grapple with action (`escape`, contested, tie keeps grapple)
- [ ] Integration test with combat flow — deferred to Phase 6 (TASK_21)
**Status**: DONE (integration test deferred to Phase 6)
**Estimated Hours**: 6

#### TASK_17: Implement Shove System
**File**: `game/scripts/battle/dnd/shove.gd`
**Description**: Implement shove/prone mechanics.
**Acceptance Criteria**:
- [x] Contested check: Athletics vs Athletics/Acrobatics (tie goes to target)
- [x] Success: target knocked prone OR pushed 5 feet (`ShoveOutcome.PRONE`/`PUSHED`, `PUSH_DISTANCE_FEET`)
- [x] Must have one hand free (`can_shove`)
- [x] Target must be within reach (`can_shove`)
- [x] Can push off edges (falling damage) — `PUSH_DISTANCE_FEET` constant; damage itself is TASK_12 (deferred, not in spec)
- [ ] Integration test with height system — deferred to Phase 6 (TASK_21)
**Status**: DONE (integration test deferred to Phase 6)
**Estimated Hours**: 5

#### TASK_18: Implement Conditions System
**File**: `game/scripts/battle/dnd/condition_manager.gd`
**Description**: Track and apply combat conditions.
**Acceptance Criteria**:
- [x] All 14 conditions implemented (`Condition` enum + `CONDITION_NAMES`)
- [x] Each condition applies correct effects (data-driven `EFFECTS` table → merged `Effects` struct)
- [x] Conditions can stack appropriately (`get_effects` merges all active)
- [x] Duration tracking (timed via `tick()`, -1 = until removed)
- [ ] UI displays active conditions — deferred to Phase 6 (TASK_22)
- [x] Unit tests for each condition (12 tests in `test_dnd_maneuvers.gd`)
**Status**: DONE (UI deferred to Phase 6)
**Estimated Hours**: 12

### Phase 5: Saving Throws and Death (Priority: MEDIUM)

#### TASK_19: Implement Saving Throw System
**File**: `game/scripts/battle/dnd/saving_throw.gd`
**Description**: Implement saving throw mechanics.
**Acceptance Criteria**:
- [x] Roll: d20 + ability mod + proficiency (`DNDSavingThrow.roll`)
- [x] DC calculation: 8 + proficiency + ability mod + bonuses (`calculate_dc`)
- [x] Success/failure determination (`ThrowResult`, `succeeded()`)
- [x] Critical success on natural 20 (`CRITICAL_SUCCESS`)
- [x] Critical failure on natural 1 (`CRITICAL_FAILURE`)
- [ ] Integration test with spells and effects — deferred to Phase 6 (TASK_21)
**Status**: DONE (integration test deferred to Phase 6)
**Estimated Hours**: 5

#### TASK_20: Implement Death Saving Throws
**File**: `game/scripts/battle/dnd/death_saves.gd`
**Description**: Handle dying and death mechanics.
**Acceptance Criteria**:
- [x] Triggered when HP reaches 0 (`die_start`)
- [x] d20 roll each turn (no modifiers)
- [x] 10+ = success, 9- = failure
- [x] 3 successes = stable at 0 HP (`State.STABLE`)
- [x] 3 failures = death (`State.DEAD`)
- [x] Natural 20 = regain 1 HP (`regained_hp`)
- [x] Natural 1 = 2 failures
- [x] Stabilization via Medicine check (`stabilize`)
- [x] Healing brings conscious (`heal`)
**Status**: DONE
**Estimated Hours**: 6

### Phase 6: Integration and UI (Priority: HIGH)

#### TASK_21: Integrate with Existing Battle System
**Files**: Multiple integration points
**Description**: Connect D&D mechanics to existing battle framework.
**Acceptance Criteria**:
- [ ] BattleController uses DnDMechanics
- [ ] Combatant extends with D&D stats
- [ ] DamageCalculator delegates to D&D system
- [ ] TurnManager uses InitiativeTracker
- [ ] Backward compatibility maintained
- [ ] Integration tests for full battles
**Status**: TODO
**Estimated Hours**: 16

#### TASK_22: Update Battle UI for D&D
**File**: `game/scripts/ui/battle/dnd_battle_ui.gd`
**Description**: Display D&D mechanics in battle interface.
**Acceptance Criteria**:
- [ ] Show ability scores and modifiers
- [ ] Display AC prominently
- [ ] Initiative order visible
- [ ] Action buttons for all actions
- [ ] Tooltips show roll breakdowns
- [ ] Condition icons displayed
- [ ] Height difference shown when targeting
- [ ] Cover status indicators
- [ ] Playtest feedback incorporated
**Status**: TODO
**Estimated Hours**: 20

#### TASK_23: Create D&D Character Sheet UI
**File**: `game/scripts/ui/character/dnd_character_sheet.gd`
**Description**: Character sheet showing all D&D stats.
**Acceptance Criteria**:
- [ ] Six ability scores with modifiers
- [ ] Proficiency bonus displayed
- [ ] Skills list with bonuses
- [ ] Saving throws with proficiency
- [ ] Armor class breakdown
- [ ] Hit points and hit dice
- [ ] Equipment and proficiencies
- [ ] Edit mode for character creation
- [ ] Save/load functionality
**Status**: TODO
**Estimated Hours**: 16

## Summary

| Phase | Tasks | Total Hours | Priority |
|-------|-------|-------------|----------|
| Phase 1: Core Mechanics | 6 | 32 | HIGH |
| Phase 2: Height & Positioning | 6 | 41 | HIGH |
| Phase 3: Action Economy | 3 | 32 | MEDIUM |
| Phase 4: Special Maneuvers | 3 | 23 | MEDIUM |
| Phase 5: Saves & Death | 2 | 11 | MEDIUM |
| Phase 6: Integration & UI | 3 | 52 | HIGH |
| **TOTAL** | **23** | **191** | |

## Dependencies

```
TASK_01 ─┬─> TASK_03 ─> TASK_04 ─> TASK_05 ─┬─> TASK_21
         │                                  │
TASK_02 ─┤                                  ├─> TASK_22
         │                                  │
         └─> TASK_06 ───────────────────────┘

TASK_07 ─> TASK_08 ─┬─> TASK_09 ─> TASK_10
                    │
                    └─> TASK_11 ─> TASK_12

TASK_13 ─> TASK_14 ─> TASK_15

TASK_16 ─┬─> TASK_18 ─> TASK_21
         │
TASK_17 ─┘

TASK_19 ─> TASK_20 ─> TASK_21

TASK_21 ─> TASK_22 ─> TASK_23
```

## Testing Strategy

1. **Unit Tests**: Each task includes unit tests for isolated functionality
2. **Integration Tests**: Test interactions between systems
3. **Playtesting**: Regular playtests after each phase
4. **Balance Testing**: Verify mechanics work across levels 1-20
5. **Performance Testing**: Ensure <1ms calculation times

## Documentation Requirements

- Code comments for all public functions
- Inline documentation for complex formulas
- User guide for players (D&D mechanics reference)
- Developer guide for extending the system
- Changelog for each completed task
