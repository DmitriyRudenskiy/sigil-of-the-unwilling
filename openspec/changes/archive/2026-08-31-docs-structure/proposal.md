---
description: "Optimize the documentation structure: organize docs into layers/areas, add an index/README, update stale docs, and begin filling system-documentation gaps. Ensure docs are committed to Git."
---

## Why

The repo ships **26 markdown docs** in `docs/` (root of the repo) but there is **no index or README**, the **naming is scattered** (`CONCEPT_*`, `TASK_*`, `PLAN_MASTER`, `ECONOMY_*`, `BIOME_SYSTEM`, `inventory_items`, `spells_system`, `battle_spells`, `binomials`, `GRAPH_KNOWLEDGE`, `OVERVIEW`, `REPORT`, `ADDING_*`), and at least one doc is **stale** (`REPORT.md` references old `scripts/…` paths that no longer exist — the project root is `game/`). Worse, `docs/` is currently **untracked in Git** (`git status` shows `?? docs/`), so the documentation is not version-controlled at all. AGENT.md points readers at `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `docs/TOOLS.md`, but there is no map to find them.

This change optimizes the documentation structure (organize into layers/areas, add an index), updates stale docs, and begins filling the most important system-documentation gaps.

## Proposed Change

1. **Index/README.** Add `docs/README.md` as a map: group docs into areas (overview, architecture, systems, economy, spells, UI, concept/design, tasks/reports, how-to/ADDING_*), with one-line descriptions and links.
2. **Organize into folders.** Move docs into area folders (e.g. `docs/architecture/`, `docs/systems/`, `docs/economy/`, `docs/spells/`, `docs/concepts/`, `docs/tasks/`, `docs/howto/`), updating cross-references in AGENT.md and within docs. Keep flat files that don't fit (README already exists at repo root).
3. **Update stale docs.** Fix `REPORT.md` (and any other doc) that references the old `scripts/…` layout → `game/…`; reconcile path references.
4. **Begin filling gaps.** Add/expand the highest-value missing system docs (the cycles introduce succession, race-class, sacrifice — document the current core systems first: world/adventure, battle, city/economy, hero/inventory/magic). Prioritize a short, concrete list.
5. **Version control.** Commit `docs/` to Git (it is currently untracked).

## Scope

- **In:** `docs/README.md`, folder reorganization + cross-reference updates, stale-doc fixes, an initial set of system docs, committing `docs/`.
- **Out:** rewriting every doc to full depth — this cycle *starts* filling gaps, not completes them.
