# Proposal: fix-audit-findings-2026-08-31

## Why

Аудит `audit-docs-and-tests` (отчёт `docs/misc/audit-docs-tests-2026-08-31.md`)
нашёл 22 дефекта. 14 из них — детерминированные малые правки (устаревшие
команды/пути/списки в AGENT.md и TESTING.md, мёртвые ссылки в docs,
always-pass-тест), которые можно исправить без новых решений и без нового
контента. Оставшиеся 8 (новые документы, миграция legacy-тестов, решения по
конвенциям) — отдельные change.

## What Changes

**AGENT.md** (contract для агентов — приоритет):
- F-1 (P0): §8 — команда валидации `tools/card_validation/validate_card_spells.gd`
  (не существует) → `tools/spell_validation/validate_spells.gd --strict --json`
- F-13 (P0): §9 — шаблон тестового файла: legacy `failed += / printerr` →
  `extends "res://tests/test_base.gd"` + assert_*; исправить утверждение
  «в проекте нет assert-хелпера» и «раннер считает каждый файл за 1 единицу»
  (считает assert'ы через `_passed/_failed`)
- F-14 (P1): §10 — autoload-список синхронизировать с `project.godot`
  (`CardSpells`/`CardTemplateBootstrap` → `Spellbook`/`TemplateBootstrap`)
- F-18 (P1): §9 — список «пропускаемых» раннеров синхронизировать со
  `SKIP_FILES` в `run_tests.gd` (7 записей; в текущем списке AGENT.md нет
  `test_audio_world_entry.gd` и `test_city_arena_view.gd`)

**TESTING.md**:
- F-15 (P1): smoke-команды `--autoquit` (несуществующий флаг Godot 4.7.2) →
  `--quit-after 120`; места: AGENT.md ×5 (:213, :245–246, :276, :280) +
  TESTING.md ×2 (:41–42)
- F-17 (P1): секция «Автономные SceneTree-раннеры» — дописать 2 недостающих
  (`test_audio_world_entry.gd`, `test_validation_runner.gd`); текущие
  (runtime_integration, city_arena_view) сохранить
- F-20 (P2): новая секция «Отбор тестов»: флаги `--filter`, `--tag`, `--list`
- F-22 (P2): убрать дублирующиеся строки в «CI-скрипты»; ожидаемая строка
  мира → фактический формат лога

**Документы — мёртвые/устаревшие ссылки**:
- F-2 (P1): 11 ссылок на старое плоское `docs/*.md` в 4 файлах
  `docs/concepts/` (CONCEPT_CHARACTER_SYSTEM ×4, CONCEPT_SOCIAL_RACES ×1,
  CONCEPT_BUILDING_SYNERGY ×2, TASK_SOCIAL_AND_BUILDINGS ×4)
  → `docs/systems/…` / `docs/concepts/…`
- F-4 (P1): `binomials.md:27,28` — `res://tilesets/processed/{biome}/…` →
  фактическое расположение `res://assets/tiles/…`
- F-5 (P1): `spells_system.md:240` — `res://scripts/data/spells.json` →
  `res://assets/data/spells.json`
- F-6 (P1): `docs/concepts/TASK_BUILDING_SCORING_GODOT47.md:39,284` —
  `game/scripts/data/UniqueBuilding.gd` → `game/scripts/world/UniqueBuilding.gd`
- F-7 (P1): `docs/README.md:3` — интро «все документы лежат плоско» →
  области = подпапки

**Тест**:
- F-16 (P1): `game/tests/test_logger.gd` — always-pass без ассертов →
  переписать на `test_base.gd`: assert'ы по формату `_tag` + smoke по 9
  публичным методам (решение D7 в design.md)

**Не входит в этот change** (follow-up'ы): F-3 (зависит от WIP-удаления
инструментов — в коммит WIP), F-8 (переписывание overview ASSET_PIPELINE),
F-9/F-10 (новые документы: socket, UI, audio), F-11 (конвенция путей),
F-12 (слияние roadmap), F-19 (миграция 13 legacy-тестов), F-21 (новые тесты).

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

(нет — change восстанавливает соответствие существующим требованиям
спеков `documentation`/`testing` без изменения самих требований;
`skip_specs: true` в `.openspec.yaml`)

## Impact

- `AGENT.md` — 6 зон: §8 (валидация, `--autoquit` ×5), §8.2 (цифра
  юнит-тестов в рабочем цикле), §9 ×2 (skip-список, шаблон + assert'ы),
  §10 (autoloads + `*`-партиция)
- `docs/howto/TESTING.md` — 4 правки
- `docs/concepts/*.md` (5 файлов), `docs/systems/spells_system.md`,
  `docs/misc/binomials.md`, `docs/README.md` — ссылки/интро
- `game/tests/test_logger.gd` — переписать на test_base.gd
- Не трогается: `game/scripts/` (кроме теста), сцены, данные, WIP-состояние
  (418 ` D` + untracked)
- Верификация: повторный ссылочный скан (0 мёртвых в затронутых файлах),
  grep-контроль старых строк, headless-прогон тестов (`run_tests.gd`),
  `openspec validate`
