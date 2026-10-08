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
## Baseline investigation: Adventurer

- Headless fixed-seed spawn probes were run for all 11 class/role pairs. Nine maps created the configured 20 enemy stacks, with 1–5 stacks in the Adventurer's city-relative ring; two did not: Barbarian seed `1481186023` had only 2 cells in the hero-connected region, Wizard seed `1070197613` had 17, and both had zero eligible enemy-spawn cells.
- On all nine maps with enemies, `AdventurerRole.enemy_target()` selected an in-ring stack, but `HeroMovementController.reach_problem(target)` returned `unreachable` at scenario start because the target was behind fog. The role considers global `enemy_stacks` without requiring visibility, while the enemy branch in `BalanceProbe._step()` retries direct movement and never calls `_explore_target()` when that path is blocked.
- Ranger seed `1057700285` was traced for 90 turns: 20 stacks remained, the selected target was `(12, 25)`, no battle/collision/win/loss event occurred, and kills remained 0. The hero started at `(0, 0)`, reached the city at `(10, 10)` around turns 51–52 during needs recovery, then remained there; the target path stayed unreachable. Thus the authoritative battle/death/kill chain was not entered in this trace; there is no evidence that kill accounting is the cause of the baseline zero.
- Code-path review confirms that `WorldBattleCoordinator` removes the enemy stack only after an attacker victory, then emits `battle_completed`/`battle_won`; `AdventurerRole` increments only from an attacker victory in its configured ring. This is downstream of the observed blocker and must be verified with an actual battle after reachability is fixed.
- Diagnosis: two independent blockers precede combat — some seeds select a tiny walkable component with no spawn candidates, and on maps with enemies the pilot does not explore through fog toward its hidden selected target. Do not tune kill counting or thresholds until the policy reaches a real battle.
- Diagnostics used headless GdUnit only; live MCP remains blocked without a safe isolated offscreen display, and the user's display/cursor were not touched.

## Adventurer implementation and post-fix verification

- `MapModel.find_spawn_cell()` now chooses the largest connected walkable component (not merely a non-isolated tile). This resolves the two previously reported seeds with tiny/immobile spawn regions. Regression coverage: MapModel 6/6, generators 9/9, spawner 5/5.
- Enemy threat tiers now use the known player-city center as their origin (falling back to the map spawn only before cities exist). This aligns the spawner's ring classification with `AdventurerRole`'s city-relative ring; Ranger seed `1057700285` now has skeleton/wraith/hobgoblin stacks in role ring 2 instead of the former ring-3 monsters.
- When a selected foe is hidden, the probe now walks to a reachable explored frontier and reveals onward instead of retrying an impossible direct path. The role tracks the selected `UnitStack` while it moves, prioritizes currently eligible ring-2 targets, and avoids armies after a confirmed loss.
- `battle_completed`'s ATTACKER/DEFENDER value is relative to battle setup, not necessarily the hero. A Ranger trace before this correction showed an ATTACKER result while the hero had actually lost and the enemy stack remained. Probe counters and role callbacks now use `GameEventBus.battle_won`/`battle_lost`; losses quarantine the cell from immediate re-engagement. The probe also finishes cleanly on hero death, reporting a gameplay outcome rather than dereferencing a freed hero.
- Focused tests verify defender-side outcome mapping and enemy-stack removal in `WorldBattleCoordinator`, role kill accounting only on `battle_won`, moving-target tracking, and loss-without-kill behavior. A separate fixed-seed Ranger trace confirmed a real ring-2 stack removal; the world-level probe is not used as a permanent GdUnit test because unrelated suite state made that integration seed non-repeatable when run after all preceding suites.
- Headless first-kill-or-terminal traces across the 11 fixed Adventurer class seeds yielded at least one confirmed role kill in **7/11**: Barbarian, Fighter, Monk, Paladin, Druid, Wizard, and Ranger. Priest, Cipher, Rogue, and Chanter ended without a role kill; some ended by hero death. These are targeted per-seed traces, not a complete 5×11 matrix run, and the unchanged `kill_goal=5` was not reached in those short probes.
- A separate 60-turn Ranger profile ended in `DEFEAT` on turn 47 (`unsuccessored_death`) with **1/5** kills and one recorded battle loss. At that stage the long-profile criterion and matrix threshold were unmet; the target-retention checkpoint below later reaches the matrix subcriterion, while the long-profile criterion remains open. No artificial hero bonus, threat suppression, or goal reduction was applied.
- Focused GdUnit results: Adventurer role behavior 2/2; BalanceProbe 2/2; WorldBattleCoordinator 18/18; MapModel 6/6; MapSpawner 5/5; map generators 9/9. Live MCP remains blocked because this host has no safe isolated offscreen display. One-shot Godot runs also print a separate `34 resources still in use at exit` warning; the focused GdUnit summaries report no errors, failures, or orphans.

