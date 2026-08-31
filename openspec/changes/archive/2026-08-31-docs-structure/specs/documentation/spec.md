---
description: "Requirements for the documentation structure: an index, organized area folders, updated cross-references, stale-doc fixes, and initial system docs."
---

## ADDED Requirements

### Requirement: An index/README maps the documentation
The `docs/` tree **MUST** have a top-level `docs/README.md` that groups all documentation into areas (overview, architecture, systems, economy, spells, UI, concept/design, tasks/reports, how-to) with a one-line description and a link to each doc.

#### Scenario: Reader finds a doc via the index
- **Given** `docs/README.md`
- **When** a reader wants to learn about the spell system
- **Then** the index links to the spell-system doc

### Requirement: Documentation is organized into area folders
Documentation **MUST** be organized into area folders under `docs/` (e.g. `architecture/`, `systems/`, `economy/`, `spells/`, `concepts/`, `tasks/`, `howto/`), so related docs live together instead of in one flat, scattered set.

#### Scenario: System docs are grouped
- **Given** the spell-system doc, the economy doc, and the battle doc
- **Then** they live in area folders (`docs/systems/…`), not mixed with concept/task docs in the root

### Requirement: Cross-references stay correct
After reorganization, **all** cross-references to docs (in `AGENT.md` and within docs) **MUST** point to the new paths. No doc link **MUST** dangle.

#### Scenario: AGENT.md references update
- **Given** `AGENT.md` links to `docs/ARCHITECTURE.md`
- **When** the docs are reorganized
- **Then** AGENT.md links to the new `docs/architecture/ARCHITECTURE.md` (or equivalent)

#### Scenario: No dangling link
- **Given** the reorganized `docs/`
- **Then** every `docs/…` reference resolves to an existing file

### Requirement: Stale documentation is corrected
Any doc that references the old project layout (`scripts/…`) **MUST** be updated to the current layout (`game/…`).

#### Scenario: REPORT.md is corrected
- **Given** `docs/REPORT.md` references `scripts/BattleState.gd`
- **When** it is updated
- **Then** it references `game/…` (or is marked stale/removed)

### Requirement: Initial system documentation is filled in
The documentation **MUST** include at least the core-system docs for the areas introduced by the cycles — world/adventure, battle, city/economy, hero/inventory/magic — so a reader can understand the current architecture.

#### Scenario: A core-system doc exists
- **Given** the `docs/systems/` area
- **Then** it contains docs covering the world/adventure, battle, city/economy, and hero systems

### Requirement: Documentation is version-controlled
The `docs/` tree **MUST** be committed to Git (it is currently untracked).

#### Scenario: Docs are tracked
- **Given** the change is committed
- **Then** `git ls-files docs/` lists the documentation files
