## MODIFIED Requirements

### Requirement: Pregame flow before turn 1
The pregame flow SHALL occur before turn 1 and SHALL consist of 6 steps: constructor → sign → globe → cities → party → training (Q18, author 2026-10-02). When the implemented slice of the flow ends — today that is after the sign choice — the game SHALL present the adventure screen (the world map with the hero), and SHALL NOT present a campaign screen: the campaign mechanic was removed from the plan on 2026-11-05, and its return is blocked by `campaign-lockout`.

#### Scenario: Pregame sequence
- **WHEN** the player starts a new game
- **THEN** the steps are presented in order: constructor, sign, globe, cities, party, training
- **AND** turn 1 does not start until all steps are complete

#### Scenario: Landing after the sign
- **WHEN** the player confirms a sign in the last implemented pregame step
- **THEN** the adventure screen `res://scenes/ui/adventure_ui.tscn` is shown with the created
  hero on the world map
- **AND** no campaign screen is loaded
- **AND** the scene carries the world with it: the hero can take a turn on the hex map right away

#### Scenario: Hero and sign survive the transition
- **WHEN** the adventure screen appears after the pregame flow
- **THEN** the hero on the map is the one created in the constructor
- **AND** the chosen sign is kept in game state and available to any carrier that displays it
