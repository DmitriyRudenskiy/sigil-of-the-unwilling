# Контракт исполнения — battle-demo-two-rosters

Этот файл перечитывается **в начале каждой фазы** (задача `N.1` каждой группы).
Он определяет, какой скилл чем обязан закончиться и чем фаза проверяется.
Ни один шаг ниже не требует человека: «read-агент» — свежая сессия
`pi -p --no-tools --no-session` (прецедент `scripts/concept_art/blind_judge.py`),
визуальная приёмка — кадр + вердикт с md5.

## Цепочка фаз

| # | Фаза | Скилл(ы) | Артефакт | Чем проверяется |
| --- | --- | --- | --- | --- |
| 0 | Контракт | — | `docs/agent-skills.md`, `docs/known-issues.md` | `grep` на «покажи пользователю» пуст |
| 1 | Каркас и гейт | `setup-engine`, `test-setup`, `test-helpers` | `project.godot`, `addons/gdunit4`, `run_tests.sh`, `tests/helpers/` | `battle-demo/run_tests.sh` → exit 0 |
| 2 | ADR и архитектура | `architecture-decision`, `create-architecture`, `domain-modeling` | `docs/decisions.md`, `docs/architecture.md`, `docs/glossary.md` | каждый ADR: контекст/альтернативы/последствия |
| 3 | Дизайн и оценка | `art-bible`, `asset-spec`, `quick-design`, `ux-design`, `design-review`, `consistency-check`, `scope-check`, `estimate` | `docs/art-bible.md`, `docs/design-brief.md`, `docs/ui-spec.md`, `docs/asset-spec.md`, `docs/design-review.md`, `docs/consistency-report.md`, `docs/scope-report.md`, `docs/estimate.md` | ревью-вердикт по каждому разделу; scope-лист ТЗ пуст |
| 4 | Боевое ядро | `tdd`, `systematic-debugging`, `test-evidence-review` | `scripts/combat/*.gd`, `tests/unit/combat/*.gd`, `docs/test-evidence.md` | гейт зелёный; бой проходит без сцены |
| 5 | Наборы A/B | `quick-design`, `tdd` | `data/units/*.tres`, `data/rosters/*.tres` | инварианты и отказы загрузки — тесты |
| 6 | Генерация спрайтов | `asset-spec` + ComfyUI MCP | `tools/spec.json`, `artifacts/generate.log`, `docs/generation-log.md` | `ИТОГ ok=… skip=… fail=…`; 45 сюжетов в реестре |
| 7 | Keying и импорт | `asset-audit` | `tools/cut_frames.py`, `tools/audit_sprites.py`, `tools/build_sprite_frames.gd`, `docs/asset-audit-report.md` | аудит по файлу; идемпотентность `.tres` |
| 8 | Анимация и приёмка спрайтов | read-агент | `scenes/battle_unit.tscn`, `docs/sprite-review-*.md`, `docs/animation-review-*.md` | тесты состояний; отчёт с md5 кадра |
| 9 | Боевой UI | `team-ui`, `ux-review` | `scenes/roster_select.tscn`, `scenes/battle.tscn`, `tools/capture_screens.gd` | тесты синхронности; 8 кадров скриншотов |
| 10 | Приёмка и автономность | `ux-review`, `qa-plan`, `smoke-check`, `regression-suite`, `verification-before-completion` | `docs/qa-plan.md`, `docs/ui-review-*.md`, `docs/regression-suite.md` | гейт зелёный; леджер тестов; отметки фаз здесь |
| 11 | Документация и публикация | `code-review`, `design-review`, `changelog`, `onboard`, `gate-check`, `vertical-slice` | `docs/handoff.md`, `CHANGELOG.md`, `docs/vertical-slice.md`, `docs/gate-check.md` | DoD по 9 пунктам, AC PASS/FAIL |

## Отклонения от ТЗ (детали и причины — `design.md` D12)

