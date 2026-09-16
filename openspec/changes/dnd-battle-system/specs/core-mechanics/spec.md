# Core D&D Battle Mechanics Specification

## Overview
This document specifies the core mechanics for implementing Dungeons & Dragons 5th Edition combat rules in the game's battle system.

## 1. Ability Scores and Modifiers

### 1.1 Six Core Abilities
Each character has six ability scores:
- **Strength (STR)**: Melee attack and damage, athletics, carrying capacity
- **Dexterity (DEX)**: Ranged attack, AC, initiative, acrobatics, stealth
- **Constitution (CON)**: Hit points, concentration checks, endurance
- **Intelligence (INT)**: Magic attacks for wizards, arcana, investigation
- **Wisdom (WIS)**: Magic attacks for clerics/druids, perception, survival
- **Charisma (CHA)**: Magic attacks for sorcerers/paladins/bards, persuasion, intimidation

### 1.2 Modifier Calculation
```gdscript
func get_ability_modifier(score: int) -> int:
    return floor((score - 10) / 2)
```

Example modifiers:
- Score 8-9: -1
- Score 10-11: 0
- Score 12-13: +1
- Score 14-15: +2
- Score 16-17: +3
- Score 18-19: +4
- Score 20-21: +5

## 2. Proficiency Bonus

### 2.1 Progression by Level
| Level | Proficiency Bonus |
|-------|------------------|
| 1-4   | +2               |
| 5-8   | +3               |
| 9-12  | +4               |
| 13-16 | +5               |
| 17-20 | +6               |

### 2.2 Application
Proficiency bonus applies to:
- Attack rolls with proficient weapons
- Spell attack rolls
- Saving throws for proficient abilities
- Skill checks for proficient skills
- Tool checks for proficient tools

## 3. Armor Class (AC)

### 3.1 Base AC Calculation
Different armor types provide different base AC:

**No Armor**: 10 + DEX modifier
**Light Armor**: Base AC + DEX modifier (full)
**Medium Armor**: Base AC + DEX modifier (max +2)
**Heavy Armor**: Base AC (no DEX modifier)
**Shield**: +2 AC (requires proficiency)

### 3.2 Armor Types
| Armor | Cost | AC | Strength Req | Stealth | Weight |
|-------|------|----|--------------|---------|--------|
| Padded | 5 gp | 11+DEX | - | Disadvantage | 8 lb |
| Leather | 10 gp | 11+DEX | - | - | 10 lb |
| Studded Leather | 45 gp | 12+DEX | - | - | 13 lb |
| Hide | 10 gp | 12+DEX (max 2) | - | - | 12 lb |
| Chain Shirt | 50 gp | 13+DEX (max 2) | - | - | 20 lb |
| Scale Mail | 50 gp | 14+DEX (max 2) | - | Disadvantage | 45 lb |
| Breastplate | 400 gp | 14+DEX (max 2) | - | - | 20 lb |
| Half Plate | 750 gp | 15+DEX (max 2) | - | Disadvantage | 40 lb |
| Ring Mail | 30 gp | 14 | - | Disadvantage | 40 lb |
| Chain Mail | 75 gp | 16 | STR 13 | Disadvantage | 55 lb |
| Splint | 200 gp | 17 | STR 15 | Disadvantage | 60 lb |
| Plate | 1500 gp | 18 | STR 15 | Disadvantage | 65 lb |

### 3.3 AC Calculation Function
```gdscript
func calculate_ac(character: Character) -> int:
    var base_ac: int = 10
    var dex_mod: int = character.get_ability_modifier('DEX')
    
    match character.armor_type:
        "none":
            base_ac = 10 + dex_mod
        "light":
            base_ac = character.armor_base_ac + dex_mod
        "medium":
            base_ac = character.armor_base_ac + min(dex_mod, 2)
        "heavy":
            base_ac = character.armor_base_ac
    
    if character.has_shield and character.is_proficient("shield"):
        base_ac += 2
    
    return base_ac
```

## 4. Attack Rolls

### 4.1 Basic Attack Roll Formula
```
d20 + ability modifier + proficiency bonus (if proficient) + other modifiers
```

### 4.2 Attack Roll Implementation
```gdscript
func make_attack_roll(attacker: Character, target: Character, weapon: Weapon) -> AttackResult:
    var d20_roll: int = randi_range(1, 20)
    var ability_mod: int = attacker.get_attack_ability_mod(weapon)
    var prof_bonus: int = attacker.proficiency_bonus if attacker.is_weapon_proficient(weapon) else 0
    var modifiers: int = calculate_situational_modifiers(attacker, target, weapon)
    
    var total_roll: int = d20_roll + ability_mod + prof_bonus + modifiers
    var ac: int = target.calculate_ac()
    
    var result := AttackResult.new()
    result.d20_roll = d20_roll
    result.total = total_roll
    result.target_ac = ac
    result.is_hit = total_roll >= ac or d20_roll == 20
    result.is_critical = d20_roll == 20
    result.is_miss = d20_roll == 1 and total_roll < ac
    
    return result
```

