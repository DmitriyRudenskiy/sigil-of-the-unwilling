## Context

Source project: `/Users/user/GAMES_TROLES` — Godot 4.7, GL Compatibility (identical to ours), Russian UI, built for "Sigil of the Unwilling".

**Start screen (source)**
- `game/scenes/ui/main_menu/MainMenu.tscn` — root Control + `MenuButtons` VBox (anchor_left=1.0, anchor_top=0.52, offset_left=-380, offset_right=-60, separation 16) with 6 buttons: NewGame, Continue, Load, Settings, Arena (⚔), Quit.
- `game/scenes/ui/main_menu/MainMenu.gd` — builds `main_menu_bg.jpeg` background (`STRETCH_KEEP_ASPECT_COVERED`), applies dark-gold `StyleBoxFlat` per state (normal `#2a2118`, hover `#3a2d1f`, pressed `#1f1811`, corner 10, gold border `#8b7355`, font 22), hover SFX `ui_hover`, click SFX `ui_click`, menu music `AudioManager.play_location_music("menu")`.
- `game/assets/ui/main_menu_bg.jpeg` — 1920×1080 throne room, title "SIGIL OF THE UNWILLING", sigil behind the throne. Made for this game.

**Start screen (ours)**
- `game/scenes/MainMenu.tscn` — bare Control + script; `game/ui/MainMenu.gd` builds everything in code: background (probes `res://assets/ui/main_menu_bg.png`, `res://assets/ui/throne.png`, then raw dir by name; falls back to a generated gradient), `RightColumn` with a «Кампания недоступна» lock panel + **7 buttons**: Новая игра, Загрузить, 🏙 Арена города, 🗡 Модель: Рыцарь, ✨ Модель: Маг, Настройки, Выход. `_on_new_game()` jumps straight to `World.tscn`. Headless guard for `--test-server`.
- No audio anywhere; no character creation; hero defaults to `hero_name = "Darkstorn"` (`game/entities/HeroController.gd:23`) with `stats = {attack:0, defense:0, spell_power:4, knowledge:2}`.

**Constructor (source)**
- `game/ui/character_creation/character_creation.tscn` + `CharacterCreationUI.gd` — panels: name + sex, race (with subraces), class (+ abilities), culture (+ backgrounds), summary/preview; «Создать персонажа» → `GameManager.load_character()` (saves `CharacterData` resource to `user://characters/`).
- Data: `game/data/modules/races.gd` (6 races: human, elf, dwarf, orc, tiefling, minotaur — each with subraces, PoE2-flavored ability bonuses, traits), `classes.gd` (11 classes with attributes/abilities), `cultures.gd` (10 cultures + 6 backgrounds), `game/data/resources/CharacterData.gd` (Resource: name, sex, race, subrace, class, subclass, culture, background, ability scores, helpers).
- Localization via `game/autoload/Loc.gd` (RU/EN dictionaries) — the source UI strings are English + Loc RU translation.

**Audio (source)**
- `game/audio/music/` — 43 mp3, ~118.5 MB. 13 groups `<Group>_Main.mp3` + `<Group>_Var1..N.mp3`: Sands_Techno, Silence_Lofi, Arena_Industrial, Meadow_House, WarDrums_HardTechno, Confrontation_Industrial, Conquest_Industrial, Fanfare_Epic, Peaks_Ambient, Fury_Industrial, Grove_Ambient, Dawn_Cinematic, Tavern_FolkElectronic.
- `game/audio/sfx/` — 6 wav (140 KB): ui_click, ui_hover, sword_hit, spell_cast, victory, defeat.
- `game/data/modules/music_tracks.gd` — `MusicTracks.get_tracks_for_location(location) -> Array[String]`, `get_biome_music(biome)`, `BATTLE_LOCATIONS` set.
- `game/autoload/AudioManager.gd` — SFX name registry (with pool `MAX_SIMULTANEOUS_SFX = 16`), `play_location_music(location)` with per-location variation history (`last_variation`, never repeats the previous pick), A/B crossfade players, buses (Master/Music/SFX/UI), UI sound hook, volume persisted to its own `user://audio_settings.json` (NOT ported — our `core/Settings.gd` already persists `master_volume`/`music_volume`/`sfx_volume`/`is_muted` with load/save and `SettingsScreen` already exposes the sliders).

