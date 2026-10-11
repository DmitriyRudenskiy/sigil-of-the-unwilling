# Against the Storm official-wiki data cross-check

**Purpose:** verify source identities, buildable categories and display-name variants against a dated game-data snapshot. This supplements the 2026-10-04 Fextralife/database inventory; it does not claim to be the complete 1.11.2 roster.

## Pinned source

- Repository: [jeffrockson/againstthestorm-wiki-data-processors](https://github.com/jeffrockson/againstthestorm-wiki-data-processors/tree/1c258fd8221deddfebdb1012f5940eb84c85b667), pinned commit `1c258fd8221deddfebdb1012f5940eb84c85b667` (2025-12-04), commit message `data updated for 1.9.3`.
- The repository README describes its input files as developer-provided game data and its scripts as preprocessors for the Against the Storm Wiki. The pinned `test_data/` JSON files preserve source `id`, `displayName`, category, footprint, workplaces, and costs. This is a community-maintained copy of developer-provided data, not an official game release artifact.
- I cloned the pinned commit and compared the buildable data files, excluding glade events, resources, needs, biomes and deposits, with the source-name manifest in `ats-buildable-source-candidates.md`.

## Census and differences

The 1.9.3 building-category JSON files contain **196 records / 190 unique display names**; repeated records are source variants, not accidental duplicate rows. The 202 Fextralife buildable/special-kind names have **188 exact display-name overlaps** after normalizing the manifest's linked article titles. The two 1.9.3 names absent from that 202-name set are `Field Engineering Station` and the buildable `Obelisk`. Fourteen Fextralife names are absent by exact display name from the 1.9.3 data and therefore represent later-snapshot, alternate-label or still-unresolved candidates: `Beacon Tower`, `Black Market`, `Cornerstone Forge`, `Explorers' Lodge`, `Flame Altar`, `Forsaken Altar`, `Giant Fluffbeak`, `Hydrant`, `Manorial Court`, `Path`, `Paved Road`, `Reinforced Road`, `Strider Port`, and `Trading Post`.

This cross-check confirms a useful pre-1.10 baseline and variants, but it does not supply a 1.11.2 source dump or establish that either web index is exhaustive for the frozen released-DLC boundary. Keep the 1.11.2 roster audit open until post-1.9.3 additions/renames are reconciled and the source-version coverage caveat is resolved.

## Explicit identity and variant dispositions

| Pinned game-data identity | Source data | Evidence-based disposition |
|---|---|---|
| `Temporary Engineering Station` → `Field Engineering Station` | `Workshops.json`; Industry; 2×2; 2 workplaces; source build cost 4 Planks + 2 Parts | Confirmed AtS industry/workshop candidate. Source costs remain comparative only; campaign cost/role requires the audited campaign decision. Add the display name to the candidate crosswalk. |
| `Monolith Positive` → `Obelisk` | `Decorations.json`; Decorations; 1×1; 0 workplaces; same-named `Glade_Events.json` record `Monolith` is a Glade Event with 2 workplaces | Two distinct source entities share the label. Keep buildable decorative Obelisk and encounter Obelisk separate; do not merge based on title. The database article's buildable-decoration identity agrees with `Monolith Positive`. The 1.9.3 data lists an empty `requiredGoods` array while the independent database article reports 1 Plank; preserve this cost discrepancy as unresolved version/source evidence and import neither value into campaign costs. |
| `Seal Guidepost` → `Guidance Stone` | `Decorations.json`; category `Ancient Relic`; 1×1; 0 workplaces; source build cost 10 Stone + 5 Resin | Confirmed buildable relic/decorative object, distinct from an economic production building. Record as a source candidate and explicitly exclude from the campaign economic catalog unless a campaign role is independently authorized. |
| `Lore Tablet 1`–`Lore Tablet 7` → `Inscribed Monolith` | Seven records in `Decorations.json`; categories Lore Tablet I–VII; each 2×1, 0 workplaces; each source description says it counts as two decorations of its type | Confirmed seven source variants of one displayed decorative family. Preserve all seven source IDs as variants; exclude source lore text/decoration score from campaign effects. |

Other inputs checked for this census are `Blight_Posts.json`, `Camps.json`, `Extractors.json`, `Farms.json`, `Farmfields.json`, `FishingHuts.json`, `Institutions.json`, `Mines.json`, `RainCatchers.json`, `Storages.json`, `Workshops.json`, `Hearths.json`, `Houses.json`, and `Decorations.json`. Full per-record version-aware roles remain to be reconciled against the pinned 1.10 boundary.
