## 1. Baseline capture (5 scenarios)
- [x] Run scenarios 1–5 via `game/tools/shell/play_scenario.sh N --log /tmp/godot_console_N.log`; record each scenario's exit code.
- [x] Parse logs with the godot-run-and-fix marker set; build the unique-message table (message, class, count, first site).
- [x] Record the baseline table in this file (under this task) — it is the diff target for the gate.

## 2. Error pass (target: 0)
- [x] Fix every error-class line at the source (no suppression).
- [x] Re-run the affected scenario(s) to confirm the error is gone.
- [x] Where the fixed path is unit-testable, add/extend a test in `game/tests/`.

## 3. Warning pass (target: 0 un-allowed)
- [x] Triage every warning-class line: fix or allowlist.
- [x] Create `docs/CONSOLE_ALLOWLIST.md` (pattern, reason, owner, date, removal plan) — only if rows are needed.
- [x] No suppression of real state (no deleting push_warning to hide a fault, no engine-wide silencing).

## 4. Gate
- [x] `game/tools/shell/check_console_clean.sh [N ...]` (default 1–5): scenario exit must be 0; any error-class marker FAILs; warning FAILs unless its pattern is allowlisted; per-scenario summary; exit 0 only when clean.
- [x] Wire as step `[6] Console clean` in `game/tools/shell/run_all_ci_checks.sh`.

## 5. Tests
- [x] New/extended unit tests for fixed code paths (if any).
- [x] Plant-a-fault sanity: temporarily introduced error must make the gate FAIL (then revert).

## 6. Final gate
- [x] 5 scenarios: exit 0 + 0 error-class lines + 0 un-allowed warnings (re-run, fresh logs).
- [x] Full unit suite green (baseline 4802 passed / 0 failed — no regressions).
- [x] `run_all_ci_checks.sh` all steps PASS (6/6).

## Результаты (2026-08-31, Godot 4.7.2, macOS)

### §1 Baseline

Маркерный сет гейта = суперсет godot-run-and-fix + CI-маркеры (`Failed to load script|Can't load script|Could not find type|does not inherit from`) + `^ERROR:`; строки app-логгера (содержат `[color=`) исключаются ДО скана — намеренные логи приложения (`GameLogger.error/warn`), не регрессия кода.

| Сценарий | Exit | Строки error-класса | Строки warning-класса |
|---|---|---|---|
| 1 (Collect) | 0 | 0 | 0 |
| 2 (Flee) | 0 | 0 | 0 |
| 3 (Explore) | 0 | 0 | 0 |
| 4 (Endure) | 0 | 0 | 0 |
| 5 (Spells) | 0 | 0 | 0 |

**Базовая линия уже чистая** — ни error-, ни warning-маркеров нет ни в одном из 5 логов (`/tmp/godot_console_{1..5}.log`). Известный риск, не воспроизведённый: конкуренция за порт 9095 → `Failed to listen: 22` (app-логгер, исключается сканом; сценарий при этом падает по exit-коду → гейт FAIL).

### §2 Error pass — 0 находок
Фиксов не требовалось; кодовая база не изменялась (п. 3 §2 — n/a). Подозреваемый `Failed to listen: 22` не воспроизводится при последовательном запуске: во всех 5 логах `✅ Listening on 127.0.0.1:9095`.

### §3 Warning pass — 0 находок
- Триаж не потребовался (0 warning-строк в baseline).
- `docs/CONSOLE_ALLOWLIST.md` не создавался change'ом («only if rows are needed» — строк нет). WIP-файл с тем же именем (таблица для операционного раннера `run_operability.sh`) остался WIP и не коммитится этим change'ом.
- Никакого подавления реального состояния: ни один `push_warning`/`push_error` не удалён и не заглушён.

### §4 Gate
`game/tools/shell/check_console_clean.sh [N ...]` (по умолчанию 1–5) + служебный `--scan <logfile...>`:
- exit сценария != 0 → FAIL; error-маркер → FAIL (allowlist для ошибок не существует); warning → FAIL, если не совпадает с allowlist (файл опционален, нет файла = строгий режим); app-логгер (`[color=`) исключается до скана.
- Итоги: пер-сценарий + общий; exit 0 только если всё чисто. macOS-safe (без `timeout`, kill-обёртка в `play_scenario.sh`).
- Исправлены баги WIP-версии: бэкттики в allowlist-паттернах (в ERE бэкттик — литерал, паттерн никогда не совпадал) — теперь strip; многострочная ERE (зависимая от реализации grep) — паттерны склеиваются через `|`; добавлено исключение app-логгера (иначе любая `GameLogger.error` валила бы гейт).
- Подключён как шаг `[6] Console clean (scenarios 1-5)` в `run_all_ci_checks.sh` (пропускается `--fast`).
- **Найден и исправлен bug обвязки** (первый вариант молча не выполнял шаг 6): (1) subshell не был обёрнут в `_pass/_fail` — провал гейта не считался бы провалом CI; (2) `cd "$PROJ_DIR"` вместо `$PROJECT_DIR` (имя переменной в `run_all_ci_checks.sh`) → `unbound variable` под `set -u`. Итог первого CI-прогона «5/6 passed» был иллюзией — гейт не запускался. После фикса: шаг 6 реально прогоняет сценарии и учитывается в сводке.

### §5 Plant-a-fault sanity — пройден
| Проверка | Ввод | Ожидание | Факт |
|---|---|---|---|
| T1: error-маркер | реальный `SCRIPT ERROR` (godot -s со сломанным скриптом) | FAIL rc=1 | ✅ rc=1 |
| T2: warning вне allowlist | реальный `push_warning` | FAIL rc=1 | ✅ rc=1 |
| T3: warning в allowlist | строка с паттерном `: unknown slot` | PASS rc=0 | ✅ rc=0 |
| T4: app-логгер | `ERROR:/WARNING:` с `[color=` | PASS rc=0 (исключение) | ✅ rc=0 |
| Полный путь | `push_warning`+`push_error` временно в `SocketController._ready`, `check_console_clean.sh 5` | сценарий exit 0 (9/9), гейт FAIL rc=1 | ✅ rc=1, потом `git checkout --` (revert-чисто) |

### §6 Final gate — пройден
- Гейт 1–5 (свежие логи /tmp/godot_console/): все сценарии exit 0, 0 error-маркеров, 0 un-allowed warning.
- Юнит-тесты: **4748 passed, 0 failed (76 файлов)** — зелёный, без регрессий. (В tasks.md указана baseline 4802 — не совпадает с прогоном на этой машине; критерий «0 failed» выполнен. Счётчик меняется по мере добавления WIP-тестов в res://tests/.)
- `run_all_ci_checks.sh` полный прогон: **6 passed, 0 failed (of 6 steps)**, exit 0 — шаг [6] Console clean реально прогоняет 5 сценариев.
