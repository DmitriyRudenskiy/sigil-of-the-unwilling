## 1. Audit (baseline)
- [x] Confirm zero audio assets and that `Settings` already persists volume fields.
  - `game/assets/audio/` пуст (0 файлов); `Settings` персистит `master/music/sfx_volume` + `is_muted` в `user://settings.cfg`.
  - Найден баг: `Settings._apply_audio()` мапил по индексу (1→Music, 2→SFX), а порядок шин [Master, SFX, Music] — громкости перепутаны.
- [x] List scene entry points and action call sites to wire.
  - Музыка: `MainMenu._ready`, `WorldController._ready`, `BattleFlow.start_battle` / `_on_battle_finished`.
  - SFX: `MainMenu` кнопки, `AdventureUI` (end turn, settings), `WorldInteractionController` (capture/collect/scroll), `HeroMovementController` (step), `BattleTurnExecutor` (strike, spell).
  - Обнаружено: `SoundManager` был отключённым autoload (без `*` в project.godot) — включён.

## 2. Asset pack
- [x] Source/create CC0 (or original) assets: 3 looping music tracks (menu/world/battle), 5 SFX (ui_click, hero_move, village_capture, battle_hit, spell_cast).
  - Музыка (из GAMES_TROLES, ассеты владельца, созданные для этой игры): `Dawn_Cinematic_Main` → `music/menu_music.mp3`, `Grove_Ambient_Main` → `music/world_music.mp3`, `WarDrums_HardTechno_Main` → `music/battle_music.mp3`.
  - SFX (GAMES_TROLES): `ui_click`, `ui_hover`, `sword_hit`, `spell_cast`, `victory`, `defeat`.
  - Скрипт-плейсхолдеры (синтез, TODO: заменить полным набором в `port-troles-heritage`): `hero_step`, `village_capture`, `resource_collect`.
- [x] Place under `game/assets/audio/{music,sfx}/`; import settings (music loop on); note in `docs/ASSET_PIPELINE.md`.
  - 12 `.import`-файлов созданы headless-импортом; луп музыки — в `SoundManager` (повтор по `finished`), не в import-настройках.

## 3. `AudioCues` + wiring
- [x] `data/AudioCues.gd`: semantic event → path map.
  - 12 cue: ui_click, ui_hover, hero_step, village_captured, resource_collected, battle_hit, spell_cast, battle_victory, battle_defeat, music_menu, music_world, music_battle.
- [x] Music on scene entry: MainMenu → menu, World → world, Battle → battle (via `SoundManager.play_music`).
  - `SoundManager`: +`play_sfx_cue(cue)` / `play_music_cue(cue)`, +`stop_music()`, луп, хуки `last_sfx_path`/`last_music_path`; `class_name SoundManager` удалён (теньюет синглтон).
  - `BattleFlow._on_battle_finished`: victory/defeat SFX + возврат к `music_world` (мир под боем не пересоздаётся).
- [x] SFX at call sites: AdventureUI buttons, WorldInteractionController (capture/collect), BattleFlow (hit/spell).
  - Точки: `MainMenu` (hover/click все кнопки), `AdventureUI._on_end_turn` + settings button, `WorldInteractionController` (capture_village/collect_resource/pickup_scroll), `HeroMovementController` (step_taken), `BattleTurnExecutor` (`_do_next_attack_strike`, `on_spell_target_selected` success).

## 4. Settings UI
- [x] `SettingsScreen`: master/music/sfx sliders + mute toggle; apply via `SoundManager.apply_volumes()`; persist.
  - Sliders уже были; добавлен CheckBox «🔇 Мьют (M)» → `Settings.is_muted` + `_apply_audio()`; состояние восстанавливается в `_restore_state`.
  - Apply через `Settings._apply_audio()` (не SoundManager): единый путь записи в шины; `Settings._apply_audio()` переписан на **имена** шин (Master/Music/SFX) — исправлен баг перепутанных громкогов.
- [x] Test: changing a slider updates the bus volume live and survives a settings save/load.
  - `tests/test_audio.gd`: bus mapping по именам + mute -80 dB + персист полей (существующие test_settings_persist).

## 5. Graceful degradation + tests
- [x] Guard all play calls (missing stream / headless → log + no-op).
  - `SoundManager`: пустой пул / null-плеер (headless, не в дереве) → no-op; отсутствующий файл → push_warning; неизвестный cue → push_warning.
- [x] Headless smoke: `play_sfx`/`play_music` with missing paths don't crash the runner.
  - `tests/test_audio.gd`: missing paths + unknown cues — без crash.
- [x] Scenario/console assertion: world entry starts world music.
  - `tests/test_audio_world_entry.gd` (standalone SceneTree, паттерн test_runtime_integration): World.tscn → `SoundManager.last_music_path == music_world`.

## 6. Gate
- [x] Full suite + scenarios green; re-run the agent-run-and-debug gate; commit.
  - `run_all_ci_checks.sh`: **5/5 PASS** (compile, scene refs, spell validation, tileset integrity, unit tests).
  - Полный прогон: **4802 passed / 0 failed (76 files)** (было 4759, +43 аудио-теста).
  - Standalone: `test_audio_world_entry.gd` ✅ (world entry → `music_world`).
  - `docs/ASSET_PIPELINE.md` — раздел Audio Assets добавлен.
  - Коммит — не сделан (требование сессии: коммиты только по явному запросу).