**Audio (ours)**
- `game/core/SoundManager.gd` — autoload; `play_sfx(path)`, `play_music(path)`, path-cached streams, pool of 8 SFX players on bus SFX, one music player on bus Music, mute on `mute` action; headless guard in `_ready`. No call sites yet (only tests).
- `game/default_bus_layout.tres` — Master, SFX, Music (no UI bus).
- Zero audio assets in `game/assets/` (`assets/audio/` is an empty dir).

**Bootstrap (ours)**
- `game/world/WorldBootstrap.gd` — `_create_hero()` does `HeroController.new()` (line 125-128); `_init_hero()` deserializes only when a save was loaded; `WorldPersistence.pending_save` is the existing static handoff pattern.
- `game/entities/HeroController.gd` — `serialize()`/`deserialize()` around line 314/333 persist `hero_name` and `stats` in the `SaveData.hero` dict.

## Design

**1. Start screen.**
- Copy `main_menu_bg.jpeg` → `game/assets/ui/main_menu_bg.jpeg`. Extend `MainMenu._find_bg()` path list with the `.jpeg` name (keep the existing fallbacks).
- `game/ui/MainMenu.gd` stays code-built (our pattern; keep the `--test-server` guard, `UIAnimator`, version label) but restyled with the ported dark-gold `StyleBoxFlat` values, and the button set becomes exactly: «Новая игра», «Загрузить», «Настройки», «Выход». Delete the lock panel builder and its flash helper.
- «Новая игра» → `get_tree().change_scene_to_file("res://scenes/CharacterCreation.tscn")`.
- `game/ui/SettingsScreen.gd`: new section «🧪 Песочница / Dev» with 3 buttons («Арена города», «Модель: Рыцарь», «Модель: Маг») reusing the existing callbacks (scene change to `CityArena.tscn`; opening `ArtifactInventoryScreen` + `HeroModelFactory` as today). Opening a sandbox target from inside Settings: close the screen first, then run the callback.
- Menu feedback: hover → `ui_hover`, press → `ui_click` SFX + `play_location_music("menu")` on scene ready.

