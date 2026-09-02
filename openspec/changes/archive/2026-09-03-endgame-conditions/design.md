## Context

- `core/GameSession.gd` is minimal: `run_seed: int`, `rng: RandomNumberGenerator`. No game state, no win/lose.
- Battle loss today = retreat: `WorldBattleCoordinator._restore_hero_after_retreat` restores the hero; the game always continues.
- No victory/defeat code exists: a grep for `victory|game_over|defeat` (non-test) yields only a reputation `+10` for winning a battle.
- Glory exists as a number: `CityManager.add_glory(amount, reason)` — but nothing reads it for a goal.
- Season/turn infrastructure: `TurnScheduler` phase cascade, `CityManager.on_turn_ended(month)`, `GameEventBus` (e.g. `relocation_completed`, `battle_result`, `date_changed`).
- City ownership does not exist yet (introduced by `city-in-world`); today the capital is implicitly the player's.
- Save: `SaveData v3` (`core/SaveData.gd`).

## Design

**1. `GameSession` state.** Add `state: GameState` (`RUNNING`/`VICTORY`/`DEFEAT`, default `RUNNING`) and `end_reason: String`. Persist in the save (additive field). A terminal state is sticky: once set, world input is disabled.

**2. `systems/EndgameController.gd`.** A node registered by `WorldBootstrap` that subscribes to `GameEventBus`:
- `battle_result` (hero lost) → check successor eligibility (stub until `succession-sigil`: no successor → defeat).
- `city_lost` / capital ownership change (from `city-in-world`) → no player cities → defeat.
- `glory_changed` (new signal emitted by `CityManager.add_glory`) → glory ≥ `GameSettings.ENDGAME_GlORY_VICTORY` → victory.
- `faction_eliminated` (from `enemy-world-ai`; no-op until it exists) → all hostile factions gone → victory.
First terminal condition wins; it sets `GameSession.state`, builds the summary, and emits `GameEventBus.game_ended`.

**3. Run summary struct.** `EndgameSummary`: turns, months/season, cities owned, glory, battles won/lost, heroes lived (generations — 1 until chronicle lands), end reason. Plain `Dictionary` for save/UI simplicity.

**4. `scenes/GameOverScreen.tscn`.** Full-screen overlay (CanvasLayer in `World.tscn`, not a scene switch — same rationale as `CityScreen` in `city-in-world`): result title («Путь завершён» / «Знак угас»), reason line, summary grid, two buttons: «В главное меню» and (on defeat with successor) «Продолжить как преемник» — the latter delegates to `succession-sigil`'s succession flow; this cycle only leaves the hook. While open, `HeroMovementController` input and end-turn are blocked.

**5. `GameSettings` thresholds.** `ENDGAME_GlORY_VICTORY: int` (default from a balance constant), `ENDGAME_DOMINATION_ENABLED: bool` (default true). Tunable without code changes.

**Grounding facts (files):**
- `game/core/GameSession.gd` (`run_seed`, `rng` only)
- `game/world/WorldBattleCoordinator.gd` (`_restore_hero_after_retreat` — retreat restores the hero)
- `game/world/CityManager.gd` (`add_glory`)
- `game/core/GameEventBus.gd` (`battle_result`, `date_changed`, `relocation_completed`)
- `game/core/GameSettings.gd` (central constants)
- `game/core/SaveData.gd` (v3)
