# Аудит документации и тестов — 2026-08-31

> Однократный аудит по OpenSpec-change `audit-docs-and-tests`. Отчёт содержит
> только findings + рекомендации; **исправление — отдельный follow-up change**.
> База аудита — рабочее дерево на момент снимка (не HEAD).

## Резюме

- **Документация**: 41 файл, 327 путей-ссылок. 28 реально мёртвых ссылок →
  сгруппированы в 13 findings. Главное: устаревшие команды/названия в
  **AGENT.md** (contract для агентов — P0/P1), остатки переезда docs в
  подпапки, ссылки на инструменты, удалённые в WIP. Контент 5 ключевых
  систем (turn/battle/city/magic/world) при спот-чеке **актуален**.
- **Тесты**: 86 `.gd` на диске, 75 файлов (783 метода) подбирает
  `run_tests.gd`, 4 standalone-раннера вне CI. 61 файл на `test_base.gd`
  (assert_*), 13 — legacy-стиль, 1 (`test_logger.gd`) — always-pass.
  AGENT.md §9/§10 описывает тесты и autoloads **до** вступления `test_base.gd`
  и card→spell rename — агенты, читающие AGENT.md, получат неверный шаблон (P0).
- **Покрытие тестами**: ядро (turn pipeline, battle, city, magic, save)
  покрыто хорошо; не покрыты UI-слой (19 файлов), socket/сеть, HeroInventory/
  HeroMagic напрямую.
- Приоритеты: **P0 × 2, P1 × 14, P2 × 6, наблюдения × 3** (всего 22 findings).

---

## 1. Документация

### 1.1 Ссылки и соответствие коду

Автоматический скан: 327 путей-ссылок в 41 файле `docs/**/*.md`, `README.md`,
`AGENT.md`. Разрешение: относительный от файла → корень репо → корень `game/`
→ `res://` под `game/`. 30 неразрешённых, из них 2 — намеренные примеры
(`res://assets/units/my_unit*.png` в `ADDING_UNITS.md` — «положить свой файл»),
28 — реальные. Все 28 подтверждены вручную.

Категории:

| Категория | Линий | Файлов |
|-----------|-------|--------|
| Старые doc-перекрёстки до реорганизации docs | 11 | 6 |
| Инструменты, удалённые в WIP (unstaged D) | 8 | 5 |
| Старые `res://`-пути (tilesets, data) | 3 | 2 |
| Неправильный подкаталог скрипта | 2 | 1 |
| Несуществующий инструмент в команде AGENT.md | 1 | 1 (счёт по находкам) |

Спот-чек 5 ключевых систем (по 3–5 фактов каждая, task 3.3):
**семантически все актуальны**, расхождений «док vs код» не найдено:

- Turn pipeline: 6/6 классов существуют (`TurnContext`, `TurnScheduler`,
  `TurnPhaseProcessor`, `GameSession`, `Platform`, `ServiceContainer`).
- Battle: сигналы `BattleTurnExecutor` (`pulse_unit`, `phase_changed`, …)
  совпадают с `battle_system.md` §«Порядок ходов».
- City: `city_system.md` отражает `scripts/city/` (CityTurnProcessor,
  AdjacencySystem, §82).
- Magic: «20 заклинаний по 4 школам» совпадает с комментарием
  `SpellRegistry.gd`; 505 записей в `spells.json` согласованы во всех 3
  документах.
- World: `WorldBootstrap.run`, `WorldEventRouter._on_end_turn`, порядок
  «после City.process_turn» — совпадают с кодом (комментарий WorldEventRouter:186).

### 1.2 Индекс (`docs/README.md`)

- 39 ссылок в индексе, **0 dangling** (утверждение «битых не найдено» верно
  для ссылок).
- 1 файл вне индекса: `CONSOLE_ALLOWLIST.md` (untracked WIP — наблюдение N-3).
- Интродукция устарела (D-7).

### 1.3 Покрытие системами

| Система (code) | Документ(ы) | Статус |
|---|---|---|
| core (turn pipeline, save) | `architecture/CORE_TURN_PIPELINE.md`, `systems/save_load.md` | ✅ полное |
| systems/battle | `systems/battle_system.md`, `battle_spells.md` | ✅ полное |
| data/magic | `systems/magic_runtime.md`, `spells_system.md` | ✅ полное |
| city + world/City* | `systems/city_system.md` | ✅ полное |
| world (map, bootstrap) | `systems/world_adventure.md` | ✅ полное |
| economy | `economy/*.md` (3) | ✅ полное |
| demographics | `concepts/CONCEPT_POPULATION_RUNTIME.md` + упоминание в `economy_runtime.md` | ✅ достаточное |
| entities (hero) | `systems/hero_system.md`, `inventory_system.md`, `inventory_items.md` | ✅ достаточное |
| **ui (19 файлов)** | — | ❌ не документировано (самодостаточная запись в «Пробелы» индекса — подтверждена) |
| **audio** | секция в `overview/ASSET_PIPELINE.md` + `openspec/specs/audio` | ⚠️ нет своего документа |
| **socket/сеть** (SocketServer, SocketController, `tools/scenarios/`) | — | ❌ не документировано нигде |
| data/TerrainCostTable, StatusEffects, UnitSprites | — | ⚠️ «Пробелы» индекса — подтверждены |

