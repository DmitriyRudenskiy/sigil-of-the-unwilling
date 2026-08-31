# audio Specification

## Purpose
Defines the audio experience contract: per-scene looping music, SFX for core actions, user-controlled volume and mute with persistence, and graceful degradation when audio assets are missing or the run is headless.

## Requirements

### Requirement: The game has music
A looping music track **MUST** play in the main menu, the world, and battle, and **MUST** change on scene entry.

#### Scenario: World music starts
- **Given** the player enters the world scene
- **When** the scene is ready
- **Then** the world track is playing (looping)

#### Scenario: Music switches
- **Given** world music is playing
- **When** a battle starts
- **Then** the battle track plays

### Requirement: Core actions have SFX
UI interaction, hero movement, village capture, resource collection, and battle actions (hit, spell) **MUST** play SFX through `SoundManager`.

#### Scenario: Capture SFX
- **Given** the hero captures a village
- **When** the capture resolves
- **Then** the capture SFX plays

### Requirement: Volume is user-controlled
Master, music, and SFX volume plus a mute toggle **MUST** be available in the settings screen, applied live, and persisted.

#### Scenario: Live volume
- **Given** the settings screen
- **When** the player lowers the music slider
- **Then** the music bus volume changes immediately and the value persists after save/load

### Requirement: Missing audio degrades gracefully
A missing or unimported audio asset **MUST** log and no-op — it **MUST NOT** crash the game or the headless test runner.

#### Scenario: Headless safety
- **Given** a headless run
- **When** `play_sfx`/`play_music` is called with a missing path
- **Then** it logs and continues (no crash)
