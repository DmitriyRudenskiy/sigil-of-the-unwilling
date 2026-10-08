# Design

## Context

See `proposal.md` for the baseline and motivation; the behavior contracts and thresholds are in both delta specs. The existing `ScenarioPilot` provides five role policies over one world simulation, while `BalanceProbe` has a 60-turn cap and currently represents death as an end state. The prior full matrix uses one deterministic seed per class/role pair; the long-probe acceptance needs its own fixed ten-seed cohort.

The matrix already has real source paths for City state, resource extraction and battle completion. Trade, kills, distinct-biome progress and survival need to be traced to authoritative state changes; a policy intention or score alone is not evidence that the game action occurred.

## Goals / Non-Goals

**Goals:**
- Fix each role at the point where its real world action is blocked or lost, keeping its workstream diagnosable and independently verifiable.
- Emit enough per-cell/per-seed evidence to explain success, failure, and time-to-goal.
- Preserve fixed-seed determinism, current role goals, City fallback and the distinction between gameplay misses and technical test failures.
- Run all verification headlessly or on an isolated offscreen display without activating a foreground game window, moving/capturing the user's cursor, or falling back to the user's display.

**Non-Goals:**
- Further lower role thresholds, redefine rare resources or city level, award synthetic deals/kills, grant artificial hero bonuses, or disable threats.
- Replace the matrix's City profile with autonomous Settlement.
- Rebalance the entire game outside the observed causes or add a new test/display dependency without first proving existing headless/offscreen paths inadequate.

## Decisions

### D1: Measure completed effects at their authoritative source

For every role, trace the action from policy choice through the world service to the state change and report. Trade requires a committed transaction with before/after stocks; combat kills require the battle/world result to confirm a dead or removed enemy; collection uses the actual extracted resource id and amount; travel records visited terrain ids and arrival; City metrics read City and its shared ledger. Do not increment counters when an action is merely requested.

**Alternative:** infer success from AI intent, dialogue, damage, distance travelled, or score deltas. Rejected because these can report success without changing the game state.

### D2: Diagnose each role as an independent workstream

For each role, first record a deterministic trace showing available targets, chosen action, rejection/block reason, and authoritative outcome. Then fix the narrowest responsible layer and add a focused regression test before running the role's 11-cell matrix. Keep the six workstreams separate in implementation and reports so an improvement in one role cannot hide regressions in another.

**Alternative:** tune shared scores or thresholds until the aggregate table improves. Rejected because it can conceal broken interactions and does not satisfy the real-effect requirements.

### D3: Keep CityBuilder in the world City path

The builder profile continues using the existing world, hero, City and shared economy; the current city-level calculation remains authoritative. Inspect funding, building eligibility/placement, food and housing dependencies, growth, and level-up in that path. Settlement stays a separate simulation and is not used to meet this change's matrix thresholds.

**Alternative:** substitute an autonomous Settlement simulation. Rejected by the resolved decision in `autopilot-scenario-matrix`: it would remove the world/hero/shared-resource integration this matrix is intended to measure.

### D4: Separate the ten-seed survival cohort from the role matrix

Use ten fixed, versioned seeds for 60-turn survival measurements. Store per-seed turns survived, death cause/turn, survival-to-60 and actual interaction counters, plus aggregate survival count and mean. A death or missed threshold is a balance outcome/warning; only engine, MCP, report-format, or unrecoverable simulation failures are technical errors. Do not change threat, healing or hero values until traces identify the cause.

**Alternative:** retain one seed or fail the MCP run at the first death. Rejected: a single seed cannot establish the requested 8/10 rate, and treating death as infrastructure failure loses the balance evidence.

### D5: Keep verification off the user's interactive display

