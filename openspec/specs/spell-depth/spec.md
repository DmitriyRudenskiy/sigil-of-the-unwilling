# spell-depth Specification

## Purpose

Adds depth to the spell system through meaningful conditions, widened secondary
effects, three new spellbook templates (HEAL_CLEAR, REVIVE, PORTAL), and a
less-dominated speed curve.

## Requirements

### Requirement: Spells carry conditions
The spell set SHALL use the `condition` field meaningfully. After the change, a
meaningful share of spells SHALL carry a `condition` (a Dictionary validated by
the spell validator's `VALID_CONDITION_KEYS`), so that spells trigger only under
specific circumstances rather than unconditionally.

#### Scenario: A spell has a condition
- **WHEN** the spell validator runs on a spell with `condition: {"target_is_damaged": true}`
- **THEN** the condition is accepted (E310 not raised) and the spell can only resolve against a damaged target

#### Scenario: Numeric condition is validated
- **WHEN** the spell validator runs on a spell with `condition: {"target_hp_max": 30}`
- **THEN** the numeric condition is accepted and the spell is gated to targets with HP ≤ 30

### Requirement: Secondary effects are varied
The `secondary_effects` array SHALL use more than the prior ~4 patterns. In
particular the valid-but-unused `DEAL_DAMAGE` secondary effect SHALL appear in at
least one spell, and status secondary effects SHALL extend beyond
`APPLY_STATUS:CHALLENGE`.

#### Scenario: DEAL_DAMAGE secondary effect is used
- **WHEN** the spell validator runs on a spell with `secondary_effects: [{"effect": "DEAL_DAMAGE", "count": 2}]`
- **THEN** `DEAL_DAMAGE` is accepted (E312 not raised)

#### Scenario: Status secondary effects extend beyond CHALLENGE
- **WHEN** the spell validator runs on a spell with `secondary_effects: [{"effect": "APPLY_STATUS", "status": "BURN"}]`
- **THEN** the status is accepted and differs from the prior CHALLENGE-only usage

### Requirement: HEAL_CLEAR / REVIVE / PORTAL templates exist in the spellbook
The spellbook SHALL include working templates for `HEAL_CLEAR`, `REVIVE`, and
`PORTAL` (previously present only in `BattleSpellBridge`), so the spellbook can
express healing-clear, resurrection, and displacement.

#### Scenario: HEAL_CLEAR template is available in the spellbook
- **WHEN** the spellbook template registry is inspected
- **THEN** a `HEAL_CLEAR` template is present and usable by a spell

#### Scenario: REVIVE and PORTAL templates are available
- **WHEN** the spellbook template registry is inspected
- **THEN** `REVIVE` and `PORTAL` templates are present and usable by spells

### Requirement: Speed curve has variety
The `speed` distribution SHALL not be dominated by a single value. After the
change, no single `speed` value SHALL exceed ~70% of all spells; the non-`fast`
spells SHALL be spread across additional valid speed values.

#### Scenario: No single speed dominates
- **WHEN** the spell set after the change is evaluated
- **THEN** the most common `speed` value covers ≤ 70% of all spells

#### Scenario: Additional speed values are valid
- **WHEN** the spell validator runs on a spell with a `speed` value outside the prior {slow, fast} usage
- **THEN** the speed is accepted (within `VALID_SPEEDS`)
