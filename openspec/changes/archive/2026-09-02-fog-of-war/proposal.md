---
description: "Add fog of war and an exploration loop: per-cell visibility states (unexplored / explored / visible), fog rendering on map and minimap, interaction limited to visible cells, cities extending sight, and fog persisted through save/load."
---

## Why

The game has **no fog of war or visibility system at all** — a grep for `fog|visibility|explored` across `game/` returns nothing. The entire map, every enemy stack, and every resource node is visible from turn 1.

Consequences:
- There is no exploration loop — the core 4X/hero discovery fantasy ("what's over that hill?") is absent.
- There is no map tension: the player can route around every threat because every threat is known.
- `WorldStateDelta`'s "explored" surface area and the minimap's full information make the minimap a cheat sheet, not a tool.

This change adds the visibility model and the rendering/interaction rules that make the map something to discover.

## Proposed Change

1. **Visibility model.** Each cell has a state: `unexplored` / `explored` / `visible`. `visible` = within sight radius of the hero or an allied city (configurable). `explored` = ever visible (remembered). Recomputed on hero move and each turn.
2. **Map rendering.** `MapRenderer` draws fog: unexplored cells are dark/hidden (no terrain detail, no entities); explored-but-not-visible cells show terrain (dimmed) but **no** dynamic entities (enemies, unvisited resources).
3. **Minimap.** `MinimapPanel` mirrors fog: unexplored = black, explored = desaturated terrain, visible = full + entity dots.
4. **Interaction rules.** The hero **MUST NOT** move to, or act on (capture, collect, chest, scroll), cells that are not visible. Reachable markers are limited to visible cells.
5. **City sight.** Cells within a city's sight radius count as visible — the player "sees" around their bases.
6. **Persistence.** Explored state is serialized into the save (`world` dictionary) and restored on load.

## Scope

- **In:** `VisibilityMap` (core), fog rendering in `MapRenderer` + `MinimapPanel`, interaction gating in `HeroMovementController`/`WorldInteractionController`, city sight, save/load, unit tests, one auto-game scenario (fog expands as the hero moves).
- **Out:** line-of-sight occlusion by terrain (sight is radius-based, not blocked by tiles — simpler, and matches the flat-hex art), per-unit sight differences, scouting units as a separate mechanic (city/hero sight only for now).

## Dependencies

- None hard. `city-in-world` gives the "allied city" sight sources (until it lands, only the capital counts). `enemy-world-ai` benefits (enemies hidden until seen) but does not block it.
