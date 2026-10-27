# campaign-core-loop Specification (Delta)

## Purpose

Канон post-pivot core loop кампании: длина кампании, структура хода (сезон, фазы, тик), бит-каркас, детерминизм, статус кампании (победа/поражение), метрики loop'а и fail states. Источник: GDD 01-core-loop, 02-mechanics §3, K-канон (K-M9, K-T5, K-R3, K-M16), решения владельца (Q-M26, Q-M31, Q-M68, D-190).

## ADDED Requirements

### Requirement: Turn equals season of 20 days
A campaign turn SHALL equal one season of 20 days (Q-M26). The campaign SHALL consist of 21 turns (420 days). The season index SHALL be computed as `(turn - 1) % 4` with turn 1 = spring; winter SHALL be every 4th turn (4/8/12/16/20).

#### Scenario: Season index per turn
- **WHEN** the campaign is on turn 5
- **THEN** the season index is 0 (spring)
- **AND** turn 4, 8, 12, 16, 20 are winter

### Requirement: Canonical phase order
A turn SHALL execute phases in the canonical order: settlement → player → caravans → diplomacy → threats → production. `caravans` and `diplomacy` SHALL be no-op post-MVP slots in the MVP. `production` SHALL run after `threats` (T-122). `TurnDriver` SHALL be the single owner of the phase order.

#### Scenario: Production resolves after raid
- **WHEN** a raid strikes during the threats phase of a turn
- **THEN** production for that turn is computed after the raid resolution
- **AND** the player sees raid consequences before the production report

#### Scenario: Post-MVP slots are no-ops
- **WHEN** the turn reaches the caravans or diplomacy phase in MVP
- **THEN** no state change and no player interaction occur
- **AND** the phase still exists in the order for 1.0

### Requirement: 21-turn bit framework
The campaign SHALL use a fixed 21-turn bit-script skeleton with story beats at turns 1, 7, 14, 17, 21 (K-M9). Turn 21 SHALL be the boss raid (CR 6-8) if the hero is in the city, or an auto-raid if the hero is away (R5).

#### Scenario: Campaign victory
- **WHEN** the player survives the turn-21 raid with any stock above zero
- **THEN** the campaign status becomes victory
- **AND** the final prestige rank is reported

#### Scenario: Campaign defeat
- **WHEN** the entire party is wiped
- **THEN** the campaign status becomes defeat
- **AND** no other defeat condition applies (Q-M68→(а), D-190)

### Requirement: Deterministic campaign state
The campaign SHALL be deterministic (I1): identical inputs (seed, actions) SHALL produce byte-identical state. Randomness SHALL be excluded from combat resolution and raid targeting; only the campaign seed may drive randomness.

#### Scenario: Replay equivalence
- **WHEN** the same seed and action sequence are replayed 100 times
- **THEN** all 100 runs produce identical final state
- **AND** no run diverges at any tick

### Requirement: Core loop metrics
The campaign SHALL emit telemetry events to a session log to compute core-loop metrics: TTFD (≤ 30s), action rate (8-15/5min), decision ratio (≥60%), loop closure (≥70% of sessions close at least one full loop), session length (35-50min), D1 (≥35%), D7 (≥15%). Event timestamps SHALL be the campaign turn (I1); wall-clock time is an optional field added by the UI layer in playtest.

#### Scenario: Telemetry event on player action
- **WHEN** the player performs a verb (build/train/move/fight)
- **THEN** an `action{type, choice_count}` event is emitted with a timestamp
- **AND** the event is included in the metrics report

#### Scenario: Loop closure event
- **WHEN** a turn ends with all loop flags set: a raid struck during the threats phase, the player acted, the hero made an expedition (left the city), the hero is back in the city at turn end, and the campaign is ongoing
- **THEN** a `loop_closed` event is emitted for that turn

#### Scenario: Post-hoc metrics report
- **WHEN** the session log is analyzed after the session ends
- **THEN** the report includes TTFD, action rate, decision ratio, loop closure, session length, and replan-after-tooltip values with pass flags against the GDD targets
- **AND** metrics without wall-clock timestamps are reported as not computable

### Requirement: Core loop fail states
The campaign SHALL enforce fail states: AFK caps per resource per raid (food ≤40%, iron/weapons ≤30% — see `raid-pressure-system`), hunger (1 food per character per transition, capacity 10; hunger → −2 to attacks), and the invariant that at least two player verbs are always available in the player phase.

#### Scenario: AFK does not cascade
- **WHEN** the player takes no action for 5 consecutive turns
- **THEN** raid losses are capped per resource per raid
- **AND** the campaign does not enter a chain-collapse state

#### Scenario: Hunger penalty
- **WHEN** a party member's carried food reaches 0 during a transition
- **THEN** that member gets −2 to attack rolls
- **AND** the penalty persists until the party resupplies in the city
