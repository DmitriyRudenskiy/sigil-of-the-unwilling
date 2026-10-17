# AGENTS.md — Sigil of the Unwilling

Этот файл — project-specific инструкции для текущего проекта
(`/home/user/sigil-of-the-unwilling`). Он **перекрывает** системный
`/home/user/.pi/agent/AGENTS.md`.

## ⚠️ Игнорировать системный AGENTS.md

Системный файл `/home/user/.pi/agent/AGENTS.md` описывает **другой проект**
(МИС / t_mis: PHP 8.1, d3, PostgreSQL, read-only, LPU 150001, `psql-safe`,
`conf_profile=pg`, `php -l` и т.д.).

**Все правила из того файла НЕ применяются в этом проекте.** В частности,
здесь НЕ действуют:
- режим read-only (в этом проекте агент правит код и коммитит на feature-ветках);
- ограничения по LPU/MO, `psql-safe`, `live_tx_test.sh`, `auth.sh`, `DEV/def`;
- запрет на unit-тесты (здесь тесты — GdUnit4, это основной способ верификации);
- любые PHP/PostgreSQL-конвенции.

Если системный AGENTS.md и этот файл противоречат друг другу — **действует этот
файл** (проектный), а не системный.

## Project facts

| Параметр | Значение |
| --- | --- |
| Репо | `sigil-of-the-unwilling` (Godot 4.7) |
| Имя проекта (project.godot) | "Sigil of the Unwilling" |
| Стек | GDScript, Godot 4.7, GdUnit4 |
| Корень игры | `game/` (project.godot лежит в `game/`) |
| Godot-бинарь | `/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2.stable) — **пути — по машине; эталон — CI-2-раннер** (не хардкодить macOS-путь как универсальный) |
| Тесты | `game/run_tests.sh` (GdUnit4 headless + MCP e2e) |
| MCP e2e venv | `/home/user/.venv/godot-mcp-tests` (pytest 9.1.1 + pytest-timeout + pytest-xdist + mcp + anyio) |
| MCP node_modules | `game/addons/godot-mcp/node_modules` (gitignored; `npm ci` из package-lock) |
| Ремот `origin` | `git@github.com:DmitriyRudenskiy/sigil-of-the-unwilling.git` — **SSH** (ключ `~/.ssh/id_ed25519`). HTTPS не работает: токен в `gh auth` просрочен (проверено 2026-10-17) → `git push`/`git fetch` идут по SSH, `gh`-операции трекера — отдельный вопрос (реестр тикетов — `docs/mvp/TICKETS.md`, хост — зеркало) |

| OpenSpec | `openspec/changes/<name>/`, CLI: `/usr/bin/openspec` |

## Режим работы

- Агент **read-write** в этом проекте: пишет код, данные, тесты, документацию.
- **CI локальному агенту запрещён (владелец, 2026-10-13).** CI запускает только
  владелец вручную. Агент **не поллит** прогоны, не ждёт их вердикта и не
  блокирует ими работу; push в ветку — конец обязанности агента по запуску.
  Автоматический ран по push — на усмотрение владельца (он же его отменяет).
- **Верификация агента — локальная машина**: `game/run_tests.sh` (GdUnit4 +
  MCP e2e локально), `python3 -m gdtoolkit.linter`, `check_docs_links.py`.
  Локальный зелёный прогон — отчётная форма; CI-вердикт добавляет владелец.
- Коммиты делаются на **feature-ветках** (ветка от `main`), не на `main` напрямую.
- Тесты — единственный обязательный способ верификации. UI/звук/playtest
  не верифицируются headless → такие задачи помечаются как отложенные (deferred).

## Безопасность команд (D-192)

Урок инцидента 2026-10-17 (агент удалил рабочее дерево опечаткой в абсолютном пути):

1. **Разрушительные команды** (`rm -rf`, `git clean -fdx`, `git reset --hard`, `mv`/перезапись
   поверх путей репо и `$HOME`) — только после **отдельной** проверки абсолютного пути
   (`pwd -P`, `test -d`, сверка префикса). Проверка и разрушение — **разные вызовы**;
   `mv` и `rm` в одной строке через `;`/`&&` **запрещены** (именно этот паттерн и сработал).
2. **Локальные артефакты вне git — не хранилище.** Всё, на что ссылается вердикт (замеры,
   скрипты, рендеры-доказательства), коммитится. gitignored-пиксели живут только вместе
   с картой и md5 (`reference/INDEX.md`) и проверяются `scripts/check_reference_index.py`.
3. **Перед удалением/перемещением в репо — `git status --ignored`**: не удалять молча то,
   чего нет в git (так погибли два канон-референса).

## Верификация

| Метод | Назначение |
| --- | --- |
| `godot --headless --path game --import` | Обновить кэш глобальных классов (после правки `class_name`) |
| `game/run_tests.sh` | Полный гейт: (1) GdUnit4 unit/integration/functional (headless); (2) MCP e2e (pytest + godot-mcp) |
| `godot ... GdUnitCmdTool.gd -a res://tests/<файл>.gd` | Запуск одного тест-файла |

