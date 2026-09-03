---
description: "Requirements for the auto-game scenario harness: assertions, console-log analysis, cross-system coverage, and an aggregate runner."
---

## ADDED Requirements

### Requirement: Scenarios assert key invariants
Each auto-game scenario **MUST** assert at least the key invariants of its flow (e.g. after `START_GAME` the hero exists and is positioned; after a collection step the relevant resource count increased; after a battle the target stack is dead). An assertion failure **MUST** cause the scenario to exit non-zero.

#### Scenario: Collection scenario checks resources
- **Given** `scenario_*_collect.py` running against the live server
- **When** the hero collects a resource node
- **Then** the scenario asserts the resource count increased and exits non-zero if it did not

#### Scenario: Battle scenario checks the enemy is dead
- **Given** a battle scenario resolving a fight
- **When** the enemy stack count reaches zero
- **Then** the scenario asserts the enemy is dead and exits non-zero otherwise

### Requirement: Scenarios analyze the console log
Each auto-game scenario **MUST**, at the end, analyze the captured console log (from the Godot server) and fail if the log contains `SCRIPT ERROR`, `Parse error`, `Invalid call`, `Nonexistent function`, `Cannot find`, `LEAK`/`leaked`, or `WARNING`/`deprecated`.

#### Scenario: A SCRIPT ERROR fails the scenario
- **Given** the Godot server log contains `SCRIPT ERROR`
- **When** the scenario finishes and analyzes the log
- **Then** the scenario exits non-zero

#### Scenario: A clean log passes the log check
- **Given** the Godot server log contains no error/warning patterns
- **When** the scenario analyzes the log
- **Then** the log check passes

### Requirement: Coverage across game systems
The scenario set **MUST** include scenarios covering the core game systems: economy/city-building, succession (hero death → successor), race-class creation, and the sacrifice mechanic — so each introduced system has an integration harness.

#### Scenario: Economy/city scenario exists
- **Given** the scenario set
- **Then** a scenario exists that builds a structure and checks the city's `storage`/`boroughs` progression

#### Scenario: Succession scenario exists
- **Given** the scenario set
- **Then** a scenario exists that triggers hero death and checks a successor is created

#### Scenario: Race-class and sacrifice scenarios exist
- **Given** the scenario set
- **Then** a scenario exists that builds a hero from a race×class combo, and a scenario that finishes off a strong enemy via sacrifice

### Requirement: An aggregate runner reports pass/fail
The project **MUST** provide a runner that executes all scenarios in isolation, collects each one's pass/fail result, prints a report, and exits non-zero if any scenario fails.

#### Scenario: Runner reports all scenarios
- **Given** the runner
- **When** it is executed
- **Then** it prints a per-scenario pass/fail report and a summary

#### Scenario: A failing scenario fails the runner
- **Given** one scenario exits non-zero
- **When** the runner is executed
- **Then** the runner exits non-zero
