# succession — delta (remove-hunger-mechanic)

## MODIFIED Requirements

### Requirement: The hero can die and reports a cause
The world MUST support a hero death event. When the conditions for death are met (battle death when the hero's combat HP reaches zero, or need-loop death when a core need is depleted for the death-streak window), the hero MUST be marked dead and a `hero_died` event MUST be emitted carrying a `cause` (StringName) such as `&"battle"`, `&"exhaustion"`, `&"isolation"`, `&"burnout"`. Starvation is no longer a death cause: hunger was removed from the core need set.

#### Scenario: Hero dies in battle
- **Given** the hero is engaged in a battle resolved by `WorldBattleCoordinator`
- **When** the hero's combat HP reaches zero after resolution
- **Then** the hero is marked dead, the battle is recorded as lost, and `hero_died` is emitted with `cause == &"battle"`

#### Scenario: Hero dies from a depleted need
- **Given** the hero is wired into the core need-loop and a need (rest/social/inspiration) is at zero for the death-streak window
- **When** the turn processor evaluates survival
- **Then** the hero is marked dead and `hero_died` is emitted with the need-specific cause (e.g. `&"exhaustion"`), and succession is triggered
