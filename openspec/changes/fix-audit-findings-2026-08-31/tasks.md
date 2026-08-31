# Tasks: fix-audit-findings-2026-08-31

Findings — из `docs/misc/audit-docs-tests-2026-08-31.md` (ID совпадают).
Решения — в design.md (D1–D8).

## 1. AGENT.md (P0 + P1)

- [x] 1.1 §8 (F-1): :242 `tools/card_validation/validate_card_spells.gd --strict --json` → `tools/spell_validation/validate_spells.gd --strict --json`; сверить с `docs/howto/TESTING.md` и CI
- [x] 1.2 §8 (F-15): заменить все `--autoquit` на `--quit-after 120` (:213, :245, :246, :276, :280); пояснения «иначе зависнет» привести к паттерну `run_godot` (§8.1)
- [x] 1.3 §9 (F-13): шаблон тестового файла → `extends "res://tests/test_base.gd"` + assert_* (по D2); убрать «в проекте нет assert-хелпера»; «каждый файл за 1 единицу» → «раннер считает ассерты (`Total: N passed, M failed (of K files)` + `ALL TESTS PASSED`)»
- [x] 1.4 §9 (F-18): список автономных раннеров синхронизировать с фактическим `SKIP_FILES` (7 записей): добавить `test_audio_world_entry.gd`, `test_city_arena_view.gd` (D4)
- [x] 1.5 §10 (F-14): autoload-список → 10 autoloads из `game/project.godot` с фактическими именами (`Spellbook`, `TemplateBootstrap`), порядок как в project.godot; исправить `*`-партицию (без `*` — только `SocketController`) (D3)
- [x] 1.6 §8.2 (цифра): «4759 passed, 0 failed из 75 файлов» → фактический baseline 4696 passed (проверено прогоном)

## 2. TESTING.md (P1 + P2)

- [x] 2.1 (F-15): smoke-команды :41–42 `--autoquit` → `--quit-after 120`
- [x] 2.2 (F-17): «Автономные SceneTree-раннеры» — дописать 2 недостающие команды: `test_audio_world_entry.gd` (audio smoke) и `test_validation_runner.gd` (валидация спеллов/карт); текущие (runtime_integration, city_arena_view) сохранить
- [x] 2.3 (F-20): новая секция «Отбор тестов»: `--filter <подстрока>`, `--tag <имя>` (повторяемый), `--list` + примеры
- [x] 2.4 (F-22): убрать дублирующиеся строки в «CI-скрипты»; ожидаемая строка smoke-запуска мира сверить с фактическим логом Godot (прогон `scenes/World.tscn --quit-after N`)

## 3. Документы — ссылки и интро (P1)

- [x] 3.1 (F-2): 11 ссылок на плоский `docs/*.md` в 4 файлах `docs/concepts/` (CONCEPT_CHARACTER_SYSTEM ×4, CONCEPT_SOCIAL_RACES ×1, CONCEPT_BUILDING_SYNERGY ×2, TASK_SOCIAL_AND_BUILDINGS ×4) → `docs/systems/…` / `docs/concepts/…`; каждую целевую ссылку проверить на существование
- [x] 3.2 (F-4): `docs/misc/binomials.md:27,28` — `res://tilesets/processed/{biome}/…` → `res://assets/tiles/…`; строки :12/:15/:40 (инструменты) не трогать (F-3 → WIP)
- [x] 3.3 (F-5): `docs/systems/spells_system.md:240` — `res://scripts/data/spells.json` → `res://assets/data/spells.json`
- [x] 3.4 (F-6): `docs/concepts/TASK_BUILDING_SCORING_GODOT47.md:39,284` — `game/scripts/data/UniqueBuilding.gd` → `game/scripts/world/UniqueBuilding.gd`
- [x] 3.5 (F-7): `docs/README.md:3` — интро «все документы лежат плоско» → «документы разложены по областям (подпапки), см. таблицы ниже»

## 4. Тест (P1)

- [x] 4.1 (F-16): `game/tests/test_logger.gd` переписать на `test_base.gd` по D7: assert'ы по `GameLogger._tag` (TAG_WIDTH=14, `[Tag` в строке, ANSI-коды цвета) + smoke-цикл по 9 публичным методам + `tag("logger")`

## 5. Верификация

- [x] 5.1 grep-контроль: `grep -rn "autoquit\|card_validation\|CardSpells\|CardTemplateBootstrap\|scripts/data/spells\|scripts/data/UniqueBuilding\|res://tilesets" AGENT.md docs/` → 0 совпадений в затронутых файлах (цитаты в openspec/changes/* не в счёт)
- [x] 5.2 повторный ссылочный скан (`tmp/audit/extract_refs2.py`): 0 мёртвых `res://`/doc-ссылок в файлах, затронутых этим change; `res://assets/raw/binom/` (F-3) — ожидаемо остаётся до WIP-коммита
- [x] 5.3 headless-прогон: `run_tests.gd --filter logger` → 0 failed; затем полный `run_tests.gd` → `ALL TESTS PASSED` (baseline 783 метода)
- [x] 5.4 `openspec validate fix-audit-findings-2026-08-31` → valid

## 6. Коммит (D8)

- [x] 6.1 явный `git add` только затронутых файлов (AGENT.md, docs/howto/TESTING.md, docs/concepts/*.md (5: CONCEPT_BUILDING_SYNERGY, CONCEPT_CHARACTER_SYSTEM, CONCEPT_SOCIAL_RACES, TASK_SOCIAL_AND_BUILDINGS, TASK_BUILDING_SCORING_GODOT47), docs/systems/spells_system.md, docs/misc/binomials.md, docs/README.md, game/tests/test_logger.gd, openspec/changes/fix-audit-findings-2026-08-31/); WIP (418 ` D`, untracked) не задевать
- [x] 6.2 коммит; после — `git status --short | awk '{print $1}' | sort | uniq -c` → WIP-снимок сохранён; отметить 6.x в tasks.md (отдельным докоммитом артефактов change)