Run GdUnit in headless mode. For MCP tests that require a live renderer, use only an isolated virtual/offscreen display (for example, the project's existing Xvfb route) and verify it is not the user's active display. Never launch a visible foreground window as a fallback. If no safe offscreen backend is available, report the MCP/e2e portion explicitly as skipped/blocked with the reason; do not claim it passed and do not take focus or cursor control.

**Alternative:** use the normal desktop display because it is convenient. Rejected: it violates the explicit no-foreground/no-cursor requirement and can interrupt the user's work.

### D6: Preserve seed inputs and report schema compatibility

Keep the existing class/role seed derivation and add trace fields additively. Store the fixed ten-seed survival cohort in the report/config; identical input seeds and actions must reproduce identical traces and aggregates. Keep reports as ignored local artifacts unless repository policy specifically requires a checked-in fixture.

**Alternative:** randomize seeds per run or replace current metrics. Rejected because it prevents before/after comparison and destroys established matrix consumers.

## Risks / Trade-offs

- **Some role failures may originate in shared systems** → change shared mechanics only after a trace demonstrates the cause; run adjacent unit/integration tests and all affected roles.
- **Additional action evidence can enlarge reports** → record structured events and summary fields needed to diagnose the six outcomes, not full per-frame state.
- **A role threshold may remain unmet after one fix** → preserve the threshold, report the exact shortfall, and keep the change incomplete rather than tuning the metric down.
- **No isolated display may be installed on the current host** → never fall back to the foreground; mark only the affected live-MCP suite skipped with an explicit reason while still running safe headless tests.
- **Fixed ten-seed survival takes longer than one probe** → run it as a separate opt-in/long regression, not in the default fast unit suite.

## Migration Plan

1. Capture the current full matrix and 60-turn report as immutable before-state evidence; include seeds and actual role outcomes.
2. Verify the safe headless/offscreen test path before starting any live-MCP validation.
3. Implement and verify the Trader and Adventurer workstreams first, as their baseline action counters are zero.
4. Implement Collector, Traveler, and CityBuilder independently, preserving their current target definitions and checking focused tests before each affected role matrix.
5. Update the 60-turn report and run the ten-seed survival cohort; report gameplay warnings separately from technical errors.
6. Run the final 5×11 matrix and regression suites in hidden mode. Do not mark the change accepted until all role-specific and shared thresholds in the specs are met.

Rollback is limited to the individual behavior/reporting changes; retain baseline evidence and never revert by changing the acceptance thresholds.

## Baseline investigation: Trader

- The requested `game/tests/mcp/scenario_matrix.gd` entry point does not exist. The role matrix is driven by `game/tests/mcp/test_scenario_pilot_roles.py`; this host has no Xvfb/offscreen display, so live MCP is explicitly skipped. GdUnit can run headlessly.
- The preserved matrix baseline `game/tests/mcp/reports/scenario_matrix_20261008T061949Z.json` contains 55 unique-seed cells, no technical errors, and `deals: 0` in all 11 Trader cells. The long-probe baseline `game/tools/mcp/reports/balance_20260913.json` records seed `20260913`, death at turn 47, and 10 snapshots.
- A headless world run for Druid/Trader seed `1885368939` reproduced the zero-deal path. At turn 0 the city had no market; the hero remained away until returning to the center at turn 13. The market was still absent at turn 17 despite industry exceeding the market's 25-unit build cost. From the return onward `_needs_low()` stayed true. `TraderRole.act()` returns immediately while the market is absent, then `BalanceProbe._step()` handles low needs at the city by ending the turn before unloading the backpack or reaching `_try_build()`.
- `MarketSystem.trade()` is the actual city-stock transaction path; no NPC trader spawn is involved. The market API already mutates stock and industry and has unit coverage. Separately, `TraderRole._sell_order()` iterates only `MarketSystem.RATES`; the observed backpack goods (`gems`, `stone`, `wood`) are omitted even though `MarketSystem.trade()` supports a default rate for other resource ids.
- Root cause: role policy is gated on a market that the baseline action order fails to build once the hero returns to recover; even after construction, the fixed sell list excludes the observed gathered goods. The fix should address both gates and retain before/after transaction evidence.

## Trader implementation and post-fix verification

- `TraderRole` now attempts to build the city market before the base probe can spend the initial capital on its default building queue. When the hero carries saleable goods, the role routes back to the city before normal needs recovery can strand the cargo; after arrival it unloads and calls the real `MarketSystem.trade()` service.
- Trade accounting still requires both a stock decrease and an industry/gold increase, and stores before/after values per transaction. City food is excluded from the sale order to preserve the reserve. No goal or success threshold changed.
- Fighter seed `1086736233` exposed a shared spawn defect: the first walkable tile `(0, 0)` was isolated by impassable neighbors, so the hero could not move or return. `MapModel.find_spawn_cell()` now skips isolated walkable tiles and is shared by hero placement, reachable-cell calculation, threat placement, and BalanceProbe start-cell logic. A focused test covers the isolated-tile case.
- Controlled headless probes on the 11 fixed Trader class seeds stopped after the first deal or a terminal outcome; **11/11** produced at least one real deal (1–3 transactions, on turns 0–4). These are transaction checks, not a full 90-turn matrix run.
- The 60-turn Druid profile passed with at least 3 real deals. It did **not** reach the unchanged `gold_goal=1000`; that remains a separate balance criterion, not a reason to reduce the trade-count thresholds.
- The focused GdUnit suite passed 4/4 cases; the spawn unit suite passed 5/5, map-generator tests 9/9, and map-spawner tests 4/4. The complete 5×11 matrix has not been rerun.
- Live MCP remains blocked on this host because no safe isolated offscreen display is available; no MCP/UI process was launched on the user's display.
