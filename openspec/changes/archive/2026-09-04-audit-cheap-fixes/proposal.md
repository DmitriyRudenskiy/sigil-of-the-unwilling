## Context

The 2026-09-04 project audit returned 18 findings across architecture, best
practices, algorithms and refactoring. Triage against the actual code:

- **4 already handled** — would be churn to "fix" (`#2` MinHeap, `#6` SoundManager
  modulo, `#7` WorldEventRouter, `#9` ArtifactInventoryScreen).
- **3 theoretical / low-value** (`#13` BattleController, `#17` CityScreen).
- **~8 are refactors or perf work** that belong in their own change
  (`#1` mcp monolith, `#4` Dijkstra→BFS, `#5` ArenaCluster cache, `#12`
  WorldBootstrap, `#14` static state).
- **A few are genuinely-worthwhile, cheap, real fixes.** This change does those.

Proposing one change for all 18 would touch ~15 files, invite merge conflicts,
and be impossible to verify as a unit. That is the over-engineering trap.

## This change

Two isolated fixes, each correct on its edge case:

1. **`core/GameLogger.gd`** — headless-safe logging. `info`/`warn`/`error` call
   `print_rich` unconditionally; only `trace` checks debug mode. In `--headless`
   debug builds this prints raw `[color=…]` tags. Switch to `print` when
   `Platform.is_headless()`.
2. **`core/HexUtils.gd` `astar_path`** — stale-entry check `cur_g > best_g`
   instead of `cur_g > best_g + 0.001` (drop the magic epsilon). More correct,
   one line.

## Skipped — already handled (no-op)

- `#2` MinHeap.pop: has a `ponytail:` comment; callers loop on
  `while not open.is_empty()`, so `[]` is never returned inside the loop.
- `#6` SoundManager: `_rr` is reset `% SFX_POOL` on every increment and the pool
  is always filled to 8 or left empty (guarded) — out-of-bounds is unreachable.
- `#7` WorldEventRouter: already guards every `connect` with `is_connected`.
- `#9` ArtifactInventoryScreen: `_apply_theme` already starts with `if _theme == null`.

## Skipped — theoretical / low-value

- `#13` BattleController: no clean try/except in GDScript; inits are simple
  `.new()` + setup. Half-built-scene risk is theoretical.
- `#17` CityScreen: audit itself marks the shown path "норм"; the only real path
  (`SocketController._cmd_city_build` empty `building`) is minor.

## Recommend as separate changes (do not bundle)

- `#1` `mcp_interaction_server.gd` (4864 lines) — own large refactor.
- `#4` EnemyTurnProcessor Dijkstra→BFS — benchmark first; `dijkstra` vs
  `bfs_reachable` differ semantically (float cost vs integer MP).
- `#5` ArenaCluster static cache — multi-file refactor (cache → `City`).
- `#12` WorldBootstrap `connect` dedup — architectural (subsystems subscribe
  themselves).
- `#14` static mutable state across files — needs per-file analysis.

## Skip — low value / style

`#8` HeroController signal rewire (existing `_signals_wired` guard is intentional),
`#10` Settings audio order (unverified, low), `#15` SocketController._process,
`#16` Variant typing, `#18` MapSpawner warning.