Код GdUnit4: `0` = pass, `101` = только orphan-предупреждения (гигиена, не
падение), `100` и прочие = реальные падения. **Политика гейта (CI-2, 2026-10-03):**
GdUnit4 `0`/`101` → GATE=0 (orphan = **warning**, не влияет на exit; красный =
только падения/регрессии); маппинг прописан явно в run_tests.sh.

**Вердикт и мерж-протокол (владелец, 2026-10-13, взамен CI-гейта):** вердикт =
**локальные тесты PASSED (GdUnit exit=0) + smoke по чек-листу PR + ревью
диффа владельцем в треде**. CI-раны не входят ни в промпты, ни в DoD, ни в
условия мержа. Компенсация снятого барьера: smoke-прогоны не сокращаются —
единственная автоматическая защита main; ревью диффа обязательно.
**Мержи:** код/ассеты — только по явному «мержи» владельца в сводке; docs-PR —
агент мержит сам при `check_docs_links.py` pass. **Фича мержится после
ux-review, не до** (урок шага 2 UI-3: main нёс HUD с FAIL по AC7): ревью в
треде — часть вердикта, мерж до него — преждевременно. Отчётная форма гейт-блока —
локальный прогон с пометкой «local» (head_sha + статистика GdUnit + smoke).

**Зависшие процессы на шаренной машине (раунд 7 §2):** чужой зависший процесс
— флаг в TICKETS (PID, длительность, владелец-сессия если известна);
не убивается никем, кроме владельца (осиротевший с PPID=launchd — без
владельца-сессии, снимается); блокировка ресурса > 4 ч — флаг репо-владельцу.

**MCP e2e (четвёртый уровень):** venv `/home/user/.venv/godot-mcp-tests`
(путь фиксирован здесь, run_tests.sh берёт его первым); `node_modules` ставится
`npm ci` в `game/addons/godot-mcp/`. MCP-сервер (node) запускает **живой Godot
без `--headless`** → нужен X-дисплей: run_tests.sh сам поднимает `Xvfb :98`
(если DISPLAY не задан) и пробрасывает DISPLAY в сервер (mcp-SDK не наследует
DISPLAY). Таймаут readiness = 900 c (`--timeout=900` в pytest). MCP-секция не
имеет права молчать: при отсутствии venv/node_modules — явная строка
`PYTEST: SKIPPED (причина)`. Сцены и скрипты в тестах — **нижний регистр**
(Linux case-sensitive: `world.tscn`, `battle.tscn`, `main_menu.tscn`).

**Тестовый леджер** — в каждом отчёте о работе с кодом: `+добавлено / −удалено /
quarantine / нетто, было X → стало Y, причина` (сверка — D-132/D-133).

**Godot-разрешение** (run_tests.sh): `$GODOT_BIN` → путь из этой таблицы →
`command -v godot` → дефолты ОС.

