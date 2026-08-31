---
description: "Add the first audio pack (music for menu/world/battle, SFX for core actions) and wire it to the existing SoundManager; expose volume/mute in the settings screen; degrade gracefully when audio is missing or headless."
---

## Why

The audio pipeline is **fully built but completely silent**. `core/SoundManager.gd` (autoload `/root/SoundManager`) implements `play_sfx`, `play_music`, a pool of 8 SFX players, mute, and cached streams; `core/Settings.gd` already stores `master_volume`, `music_volume`, `sfx_volume`, and `is_muted` (with load/save). But the project contains **zero audio assets** — no `.ogg`/`.wav`/`.mp3` anywhere. Every gameplay moment is silent: no music on scene entry, no SFX on move/capture/battle/UI.

This is the cheapest high-leverage "feel" change in the project: the plumbing exists; only assets and call sites are missing.

## Proposed Change

1. **First audio pack.**
   - Music (looping): main menu, world, battle — at least 3 tracks.
   - SFX set (start 3–5, extend later): UI click, hero move, village capture, battle hit, spell cast.
   - Assets into `game/assets/audio/{music,sfx}/`, original or properly licensed (CC0); import settings with loop enabled for music.
2. **Event → sound map.** `data/AudioCues.gd`: named events (`ui_click`, `hero_move`, `village_captured`, `battle_hit`, `spell_cast`, `music_menu`, `music_world`, `music_battle`) → asset paths.
3. **Wiring.** Call sites: `MainMenu` (menu music + UI SFX), `World.tscn` entry (world music), battle start (battle music + hit/spell SFX), `WorldInteractionController` (capture/collect), `AdventureUI` buttons. Music switches on scene entry; SFX via the existing pool.
4. **Settings UI.** `ui/SettingsScreen.gd` gains master/music/sfx sliders + a mute toggle, bound to the existing `Settings` fields and applied through `SoundManager` (the settings exist today but the screen does not expose them).
5. **Graceful degradation.** A missing/unimported asset **MUST** log and no-op (no crash, headless-safe); volume changes apply live.

## Scope

- **In:** the audio pack (assets + import settings), `AudioCues`, wiring at the listed call sites, settings-screen volume UI, graceful-degradation guard, tests (headless smoke: play calls with missing files don't crash; music starts on world entry — console assertion).
- **Out:** a full sound design pass (ambience, per-unit voices, dynamic mixing), asset sourcing beyond the first pack, per-battle music variation.
