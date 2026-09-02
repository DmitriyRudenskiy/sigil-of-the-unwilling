## Context

- AdventureUI right column: `ArmyPanel`, `ResourcePanel`, `StrategicPanel`, `SkillsPanel`, `ToolsPanel` — no hero-condition or legend panel. `InfoPanel` shows date/time/status only.
- The hero has no needs: `Character.NEED_KEYS` (`hunger/rest/social/belief`) are citizen-only (`demographics/Character.gd`, decayed by `DemographicTurnProcessor`). The hero's only state surfaced anywhere is the morale battle modifier.
- Glory: `CityManager.add_glory(amount, reason)` — a number, no reader, no UI.
- Identity events do not exist yet: `inspiration-core` (inspiration/burnout), `succession-sigil` (death, successor), `race-class-matrix` (race×class) define the data this cycle presents.
- Animation: `UIAnimator` exists (used by MainMenu/Settings) — reusable for the death sequence.
- Save: `SaveData v3` — a `chronicle` array is additive.
- `GameEventBus` is the established event surface (`battle_result`, `date_changed`, `game_ended` from `endgame-conditions`).

## Design

**1. `ui/HeroStatusPanel.gd`.** A new panel in the AdventureUI right column (toggleable from `ToolsPanel`, like the other screens). Sections:
- **Condition**: needs bars. After `inspiration-core` lands, the inspiration/burnout meter; until then, the panel renders only sections whose data exists (graceful degradation — a requirement).
- **Stats**: level, XP, morale, key skills (from the existing skill data).
- **Followers**: list (name, path, traits) from `hero.followers` (from `city-in-world`); empty list until then.
Read-only; it renders state it is given, so it never blocks earlier cycles.

**2. `ui/DeathSequence.tscn`.** A full-screen `CanvasLayer` overlay in `World.tscn` (same overlay rationale as `CityScreen`/`GameOverScreen`). Triggered by the `succession-sigil` hero-death event (and, as a fallback, `endgame-conditions` defeat). Beats: (a) the fall — hero name + «цикл оборвался/продолжится»; (b) run summary grid (turns, cities, glory, battles); (c) if a successor exists — successor card (name, race×class, inherited sigil) + «Знак переходит» button that invokes the succession flow; else a «В меню» button. Animation via `UIAnimator`; input blocked while open.

**3. `core/Chronicle.gd`.** A `GenerationEntry` (hero name, race×class, path, start/end month, cities, glory, battles, outcome) appended on `cycle_ended` (succession) and on `game_ended` (final run). `ui/ChronicleScreen.tscn` lists entries newest-first, reachable from the main menu («Летопись») and after death. Serialized in the save (`chronicle` array). The chronicle is the project's memory across cycles — and, later, across shards (`astral-macro`).

**4. Glory meter.** A small bar/label in `AdventureUI` (near `InfoPanel`): current glory → threshold (from `endgame-conditions` settings). Updates on `glory_changed`.

**Grounding facts (files):**
- `game/ui/AdventureUI.gd` (right-column panels, `ToolsPanel` toggle pattern)
- `game/ui/InfoPanel.gd` (date/time/status)
- `game/demographics/Character.gd` (`NEED_KEYS` — citizen-only)
- `game/world/CityManager.gd` (`add_glory`)
- `game/ui/UIAnimator.gd` (animation)
- `game/core/GameEventBus.gd` (`battle_result`, `game_ended`)
- `game/core/SaveData.gd` (v3)
