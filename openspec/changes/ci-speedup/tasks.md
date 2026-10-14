# Tasks: ci-speedup

Ветка: `feat/ci-speedup` (от main). Гейт: локальный полный + CI-2
зелёный на ветке. Мерж — через merge-ветку после зелёного (D-144).

## Фаза 0: Baseline (D-148)

- [x] 0.1 Зафиксировать baseline: wall time последнего зелёного рана
  main (jobs API, по шагам) + строка «было 6м41с (38443410901)» в
  отчёт; MCP-коридор-факт (259с, 38 тестов)
  → ФАКТ: 38443410901 (f0817a00, 2026-10-13, success): wall 6м41с;
  MCP e2e 259с, GdUnit4 69с, lint 26с, setup ~31с, ост. ~15с
- [x] 0.2 Снимок счётчиков: GdUnit4 2474, MCP 38 (для сверки после)
  → ФАКТ: GdUnit4 2474 (0 err/0 fail/2sk, exit 0), MCP 38 (37 pass +
  1 skip на зелёном)

## Фаза 1: Настраиваемый порт (вендор, аддитивно)

РЕВИЗИЯ (при реализации): на main уже есть домашний MCP-сервер
`game/tools/mcp/mcp_interaction_server.gd` (world-controller-
decoupling, adf523c0) — autoload в project.godot указывает на него;
он уже читает `MCP_PORT` (env → ProjectSettings mcp/port → 9090)
+ EADDRINUSE-диагностика. Вендорный root-скрипт — мёртвый файл.
→ Портируется только node-сторона (index.ts) на `MCP_PORT`;
правка вендорного .gd отменена.

- [x] 1.1 `addons/godot-mcp/src/index.ts`: `INTERACTION_PORT` из
  `process.env.MCP_PORT` (дефолт 9090, Number)
- [x] 1.2 Godot-сторона: изменений НЕ требуется (домашний
  `tools/mcp/mcp_interaction_server.gd` уже читает `MCP_PORT`);
  первая итерация (правка вендорного .gd) отменена — тот файл не
  грузится (autoload → tools/mcp/)
- [x] 1.3 `npm run build` в аддоне (build/ gitignored — CI собирает
  сама; в коммит — только src)
- [x] 1.4 Локальная проверка: без env — 9090 (PASSED); с
  `MCP_PORT=9091` — 9091 (PASSED); лог «Connected to game
  interaction server on port 9091»
- [x] 1.5 Vendor-drift: сообщение коммита + code-комментарий
  (прецедент stdin-ignore); docs/CHANGELOG.md — вне (скоуп docs/)

## Фаза 2: Воркеры (conftest + run_tests.sh)

- [x] 2.1 `conftest.py`: `_worker_port()` — явный `MCP_PORT` →
  индекс `PYTEST_XDIST_WORKER` (gwN → 9090+N) → 9090;
  `SERVER_ENV["MCP_PORT"] = str(_worker_port())` (mcp-SDK не
  наследует shell-env — env передаётся явно, stdio.py:129)
- [x] 2.2 `run_tests.sh`: `MCP_WORKERS` (дефолт 1); при >1:
  `-n $MCP_WORKERS`; при отсутствии pytest-xdist в venv — явная
  строка + фолбэк на 1 воркер (уровень не молчит, гейт не
  ослабевает). **Леджер-парсинг под xdist:** нет строки «collected
  N items» — хедер «N workers [M items]» (добавлен фолбэк-парсинг)
- [x] 2.3 venv: локально `pip install pytest-xdist` (3.8.0);
  состав venv + MCP_WORKERS-документация в AGENTS.md (2 строки);
  CI-венв — фаза 3 (3.3)
- [x] 2.4 Локально: `MCP_WORKERS=3 bash run_tests.sh` —
  **35 passed / 1 skipped / 2 failed** (из 38): оба падения =
  balance_probe — **пре-экзистинг (T-125):** на этой машине
  красный и в serial, и на чистом main-база (db5588da, worktree:
  180.18с world-bootstrap timeout); CI-2 baseline 38443410901
  зелёный. D-166-класс: канон — CI-2. Порты 9090/9091/9092 в
  логах, леджер-равенство работает (collected=38).
  **Баг, найденный прогоном и исправленный:** preflight
  `wait_port_free` в godot_mcp.py хардкодил 9090 → 22/24 ложных
  «порт 9090 занят» на соседних воркерах (первый 3-worker прогон);
  клиент теперь получает порт воркера (conftest → GodotMCPClient)
