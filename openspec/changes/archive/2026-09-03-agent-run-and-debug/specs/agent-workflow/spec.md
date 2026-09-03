---
description: "Requirements for the run-and-debug workflow: mandatory hang-preventing wrapper and an end-of-cycle console-clean gate."
---

## ADDED Requirements

### Requirement: Every Godot run uses a hang-preventing wrapper
`AGENT.md` **MUST** mandate that every Godot invocation (`--scene`, `-s script.gd`, `--test-server`) in any cycle is wrapped in a hang-preventing timeout (a background process + `kill`, since `timeout` is absent on macOS). A bare `godot --scene …` or `godot -s …` without a timeout **MUST NOT** be used in a cycle.

#### Scenario: Agent runs a scene
- **Given** a cycle needs to run `scenes/World.tscn`
- **When** the agent invokes Godot
- **Then** it calls `run_godot 40 $GODOT --headless --path game --scene scenes/World.tscn --autoquit` (or `scripts/run_and_fix.sh`) rather than a bare `godot --scene`

#### Scenario: Bare invocation is rejected
- **Given** a proposed command `godot --headless --path game --scene scenes/World.tscn`
- **When** it is not wrapped in a timeout
- **Then** it is rejected and must be wrapped before running

### Requirement: End-of-cycle run-and-debug gate
At the end of every cycle, before committing, the agent **MUST** run the relevant Godot entry points (full CI via `run_all_ci_checks.sh`, plus any smoke scenario the cycle touches) through the hang-preventing wrapper, capture the console output, and scan it for errors and warnings.

#### Scenario: Gate runs CI at end of cycle
- **Given** a cycle has been implemented
- **When** the agent prepares to commit
- **Then** it runs `bash tools/shell/run_all_ci_checks.sh` through the wrapper and captures the log

#### Scenario: Console is scanned for errors and warnings
- **Given** the captured log
- **When** it is scanned
- **Then** the scan flags `SCRIPT ERROR`, `Parse error`, `Invalid call`, `Nonexistent function`, `Cannot find`, `LEAK`/`leaked`, and `WARNING`/`deprecated`

### Requirement: Console must be clean before commit
The gate **MUST** require that the console log contain no errors and no warnings (only benign import warnings are acceptable) before the cycle is committed. Any finding **MUST** be fixed and the gate **MUST** be re-run until the log is clean.

#### Scenario: An error blocks the commit
- **Given** the captured log contains `SCRIPT ERROR`
- **When** the agent attempts to commit
- **Then** the commit is blocked until the error is fixed and the log is re-scanned clean

#### Scenario: Warnings must be resolved
- **Given** the captured log contains a `WARNING` (e.g. a deprecation or a leak)
- **When** the gate runs
- **Then** the warning is fixed and the gate re-run until the log is clean

### Requirement: The run-and-fix skill is wired in
`AGENT.md` **MUST** reference the `godot-run-and-fix` skill as the tool that captures console output and applies fixes, and **MUST** standardize the scan patterns (`scripts/run_and_fix.sh` writes `/tmp/godot_errors_<PID>.txt`, `/tmp/godot_warnings_<PID>.txt`, `/tmp/godot_full_<PID>.txt`).

#### Scenario: Agent uses the skill at the gate
- **Given** the gate finds an error
- **When** the agent fixes it
- **Then** it uses `scripts/run_and_fix.sh <path>` to capture errors/warnings and iterates until clean
