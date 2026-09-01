---
description: "Requirements for hero death, successor selection, legend inheritance and temple resurrection."
---

# succession Specification

## Purpose

Lets a world survive the death of its hero: the hero dies and reports a cause, a same-path follower is selected as successor and inherits the full legend (cities, economy, spellbook, inventory, glory), and a dead hero may return via a temple resurrection that restores only path, spellbook and template gear.

## Requirements

### Requirement: The hero can die and reports a cause
The world MUST support a hero death event. When the conditions for death are met (battle death when the hero's combat HP reaches zero, or need-loop death when a core need is depleted for the death-streak window), the hero MUST be marked dead and a `hero_died` event MUST be emitted carrying a `cause` (StringName) such as `&"battle"`, `&"starvation"`, `&"exhaustion"`, `&"isolation"`.

#### Scenario: Hero dies in battle
- **Given** the hero is engaged in a battle resolved by `WorldBattleCoordinator`
- **When** the hero's combat HP reaches zero after resolution
- **Then** the hero is marked dead, the battle is recorded as lost, and `hero_died` is emitted with `cause == &"battle"`

#### Scenario: Hero dies from a depleted need
- **Given** the hero is wired into the core need-loop and a need (hunger/rest/social) is at zero for the death-streak window
- **When** the turn processor evaluates survival
- **Then** the hero is marked dead and `hero_died` is emitted with the need-specific cause (e.g. `&"starvation"`), and succession is triggered

### Requirement: A successor is selected from the hero's followers
On `hero_died`, the world MUST select a successor from the hero's followers. A follower is eligible only if it is a follower **of the same path** as the deceased hero. If no eligible follower exists, the run ends (the legend dies with the hero).

#### Scenario: Successor is a follower of the same path
- **Given** the deceased hero had followers and at least one is a follower of the same path
- **When** succession runs
- **Then** the chosen successor is one of those same-path followers, and no follower of a different path is ever chosen

#### Scenario: No eligible follower ends the run
- **Given** the deceased hero has no followers of the same path
- **When** succession runs
- **Then** no successor is created and the run ends

### Requirement: The legend is inherited by the successor
The successor MUST inherit, in full, the deceased hero's: path (build identity), all cities (boroughs, buildings, roads, pop, specialization, level, reputation, faction, `is_capital`), the economy (`storage` resources + `resource_ctx` production chains), the spellbook (`HeroMagic.spellbook`, `schools`, `mana`), the inventory/weapons (`HeroInventory` equipped slots + backpack), strategic resources, and accumulated glory (`CityManager.glory`). The old hero is removed and a new `HeroController` becomes the active hero.

#### Scenario: Cities and economy transfer intact
- **Given** the hero controls three cities with buildings, roads, `storage` and a `resource_ctx`
- **When** succession completes
- **Then** the successor's world owns the same three cities with identical boroughs, buildings, roads, pop, specialization, level, reputation, faction, `storage` and `resource_ctx`

#### Scenario: Spellbook and weapons transfer intact
- **Given** the hero has a non-empty `HeroMagic.spellbook`, `schools`, `mana` and a `HeroInventory` with weapons equipped
- **When** succession completes
- **Then** the successor's `HeroMagic` and `HeroInventory` are identical to the deceased hero's

#### Scenario: Successor cannot choose a different path
- **Given** the deceased hero's path
- **When** the successor is created
- **Then** the successor's path equals the deceased hero's path; the successor cannot pick another path

### Requirement: Resurrection requires a temple and resources
The world MUST allow a dead hero to be resurrected only if a controlled city has a `great_temple` building of level ≥ 1 and the city's `storage` holds the required resources (industry + a special resource). Resurrection MUST NOT restore the hero's inventory (weapons/artifacts); only the path, spellbook and template gear return. Resurrection is a one-per-cycle action and consumes the temple's stored resources.

#### Scenario: Resurrection succeeds with temple and resources
- **Given** a controlled city with a `great_temple` of level ≥ 1 and enough `storage` resources
- **When** the player invokes resurrection for the dead hero
- **Then** the hero returns to life, the temple's stored resources are consumed, and the hero's inventory is **not** restored

#### Scenario: Resurrection fails without a temple
- **Given** a controlled city with no `great_temple` building
- **When** the player invokes resurrection
- **Then** resurrection is refused and no resources are consumed

#### Scenario: Resurrection does not restore inventory
- **Given** a hero that is resurrected
- **When** the hero's inventory is inspected
- **Then** the inventory contains only template gear, not the previously equipped weapons/artifacts