**2. Hero constructor.**
- Files: `game/scenes/CharacterCreation.tscn`, `game/ui/CharacterCreationUI.gd` (port, drop the `GameManager`/`Loc` autoload dependencies — inline the RU strings or keep Loc as a later candidate), `game/data/hero_races.gd`, `game/data/hero_classes.gd`, `game/data/hero_cultures.gd` (static data; content = ported tables), `game/data/HeroBuildProfile.gd` (Resource: `name, sex, race, subrace, class, culture, background`, `abilities: Dictionary`, `get_stats() -> Dictionary`).
- Ability→stat mapping (documented, deterministic): `attack = 5 + 2*Might + 1*Dexterity`, `defense = 3 + 2*Constitution + 1*Perception`, `spell_power = 3 + 2*Intellect + 1*Resolve`, `knowledge = 2 + 2*Perception + 1*Intellect` (base values chosen so a default-ish build ≈ today's `stats` defaults; tune in the balance pass, not here). Class attributes (e.g. Might/Intellect priorities) add +1 to the mapped stat per listed attribute.
- Flow: constructor «Создать» → `WorldPersistence.pending_new_game = profile` (static, cleared on read — same pattern as `pending_save`) → `change_scene_to_file("res://scenes/World.tscn")`. `WorldBootstrap._create_hero()`: if `pending_new_game != null` → apply `hero_name`, `stats`, and new metadata fields `hero_race/hero_class/hero_culture/hero_background` on the `HeroController`. «Назад/Отмена» → back to `MainMenu.tscn`.
- `HeroController.serialize()` persists the 4 metadata fields + `stats` into `SaveData.hero` (forward-compat: `deserialize` uses defaults when absent, so old saves keep loading).

**3. Audio.**
- Assets: copy 43 mp3 → `game/assets/audio/music/`, 6 wav → `game/assets/audio/sfx/`. Run the headless import pass (`/Applications/Godot.app/Contents/MacOS/Godot --headless --import`). Music mp3s loop (import default loop for music players is handled in code: `stream.loop = true` guard / `AudioStreamMP3` loop flag at load).
- `game/data/MusicTracks.gd` — port of the source registry with retargeted paths; keeps `get_tracks_for_location()`, `get_biome_music()`, `BATTLE_LOCATIONS`.
- `game/core/SoundManager.gd` upgrade (same `class_name`, existing API preserved):
  - SFX name registry (from the source `AudioManager` SFX map) + `play_sfx_named(name)`; pool raised to 16.
  - `play_location_music(location: String, rng: RandomNumberGenerator = null)` — resolves `MusicTracks` group, picks Main or a Var avoiding `last_variation[location]`, crossfades A/B players over 1.5 s, remembers the pick per location; `stop_music()`.
  - Volume: `apply_volumes(master, music, sfx, muted)` wired from `Settings` (replaces bus writes; `SettingsScreen` already calls `Settings._apply_audio()` — extend that path to also notify `SoundManager`).
  - Headless: every play method no-ops with a trace when `_Platform.is_headless()` or the stream is missing (graceful degradation, same rule as `audio-pass`).
- `game/default_bus_layout.tres`: add `UI` bus (→ Master).
- Call sites: `MainMenu` (menu music + hover/click), `World.tscn` bootstrap (`play_location_music` by current biome: default `world`, overrides snow→`world_snow`? — mapping decision: world uses `get_biome_music(biome)` with default `Grove_Ambient`; biome keys: grass/forest→Grove_Ambient, snow→Peaks_Ambient, sand→Sands_Techno, swamp→Silence_Lofi, lava/volcano→Fury_Industrial, mountain→Peaks_Ambient, water→Grove_Ambient), `CityArena`/city entry → Tavern_FolkElectronic, battle start → WarDrums_HardTechno (crossfade), battle end → victory (Fanfare_Epic) / defeat (Silence_Lofi) one-shots, `BattleView`/`BattleFlow` sword_hit on melee resolve, spell_cast on cast.

**4. What else to take from GAMES_TROLES (analysis — port nothing else now).**

| Candidate | Verdict | Notes |
|---|---|---|
| `assets/ui/main_menu_bg.jpeg` | **Port** | Our title is on it; the core of this cycle |
| `ui/themes/dark_fantasy_button_style.tres`, `dark_fantasy_theme.tres`, `theme/ParchmentTheme.gd` | Inline now / keep reference | Style values are small (61 lines total); we inline the button StyleBox values in code; parchment theme — later polish |
| `autoload/Loc.gd` (RU/EN dictionaries) | **Future candidate** | Useful for all our UI strings; separate small cycle if wanted |
| `autoload/SceneRouter.gd` | **Future candidate** | Modal/screen navigation pattern; pairs with `city-in-world`, `legend-chronicle` |
| `autoload/DifficultyManager.gd` | **Future candidate** | 4 difficulties × multipliers; pairs with `endgame-conditions`, `enemy-world-ai` |
| `assets/sounds/` (64 wav, ~99 MB: lose1A, sword sets…) | Skip for now | Raw pool; if battle SFX variety is ever needed, cherry-pick from here (license: same source as the rest) |
| PoE2 content: `data/modules/{spells,items,enemies,loot,encounters}.gd`, quests/dialogs | **Skip** | Different identity; our cycles (`spell-depth`, `race-class-matrix`, `endgame-conditions`) define our own content |
| `GameManager`, `SaveManager`, `DialogueManager`, `QuestManager`, `ArenaManager` autoloads | **Skip** | Replaced by our flows (WorldPersistence, SaveManager, CityArena) |

**Grounding facts (files):**
- Source: `GAMES_TROLES/game/scenes/ui/main_menu/{MainMenu.tscn,MainMenu.gd}`, `GAMES_TROLES/game/assets/ui/main_menu_bg.jpeg` (1920×1080, ~400 KB), `GAMES_TROLES/game/ui/character_creation/{character_creation.tscn,CharacterCreationUI.gd}`, `GAMES_TROLES/game/data/modules/{races,classes,cultures,music_tracks}.gd`, `GAMES_TROLES/game/data/resources/CharacterData.gd`, `GAMES_TROLES/game/autoload/{AudioManager,Loc,DifficultyManager,SceneRouter,GameManager}.gd`, `GAMES_TROLES/game/audio/{music,sfx}/`
- Ours: `game/ui/MainMenu.gd` (7 buttons + lock panel, `_on_new_game`), `game/ui/SettingsScreen.gd` (Graphics/Audio/Gameplay sections, `_make_button`), `game/core/SoundManager.gd` (path-based, pool 8), `game/core/Settings.gd` (volume fields + `_apply_audio`), `game/default_bus_layout.tres` (Master/SFX/Music), `game/entities/HeroController.gd:23,314,333` (name, stats, serialize/deserialize), `game/world/WorldBootstrap.gd:125-138` (`_create_hero`, `_init_hero`), `game/world/WorldPersistence.gd` (`pending_save` pattern), `game/data/SpellRegistry.gd` etc. (existing registries — new data files must not clash: hence `hero_races`/`hero_classes`/`hero_cultures`/`MusicTracks` names)
