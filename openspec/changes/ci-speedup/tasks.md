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
- [ ] 2.2 `run_tests.sh`: `MCP_WORKERS` (дефолт 1); при >1:
  `-n $MCP_WORKERS`; при отсутствии pytest-xdist в venv — явная
  строка (уровень не молчит)
- [ ] 2.3 venv CI (ci2.yml) + инструкция в AGENTS.md: +pytest-xdist
  в состав MCP-venv
- [ ] 2.4 Локально: `MCP_WORKERS=3 bash run_tests.sh` — 38 тестов
  зелёные, порты 9090/9091/9092 в логах, леджер-равенство
  (collected == executed) удерживается под xdist
- [ ] 2.5 Локально: `bash run_tests.sh` без env — поведение как до
  (1 воркер, 9090)

## Фаза 3: Пересборка ci2.yml (4 job'а + кэши)

- [ ] 3.1 `static` job: checkers + lint (gdtoolkit venv → кэш) +
  DOCS-LINKS
- [ ] 3.2 `gdunit` job: Godot (кэш бинаря) + --import + GdUnit4
  (полный `-a res://tests`), exit-код политика 0/101
- [ ] 3.3 `mcp` job: apt (xvfb+libs), node, pip-venv (кэш), Godot
  (кэш), npm ci (кэш node_modules), Xvfb-скан, `MCP_WORKERS=3`,
  ретраи ×3 (CI-1(12)), артефакт логов (все попытки)
- [ ] 3.4 `verdict` job: `needs: [static, gdunit, mcp]`,
  `if: always()` — CI-2 Stability (D-174, код без изменений) +
  4-уровневая строка (D-147): GdUnit/MCP/DOCS-LINKS/CHECKERS
- [ ] 3.5 Concurrency-группа и `on:` (push '**' + PR) — без
  изменений; timeout-minutes: 45 → 20
- [ ] 3.6 Balance metrics + balance-report артефакт: перенос в
  `gdunit` job (нужен только Godot)
- [ ] 3.7 YAML-валидация (checker 5) + локальный dry-run логики
  (bash -n, python yaml.safe_load)

## Фаза 4: Приёмка (design §Measurement)

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
