# Project Task List & Roadmap

This document tracks the progress, current status, and future tasks for the project.

## ✅ Completed Tasks

### Image & Asset Pipeline
- [x] Identify and analyze source images from local folders (refer_spell, folder 33).
- [x] Create sprite sheets from raw images using `tools/make_grid.py`.
- [x] Extract 32 high-quality icons from image grids with automatic background removal and 128x128 resizing.
- [x] Implement image compression (JPG) for server processing.
- [x] Standardize all primary assets to 512x512 resolution using LANCZOS algorithm.
- [x] Automate asset sorting into `data/processed/{biome}` folders based on color analysis.
- [x] Implement hexagon-cropping mask for all textures to ensure correct tiling.
- [x] Generate visual showcase (`biome_showcase.png`) and map preview (`map_preview.png`).

### Project Architecture & Structure
- [x] Analyze and identify "Type-based" project structure.
- [x] Create "Feature-based" migration plan.
- [x] Execute Phase 1 Migration:
    - Move global systems to `scripts/core/`.
    - Move entity logic to `game/scripts/entities/`.
    - Move complex logic to `game/scripts/systems/`.
    - Move UI components to `game/scripts/ui/`.
    - Move world management to `game/scripts/world/`.
    - Move config/data to `scripts/data/`.
- [x] Establish comprehensive Documentation Suite in `/DOCS`.

### Tools & Knowledge Graph
- [x] Integrate `graphify` and `grepai` for Knowledge Graph analysis.
- [x] Map project dependencies using Graphify.
- [x] Identify and analyze core project tools (`tileset_builder.gd`, `make_grid.py`).

### Biome & World System
- [x] Analyze texture combinations for biomes (Swamp, Water, etc.).
- [x] Establish visual weight and color palette guidelines.
- [x] Verify `scripts/autoload/ResourceRegistry.gd` for biome compatibility.

### Documentation & Concepts
- [x] Created `DOCS/CONCEPT_ENDLESS_LEGEND.md` (FIDSI, Boroughs, Approval, Seasons).
- [x] Created `DOCS/CONCEPT_LORDS_OF_MAGIC.md` (Followers, Stewards, Fame, Resources).
- [x] Created `DOCS/CONCEPT_HYBRID.md` (Synthesis of EL + LoM).
- [x] Created `DOCS/CONCEPT_GAME.md` (Full Game Concept).
- [x] Created `DOCS/CONCEPT_ENDLESS_LEGEND_ANALYSIS.md` (Technical Analysis).

## 🚧 Roadmap: Sigil of the Unwilling Project

### Core Systems Refinement (Closing Loopholes)
- [ ] **Max Builders**: Implement `max_builders` limit for all building types in the UI and logic.
- [ ] **Net Food Indicator**: Update UI to display "Net Food" (Production - Consumption) instead of gross output.
- [ ] **Migration Cap**: Implement `1 + (Level / 2)` migration cap per turn.
- [ ] **Upkeep System**: Implement Gold upkeep for `prod_tavern`, `prod_market`, and `health_clinic`.
- [ ] **Disease Pool**: Replace instant death with the accumulated "Disease Pool" and Outbreak mechanic.
- [ ] **Adjacency Penalties**: Implement logic for Industrial, Sanitary, and Commercial zones.
- [ ] **Logistics/Roads**: Implement distance-based work speed penalties and `infra_road` removal.
- [ ] **Scale Shift**: Implement the transition to "Households" and "Urban Quarters" at Turn 50+.

### Module 1: Foundation (Economy & Logistics)
- [ ] **Resource & Binome System**:
    - [ ] Implement 3-tier resource categories (Materials, Strategic, Luxury).
    - [ ] Create Binome logic: Luxury $\rightarrow$ Strategic bonus.
    - [ ] Update `ResourceRegistry.gd` with new data.
- [ ] **Building Registry**:
    - [ ] Create `BuildingRegistry.gd` with costs, outputs, and requirements.
    - [ ] Implement tiered construction requirements (Tier 1-3).
    - [ ] Add dependency logic for Strategic resources in high-tier builds.
