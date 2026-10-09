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
- A separate 60-turn Ranger profile ended in `DEFEAT` on turn 47 (`unsuccessored_death`) with **1/5** kills and one recorded battle loss. Thus the long-profile criterion and matrix threshold remain unmet; no artificial hero bonus, threat suppression, or goal reduction was applied.
- Focused GdUnit results: Adventurer role behavior 2/2; BalanceProbe 2/2; WorldBattleCoordinator 18/18; MapModel 6/6; MapSpawner 5/5; map generators 9/9. Live MCP remains blocked because this host has no safe isolated offscreen display. One-shot Godot runs also print a separate `34 resources still in use at exit` warning; the focused GdUnit summaries report no errors, failures, or orphans.

## Calibration-only committed baseline control (2026-10-09)

- On `fix/world-session-baseline`, committed only calibrated target values and seed multiplier in `game/scripts/data/scenario_targets.gd` (`rare_goal=10`, `biome_goal=2`, `population_goal=8`, `buildings_goal=2`, hash multiplier `947`). Adventurer/Trader goals remain unchanged. Calibration commit: `2c3e8848`, pushed to `origin/fix/world-session-baseline`. `test_scenario_pilot.gd`: 14 cases, 0 errors/failures, 17 orphan warnings (exit 101, orphan-only).
- The first target-only 44-cell control, before RNG wiring was audited, exposed a non-repeatable runtime: two Wizard/Trader runs with the same seed `1490911174` and 90 turns finished at industry 154 versus 212. The City charisma event differed at turn 35. `CharismaEvents._rng` was an unseeded static RNG; `MigrationProcessor.set_cha_rng()` had no production caller. This first control and the earlier overlaid 44-cell report are provisional, not authoritative deterministic baselines; do not attribute their outcome differences solely to the omitted role files or to the `947` seed multiplier.
- Fixed the common RNG wiring separately, without role-policy or balance changes. Commit `efd508a6` seeds charisma events from the session RNG; `98e96478` also wires `ReputationSystem`, `CityService` recruitment and `WeaponTechService` RNGs, and adds a bootstrap regression. Tests: `test_world_bootstrap.gd` 8/8, `test_charisma_events.gd` 9/9, `test_city_tech_tree.gd` 10/10, `test_weapon_tech.gd` 25/25. Two Wizard/Trader repeats then matched at industry 154, 130 real deals, turn 90.
- Ran the 44 open-role cells twice from committed, target-only source after RNG seeding, as separate headless processes with fresh worlds and fixed class/role seeds. The second 44-cell report matched the first exactly for seed, turn/frame counts, goals, metrics, interactions and end state. No runtime errors occurred. Both runs hit the temporary 30,000-frame safety cap only in Traveler/Druid and Traveler/Chanter (still `RUNNING`, turns 8 and 16); these are incomplete gameplay/policy paths, not technical failures or successes. Adventurer was not included in this open-role control.
- Final calibration-only results on `98e96478`: Collector **11/11**; Traveler **7/11** (Paladin and Wizard ended in DEFEAT; Druid and Chanter did not complete before the frame cap); CityBuilder **3/11** (Monk, Paladin, Cipher); Trader **0/11** at industry 1000, with **11/11** profiles recording confirmed non-food transactions (**547 total**), final industry **0–187**, and **4/11** surviving. The Builder acceptance was checked externally as population ≥8, level ≥2, buildings ≥2; the clean-branch `BuilderRole.goal_met()` still checks level/buildings and can stop early (Chanter stops at population 7). The dirty overlay's population gate is a separate role change, not part of this calibration-only baseline.
- Audit of the five overlay files confirms they were not a pure target snapshot: besides `ScenarioTargets.gd`, `TravelerRole.gd` adds the biome gate/final-cell terrain to metrics; `BuilderRole.gd` switches its completion gate from building count to population; `TraderRole.gd` adds only a `City` type guard; and `balance_probe.gd` changes battle target selection and ranged line-of-sight checks. The older overlay-based 44-cell counts remain historical experiment results; exact behavioral attribution is not isolated because those runs also lacked the now-fixed RNG wiring.

## Trader target semantics, income, costs and survival trace (2026-10-09)

- `TraderRole.goal_met()` compares `gold_goal` to `city.storage[&"industry"]`; `TraderRole.metrics()["gold"]` reports that same industry value; and `MarketSystem.trade()` credits the same field. Thus the goal and reported number are numerically aligned, and real sales increase the target bucket. The naming remains semantically ambiguous: `CityFactory` starts industry at **30** and separately initializes actual `ResourceContext` gold at **5**. The Trader goal is therefore an industry/capital target, not the separate gold resource. At the pre-experiment baseline, `gold_start=100` did not match the starting industry, so `margin` was not a true start-to-current delta; the follow-up changes it to 30 without changing the goal or resource bucket.

