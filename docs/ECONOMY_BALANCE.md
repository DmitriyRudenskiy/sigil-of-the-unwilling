# Economy & Balance Documentation

This document details the mathematical foundation and balancing rules for the game's economy, derived from the "Survival to Empire" audit.

## 1. Core Production Formulas

### 1.1. Work & Construction
To prevent instant construction by over-assigning workers, we use the `max_builders` limit.
- **Formula**: `Turns = ceil(work / min(assigned_free, max_builders))`
- **Max Builder Limits**:
  - Small Buildings: 2
  - Medium Buildings: 4
  - Large Buildings: 6

### 1.2. Resource Gathering (Net Yield)
Yields are calculated as **Net Yield** (Total Production - Personnel Consumption).
- **Food Gathering**: Base 3 | Net +2
- **Food Hunting / Fishing**: Base 5 | Net +4
- **Food Fields**: Base 10 per 2 personnel | Net +8

## 2. Population & Growth

### 2.1. Growth Threshold
Population growth is non-linear to force expansion.
- **Formula**: `Threshold = 5 * (Current Population)^2.75`

### 2.2. Migration Cap
To prevent "Explosive Migration" where the population exceeds food capacity instantly:
- **Migration Cap**: `1 + (City Level / 2)` residents per turn.
- *Note: Even if Free Housing points are high, the city can only physically accept this amount per turn.*

### 2.3. Disease Pool (Outbreak System)
Instead of instant death, we use an accumulated pool.
- **Pool Addition**: `Population * BaseRate * Modifiers` per turn.
- **Outbreak**: Occurs when Pool >= 100.
  - Reset Pool to 0.
  - 1d3 residents die (prioritizing free units).
  - Reputation -5.
- **Health Buildings**: Chance (50%) to absorb the outbreak without deaths, costs 5 Food and 2 Gold.

## 3. Upkeep & Reputation

### 3.1. Gold Sinks (Upkeep)
Advanced buildings require Gold to remain operational.
- **Buildings requiring Upkeep**: `prod_tavern`, `prod_market`, `health_clinic`.
- **Penalty**: If Gold < 0, the building is disabled and Reputation decreases by -2 per turn.

### 3.2. Adjacency & Zoning
- **Industrial Zone**: `prod_sawmill`, `prod_quarry`, `prod_mine` must have 1+ adjacent free hexes. If fully surrounded, efficiency drops by 50%.
- **Sanitary Zone**: `health_graveyard` and `prod_forge` (soot) give -1 Reputation and +5% Disease chance for every adjacent housing hex.
- **Commercial Zone**: `prod_market` and `prod_tavern` give +1 Gold / +1 Reputation for every 2 adjacent housing hexes.

### 3.3. Logistics
- **Base Penalty**: -20% work speed for buildings > 3 hexes from `core_camp` / `core_townhall`.
- **Infra Roads**: Remove this penalty. Costs 1 Wood/turn for maintenance if used by caravans.

## 4. Scale Shift (Turn 50+ / Level 4)

When the city reaches Level 4 (Pop ~120+), the paradigm shifts from Individual Units to Households.
- **1 Household** = 5 Residents.
- **District System**: Buildings are grouped into "Urban Quarters" to optimize engine performance.
- **Ring Logic**: Development follows a radial expansion model.

## 5. Starting Map Balance

| Map Type | Food | Wood | Stone | Gold | Survival Note |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Forest** | 20 | 40 | 5 | 0 | High wood, fast food depletion. |
| **Plains** | 35 | 15 | 5 | 0 | High food, critical wood deficit. |
| **Coast** | 25 | 25 | 5 | 5 | Balanced. Gold allows initial trade. |
| **Hills** | 20 | 20 | 20 | 0 | High stone, extreme early wood management. |