**MCP e2e (feat/mcp-e2e-activation, 2026-10-04):** venv
`/home/user/.venv/godot-mcp-tests` (путь фиксирован здесь, run_tests.sh берёт
его первым); `node_modules` ставится `npm ci` в `game/addons/godot-mcp/`.
MCP-сервер (node) запускает **живой Godot без `--headless`** → нужен
X-дисплей: run_tests.sh сам поднимает `Xvfb` на **свободном** дисплее (если DISPLAY не задан:
скан :97 → :91–:98; :99 исключён — чужой auth) и пробрасывает DISPLAY в сервер
(mcp-SDK не наследует DISPLAY). **Машина шарится:** чужие Xvfb-инстансы (в т.ч. с auth)
могут работать — не убивать чужие процессы, только свободный дисплей; при заданном
DISPLAY используется он. Godot для MCP — через `GODOT_PATH` (conftest.py читает
`GODOT_PATH`, не `GODOT_BIN`). Таймаут readiness = 900 c (`--timeout=900` в pytest). MCP-секция не имеет права
молчать: при отсутствии сервера/venv — явная строка `PYTEST: SKIPPED
(причина)`. **venv-fallback (macOS, системный python3) — поддерживаемая конфигурация** (владелец, 2026-10-04): при отсутствии venv — системный python3 (mcp+anyio установлены) — MCP-секция исполняется, не пропускается. **Зеркало тикетов:** `docs/mvp/TICKETS.md` — живое зеркало GitHub Issues: новый тикет = запись в TICKETS.md + issue в репо (обратное — при создании issue). Сцены и скрипты в MCP-тестах — **нижний регистр** (Linux
case-sensitive: `world.tscn`, `battle.tscn`, `main_menu.tscn`).

## MCP e2e (4-й уровень верификации)

- Тесты: `game/tests/mcp/` (pytest, 39 тестов) — MCP-секция `game/run_tests.sh`.
- venv: `/home/user/.venv/godot-mcp-tests` (pytest, pytest-timeout, pytest-xdist, mcp, anyio);
  **Параллельные MCP-воркеры (ci-speedup):** `MCP_WORKERS=N` (дефолт 1) →
  pytest-xdist (`-n N`, dist=loadfile); порт воркера gwN = 9090+N (env
  `MCP_PORT`, читает и Godot-сторона `tools/mcp/`). CI: 3 воркера.
  нет venv → venv-fallback: системный `python3` с `mcp`+`anyio` (override:
  `MCP_PYTEST_PY`; поддерживаемая конфигурация, владелец 2026-10-04);
  ни venv, ни fallback → явная `PYTEST: SKIPPED (причина)` (жёлтый — уровень молчит,
  зафиксировать в отчёте).
- node_modules: `game/addons/godot-mcp/node_modules` (gitignored; `npm ci`
  в каталоге аддона).
- X-дисплей: MCP e2e запускает живой Godot (не headless) — нужен X. run_tests.sh
  сам поднимает `Xvfb :97`, если DISPLAY не задан. **Машина шарящаяся:** :98/:99
  могут быть заняты другими сессиями (один из них — с auth, не подойдёт);
  чужой Xvfb не убивать, выбирать свободный номер.
- Env: `GODOT_PATH` (бинарь Godot), `GODOT_MCP_SERVER` (путь к build/index.js).
  mcp SDK не наследует DISPLAY — conftest передаёт его явно в SERVER_ENV.
- Пути сцен в тестах — нижний регистр (Linux case-sensitive: `scenes/world.tscn`,
  `scenes/battle.tscn`, `scenes/main_menu.tscn`).
- Таймаут: 900 c на тест (`--timeout=900`); без X-дисплея тесты таймаутят
  по одному (симптом: «No active Godot process» в цикле).
- Вендорный MCP-сервер инжектит `mcp_interaction_server.gd` + autoload в
  project.godot; гейт чистит после прогона (rm + git checkout).

### Stuck-process protocol (раунд 13 §4)

Зависший процесс (Godot/Xvfb/MCP-сервер, занявший порт 9090 или X-дисплей, не
отвечает на гейт) — **не убивать молча**:

