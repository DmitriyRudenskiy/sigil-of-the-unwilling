# Design: fix-audit-findings-2026-08-31

## Context

Findings из `docs/misc/audit-docs-tests-2026-08-31.md` (change
`audit-docs-and-tests`). Все правки — в текстах документации и в одном
тестовом файле; исходники игры не трогаются. Факты, на которые опираются
правки:

- `game/project.godot`: 10 autoloads (SoundManager, Settings, GameEventBus,
  Spellbook, TemplateBootstrap, SocketController, Units, Artifacts, Spells,
  Resources).
- `game/tests/run_tests.gd`: флаги `--filter`/`--tag`/`--list`;
  `SKIP_FILES = {debug_load.gd, test_audio_world_entry.gd, test_city_arena_view.gd}`;
  итог: `=== Total: N passed, M failed (of K files) ===` + `ALL TESTS PASSED`.
- `game/tests/test_base.gd`: `assert_eq/true/false/not_null/null/not_empty/gt/lt/approx`,
  хуки `before_each` (вызывается раннером, если определён) и `after_each`,
  `tag(...)`.
- `game/tools/spell_validation/validate_spells.gd` — единственный валидатор
  (`--strict --json`); `tools/card_validation/` удалён в `86ab26f`.
- `game/scripts/core/GameLogger.gd`: статические `info/warn/error/trace/
  battle/world/inventory/ui/hero`; вывод через `print_rich`/`push_*` (не
  перехватываем из теста); форматирование — `static func _tag(tag)` с
  `TAG_WIDTH = 14` + ANSI-цветными кодами.
- Godot 4.7.2: флага `--autoquit` нет; есть `--quit-after <int>`.
- Ветка: 418 unstaged ` D` + untracked WIP — не трогать, в коммит не включать.

## Goals / Non-Goals

**Goals:**
- Устранить 14 детерминированных findings (F-1…F-7, F-13…F-18, F-20, F-22)
  без изменения поведения игры.
- После правок: повторный ссылочный скан по затронутым файлам = 0 мёртвых
  ссылок (кроме F-3, отложенной в WIP-коммит).

**Non-Goals:**
- F-3 (инструменты, удалённые в WIP) — правки `binomials.md:12,15,40`,
  `ADDING_TERRAINS:13,24`, `ASSET_PIPELINE:96`, `README:20`, `TASK:9`
  выполняются вместе с коммитом WIP, иначе доки опираться на незакоммиченное
  состояние.
- F-8 (переписывание overview ASSET_PIPELINE), F-9/F-10 (новые документы),
  F-11 (конвенция путей), F-12 (roadmap), F-19 (legacy-тесты), F-21
  (новые тесты) — отдельные follow-up change'ы.
- Любые изменения `game/scripts/**` (кроме `game/tests/test_logger.gd`).

## Decisions

**D1. Замена `--autoquit` → `--quit-after 120` (F-15).**
Во всех 7 местах (AGENT.md :213, :245, :246, :276, :280; TESTING.md :41, :42).
Пояснения вида «(нужен --autoquit, иначе зависнет)» переписать под
`--quit-after 120` + существующий обёрточный паттерн `run_godot` (§8.1
AGENT.md уже его описывает — ссылка остаётся). Альтернатива «оставить как
есть» отклонена: флаг не существует, команды не работают.

**D2. Шаблон теста в AGENT.md §9 (F-13).**
Новый шаблон на `test_base.gd`:

```gdscript
extends "res://tests/test_base.gd"

const _X = preload("res://scripts/...")

func before_each() -> void:
    # создание зависимостей (опционально)

func test_имя_кеbab() -> void:
    tag("unit")
    assert_eq(1 + 1, 2, "пример")
```

Плюс правка текста: «в проекте нет assert-хелпера» → «база `tests/test_base.gd`
(10 assert_*)», «раннер считает каждый файл за 1 единицу» → «раннер считает
ассерты: `_passed/_failed` из test_base, итог `Total: N passed, M failed (of K files)`».
Советы про память (`free()`) и про SceneTree (`is_inside_tree()`) сохранить —
они актуальны. Альтернатива (не трогать) отклонена: P0 — агенты создают
legacy-тесты против реального стиля (61/75 файлов на test_base).

**D3. Autoload-список AGENT.md §10 (F-14).**
Заместить на 10 строк из `project.godot` с текущими именами скриптов
(`Spellbook`, `TemplateBootstrap`); порядок как в project.godot.

**D4. Skip-список AGENT.md §9 (F-18).**
Первое предложение §9 перечисляет автономные раннеры — синхронизировать с
фактическим `SKIP_FILES` из `run_tests.gd` (7 записей: `test_base.gd`,
`run_tests.gd`, `test_runtime_integration.gd`, `test_audio_world_entry.gd`,
`test_city_arena_view.gd`, `test_validation_runner.gd`, `debug_load.gd`):
в текущем списке AGENT.md нет `test_audio_world_entry.gd` и
`test_city_arena_view.gd`.

