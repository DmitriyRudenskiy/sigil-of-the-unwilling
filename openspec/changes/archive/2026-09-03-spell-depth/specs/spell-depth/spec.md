---
description: "Requirements for spell-system depth: condition coverage, widened secondary effects, HEAL_CLEAR/REVIVE/PORTAL templates, and speed-curve variety."
---

## Purpose

Adds depth to the spell system through meaningful conditions, widened secondary
effects, three new spellbook templates (HEAL_CLEAR, REVIVE, PORTAL), and a
less-dominated speed curve.

## ADDED Requirements

### Requirement: Spells carry conditions
The spell set **MUST** use the `condition` field meaningfully. After the change, a meaningful share of spells **MUST** carry a `condition` (a Dictionary validated by the spell validator's `VALID_CONDITION_KEYS`), so that spells trigger only under specific circumstances rather than unconditionally.

#### Scenario: A spell has a condition
- **Given** a spell with `condition: {"target_is_damaged": true}`
- **When** the spell validator runs
- **Then** the condition is accepted (E310 not raised) and the spell can only resolve against a damaged target

#### Scenario: Numeric condition is validated
- **Given** a spell with `condition: {"target_hp_max": 30}`
- **When** the spell validator runs
- **Then** the numeric condition is accepted and the spell is gated to targets with HP ≤ 30

### Requirement: Secondary effects are varied
The `secondary_effects` array **MUST** use more than the current ~4 patterns. In particular the valid-but-unused `DEAL_DAMAGE` secondary effect **MUST** appear in at least one spell, and status secondary effects **MUST** extend beyond `APPLY_STATUS:CHALLENGE`.

#### Scenario: DEAL_DAMAGE secondary effect is used
- **Given** a spell with `secondary_effects: [{"effect": "DEAL_DAMAGE", "count": 2}]`
- **When** the spell validator runs
- **Then** `DEAL_DAMAGE` is accepted (E312 not raised)

#### Scenario: Status secondary effects extend beyond CHALLENGE
- **Given** a spell with `secondary_effects: [{"effect": "APPLY_STATUS", "status": "BURN"}]`
- **When** the spell validator runs
- **Then** the status is accepted and differs from the prior CHALLENGE-only usage

### Requirement: HEAL_CLEAR / REVIVE / PORTAL templates exist in the spellbook
The spellbook **MUST** include working templates for `HEAL_CLEAR`, `REVIVE`, and `PORTAL` (previously present only in `BattleSpellBridge`), so the spellbook can express healing-clear, resurrection, and displacement.

#### Scenario: HEAL_CLEAR template is available in the spellbook
- **Given** the spellbook template registry
- **Then** a `HEAL_CLEAR` template is present and usable by a spell

#### Scenario: REVIVE and PORTAL templates are available
- **Given** the spellbook template registry
- **Then** `REVIVE` and `PORTAL` templates are present and usable by spells

### Requirement: Speed curve has variety
The `speed` distribution **MUST** not be dominated by a single value. After the change, no single `speed` value **MUST** exceed ~70% of all spells; the 64 non-`fast` spells currently present **MUST** be spread across additional valid speed values.

#### Scenario: No single speed dominates
- **Given** the spell set after the change
- **Then** the most common `speed` value covers ≤ 70% of all spells

#### Scenario: Additional speed values are valid
- **Given** a spell with a `speed` value outside the prior {slow, fast} usage
- **When** the spell validator runs
- **Then** the speed is accepted (within `VALID_SPEEDS`)
