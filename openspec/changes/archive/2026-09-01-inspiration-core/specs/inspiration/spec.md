---
description: "Requirements for the inspiration (secular) hero need and its trait modifiers."
---

## ADDED Requirements

### Requirement: Inspiration is a core internal need
The hero **MUST** have an internal need identified by the StringName `&"inspiration"`, which replaces the former `&"belief"` need. It is one of the hero's core needs and participates in the same life-support loop as hunger, rest and social.

#### Scenario: Inspiration is present in the need set
- **Given** a newly created `Character`
- **When** the game reads the hero's needs
- **Then** `Character.NEED_KEYS` contains `&"inspiration"` and no longer contains `&"belief"`

#### Scenario: Inspiration regenerates between turns
- **Given** a hero whose inspiration is not depleted
- **When** the city/world turn processor advances
- **Then** the hero's inspiration regenerates by its normal recovery rate (previously applied to `belief`, +0.05 when not starving)

### Requirement: Inspiration depletion causes death (burnout)
When a hero's inspiration stays at zero for the death-streak window, the hero **MUST** die from burnout — the secular replacement for the former "despair" death.

#### Scenario: Death by burnout
- **Given** a hero whose inspiration is at zero for `DEATH_STREAK` turns
- **When** the turn processor evaluates survival
- **Then** the hero is killed and the cause is reported as burnout (formerly `&"despair"`), not as a religious event

#### Scenario: Other needs still cause their own deaths
- **Given** a hero starving, exhausted or socially isolated
- **When** the corresponding need hits the death-streak window
- **Then** the hero dies from that need's own cause (starvation, exhaustion, isolation); inspiration is one need among several, not the only death path

### Requirement: Traits modify inspiration
Traits **MUST** carry a tag identifying them as inspiration-related and can modify the hero's inspiration by a scalar (positive or negative), exactly as the former belief traits did.

#### Scenario: Positive inspiration trait
- **Given** a hero with an inspiration-boosting trait (e.g. the secular replacement for «Дар пророка»)
- **When** the hero's needs are evaluated
- **Then** inspiration is increased by the trait's modifier (previously +0.20)

#### Scenario: Negative inspiration trait
- **Given** a hero with an inspiration-draining trait (e.g. the secular replacement for «Скептик» / «Еретик»)
- **When** the hero's needs are evaluated
- **Then** inspiration is decreased by the trait's modifier (previously -0.08 / -0.12)

### Requirement: Inspiration traits are secular in name and flavor
Inspiration-related traits **MUST** keep their mechanical effect but be named and described without religious connotation.

#### Scenario: Trait names avoid religion
- **Given** the registry of inspiration traits
- **Then** no trait uses religious identifiers such as `faith`, or religious roles like «Верующий», «Пророк», «Еретик», «Повитый Сигиллом» in its id or flavor text