Активные changes (16 шт., напр. `fog-of-war`, `endgame-conditions`) — фичи в
работе, их документы появятся вместе с изменениями; в findings не включаются.

### 1.4 Противоречия и дубли

- Счётчики заклинаний (505 / 20) согласованы во всех документах —
  противоречий не найдено.
- Дублирование: `PLAN_MASTER.md` (фазы) vs `TASK.md` (73 пункта) — два
  roadmap-документа (D-12).
- Четыре документа про боевую магию (`battle_spells`, `battle_system`,
  `magic_runtime`, `spells_system`) — разделением ролей не конфликтуют
  (данные / слои / исполнение / обзор).

---

## 2. Тесты

### 2.1 Исполняемость и «осиротевшие»

`run_tests.gd --list` (headless, Godot 4.7.2): подобрано **75 файлов / 783
метода** из 86 `.gd` в `game/tests/`. Не подобрано 11:

| Файл | Статус |
|---|---|
| `run_tests.gd`, `test_base.gd`, `debug_load.gd`, `fakes/*.gd` (4) | не тесты — ожидаемо |
| `test_runtime_integration.gd` | standalone, задокументирован в TESTING.md |
| `test_city_arena_view.gd` | standalone, задокументирован в TESTING.md |
| `test_audio_world_entry.gd` | standalone, **не в TESTING.md** (T-5) |
| `test_validation_runner.gd` | standalone, не в TESTING.md (упомянут в `spells_system.md`) (T-5) |

CI (`run_all_ci_checks.sh` → шаг `unit_tests`) запускает только
`run_tests.gd` — **ни один standalone-раннер в CI не выполняется** (T-5).
Механизм `_skips_for_missing_dev_tools` в текущем проекте не срабатывает
(`tools/` существует) — [SKIP]-строк в логе нет.

### 2.2 Матрица «система → тесты»

| Система | Файлов | Примеры |
|---|---|---|
| battle | 16 | `test_battle_state` (542 стр.), `test_battle_integration`, `test_status_effects` |
| city | 12 | `test_city_*` (10), `test_borough_rules`, `test_market_walls_raids` |
| magic | 7 | `test_spell_system` (375), `test_spells_json` (340), `test_scroll` |
| world/map | 8 | `test_map_model`, `test_movement_costs`, `test_camera_clamp`, `test_algorithm_optimizations` |
| economy/resources | 11 | `test_economic_processor`, `test_resource_context`, `test_production_chain`, `test_trait_registry` |
| hero/character/inventory | 4 | `test_characters`, `test_hero_serialize`, `test_artifact_system`, `test_hero_movement` |
| save/persistence | 5 | `test_save_v3` (405), `test_save_roundtrip`, `unit/test_world_persistence` |
| core/autoload | 5 | `test_turn_scheduler`, `test_event_bus`, `test_hex_utils`, `test_logger`, `test_node_lifecycle` |
| units | 3 | `test_unit_registry`, `test_unit_abilities`, `test_pop_unit` |
| audio | 1 | `test_audio` |
| mixed/регресс | 5 | `test_applied_fixes`, `test_refactoring_*`, `test_error_handling` |

**Пробелы покрытия** (T-9): UI-слой (19 файлов, 0 тестов), socket/сеть
(SocketServer/SocketController + `tools/scenarios/`, 0 тестов),
HeroInventory/HeroMagic (только косвенно), WorldBootstrap/WorldBattleCoordinator
(нет dedicated), UniqueBuilding/scoring (0 — фича в работе).

### 2.3 Качество (ассерты, flaky)

- 61/75 файлов — современный стиль (`extends test_base.gd`, assert_*).
- 13 файлов — legacy-стиль (`extends SceneTree`, `failed += / printerr`):
  `test_battle_ai`, `test_battle_cursor`, `test_battle_integration`,
  `test_battle_retreat_smoke`, `test_battle_state`, `test_hero_serialize`,
  `test_hex_utils`, `test_map_generator_seed`, `test_map_model`,
  `test_spell_registry`, `test_status_effects`, `test_unit_abilities`,
  `test_unit_registry` (T-7).
- 1 файл без единой проверки: `test_logger.gd` (11 строк, `_passed = 1`
  безоговорочно) (T-4).
