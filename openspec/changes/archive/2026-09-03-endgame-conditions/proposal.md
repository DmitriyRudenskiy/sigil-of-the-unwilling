---
description: "Give the game an ending: defeat (hero dies without an eligible successor, or the player loses all cities) and victory (completing the Path via a glory threshold, or eliminating all hostile factions), a terminal game state, and an end screen with a run summary."
---

## Why

The game has **no victory or defeat conditions anywhere**. A grep for `victory|game_over|defeat|побед|поражен` across `game/` (excluding tests) finds only a `+10` reputation bonus for winning a battle. Consequences:

- The player can never truly lose: a lost battle just retreats (`WorldBattleCoordinator._restore_hero_after_retreat` — the hero is restored, the game continues).
- There is no goal: the legend is endless with no endpoint, so there is no reason to play one more turn.
- The identity cycles make this worse rather than better: `succession-sigil` makes death *real*, but if death cannot end the run, it cannot matter.

The owner's own framing for the project is "each cycle passes on the sign and continues the path" — a cycle needs an end. This change adds the ends.

## Proposed Change

1. **Game state machine.** Extend `GameSession` (currently just `run_seed` + `rng`) with a `GameState` enum (`RUNNING`, `VICTORY`, `DEFEAT`) and a reason string.
2. **Defeat conditions.**
   - **Unsuccessored death**: the hero dies in battle and no eligible successor exists (per `succession-sigil` rules) → `DEFEAT`.
   - **Total collapse**: the player owns no cities (capital falls) → `DEFEAT`.
3. **Victory conditions** (configurable in `GameSettings`):
   - **Path completion**: glory ≥ threshold → `VICTORY` ("the Path is completed").
   - **Domination** (secondary): all hostile enemy factions on the shard eliminated → `VICTORY`.
4. **End screen.** New `scenes/GameOverScreen.tscn`: result, reason, and a run summary (turns, cities, glory, battles, generations). The world is frozen (input disabled) until the player returns to the main menu.
5. **Post-game hook.** On end, emit `GameEventBus.game_ended(result, reason, summary)` — the `legend-chronicle` cycle consumes this to append a generation entry to the chronicle.

## Scope

- **In:** `EndgameController` (event-driven checks), `GameSession` state, defeat/victory conditions + thresholds in `GameSettings`, `GameOverScreen`, `game_ended` event + summary struct, unit tests, one auto-game scenario (forced defeat path).
- **Out:** the death/successor rules themselves (`succession-sigil`), faction elimination mechanics (`enemy-world-ai` — this cycle only consumes the "faction eliminated" event), multiple-endings content, post-victory New Game+.

## Dependencies

- `succession-sigil` (death + successor eligibility) — until it lands, the defeat-by-death check uses a stub rule (any death = defeat).
- `city-in-world` (city ownership) — until it lands, collapse checks only the capital.