**D5. TESTING.md (F-17, F-20, F-22).**
- «Автономные SceneTree-раннеры» — дописать 2 недостающие команды:
  `test_audio_world_entry.gd` (audio smoke: world-entry SFX) и
  `test_validation_runner.gd` (валидация спеллов/карт).
- Новая секция «Отбор тестов»: `--filter <стр>`, `--tag <имя>` (повторяется),
  `--list` — с примерами.
- «CI-скрипты» — убрать дубль `run_all_ci_checks.sh`; оставить `--fast`/
  `--tests`-варианты по фактическому usage скрипта.
- Ожидаемый вывод smoke: `[World] Scene ready.` → `[World] Scene ready, seed=<N>`
  (факт: `WorldController.gd:84`, `GameLogger.world("Scene ready, seed=%d")`).

**D6. Перезапись ссылок (F-2, F-4…F-7).**
- F-2: 11 ссылок в 4 файлах `docs/concepts/`
  (`CONCEPT_CHARACTER_SYSTEM.md` ×4, `CONCEPT_SOCIAL_RACES.md` ×1,
  `CONCEPT_BUILDING_SYNERGY.md` ×2, `TASK_SOCIAL_AND_BUILDINGS.md` ×4):
  `docs/hero_system.md` → `docs/systems/hero_system.md`,
  `docs/inventory_system.md` → `docs/systems/inventory_system.md`,
  `docs/CONCEPT_SOCIAL_RACES.md` / `docs/CONCEPT_BUILDING_SYNERGY.md` /
  `docs/TASK_SOCIAL_AND_BUILDINGS.md` → `docs/concepts/…`. Каждую целевую
  ссылку проверить на существование.
- F-4: `binomials.md:27,28` — `res://tilesets/processed/{biome}/` →
  `res://assets/tiles/` (фактическое расположение тайлсетов; `res://tilesets/`
  не существует ни в HEAD, ни в WIP). Строки :12/:15/:40 (инструменты) —
  не трогать (F-3).
- F-5: `spells_system.md:240` — `res://scripts/data/spells.json` →
  `res://assets/data/spells.json`.
- F-6: `docs/concepts/TASK_BUILDING_SCORING_GODOT47.md:39,284` —
  `game/scripts/data/UniqueBuilding.gd` → `game/scripts/world/UniqueBuilding.gd`.
- F-7: `docs/README.md:3` — «все документы лежат плоско» → документы
  разложены по областям (подпапки), таблица — ниже по файлу.

**D7. test_logger.gd (F-16) — переписать, не удалять.**
`GameLogger` — чистые статические функции без sink'а: перехват вывода из
теста невозможен, но есть ассертируемая логика форматирования. Новый тест
на `test_base.gd`:
- `GameLogger._tag("Battle")` содержит `[Battle` и занимает `TAG_WIDTH` (14)
  позиций до `]`;
- 9 публичных методов вызываются без ошибок (smoke-цикл, guard на
  `OS.is_debug_build()` для `trace` не нужен — вызов безопасен в любом билде);
- `tag("logger")` + итог через `get_results()`.
Альтернатива «удалить файл» отклонена: smoke по API-поверхности защищает от
silent rename методов.

**D8. Коммит.**
Один коммит: AGENT.md, docs/howto/TESTING.md, docs/concepts/*.md (6),
docs/systems/spells_system.md, docs/systems/TASK_BUILDING_SCORING_GODOT47.md,
docs/misc/binomials.md, docs/README.md, game/tests/test_logger.gd +
артефакты change. Только явные `git add <path>`; WIP (418 ` D`, untracked)
не задевать.

## Risks / Trade-offs

- **R1.** `binomials.md:27,28` правим до коммита WIP: если WIP-решение по
  пайплайну биномиев окажется «удалить механику», строки переписывать
  повторно. Митигция: правка минимальная (2 строки пути), фактическая на
  сегодня.
- **R2.** `_tag` — «приватный» по конвенции (не `_`-конвенция в GDScript,
  префикс `_tag` — соглашения проекта). Тест на него допустим как проверка
  формат-контракта; при рефакторинге GameLogger тест покажет разрыв.
- **R3.** Потоки `print_rich`/`push_warning` в headless не проверяются —
  smoke-цикл покрывает только отсутствие ошибок вызова (регрессия rename/
  сигнатур), не цветовой вывод. Принято: формат ANSI-кодов ассертируется
  через `_tag` косвенно.
- **R4.** Правки AGENT.md влияют на поведение всех будущих агентов —
  поэтому §9/§10 сверяются с кодом построчно на этапе реализации (проверка
  в tasks 5.x).
