# Proposal: content-expansion-pack-1

## Status
status: completed *(legacy backfill, верифицировано по коду 2026-09-27)*

## Summary
Первый пакет контента: события/кризисы (JSON-шаблоны), конфигурация игры и данных мира, единицы/классы/расы, оружие и заклинания — наполнение data-driven слоёв поверх реализованных систем.

## Verification
- `game/data/events/` — `crisis_01..08.json`, `event_*.json` (контент событий/кризисов).
- `game/data/config/` — конфиги баланса/мира.
- `game/scripts/data/templates/` (`t07_spell_draw.gd` и др.) — шаблоны контента.
- `game/scripts/systems/weapon_catalog.gd` — контент оружия.
- Покрытие: `test_crisis_events.gd` (валидность всех JSON-шаблонов, well-formed choices, иконки), `test_law_manager.gd`.

## Acceptance Criteria
- [x] Пакет событий/кризисов загружается из JSON без ошибок (тесты валидации)
- [x] Конфиги данных консистентны с загрузчиками
- [x] Контент интегрирован в crisis/event/weapon системы

## Note
`skip_specs: true`. Готово к архивации без sync.
