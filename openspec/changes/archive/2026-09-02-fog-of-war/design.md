## Context

- No visibility code exists: `grep -rn "fog\|visibility\|explored" game/ --include="*.gd"` (non-test) is empty.
- The map is fully rendered from the start: `MapRenderer` draws every cell from `MapModel` terrain; `MapSpawner` places all enemies/resources, all visible.
- Hero reachability: `HeroMovementController` computes reachable cells (`can_reach`, `_full_path`, `show_reach_markers`) via terrain cost; there is no visibility term.
- Interaction: `WorldInteractionController` (`capture_village_at`, `collect_resource_at`, `check_chest_contact`, `pickup_scroll_at`) has no visibility check.
- Minimap: `ui/MinimapPanel.gd` renders the full map (terrain + entities) — a cheat sheet today.
- Save: `SaveData v3` `world` dictionary is the home for the explored set.
- The capital (and later all player cities via `city-in-world`) are natural sight sources.

## Design

**1. `core/VisibilityMap.gd`.** Holds three parallel `PackedByteArray`/int grids over the map: `visible`, `explored` (0/1). `recompute(hero_cell, sight_sources: Array[Vector2i], hero_sight: int, city_sight: int)` sets `visible` = union of radius disks (hex distance, `HexUtils.hex_distance`) around sources; `explored` is OR-accumulated (monotonic — never un-explored). Radius-based, not line-of-sight: simpler, deterministic, and consistent with the flat tile art. Constants in `GameSettings` (`FOG_HERO_SIGHT`, `FOG_CITY_SIGHT`).

**2. Rendering (`world/MapRenderer.gd`).** A fog pass after terrain/entities:
- unexplored: draw a solid dark tile (or skip the cell + dark overlay) — no terrain detail, no entities.
- explored + not visible: draw terrain dimmed (multiply/overlay); dynamic entities (enemy stacks, unvisited resource nodes/chests/scrolls) are **not** drawn.
- visible: full render.
Implemented as a single overlay pass (per-cell color or a batched polygon) to keep one draw call class; a `visibility_changed` signal triggers the redraw of affected cells (not the whole map) on move.

**3. Minimap (`ui/MinimapPanel.gd`).** Same three states: black / desaturated terrain / full + entity dots. Rebuilt on `visibility_changed` (throttled per frame).

**4. Interaction gating.** `HeroMovementController` marks unexplored cells as impassable for reachability (they cannot become reachable); `WorldInteractionController` refuses actions on non-visible cells with a status message. Reachable markers are clipped to visible cells.

**5. City sight.** Sight sources = hero cell + all player-owned city centers (via `city-in-world` ownership; until then, the capital). Recomputed each turn and on hero move.

**6. Persistence.** Serialize the `explored` grid (a `PackedByteArray`, ~map-size bytes) into the save `world` dictionary; `visible` is recomputed on load. Additive save field.

**Grounding facts (files):**
- `game/core/HexUtils.gd` (`hex_distance`, `get_all_neighbors`)
- `game/entities/HeroMovementController.gd` (reachability, markers, `_terrain_cost`)
- `game/world/MapRenderer.gd`, `game/world/MapModel.gd` (cells/terrain)
- `game/world/WorldInteractionController.gd` (actions to gate)
- `game/ui/MinimapPanel.gd` (full-map minimap)
- `game/core/GameSettings.gd` (new sight constants)
- `game/core/SaveData.gd` (v3, `world` dict)
