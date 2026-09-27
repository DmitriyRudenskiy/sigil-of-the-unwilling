# Proposal: save-load-coverage-expansion

**Status:** Open (propose)

## Why

Сериализация мира фрагментирована: `world_state_serializer.gd` (152 строки, на практике используется как snapshot для MCP/отладки — hero pos, ресурсы, followers, needs), `city_state_serializer.gd`, `city_serializer.gd`. Аудит незакрытых циклов 2026-09-27 показал, что подсистемы, добавленные в v1.x, **не имеют подтверждённого покрытия сейвом**: активные crisis-события и их прогресс (`crisis_event_system.gd`), сезонный счётчик (`WorldSeasons._turns_in_season` — static var!), D&D combatant-профили, квесты/репутация (`quest-system`, `reputation-system` из архива), хроника (`legend_tracker.gd`, `glory_tracker.gd`). Каждый незакрытый случай = потеря прогресса при load. Нужен систематический цикл аудита→покрытия→миграций.

## What Changes

- **NEW capability `save-migration`:** контракт полноты сериализации + версионирование формата сейва.
- Матрица покрытия: каждая stateful-подсистема имеет roundtrip-тест (save → load → deep-equal).
- Версия формата сейва + миграции (сейвера у legacy-формата нет — зафиксировать baseline v1).
- Устранение hidden state: `static var` счётчики (WorldSeasons и аудит остальных) переводятся в сериализуемое состояние или сбрасываются детерминированно при load.
- Интеграция с будущими циклами: crafting-прогресс (`scarce-crafting-system`) и новые события обязаны добавлять roundtrip-тест — требование спеки.

## Capabilities

### New Capabilities
- `save-migration`: полнота roundtrip-сериализации, версионирование, политика миграций, запрет несериализуемого скрытого состояния.

## Impact

- `game/scripts/autoload/world_state_serializer.gd`, `city_state_serializer.gd`, `city_serializer.gd`
- Подсистемы из матрицы: crisis, seasons, quests, reputation, legend/glory, artifact_registry, dnd profiles (если live-wired)
- Тесты: новый набор `game/tests/functional/save_roundtrip_*`
- Координация: scarce-crafting-system, crisis-content-*, tactical-combat-implementation (трофеи/ранения)

## Acceptance Criteria

- [ ] 1. Матрица покрытия составлена, все gaps закрыты roundtrip-тестами
- [ ] 2. Формат сейва имеет версию; загрузка без версии трактуется как v1
- [ ] 3. 0 несериализуемых `static var` с игровым состоянием (найденные — переведены или обнуляемы при load с тестом)
- [ ] 4. Crisis-событие посреди активного кризиса переживает save/load без потери фазы/таймеров
- [ ] 5. Полный прогон зелёный; delta synced; цикл архивирован
