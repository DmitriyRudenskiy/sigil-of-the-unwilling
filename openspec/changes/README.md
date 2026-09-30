# Индекс активных циклов OpenSpec

Обновлён: 2026-09-29.

**Активных циклов нет.** Все циклы завершены и заархивированы.

Последний завершённый цикл: **dnd-battle-factory** (2026-09-29) —
production-API для построения и разрешения D&D-боя из явных определений
персонажей (DnDBattleFactory + DnDCharacterDef: build_profile/build_stack/
build_battle/simulate). Переводит per-character D&D-модель из test-only в
production-entry point, не затрагивая stack-модель и WorldBattleCoordinator.

Ранее завершены (2026-09-29): dnd-class-race-tactical-bonuses — класс/расовые
tactical-бонусы D&D-персонажей (закрыл последний ⏳ тактической спеки).

Ранее завершены (2026-09-28): dnd-live-battle-wiring, world-controller-decoupling,
tactical-combat-implementation, scarce-crafting-system, dnd-verticality-falling,
crisis-content-seasonal-rare-events, save-load-coverage-expansion.

Архив завершённых циклов: `openspec/changes/archive/` (31 запись на 2026-09-29).
Main specs (истина): `openspec/specs/` — 24 capability.

**Тесты:** полный прогон `-a res://tests` зелёный — 205/205 suites, 1944 test cases,
0 errors, 0 failures (включая 11 новых test_dnd_battle_factory). 135 orphans —
метрика GdUnit4 (warning, exit 101), не failures. Конфликты class_name в gdUnit4
(City/BaseTest) патчатся `tests/patch_gdunit4.sh` (см. `doc/testing.md`); полный
прогон запускается `bash tests/run_all.sh`.
