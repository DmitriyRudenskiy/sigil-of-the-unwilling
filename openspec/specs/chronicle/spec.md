---
description: "Requirements for the identity's presentation: a hero-condition screen, a death-and-succession moment, a persistent chronicle of generations, and visible glory progress."
---

# chronicle Specification

## Purpose

Презентация легенды: экран кондиции героя, смерть как момент (последовательность со сводкой забега и преемником), персистентная летопись поколений и видимый прогресс славы к порогу победы.

## Requirements

### Requirement: The player can see the hero's condition
A hero-condition screen **MUST** show the hero's state — needs/inspiration (when present), morale, skills, and followers (name, path, traits) — and **MUST** render only the sections whose data exists (graceful degradation before the identity cycles land).

#### Scenario: Partial data
- **Given** the identity cycles are not yet implemented (no hero needs)
- **When** the hero-condition screen opens
- **Then** it shows the available sections (stats, followers) and omits the missing ones without error

#### Scenario: Full data
- **Given** inspiration, skills, and followers exist
- **When** the screen opens
- **Then** the inspiration meter, skills, and the follower list are shown

### Requirement: Death is a moment, not an error
On hero death, a full-screen death sequence **MUST** play: the fall of the hero, a run summary, and — when a successor exists — the successor's presentation with a transition into the succession flow.

#### Scenario: Death with successor
- **Given** a hero with an eligible successor dies
- **When** the death event fires
- **Then** the sequence shows the summary and the successor card, and «Знак переходит» starts the succession flow

#### Scenario: Death without successor
- **Given** a hero with no successor dies
- **When** the death event fires
- **Then** the sequence shows the summary and a «В меню» option

### Requirement: The chronicle records generations
Each ended cycle **MUST** append a chronicle entry (hero name, path, years, key stats, outcome), and the chronicle **MUST** be viewable from the main menu and after death.

#### Scenario: Entry appended
- **Given** a cycle ends (succession or final run)
- **When** the end event fires
- **Then** a new entry appears in the chronicle

#### Scenario: Viewable
- **Given** a non-empty chronicle
- **When** the player opens «Летопись»
- **Then** entries are listed newest-first

### Requirement: Glory is visible
The UI **MUST** show current glory and progress toward the victory threshold.

#### Scenario: Progress shown
- **Given** glory is 40 of a 100 threshold
- **When** the player looks at the glory meter
- **Then** it shows 40/100

### Requirement: The chronicle persists
Chronicle entries **MUST** survive save/load.

#### Scenario: Survives reload
- **Given** a chronicle with entries
- **When** the game is saved and reloaded
- **Then** the entries are present
