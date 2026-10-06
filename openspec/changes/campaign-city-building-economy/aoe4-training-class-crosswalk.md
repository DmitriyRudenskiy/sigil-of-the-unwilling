# AoE IV military-training/class-role crosswalk

**Source pin:** [`aoe4world/data@b2cd38222deae40ba2db18171edf494f81410c69`](https://github.com/aoe4world/data/tree/b2cd38222deae40ba2db18171edf494f81410c69), 2026-05-04; `buildings/all.json` and `units/all.json`. The Explorer/DLC completeness limitation remains in [`source-inventory.md`](source-inventory.md).

## Normalization rule

The source scan found **49 display names / 186 per-civilization building records** whose producer links train a source unit tagged both `human` and `land_military`. Only the combat role is mapped; source unit names, stats, upgrades, costs, train times, and troop stacks are not imported. Deterministic role mapping from pinned unit-class tags:

1. `religious`, `monk`, or `healer` → campaign `cleric`;
2. `ninja` or `stealth` → campaign `rogue`;
3. `scout` or `ranged` → campaign `ranger`;
4. `melee`, `infantry`, or `cavalry` → campaign `fighter`;
5. no matching role → not trainable; explicit support/exclusion below.

When an output has more than one qualifying tag, this order prevents duplicate training actions. `paladin` and `wizard` remain approved MVP classes but have no role-matched AoE IV producer in this pin. Campaign options are still filtered by `mvp_catalog.json` (`hireable` class set) and `CampaignTrainingService`; no AoE generic unit can be a training target.

| Source building | Per-civ campaign class roles from the linked source units |
|---|---|
| Abbey of Kings | `fighter`: en, hl |
| Abbey of the Trinity | `cleric`: ru |
| Archery Range | `ranger`: ab, ay, by, ch, de, en, fr, hl, hr, ja, je, kt, ma, mac, mo, od, ot, ru, sen, tug, zx; `fighter+ranger`: gol |
| Barracks | `fighter`: ab, ay, by, ch, de, en, fr, gol, hl, hr, ja, je, jin, ma, mo, od, ot, ru, sen, tug, zx; `cleric+fighter`: kt |
| Berkshire Palace | `fighter+ranger`: en |
| Buddhist Temple | `cleric`: ja, sen |
| Burgrave Palace | `fighter`: hr, od |
| Capital Town Center | `ranger`: ab, ay, by, ch, de, en, fr, gol, hl, ja, je, jin, kt, ma, mac, mo, od, ot, ru, sen, tug, zx; `cleric+ranger`: hr |
| Council Hall | `ranger`: en |
| Dome of the Faith | `cleric`: de, tug |
| Farimba Garrison | `fighter+ranger`: ma |
| Golden Horn Tower | `ranger`: mac; `fighter+ranger`: by (Byzantine mercenary production is a training role, not defense) |
| Golden Tent | `fighter`: gol |
| Grand Winery | `cleric`: by, mac |
| Great Pasture | `fighter+ranger`: jin |
| Hojo Clan Daimyo Estate | `fighter`: sen |
| Hunting Cabin | `ranger`: ru |
| Imperial Hippodrome | `fighter+ranger`: by, mac |
| Keep | `ranger`: de; `fighter+ranger`: en |
| Khaganate Palace | `cleric+fighter+ranger`: mo |
| King's Palace | `ranger`: en |
| Koka Township | `fighter`: ja |
| Machine Workshop | `ranger`: jin |
| Mercenary House | `fighter+ranger`: by |
| Military School | `fighter+ranger`: ot |
| Monastery | `cleric`: by, ch, en, fr, hl, hr, je, jin, kt, mac, od, ru, zx |
| Mosque | `cleric`: ab, de, ma, ot, tug |
| Mountain Hall | `cleric`: jin |
| Oda Clan Daimyo Estate | `fighter+ranger`: sen |
| Pagoda | `cleric`: zx |
| Palace of Swabia | `cleric+ranger`: hr, od |
| Palace of the Sultan | `fighter`: tug |
| Palatine School | `fighter`: by, mac |
| Prayer Tent | `cleric`: gol, mo |
| Regnitz Cathedral | `cleric`: hr, od |
| School of Cavalry | `fighter+ranger`: fr, je |
| Shaolin Monastery | `cleric`: zx |
| Shinto Shrine | `cleric`: ja |
| Siege Workshop | `fighter`: gol |
| Stable | `fighter+ranger`: ab, ay, by, ch, de, en, fr, gol, hl, hr, ja, je, kt, ma, mac, mo, od, ot, ru, sen, tug, zx |
| Takeda Clan Daimyo Estate | `fighter`: sen |
| Tanegashima Gunsmith | `ranger`: ja |
| Temple of Equality | `cleric`: ja, sen |
| The White Tower | `fighter+ranger`: en |
| Town Center | `ranger`: ab, ay, by, ch, de, en, fr, gol, hl, ja, je, jin, kt, ma, mac, mo, od, ot, ru, sen, tug, zx; `cleric+ranger`: hr |
| Tughlaqabad Fort | `fighter`: tug |
| Varangian Stronghold | `fighter+ranger`: mac |
| Varangian Warcamp | `fighter+ranger`: mac |
| War Stable | `fighter+ranger`: jin |

## Remaining source-signal names: support or exclusion

The other discovered AoE IV signal names do not directly link to an eligible source unit role or have been separately dispositioned in the defense crosswalk. They are not training choices. This table records why they do not produce an approved class action.

| Candidate | Disposition |
|---|---|
| AOE-C-008 Grassland | Exclude from character training: spawns horses/resource effects used by cavalry production, not a human land character. |
| AOE-C-031 Tower of Victory | `training_support` only: source unit-production aura; no direct training and no static defense. The source attack-speed value is not imported. |
| AOE-C-037 Jiangnan Tower | Exclude: source free-army progression generates mixed unit templates rather than approved individual campaign characters. |
| AOE-C-040 Astronomical Clocktower | Exclude: siege-only production; no approved campaign class target. |
| AOE-C-042 Kurultai | `training_support` only: heals/buffs nearby units; no class training or static defense. Numeric aura values are not imported. |
| AOE-C-043 Istanbul Imperial Palace | Exclude: Imperial Council/Vizier progression, not eligible unit training or static defense. |
| AOE-C-044 Mehmed Imperial Armory | Exclude: siege-only production. |
| AOE-C-045 Foreign Engineering Company | Exclude: siege-only production and source currencies; no eligible class target. |
| AOE-C-048 Wynguard Palace | Exclude: produces bundled battalion templates, not individual human-class characters; source battalions are not imported. |
| AOE-C-049 College of Artillery | Exclude: artillery/siege production and technology; no approved campaign class target. |
| AOE-C-052 Sword Hunt Statue | Exclude from training: source Daimyo/levy discounts and buffs do not map to an approved class action. |
| AOE-C-053 Spirit Way | Exclude: technology and triggered source-combat effects, not eligible training or static defense. |
| AOE-C-055 Zhu Xi's Library | Exclude: source technology unlocks are not direct campaign class training. |
| AOE-C-077 Harbor | Explicit naval exclusion; ships/naval weapons do not enter city training or defense. |
| AOE-C-078 House | `defense_support` only: garrison-dependent source weapon profile; not a standalone defensive structure. |
| AOE-C-081 Manor | `defense_support` only: garrison-dependent source weapon profile; not a standalone defensive structure. |
| AOE-C-093 Village | `defense_support` only: garrison-dependent source weapon profile; not a standalone defensive structure. |

Other discovered names resolve through [`aoe4-static-defense-crosswalk.md`](aoe4-static-defense-crosswalk.md): static fortifications map to `static_defense`, false-positive defensive labels to `not_defense`, and garrison-dependent profiles to `defense_support`. Lancaster Castle's direct fortification role is included there; its source muster is not imported. All source-signal names AOE-C-001–095 now have a training, static-defense, support, naval, or explicit exclusion disposition for the declared 2026-10-04 released-content boundary. The live data/news recheck found no later released building row; a general Explorer DLC warning remains a source caveat, not an unclassified candidate.
