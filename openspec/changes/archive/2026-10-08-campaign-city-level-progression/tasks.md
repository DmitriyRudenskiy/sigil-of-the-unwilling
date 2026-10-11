# Tasks

## 1. Enforce campaign building-cell progression

- [x] 1.1 Add one campaign progression helper for the 11-level cell-cap table and unique occupied-cell counting; verify exact caps, multi-cell footprints, starting structures, in-progress structures, and ruins with focused GdUnit4 tests.
- [x] 1.2 Reject construction that exceeds the current cap before any resource transaction; verify the full-city rejection leaves the ledger and building state unchanged, and level 11 permits at most 52 occupied cells.
- [x] 1.3 Gate campaign level-up on a full current allowance and preserve legacy prosperity level-ups; verify blocked, successful, maximum-level, and legacy paths.

## 2. Expose progression in the campaign city

- [x] 2.1 Show campaign level and occupied/max cells in the HUD, provide an accessible level-up action, and explain blocked construction/level-up; verify button state, text, and no-write behavior in CityScreen tests.

## 3. Reconcile balance and verify

- [x] 3.1 Replay explicit level-up actions in the deterministic 21-day balance itinerary; verify the selected plan remains affordable, reaches the correct level, and its report is reproducible.
- [x] 3.2 Run focused progression/construction/UI/balance tests, full `game/run_tests.sh`, strict OpenSpec validation, docs-link checks, and `git diff --check`; resolve failures and record any environment skip explicitly.
