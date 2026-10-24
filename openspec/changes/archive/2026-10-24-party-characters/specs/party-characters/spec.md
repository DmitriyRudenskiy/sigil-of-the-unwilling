# party-characters Specification (Delta)

## Purpose

Канон партии и персонажей post-pivot: состав (≤5, герой-лидер), атрибуты + Удача, XP и уровни 1–5 (K-M13), ASI, SM персонажа (READY/WOUNDED/UNSTABLE/DEAD), ветеран (K-M10), снабжение (R7), финальность смерти. Источник: GDD 02-mechanics §3.2 [КАНОН], MVP-scope (Р1, Р2, Р4, Р7), K-канон (K-M13, K-M10, K-M11, K3).

## ADDED Requirements

### Requirement: Party composition
The party SHALL contain at most 5 characters (K-M13). The hero SHALL be one of the 5 (the party leader, R1). The army SHALL be a pool and the party a selection from it (Y1); in MVP the pool equals the party. The starting party SHALL be 1 fighter + 1 ranger at level 1 (R2).

#### Scenario: Party full
- **WHEN** the party already has 5 members
- **THEN** no new member can join
- **AND** training/recruit options are hidden or show the full state

### Requirement: Character attributes and luck
A character SHALL have 6 attributes (STR/DEX/CON/INT/WIS/CHA) plus Luck as the 7th attribute (K-M5 catalog). Modifiers SHALL be `floor((stat - 10) / 2)`. Effective attribute SHALL be base minus penalties (antagonism, threshold 16). Luck SHALL NOT be an ASI target.

#### Scenario: Effective attribute with penalty
- **WHEN** a character has base DEX 14 and a −2 penalty from antagonism
- **THEN** the effective DEX is 12
- **AND** the DEX modifier used in combat is +1

### Requirement: XP and levels 1-5
Characters SHALL gain XP from: battle `100 * CR * (1 + 0.1 * n)`, node (one-time) 200-800, raid survived 300 (R4). District creation SHALL NOT grant XP (K-M16). Levels SHALL be 1-5 with thresholds 0/2700/6500/15000/38000 (K-M13, R4 canon, never changed). On level-up, ASI SHALL grant +2 to one attribute or +1 to two, practical cap 16 (K3).

#### Scenario: Level threshold
- **WHEN** a character accumulates 2700 XP
- **THEN** the character reaches level 2
- **AND** an ASI choice is offered

#### Scenario: District is not XP
- **WHEN** a district is created
- **THEN** no XP is granted to any party member
- **AND** the event is logged in the chronicle without XP

### Requirement: Character state machine
A character SHALL follow the state machine READY → WOUNDED → UNSTABLE → DEAD. WOUNDED and UNSTABLE SHALL be in-battle states (T-116 layer). **V-5/D-220 (2026-10-21):** the party hero's `current_hp` SHALL persist between battles (battle starts from stored `current_hp`); a hero who survives a battle at 0 HP (death saves) SHALL leave the roster-level `WOUNDED` state with `current_hp = 1` (D4: alive — counts for `alive_members`/wipe/party limit, no combat penalty); a hero who dies SHALL become `DEAD` (exactly one roster member, no duplicate deaths). REST SHALL fully restore living members (READY/WOUNDED → `max_hp`/READY) and SHALL NOT restore DEAD members; the `(2 + CON) * hit_die` healing formula is deferred (hit-die design has no canon). `max_hp` of all members SHALL be the warrior statblock proxy (D2; class→statblock mapping is out of V-5 scope). A DEAD character SHALL be replaced by a companion of the same class via training (§3.3), level 1 in MVP (C-1: the "city level - 1" formula is a dead reference, K-M3).

#### Scenario: Rest heals
- **WHEN** the hero is in the city and the settlement phase runs (D3: automatic REST)
- **THEN** every living member (READY/WOUNDED) is restored to `max_hp` and set to READY
- **AND** DEAD members are untouched

#### Scenario: Wounded persists between battles
- **WHEN** the hero survives a battle at 0 HP (stabilized by death saves) and no REST has occurred
- **THEN** the roster member is WOUNDED with `current_hp = 1`
- **AND** the next battle starts from `current_hp = 1`

#### Scenario: Out of city — no REST
- **WHEN** the hero is outside the start region when the settlement phase runs
- **THEN** no REST occurs and battle damage persists into the next battle

#### Scenario: Replacement after death
- **WHEN** a party member dies and the player trains a replacement of the same class
- **THEN** the replacement joins at level 1 in MVP
- **AND** the dead character's save and prestige are preserved

### Requirement: Veteran status
A character SHALL gain the veteran status after surviving N battles (Q-M56→(а), K-M10). Veteran SHALL grant +1 step to saves/checks until the end of the battle. Veteran SHALL NOT be a purchasable unit.

#### Scenario: Veteran bonus
- **WHEN** a veteran character makes a save in battle
- **THEN** the save gets +1 step
- **AND** the bonus lasts until the end of that battle

### Requirement: Party supply
The hero SHALL carry 10 food (capacity). Food SHALL be consumed at 1 per character per transition (R7, Q-M75→(б)). Full (>50% capacity) SHALL grant +2 to the first save; hunger (0 food) SHALL grant −2 to attacks.

#### Scenario: Hunger penalty
- **WHEN** the party's carried food reaches 0
- **THEN** all party members get −2 to attack rolls
- **AND** the penalty persists until resupply in the city

### Requirement: Death is final for the campaign
A character's death SHALL be final for the campaign. The save and prestige SHALL be preserved after death. Hero death SHALL NOT end the campaign; the party gains a "loss" (−2 to fear/charisma saves until end of battle, K-M11); the campaign ends only on full party wipe (R1, Q-M68→(а)).

#### Scenario: Hero death
- **WHEN** the hero (party leader) dies in battle
- **THEN** the party gains a "loss" status (−2 to fear/charisma saves until end of battle)
- **AND** the campaign continues unless the whole party is wiped
