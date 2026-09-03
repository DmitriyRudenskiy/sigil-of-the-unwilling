---
description: "The hero's survival loop: four core needs (hunger/rest/social/inspiration) that decay in the field and recover in a friendly city, death by need depletion (starvation/exhaustion/isolation/burnout) routed through the existing succession flow, and temple resurrection as a player choice on the death screen."
---

## Why

The main specs (`succession`, `inspiration`) already define the hero's survival behavior, but the code implements only **battle death**:

- The hero has **no needs at all** — `Character.NEED_KEYS` (hunger/rest/social/inspiration) exist for citizens only (`DemographicTurnProcessor`). The `succession` spec scenario «Hero dies from a depleted need» and the entire `inspiration` spec (inspiration as a core need, death by burnout) are unimplemented for the hero. `HeroStatusPanel` already has a graceful placeholder (`if "inspiration" in h`) waiting for this.
- **Resurrection is a dead function.** `SuccessionController.resurrect_hero()` + `City.can_resurrect()` exist and are unit-tested, but **nothing ever calls them** — no UI, no command, no player entry point. The `succession` spec requirement «Resurrection requires a temple and resources» has no way to be satisfied.
- Result: the hero can only die in battle; the dramatic counter-choices (keep the hero alive, or bring them back from the temple) don't exist in the game.

## Proposed Change

1. **Hero needs loop.** `HeroNeeds` component on `HeroController`: the four core needs (reusing `Character.NEED_KEYS`), each 0..1, ticked on `end_turn()`. In a friendly city the hero recovers on the same table citizens use (hunger +0.20 / −0.10 if the city starves, rest +0.12, social +0.10 with pop ≥ 3 else −0.05, inspiration +0.05); in the field needs decay with no recovery. A need at zero for `DEATH_STREAK` (3) turns kills the hero with cause `starvation`/`exhaustion`/`isolation`/`burnout` — same mapping as demographics — and emits the existing `GameEventBus.hero_died(cause)`, so the whole downstream flow (successor selection, DeathSequence, chronicle, endgame DEFEAT on unsuccessored death) works unchanged.
2. **Resurrection on the death screen.** When the hero dies and a controlled city can afford it (`great_temple` level ≥ 1, storage ≥ 500 industry + 100 gold), `DeathSequence` gains a third button «Воскресить (500⚙ + 100💰)» next to «Знак переходит»/«В меню». Choosing it calls the existing `SuccessionController.resurrect_hero(city)` (consumes storage), the hero returns **alive at the temple's city** with HP restored, needs reset, path/spellbook kept, and inventory reset to template gear (weapons/artifacts do not return). Resurrection is **once per cycle**: the flag lives on the hero (`resurrected_once`, serialized with the hero), resets when a successor takes over (new cycle).
3. **Needs visible.** `HeroStatusPanel` replaces the inspiration placeholder with the four need values.

## Scope

- **In:** `entities/HeroNeeds.gd` (new), `HeroController` (needs tick in `end_turn`, `revive_at`, `resurrected_once`, serialization), `WorldController` (resurrection candidate on death, keep-alive of the deceased, resurrection/succession branch), `ui/DeathSequence.gd` (third button), `ui/HeroStatusPanel.gd` (needs display), unit tests (`tests/test_hero_survival.gd`), socket scenario 12.
- **Out:** needs UI polish (bars/tooltips), resurrection elsewhere than the death screen, city buildings that specifically target hero needs, any new spec-level behavior — everything above is already contracted by the main `succession` and `inspiration` specs (implementation catch-up, `skip_specs: true`).

## Impact

- Code: new `HeroNeeds.gd`; touches `HeroController`, `WorldController`, `DeathSequence.gd`, `HeroStatusPanel.gd`. No SaveData version bump (hero dict gains keys via `data.get` defaults; `resurrected_once` defaults false for old saves).
- Specs: none modified — `succession` («Hero dies from a depleted need», «Resurrection requires a temple and resources») and `inspiration` (inspiration as core need, death by burnout) already define the behavior; this change implements it.
- Tests: new `test_hero_survival.gd`; existing succession/endgame tests untouched (battle-death path unchanged).
