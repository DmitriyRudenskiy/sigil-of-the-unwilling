## 1. Condition coverage
- [x] Add `condition` (using only `VALID_CONDITION_KEYS`) to a meaningful subset of spells (support/utility).
- [x] Do not change `cost`/`speed`/`params` of existing spells (preserve `norm()`).
- [x] Spell validator: no E310/E210/E211 for the new conditions.

## 2. Secondary-effect variety
- [x] Add `DEAL_DAMAGE` secondary effect to at least one spell with an empty `secondary_effects`.
- [x] Extend `APPLY_STATUS` values beyond `CHALLENGE` (BURN, FROZEN) on selected spells.
- [x] Re-differentiate any edited spell descriptions (idempotent `(…)` rule) to keep `norm(c)` unique.

## 3. HEAL_CLEAR / REVIVE / PORTAL templates
- [x] Add `HEAL_CLEAR`, `REVIVE`, `PORTAL` templates to the spellbook template registry (move from battle-only `BattleSpellBridge` exposure into the template engine).
- [x] Wire each template into at least one spellbook template and one spell.
- [x] Unit test: the three templates are present and usable.

## 4. Speed-curve rebalance
- [x] Split a portion of the `fast` spells to other valid `speed` values so no single value exceeds 70% (fast 69.1%, slow 15.9%, burst 15.0%).
- [x] Re-differentiate every changed spell (speed is part of `norm()`) to avoid norm-dup; run `differentiate_spells.py`.
- [x] Spell validator: W924 warning resolved; no uniqueness errors.

## 5. Validation + tests
- [x] Run `--path game -s $PWD/game/tools/spell_validation/validate_spells.gd --strict --json` green (0 errors, 0 warnings, 1 info I922).
- [x] Run spell-relevant CI steps green: compile_all (0), check_scene_refs (0), unit tests (5471 passed, 0 failed). Full `run_all_ci_checks.sh` has a pre-existing out-of-scope console_clean failure (locked-object SCRIPT ERROR, committed HEAD state).
- [x] Add/adjust unit tests (conditions, secondary effects, templates, speed distribution).

## 6. Docs + commit
- [x] Document the depth additions in `docs/` (19 templates, speed rebalance, resolved warnings).
- [x] Commit scoped to `spells.json` + affected `.gd`/tool files.