## Adventurer target-retention checkpoint (2026-10-08)

- In a detached worktree based on `e28318f2`, the composite policy uses the unchanged `K=170` feasibility proxy, route cost for eligible in-ring targets (geometric lower-bound fallback under fog, HP tie-breaker), and retains an already selected `UnitStack` after it exits ring 2 only while it remains on the map, has not been lost, and still passes the same HP budget. No hero stats, threat levels, or kill goal were changed.
- Monk seed `1397225540` starts with 39 Goblins at `(19,3)`, `312 HP`; personal base damage is 5, so the unchanged budget is `850`. The same stack moves to `(14,1)`, crossing from distance 12 to 11 from the city center. Without retention the role clears the target; with retention it engages, receives `battle_won`, and the world removes the stack. A focused GdUnit assertion verifies both the role kill and stack removal.
- Two identical fixed-seed first-kill-or-terminal series produced **8/11** classes with a confirmed role kill: Barbarian `1481186023`, Fighter `80119704`, Monk `1397225540`, Paladin `1931611581`, Priest `665972471`, Druid `1059021645`, Cipher `2118222897`, Ranger `1057700285`. Wizard `1070197613`, Rogue `991894253`, and Chanter `119624935` had zero. Results were identical in both series.
- For successful cells, the diagnostic stops immediately after the first authoritative kill; zero-kill cells run to terminal outcome. Thus this verifies the matrix subcriterion (at least one kill in 8/11), not a complete 11-cell profile or `kill_goal=5`. Druid's first confirmed kill was on turn 3; it was intentionally not continued to terminal in this threshold probe.
- Wizard's observed battle is a city-defense override, not a pathfinding failure: city center `(13,12)`, adjacent threat `(12,13)`, and the pilot explicitly chose that threat while the role's ring-2 target was `(26,25)`. Chanter remains a separate enemy-turn interception (`(8,19)` → `(7,22)`, then attack at distance 1); a static safe route to its selected target existed. Neither behavior was altered by this checkpoint.
- The separate long-profile criterion was unmet on the target-retention-only checkpoint: Ranger seed `1057700285`, cap 60, terminated at turn 47 (`DEFEAT`, `unsuccessored_death`) with 1/5 role kills. The subsequent per-turn trace below corrects the apparent cause: the preceding battle left HP at 1, but the actual death event was exhaustion because city rest recovery was not wired. Target retention alone did not fix long-run survival.
- **Deferred balance debt:** `K=170` is still a heuristic; an earlier `K=230` cohort fell to 5/11. Keep K fixed for this checkpoint and track replacement with a better combat-feasibility model as a separate follow-up.

## Adventurer survival and REST integration follow-up (2026-10-08, isolated experiment)

