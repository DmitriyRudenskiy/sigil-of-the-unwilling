# Индекс активных циклов OpenSpec

Обновлён: 2026-09-29.

**Активных циклов нет.** Все циклы завершены и заархивированы.

Последний завершённый цикл: **dnd-class-race-tactical-bonuses** (2026-09-29) —
класс/расовые тактические бонусы для D&D-персонажей в живом D&D-бою
(DnDCombatantProfile.class_id/race_id, таблица DnDTacticalBonuses, DnDBattleBridge
применяет attack/defense/crit/damage-бонусы). Закрывает последний ⏳ тактической
спеки (причина отложенности «D&D-профили отложены» устранена dnd-live-battle-wiring).

Ранее завершены (2026-09-28): dnd-live-battle-wiring, world-controller-decoupling,
tactical-combat-implementation, scarce-crafting-system, dnd-verticality-falling,
crisis-content-seasonal-rare-events, save-load-coverage-expansion.

Архив завершённых циклов: `openspec/changes/archive/` (32 записи на 2026-09-29).
Main specs (истина): `openspec/specs/` — 24 capability.

**Тесты:** полный прогон `-a res://tests` зелёный — 204/204 suites, 1933 test cases,
0 errors, 0 failures (включая 13 новых test_dnd_tactical_bonuses). Конфликты
class_name в gdUnit4 (City/BaseTest) патчатся `tests/patch_gdunit4.sh` (см.
`doc/testing.md`); полный прогон запускается `bash tests/run_all.sh`.
