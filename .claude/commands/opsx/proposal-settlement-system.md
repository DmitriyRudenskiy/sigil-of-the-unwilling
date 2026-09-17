# Proposal: Settlement System - Races, Buildings, and Development

## Overview

This proposal outlines a comprehensive settlement management system featuring multiple species, building progression, resource chains, and meta-progression mechanics. The system emphasizes adaptive strategy over perfect optimization, where players build temporary "reputation machines" rather than permanent cities.

## Core Principles

1. **Three Species Limit**: Only three species can coexist in a settlement, determined by caravan selection
2. **Reputation Victory**: Fill the Reputation meter before Forest Hostility becomes overwhelming
3. **Adaptive Economy**: Work with available buildings and resources rather than pursuing optimal builds
4. **Meta-Progression**: Failed settlements contribute resources to the Smoldering City for permanent upgrades

---

## 1. Species System

### 1.1 Available Species

| Species | Base Resolve | Demand Threshold | Decadence | Hunger Tolerance | Break Interval | Key Traits |
|---------|-------------|------------------|-----------|------------------|----------------|------------|
| **Humans** | 15 | High (30) | +4 | 6 | Every 2:00 | Adaptable, rain-sensitive |
| **Beavers** | 10 | High (30) | +2 | 6 | Every 2:00 | Hardworking, honest, demanding |
| **Lizards** | 5 | Medium (15) | +7 | 12 (highest) | Every 1:40 | Hardy, distrustful |
| **Harpies** | 5 | Medium (15) | +3 | 4 (lowest) | Every 1:40 | Noble, fragile, aggressive side |
| **Foxes** | 5 | Medium (15) | +5 | 3 | Every 2:00 | Majestic, mysterious, forest-bound |
| **Frogs** | 10 | 25 | 5 | 8 | Every 2:30 | Proud, wealth-seeking, water-loving, architectural skills |
| **Bats** | TBD | TBD | TBD | TBD | TBD | Nightwatchers DLC |

**Notes:**
- Frogs unlock at Smoldering City Level 9 (Keepers of the Stone DLC)
- Bats unlock at Smoldering City Level 11 (Nightwatchers DLC)
- Frogs refuse to live in basic Shelters; require species-specific housing immediately

### 1.2 Species Mechanics

**Resolve (Mood)**
- Primary wellbeing indicator
- High resolve generates Reputation points over time
- Resolve dropping to 0 causes residents to leave
- Affected by needs satisfaction, comfort, and events

**Needs System**
- Food preferences (species-specific complex foods)
- Clothing requirements (Coats, Boots)
- Housing needs (basic shelter vs species houses)
- Service goods (ale, incense, scrolls)

**Specializations**
- **Proficiency**: 10% chance to produce double resources when working in matching specialization
- **Comfort**: +5 individual Resolve when working in matching specialization

**Need Satisfaction Bonuses**
- Numbers (+4, +5, +8, +10) indicate Resolve bonus per satisfied need
- Coats: +5 Resolve, +3 during Storm
- Boots: +5 Resolve, +15% movement speed

---

## 2. Building System

### 2.1 Starting Buildings

- **Ancient Hearth**: Heats nearby homes; settlers gather here to rest and eat
- **Main Warehouse**: Centralizes resources for settlement supply chain

### 2.2 Camps (Resource Gathering)

| Camp Type | Size | Unlocks | Purpose |
|-----------|------|---------|---------|
| Woodcutters' Camp | Normal | Always | Tree harvesting |
| Stonecutters' Camp | Normal | Always | Stone mining |
| Harvesters' Camp | Normal | Always | General gathering |
| Small Foragers' Camp | Small | Always | Plant resources (small nodes only) |
| Small Herbalists' Camp | Small | Level 2 | Medicinal herbs |

### 2.3 Production Buildings

**General Production**
- **Lumber Mill**: Produces planks from wood
- **Bakery**: Produces complex foods
- **Granary**: Agricultural processing
- **Crude Workstation**: Early-game production of planks, bricks, cloth

**Species-Specialized Buildings**
- **Cooperage (Harpies)**: Barrels, coats, tea
- **Tinctury (Beavers)**: Ale, wine, pigment

**Recipe Selection**: Buildings produce one selected recipe at a time, not all simultaneously

### 2.4 Housing System

