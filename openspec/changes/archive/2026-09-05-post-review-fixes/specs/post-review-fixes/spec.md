## Purpose

Behavioral guarantees added by the post-review fix cycle: correct arena input
handling, settings save/rollback semantics, real save-file deletion,
cache correctness, and headless/isolated-context safety across city, arena,
battle, and world systems.

## ADDED Requirements

### Requirement: Arena cell click handling

The city arena view MUST process left mouse button presses on arena cells: a
press MUST invoke the cell click handler for the cell under the pointer.

#### Scenario: Left click selects a cell

- **WHEN** the player presses the left mouse button on an arena cell
- **THEN** the cell click handler runs for that cell and the selection state updates

### Requirement: User save deletion

Save deletion MUST remove the actual save file from disk and MUST return
false when no save exists.

#### Scenario: Deleting an existing save

- **WHEN** a save file exists and deletion is requested
- **THEN** the file is removed from disk and the call returns true

#### Scenario: Deleting a missing save

- **WHEN** no save file exists and deletion is requested
- **THEN** the call returns false and no error is raised

### Requirement: Building placement rejects worker-occupied cells

City building validation MUST reject placement on a cell occupied by a worker
pop unit, in addition to the center/borough/building occupancy checks.

#### Scenario: Build on a worker's cell

- **WHEN** a build is requested on a cell where a worker pop unit is assigned
- **THEN** the request fails with an occupied-cell error and the worker is unaffected

### Requirement: Settings screen apply/cancel semantics

The settings screen MUST persist changes only on "Apply". "Cancel" MUST
restore all editable settings (including volume levels and zoom) to their
pre-open values and MUST NOT save.

#### Scenario: Cancel restores volume

- **WHEN** the user changes a volume level and presses "Cancel"
- **THEN** the volume returns to its pre-open value and no save is written

#### Scenario: Zoom change persists only on Apply

- **WHEN** the user selects a new zoom level and presses "Cancel"
- **THEN** the zoom index is unchanged and unsaved; pressing "Apply" saves it once

### Requirement: Single source of zoom levels

The zoom level table MUST be defined exactly once and every consumer (settings
UI, camera) MUST read it from that single source.

#### Scenario: Settings and camera agree

- **WHEN** a zoom level is selected in settings
- **THEN** the camera zoom and the settings UI report the same value from the shared table

### Requirement: Enemy turn pathfinding budget

Enemy turn processing MUST NOT recompute identical pathfinding queries within
one turn: results for a (start cell, movement budget) pair MUST be reused for
the duration of the turn.

#### Scenario: Multiple stacks, same start and budget

- **WHEN** several enemy stacks share the same start cell and movement budget in one turn
- **THEN** the pathfinding for that pair is computed at most once

### Requirement: Reachability cache board freshness

Cached reachability results MUST be invalidated or versioned against the
battle board state so that queries after any board mutation reflect the
current board.

#### Scenario: Move then query

- **WHEN** a unit moves (changing the board) and reachability is then queried for a previously cached cell
- **THEN** the result reflects the post-move board

### Requirement: Headless-safe FX

Effect playback and particle spawning MUST be safe outside a live rendering
tree and in headless mode: the call MUST guard and return without errors.

#### Scenario: Attack sequence outside the tree

- **WHEN** the attack sequence is requested while the FX node is not in the tree
- **THEN** the call returns gracefully without an assertion failure

#### Scenario: Particle burst in headless

- **WHEN** a particle burst is requested during a headless run
- **THEN** no node is spawned and no error is emitted

### Requirement: Idempotent endgame setup

Endgame controller setup MUST be safe to call more than once: every signal
connection MUST be guarded so handlers are never duplicated.

#### Scenario: Double setup

- **WHEN** setup is called twice with the same dependencies
- **THEN** each signal has exactly one connected handler

### Requirement: City relocation validation

City relocation MUST reject a new center that is outside map bounds or
occupied by another city, in addition to the existing distance and occupancy
checks.

#### Scenario: Relocate out of bounds

- **WHEN** the new center lies outside the map
- **THEN** the relocation fails with a bounds error

#### Scenario: Relocate onto another city

- **WHEN** the new center is a cell belonging to another city
- **THEN** the relocation fails

### Requirement: Mute state consistency and persistence

Mute state MUST be owned by the settings store: toggling mute MUST update and
persist that state, and reset-to-defaults MUST also persist, so mute and
reset survive a restart.

#### Scenario: Mute survives restart

- **WHEN** the user toggles mute
- **THEN** the state is persisted and restored on the next run

#### Scenario: Reset persists

- **WHEN** the user resets settings to defaults
- **THEN** the reset state is persisted

### Requirement: Chronicle entry safety without event bus

Chronicle append MUST work in isolated contexts where the game event bus
autoload is absent: the entry is still recorded and the bus emission is
skipped instead of crashing.

#### Scenario: Append without bus

- **WHEN** an entry is appended with no event bus in the tree
- **THEN** the entry is recorded and no error is raised

### Requirement: Hero placement in hero component

When placing the capital inside the hero's map component, candidate cells MUST
exclude cells occupied by enemy stacks, resources, or other spawn entities.

#### Scenario: Nearest cells are occupied

- **WHEN** the nearest walkable cells in the hero component are occupied by enemy stacks or resources
- **THEN** placement selects a free cell and never places on an occupied one
