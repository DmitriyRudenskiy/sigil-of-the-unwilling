# Proposal: spell-system-audit-class-race-progression

## Status
status: completed *(legacy backfill, верифицировано по коду 2026-09-27)*

## Summary
Аудит и выравнивание системы заклинаний с прогрессией классов/рас: реестр заклинаний, книги заклинаний (spellbooks), резолвер эффектов, привязка расовых и классовых способностей к наследию/прогрессии.

## Verification
- `game/scripts/autoload/spell_registry.gd`, `spellbook_registry.gd` — реестры заклинаний и книг.
- `game/scripts/data/spell_resolver.gd`, `spell_utils.gd`, `spell_enums.gd`, `spellbook_def.gd` — резолв и модели данных.
- `game/scripts/data/class_def.gd`, `hero_classes.gd`, `race_def.gd`, `hero_races.gd`, `race_class_registry.gd` — класс/расовая прогрессия.
- `game/scripts/systems/spell_caster.gd`, `game/scripts/ui/battle_spellbook_panel.gd` — применение в бою/UI.
- Тесты: spell/class/race-тесты в `game/tests/unit/data/` и `game/tests/unit/systems/`.

## Acceptance Criteria
- [x] Реестр заклинаний единый источник правды (id → дефиниция)
- [x] Классы/расы корректно мапятся на доступ к спеллбукам
- [x] Резолвер эффектов покрыт юнит-тестами

## Note
`skip_specs: true`. Готово к архивации без sync.