**Basic Housing**
- **Shelter**
  - Capacity: 3 settlers
  - Cost: Wood
  - Availability: Always
  - Note: Frogs refuse to live here

- **Big Shelter**
  - Capacity: 3 settlers
  - Cost: Wood
  - Unlocks: Ancient Knowledge upgrade

**Species Houses** (2 capacity each)
| House | Species | Cost | Unlock Requirement |
|-------|---------|------|-------------------|
| Human House | Humans | 4 Planks + 2 Bricks | Vanguard Spire L1 |
| Beaver House | Beavers | 8 Planks | Vanguard Spire L2 |
| Lizard House | Lizards | 2 Cloth + 2 Bricks | Vanguard Spire L3 |
| Harpy House | Harpies | 4 Cloth | Vanguard Spire L4 |
| Fox House | Foxes | TBD | Vanguard Spire L6 |
| Frog House | Frogs | TBD | Smoldering City L9 |
| Bat House | Bats | TBD | Smoldering City L11 |

**House Upgrades**
- Two upgrade levels per house type
- Choose 1 of 2 bonuses per level
- Common bonuses: +15% movement speed, +1 housing capacity, +1 Resolve per resident
- Unlocks at high Smoldering City levels (Brass Forge L11, Pioneer Gates L12)

**Housing Mechanics**
- **Hearth Radius**: All housing must be within Ancient Hearth radius
- **Auto-distribution**: Homeless settlers automatically move into new houses
- **Resolve Impact**: Satisfied housing needs provide small constant Resolve bonus
- **Critical for**: Harpies and Foxes especially benefit from species housing

### 2.5 Service Buildings

Provide access to services (e.g., Tavern serving ale)

### 2.6 Construction Mechanics

- Built by idle settlers (not assigned to other tasks)
- Require appropriate building materials
- Slow construction? Temporarily reassign workers from production
- Diversity over efficiency: having reliable recipes matters more than perfect optimization

---

## 3. Resources and Goods

### 3.1 Food Chain

**Raw Food**
- Gathered from map nodes
- Basic sustenance

**Complex Food**
- Produced from raw food in specialized buildings
- Better saturation and Resolve bonuses
- Examples: Jerky, Kebab, Cookies, Pie, Pickles, Porridge
- Species have preferred complex foods

### 3.2 Building Materials

**Primary**: Planks, Bricks, Cloth
**Special**: Spare Parts, Wildfire Essence

### 3.3 Consumables

**Clothing**
- Coats: +5 Resolve, +3 during Storm
- Boots: +5 Resolve, +15% movement speed

**Service Goods**
- Ale, Incense, Scrolls, etc.

### 3.4 Fuel & Exploration

**Fuel**: Firewood, Coal, Sea Marrow
**Tools**: Used for clearing dangerous glade events

### 3.5 Trade Goods

- **Amber**: Primary currency
- **Packs of Goods**: Bundled resources for sale
- **Ancient Tablets**: Valuable Citadel resource

---

## 4. Settlement Development

### 4.1 Meta-Progression: Smoldering City

The Smoldering City serves as permanent capital and meta-progression hub. Earn special Citadel resources in settlements, spend them here for permanent upgrades:

- New starting buildings
- Species improvements
- Resource bonuses
- Other permanent effects

### 4.2 Early Game Strategy

**First Steps**
1. Pause and plan initial actions
2. Build 2-3 Woodcutters' Camps (wood = fuel + building material)
3. Construct Crude Workstation for planks, bricks, cloth production
4. Before first storm: build shelters for 8+ settlers + park/decoration in Hearth radius

**Hearth Level Progression** (via houses and decorations in radius)
- **Level 1**: +1 Resolve for all settlers
- **Level 2**: +10% production speed
- **Level 3**: +10% chance for double production

### 4.3 Economic Strategy

**Beginner Approach**
1. Raw food → One reliable complex food → Efficient fuel → Rainwater upgrades
2. Don't try to produce everything simultaneously
3. Recipe flexibility: swap ingredients based on available resources
4. Reliable > Optimal: consistent production beats theoretical maximums

**Advanced Mechanics**
- **Trade**: Build Trading Post to exchange goods for Amber, buy missing resources/buildings
- **Rainwater**: Collect and route to production buildings for speed/crit/Resolve bonuses
- **Small Warehouses**: Build near remote production/farms to reduce carry time (critical for farmers)
- **Rainpunk Engines**: Install in buildings to boost worker Resolve

