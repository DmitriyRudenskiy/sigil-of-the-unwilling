## Context

- `docs/CONCEPT_GAME.md`: three pillars — micro (city, done), meso (world shard, mostly done), macro (astral sea, shards, factions, diplomacy, travel — absent).
- The world is a single bootstrap: `WorldBootstrap` builds one map (seeded `MapGenerator`), one capital, one hero, static enemy stacks. There is no notion of "another map."
- Save: `SaveData v3` holds one `world` dictionary — no shard list, no run scope vs shard scope.
- Victory today (after `endgame-conditions`) is run-scoped: ending the game ends the whole run. Shard completion needs victory to be shard-scoped.
- Enemy AI (after `enemy-world-ai`) is one hostile "faction"; factions need per-faction goal sets and states.
- `GameSession` (after `endgame-conditions`) tracks run state — the astral sea needs a *campaign* state above it.

## Design

**1. `ShardState` + `core/ShardManager.gd` (Stage 1).**
A `ShardState`: `id`, `name`, `seed`, `biome_mix`, entry cell, completion flag, and references to that shard's `world` dictionary (cities, enemies, growth, fog). `ShardManager` owns the shard list + the active shard; `WorldBootstrap` becomes "bootstrap the active shard" (a thin parameterization — shard #1 is exactly today's world, so Stage 1 is a refactor with no behavior change). Save migration: the single `world` dict moves under `shards[active]` (v3→v4 with a migration that wraps the legacy field).

**2. The astral sea (Stage 2).**
`ui/AstralSeaScreen.tscn`: a node graph (shards as nodes, routes as edges; a `GraphNode`-style layout or a simple 2D arrangement). Data: `AstralSeaModel` (shards, routes, unlocked set, travel cooldown/cost). Travel = a route action: pay cost, start cooldown, switch the active shard, load its `World.tscn` with its seed, place the hero at the entry cell with existing forces. Menu gets an «Астральное море» entry (visible once ≥1 route exists).

**3. Shard completion (Stage 3).**
`endgame-conditions` gains a scope: `VICTORY` can be *shard* scope (complete this shard) vs *run* scope (the final goal). A completed shard sets `ShardState.completed` and unlocks its outbound routes. The run ends only at the final shard's victory (or the player may continue exploring — a setting).

**4. Factions (Stage 4).**
`EnemyAIProfile` (from `enemy-world-ai`) generalizes to a `Faction` archetype: `theocracy` / `swarm` / `legion` (per `CONCEPT_GAME.md`), each a goal set + growth behavior over the existing stack machinery. `FactionState`: `id`, `shard`, `goal`, `war_truce` (`at_war`/`truce`), `strength`. War/truce is a stub state machine (actions to declare/seek truce come later with diplomacy — out of scope). UI: a faction panel (name, goal, state) in the adventure UI.

**5. Cross-shard legend (Stage 4+).**
Glory, the chronicle, and inherited state (sigil, path) live at campaign scope (above `ShardManager`), so they persist across shards and survive succession. The final run summary aggregates all shards.

**Grounding facts (files):**
- `docs/CONCEPT_GAME.md` (macro pillar: shards, factions, diplomacy, travel)
- `game/world/WorldBootstrap.gd` (single-world bootstrap to parameterize)
- `game/core/SaveData.gd` (v3, single `world` dict)
- `game/core/GameSession.gd` (+ `endgame-conditions` state)
- `game/data/` (`EnemyAIProfile` from `enemy-world-ai`)
- `game/ui/MainMenu.tscn` (new «Астральное море» entry)
