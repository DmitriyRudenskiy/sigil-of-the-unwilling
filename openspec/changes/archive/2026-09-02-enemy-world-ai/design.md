## Context

- Enemy stacks live in `model.enemy_stacks` (cell → stack). `MapSpawner.place_enemies` places them once using a seeded RNG (offset `+777`) and `GameSettings.MAP_ENEMY_COUNT`, choosing factions from `reg.FACTION_SETS` and units via `reg.make_stack(unit_key, rng)`.
- The only enemy behavior is reactive: `WorldEventRouter` → `check_enemy_contact(cell)` on hero move, then `_start_battle`.
- Enemy auras already block/penalize hero movement near stacks (`HeroMovementController._enemy_aura_blocked`) — proof that "enemy presence" already influences the player.
- Pathfinding is ready: `HexUtils.bfs_path`, `astar_path`, `dijkstra(start, max_cost, cost_fn, w, h)` (`core/HexUtils.gd:84-180`).
- Turn cascade: `TurnScheduler` processors (city/economy/demographics) run on `turn_ended` via `WorldEventRouter._run_turn_scheduler`.
- Seasons: `CityManager.get_season(month)`.
- Save: `SaveData v3` (`world` dictionary) — enemy positions not yet serialized.

## Design

**1. `systems/EnemyTurnProcessor.gd`.** Registered into `TurnScheduler` like the other M-phase processors (`WorldBootstrap`). On `turn_ended` it iterates alive stacks and acts. Keeping the cascade pattern (rather than a separate timer) means enemies act exactly once per player turn and stay in the same deterministic, testable pipeline.

**2. Goal selection (`data/EnemyAIProfile.gd`).** A static per-faction/stack-type profile: `aggro_radius`, `mp`, and goal weights `{village, resource, hero}`. `select_goal(stack, world)` scores reachable goals within aggro radius by `weight / distance` and returns the best; ties break by seeded RNG for variety. Trait flags (e.g. `RAIDER` → +village weight, `SEEKER` → +hero weight) come from the registry, not hardcoded.

**3. Movement.** `HexUtils.dijkstra` with a `cost_fn` that reads terrain cost (reuse the hero's `_terrain_cost` semantics) and treats water/blocked cells as impassable; the stack walks the path up to its MP. If the hero is within attack range at the end of the move, the stack attacks instead of moving further.

**4. Capture + contact.**
- Village capture: on reaching a player village cell, flip ownership to `enemy` (via `city-in-world`'s ownership once available; until then, a `MapModel`/`WorldStateDelta` village-ownership flag), emit a world event, and mark the stack "garrisoned" (it stops moving that turn).
- Contact: moving onto the hero's cell calls the existing `WorldBattleCoordinator._start_battle` with roles swapped (enemy is the attacker). Victory/defeat handling is the existing battle flow.

**5. Growth.** Per `get_season(month)`, an `EnemyGrowthSystem` step: for each defeated stack, schedule a respawn (weakened by 1 tier) after N turns; spawn new stacks up to `MAP_ENEMY_COUNT` at frontier cells. Growth counters and scheduled respawns are saved in the `world` dictionary.

**6. Threat UI.** `MarkerLayer`/`MinimapPanel` draw a threat marker for any enemy within aggro radius of a player village or the hero; `AdventureUI` status line shows «Враги движутся» when stacks moved this turn.

**Grounding facts (files):**
- `game/world/MapSpawner.gd` (`place_enemies`, seeded RNG, `FACTION_SETS`, `make_stack`)
- `game/world/WorldEventRouter.gd` (`check_enemy_contact`, `_run_turn_scheduler`)
- `game/entities/HeroMovementController.gd` (`_enemy_aura_blocked`, `_terrain_cost`)
- `game/core/HexUtils.gd` (`bfs_path`, `astar_path`, `dijkstra`)
- `game/core/TurnScheduler.gd` + `game/world/CityManager.gd` (`get_season`)
- `game/core/SaveData.gd` (v3, `world` dict)
