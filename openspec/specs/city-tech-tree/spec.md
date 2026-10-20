# city-tech-tree Specification

> **SUPERSEDED (MVP) — реестровый акт 2026-10-19 (C-9, D-215); синк 2026-10-20 (campaign-city-building-economy).**
> Pre-pivot требования (уровни города 1–11, tech tree, тир найма, тир оружия)
> **REMOVED** синком (Reason/Migration — в дельте change; K-M3: уровней города нет).
> Pre-pivot контент — носитель правила для 1.0 (Q-M46/Q-M52: уровни = 1.0),
> сохранён в доках 02e* и git-истории. Пост-пивот требования ниже —
> текущий контракт capability (файл не удаляется: реестровая практика).

## Purpose

Определяет пост-пивот развитие города кампании: открытие зданий явными
pre-requirement'ами (без уровней города 1–11), class-based обучение персонажей
с capacity/data-gate и лимиты города от административных зданий (канон —
02g, 00-overview; K-M3).

## Requirements

### Requirement: Building unlocks use explicit prerequisites, not city levels
A campaign building SHALL be available when all declared prerequisites are met: required registered resources, prerequisite buildings/roles, scenario flags, and administrative capacity where applicable. No building SHALL require a city level from 1 to 11.

#### Scenario: All prerequisites met
- **WHEN** the city satisfies every declared building prerequisite and has room/capacity
- **THEN** the building becomes available
- **AND** the UI lists the satisfied conditions

#### Scenario: Prerequisite missing
- **WHEN** one or more declared prerequisites are unmet
- **THEN** the building remains unavailable
- **AND** the player sees the exact unmet prerequisite without resource loss

### Requirement: Character training is capacity- and data-gated
A military building SHALL offer only training actions explicitly linked to an approved campaign character class. Training SHALL check registered costs, declared infrastructure, and existing party/capacity limits before any stock is deducted. It SHALL use the canonical character/party pipeline, not the legacy generic UnitRegistry roster.

#### Scenario: Valid training
- **WHEN** the class-training action is unlocked and all costs, prerequisites, and party-capacity requirements are met
- **THEN** the canonical campaign character/party pipeline completes the action and costs are committed atomically

#### Scenario: Training unavailable
- **WHEN** the class is not approved, its prerequisite is missing, or capacity is full
- **THEN** training is rejected with a specific reason
- **AND** city stocks and party members remain unchanged

### Requirement: Administrative buildings set city capacity
Where a limit is required, it SHALL come from the existing campaign party/capacity rules or an explicit administrative building/scenario rule, never from a city level. Capacity SHALL be visible; changes SHALL not delete existing buildings or characters.

#### Scenario: Capacity reached
- **WHEN** an action would exceed a declared capacity
- **THEN** the action is blocked before costs are deducted
- **AND** the UI identifies the capacity source and available limit

#### Scenario: Capacity source is disabled
- **WHEN** the administrative building granting capacity becomes inactive
- **THEN** existing entities remain intact
- **AND** new actions exceeding the reduced capacity are blocked