### 4.3 Advantage and Disadvantage
- **Advantage**: Roll 2d20, take higher result
- **Disadvantage**: Roll 2d20, take lower result
- Multiple sources don't stack (only one advantage/disadvantage applies)

```gdscript
func roll_with_advantage(has_advantage: bool, has_disadvantage: bool) -> int:
    var roll1: int = randi_range(1, 20)
    var roll2: int = randi_range(1, 20)
    
    if has_advantage and not has_disadvantage:
        return max(roll1, roll2)
    elif has_disadvantage and not has_advantage:
        return min(roll1, roll2)
    else:
        return roll1  # Normal roll if both or neither apply
```

## 5. Damage Calculation

### 5.1 Damage Formula
```
Weapon damage dice + ability modifier + other bonuses
```

### 5.2 Critical Hits
- On natural 20, roll all damage dice twice
- Add modifiers only once
- Example: Longsword (1d8 slashing) +3 STR on crit = 2d8 + 3

### 5.3 Damage Implementation
```gdscript
func calculate_damage(weapon: Weapon, attacker: Character, is_critical: bool) -> int:
    var damage_dice: int = weapon.damage_dice_count
    var dice_size: int = weapon.damage_die
    
    if is_critical:
        damage_dice *= 2
    
    var dice_damage: int = 0
    for i in range(damage_dice):
        dice_damage += randi_range(1, dice_size)
    
    var ability_mod: int = attacker.get_damage_ability_mod(weapon)
    var total_damage: int = max(0, dice_damage + ability_mod)
    
    return total_damage
```

### 5.4 Damage Types
- Bludgeoning
- Piercing
- Slashing
- Fire
- Cold
- Lightning
- Acid
- Poison
- Psychic
- Necrotic
- Radiant
- Force
- Thunder

## 6. Initiative System

### 6.1 Initiative Calculation
```
d20 + Dexterity modifier + other bonuses
```

### 6.2 Initiative Implementation
```gdscript
func roll_initiative(character: Character) -> int:
    var d20_roll: int = randi_range(1, 20)
    var dex_mod: int = character.get_ability_modifier('DEX')
    var bonus: int = character.initiative_bonus  # Feats, magic items, etc.
    
    return d20_roll + dex_mod + bonus
```

### 6.3 Turn Order Management
```gdscript
class InitiativeTracker:
    var turn_order: Array[Character] = []
    var current_turn_index: int = 0
    
    func init_combat(combatants: Array[Character]):
        var initiatives: Array[Dictionary] = []
        for char in combatants:
            initiatives.append({
                "character": char,
                "initiative": char.roll_initiative(),
                "dex": char.abilities['DEX']
            })
        
        # Sort by initiative (desc), then Dexterity (desc)
        initiatives.sort_custom(func(a, b): 
            if a['initiative'] != b['initiative']:
                return a['initiative'] > b['initiative']
            return a['dex'] > b['dex']
        )
        
        turn_order = []
        for item in initiatives:
            turn_order.append(item['character'])
        
        current_turn_index = 0
    
    func next_turn() -> Character:
        if turn_order.is_empty():
            return null
        
        var current: Character = turn_order[current_turn_index]
        current_turn_index = (current_turn_index + 1) % turn_order.size()
        
        return current
    
    func get_current_character() -> Character:
        if turn_order.is_empty():
            return null
        return turn_order[current_turn_index]
```

## 7. Combat Actions

### 7.1 Standard Actions
Each character gets one action per turn:

1. **Attack**: Make one melee or ranged attack
2. **Cast a Spell**: Cast a spell with casting time of 1 action
3. **Dash**: Double movement speed for this turn
4. **Disengage**: Movement doesn't provoke opportunity attacks
5. **Dodge**: Attacks against you have disadvantage until your next turn
6. **Help**: Give ally advantage on next ability check or attack
7. **Hide**: Make Stealth check to become hidden
8. **Ready**: Prepare action to trigger later
9. **Search**: Make Perception or Investigation check
10. **Use an Object**: Interact with object in environment

### 7.2 Bonus Actions
Available only if specific ability allows:
- Two-weapon fighting off-hand attack
- Casting spells with bonus action casting time
- Class features (Cunning Action, Rage, etc.)
- Certain feats

### 7.3 Reactions
One reaction per round, resets at start of turn:
- **Opportunity Attack**: When enemy leaves your reach
- **Shield Spell**: +5 AC against one attack
- **Counterspell**: Interrupt enemy spellcasting
- **Feather Fall**: Slow descent of falling creatures
- Other reaction-based abilities

## 8. Movement and Positioning

### 8.1 Movement Speed
- Base speed typically 30 feet (6 squares on grid)
- Affected by armor, encumbrance, terrain
- Different movement types: walking, flying, swimming, climbing

### 8.2 Difficult Terrain
- Costs double movement
- Examples: rubble, steep stairs, thick undergrowth

### 8.3 Standing Up from Prone
- Costs half movement speed
- Requires no action

## 9. Special Combat Maneuvers