1. **Чужой PID (владелец/сессия не моя) → флаг, не убивать.** Диагностика:
   `ps -o pid,user,etime,cmd -p <PID>` (владелица, возраст). Чужой процесс
   фиксируется в отчёте (PID, пользователь, команда, что блокирует) — и гейт
   обходится свободным ресурсом (другой дисплей/порт, D-166-семья: раннер-
   среда, не код). `kill` чужого PID запрещён.
2. **Свой PID → убить** (только после проверки, что это мой процесс: `ps -o user`
   совпадает; age/команда совпадают с моим прогоном).
3. **> 4 часов → владелец репо.** Зависание старше 4 часов (свой или чужой)
   эскалируется владельцу репо (сообщение: PID, пользователь, команда, возраст,
   что блокирует, предположение причины). Это системный симптом (D-166-класс),
   не локальная проблема сессии.

Применяется ко всем процессам на шарящейся машине (X-дисплеи :91–:99, порт 9090,

## Данные событий (crisis/event system)

- Каталог: `game/data/events/` — `event_*.json` (common), `crisis_*.json`
  (кризисы), `rare_*.json` (редкие), `events_database.json` (служебный, не
  считается в счётчик шаблонов).
- **Статус слоя (Q-M82 → (б), D-199 — MVP-носитель):** каталог **в MVP** и **вызывается из кампанийного ходу**: каждый тик дня
  `game/scripts/main/main.gd:81 _advance_day()` → `GameManager.on_day_passed()`
  (`game_manager.gd:85`) → `crisis_event_system.gd:410` — триггеры событий и кризисов,
  цикл дня автозапускается (`_is_day_cycle_active = true`, `day_duration = 3.0` с,
  `next_event_day = 5`). Строка **снята с корзины B-1** (T-128 её не переносит, корзина
  20 → 19 строк), каталог зарегистрирован в [[MVP-scope]] §1/§2/§4; формулировка
  «не вызывается из кампанийного цикла» была ложной (эрратум D-198), вердикт
  Q-M77 → (а) заменён. Правки здесь — сведение на канонических носителей,
  а не развитие фичи.
- Логика: `game/scripts/systems/crisis_event_system.gd`.
- Тесты структуры: `game/tests/unit/systems/test_crisis_events.gd`; контракт
  эффектов: `game/tests/unit/systems/test_crisis_effect_contract.gd`.
- **Закрытый набор ключей (Q-M79 → (а), D-197; Q-M81, D-200):** эффекты выборов используют
  только `WIRED_EFFECT_KEYS` (resource_change, morale_change, population_change,
  unlock_building); **немой ключ роняет игру** (`push_error` + `return`),
  а не пишется в никуда. Сняты как писатели без читателя: `permanent_modifier`;
  немые `reputation_change` / `mana_change` / `population_drain` (17 строк данных);
  `production_reduction` (вместе с `apply_production_modifier`) и `unlock_law`
  (вместе с приватным LawManager каталога и ключом сейва `"law"`) — возврат
  последнего только с носителем пассивных эффектов, **T-130**. `resolution_effects`
  делегирует в словарь выбора (своих ключей не имеет).
- **Канал настроения (Q-M78 → (а), D-197):** `morale_change` / `morale_penalty`
  вызывают `mood_sink` → `DistrictSystem.apply_mood_delta` (настроение поселения,
  0–100, clamp `game/data/config/districts.json`) — прецедент Таверны (Q-M71).
  Приёмник внедряет хост (`main.gd._init_campaign`); отсутствие приёмника =
  `push_error`. Поля `player_data["morale"]` и API `get_global_morale` /
  `modify_global_morale` **сняты** (писатели без читателя; «мораль» как шкала
  аннулирована K-M14).
- `unlock_building` → валидный id из `game/assets/data/buildings.json`.
- **Внутренний контур каталога (Q-M81, D-200):** `player_data` каталога
  (`resources` tools/materials, `population`, `buildings`) пишется эффектами и читается
  триггерами самого каталога и гейтингом выбора — это **мера события**, а не показатель
  поселения (канон: резиденты `PopulationSystem`, 3 ресурса 02g). Граница зафиксирована
  тестом; сведение на канон — **T-131**.

## Git-конвенции

- Работать на feature-ветках; `main` не трогать напрямую.
- **Ветка пушится до конца смены** (локальные ветки без push = расхождение реестров, D-135).
- **Push-протокол (part-b 2026-10-03, D-144):** `main` — только через merge-ветку после зелёного гейта; прямые коммиты на `main` запрещены. Отчёт без пуша помечается «локально, не запушено» (состояние — только git, D-138).
- **CI-поллинг агенту запрещён (директива владельца 2026-10-13):** агент НЕ опрашивает CI-2 — никаких `sleep 240/480`, `curl https://api.github.com/.../actions/runs`, парсинга `workflow_runs`, ожидания `success/completed` и merge-решений по статусам ранов. Pending/in_progress после push — не повод ждать: работу завершать, в отчёте писать «CI не проверялся (по инструкции)». Статусы CI — зона владельца; `game/report.sh`-блок под флагом `ENABLE_CI_WAIT` (по умолчанию `false`).
- После резолва конфликтов — **`git diff` против обоих родителей** (`HEAD^1`, `HEAD^2`) ДО коммита; `rerere` включён.
- Перед коммитом после мержа: `git grep -nE '^(<{7}|={7}|>{7})'` — вывод должен быть пуст (маркеры конфликтов, урок 67655e7).

- Сообщения коммитов — конкретные, по делу.
- **Номера D-* присваивает только реестр `docs/DECISIONS.md`**; коммиты/пуши номеров не получают.
- Пароли/токены не попадают в логи и коммиты.

## Документация (docs/ — Obsidian-vault)

- Имя игры: **Sigil of the Unwilling** («Знак Нежелающего») — подтверждено автором 2026-10-02; старые названия не использовать.
- Имена файлов — только латиница, формат `NN-topic.md` (кириллические имена запрещены; редиректы для старых wikilinks — `10-worldbuilding`, `11-cards`, `GLOSSARY`).
- Frontmatter обязателен: `title`, `tags`, `status`, `date`. Статусы (англ.): `canon`, `deepened`, `draft`, `redirect`, `reference`, `archived`. `date` = дата последнего содержательного изменения (синхронизируется с датами решений в тексте).
- Wikilinks — без пути (`[[02-mechanics]]`, не `[[gdd/02-mechanics]]`).
- Все новые TBD-хвосты регистрируются в реестре `docs/QUESTIONS.md` (§ «Реестр TBD»); в текстах документов TBD допускается только со ссылкой на пункт реестра (T1–T10).
- Проверка связности перед пушем: `python3 scripts/check_docs_links.py` (битые wikilinks, кириллица в именах, неизвестные статусы; exit ≠ 0 — править).
- Архивные логи (`STRUCTURE_AUDIT`, `CONFLICTS_REPORT`, `UNIFICATION_CHANGES`, `NORMALIZATION_REPORT`; RESTRUCTURING_LOG удалён в Фазе 0) освобождены от frontmatter и wikilink-графа; не редактируются; архивация — реестровый акт (запись в `DECISIONS.md` + `docs/CHANGELOG` с датой), файл не изменяется. Легаси-пути `gdd/…` в них — исторические цитаты.
- Банковская зона доков — одна: реестр `docs/BANK.md` + полные файлы `docs/bank/` (каждая позиция с меткой аннулирования и основаниями); зона исключена из `check_docs_links.py` и grep-гейтов; выемка из банка — только новым предложением против мандата, не «синхронизацией».

## Agent skills

### Issue tracker

**Реестр тикетов — `docs/mvp/TICKETS.md`** (append-only, D-139); внешние трекеры (GitHub Issues `DmitriyRudenskiy/sigil-of-the-unwilling`) — **зеркало, не источник истины**; при появлении `gh` CLI/токена — зеркалирование **в одну сторону** (репо → хост). Операции через `gh` CLI.

### Triage labels

Дефолтная пятиролевая лексика (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
