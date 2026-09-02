## 1. Audit (baseline)
- [x] Confirm enemy stacks are static (no turn movement) and contact is hero-triggered only.
- [x] Note `HexUtils.dijkstra` signature and the hero `_terrain_cost` semantics to reuse.

## 2. `EnemyTurnProcessor`
- [x] Create `systems/EnemyTurnProcessor.gd`, register in `TurnScheduler` via `WorldBootstrap`.
- [x] Iterate alive stacks on `turn_ended`; respect per-stack MP.
- [x] Deterministic: seeded RNG per stack; same seed → same enemy turns (testable).

## 3. Goal selection + movement
- [x] `data/EnemyAIProfile.gd`: aggro radius, MP, goal weights, trait flags.
- [x] `select_goal(stack, world)`: weighted `village/resource/hero` within aggro radius.
- [x] Move via `HexUtils.dijkstra` with terrain `cost_fn`; stop on attack range of the hero.

## 4. Capture + contact
- [x] Village capture: flip ownership to `enemy` (flag until `city-in-world`), emit event, garrison the stack.
- [x] Contact: `_start_battle` with roles swapped; reuse existing battle flow + result handling.
- [x] Unit tests: capture flips ownership; contact starts a battle; garrisoned stack holds.

## 5. Growth
- [x] `EnemyGrowthSystem`: per-season respawn (weakened) + spawn to `MAP_ENEMY_COUNT`.
- [x] Persist growth counters + scheduled respawns in the save `world` dict.
- [x] Test: defeated stack respawns after N turns; cap is respected.

## 6. Threat UI
- [x] Minimap/marker threat indicator for enemies within aggro radius of a village or the hero.
- [x] Status line «Враги движутся» when stacks moved.

## 7. Scenario + gate
- [x] Auto-game scenario: place an enemy near a village, end turns until it captures (assert ownership flip).
- [x] Full suite + all scenarios green; re-run the agent-run-and-debug gate; commit.
