# Proposal: world-controller-decoupling

**Status:** In Progress (R1 done; R2–R7 open)
**Created:** 2026-07-15 · **Restored:** 2026-09-27 (артефакты восстановлены из audit-заметок `.pi/todos/opsx-propose-audit.md`; оригинал потерян при graft истории)

## Why

Senior-architect аудит по 5 измерениям выявил нарушения слоистой архитектуры (`ARCHITECTURE.md`, `CORE_TURN_PIPELINE.md`):

- **WorldController** содержал 602 строки, ~200 из которых — тяжёлая логика наследования/смерти/воскрешения/хроники, что нарушает принцип «координаторы не держат тяжёлую логику». **Исправлено в R1** (сейчас 141 строка).
- **Socket/MCP сервер** (`game/tools/mcp/mcp_interaction_server.gd`, 205 строк) — смешение транспорта и команд + глобальное состояние; историческая проблема EADDRINUSE при повторном listen. Кандидат на декомпозицию (R2).
- **7 untyped Variant-полей** в контуре WorldController; дрейф `ServiceContainer.current` vs DI — R4/R5.
- Сильные стороны (не трогаем): pathfinding (BFS/A*/Dijkstra + MinHeap), 1010+ тестовых методов.

## What Changes

- **R1 (DONE, commit d7131b1):** death-flow (14 методов) вынесен из WorldController в `HeroLifecycleSystem` (RefCounted, headless-safe, подписан на `hero_died`). WC: 602 → 141 строка (цель Req2 ≤400 перевыполнена). Тесты обновлены (3 файла); compile clean (177 ok); 5672 tests pass, 0 fail; operability CLEAN.
- **R2:** декомпозиция MCP/Socket-слоя: транспорт ↔ команды (`mcp_commands_*` уже разделены) ↔ состояние; устранение глобального состояния; корректная обработка занятого порта.
- **R3:** интерфейс `IHeroConsumer` — **REJECTED** (Design D: `_install_hero` остаётся на WC как coordinator-owned).
- **R4:** типизация всех Variant-полей в WC-контуре.
- **R5:** устранение дрейфа `ServiceContainer.current` vs DI (единый контейнер).
- **R6:** остаточная координационная «клейкая» логика → `world_event_router` / сервисы.
- **R7:** регрессионная верификация + операционная проверка (0 errors/warnings).

## Capabilities

### New Capabilities
- `world-controller`: контракт координатора мира — тонкий делегат, без тяжёлой игровой логики, ≤400 строк, типизированные поля, единственный DI-путь.

### Modified Capabilities
- (нет — поведение игры не меняется, чистый рефакторинг)

## Impact

- `game/scripts/world/world_controller.gd` (R1 ✓), `game/scripts/world/hero_lifecycle_system.gd` (R1 ✓)
- `game/tools/mcp/mcp_interaction_server.gd`, `mcp_commands_*.gd`, `mcp_serialization.gd` (R2)
- `game/scripts/autoload/services.gd` / ServiceContainer (R5)
- Тесты: `game/tests/` (unit/integration/systems), `game/tests/mcp/`
- Risk: low — каждый шаг закрывается зелёным прогоном `run_all.sh` + operability check.

## Acceptance Criteria

- [x] 1. WorldController ≤ 400 строк без тяжёлой игровой логики (факт: 141)
- [x] 2. HeroLifecycleSystem покрыт тестами, death-flow работает как прежде
- [x] 3. Socket/MCP слой: транспорт отделён от команд (McpCommandDispatcher), явный lifecycle start/stop, EADDRINUSE-обработка (R2)
- [ ] 4. 0 untyped Variant-полей в WC-контуре (R4)
- [ ] 5. Единый DI-путь, `ServiceContainer.current` удалён или обёрнут (R5)
- [ ] 6. Полный прогон тестов зелёный + operability CLEAN после каждой фазы (R7)
