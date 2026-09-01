---
description: "Endless succession: when the hero dies a follower inherits the path, cities, economy, spellbook and weapons; resurrection via temple + resources."
---

## Why

The game's identity is **an endless cycle of legends**, not a fresh run each time. Right now the hero is effectively immortal: battle loss only triggers a retreat, and the hero has no death mechanism at all (it is a `HeroController` separate from the demographic `Character` need-loop). There is no concept of a "current hero," no death event, no successor, and no inheritance. The player's progress (cities, economy, spellbook, weapons) lives only in the current hero's life and is lost the instant the run ends. This breaks the core fantasy: "each cycle passes on the «Знак» (Sigil) and continues the путь."

This change makes death real, wires a succession trigger, selects a successor from the hero's followers, and transfers the accumulated legend onto them.

## Proposed Change

**Inheritance of the legend.** On hero death, the world selects a successor: one of the hero's own followers (a follower of the same path can be chosen). The successor inherits:
- the **path** (build identity: schools, skill focus, role) — the successor *cannot* pick a different path, only a follower of the path qualifies;
- **cities** (all `City` instances: boroughs, buildings, roads, pop, specialization, level, reputation, faction, `is_capital`);
- the **economy** (`storage` resources + `resource_ctx` production chains);
- the **spellbook** (`HeroMagic.spellbook`, `schools`, `mana`) and the hero's own **inventory/weapons** (`HeroInventory`: 11 equipped slots + 16 backpack, `Artifact`-based);
- strategic resources and accumulated **glory** (`CityManager.glory`).

**Death.** The hero gains a death path: (a) battle death when the hero's HP drops to zero after combat resolution, and/or (b) need-loop death (hunger/rest/social) once the hero is tied into the demographic need system. Death emits a `hero_died` event carrying the cause.

**Resurrection.** A hero may be returned to life only if a controlled city has a `great_temple` building and the city's `storage` has enough resources (industry + a special resource). Resurrection does **not** restore the hero's inventory (only the path + spellbook + template gear). It is a one-per-cycle cost, gated by resources, and consumes the temple's stored resources.

**Successor selection.** A successor is chosen from the hero's followers via a deterministic-but-seeded rule (oldest free follower of the path, or a weighted roll). The successor is a fresh `HeroController` built from the inherited data; the old hero is removed.

## Scope

- **In:** death event + cause, successor selection from followers, legend transfer (path, cities, economy, spellbook, inventory, glory), resurrection temple gate, the "path" gate on successor eligibility, save/migration for the new hero field.
- **Out (other cycles):** the D&D race×class matrix (cycle 4), the sacrifice mechanic (cycle 3), the god/faith layer (out of scope — secular), battle spell/condition depth (cycle 5).
- The hero is created by `WorldBootstrap._create_hero` (currently a bare `HeroController` named "Hero"). Succession hooks into the battle result path (`WorldBattleCoordinator._apply_results`) and any future need-loop death path.
