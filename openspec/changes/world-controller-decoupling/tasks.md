# Tasks: world-controller-decoupling

> **Status (2026-09-27):** цикл восстановлен из audit-заметок. Фаза 1 закрыта (коммит d7131b1). Следующий шаг — `/opsx-apply` фаза 2 (R2, High priority).

## Phase 1 — R1: HeroLifecycleSystem extraction ✅

- [x] 1.1 Создать `game/scripts/world/hero_lifecycle_system.gd` (RefCounted, headless-safe, коннект к `hero_died`) *(R1)*
- [x] 1.2 Перенести 14 методов death-flow из WorldController (602 → 141 строка; Req2 ≤400 перевыполнен) *(R1)*
- [x] 1.3 WC: coordinator-owned `_hero` + тонкие делегации + `set_hero()` *(R1)*
- [x] 1.4 Обновить тесты (3 файла): wire `_hero_lifecycle`, переименовать 4 поля death-flow *(R1)*
- [x] 1.5 Верификация: compile clean (177 ok), 5672 tests pass / 0 fail, operability CLEAN *(R1)*
- [x] 1.6 Коммит **d7131b1** *(R1)*
- [x] 1.7 R3 `IHeroConsumer` — REJECTED (Design D: `_install_hero` остаётся на WC) *(R3)*

## Phase 2 — R2: Socket/MCP декомпозиция (High) ⬜

- [ ] 2.1 Инвентаризация состояния `mcp_interaction_server.gd` (205 строк): что относится к транспорту, что к командам
- [ ] 2.2 Вынести остаточную командную логику в `mcp_commands_*` (base/system/input/render уже разделены)
- [ ] 2.3 Устранить глобальное mutable state сервера (явный lifecycle start/stop)
- [ ] 2.4 Обработка EADDRINUSE: идемпотентный `listen()`, понятная ошибка, без утечки peers
- [ ] 2.5 Тесты `game/tests/mcp/`: повторный старт, регистрация команд через новый путь
- [ ] 2.6 Верификация gate (compile + run_all + operability) + коммит

## Phase 3 — R4: Типизация ⬜

- [ ] 3.1 Найти все untyped Variant-поля в WC-контуре (baseline: 7)
- [ ] 3.2 Типизировать; статический анализ чистый
- [ ] 3.3 Верификация gate + коммит

## Phase 4 — R5: DI convergence ⬜

- [ ] 4.1 Подсчитать call-sites `ServiceContainer.current`
- [ ] 4.2 Мигрировать потребителей на внедрение; `.current` удалить или оставить фасадом (решение по 4.1)
- [ ] 4.3 Верификация gate + коммит

## Phase 5 — R6: Event routing ⬜

- [ ] 5.1 Перенести разбросанные коннекты мир-событий в `world_event_router.gd`
- [ ] 5.2 WC не содержит роутинга; регрессия событий покрыта тестами
- [ ] 5.3 Верификация gate + коммит

## Phase 6 — R7: Final verification & sync ⬜

- [ ] 6.1 Полный прогон: compile, run_all.sh, operability CLEAN
- [ ] 6.2 Обновить Acceptance Criteria в proposal.md
- [ ] 6.3 `/opsx-sync`: создать main spec `openspec/specs/world-controller/spec.md`
- [ ] 6.4 `/opsx-archive world-controller-decoupling`