- Wizard/Trader seed `1490911174`, fixed 90-turn profile: start industry 30; **130** confirmed deals sold 303 units (mercury 5, ore 4, stone 140, wood 154) for **866.601** gross industry. Base city industry yield was **0**; prosperity bonuses added **380.280**; a merchant-caravan event added **10**. Seven unrepelled raids removed **295.513** at the configured 30% pillage rate. The city built 42 buildings for **837** total (40 duplicate Barracks ×20, one Market, one Farm). Net: `30 + 866.601 + 380.280 + 10 - 295.513 - 837 = 154.368`, reported as integer industry 154. This reconciles the final metric; the trade path itself is active, but the goal measures treasury after city actions and losses.
- Druid/Trader seed `1885368939` died at turn 41 by `hero_died("exhaustion")`, with REST 0 at `(31,8)` away from the city; it had one battle win and no losses. Its 11 deals yielded **91.64**, passive industry yield was 0, prosperity added **102.93**, a city event added 10, raids removed **45.19**, and 10 constructions cost **189**; final industry was **0.372** (reported 0). Across the seven dead Trader profiles, all seven deaths were exhaustion with REST 0; none died from battle damage. Priest and Ranger had earlier battle losses (7 and 12 respectively) but still died later from exhaustion. The four survivors and seven deaths match the fixed-seed matrix.
- The major industry sink is the shared `BalanceProbe` build queue: it repeatedly constructs Barracks (the building does not provide raid defense), while `CityService.defense_strength()` counts militia, Walls, specialization and campaign defense. The queue does not build Walls; the observed raids were unrepelled. No periodic industry upkeep was found in the write paths; the measured loss comes from construction, raids, plus event/resource flows. Separately, low-needs routing does not reliably leave the hero on the exact city-center cell long enough to recover REST; the Druid trace below localizes a premature route-abort after movement points refresh. No survival fix has been applied.

- Next Trader work should keep `gold_goal=1000` and the current `industry` bucket intact while addressing (a) role-inappropriate repeated construction and raid exposure, and (b) reliable return to the exact city center before REST reaches zero. Keep these as separate policy/survival diagnoses; do not conflate them with confirmed trade counts. Live MCP remains blocked without a safe isolated offscreen backend.

## Trader build-policy experiment and REST-route localization

- The shared `BalanceProbe.BUILD_QUEUE` is exactly `[barracks, market, farm, range]`; Walls are not a candidate. `TraderRole` already constructs the Market itself. Separately, `CityBuildingService.can_build_building()` rejects a building until `city.level >= def.min_city_level`; Walls require city level **5**. The fixed Wizard/Trader profile starts at level 1 and reaches only level **2** (population **3**) by turn 90, so simply adding Walls to an early queue cannot protect this profile.
- A provisional `ScenarioPilot._try_build()` override makes the Trader target Walls only when unlocked and only until defense reaches the maximum configured raid strength (**15**); the shared queue remains the fallback for non-Trader roles. `gold_start` is corrected from 100 to the actual starting industry **30**; `gold_goal=1000` and the `industry` bucket are unchanged.
- One instrumented Wizard/Trader run on seed `1490911174` ended at turn 90 with one Market, no Barracks or Walls, city level 2/population 3, **112** confirmed deals, industry **289.819**, margin **259**, defense 0 and **9/9** raids unrepelled; goal not met. The queue stopped Barracks spam, but Walls remained locked and industry stayed far below 1000. The result also differs from the prior 130-deal/seven-raid run, so the baseline arithmetic is not a fixed counterfactual once action order changes. Do not expand this policy to all Trader seeds until Wall availability or an eligible defense path is resolved.
- The 11-cell CityBuilder control under the provisional branch matched the committed target-only baseline exactly for every class, including outcomes and metrics. External acceptance remains **3/11** (Monk, Paladin, Cipher); Chanter still ends at population 7 and is not a success. This confirms no Builder regression from the role-gated override.
- A headless movement trace for Druid/Trader seed `1885368939` localized the return failure. The low-need trigger is active, the target is the correct player-city center `(10,10)`, and at turn 39 the hero starts moving home. At turn 40 the hero is at `(14,10)`, REST 0, with 0 MP. `_walk_to(center)` ends a turn, refreshes movement to 10 MP, and `reach_problem(center)` becomes empty, but then returns false solely because the hero's cell did not change during that just-ended turn. The caller treats the home route as failed, selects exploration frontier `(25,0)`, and eventually the hero moves out to `(31,8)` and dies of exhaustion on turn 41. The defect is the no-cell-advance early return in `_walk_to()`, not a missing low-REST trigger or wrong center. No survival fix was applied in this experiment.
- Traveler/Druid and Traveler/Chanter still hit the frame cap without terminal outcomes. A separate diagnosis task is recorded below; these cells remain incomplete, not successes or technical failures.
