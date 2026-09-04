# test-factory-helpers Specification

## Purpose

Provide shared, deterministic factory helpers for tests so that test files no longer each redefine their own hero/follower/city builders, while keeping every test's behavior unchanged.

## Requirements

### Requirement: Shared factory helpers exist

A shared test helper module SHALL expose `make_hero`, `make_follower`, and `make_city` factory functions usable by any test file.

#### Scenario: A test uses the shared helper
- **WHEN** a test calls the shared `make_city` helper
- **THEN** it obtains a city with the same starter state the previous local helper produced

### Requirement: Factories are deterministic

The helpers SHALL produce the same objects across runs (seeded RNG, fixed starter population) so existing assertions hold.

#### Scenario: Repeated factory calls are stable
- **WHEN** `make_hero` is called twice with the same arguments
- **THEN** the resulting heroes are equivalent for the purposes of existing tests

### Requirement: Local redefinitions are removed

Existing per-file `_make_follower`, `_make_hero`, and `_make_city` definitions SHALL be removed in favor of the shared module, without changing any test outcome.

#### Scenario: No duplicate local factories remain
- **WHEN** the test suite is searched for local factory definitions
- **THEN** only the shared module defines them and all tests still pass
