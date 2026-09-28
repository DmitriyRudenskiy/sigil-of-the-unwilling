# Индекс активных циклов OpenSpec

Обновлён: 2026-09-28.

**Активных циклов нет.** Все циклы завершены и заархивированы.

Последний завершённый цикл: **dnd-live-battle-wiring** (2026-09-28) — D&D-персонажи
в живом цикле боя (пул HP, d20 vs AC через DnDBattleBridge, урон в пул HP).
Закрывает TASK_21 dnd-battle-system («BattleController uses DnDMechanics»).

Ранее завершены (2026-09-28): world-controller-decoupling, tactical-combat-implementation,
scarce-crafting-system, dnd-verticality-falling, crisis-content-seasonal-rare-events,
save-load-coverage-expansion.

Архив завершённых циклов: `openspec/changes/archive/` (31 запись на 2026-09-28).
Main specs (истина): `openspec/specs/` — 24 capability.

**Тесты:** unit/battle 162/162 зелёный (включая 18 новых test_dnd_live_battle).
⚠️ Полный прогон `-a res://tests` заблокирован pre-existing parse-ошибками
City/CityData/Faction/make_node в functional- и части unit-тестов (desync API
`recruit_military(CityData)` vs тесты, передающие `City`). Подтверждено на чистом
дереве — не из dnd-live-battle-wiring. Отдельная задача на починку.
