# Proposal: nwn-arsenal-integration

## Status
status: completed *(legacy backfill, верифицировано по коду 2026-09-27)*

## Summary
Интеграция арсенала оружия/экипировки по мотивам Neverwinter Nights: каталог оружия с D&D-параметрами (урон-кубики, свойства finesse/ranged/two-handed) и сервис технологического прогресса разблокировок.

## Verification
- `game/scripts/systems/weapon_catalog.gd` — каталог оружия (данные NWN-арсенала).
- `game/scripts/systems/weapon_tech_service.gd` — тех-дерево/прогресс разблокировок.
- Capability-спека: `openspec/specs/weapon-tech-progress/spec.md` (синхронизирована ранее).
- Тесты: юнит-тесты weapon tech в `game/tests/unit/` (см. архив `2026-09-25-social-stats-weapon-tech`).

## Acceptance Criteria
- [x] Каталог оружия загружается и валиден (урон/свойства)
- [x] Прогресс технологий разблокирует оружие
- [x] Покрыто тестами, интегрировано в бой через боевые юниты

## Note
Спека уже в main specs → архивация без sync.