- [ ] **Population Dynamics**:
    - [ ] Implement non-linear population growth threshold formula.
    - [ ] Implement Migration Cap per turn.
    - [ ] Implement consumption logic (Food/Gold per population).
- [ ] **City & Logistics**:
    - [ ] Implement distance-based work speed penalties from `core_camp`.
    - [ ] Implement "Expansion Penalty" (-10 Approval per extra city).
    - [ ] Create logic for dynamic center relocation and penalty recalculation.
    - [ ] Implement "Net Yield" UI indicators for all production buildings.
- [ ] **Scale Shift**:
    - [ ] Implement transition to "Households" (1:5 ratio) at Level 4.
    - [ ] Implement District/Ring logic for high-population areas.

### Module 2: Economy & Resources (The Engine)
- [ ] **FIDSI Base**: Implement core resource production and consumption.
- [ ] **Food Growth Logic**: Implement non-linear population growth threshold (Food required).
- [ ] **Winter Penalties**: Implement seasonal production drops for Food.
- [ ] **Production Chains**: Implement multi-step crafting (e.g., Wheat $\rightarrow$ Mill $\rightarrow$ Bakery $\rightarrow$ Tavern).
- [ ] **Special Resources**: Implement Gold, Crystals, and Ale production from FIDSI.
- [ ] **Faith System**: Implement Faith generation through Temples and social dogmas.
- [ ] **Soul System**: Implement Soul collection logic (Rituals/Death) and usage for high-level craft.
- [ ] **Empire Plans**: Implement system for global temporary buffs (Influence spend).
- [ ] **Trade Routes**: Implement logistics for resource transport between "Shattered Spheres".

### Module 3: Demography & Characters (The Soul)
- [ ] **Population Units**: Implement physical units on cells (not abstract population).
- [ ] **Job Assignment**: Implement logic for assigning units to specific cells (Forest $\rightarrow$ Industry, etc.).
- [ ] **Transformer Logic**: Implement 3-state logic for population (Worker, Follower, Militia).
- [ ] **Character Classes**: Implement D&D-inspired classes with unique stats and roles.
- [ ] **7-Day Population Cycle**: Implement arrival of new followers based on Fame and Season.
- [ ] **Fame System**: Accumulate Fame via victories, quests, and exploration.
- [ ] **Social Dynamics**: Basic sympathy/antipathy and social interaction system for colonists.
- [ ] **Militia System**: Automatic transition of population units to militia during threats.
- [ ] **Minor Factions**: Implement village system and assimilation mechanics.

### Module 4: Expansion & Diplomacy (The Scale)
- [ ] **Astral Sea Map**: Implement global map with distinct "Shattered Spheres".
- [ ] **Ship Navigation**: Implement movement logic for Astral Ships (Floating Towers, Bio-ships).
- [ ] **Factions & Diplomacy**: Implement AI faction types with relationship scores and trade agreements.
- [ ] **Crisis System**: Trigger global events (Blood of Gods, Plan Convergence, etc.).

### Module 5: Magic & Narrative (The Flavor)
- [ ] **Ley Line System**: Implement "Mana Flow" for powering buildings and spells.
- [ ] **Ritual System**: Implement logic for temple rituals and magical activations.
- [ ] **Storyteller Events**: Implement random event generator based on player state.
- [ ] **Dynamic Weather**: Implement seasonal effects on FIDSI, movement, and combat.

## 🚀 Future Tasks / Backlog

### Graphics & Rendering
- [ ] **Shader/Material Creation**: Custom shaders for biomes (e.g., water ripples, snow shaders).
- [ ] **TileMap Configuration**: Finalize Godot TileMap setup using the processed hex textures.
- [ ] **VFX/Particles**: System for combat effects and environment particles.

### World & AI
- [ ] **Advanced NPC AI**: Behavior trees or state machines for world inhabitants.
- [ ] **Optimization**: Performance profiling for large-scale world generation.

### Quality Assurance
- [ ] **Headless Testing**: Automated tests for core logic in headless environments.
- [ ] **Multi-platform Verification**: Ensuring correct behavior on different OS and resolutions.
- [ ] **Settings Verification**: Validate "zoom" and "combat field" logic requirements (2:1 ratio).
