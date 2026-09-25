# Proposal: dynamic-events-roleplay

## Status
status: completed

## Why
Система событий с ролевым отыгрышем: панель решений игрока и кризисы с выбором
последствий. Реализовано в PR #2 (UIManager, GameManager, CrisisEventSystem,
decision_panel) и починено post-merge (commit 0a4e939).

## What Changes
- UIManager: show_decision_panel() / show_crisis_panel(), сигналы decision_made / crisis_resolved
- GameManager: on_day_passed() → триггеры событий, start_crisis / end_crisis, has_building / get_resource
- decision_panel: проверка требований выбора (здания, ресурсы), индикатор серьёзности

## Impact
- specs: не модифицирует main specs (skip_specs) — поведение покрыто кодом и тестами
- code: game/scripts/managers/, game/scripts/ui/decision_panel.gd, game/scripts/systems/crisis_event_system.gd
