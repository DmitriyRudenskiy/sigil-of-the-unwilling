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
| Godot-бинарь | `/home/user/.local/bin/godot` |
| Тесты | `game/run_tests.sh` (GdUnit4, headless) |
| OpenSpec | `openspec/changes/<name>/`, CLI: `/usr/bin/openspec` |

## Режим работы

- Агент **read-write** в этом проекте: пишет код, данные, тесты, документацию.
- Коммиты делаются на **feature-ветках** (ветка от `main`), не на `main` напрямую.
- Тесты — единственный обязательный способ верификации. UI/звук/playtest
  не верифицируются headless → такие задачи помечаются как отложенные (deferred).

## Верификация

| Метод | Назначение |
| --- | --- |
| `godot --headless --path game --import` | Обновить кэш глобальных классов (после правки `class_name`) |
| `game/run_tests.sh` | Полный GdUnit4-свит (headless) |
| `godot ... GdUnitCmdTool.gd -a res://tests/<файл>.gd` | Запуск одного тест-файла |

Код GdUnit4: `0` = pass, `101` = только orphan-предупреждения (гигиена, не
падение), `100` и прочие = реальные падения.

## Данные событий (crisis/event system)

- Каталог: `game/data/events/` — `event_*.json` (common), `crisis_*.json`
  (кризисы), `rare_*.json` (редкие), `events_database.json` (служебный, не
  считается в счётчик шаблонов).
- Логика: `game/scripts/systems/crisis_event_system.gd`.
- Тесты структуры: `game/tests/unit/systems/test_crisis_events.gd`.
- Эффекты выборов используют только WIRED_EFFECT_KEYS
  (resource_change, morale_change, population_change, unlock_building,
  permanent_modifier, unlock_law).
- `unlock_building` → валидный id из `game/assets/data/buildings.json`;
  `unlock_law` → валидный id из `LawManager.gd`.

## Git-конвенции

- Работать на feature-ветках; `main` не трогать напрямую.
- Сообщения коммитов — конкретные, по делу.
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

GitHub — issues в `DmitriyRudenskiy/sigil-of-the-unwilling` GitHub Issues, операции через `gh` CLI.

### Triage labels

Дефолтная пятиролевая лексика (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