### 4.4 Population Management

**Firekeeper Assignment**
Different species provide different bonuses as Firekeeper:
- Harpies: Movement speed bonus
- Lizards: Resolve bonus

**Resolve Management**
- High Resolve → Gradual Reputation point generation
- Low Resolve (→0) → Settlers leave settlement
- Boost methods:
  - Satisfy species-specific needs (food, clothing, housing, services)
  - Assign to matching specialization buildings (+5 Comfort)
  - Install Rainpunk Engines
  - Appropriate Firekeeper selection

### 4.5 Building Access

**Limited Random Access**
- New buildings obtained via: Reputation rewards, quest completion, trader purchases, glade event clearing
- Cannot build everything desired; must adapt economy to available tools
- Building diversity often more valuable than maximum efficiency

### 4.6 Forest Hostility and Storms

**Hostility Growth Factors**
- Each passing year
- Each new settler
- Each opened glade
- Each active woodcutter camp

**Storm Effects**
- Higher Hostility = harsher Resolve penalties during Storm
- Critical Resolve drop causes mass exodus

**Risk Management**
- Don't open all glades indiscriminately
- Focus exploration on Dangerous and Forbidden glades (best resources/events)
- During Storm: fire woodcutters to reduce Hostility
- Build Small Hearths in new districts (each reduces overall Hostility)

### 4.7 Prestige Levels (Non-Remote Mechanics)

| Prestige | Effect |
|----------|--------|
| 1 | Victory requires +4 additional Reputation points; quests harder |
| 2 | Storm season lasts longer |
| 5 | Low-Resolve settlers leave 2× faster |
| 6 | All building costs +50% |
| 7 | 50% chance to consume 2 food instead of 1 |
| 8 | 50% chance to consume 2 luxury goods instead of 1 |
| 9 | Settlers work 33% slower on glade events |
| 10 | All trade goods 50% cheaper for merchants |

*Prestige levels involving remote mechanics excluded*

---

## 5. Victory and Defeat

**Victory Condition**
- Reputation meter completely filled

**Defeat Conditions**
- All settlers left or died
- Critical instability threshold reached

---

## 6. Design Philosophy

### 6.1 Originality Statement

This is an original design work that borrows general concepts but significantly reimagines and modifies them:

**Key Differences from Source Material**
- **Species**: 7 species vs 5+2; original stats and mechanics
- **Unified Buildings**: Unique mechanic; closest analogue is "Commons" but functions differently
- **Specializations**: Original inventions (e.g., "Cooperation" bonus for 3+ Foxes in same building)

### 6.2 Core Gameplay Loop

> You are not building a city for eternity. You are building an efficient temporary machine for generating Reputation. The main goal is to prevent collapse, quickly establish key supply chains, and complete enough quests to win before Forest Hostility becomes insurmountable.

**Key Advice**: Don't fear failure. Every lost settlement still contributes resources to meta-progression, making the next attempt slightly easier. Adaptability and quick restructuring are the keys to success.

---

## 7. Implementation Notes

### 7.1 Data Gaps Requiring Clarification

- **Bat species**: All numerical stats (Base Resolve, Demand, Decadence, Hunger Tolerance, Break Interval) need definition
- **Fox House**: Cost specification needed
- **Frog House**: Cost specification needed
- **Bat House**: Cost specification needed

### 7.2 Level References

"Levels" for Frogs and Bats refer to Smoldering City meta-progression levels:
- Frogs: Unlock at Level 9 (Keepers of the Stone DLC required)
- Bats: Unlock at Level 11 (Nightwatchers DLC required)

### 7.3 Unified Buildings Clarification

Unified buildings function similarly to "Commons" building:
- Satisfy multiple service needs in one location
- Provide smaller Resolve bonus than specialized buildings
- Unlock at Smoldering City Level 6

The card/biome/landscape transformation system represents a new gameplay layer beyond core mechanics.

---

## 8. Next Steps

1. Fill data gaps for Bat species statistics
2. Define costs for Fox/Frog/Bat houses
3. Create detailed recipe tables for all production buildings
4. Design specific glade event types and rewards
5. Balance prestige level difficulty curve
6. Develop tutorial progression for new players
