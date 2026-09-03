---
description: "Requirements for the sacrifice battle action: spend a cost to guarantee finishing off a target enemy stack."
---

## ADDED Requirements

### Requirement: Sacrifice is a first-class battle action
The battle system **MUST** expose a sacrifice action `apply_sacrifice(state, sacrifice, target, rng)` parallel to `apply_attack` and `apply_spell`. It **MUST** validate that the acting unit is alive, the `target` is an alive enemy stack, and the `sacrifice` cost is valid and available; otherwise it **MUST** return a non-success result without changing board state.

#### Scenario: Valid sacrifice is accepted
- **Given** an acting unit that is alive and a live enemy `target`
- **When** `apply_sacrifice` is called with an available cost
- **Then** the action succeeds and resolves on the board

#### Scenario: Invalid sacrifice is rejected
- **Given** a `target` that is already dead, or a cost that is not available
- **When** `apply_sacrifice` is called
- **Then** it returns a non-success result and the board is unchanged

### Requirement: Sacrifice finishes off the target
When a sacrifice resolves, the target enemy stack **MUST** be finished off: its count is reduced to zero and it **MUST** be killed, regardless of the damage it would otherwise take.

#### Scenario: Strong enemy is finished off
- **Given** a high-HP / high-defense enemy stack that a normal attack could not kill
- **When** a sacrifice targets that stack
- **Then** the stack is killed (count reduced to zero)

### Requirement: Sacrifice bypasses rebirth
A target stack with a `rebirth` tag **MUST** still be killed by a sacrifice — the "finish off" effect **MUST** bypass the rebirth resurrection.

#### Scenario: Sacrifice kills a rebirth monster
- **Given** an enemy stack with the `rebirth` tag
- **When** a sacrifice finishes off that stack
- **Then** the stack is killed and does not rebirth

### Requirement: Sacrifice consumes a defined cost and one action
A sacrifice **MUST** consume exactly one specified cost — a follower/unit stack, a stored resource, or an equipped artifact — and **MUST** consume one turn/action of the acting unit. Each cost type **MUST** be removed/decayed from the board or economy only when the sacrifice resolves.

#### Scenario: Follower-stack cost is consumed
- **Given** a sacrifice whose cost is an ally follower stack
- **When** the sacrifice resolves
- **Then** the follower stack is removed from the board and the acting unit has moved/acted

#### Scenario: Resource cost is consumed
- **Given** a sacrifice whose cost is a stored resource (industry/gold/special)
- **When** the sacrifice resolves
- **Then** the resource amount is deducted from the controlled economy

#### Scenario: Artifact cost is consumed
- **Given** a sacrifice whose cost is an equipped artifact
- **When** the sacrifice resolves
- **Then** the artifact is removed from the equipped slot
