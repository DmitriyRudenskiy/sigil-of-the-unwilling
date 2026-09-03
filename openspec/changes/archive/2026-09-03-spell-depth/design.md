## Context

`game/data/spells.json` holds 505 spell entries with keys `id, name, template, speed, cost, color, params, description`. The validator (`tools/spell_validation/SpellValidator.gd` / `validate_spells.gd`) enforces required fields, `VALID_CONDITIONS`/`VALID_SPEEDS`/`VALID_COLORS`, `condition` (Dictionary), `secondary_effects` (Array), `norm(c)` uniqueness, and balance warnings (W922 multifaction/colorless cost, W924 speed). Confirmed current state:
- `condition` field: **0/505** spells use it (validator supports `VALID_CONDITION_KEYS`: numeric `target_hp_max/target_cost_max/hand_size_max/spell_cost_max/discard_cost/min_ally_count`; bool `target_is_damaged/target_is_flying/attacker_unblocked`).
- `secondary_effects`: **501 None, 2 DRAW, 1 HEAL_NEXUS, 1 APPLY_STATUS:CHALLENGE**; `DEAL_DAMAGE` is valid but unused.
- `speed`: **441 fast, 64 slow** (≈87% fast).
- `HEAL_CLEAR`/`REVIVE`/`PORTAL`: **0** in spells.json — only in `data/BattleSpellBridge.gd`.
- `influence_req`: a **spellbook-template** field (`SpellbookDef`), used by `SpellResolver` — correctly spellbook-scoped, not a per-spell field.

## Design

**Safe, description-level, balance-preserving.** Per the proven `fc988ae` approach: do **not** change `cost`/`speed`/`params` of existing spells (so `norm()` and the balance warnings stay green). Instead:

1. **Condition coverage:** add `condition` to a meaningful subset of spells (e.g. utility/support spells), using only `VALID_CONDITION_KEYS`. This changes spell *behavior gating*, not `norm()` (condition is not part of norm).
2. **Secondary-effect variety:** add `DEAL_DAMAGE` and additional `APPLY_STATUS` values to spells that currently have empty `secondary_effects`; these are new entries/edits that keep `norm()` unique (differentiation rules from `fc988ae` still apply — append `(…)` if a description would otherwise collide).
3. **HEAL_CLEAR/REVIVE/PORTAL templates:** add these templates to the spellbook template registry (currently in `BattleSpellBridge`) and wire them into spellbook templates + a few spells.
4. **Speed rebalance:** split a portion of the 441 `fast` spells into other valid `speed` values so no single value exceeds 70%. This is a `speed` change, so it **does** touch `norm()` — each changed spell must be re-differentiated (description-level) to keep `norm(c)` unique.

**Grounding facts (files):**
- `game/data/spells.json` — the spell data.
- `tools/spell_validation/SpellValidator.gd` / `validate_spells.gd` — validator + `VALID_*` tables.
- `data/BattleSpellBridge.gd` — current home of HEAL_CLEAR/REVIVE/PORTAL.
- `data/SpellbookDef.gd` / `TemplateEngine.gd` / `TemplateBootstrap.gd` — spellbook templates.
- `game/tools/differentiate_spells.py` — the differentiation tool (re-run after edits).

## Risks / Trade-offs

- **Speed rebalance touches norm():** changing `speed` changes `norm()`, so differentiated descriptions must be refreshed to avoid norm-dup. Run the differentiation tool after.
- **Balance:** keep cost/params of existing spells fixed; depth comes from gating (conditions) and template availability, not power creep.
- **HEAL_CLEAR/REVIVE/PORTAL in battle vs spellbook:** these were battle-only; exposing them in the spellbook may need battle resolution support — scope the spellbook wiring to what the template engine already supports, and flag battle integration as a follow-up.