- [x] 2.5 Локально: `bash run_tests.sh` без env — поведение как до
  (1 воркер, 9090): проверено фаза 1 (1.4) + serial-прогоны проба
  (T-125-диагностика); GdUnit-часть не затронута (MCP_WORKERS не
  влияет)

## Фаза 3: Пересборка ci2.yml (4 job'а + кэши)

- [x] 3.1 `static` job: checkers + lint (gdtoolkit venv → кэш
  `ci2-lint-venv-gdtoolkit-4.5.0`) + DOCS-LINKS; level-строки
  (CHECKERS/LINT/DOCS-LINKS) → артефакт `ci2-static-logs`
- [x] 3.2 `gdunit` job: Godot (кэш `godot-4.7-stable-linux-x86_64`)
  + --import + GdUnit4 (полный `-a res://tests`), exit-код
  политика 0/101; level-строка (RC + Overall Summary) → артефакт
  `ci2-gdunit-logs`; Diagnostics `if: failure()` (::error::-аннотации,
  D-167)
- [x] 3.3 `mcp` job: apt (xvfb+libs), node, pip-venv (кэш
  `ci2-mcp-venv-v1`, +pytest-xdist, импорт-проверка = валидация
  кэша), Godot (кэш), npm ci (кэш по package-lock hash),
  `MCP_WORKERS=3`, ретраи ×3 (CI-1(12)), артефакт `ci2-mcp-logs`
  (все попытки + level-строки); Diagnostics `if: failure()`
- [x] 3.4 `verdict` job: `needs: [static, gdunit, mcp]`,
  `if: always()` — 4-уровневая строка (D-147: GdUnit4/MCP/
  DOCS-LINKS/exit-code) через `needs.*.result` + `::notice::`
  (публичный канал без токена, D-167-семья) + CI-2 Stability
  (D-174, код без изменений). Репортёр, не гейт: workflow-красный
  идёт от gate-job'ов
- [x] 3.5 Concurrency-группа и `on:` (push '**' + PR) — без
  изменений; timeout-minutes: 45 → per-job (static 10, gdunit 15,
  mcp 20, verdict 5)
- [x] 3.6 Balance metrics + balance-report артефакт: перенос в
  `gdunit` job (нужен только Godot)
- [x] 3.7 YAML-валидация (checker 5) + локальный dry-run логики
  (bash -n по всем run-блокам, python yaml.safe_load) — OK.
  **Найден и исправлен гейт-баг:** GitHub-шаги идут с `-eo pipefail` —
  при падении пайплайна шаг умирал до снятия RC (level-строки
  терялись; DOCS-LINKS/lint могли выйти 0). Явные `set +o pipefail` +
  `RC=${PIPESTATUS[0]}` + гейт-команда в конце шага

## Фаза 4: Приёмка (design §Measurement)

CI-ФАКТ (2026-10-14): ран 38485389297 (первый пуш, MCP_WORKERS=3) —
RED: static ✓, gdunit ✓, mcp ✗ (20m job-timeout: 3 ретрая × T-125-стоп
пробов — contention на 4 ядрах открывает race-окно; timeline совпадает:
3×~7.5 мин ≈ отмена 23:57:52). Коррекция: MCP_WORKERS=2 на CI (2 ядра
на Godot + 2 запаса; serial на раннере зелёный — стоп speed-зависимый);
job timeout 20→30. 3 воркера — после фикса T-125.

- [ ] 4.1 Локальный полный гейт (run_tests.sh, без env) — зелёный,
  счётчики 2474/38 не изменились
- [ ] 4.2 Пуш ветки → CI-2: wall time мcp-жоба (цель ≤ ~130с
  включая setup), общий wall ≤ 3 мин
- [ ] 4.3 Три зелёных рана main после мержа: wall time каждого в
  отчёт (D-148: было 6м41с → стало X)
- [ ] 4.4 Красный-ран проверка: тест-ветка с падающим MCP-тестом →
  ретраи ×3, verdict отработал, stability-строка на месте, wall ≤
  ~8 мин (ветка удаляется после проверки)
- [ ] 4.5 Отчёт владельцу: 4 уровня (D-147) + baseline-строка
  (D-148) + vendor-drift (D1.5) + решение по стадии 3 (GdUnit-
  шардирование) — нужно ли
