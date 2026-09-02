# Proposal: operability-verification

## Why

В проекте есть гейты **проверки** (`run_all_ci_checks.sh`, `check_console_clean.sh`, `play_scenario.sh`, юнит-тесты), но они только **ловят** проблемы — ни один из них не гоняет игру **полностью через скил `godot-run-and-fix`** (запусти → поймал → починил → проверил) по всем точкам входа и не даёт сводного вердикта «работоспособна/нет». В результате цикл может быть закоммичен, пока в консоли остаются `SCRIPT ERROR` / runtime-ошибки / предупреждения вне allowlist.

## What Changes

- Добавить сводный **runner полной проверки работоспособности** (`game/tools/shell/run_operability.sh`), который гоняет игру по **всем точкам входа**: сцены (`MainMenu`, `CityArena`, `World`, `Battle`), авто-сценарии (`scenario_{1..7}`), юнит-тесты.
- Реализовать **run-and-fix цикл** (run → capture → scan → fix → verify) на основе скила `godot-run-and-fix`: любая строка-ошибка или предупреждение вне allowlist → чиним по шаблонам скила → повтор, пока консоль чиста.
- **Использовать** существующие гейты (`check_console_clean.sh`, `run_all_ci_checks.sh`, `play_scenario.sh`) вместо дублирования.
- Выдать **операбильный вердикт + отчёт** (`/tmp/operability_report.md`): чисто/грязно, список находок, по каким точкам вход прогонялось.
- Оборачивать **каждый** запуск Godot в hang-preventing обёртку (`run_godot` из AGENT.md, правило 8.1).

## Capabilities

### New Capabilities
- `operability-verification`: сводный runner полной проверки работоспособности по всем точкам входа со скил-циклом run-and-fix и отчётом-вердиктом.

### Modified Capabilities
- _(нет изменений требований к существующим возможностям; описана только новая)_

## Impact

- `game/tools/shell/run_operability.sh` (новый), интеграция с `check_console_clean.sh`, `run_all_ci_checks.sh`, `play_scenario.sh`.
- `game/tools/*.gd` — точки входа для сцен (SceneTree-скрипты `_init()` + `quit()`).
- `AGENT.md` — ссылка на runner и скил `godot-run-and-fix` как на процедуру верификации.
- `docs/CONSOLE_ALLOWLIST.md` — переиспользуется как источник allowlist-паттернов.
- Зависимость: Godot 4.x в PATH (`GODOT_BIN`); реестр `global_script_class_cache.cfg` (авто-загрузка, как в CI).
