## Context

- `core/SoundManager.gd`: autoload `/root/SoundManager`; `play_sfx(path)`, `play_music(path)`, `_cached_stream`, SFX pool (`SFX_POOL = 8`), mute, `_ready` preloads `_Platform` (headless awareness already present in the codebase).
- `core/Settings.gd`: `master_volume` / `music_volume` / `sfx_volume` (int) + `is_muted`, with `_load`/`_save` to the config file (lines 25-27, 34, 80-91) — persisted today, but `ui/SettingsScreen.gd` exposes no volume controls.
- Zero audio assets: `find game/assets -name "*.ogg|*.wav|*.mp3"` is empty.
- Scene entry points: `MainMenu` (`_on_new_game` → World), `World.tscn` (bootstrap), battle start via `WorldBattleCoordinator` → `scenes/Battle.tscn`.
- Action call sites: `WorldInteractionController` (`capture_village_at`, `collect_resource_at`, `check_chest_contact`, `pickup_scroll_at`), `AdventureUI` buttons, `BattleFlow` (hit/spell).

## Design

**1. Asset pack.** `game/assets/audio/music/` (looping `.ogg`: menu, world, battle) and `game/assets/audio/sfx/` (`.ogg`: ui_click, hero_move, village_capture, battle_hit, spell_cast). Music import settings: loop on. Assets must be original or CC0-licensed; a `docs/ASSET_PIPELINE.md` note records the import settings and the licensing rule (extends the `docs-structure` doc effort, not blocking).

**2. `data/AudioCues.gd`.** A static event→path map so call sites reference semantic names, not file paths (paths can change without touching gameplay code).

**3. Wiring.**
- Music: a single music player owned by `SoundManager` (`play_music` already handles switching/looping). Scene `_ready` plays its cue: `MainMenu` → `music_menu`, `World.tscn` → `music_world`, `Battle.tscn` → `music_battle`. No crossfade for the first pass (a later polish).
- SFX: call `SoundManager.play_sfx(AudioCues.X)` at the action sites; the existing pool handles overlap.

**4. Settings UI.** `SettingsScreen` adds three `HSlider`s (master/music/sfx, 0-100) + a mute `CheckBox`, bound to `Settings` fields on change and applied via `SoundManager` (a new `apply_volumes()` that sets `AudioServer` bus volumes + mute). Persists through the existing `_save`.

**5. Graceful degradation.** `SoundManager` guards every play: if the stream is null (missing file, not imported, headless with no audio driver) it logs via `GameLogger` and returns. Headless smoke: calling `play_sfx`/`play_music` with a missing path must not crash the test runner.

**Grounding facts (files):**
- `game/core/SoundManager.gd` (`play_sfx`, `play_music`, `_cached_stream`, `SFX_POOL`)
- `game/core/Settings.gd` (volume fields + load/save)
- `game/ui/SettingsScreen.gd` (no volume UI today)
- `game/world/WorldInteractionController.gd` (action call sites)
- `game/ui/MainMenu.gd`, `game/scenes/World.tscn`, `game/scenes/Battle.tscn` (scene entry/music)
- `game/systems/BattleFlow.gd` (hit/spell call sites)
