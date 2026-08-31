# console-hygiene Specification

## Purpose

Keeps live gameplay console output clean across the socket scenarios (menu -> world -> movement -> capture -> spells): no error-class lines ever, and every warning either fixed at the source or explicitly allowlisted, enforced by a one-command reproducible gate.

## Requirements

### Requirement: Scenario play produces no console errors
A run of any standard socket scenario (menu → world → gameplay) **MUST NOT** emit error-class console lines (`SCRIPT ERROR`, parse errors, invalid calls, nonexistent members/functions/classes, `E 0:`) to the server log.

#### Scenario: Clean five-scenario run
- **Given** the game boots headless with the test server
- **When** scenarios 1–5 (collect, flee, explore, endure, spells) run to completion
- **Then** each scenario exits 0 and its log contains zero error-class lines

### Requirement: Console warnings are fixed or explicitly allowed
Every warning-class console line (leak, deprecated, failed resource load, `W 0:`) **MUST** either be fixed at the source or appear in `docs/CONSOLE_ALLOWLIST.md` with pattern, reason, owner, date, and removal plan. Suppression of a warning while keeping the faulty state **MUST NOT** be used as a fix.

#### Scenario: New warning appears
- **Given** a change introduces a new warning-class line in a scenario log
- **When** the console-clean gate runs
- **Then** the run FAILs unless the warning's pattern is an allowlisted row

### Requirement: The console-clean gate is one command and reproducible
A single script **MUST** run the named scenarios (default 1–5), assert each scenario's exit code is 0, and fail on any error-class line or any un-allowed warning; it **MUST** print a per-scenario summary.

#### Scenario: Gate fails on a planted error
- **Given** a temporary fault introduced in gameplay code
- **When** `check_console_clean.sh` runs
- **Then** it exits non-zero and prints the offending log line(s)

#### Scenario: Gate passes when clean
- **Given** all errors fixed and all warnings fixed or allowlisted
- **When** `check_console_clean.sh` runs scenarios 1–5
- **Then** it exits 0 with a per-scenario "clean" summary
