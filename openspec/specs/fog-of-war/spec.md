---
description: "Requirements for fog of war: per-cell visibility states, fog rendering on map and minimap, interaction limited to visible cells, city-extended sight, and persistence through save/load."
---

# fog-of-war Specification

## Purpose

Туман войны: каждая клетка карты имеет состояние видимости (неразведанная/разведанная/видимая), карта и мини-карта не раскрывают неизвестное, герой ограничен видимыми клетками, города расширяют обзор, а память о разведанном переживает сохранение.

## Requirements

### Requirement: Cells have visibility states
Each map cell **MUST** have a visibility state: `unexplored`, `explored`, or `visible`. `visible` **MUST** equal the union of sight radii around the hero and allied cities; `explored` **MUST** be monotonic (a cell never un-explores).

#### Scenario: Hero movement reveals cells
- **Given** an unexplored area
- **When** the hero moves adjacent to it
- **Then** cells within the hero's sight radius become `visible` and `explored`

#### Scenario: Memory is monotonic
- **Given** an explored but not currently visible cell
- **When** the hero moves away
- **Then** the cell remains `explored`, not `unexplored`

### Requirement: Unexplored terrain is hidden
The map and minimap **MUST NOT** reveal unexplored cells: no terrain detail and no entities.

#### Scenario: The unknown is unknown
- **Given** a cell the hero has never seen
- **When** the map and minimap render
- **Then** the cell shows fog (no terrain, no enemy, no resource)

### Requirement: Explored-but-not-visible hides dynamics
For explored-but-not-visible cells, the map **MUST** show terrain (dimmed) but **MUST NOT** show dynamic entities (enemies, unvisited resources).

#### Scenario: Ghost of the known
- **Given** a previously seen enemy that has since left the area
- **When** the cell is explored but not visible
- **Then** the terrain is visible (dimmed) and the enemy is not drawn

### Requirement: The hero is limited to visible cells
The hero **MUST NOT** move to, or act on (capture, collect, chest, scroll), cells that are not visible; reachable markers **MUST** be clipped to visible cells.

#### Scenario: Cannot act on the unknown
- **Given** a village the hero has not seen
- **When** the hero is adjacent and tries to capture it
- **Then** the action is refused with a status message

#### Scenario: Reachable markers respect fog
- **Given** unexplored cells within MP range
- **When** reachability is computed
- **Then** those cells are not marked reachable

### Requirement: Cities extend sight
Cells within a player-owned city's sight radius **MUST** count as visible.

#### Scenario: Base vision
- **Given** a player city with cells within its sight radius
- **When** visibility is recomputed
- **Then** those cells are visible (and explored) even without the hero nearby

### Requirement: Fog persists through save/load
The explored set **MUST** be serialized into the save and restored on load; the visible set **MUST** be recomputed on load.

#### Scenario: Memory survives
- **Given** an explored region
- **When** the game is saved and reloaded
- **Then** the region is still explored (and visible where a source is present)
