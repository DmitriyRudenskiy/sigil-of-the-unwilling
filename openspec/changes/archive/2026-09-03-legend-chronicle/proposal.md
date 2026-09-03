---
description: "Give the identity a face: a hero-condition screen (needs/inspiration, morale, skills, followers), a death-and-succession moment (full-screen, with run summary), a persistent chronicle of generations, and visible glory progress toward the Path."
---

## Why

The identity cycles (`inspiration-core`, `succession-sigil`, `race-class-matrix`) create rich in-game state — the hero's path, inspiration/burnout, death, inheritance of the sigil, generations, glory — but **none of it has a face in the game**. Concretely:

- The player cannot see the hero's condition. `Character.NEED_KEYS` (hunger/rest/social/belief) exist for **citizens** (demographics); the hero has no needs UI and, after `inspiration-core`, no visible inspiration meter at all.
- The hero's path, skills, and followers are data without a screen (the AdventureUI right column has Army/Resources/Skills/Tools panels, but no hero-condition or legend panel).
- When `succession-sigil` makes death real, death is a state change, not a *moment* — the emotional core of the project ("each cycle passes on the sign") currently has no presentation.
- Glory (`CityManager.add_glory`) is a number nobody shows, so there is no visible progress toward a goal (which `endgame-conditions` turns into victory).

This change is the presentation layer for the identity: it makes the player *feel* the legend.

## Proposed Change

1. **Hero-condition screen.** A panel (in the AdventureUI right column, expandable) showing the hero's state: needs/inspiration (after `inspiration-core`), morale, skills, and followers (name, path, traits).
2. **Death-and-succession moment.** On hero death, a full-screen sequence: the fall of the current hero, a run summary (turns, cities, glory, battles), and — when a successor exists — the presentation of the successor (name, race×class, the inherited sigil) with a «Знак переходит» transition into the succession flow.
3. **Chronicle of generations.** A persistent log (`core/Chronicle.gd`): one entry per ended cycle (hero name, path, years, key stats, outcome), viewable in a `ChronicleScreen` from the menu and after death; entries persist through save/load.
4. **Visible glory.** A glory meter in the AdventureUI showing current glory and progress toward the victory threshold (`endgame-conditions`).

## Scope

- **In:** `ui/HeroStatusPanel.gd`, `ui/DeathSequence.tscn` (overlay), `core/Chronicle.gd` + `ui/ChronicleScreen.tscn`, glory meter in `AdventureUI`, save persistence of the chronicle, unit tests.
- **Out:** narrative writing beyond the summary lines (templates, not prose), art/animation beyond reusing `UIAnimator`, per-generation stat tracking beyond the existing systems, the death/successor *rules* (`succession-sigil`).

## Dependencies

- `inspiration-core` (hero needs/inspiration to display) — the panel degrades gracefully (shows what exists) until it lands.
- `succession-sigil` (death + successor events) — the death sequence hooks its events; until it lands, the sequence shows the summary + a «В меню» button only.
- `endgame-conditions` (glory threshold for the meter; `game_ended` to append the final entry).
