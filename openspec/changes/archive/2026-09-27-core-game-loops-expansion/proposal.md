# Proposal: core-game-loops-expansion

## Status
status: completed *(legacy backfill, верифицировано по коду 2026-09-27)*

## Summary
Расширение основных игровых циклов: город (тех-дерево), бой (контроллер/ИИ/разрешение урона), экономика/баланс, события и кризисы, квесты/репутация, вес/нагрузка, сезонность — переход от «одного хода» к полноценному long-term loop.

## Verification
- `game/scripts/city/`, `game/scripts/economy/`, `game/scripts/balance/` — экономический и городской циклы.
- `game/scripts/systems/`: `battle_controller.gd`, `battle_ai.gd`, `battle_turn_executor.gd`, `quest_system.gd`, `faction_reputation.gd`, `crisis_event_system.gd`, `law_manager.gd`, `world_seasons.gd`, `enemy_growth_system.gd`, `endgame_controller.gd` — все ключевые лупы.
- Архивные циклы, закрывающие части этого скоупа: `2026-09-13-early-game-foundation`, `2026-09-17-quests-reputation-system`, `2026-09-25-balance-core`, `2026-09-25-dynamic-events-roleplay`, `2026-09-25-social-stats-weapon-tech`, `2026-09-25-attribute-weight-system`.
- Тесты: полный headless-сьют (1757 тестов, см. CHANGELOG).

## Acceptance Criteria
- [x] Ход мира → экономика → город → бой → события связаны через GameManager/EventBus
- [x] Endgame-контур (`endgame_controller.gd`) замыкает цикл
- [x] Каждая подсистема имеет юнит-покрытие

## Note
Зонт-изменение v1.0.0; декомпозировано в перечисленные архивные циклы. `skip_specs: true`, синхронизация не требуется.
