# mvp-ui-flow Specification

## Purpose
Канон UI post-pivot (07-ui-ux): 8 экранов MVP (K-M8), SM навигации, туториал-оверлей, панель целей 3 первых дней (M3), инварианты UI (≤2 клика до причины, правила D&D видны без подсказок). Источник: GDD 07-ui-ux, MVP-scope (UI), K-канон (K-M8, K-M15), решения (Q18, M3, D4, C-3, C-10).
## Requirements
### Requirement: Eight MVP screens
The MVP SHALL have 8 screens (K-M8): pregame, menu, map, city, battle, party, chronicle, settings, plus a tutorial overlay (first turns, not a scene). "Report" as a separate screen SHALL be deprecated (battle results are the battle screen's finale; turn events are the chronicle).

#### Scenario: No separate report screen
- **WHEN** a battle ends
- **THEN** the results are shown on the battle screen (finale)
- **AND** there is no separate "Report" screen

### Requirement: Navigation state machine
Navigation SHALL follow the state machine PREGAME → MENU → MAP → (CITY/BATTLE/PARTY/CHRONICLE/SETTINGS) → ... The battle screen SHALL return to MAP via "Continue" (K-M8). MAP → CHRONICLE SHALL be available anytime. * → TUTORIAL SHALL trigger on first entry to a screen (once).

#### Scenario: Battle returns to map
- **WHEN** the player clicks "Continue" on the battle finale
- **THEN** the navigation returns to MAP
- **AND** there is no "close to nowhere" option

#### Scenario: Tutorial on first entry
- **WHEN** the player enters a screen for the first time
- **THEN** the tutorial overlay appears once
- **AND** it does not reappear on subsequent entries

### Requirement: Three-day goal panel
The MVP SHALL have a 3-day goal panel (M3): day 1 — build a farm and barracks; day 2 — train a warrior (K-M15; training, not hiring — Q18); day 3 — visit the ruins. The panel SHALL be visible until all goals are completed. TTFD covers the first action.

#### Scenario: Goal panel visibility
- **WHEN** the player has completed all 3-day goals
- **THEN** the goal panel is hidden
- **AND** the goals are not re-shown

#### Scenario: Day 2 goal
- **WHEN** the player is on day 2
- **THEN** the goal is "train a warrior"
- **AND** the goal references training, not hiring (Q18)

### Requirement: UI invariants
Any modifier SHALL be reachable to its cause in <= 2 clicks (pillar 1). In battle, all D&D rules affecting the turn SHALL be visible on screen without tooltips (help via key).

#### Scenario: Modifier to cause
- **WHEN** the player sees a modifier on a screen
- **THEN** the cause is reachable in <= 2 clicks
- **AND** no tooltip is required for the cause

#### Scenario: Battle rules visible
- **WHEN** the player is in battle
- **THEN** all D&D rules affecting the turn are visible on screen
- **AND** no tooltip is required

### Requirement: Low resolution support
The MVP SHALL support 1280x720 minimum resolution. The grid SHALL scale; main screens SHALL have no scroll. The battle field at 720p SHALL use scale x0.8 (C-10: field size — 07-balance#4, "8x8-12x12" deprecated).

#### Scenario: 720p scaling
- **WHEN** the game runs at 1280x720
- **THEN** the grid scales
- **AND** main screens have no scroll

### Requirement: Party screen slot hint
The party screen SHALL show "what frees a slot" (link to battle/death) when the training queue is empty and the party is full, not emptiness.

#### Scenario: Full party hint
- **WHEN** the training queue is empty and the party is full
- **THEN** the party screen shows "what frees a slot"
- **AND** the hint links to battle/death

