## Purpose

Сводный runner полной проверки работоспособности проекта: гоняет игру по всем точкам входа (сцены, авто-сценарии, юнит-тесты) через цикл `godot-run-and-fix` (запусти → поймал ошибки/предупреждения → починил → проверил) и выдаёт вердикт «консоль чиста» с отчётом.

## ADDED Requirements

### Requirement: The operability gate exercises all entry points
The operability runner **MUST** run the game end-to-end across every entry point: the scenes (`MainMenu`, `CityArena`, `World`, `Battle`), the auto-game scenarios (`scenario_{1..7}`), and the unit tests.

#### Scenario: Run across entry points
- **WHEN** the operability runner is invoked
- **THEN** it launches each scene, each scenario, and the unit test suite, capturing output for each

### Requirement: The operability gate applies the run-and-fix loop
The runner **MUST** implement a run-and-fix loop (run → capture → scan → fix → verify) using the `godot-run-and-fix` skill: after each run it scans the captured console, and on any finding it applies the skill's fix patterns and re-runs until the console is clean.

#### Scenario: Fix until clean
- **WHEN** a run produces a `SCRIPT ERROR` or a warning outside the allowlist
- **THEN** the runner fixes it per the skill templates and re-runs that entry point until no findings remain

### Requirement: The operability gate reuses existing gates
The runner **MUST** reuse the existing gates (`check_console_clean.sh`, `run_all_ci_checks.sh`, `play_scenario.sh`) and the `docs/CONSOLE_ALLOWLIST.md` allowlist instead of redefining markers or duplicating logic.

#### Scenario: No duplicated markers
- **WHEN** the runner needs error/warning markers or the allowlist
- **THEN** it consumes them from `check_console_clean.sh` / `docs/CONSOLE_ALLOWLIST.md` rather than maintaining its own copy

### Requirement: The operability gate produces a verdict and report
The runner **MUST** emit an operability verdict (clean / dirty) and write a report (to `/tmp/operability_report.md`) listing the entry points exercised, the findings, and the final state after fixing.

#### Scenario: Report is written
- **WHEN** the runner finishes
- **THEN** `/tmp/operability_report.md` contains the list of entry points, the findings, and a clean/dirty verdict

### Requirement: Every Godot run is hang-prevented
Every Godot invocation in the operability gate **MUST** go through a hang-preventing wrapper (`run_godot`) with an explicit timeout, and the runner **MUST** fail loudly if a run cannot be terminated.

#### Scenario: A hung scene is killed
- **WHEN** a scene run exceeds its timeout
- **THEN** the wrapper kills the process and the runner reports the timeout rather than blocking indefinitely
