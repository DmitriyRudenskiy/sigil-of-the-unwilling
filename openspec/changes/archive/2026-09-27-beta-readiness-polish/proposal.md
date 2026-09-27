# Proposal: beta-readiness-polish

## Status
status: completed *(legacy backfill, верифицировано по CHANGELOG/коду 2026-09-27)*

## Summary
Полировка до beta-состояния v1.0.0: исправления стабильности (headless-сьют без падений и утечек), сохранение/загрузка состояний подсистем, валидация данных (иконки/JSON), UX-мелочи вне скоупа спецификаций.

## Verification
- CHANGELOG.md: серия записей 2026-09-25 — полные прогоны сьюта **1757/1757 passed, 0 failures** (стабилизирующие фиксы crisis/save-load, валидные иконки `crisis_fire.png`/`crisis_famine.png` вместо битых путей, null-guarded ключ `crisis_state`).
- Сохраняемость состояний: `CrisisEventSystem.serialize_state()/deserialize_state()`, `LawManager.to_dict/from_dict`, `DnDDeathSaves`/`DNDConditionManager` serialization — покрыты round-trip тестами (`test_crisis_events.gd` +3, `test_law_manager.gd`).
- Архивный цикл `2026-02-22-ui-icons-cursors-improvement` (иконки/курсоры) — UI-полировка закрыта ранее.

## Acceptance Criteria
- [x] Полный headless-сьют зелёный на момент релиза v1.0.0
- [x] Все новые подсистемы сохраняются/восстанавливаются (round-trip тесты)
- [x] Нет битых ресурсов (иконки/шрифты) в data-driven контенте

## Note
Зонт-полировка без отдельной спеки (`skip_specs: true`). Готово к архивации без sync.
