# Archetype relations (task 2.2)

## Scope and source handling

The matrix operates on the seven canonical campaign archetypes only, never on ancestry. `docs/02f-a-core.md` §4.1 contains an older draft friendship/antipathy graph using short aliases (`Водники` = Торговцы & Дипломаты; `Следопыты` = Охотники & Следопыты; `Воины` = Алхимики & Хранители Пламени; `Мистики` = Ткачи & Ремесленники). It is used only as a source of candidate directions: its changing relationships, race-level effects, random quarrels, and unbounded consequences are not imported. The source AtS species data has no pair-affinity mechanic, so no AtS relationship values are claimed.

The table below is the campaign's explicit, symmetric, bounded design. Positive/negative magnitudes are small campaign units, not the old draft's mood/production percentages. An omitted distinction is explicitly neutral (`0`).

## Complete pair matrix

| Archetype | Engineers | Farmers | Alchemists | Weavers | Traders | Hunters | Metallurgists |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Engineers & Builders** | 0 | +1 | 0 | -2 | +2 | -1 | 0 |
| **Farmers & Brewers** | +1 | 0 | -1 | 0 | +1 | 0 | 0 |
| **Alchemists & Flamekeepers** | 0 | -1 | 0 | -2 | -2 | +1 | +2 |
| **Weavers & Crafters** | -2 | 0 | -2 | 0 | 0 | +2 | -1 |
| **Traders & Diplomats** | +2 | +1 | -2 | 0 | 0 | -2 | 0 |
| **Hunters & Trackers** | -1 | 0 | +1 | +2 | -2 | 0 | +2 |
| **Metallurgists & Technicians** | 0 | 0 | +2 | -1 | 0 | +2 | 0 |

The matrix contains all 21 distinct cross-group pairs, is symmetric, and has no value outside `[-2, +2]`. `0` means no declared affinity, not an exclusion. No affinity changes job eligibility, ancestry mapping, housing eligibility, training access, or migration eligibility.

## Mitigation and deterministic effect

- **Where it applies:** only when residents of two archetypes share the same staffed workplace during a turn. Merely living in the same city or occupying adjacent hexes does not trigger a pair effect; neighborhood effects belong to the separate placement rules.
- **Raw effect:** each co-working archetype pair contributes its matrix value to both groups' satisfaction delta for that turn.
- **Bound:** sum a group's pair contributions, clamp the total relationship contribution to `[-2, +2]` per turn, then combine it with the need-response change from [`archetype-profiles.md`](archetype-profiles.md) and clamp satisfaction to `[0, 100]`. Resolve pairs in stable archetype-ID order; integer addition makes output independent of container iteration order.
- **Mitigation service:** an active building may declare `community_mediation` capacity and a set of served archetypes. A service-capacity point may mitigate at most one pair per turn. Process negative co-working pairs in stable archetype-ID order; if an active provider serves both archetypes and has unused capacity, spend one point and move that pair's value one step toward zero (`-2 → -1`, `-1 → 0`). Never turn tension into synergy or reuse capacity. No provider leaves raw tension unchanged. The service is capacity, not a currency; any recipe inputs still use only registered resources.
- **Provider link:** the unified building catalog must identify a canonical building/provider role for `community_mediation`, or explicitly leave it unavailable in the MVP catalog. No source building is assumed to provide it before task 3.1's source/capacity audit.
- **Auditability:** the turn ledger/UI reports each active pair, raw value, mitigation provider (if any), and final contribution. There is no random fight, relationship drift, permanent ancestry effect, or hidden hard job/race restriction.

## Completion audit

- All seven diagonal entries and 21 distinct pairs are explicit; the symmetric table is bounded.
- Every non-neutral value has a bounded deterministic effect; neutral pairs contribute zero.
- Tension has one explicit, bounded mitigation service and provider-resolution rule; lack of a provider leaves raw tension unchanged.
- Pair effects are workplace-only, ancestry-independent, and never restrict jobs or residents.
