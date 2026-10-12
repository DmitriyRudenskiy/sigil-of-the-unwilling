---
title: "Draft: upstream issue gdUnit4 — silent no-op assert without check method"
tags: [mvp, testing, upstream]
status: draft
date: 2026-10-13
---

# Черновик issue в [MikeSchulze/gdUnit4](https://github.com/MikeSchulze/gdUnit4)

**Status:** черновик; публикация отложена (нет токена для upstream; репо приватный,
владелец опубликует вручную). Трекается в [[TICKETS]] T-123.

## Title

`assert_that(value)` / `assert_bool(value)` without a check method passes silently — please warn or fail

## Body

`assert_that()` (and the typed `assert_*` family) return an assert object but
perform **no verification** until a check method (`is_true()`, `is_equal()`, …)
is chained. A test that ends the statement at the assert object is **always
green**:

```gdscript
func test_something() -> void:
    assert_that(false)          # PASSES — no check method, no failure
    assert_bool(1 == 2)         # PASSES — same
    assert_that(x == y).override_failure_message("...")  # PASSES — message
                                                # is not a check
```

We discovered this class in a real suite: **201 vacuous assertions across 24
test files**, all green for the entire lifetime of the codebase, several
hiding genuine bugs (off-by-one in game rules, wrong expected constants,
int-vs-float JSON comparisons).

The pattern `assert_that(x == y).override_failure_message(msg)` reads as a
complete assertion and is an easy mistake; the failure mode (permanently green)
is the worst possible for a test framework.

**Proposal:** track on the assert object whether a check method was called; in
`GdUnitAssert` finalization (or suite teardown), emit a warning — or, behind a
project setting, a test failure — for asserts that performed no check. A static
hint in the docs for `assert_that` ("must be followed by a check method") would
also help.

Environment: Godot 4.7.x, gdUnit4 (vendored build, 4.x).
