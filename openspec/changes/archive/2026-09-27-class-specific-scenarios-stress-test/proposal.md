# Proposal: class-specific-scenarios-stress-test

## Status
status: completed *(legacy backfill, верифицировано по тестам 2026-09-27)*

## Summary
Стресс-проверка классово-специфичных сценариев: каждый класс/раса проверяется в характерных ситуациях (бой, заклинания, нагрузка, социалка) через расширенные юнит-тесты и детерминированные прогоны.

## Verification
- Тесты классов/рас: `game/tests/unit/data/` — coverage для `hero_classes.gd`, `hero_races.gd`, `race_class_registry.gd` (наследие, стартовые спеллбуки, расовые модификаторы).
- Боевые сценарии: `game/tests/unit/battle/` — атаки/урон/условия per-class (`test_dnd_integration.gd`, `test_dnd_maneuvers.gd`, `test_dnd_saves.gd`; rigged RNG для детерминизма).
- Нагрузочные/стресс-кейсы: `game/tests/unit/test_settings_guard.gd`, массовые прогоны боевого стека; полный сьют 1757 тестов (CHANGELOG 2026-09-25).
- MCP-проба: `game/tests/mcp/test_balance_probe.py` — стресс экономики вне GUI.

## Acceptance Criteria
- [x] Каждый класс/раса имеет минимум один целевой сценарный тест
- [x] Стресс-прогоны детерминированы (seed/rigged RNG)
- [x] Деградации (0 HP, перегруз, пустой спеллбук) покрыты edge-case тестами

## Note
`skip_specs: true` — тестовое изменение, спека не требуется. Готово к архивации без sync.
