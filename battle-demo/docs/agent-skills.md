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

| Фаза | Скилл выполнен | Артефакт (путь) |
| --- | --- | --- |
| 0 | — | — |
