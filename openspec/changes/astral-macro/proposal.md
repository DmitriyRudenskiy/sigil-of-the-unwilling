---
description: "Turn the single-shard game into a multi-shard strategy: shard abstraction (the current world becomes one shard), an astral-sea meta-map of shards and routes, travel between shards, shard completion, and AI factions with goals and war/truce states. A long-term epic, staged."
---

## Why

`docs/CONCEPT_GAME.md` defines the game as three pillars: the micro-level (the city — done), the meso-level (the world shard — mostly done), and the **macro-level: the astral sea, shards, factions, diplomacy, and travel between shards — none of which exists**. The current game is a single static map: one bootstrap (`WorldBootstrap`), one world, static enemies, no other shards, no factions beyond enemy stacks.

The identity cycles answer "why does the hero keep playing" (the path, the sigil, generations). The macro level answers "what is bigger than one map" — it is the project's "foundation for something bigger." This is the long-term epic that turns a one-map game into a campaign of shards.

This is deliberately an **epic**: it is staged, and each stage is independently shippable.

## Proposed Change (staged)

1. **Stage 1 — Shard abstraction.** Encapsulate the current world (map + cities + hero + enemy state) as a *shard*: a `ShardState` (seed, cities, enemies, completion) managed by `core/ShardManager.gd`. The current game becomes shard #1 with no behavior change. A second shard (a different seed/biome mix) can be created and loaded.
2. **Stage 2 — The astral sea.** A meta-screen (`ui/AstralSeaScreen.tscn`) showing shards as nodes and routes between them. The player travels along a route (cost + cooldown) and appears at the destination shard's entry cell with their existing forces. Shard entry/exit points are defined per shard.
3. **Stage 3 — Shards can be completed.** A shard is "completed" when its local victory condition is met (via `endgame-conditions`, per-shard scope instead of run scope). Completion unlocks the routes out of the shard.
4. **Stage 4 — Factions.** AI factions on shards (per `CONCEPT_GAME.md`: theocracy / swarm / legion as starting archetypes) with goals (expand, capture the sigil) and a war/truce state visible in the UI; built on `enemy-world-ai` (per-faction goal sets instead of one hostile "faction").
5. **Cross-shard legend.** Glory, the chronicle, and inherited state persist across shards — the legend is bigger than any one map (consumes `legend-chronicle` and `succession-sigil` data).

## Scope

- **In (staged):** `ShardState`/`ShardManager`, shard #2, `AstralSeaScreen` + travel, per-shard completion, faction archetypes + war/truce, cross-shard persistence, save migration, tests per stage, one scenario per stage.
- **Out:** dynamic shard generation beyond seed+biome-mix, full diplomacy (treaty terms, trade), ships as a separate unit class (travel is a route action for now), multiplayer.

## Dependencies (hard)

- `endgame-conditions` (shard completion = local victory; run vs shard scope).
- `enemy-world-ai` (factions are generalized enemy AI).
- `city-in-world` (multiple cities per shard; cross-shard income).
- `legend-chronicle` / `succession-sigil` (the legend persists across shards).
- Stages 1–2 can begin in parallel with those cycles (shard #1 = today's world); stages 3–4 wait on their dependencies.
