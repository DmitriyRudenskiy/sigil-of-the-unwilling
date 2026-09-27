# Proposal: dynamic-ecosystem-scarce-crafting-overhaul

## Status
status: partially-completed *(re-audit 2026-09-27: статус «completed» в старом бэкфилле был ошибочным)*

## Summary
Пересмотр экономики: динамическая экосистема ресурсов (исчерпаемость/возобновление) и дефицитный крафт. Реализована экономическая/экологическая часть; крафт-контур не имеет отдельной системы в коде.

## Verification (что реализовано)
- `game/scripts/economy/` — экономический цикл (добыча/потребление/рынок).
- `game/scripts/systems/world_seasons.gd` — сезонная динамика, влияющая на ресурсы.
- `game/scripts/systems/enemy_growth_system.gd`, `game/scripts/demographics/` — динамика популяций (экосистемная часть).
- `game/scripts/balance/` + `game/scripts/probe/balance_probe.gd` — калибровка редкости/потоков ресурсов (MCP-тесты `game/tests/mcp/test_balance_probe.py`).

## Open Work (почему цикл не закрыт)
- [ ] Крафт-система как отдельный модуль (`crafting_system.gd` / рецепты с дефицитными ингредиентами) — отсутствует в `game/scripts/`; текущий «крафт» ограничен городским тех-деревом (`city-tech-tree`) и `weapon_tech_service.gd`.
- [ ] Сцены/данные рецептов (`game/data/` recipes) — отсутствуют.
- [ ] Delta-specs capabilities `scarce-crafting` / `resource-ecosystem` — не написаны.

## Recommendation
Либо: (а) переименовать/сузить это изменение до «dynamic ecosystem» и закрыть его (реализовано), а крафт вынести в новый propose `scarce-crafting-system`; либо (б) реализовать Open Work и закрыть целиком. Вариант (а) предпочтительнее — код экосистемы уже стабилен и покрыт тестами.
