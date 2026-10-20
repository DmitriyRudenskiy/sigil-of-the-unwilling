# Tasks — docs-reference-vault-import

## 1. Каркас зоны

- [x] 1.1 Создать `docs/reference/` с шестью зонами: `against-the-storm/`, `terrascape/`,
      `homm3/`, `allods/`, `dnd/`, `poe2/` — **готово:** плюс седьмая, `sigil-ats-prototype/`
      (карантин, см. 2.6). Итого 29 файлов, ~370 КБ.
- [x] 1.2 Убедиться, что зона проходит `python3 scripts/check_docs_links.py` без правок в
      самом скрипте — **готово:** `OK: docs/ links consistent (88 notes checked)`, exit 0
      (было 59 заметок). Скрипт не изменялся.

## 2. Импорт против канона (задача 1)

- [x] 2.1 `atts/index.md` → `docs/reference/against-the-storm/ats-index.md` — **готово.**
- [x] 2.2 `atts/ats-canon.md` → `against-the-storm/ats-canon.md` — **готово.**
- [x] 2.3 `atts/species.md` → `against-the-storm/ats-species.md` — **готово.**
- [x] 2.4 `atts/specializations.md` → `against-the-storm/ats-specializations.md` — **готово.**
- [x] 2.5 `atts/goods.md` → `against-the-storm/ats-goods.md` — **готово.**
- [x] 2.6 `atts/notes.md` → `against-the-storm/ats-notes.md` — **готово.**
- [x] 2.7 `textures/terrain-tiles.md` → `homm3/homm3-terrain-tiles.md` — **готово.**
      В шапке указан адресат: [[13-art-bible]] §9.1 и «Префикс-промпт генерации новых ассетов»;
      это промпты, не ассеты.
- [x] 2.8 `allods/races.md` → `allods/allods-races.md` — **готово.** В шапке: Приложение А и
      [[02e3-races]] этот файл не подменяет.
- [x] 2.9 `dnd/races.md` → `dnd/dnd-races.md` — **готово.**
- [x] 2.10 `dnd/classes.md` → `dnd/dnd-classes.md` — **готово.**
- [x] 2.11 `terrascape/merged-buildings.md` → `terrascape/terrascape-merged-buildings.md` —
      **готово.** В шапке: счёт «20 слияний источника против 02g §4.1» → [[CONFLICTS]] К-10.
- [x] 2.12 `PoE2-Character-Creation/index.md` → `poe2/poe2-index.md` — **готово.**
- [x] 2.13–2.20 `PoE2-Character-Creation/01-Classes/…/07-Multiclassing/…` →
      `poe2/poe2-{classes,creation-flow,abilities,races,skills,specializations,destinies,multiclassing}.md` —
      **готово** (8 файлов).
      Замечание к задаче: «PoE2» в вольте = **Pillars of Eternity II: Deadfire**, не Path of
      Exile (проверено по телам: «Deadfire», «The Living Lands», «Edér», «11 classes»).
      Имя префикса `poe2-` сохранено как в тикете.
- [x] 2.21 Каждый импортированный файл — frontmatter + provenance-шапка (источник, дата,
      статус «не канон», ссылка на [[CONFLICTS]]) — **готово** у всех 27.
- [x] 2.22 Тела файлов — дословные копии источника — **готово:** выборочная побайтовая
      сверка 3 файлов (`atts/goods.md`, `PoE2 …/Skills System.md`, `kb/mechanics.md`):
      различаются только строки со ссылками (переписаны по 2.23), остальное идентично.
- [x] 2.23 Относительные ссылки источника (`../kb/goods.md`, `README.md`, `./01-Classes/…`)
      переписаны на реальные имена в репо; висячих путей вольты не осталось — **готово**
      (grep по `](kb/`, `](atts/`, `](textures/`, `](PoE2…/` — пусто; `](dnd/…)` остались
      только как корректные пути внутри зоны).

## 3. Карантин прототипа (задача 2)

- [x] 3.1 `kb/` → `docs/reference/sigil-ats-prototype/` (7 файлов: `sigil-ats-{index,notes,
      mechanics,buildings,goods,merged-buildings,implementation}.md`) — **готово.**
