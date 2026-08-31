# Project Overview: Sigil of the Unwilling

## Description
A large-scale world-building and procedural generation project focused on creating visually consistent and logically structured environments. The project emphasizes an automated asset pipeline, where raw textures are processed into biome-specific tilesets using automated color clustering and geometry adjustments.

## Core Objectives
- **Visual Consistency**: Ensuring seamless transitions between diverse biomes (e.g., Swamp, Water, Mountains) through color palette guidelines and visual weight balancing.
- **Scalable Architecture**: Utilizing a "Feature-based" project structure to allow for modular expansion of game systems (Spells, Resources, UI).
- **Automated Asset Pipeline**: Moving from raw image folders to production-ready sprite sheets and hexagonal tilesets with minimal manual intervention.
- **Knowledge-Driven Design**: Using Knowledge Graphs (via Graphify) to map relationships between game objects, resources, and environmental constraints.

## Technology Stack
- **Engine**: Godot 4.7
- **Language**: GDScript (Game Logic), Python (Tooling & Asset Processing)
- **AI & Analysis**: Gemma 4 Vision (Image analysis), Graphify (Knowledge Graph), PIL/NumPy (Image processing)
- **Data Management**: JSON-based registries, ResourceRegistry.gd, and automated folder structures.

## Key Features
- **Biome Clustering**: Automated classification of textures into biomes based on color analysis.
- **Hexagonal Tiling**: Custom texture cropping and mask application for hexagonal grid compatibility.
- **Resource Registry**: A centralized system for managing biome compatibility and global game constants.
- **Procedural Map Visualization**: Tools for generating and previewing biome distribution before final production.

## Audio Assets (audio-pass, 2026-08)

- Location: `game/assets/audio/{music,sfx}/` (12 files: 3 MP3 tracks, 9 WAV SFX).
- Music: menu/world/battle — ported from the GAMES_TROLES pack (owner's own assets for this game), looped at runtime by `SoundManager` (not in import settings).
- SFX: `ui_click`, `ui_hover`, `sword_hit`, `spell_cast`, `victory`, `defeat` (ported) + synthesized placeholders `hero_step`, `village_capture`, `resource_collect` (pure-Python `wave`, 16-bit mono 44100 Hz, deterministic).
- **TODO**: replace the full SFX set with the GAMES_TROLES pack in the `port-troles-heritage` cycle.
- Cue→path mapping: single source of truth is `game/data/AudioCues.gd`. Call sites use `SoundManager.play_sfx_cue(cue)` / `play_music_cue(cue)`; raw path calls are forbidden in new code.
- Import: headless `godot --headless --path game --import` generates the `.import` files; missing files/unknown cues degrade gracefully (warning, no crash) — see `game/tests/test_audio.gd`.
