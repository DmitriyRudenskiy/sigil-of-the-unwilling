## 1. Audit (baseline)
- [x] Confirm source files exist: `GAMES_TROLES/game/assets/ui/main_menu_bg.jpeg`, `audio/music/` (43 mp3), `audio/sfx/` (6 wav), `MainMenu.tscn/.gd`, `character_creation.tscn`, `CharacterCreationUI.gd`, `races/classes/cultures/music_tracks.gd`, `CharacterData.gd`, `AudioManager.gd`.
- [x] Confirm our baseline: `MainMenu.gd` 7 buttons + lock panel, `assets/audio/` empty, no `UI` bus, `WorldBootstrap._create_hero` default hero.

## 2. Asset port
- [x] Copy `main_menu_bg.jpeg` → `game/assets/ui/main_menu_bg.jpeg`.
- [x] Copy 43 mp3 → `game/assets/audio/music/`, 6 wav → `game/assets/audio/sfx/`.
- [x] Headless import pass (`/Applications/Godot.app/Contents/MacOS/Godot --headless --import`); verify `.import`/`.uid` generated for all assets; no orphaned files.
- [x] Note the source and license rule in docs (extends `docs-structure` effort; non-blocking).

## 3. Start screen
- [x] `MainMenu._find_bg()`: add `res://assets/ui/main_menu_bg.jpeg` to the probe list.
- [x] `game/ui/MainMenu.gd`: port dark-gold `StyleBoxFlat` button style; buttons exactly «Новая игра», «Загрузить», «Настройки», «Выход»; delete lock panel + `_flash_lock` (keep load-failure feedback as a temporary label or toast).
- [x] «Новая игра» → `CharacterCreation.tscn` (not `World.tscn` directly).
- [x] `SettingsScreen.gd`: add «🧪 Песочница / Dev» section with «Арена города», «Модель: Рыцарь», «Модель: Маг» (close the settings screen first, then run the existing MainMenu callbacks/scenes).
- [x] Menu audio: `play_location_music("menu")` on ready; hover → `ui_hover`, click → `ui_click`.
- [x] Keep the `--test-server` guard and `UIAnimator` integration.

## 4. Hero constructor
- [x] `game/data/hero_races.gd`, `hero_classes.gd`, `hero_cultures.gd` — port the source tables (renamed files; content unchanged, RU descriptions kept).
- [x] `game/data/HeroBuildProfile.gd` — Resource: name, sex, race, subrace, class, culture, background, abilities; `get_stats()` with the documented ability→stat mapping.
- [x] `game/scenes/CharacterCreation.tscn` + `game/ui/CharacterCreationUI.gd` — port the UI; remove source autoload dependencies (inline strings); wire «Создать» → `WorldPersistence.pending_new_game` + scene change to `World.tscn`; «Назад» → `MainMenu.tscn`.
- [x] `WorldPersistence.pending_new_game` static (same handoff pattern as `pending_save`, cleared on read).
- [x] `WorldBootstrap._create_hero()`: apply `pending_new_game` (name, stats, race/class/culture/background metadata) when present.
- [x] `HeroController`: add `hero_race/hero_class/hero_culture/hero_background` fields; include in `serialize()`/`deserialize()` with defaults for old saves.
- [x] Test (headless): building a profile with a chosen race/class yields the expected deterministic `stats`; bootstrap with `pending_new_game` produces a hero with that name/stats/metadata; an old save without the new fields still deserializes.

## 5. Audio system
- [x] `game/data/MusicTracks.gd` — port the registry; paths → `res://assets/audio/music/`; keep `get_tracks_for_location()`, `get_biome_music()`, `BATTLE_LOCATIONS`.
- [x] `default_bus_layout.tres`: add `UI` bus (send → Master).
- [x] `SoundManager` upgrade (same `class_name`, existing API intact): SFX name registry + `play_sfx_named()`, pool 16; `play_location_music(location)` with Main/Var rotation (no repeat of previous pick, seedable rng), A/B crossfade 1.5 s, `stop_music()`; `apply_volumes()` driven by `Settings` (extend `Settings._apply_audio()` to notify it); headless/missing-stream no-op + trace.
- [x] `SettingsScreen` volumes already wired — verify the new manager respects them live (change slider → bus volume changes).
- [x] Call sites: `World.tscn` entry → biome music (default Grove_Ambient; snow/mountain → Peaks_Ambient, sand → Sands_Techno, swamp → Silence_Lofi, lava/volcano → Fury_Industrial); city entry → Tavern_FolkElectronic; battle start → WarDrums_HardTechno (crossfade); battle end → victory (Fanfare_Epic) / defeat (Silence_Lofi); `BattleView`/`BattleFlow` → `sword_hit` on melee resolve, `spell_cast` on cast.

## 6. Tests + gate
- [x] Headless smoke: menu scene loads; all `play_*` calls with missing files do not crash the runner.
- [x] Determinism test: with a fixed seed, `play_location_music` variation rotation never repeats the previous pick and cycles through Main/Vars.
- [x] Settings sandbox section test: the 3 moved entries exist and map to the right scenes.
- [x] Full suite + auto-game scenarios green; re-run the `agent-run-and-debug` gate (no new warnings/errors in console); commit.
- [x] Housekeeping: archive `audio-pass` (superseded) or narrow it to the remaining SFX event map (hero_move, village_capture, resource_collect) — decision recorded at review.
