---
description: "Port the start screen (art + styled menu), the hero constructor, and the full audio pack (13 music groups / 43 tracks + 6 SFX + location-aware AudioManager) from the sister project GAMES_TROLES; move our extra dev/sandbox menu buttons into Settings; wire music and SFX into the real game flow."
---

## Why

The sister Godot 4.7 project `/Users/user/GAMES_TROLES` (same engine version, same renderer) was built **for this game** and already contains three things we lack:

1. **A finished start screen** — `scenes/ui/main_menu/MainMenu.tscn/.gd` + `assets/ui/main_menu_bg.jpeg` (1920×1080 throne room with the game's own title "SIGIL OF THE UNWILLING" and the sigil behind the throne), dark-gold styled buttons, hover SFX, menu music. Our menu is procedural: 7 code-built buttons over a placeholder/autofound background.
2. **A hero constructor** — `ui/character_creation/character_creation.tscn` + `CharacterCreationUI.gd` (name, sex, race, class, culture, background, ability preview) with data modules `races.gd` (6 races + subraces), `classes.gd` (11 classes), `cultures.gd` (10 cultures + 6 backgrounds). Our "Новая игра" jumps straight into the world with a default hero "Darkstorn" — no creation flow.
3. **A complete audio pack + smart player** — `audio/music/` (43 mp3, 13 thematic groups with Main/Var1..N variations, ~118 MB), `audio/sfx/` (6 wav: ui_click, ui_hover, sword_hit, spell_cast, victory, defeat), `data/modules/music_tracks.gd` (location → group registry), `autoload/AudioManager.gd` (SFX name registry + pool, location music with variation rotation that never repeats the previous pick, A/B crossfade, buses, UI sound hook, volume settings). Our project has **zero audio assets** and a minimal `SoundManager` (path-based, no variation, no crossfade) — the game is silent.

Porting is far cheaper than rebuilding: the art literally bears our title, the engine version matches (4.7, GL Compatibility), and the audio is already curated/renamed for this game (13 groups mapped to locations).

**Overlap note:** this cycle **supersedes `audio-pass`** (created earlier, before GAMES_TROLES was discovered): assets and the manager now exist to be ported instead of sourced from scratch. `audio-pass` can be archived, or narrowed to the remaining delta (event→SFX map for our own actions: hero move, village capture, resource collect).

## Proposed Change

1. **Start screen.**
   - Copy the throne-room art to `game/assets/ui/main_menu_bg.jpeg` (our `MainMenu._find_bg()` already probes that path).
   - Restyle `ui/MainMenu.gd` with the ported dark-gold `StyleBoxFlat` look; the visible menu keeps **4 core buttons**: «Новая игра» (→ hero constructor), «Загрузить», «Настройки», «Выход». No «Продолжить» — we have a single save slot (no autosave), «Загрузить» covers it.
   - **Remove the old «Кампания недоступна» lock panel** (it belonged to the placeholder-bg design; with the real art and 4 buttons the compact layout is clean).
   - The **extra buttons** (the three dev/sandbox entries «🏙 Арена города», «🗡 Модель: Рыцарь», «✨ Модель: Маг») **move to `SettingsScreen.gd`** as a new «Песочница / Dev» section with the same callbacks (`_on_arena`, `_on_model_warrior`, `_on_model_mage`).
   - Menu UI feedback: hover/click SFX + menu music on entry (via the new audio system).
2. **Hero constructor.**
   - Port the scene + UI to `game/scenes/CharacterCreation.tscn` + `game/ui/CharacterCreationUI.gd`.
   - Port the data as **our** registries: `game/data/hero_races.gd`, `game/data/hero_classes.gd`, `game/data/hero_cultures.gd` (content = the ported tables; renamed to avoid clashing with our existing registries) and `game/data/HeroBuildProfile.gd` (Resource adapted from `CharacterData`: name, sex, race, class, culture, background, ability scores, derived stats).
   - New-game flow: MainMenu «Новая игра» → constructor scene → «Создать» stores the profile in `WorldPersistence.pending_new_game` (same pattern as `pending_save`) → `World.tscn` → `WorldBootstrap` applies the profile to the new `HeroController` (name, stats via a documented ability→stat mapping, race/class/culture/background metadata persisted in the hero save dict).
   - Cancel/«Назад» returns to the main menu. The constructor reads only the data registries, so the `race-class-matrix` cycle can later swap the content for the D&D 12-race × class matrix without touching the UI.
3. **Audio.**
   - Copy `audio/music/*.mp3` (43) and `audio/sfx/*.wav` (6) into `game/assets/audio/{music,sfx}/`.
   - Port the registry to `game/data/MusicTracks.gd` (paths retargeted to `res://assets/audio/music/`).
   - **Upgrade `core/SoundManager.gd` in place** (keep `class_name SoundManager` and the existing `play_sfx(path)`/`play_music(path)` API): add the SFX name registry + pool, location music (`play_location_music(location)`), Main/Var rotation with no-repeat of the previous pick (seedable for tests), A/B crossfade, a `UI` bus, and volume application from our `Settings` (single source of truth — the source's separate `user://audio_settings.json` is **not** ported).
   - Add the `UI` bus to `default_bus_layout.tres`.
   - Wire locations: menu → Dawn_Cinematic; world default → Grove_Ambient with biome overrides (snow → Peaks_Ambient, sand → Sands_Techno, lava → Fury_Industrial, swamp → Silence_Lofi); city → Tavern_FolkElectronic; battle → WarDrums_HardTechno; victory/defeat one-shots (Fanfare_Epic / Silence_Lofi). SFX: ui_click/ui_hover on menu buttons, sword_hit on battle hits, spell_cast on casting, victory/defeat on battle end.
   - Graceful degradation (as in `audio-pass`): a missing/unimported asset logs and no-ops; headless-safe.
4. **Analysis of the rest of GAMES_TROLES** (documented in `design.md`, decisions recorded here): port nothing else now. Keep as future candidates: `Loc.gd` (RU/EN localization of UI strings), `SceneRouter.gd` (modal/screen navigation pattern — useful for `city-in-world`, `legend-chronicle`), `DifficultyManager.gd` (EASY..NIGHTMARE multipliers — useful for `endgame-conditions`, `enemy-world-ai`), `ui/themes/dark_fantasy_*.tres` (button styles). Skip: PoE2-derived gameplay content (spells/items/enemies/loot/quests — our identity cycles define our own), the 99 MB raw `assets/sounds/` pool, and the source's `GameManager`/`SaveManager`/`DialogueManager`/`QuestManager` (replaced by our flows).

## Scope

- **In:** the three ports (start screen, constructor, audio) with the wiring above; the Settings «Песочница / Dev» section; `WorldPersistence.pending_new_game` + bootstrap apply; hero save-dict fields for race/class/culture/background; tests (headless: constructor flow yields a hero with chosen name/stats; audio calls with missing files don't crash; menu scene loads; variation rotation is deterministic with a fixed seed; settings sandbox section exposes the 3 moved entries).
- **Out:** replacing the ported race/class/culture content with the D&D matrix (that is `race-class-matrix`'s job), quest/dialogue systems, the raw 99 MB sound pool, OGG transcoding of the mp3s, multi-slot saves/autosave.

## Dependencies

- **Supersedes `audio-pass`** — archive or narrow that cycle after this one lands.
- **Complements `race-class-matrix`** — the constructor is data-driven against our registries; the matrix cycle swaps content, not UI.
- **Feeds `endgame-conditions` / `succession-sigil`** — hero now carries name/race/class in its save dict, which the legend and succession systems display and inherit.
- No dependency on the existing 8 cycles' implementation; all three ports are independent of each other within this cycle (only the menu SFX wiring needs the audio piece).
