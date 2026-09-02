---
description: "Make the world live: after the player's turn, enemy stacks act on their own turn — pick goals (villages, resources, the hero), path and move, capture villages, fight on contact, and regrow over time — with UI threat signals."
---

## Why

The world is **dead**. Enemy stacks are placed once (`MapSpawner.place_enemies` with a seeded RNG) and never move. The only enemy behavior in the whole game is reactive: `WorldEventRouter` checks contact **when the hero moves onto an enemy** (`check_enemy_contact`). There is no enemy turn, no aggression, no growth, no pressure.

Consequences:
- Nothing threatens the player, so there is nothing to defend — the core 4X tension is absent.
- Captured villages (`city-in-world`) are safe forever; the "base" fantasy is unopposed.
- Most of the threat machinery (enemy auras, `WorldStateDelta` enemy records, battle role swap) is dormant.

This change adds an enemy turn so the map is a place with stakes, not an obstacle field.

## Proposed Change

1. **Enemy turn phase.** After the player's end-of-turn, an `EnemyTurnProcessor` runs each alive hostile stack: pick a goal, path, and move up to its movement points (MP).
2. **Goal selection.** Each stack picks a goal by weighted priority: player villages > resource nodes > the hero, within an aggro radius; stack traits modify weights (raiders prefer villages, seekers prefer the hero).
3. **Village capture.** An enemy stack that reaches a player village **MUST** be able to capture it (ownership flips to `enemy`), consuming the turn's stack action.
4. **Combat on contact.** An enemy moving onto the hero's cell triggers the existing battle with roles swapped (enemy attacker). Player loss follows the existing retreat/death rules.
5. **Growth.** Per season, defeated stacks may respawn (weakened) after N turns and new stacks spawn up to `GameSettings.MAP_ENEMY_COUNT`, creating ongoing pressure. Growth state is saved.
6. **Threat signals.** The UI surfaces nearby enemy movement (markers on the minimap + a status line) so the world feels alive before contact.

## Scope

- **In:** `EnemyTurnProcessor` (registered in `TurnScheduler`), goal table (`data/EnemyAIProfile.gd`), movement via `HexUtils` pathfinding, capture + contact hooks, seasonal growth, minimap threat markers, unit tests, one auto-game scenario (enemy reaches a village).
- **Out:** per-faction strategic goals and diplomacy (`astral-macro`), unit-level tactical AI inside battles (already exists), enemy economy/buildings, difficulty scaling beyond the base cap.

## Dependencies

- `city-in-world` (city ownership) — until it lands, "capture" flips a `village_cells` ownership flag in `MapModel`/delta.
- `endgame-conditions` consumes the `faction_eliminated` event this cycle will eventually define (no dependency for MVP: a single hostile "faction" = all stacks).
