---
description: "Add depth to the core spell system: use conditions, drop the dead influence_req field, widen secondary-effect templates, rebalance the speed curve, and bring HEAL_CLEAR/REVIVE/PORTAL into spellbook templates."
---

## Why

The spell system is the heart of the game's variability ("spell × weapon × skill × traits"). But it is shallow and partly broken: only **22 of 505 spells (~4.4%) carry a `conditions` clause** (13 condition types), the **`influence_req` field is dead** (used by 0 spells, absent from the schema/validator), **secondary effects collapse to ~4 patterns** (`DRAW`, `HEAL_NEXUS`, `APPLY_STATUS:CHALLENGE`; `DEAL_DAMAGE` unused), the **speed curve is 87% "fast"** (W924 → near-zero speed variety), **multifaction/colorless spells sit at 0/1 cost** (W922), and **HEAL_CLEAR / REVIVE / PORTAL exist only in `BattleSpellBridge`, not in any of the 16 spellbook templates** — so the spellbook can never express them. This is exactly the "main gap = system depth" the user named.

This change deepens the spell system without breaking balance: it (a) fills the `condition` field across spells (currently 0/505), (b) widens `secondary_effects` (currently only DRAW/HEAL_NEXUS/APPLY_STATUS:CHALLENGE; `DEAL_DAMAGE` is valid but unused), (c) adds status variety and the HEAL_CLEAR/REVIVE/PORTAL templates (0 in spells.json, only in `BattleSpellBridge`), (d) rebalances the speed curve (currently 441 fast / 64 slow ≈ 87% fast), and (e) wires the missing templates into the 16 spellbook templates.

## Proposed Change

Purely additive/refactoring work on `game/data/spells.json`, the spell templates, and the validator/schema — **no numeric parameter changes to existing spells** (so `norm()` is unchanged and the spell validator / balance stay green). This is the "safe description-level" approach already proven in the spell-differentiation commit (`fc988ae`).

## Scope

- **In:** `condition` coverage, widened `secondary_effects` (incl. `DEAL_DAMAGE` + status variety), HEAL_CLEAR/REVIVE/PORTAL templates wired into spellbook, speed-curve rebalance.
- **Note:** `influence_req` is a spellbook-template field (`SpellbookDef`) used by `SpellResolver`; it is not a per-spell field, so no per-spell removal is needed — this change keeps it spellbook-scoped.
- **Out:** battle spell resolution depth (`SpellRegistry`, 20 battle spells) unless a template needs it; the god/faith layer is out of scope.
