## 1. Audit (baseline)
- [x] Confirm no visibility code exists; note the minimap's full-map render and the reachability entry points.

## 2. `VisibilityMap`
- [x] `core/VisibilityMap.gd`: `visible`/`explored` grids; `recompute(hero_cell, sight_sources, hero_sight, city_sight)`; monotonic `explored`.
- [x] `GameSettings`: `FOG_HERO_SIGHT`, `FOG_CITY_SIGHT`.
- [x] Tests: disk correctness (hex distance), monotonic explored, city sight adds cells.

## 3. Rendering
- [x] `MapRenderer` fog pass: unexplored hidden, explored dimmed (no dynamic entities), visible full.
- [x] `visibility_changed` signal → redraw affected cells only.
- [x] Minimap: black / desaturated / full + entity dots; throttled rebuild.

## 4. Interaction gating
- [x] `HeroMovementController`: unexplored cells not reachable; markers clipped to visible.
- [x] `WorldInteractionController`: refuse capture/collect/chest/scroll on non-visible cells + status message.
- [x] Tests: cannot reach/act on hidden cells; can after they become visible.

## 5. City sight + persistence
- [x] Sight sources include player-owned city centers (capital until `city-in-world`).
- [x] Serialize `explored` grid in the save `world` dict; recompute `visible` on load.
- [x] Test: explored set survives save/load.

## 6. Scenario + gate
- [x] Auto-game scenario: assert fog is present at start, expands after the hero moves, and a hidden enemy becomes visible on approach.
- [x] Full suite + all scenarios green; re-run the agent-run-and-debug gate; commit.
