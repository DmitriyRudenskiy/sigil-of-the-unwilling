---
description: "Connect the world's cities to the playable game: captured villages become real cities, the player can enter and manage them (buildings, FIDSI, citizens, garrison), terrain drives tile yields, city income flows to the player, and followers can be recruited into the hero's party."
---

## Why

The deepest system in the project is invisible in the playable game. The city/economy layer — FIDSI, zoning, production chains, demographics with citizen needs (`city/`, ~1820 lines, plus `world/City.gd`, `world/CityManager.gd`, `CityTurnProcessor`) — runs every turn in the background, but the player can neither enter nor manage a single city in the main game.

Grounding facts:
- The world contains **exactly one City object**: the capital «Перворечье», created in `WorldBootstrap.gd:192-200`. Everything else (the whole economy stack) serves that one background city.
- Villages (`MapSpawner.place_villages`) are **never turned into City objects**. Capturing a village only records a world delta and adds a text label «Деревня (x, y)» to the UI (`WorldEventRouter._on_village` → `WorldInteractionController.capture_village_at`).
- The only playable city UI, `scenes/CityArena.tscn`, is a **standalone sandbox** with its own model (`CityArenaModel.new_game`, `ArenaBalance`), reachable only from the main menu (`MainMenu.gd:186`). It is not bound to the world.
- `CityManager.set_tile_yield_provider` is a **stub**: it returns a constant `{food: 5.0, industry: 5.0, dust: 0.0, science: 0.0, influence: 0.0}` (`WorldBootstrap.gd:203-206`). The economy does not look at real terrain.
- The player has no base, no income, no recruitment, and nothing to defend.

This change makes the city layer playable: villages become cities, the player enters and manages them, terrain drives yields, income flows to the player, and cities become the source of the hero's followers (the bridge into `succession-sigil`).

## Proposed Change

1. **Village → city.** Capturing a village MUST create a `City` object (level 1) centered on the village cell and register it in `CityManager`. The capital keeps its existing bootstrap path.
2. **In-world city screen.** When the hero is on a city cell, a city management screen opens **bound to the real world City** (not a sandbox model): ring map, building palette, worker assignment, upgrade — reusing the rendering/action logic of `CityArenaView` extracted into a reusable `CityScreen` component. CityArena (sandbox) keeps working unchanged.
3. **Real tile yields.** Replace the stub yield provider with `data/CityYieldTable.gd`: biome/terrain → FIDSI per ring cell, computed from `MapModel` terrain (grass → food, rock → industry, etc.).
4. **Income to the player.** Each owned city contributes income (royalties from the FIDSI surplus) to the player's strategic resources at end-of-turn, visible in the `ResourceBar`.
5. **Recruitment and garrison.** The player can recruit a named follower (an individual with traits and a path, not a counter) from a city's population into the hero's party, and assign part of the population as a garrison. Followers are the successor pool for `succession-sigil`.
6. **Ownership.** Cities have an owner (player / enemy / none). `WorldStateDelta` and `SaveData` record ownership so enemy AI (`enemy-world-ai`) and endgame (`endgame-conditions`) can act on it.

## Scope

- **In:** village→city creation, `CityScreen` bound to world state, real tile-yield table, income flow, follower recruitment + garrison, ownership in delta/save, unit tests, one new auto-game scenario («develop a city»).
- **Out:** full CityArena building parity (keep the existing set), multi-shard expansion (`astral-macro`), diplomacy, new city art (reuse existing ring rendering), re-derivation of the FIDSI formulas themselves.