- A per-turn/per-battle trace of the pre-fix Ranger long profile (`seed=1057700285`) disproved the initial “died from combat damage” interpretation. On probe turn 3, the hero lost one large battle to a Wraith at `(7,28)`: combat HP went **20 → 1** (`-19`), with `hp_scar=20`, `max_combat_hp=1`, and a five-turn wound. When the wound expired, max HP recovered to 21 but current combat HP remained 1; no out-of-combat combat-HP healing was found.
- The terminal death was `GameEventBus.hero_died("exhaustion")` at probe turn 46 / world turn 47, not a battle death. The hero had returned to the capital center `(10,10)` by probe turn 7, but `HeroController.city_manager` was null throughout the run. `WorldBootstrap._init_hero()` assigned `R.cities` before `_create_city_layer()` created the `CityManager`, so the hero never acquired the reference. `HeroNeedsComponent.end_turn()` consequently treated the hero as outside the city: REST fell by 0.01 per day to zero instead of recovering.
- Isolated fix: bind `R.hero.city_manager = R.cities` immediately after `_create_cities()` and remove the premature null assignment. A functional regression test verifies the reference and that REST rises while the hero stands on the capital center. REST and combat HP are distinct: this wiring fix does not itself heal combat HP.
- The single-process discrepancy was traced to persistent static `WorldSeasons._turns_in_season`, not to the scenario RNG. A Chanter profile reached turn 90 and left the counter at 90; a reloaded Rogue world with the same session/map seed (`map_seed=62838`) started at 90 and ended at turn 90 with 0 kills. After resetting seasons, the same Rogue seed/map started at 0 and recorded 1 kill at turn 14. `WorldBootstrap.run()` previously restored the counter only for loaded saves and never reset it for a new game.
- `WorldBootstrap.run()` now calls `WorldSeasons.reset()` only when no save was loaded; loaded games still restore their persisted counter through `WorldPersistence.apply_loaded_save()`. A functional bootstrap test simulates a prior 90-turn scenario and asserts the new world starts at season turn 0. Existing save/season round-trip tests continue to pass.
- After this fix, two complete fixed-seed Adventurer 11-class first-kill-or-terminal series were run sequentially in one headless Godot process, creating a fresh world for each cell. Every cell started with season turn 0; the repeated map seeds and outcomes were identical. Both series recorded **9/11**: Barbarian, Fighter, Monk, Paladin, Priest, Druid, Cipher, Ranger, and Rogue each recorded ≥1 role kill; Wizard ended in `DEFEAT` at turn 49 and Chanter reached turn 90 without a kill. Every successful cell also recorded at least one `enemy_stack_defeated` event after the coordinator removed the stack. This validates the same-process world-reload path headlessly; the full 5×11 MCP matrix was not rerun, and live MCP remains blocked without a safe offscreen display.
- The post-fix Ranger profile (`seed=1057700285`, 60-turn cap) reached the unchanged kill goal **5/5 at turn 37**, with the world still `RUNNING` and role metrics `survived=true`, `hp=1`. `WorldBattleCoordinator.enemy_stack_defeated` recorded six actual stack removals in that run; the five role kills therefore are not damage-only credit. The profile stopped at goal completion before the cap.
- These repeatable 9/11 and 5/5-by-turn-37 results meet Adventurer task 3.3 on the isolated experiment branch. `K=170`, `kill_goal=5`, hero stats, and threat levels were unchanged. The severe one-battle HP loss remains: the REST wiring fixes exhaustion at the capital but does not restore combat HP.
- Full-suite caveat on this macOS/Godot run: the same two long Trader integration tests fail after 30,000 frames on both clean `e28318f2` and the experiment branch (2291 vs. 2294 tests, six assertion failures in those two tests, zero runtime errors). The Trader suite passes 4/4 when run alone and after `test_scenario_pilot`; the full-suite divergence is reproducible on the clean base and persisted after the season-reset fix, but its exact trigger remains undiagnosed and is not attributed to the Adventurer patches. The separate `_FakeCity`/`City` Trader metrics fixture error was fixed in its own commit.
