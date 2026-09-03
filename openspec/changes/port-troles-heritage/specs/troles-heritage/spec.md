---
description: "Requirements for the ported start screen, hero constructor, and location-aware audio system, including graceful degradation and the relocation of dev/sandbox entries into settings."
---

## ADDED Requirements

### Requirement: The start screen shows the throne-room art and exactly four core actions
The main menu **MUST** use the ported throne-room background art (`res://assets/ui/main_menu_bg.jpeg`, aspect-covered) and **MUST** offer exactly four core buttons: «Новая игра», «Загрузить», «Настройки», «Выход». The old «Кампания недоступна» lock panel **MUST NOT** be present. Buttons **MUST** use the ported dark-gold styling.

#### Scenario: Menu renders
- **Given** the player launches the game
- **When** the main menu scene is ready
- **Then** the throne-room art is visible and exactly the four core buttons are present (no lock panel)

#### Scenario: Loading without a save
- **Given** no save file exists
- **When** the player presses «Загрузить»
- **Then** a failure feedback is shown and the player stays in the menu

### Requirement: The menu is compact; dev/sandbox entries live in settings
The three sandbox entries (city arena, hero model: knight, hero model: mage) **MUST** be reachable from the settings screen in a dedicated sandbox/dev section and **MUST NOT** be visible in the main menu. Selecting one **MUST** close the settings screen and open the same target as before.

#### Scenario: Sandbox entry from settings
- **Given** the player opens settings
- **When** the player presses «Модель: Маг» in the sandbox section
- **Then** settings closes and the mage model window opens

### Requirement: New games start with the hero constructor
«Новая игра» **MUST** open the character creation scene. The constructor **MUST** allow choosing name, sex, race, class, culture, and background from the ported data registries and **MUST** show a summary with the derived hero stats. Confirming **MUST** start a new world where the hero carries the chosen name, stats, and race/class/culture/background metadata; cancelling **MUST** return to the main menu.

#### Scenario: Create a hero and enter the world
- **Given** the player is in the constructor with a filled-in build
- **When** the player confirms creation
- **Then** the world scene starts and the hero has the chosen name and the deterministic stats derived from the build

#### Scenario: Cancel returns to the menu
- **Given** the player is in the constructor
- **When** the player presses back/cancel
- **Then** the main menu is shown and no world is started

#### Scenario: Constructor is data-driven
- **Given** the race/class/culture data lives in `hero_races.gd`, `hero_classes.gd`, `hero_cultures.gd`
- **When** the data content is replaced (e.g. by the race-class matrix)
- **Then** the constructor UI keeps working without code changes

### Requirement: Hero identity persists
The hero save dictionary **MUST** persist `hero_name`, `stats`, `hero_race`, `hero_class`, `hero_culture`, `hero_background`. Saves created before this change (without the new fields) **MUST** still load, with the new fields defaulting.

#### Scenario: Old save loads
- **Given** a save file without the new identity fields
- **When** it is loaded
- **Then** the hero deserializes successfully with default identity metadata

#### Scenario: New save round-trips identity
- **Given** a hero created with race/class/culture/background
- **When** the game is saved and reloaded
- **Then** all four identity fields survive the round-trip

### Requirement: The game has a music pack and location-aware music
The project **MUST** ship the ported music pack (13 groups, 43 tracks: `<Group>_Main` + variations) and the 6 SFX (ui_click, ui_hover, sword_hit, spell_cast, victory, defeat). `SoundManager` **MUST** provide location music (`play_location_music(location)`) that picks Main or a variation **without repeating the previous pick for that location** (pick order seedable for tests), crossfades between tracks on location change, and **MUST** apply user volumes from `Settings` live. Menu, world (biome-aware), city, and battle locations **MUST** play distinct music.

#### Scenario: Menu music
- **Given** the main menu is ready
- **When** audio is available
- **Then** the menu location track is playing

#### Scenario: World biome music
- **Given** the world biome is snow
- **When** the world scene enters
- **Then** the snow biome music group plays instead of the default world group

#### Scenario: Variation rotation
- **Given** a seeded rotation state for a location
- **When** `play_location_music` is called repeatedly
- **Then** the same track is never picked twice in a row

#### Scenario: Battle crossfade
- **Given** world music is playing
- **When** a battle starts
- **Then** the battle track fades in while the world track fades out

### Requirement: Core actions have SFX
Menu hover/click, melee battle hits, spell casts, and battle outcome (victory/defeat) **MUST** play SFX through `SoundManager` (named SFX registry, pooled players).

#### Scenario: Menu click
- **Given** the main menu is visible
- **When** the player presses a button
- **Then** the click SFX plays (and the hover SFX plays on hover)

#### Scenario: Battle outcome
- **Given** a battle ends in victory
- **When** the result is shown
- **Then** the victory SFX/track plays (defeat equivalent on loss)

### Requirement: Audio degrades gracefully
Every audio play call **MUST** be safe when the asset is missing/unimported or the runtime is headless: log (trace/warn) and no-op — never crash. Volume changes **MUST** apply live to the audio buses.

#### Scenario: Missing asset
- **Given** a play call for a path/name with no file
- **When** it is invoked (including under headless)
- **Then** no error is raised and the game continues
