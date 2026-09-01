## Context

The current world has a `HeroController` (an autoload-ish facade composing `HeroMovementController`, `HeroArmyController`, `HeroInventory`, `HeroMagic`, `HeroSkills`, `HeroTools`, `HeroTime`, `HeroStrategicResources`, `HeroResources`). It is created bare in `WorldBootstrap._create_hero` (name "Hero", hardcoded stats) and, critically, has **no death mechanism**: battle loss only retreats (`_restore_hero_after_retreat`), and the hero is not part of the demographic `Character` need-loop, so it cannot die from hunger/rest/social. There is no "current hero" pointer beyond `WorldController.get_hero()`, no successor, and no inheritance.

The legend's durable assets already exist as serializable models:
- **Cities:** `world/City.gd` (RefCounted pure model) with `boroughs`, `buildings`, `roads`, `pop: Array[PopUnit]`, `specialization`, `level`, `reputation`, `faction`, `is_capital`, `food_stockpile`, `storage` (industry/gold/dust/science/influence), `resource_ctx: ResourceContext`, `special_sites`. Serializes/deserializes (`serialize()`/`deserialize()`). `CityManager` owns `cities`, `capital`, `glory` (`GloryTracker`), `current_turn`.
- **Economy:** `EconomicTurnProcessor` runs production chains / upkeep against `city.resource_ctx`; `City.process_turn` runs food/births/borough level-ups and writes `storage`.
- **Spellbook:** `HeroMagic` (autoload "Spellbook", `SpellbookRegistry`) holds `spellbook: Array[StringName]`, `schools`, `mana`.
- **Inventory:** `HeroInventory` holds `equipped: Dictionary` (11 slots) + `backpack: Array[Artifact]`; `Artifact` (weapon profile, slots, two-handed).

Battle resolution lives in `systems/BattleActionResolver.gd` (`apply_attack`, `apply_spell`) and `systems/BattleTurnExecutor.gd`; `WorldBattleCoordinator._apply_results` applies results to the hero and, on defeat, retreats. There is a `rebirth` monster tag but no hero death.

Succession therefore needs three new seams: (1) a death trigger + `hero_died` event on `GameEventBus`, (2) a successor builder that constructs a new `HeroController` from the inherited assets, (3) a transfer routine that copies cities/economy/spellbook/inventory/glory onto the successor's world, and (4) a temple+resource resurrection gate.

## Design

**Death seam.** `WorldBattleCoordinator._apply_results` gains a check: if the attacker lost AND the hero's combat HP is zero (not merely routed), emit `GameEventBus.hero_died.emit(cause: &"battle")` instead of `_restore_hero_after_retreat`. Need-loop death is handled where the hero is later wired into the need-loop (future `Character` integration) — the requirement only mandates the *event*, not the need wiring in this cycle. A `HeroController.is_alive()` flag is added.

**Succession seam.** A new `SuccessionController.gd` (RefCounted, `class_name SuccessionController`) owns selection + transfer. It is created in `WorldBootstrap` and injected into `WorldController`. On `hero_died`:
1. `select_successor()`: read the deceased hero's followers (path gate). The path is stored on `HeroController` as `path_id: StringName`. Followers are drawn from the capital's `pop` filtered to `PopUnit.State.FOLLOWER` whose `path_id` matches (a new `PopUnit.path_id` field). If none, run ends.
2. `transfer_legend()`: build a fresh `HeroController`, copy `path_id`, `HeroMagic` (spellbook/schools/mana), `HeroInventory`, strategic resources, and register the deceased hero's cities onto the successor's `CityManager` (cities are re-registered so `capital`/`glory`/`current_turn` are preserved).
3. Swap `WorldController._hero`, emit `hero_successor` for UI.

**Path gate.** `PopUnit` gains `path_id: StringName` (default matches the capital's faction/path). `HeroController.path_id` is the source of truth. Only `PopUnit`s with matching `path_id` are eligible — this is what makes the successor "a follower of the path" who cannot pick another.

**Resurrection seam.** `City.get_great_temple_level()` already exists. Add `City.can_resurrect(temple_resources: Dictionary) -> bool` (checks temple level ≥ 1 and `storage` has the required amounts), and a `SuccessionController.resurrect_hero(city, ...)` that, on success, consumes the resources and rebuilds the dead hero (path + spellbook + template gear only, no inventory). One-per-cycle flag on the world.

**Serialization.** `HeroController.serialize/deserialize` gains `path_id`; `PopUnit.serialize/deserialize` gains `path_id`. Save version bump.

**Grounding facts (files):**
- `world/WorldBootstrap.gd:125` `_create_hero` (bare hero) — death/inheritance hooks in here.
- `world/WorldBattleCoordinator.gd:200-250` `_apply_results` — battle-death trigger.
- `world/City.gd` — cities/economy model + `get_great_temple_level()`.
- `world/CityManager.gd` — `cities`, `capital`, `glory`, `current_turn`.
- `entities/HeroInventory.gd` — weapons/artifacts.
- `entities/HeroMagic.gd` — spellbook/schools/mana.
- `entities/PopUnit.gd` — `State.FOLLOWER`, `is_free_follower()`, serialization.
- `core/GameEventBus.gd` — add `hero_died` / `hero_successor` signals.

## Risks / Trade-offs

- **Hero death vs. current design:** the hero is currently immortal by accident. Making them dieable changes battle stakes; keep battle-death gated behind a config flag so it can be tuned/disabled (matches "AI deferred / final stages" caution).
- **Path gate strictness:** if no same-path follower exists, the run ends. This is intentional (endless-cycle identity) but harsh; consider a rare "wayfinder" fallback in a later cycle.
- **Resurrection no-inventory:** deliberate (user's decision) — resurrection restores the *path*, not the *loot*. Documented so it isn't seen as a bug.
- **City re-registration:** cities are shared world state; re-attaching them to the successor's `CityManager` must preserve `capital`/`glory`/`current_turn` to avoid economy reset.