- [x] 3.2 В каждой шапке — «браузерный прототип на JavaScript, **не** сборка Godot 4.7» +
      запрет переноса формул в `game/scripts/` и [[07-balance]] — **готово.**
- [x] 3.3 Проверено, что в `game/` нет цитат из этих формул — **готово:** `grep -rniE
      'morale|prestige|anger' game --include=*.js` → 0 файлов; `.js` в `game/` нет вовсе.
      Единственный след — совпадающие названия сезонов (В-5 в [[CONFLICTS]]).
- [x] 3.4 `README.md` зоны — **готово** (раздел «Карантин»).

## 4. Реестр расхождений (задача 3)

- [x] 4.1–4.7 `docs/reference/CONFLICTS.md` — таблица «утверждение | канон | основание |
      вердикт»: **К-1…К-19** (вольта ↔ канон) + **В-1…В-5** (внутренние расхождения репо) +
      **И-1…И-5** (вопросы источника) + раздел «что можно брать как есть» — **готово.**
      Основания — канон-доки с номерами строк; коды и данные не правились.
      Уточнение к 4.2: «уровни города 1–11» уже зарегистрированы как **Q-M46** — В-1/В-2
      отсылают к нему (новое основание: 18 `min_city_level` в `buildings.json`), а не
      дублируют вопрос.
      Новое вскрытое расхождение (В-3/В-4): 02g §5.1 несёт полную таблицу 7 AtS-видов
      числами из `ats-species.md`, а `settlement_species.gd` — её реализация.

## 5. Вопросы владельцу (задача 4)

- [x] 5.1 → **Q-M48** — **готово,** переформулирован по ходу сверки: очередь строительства и
      время постройки **уже реализованы** (`campaign_building_construction_service.gd`,
      `campaign_construction_processor.gd`; change `campaign-city-construction-queue` закрыт),
      а в канон-доках — 0 упоминаний. Вопрос = «документировать ли реализованное» (drift
      доков за кодом), а не «вводить ли». То же основание — В-6 в [[CONFLICTS]].
- [x] 5.2 → **Q-M49** «Классы населения и ручное назначение рабочих» — **готово.**
      Уточнение к задаче: мультикласс и point-buy в каноне **описаны**
      ([[02d-classes-skills]]:150, [[02d-antagonism]]:31, :85), а назначение рабочих уже
      реализовано автоматическим (`world/worker_assignment.gd::assign_all`), поэтому вопрос —
      «сливать ли классы населения с сословиями» ([[BANK]] 10.2), а не «вводить ли назначение».
- [x] 5.3 → **Q-M50** «Внутриигровая энциклопедия (Кодекс)» — **готово.**
- [x] 5.4 → **Q-M51** «Естественная убыль населения» — **готово.** Уточнение к задаче:
      point-buy есть; вопрос — про убыль: 02g §5.2 знает приход и выселение, но не потери;
      болезни упомянуты один раз ([[02f-a-core]]:263).
- [x] 5.5 Номера присвоены реестром [[QUESTIONS]] (Q-M48…Q-M51, продолжение Q-M47);
      в коммитах номеров нет.

## 6. Индекс и журнал

- [x] 6.1 [[00-overview]] — одна строка в блоке «Справочники и банк»: зона
      `docs/reference/` + [[CONFLICTS]]. Больше канон-доков не трогать — **готово.**
- [x] 6.2 [[CHANGELOG]] — запись 2026-10-16 — **готово.**

## 7. Проверка

- [x] 7.1 `python3 scripts/check_docs_links.py` → exit 0 — **готово** (88 заметок).
- [x] 7.2 Конфликт-маркеров нет (`git grep -nE '^(<{7}|={7}|>{7})' -- docs/` — пусто);
      файлов с кириллицей в именах в зоне нет — **готово.**
- [x] 7.3 `game/run_tests.sh` **не запускался:** код и данные не менялись (docs-only).
      Тестовый леджер: +0 / −0 / quarantine 0, нетто 0, было 0 → стало 0.
- [x] 7.4 Выборочная сверка provenance — **готово,** см. 2.22.
