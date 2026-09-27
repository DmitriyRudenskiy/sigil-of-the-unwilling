# Proposal: auto-balance-mcp-framework

## Status
status: completed *(legacy backfill, верифицировано по коду/тестам 2026-09-27)*

## Summary
Автоматический балансировочный фреймворк: headless-проба игрового баланса (`balance_probe.gd`), запускаемая извне через MCP (Model Context Protocol) тулинг для итеративной калибровки экономики и боя без GUI.

## Verification
- `game/scripts/probe/balance_probe.gd` — проба симуляции баланса (симуляция ходов, метрики ресурсов/населения).
- `game/tests/mcp/test_balance_probe.py` — Python-тесты MCP-обвязки пробы.
- Связанные закрытые циклы: архивные изменения `2026-09-25-balance-core` (ядро баланса + тесты).

## Acceptance Criteria
- [x] Headless-проба баланса существует и детерминирована (seeded RNG)
- [x] Вызов из внешнего тулинга (MCP) покрыт тестами
- [x] Интегрировано в CI-сьют Godot-тестов (см. CHANGELOG: полные прогоны сьюта)

## Note
Артефакты tasks/design/delta-specs не создавались на этапе v1.0.0 (`skip_specs: true`). Цикл закрывается бэкфиллом верификации; delta-specs синхронизировать не требуется (capability `balance-probe` уже присутствует в `openspec/specs/`).
