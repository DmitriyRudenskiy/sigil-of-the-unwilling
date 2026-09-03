## Stage 1 — Shard abstraction
- [ ] `ShardState` (id, name, seed, biome_mix, entry cell, completed) + `core/ShardManager.gd` (list + active).
- [ ] Parameterize `WorldBootstrap` to bootstrap the active shard (shard #1 = today's world, no behavior change).
- [ ] Save migration v3→v4: wrap the legacy `world` dict under `shards[active]`.
- [ ] Create + load shard #2 (different seed/biome mix).
- [ ] Tests: shard #1 unchanged; shard #2 loads with its seed; save round-trips both.

## Stage 2 — The astral sea
- [ ] `AstralSeaModel` (shards, routes, unlocked, travel cost/cooldown).
- [ ] `ui/AstralSeaScreen.tscn`: shard nodes + route edges; menu entry «Астральное море».
- [ ] Travel action: pay, cooldown, switch active shard, load its `World.tscn`, place hero at entry with existing forces.
- [ ] Tests: travel switches shards and preserves forces; locked routes are unavailable.

## Stage 3 — Shard completion
- [ ] Scope `endgame-conditions` victory: shard vs run; completed shard sets `ShardState.completed` + unlocks outbound routes.
- [ ] Final-shard victory ends the run (or continue exploring — setting).
- [ ] Test: completing shard #1 unlocks its route and does not end the run.

## Stage 4 — Factions
- [ ] `Faction` archetype (theocracy/swarm/legion) over `EnemyAIProfile`; `FactionState` (goal, war/truce, strength).
- [ ] Per-faction goals (expand, capture the sigil); growth via the `enemy-world-ai` machinery.
- [ ] Faction panel UI (name, goal, war/truce state).
- [ ] Test: two factions with different goals behave differently; war/truce is visible.

## Stage 4+ — Cross-shard legend
- [ ] Move glory/chronicle/inherited state to campaign scope; final run summary aggregates shards.
- [ ] Test: glory and chronicle persist across a shard travel + succession.

## Per-stage gate
- [ ] After each stage: full suite + scenarios green; re-run the agent-run-and-debug gate; commit per stage.