### 9.1 Grapple
- Contested check: Athletics (attacker) vs Athletics or Acrobatics (target)
- Target's speed becomes 0
- Can move while grappling (at half speed)

```gdscript
func attempt_grapple(attacker: Character, target: Character) -> bool:
    var attacker_roll: int = attacker.make_ability_check('STR', 'athletics')
    var defender_choice: String = 'athletics' if target.skills['athletics'] > target.skills['acrobatics'] else 'acrobatics'
    var defender_roll: int = target.make_ability_check('STR' if defender_choice == 'athletics' else 'DEX', defender_choice)
    
    if attacker_roll >= defender_roll:
        target.status_effects.append("grappled")
        target.speed = 0
        return true
    return false
```

### 9.2 Shove
- Contested check: Athletics (attacker) vs Athletics or Acrobatics (target)
- Success: Target knocked prone OR pushed 5 feet away

### 9.3 Disarm
- Optional rule: Attacker drops item on successful attack with -2 penalty

## 10. Conditions Affecting Combat

### 10.1 Common Conditions
- **Blinded**: Attack rolls have disadvantage, attacks against have advantage
- **Deafened**: Cannot hear, fails checks requiring hearing
- **Frightened**: Disadvantage on checks while source visible, cannot move closer
- **Grappled**: Speed 0, can't benefit from movement bonuses
- **Incapacitated**: Can't take actions or reactions
- **Invisible**: Heavily obscured, attacks have advantage, attacks against have disadvantage
- **Paralyzed**: Incapacitated, can't move/speak, auto-fail STR/DEX saves, attacks against auto-crit within 5ft
- **Petrified**: Heavily obscured, immune to poison/disease, weight x10
- **Poisoned**: Disadvantage on attack rolls and ability checks
- **Prone**: Only crawl movement, attacks from >5ft have advantage, melee attacks against have disadvantage
- **Restrained**: Speed 0, attacks against have advantage, attacks have disadvantage, disadvantage on DEX saves
- **Stunned**: Incapacitated, can't move, speak incoherently, auto-fail STR/DEX saves, attacks against have advantage
- **Unconscious**: Incapacitated, can't move/speak, unaware, auto-fail STR/DEX saves, attacks against auto-crit within 5ft

## 11. Saving Throws

### 11.1 Saving Throw Formula
```
d20 + ability modifier + proficiency bonus (if proficient)
```

### 11.2 DC Calculation
```
DC = 8 + proficiency bonus + ability modifier + other bonuses
```

### 11.3 Implementation
```gdscript
func make_saving_throw(character: Character, ability: String, dc: int) -> SaveResult:
    var d20_roll: int = randi_range(1, 20)
    var ability_mod: int = character.get_ability_modifier(ability)
    var prof_bonus: int = character.proficiency_bonus if character.is_save_proficient(ability) else 0
    
    var total: int = d20_roll + ability_mod + prof_bonus
    var success: bool = total >= dc
    
    var result := SaveResult.new()
    result.d20_roll = d20_roll
    result.total = total
    result.dc = dc
    result.is_success = success
    result.is_critical_success = d20_roll == 20
    result.is_critical_failure = d20_roll == 1 and not success
    
    return result
```

## 12. Death and Dying

### 12.1 Death Saving Throws
- When HP reaches 0, character falls unconscious
- Make death saving throw each turn (d20, no modifiers)
- 10+ = success, 9- = failure
- 3 successes = stable at 0 HP
- 3 failures = death
- Natural 20 = regain 1 HP
- Natural 1 = 2 failures

### 12.2 Stabilization
- Medicine check (DC 10) stabilizes dying creature
- Healing any amount brings creature conscious

## 13. Rest and Recovery

### 13.1 Short Rest
- 1 hour minimum
- Can spend Hit Dice to recover HP
- Some abilities recharge

### 13.2 Long Rest
- 8 hours minimum
- Regain all lost HP
- Regain spent Hit Dice (up to half maximum)
- Most abilities and spell slots restored

## Integration Points

### Existing Systems to Modify
1. `BattleController.gd` - Main battle flow control
2. `Combatant.gd` - Character stats and abilities
3. `DamageCalculator.gd` - Damage computation
4. `TurnManager.gd` - Initiative and turn order
5. `BattleUI.gd` - Display D&D mechanics

### New Scripts to Create
1. `DnDMechanics.gd` - Core D&D calculations
2. `InitiativeTracker.gd` - Turn order management
3. `ConditionManager.gd` - Status effects handling
4. `SavingThrow.gd` - Save mechanics
5. `ActionEconomy.gd` - Actions/bonus actions/reactions tracking

## Testing Requirements
- Unit tests for all calculation functions
- Integration tests for complete combat scenarios
- Edge case testing (critical hits/fails, advantage/disadvantage stacking)
- Performance testing with multiple combatants
- Balance testing across character levels 1-20

## References
- Dungeons & Dragons 5th Edition Player's Handbook
- Dungeons & Dragons 5th Edition Dungeon Master's Guide
- System Reference Document (SRD) 5.1
