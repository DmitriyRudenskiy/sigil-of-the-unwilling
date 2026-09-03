---
description: "A sacrifice battle action: spend a follower/resource/artifact to guarantee finishing off a strong enemy stack."
---

## Why

The user's design states: *"с помощью жертвоприношения преемник может добить сильного монстра"* — "via a sacrifice, the successor can finish off a strong monster." Currently the battle system (`BattleActionResolver.apply_attack` / `apply_spell`) has only two offensive actions: a normal attack and a spell. There is no way to guarantee a kill on a strong enemy that would otherwise survive (or that has a `rebirth` tag). A purely stronger attack or spell may fail against a high-HP / high-defense stack, so the player has no reliable "finisher." This leaves a gameplay gap: a well-built successor can still be stuck against a monster it should be able to put down.

This change adds a **sacrifice** battle action: spend a defined cost (a follower stack, a stored resource, or an artifact) to guarantee finishing off a chosen target enemy stack. It is a build-expression lever (ties into the race×class + spell/build variety) and a risk/reward decision.

## Proposed Change

Add `BattleActionResolver.apply_sacrifice(state, sacrifice, target, rng)` as a first-class battle action, parallel to `apply_attack`/`apply_spell`. The **sacrifice cost** is one of:
- a **follower/unit stack** (`BattleState.BattleUnit`) — a disposable ally spent as fuel;
- a **stored resource** (industry/gold/special from the controlled economy);
- an **artifact** (an equipped weapon/item consumed).

The effect: the target enemy stack is **finished off** — its count is reduced to zero and it is killed, bypassing `rebirth` (the sacrifice "finishes off" what a normal attack could not). The action consumes one turn/action of the acting unit and the specified cost.

## Scope

- **In:** the `apply_sacrifice` action (validation + effect), cost types (follower stack, stored resource, artifact), the "finish off" semantics (guaranteed kill, bypass rebirth), action/turn cost, and unit tests.
- **Out:** *what* can be sacrificed is a data/config decision left to the cycle owner (this change defines the mechanism, not the balance); the race×class matrix (cycle 4) feeds the *who* (which classes can sacrifice); the resurrection gate (succession-sigil) is a separate life-cycle concern.