- Flaky-рисков (sleep > 2 с в unit-тестах) не найдено; async-ожидания
  вынесены в 4 standalone-раннера.

### 2.4 Согласованность с CI

- CI `unit_tests` = `run_tests.gd` без фильтров → закрывает все 75 файлов
  (кроме 4 standalone — T-5).
- `compile_all` покрывает компиляцию тестов (шаг 1 CI).
- Флаги раннера `--filter`, `--tag`, `--list` не задокументированы (T-8).

---

## 3. Findings

Приоритеты: **P0** — ломает работу агента/CI или даёт ложную уверенность;
**P1** — неверная информация в доках/непокрытая зона; **P2** — несогласованность,
стиль, дубли.

| ID | Приоритет | Область | Finding | Рекомендация |
|----|-----------|---------|---------|--------------|
| F-1 | P0 | AGENT.md | :242 — команда `tools/card_validation/validate_card_spells.gd` не существует (удалён в 86ab26f, card→spell rename) | Заменить на `tools/spell_validation/validate_spells.gd --strict --json` (как в TESTING.md:34 и CI) |
| F-2 | P1 | docs | 11 ссылок на старое плоское расположение docs (`docs/hero_system.md` и т.п.) в 6 файлах concepts/ | Переписать ссылки на `docs/systems/…` / `docs/concepts/…` |
| F-3 | P1 | docs | 8 ссылок на инструменты, удалённые в WIP: `make_grid.py` (README:20, TASK:9), `process_assets.py` (TOOLS:96), `binom_cutter.gd`/`biome_preview_tool.gd`/`res://assets/raw/binom/` (binomials:12,15,40), `tileset_builder.gd` (ADDING_TERRAINS:13,24) | Обновить в рамках WIP-чистки (инструменты в `tools/archived/` или удалены) |
| F-4 | P1 | binomials.md | :27,28 — `res://tilesets/processed/{biome}/…`: старый префикс + директории не существует | Привести к `res://assets/tiles/…` после решения судьбы пайплайна |
| F-5 | P1 | spells_system.md | :240 — в кодовом примере `res://scripts/data/spells.json` | `res://assets/data/spells.json` |
| F-6 | P1 | TASK_BUILDING_SCORING_GODOT47.md | :39,284 — `game/scripts/data/UniqueBuilding.gd` | `game/scripts/world/UniqueBuilding.gd` |
| F-7 | P1 | docs/README.md | :3 — «все документы лежат плоско (`docs/*.md`)» — ложно (7 подпапок) | Переписать интро: области = подпапки |
| F-8 | P1 | ASSET_PIPELINE.md | стр. 1–24 — генерический английский overview («Feature-based structure», «Gemma 4 Vision», «Graphify»), язык смешан с остальной докой | Переписать описание под проект (русс.) или выделить в отдельный research-документ |
| F-9 | P1 | покрытие | audio — только секция ASSET_PIPELINE + spec; socket/сеть (SocketServer, SocketController, scenarios) — без документа | Создавать документы в follow-up (socket — приоритетно) |
| F-10 | P1 | покрытие | UI-слой (19 файлов) без документации; TerrainCostTable/статусы/UnitSprites без доков (самопризнание индекса) | Закрыть «Пробелы» в follow-up по приоритету |
| F-11 | P2 | convention | 161 ссылка с базой `game/` vs 27 с базой корня; конвенция нигде не описана | Зафиксировать в docs/README.md один формат (рекомендуется `res://`-относительный) |
| F-12 | P2 | дубли | `PLAN_MASTER.md` и `TASK.md` — два roadmap; TASK.md содержит ссылку на удалённый `make_grid.py` | Слить/указать, кто source of truth |
| F-13 | P0 | AGENT.md §9 | Шаблон теста — legacy `failed += / printerr` + «в проекте нет assert-хелпера»: ложно, `test_base.gd` (10 assert_*) существует, 61/75 файлов на нём. «Раннер считает каждый файл за 1 единицу» — неверно (считает assert'ы) | Заменить шаблон на `extends "res://tests/test_base.gd"` + assert_* |
| F-14 | P1 | AGENT.md §10 | Autoload-список: `CardSpells`, `CardTemplateBootstrap` — старые имена (факт: `Spellbook`, `TemplateBootstrap` из project.godot) | Синхронизировать с project.godot (10 autoloads) |
| F-15 | P1 | TESTING.md | Smoke-команды: `--autoquit` — несуществующий флаг Godot 4.7.2 (есть `--quit-after N`) | Заменить на `--quit-after 120` (как в AGENT.md §8.1) |
| F-16 | P1 | test_logger.gd | Always-pass: `_passed = 1` без единого ассерта | Переписать: перехват вывода GameLogger и проверки уровня/формата — или удалить |
| F-17 | P1 | standalone | 4 раннера вне CI; TESTING.md упоминает только 2 из 4 (`test_audio_world_entry`, `test_validation_runner` — не упомянуты) | Догрузить список в TESTING.md; решить, включить ли `test_audio_world_entry` в CI (audio-pass) |
| F-18 | P1 | AGENT.md §9 | Список «пропускаемых» раннеров неточен: включены `debug_load.gd`/`run_tests.gd` (не в SKIP_FILES — просто не по шаблону `test_*`), пропущены `test_audio_world_entry.gd`/`test_city_arena_view.gd` (в SKIP_FILES) | Синхронизировать со `SKIP_FILES` в run_tests.gd |
| F-19 | P2 | стиль | 13 legacy-файлов (SceneTree + `failed +=`), не на test_base | Перенести на test_base (батч по системам) |
| F-20 | P2 | TESTING.md | Флаги раннера `--filter`/`--tag`/`--list` не задокументированы | Добавить секцию «Отбор тестов» |
| F-21 | P2 | покрытие | Не покрыто: UI (19 файлов), socket/сеть, HeroInventory/HeroMagic (напрямую), WorldBootstrap/WorldBattleCoordinator (dedicated) | Тестовые задачи в follow-up / соответствующие changes |
| F-22 | P2 | TESTING.md | Мелочи: дублирующиеся строки в «CI-скрипты»; «`[World] Scene ready.`» vs факт «`Scene ready, seed=%d`» | Почистить |

### Наблюдения (не findings)

- **N-1**: 418 unstaged-удалений (WIP) — намеренное состояние, не дефект.
- **N-2**: 31 untracked WIP-файл (включая `game/assets/tiles/`, `hex_autotiler.gd`,
  `tile_atlas.gd`) — вне скоупа аудита.
- **N-3**: `docs/CONSOLE_ALLOWLIST.md` (untracked WIP) не в индексе — при
  коммите потребуется запись (spec `documentation`).

---

## Приложение A. Методология

1. **Снимок** (task 1.1): 2026-08-31 22:52 +07, HEAD `e314826`
   (`chore(openspec): archive restructure-game-folders`), dirty: 418 ` D` +
   36 `??` (WIP, сохранён; ничего не трогалось).
2. **Реестр кода**: 10 autoloads, 137 `class_name`, 4 сцены, 141 скрипт,
   86 тестов, 31 инструмент (скрипт в `tmp/audit/`, не в репозитории).
3. **Скан ссылок**: 327 путей из 43 .md-файлов; разрешение по 4 базам
   (файл → корень репо → `game/` → `res://`); все 30 мёртвых — вручную.
4. **Спот-чек** (task 3.3): 5 систем × 3–5 фактов, сверка с кодом.
5. **Тесты**: `godot --headless --path game -s tests/run_tests.gd --list`
   (background + sleep 75 + kill, без GPU); diff vs диск; классификация
   стиля по `extends`/assert-паттернам; сверка TESTING.md/AGENT.md с
   `run_tests.gd`, `project.godot`, `godot --help`.
6. Все Godot-запуски read-only (только `--list`), паттерн AGENT.md §8.1.

## Приложение B. Сырые данные

- Логи и скрипты сканов — в `tmp/audit/` (git-игнорируются):
  `testlist.log` (783 метода), `refs2.tsv` (327 ссылок), `registry.json`.
- Полный список legacy-тестов — §2.3. Полный список мёртвых ссылок —
  `refs2.tsv` (статус `DEAD`).

## Приложение C. Отброшенные ложные срабатывания

> `res://`-строки в кавычках в этом отчёте (напр. `res://scripts/data/spells.json`,
> `res://assets/raw/binom/`) — цитаты мёртвых путей из findings, а не ссылки;
> намеренно не резолвятся.

- `docs/howto/ADDING_UNITS.md` — `res://assets/units/my_unit*.png` (2 шт.):
  намеренный пример «куда положить свой файл», не ссылка на существующий
  файл.
- Скан по именам: `Spells` (autoload) и `Spells` (class) — разные сущности,
  конфликта имён нет.
- «Дубль» city-тестов `test_city_model.gd` (36 методов) vs
  `unit/test_city_system.gd` (12 методов): пересечение имён тест-методов
  пустое — покрытие комплементарно (build/approval vs growth/workers).

## Приложение D. Снимок git (1.1)

```
2026-08-31 22:52 +07, HEAD e314826 (chore(openspec): archive restructure-game-folders)
unstaged: 418 D (WIP-удаления, намеренные), untracked: 36 ?? (WIP-файлы)
staged:   пусто
```
Аудит read-only: ни одно из 418 удалений и ни один untracked-файл не
тронуты; единственные изменения — сам отчёт и строка индекса `docs/README.md`.
