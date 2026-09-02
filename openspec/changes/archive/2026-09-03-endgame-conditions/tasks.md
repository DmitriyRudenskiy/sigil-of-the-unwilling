## 1. Audit (baseline)
- [x] Confirm no existing terminal state (`grep -rn "game_over\|victory\|defeat" game/ --include="*.gd" | grep -v test`).
- [x] List `GameEventBus` signals usable for endgame triggers (`battle_result`, `date_changed`, …).

## 2. Game state + session
- [x] `GameSession`: add `state: GameState` + `end_reason: String`; persist (additive save field). → SaveData v5 (`_migrate_v4_to_v5`, roundtrip).
- [x] Sticky terminal state: world input disabled when not `RUNNING`. → `WorldController`: sticky gate, первый терминальный исход побеждает.

## 3. `EndgameController`
- [x] Create `systems/EndgameController.gd`, register in `WorldBootstrap`.
- [x] Defeat: hero lost battle + no eligible successor (stub rule until `succession-sigil`). → eligible successor = `hero.followers` непусто (succession-хук `hero_successor` реинит героя).
- [x] Defeat: player owns no cities (capital-only until `city-in-world` lands). → `enemy_village_captured` + fallback `turn_ended` (enemy-фаза после `turn_ended`).
- [x] Victory: glory ≥ `GameSettings.ENDGAME_GlORY_VICTORY` (emit `glory_changed` from `CityManager.add_glory`).
- [x] Victory hook: all hostile factions eliminated (consume `faction_eliminated`; inert until `enemy-world-ai`). → доминация через `enemy_stack_defeated`: победа при уничтожении всех вражеских стаков.
- [x] First condition wins; build `EndgameSummary`; emit `GameEventBus.game_ended`.

## 4. End screen
- [x] ~~`scenes/GameOverScreen.tscn` overlay~~ → code-built `scripts/ui/GameOverScreen.gd` (CanvasLayer: result title, reason, summary grid). Отклонение: UI-конвенция «большие экраны — code-built controls», а не `.tscn`; в Godot 4.7 рантайм-ноды без явного `.name` получают авто-имена `@Panel@N`, `get_node` по простым именам не работает.
- [x] Buttons: «В главное меню»; defeat-with-successor → «Продолжить как преемник» (hook only). → преемник: новый hero с полным войском, sticky state сбрасывается на RUNNING.
- [x] Block hero input + end-turn while open.

## 5. Settings
- [x] `GameSettings`: `ENDGAME_GlORY_VICTORY`, `ENDGAME_DOMINATION_ENABLED` with balance defaults.

## 6. Tests + scenario + gate
- [x] Unit tests: each trigger flips state once; sticky; summary fields populated. → `tests/test_endgame.gd`: 15 тестов (11 flow + 4 data).
- [x] Auto-game scenario: force a defeat path (hero loses, no successor) → assert `game_ended` + screen shown. → `scenario_11_endgame.py`: deterministic defeat через test-only socket-hook `hero_died`.
- [x] Full suite + scenarios green; re-run the agent-run-and-debug gate; commit. → suite 5306 passed / 15 ObjectDB (базовый шум ≤20 allowlist, 0 RID); operability gate: **CLEAN (ошибок: 0, предупреждений: 0)**.
