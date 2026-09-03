## 1. Battle logic: `apply_sacrifice`
- [ ] Add `static func apply_sacrifice(state, acting, sacrifice, target, cost, rng) -> Dictionary` to `systems/BattleActionResolver.gd`.
- [ ] Validate acting/target alive and cost available; return non-success without mutation on failure.
- [ ] On success: `target.set_count(0)` + `state.kill_unit(target)` (bypass rebirth); consume cost; set `acting.has_moved = true`; `invalidate_board_cache` + `check_end`.
- [ ] Unit test: valid sacrifice finishes off a strong enemy and kills it.
- [ ] Unit test: sacrifice rejects a dead target and an unavailable cost.
- [ ] Unit test: sacrifice kills a `rebirth`-tagged enemy without rebirth.
- [ ] Unit test: follower-stack / resource / artifact costs are each consumed on resolve.

## 2. Turn/executor wiring
- [ ] Add `execute_sacrifice(acting, target, cost)` signal to `systems/BattleTurnExecutor.gd`.
- [ ] Add an executor path that invokes `apply_sacrifice` and emits the signal.
- [ ] Unit test: executor applies sacrifice and emits the signal.

## 3. UI (player-facing)
- [ ] BattleUI: select cost → select target → confirm sacrifice; gate by one-action-per-turn.
- [ ] `BattleView` renders the sacrifice (cost consumed + target death animation).
- [ ] Headless scenario: sacrifice resolves end-to-end.

## 4. Tests + validation
- [ ] Add/adjust unit tests under `tests/`.
- [ ] Run `run_all_ci_checks.sh` green.

## 5. Docs + commit
- [ ] Document the mechanic in `docs/`.
- [ ] Commit scoped to changed files.
