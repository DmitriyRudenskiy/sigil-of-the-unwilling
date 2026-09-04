# inspiration — delta (remove-hunger-mechanic)

## MODIFIED Requirements

### Requirement: Inspiration is a core internal need
The hero **MUST** have an internal need identified by the StringName `&"inspiration"`, which replaces the former `&"belief"` need. It is one of the hero's core needs and participates in the same life-support loop as rest and social. The need set no longer contains `&"hunger"` — hunger is removed as a survival need for both the hero and citizens; food is a city economic resource only (stockpile, growth, approval, trade) and no longer gates any life-support loop.

#### Scenario: Inspiration is present in the need set
- **Given** a newly created `Character`
- **When** the game reads the hero's needs
- **Then** `Character.NEED_KEYS` contains `&"inspiration"` and no longer contains `&"belief"` or `&"hunger"`

#### Scenario: Inspiration regenerates between turns
- **Given** a hero whose inspiration is not depleted
- **When** the city/world turn processor advances
- **Then** the hero's inspiration regenerates by its normal recovery rate (previously applied to `belief`, +0.05)

#### Scenario: Other needs still cause their own deaths
- **Given** a hero exhausted or socially isolated
- **When** the corresponding need hits the death-streak window
- **Then** the hero dies from that need's own cause (exhaustion or isolation); inspiration is one need among several, not the only death path
