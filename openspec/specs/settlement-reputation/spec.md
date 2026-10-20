# settlement-reputation Specification

> **Синк 2026-10-20 (campaign-city-building-economy).** Pre-pivot требования
> (Demand/Decadence, Hostility, штормы, Prestige-уровни, условия поражения)
> **REMOVED** (Reason/Migration — в дельте change); pre-pivot контент —
> носитель правила для 1.0 (доки 02e*, git-история). Пост-пивот требования
> ниже — текущий контракт capability.

## Purpose
Определяет репутацию/состояние города кампании: рейдерское давление
кампании — единственный рейд-таймер города, а satisfaction и Sign Prestige
остаются отдельными величинами (не валюда победы).
## Requirements

### Requirement: Campaign raid pressure remains the only city raid clock
City raids SHALL be generated and paced by the canonical campaign pressure system. Building and population effects MAY modify declared pressure inputs or defense values but SHALL NOT schedule raids by fixed settlement cycles or a separate Hostility meter.

#### Scenario: Building changes raid pressure
- **WHEN** a city building or population effect modifies a configured pressure input
- **THEN** the pressure system receives the explicit deterministic modifier
- **AND** the source is available in the raid explanation

#### Scenario: City turn without pressure threshold
- **WHEN** a campaign city turn resolves and the pressure accumulator has not crossed a configured threshold
- **THEN** no raid is generated solely because a source-game storm or calendar trigger fired

### Requirement: Satisfaction and Sign Prestige remain separate
City group satisfaction SHALL NOT award, spend, or store Sign Prestige unless a separately authorized Sign rule explicitly defines such a transaction.

#### Scenario: High satisfaction
- **WHEN** all city groups have high satisfaction
- **THEN** only the declared city and population effects occur
- **AND** Sign Prestige is unchanged absent an eligible Sign event
