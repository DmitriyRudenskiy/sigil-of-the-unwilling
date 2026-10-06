# Tasks

## 1. Construction request and payment

- [ ] 1.1 Add construction request validation for audited catalog entry, prerequisites, costs, and 52-hex placement; verify valid and rejected requests with focused GdUnit4 tests, including no mutations on failure.
- [ ] 1.2 Commit accepted costs once through the city's shared `ResourceContext` and create a persisted in-progress instance; verify exact ledger flow and atomic resource balances.

## 2. Turn progress and eligibility

- [ ] 2.1 Advance each in-progress instance once in the established scheduler order and activate only at zero remaining turns; verify deterministic zero-/multi-turn cases and phase ordering.
- [ ] 2.2 Suppress production, upkeep, class training, and static defense during construction; verify active/inactive/ruined behavior with focused GdUnit4 tests.

## 3. Persistence and integration

- [ ] 3.1 Round-trip in-progress instances through city saves and load legacy instances without synthesizing progress or spending resources; verify migration idempotence.
- [ ] 3.2 Add a deterministic construction-to-production scenario using audited catalog entries and shared ledger; verify reproducibility and run `game/run_tests.sh`.
