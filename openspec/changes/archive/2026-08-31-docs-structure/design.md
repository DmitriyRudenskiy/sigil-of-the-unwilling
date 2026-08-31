## Context

`docs/` holds 26 markdown files (196K), all **untracked in Git** (`git status` → `?? docs/`, not in `.gitignore`). Naming is flat/scattered: `ARCHITECTURE.md`, `OVERVIEW.md`, `TESTING.md`, `TOOLS.md`, `PLAN_MASTER.md`, `TASK.md`, `REPORT.md`, `ECONOMY_BALANCE.md`, `ECONOMY_DATA.md`, `BIOME_SYSTEM.md`, `inventory_items.md`, `spells_system.md`, `battle_spells.md`, `binomials.md`, `GRAPH_KNOWLEDGE.md`, `ADDING_TERRAINS.md`, `ADDING_UNITS.md`, `CONCEPT_*.md` (8), `TASK_SOCIAL_AND_BUILDINGS.md`. No `docs/README.md` index. AGENT.md references several `docs/*.md` directly. Two docs are stale: `REPORT.md` and `ADDING_UNITS.md` reference old `scripts/…` paths (project root is `game/`).

## Design

**1. Index first (`docs/README.md`).** Group the 26 docs into area folders with a one-line description + link. Draft grouping:
- `architecture/` — ARCHITECTURE.md.
- `overview/` — OVERVIEW.md, PLAN_MASTER.md, TASK.md, TASK_SOCIAL_AND_BUILDINGS.md.
- `systems/` — spells_system.md, battle_spells.md, inventory_items.md, BIOME_SYSTEM.md, GRAPH_KNOWLEDGE.md, binomials.md.
- `economy/` — ECONOMY_BALANCE.md, ECONOMY_DATA.md.
- `concepts/` — CONCEPT_*.md (8).
- `howto/` — ADDING_TERRAINS.md, ADDING_UNITS.md.
- `reports/` — REPORT.md, TESTING.md, TOOLS.md.

**2. Reorganize.** `git mv` (to preserve history) files into the folders; update cross-references in AGENT.md and within docs. Keep repo-root `README.md` (not in docs/) and `AGENT.md` as-is.

**3. Fix stale refs.** Update `scripts/…` → `game/…` in `REPORT.md` and `ADDING_UNITS.md`; if `REPORT.md` is an open-questions audit that is no longer actionable, mark it clearly or move to `reports/`.

**4. Fill initial gaps.** Prioritize core-system docs the cycles need: world/adventure, battle, city/economy, hero/inventory/magic. Start with the most central (e.g. a `docs/systems/` overview + the spell system doc, already present but possibly stale). Do not attempt full depth for all systems.

**5. Commit.** Add and commit `docs/` to Git.

**Grounding facts (files):**
- `docs/*.md` (26 files), `docs/REPORT.md` (stale `scripts/…` refs), `docs/ADDING_UNITS.md` (stale).
- `AGENT.md` (lines 4, 90, 335–338 reference `docs/*.md`).
- `git ls-files docs/` → empty (untracked).

## Risks / Trade-offs

- **`git mv` + history:** use `git add -A` for new/renamed files; the rename tooling should preserve paths where possible. Because docs/ is untracked, renames start fresh — commit them as new.
- **Scope of "fill gaps":** 26 docs already exist; the risk is over-writing good content. This cycle *organizes + fixes + starts*; it does not rewrite everything.
- **Cross-ref churn:** reorganization touches many files; keep a diff review to avoid dangling links.