| ТЗ | Как делается |
| --- | --- |
| GUT | GdUnit4 (аддон репозитория) |
| `docs/decisions.md`, `CHANGELOG.md`, `data/`, `project.godot` в корне | те же имена под `battle-demo/` |
| read-агент «Explore/general-purpose» | `pi -p --no-tools --no-session --mode text @кадр.png` |
| свой CI / PR | локальный гейт + push в `main` по «мержи» (AGENTS.md) |
| скилл `handoff` | `onboard` + `docs/handoff.md` |
| `setup-engine` поверх занятого движка | сверка версии и фиксация в `docs/architecture.md` |
| анимации `idle/walk/attack/hit/death` | `idle/walk/attack/hit/turn`, гибель без анимации (владелец, 2026-10-24) |
| `Xvfb` для съёмки кадров | на macOS GUI поднимается нативно; `Xvfb` — только на Linux-раннере |

## Отметки фаз

Отмечено 2026-10-25 (задача 10.8). «Выполнен» = артефакт фазы лежит по пути
контракта; «носитель другой» = работа сделана, но не тем файлом, что назван в
контракте (причина в сноске); «открыто» = задача группы не сделана.

| Фаза | Скилл выполнен | Артефакт (путь) |
| --- | --- | --- |
| 0 | да | `docs/agent-skills.md`, `docs/known-issues.md` |
| 1 | да | `project.godot`, `addons/gdunit4/`, `run_tests.sh`, `tests/helpers/` |
| 2 | да | `docs/decisions.md`, `docs/architecture.md`, `docs/glossary.md` |
| 3 | да | `docs/art-bible.md`, `docs/design-brief.md`, `docs/ui-spec.md`, `docs/asset-spec.md`, `docs/design-review.md`, `docs/consistency-report.md`, `docs/scope-report.md`, `docs/estimate.md` |
| 4 | да | `scripts/combat/`, `tests/unit/combat/`, `docs/test-evidence.md` |
| 5 | да | `data/units/*.tres`, `data/rosters/*.tres`, `tests/unit/data/` |
| 6 | частично | `tools/spec.json`, `artifacts/generate.log`, `docs/generation-log.md`. Открыто: 6.8, 6.9, 6.10, 6.15, 6.16 (покадровый фолбэк и лист экипировки — не гнались; клип-путь D15 дал девять комплектов) |
| 7 | носитель другой | названных `tools/cut_frames.py`, `tools/audit_sprites.py`, `docs/asset-audit-report.md` в репо нет: фон снимает ункей в `tools/gen_clip.py`/`tools/mirror_anim.py` (мера спила — `known-issues.md` №6), аудит треков делают тесты `tests/unit/helpers/test_sprite_asserts.gd` и `tests/unit/view/test_sprite_tracks.gd`, сборка `.tres` — `tools/build_sprite_frames.gd` + `.py` |
| 8 | частично (8.1–8.4) | `scenes/battle_unit.tscn`, `scripts/view/battle_unit_view.gd`, `tests/unit/combat/test_battle_unit_view.gd`. Открыто: 8.5–8.9 — контактный лист, стилевой вердикт read-агента, `docs/sprite-review-*.md`, `docs/animation-review-*.md`, I2V-ветка |
| 9 | да | `scenes/roster_select.tscn`, `scenes/battle.tscn`, `scripts/view/`, `tools/capture_screens.gd` (+8 кадров приёмки), `tests/unit/combat/test_battle_{screen,hud}.gd` |
| 10 | да | `docs/qa-plan.md`, `docs/ui-review-2026-10-25.md`, `docs/ui-read-judge-2026-10-25{,-r3,-r4}.md`, `docs/regression-suite.md` (с леджером), `docs/known-issues.md` (№7), отметки здесь |
| 11 | да (кроме 11.9) | `docs/test-coverage-matrix.md`, `docs/gate-check.md`, `docs/handoff.md`, `CHANGELOG.md`, `docs/vertical-slice.md`, `docs/ui-read-judge-2026-10-26.md`. Открыто: 11.9 — push по явному «мержи» владельца; вердикт ворот — **FAIL** (два блокера «спека ↔ носитель») |
