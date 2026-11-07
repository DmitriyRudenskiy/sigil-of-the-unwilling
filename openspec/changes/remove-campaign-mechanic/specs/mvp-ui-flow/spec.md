## MODIFIED Requirements

### Requirement: Eight MVP screens
The MVP SHALL have 8 screens (K-M8): pregame, menu, map, city, battle, party, chronicle, settings, plus a tutorial overlay (first turns, not a scene). "Report" as a separate screen SHALL be deprecated (battle results are the battle screen's finale; turn events are the chronicle). The MAP screen SHALL be the adventure screen of the world layer — world map, hero, army, resources, minimap. The CITY screen SHALL be a scene of its own, hosted independently of the map screen; a campaign screen SHALL NOT be among the eight, and the city SHALL NOT be a layer of a campaign HUD.

#### Scenario: No separate report screen
- **WHEN** a battle ends
- **THEN** the results are shown on the battle screen (finale)
- **AND** there is no separate "Report" screen

#### Scenario: City is a scene, not a HUD layer
- **WHEN** the player opens the city from the map
- **THEN** the city scene is shown
- **AND** closing it returns the player to the map screen with the map state intact

#### Scenario: No campaign screen in the carrier set
- **WHEN** the set of screen carriers is enumerated for verification
- **THEN** it contains the adventure screen and the city scene
- **AND** it contains no campaign screen

### Requirement: Navigation state machine
Navigation SHALL follow the state machine PREGAME → MENU → MAP → (CITY/BATTLE/PARTY/CHRONICLE/SETTINGS) → ... The battle screen SHALL return to MAP via "Continue" (K-M8). MAP → CHRONICLE SHALL be available anytime. * → TUTORIAL SHALL trigger on first entry to a screen (once). After the pregame flow the game SHALL enter MAP directly, without an intermediate campaign screen, and every screen of the graph SHALL be reachable from MAP and return to MAP.

#### Scenario: Battle returns to map
- **WHEN** the player clicks "Continue" on the battle finale
- **THEN** the navigation returns to MAP
- **AND** there is no "close to nowhere" option

#### Scenario: Tutorial on first entry
- **WHEN** the player enters a screen for the first time
- **THEN** the tutorial overlay appears once
- **AND** it does not reappear on subsequent entries

#### Scenario: Pregame enters the map directly
- **WHEN** the pregame flow ends
- **THEN** the current screen is MAP
- **AND** no campaign screen appears in the transition history

### Requirement: NEW GAME FLOW ENDS ON THE ADVENTURE SCREEN
The new-game flow SHALL be `menu → character creation → sign choice → adventure screen`. The
adventure screen SHALL be the entry scene `res://scenes/ui/adventure_ui.tscn`, and it SHALL carry
the world it shows (hero, hex map, cities) — opening it alone SHALL produce a playable map, not a
panel of buttons. The carrier scenes `res://scenes/ui/world_ui.tscn` and
`res://scenes/archive/world.tscn` SHALL be retired, and `res://scenes/main/main.tscn` SHALL NOT
appear anywhere in the flow.

#### Scenario: Sign choice hands over to the adventure screen
- **WHEN** the player picks a sign
- **THEN** `res://scenes/ui/adventure_ui.tscn` becomes the current scene
- **AND** the sign is visible in the hero state

#### Scenario: The adventure screen boots a playable world
- **WHEN** the adventure screen is entered from the sign choice
- **THEN** the hero created in the constructor stands on the hex map
- **AND** a move, a city entry and a battle are all reachable from that screen
