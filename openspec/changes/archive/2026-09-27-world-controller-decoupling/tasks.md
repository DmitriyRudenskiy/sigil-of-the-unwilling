# Tasks: world-controller-decoupling

> **Status:** фаза 1 закрыта (коммит d7131b1), фаза 2 (R2, MCP-декомпозиция) закрыта. Следующий шаг — фаза 3 (R4, типизация).

## Phase 1 — R1: HeroLifecycleSystem extraction ✅

- [x] 1.1 Создать `game/scripts/world/hero_lifecycle_system.gd` (RefCounted, headless-safe, коннект к `hero_died`) *(R1)*
- [x] 1.2 Перенести 14 методов death-flow из WorldController (602 → 141 строка; Req2 ≤400 перевыполнен) *(R1)*
- [x] 1.3 WC: coordinator-owned `_hero` + тонкие делегации + `set_hero()` *(R1)*
- [x] 1.4 Обновить тесты (3 файла): wire `_hero_lifecycle`, переименовать 4 поля death-flow *(R1)*
- [x] 1.5 Верификация: compile clean (177 ok), 5672 tests pass / 0 fail, operability CLEAN *(R1)*
- [x] 1.6 Коммит **d7131b1** *(R1)*
- [x] 1.7 R3 `IHeroConsumer` — REJECTED (Design D: `_install_hero` остаётся на WC) *(R3)*

## Phase 2 — R2: Socket/MCP декомпозиция (High) ✅

> Уточнение путей (2026-09-27, по факту репозитория): сервер находится в `game/tools/mcp/`, не `game/scripts/mcp/`. Разделение команд уже частично выполнено: `mcp_commands_base.gd` (53), `_system.gd` (1788), `_render.gd` (1223), `_ui.gd` (646), `_input.gd` (434), `mcp_serialization.gd` (183). В `mcp_interaction_server.gd` (205 строк) `listen()` вызывается однократно (~стр. 52), явной обработки EADDRINUSE нет — задача 2.4 подтверждена как реальная. Python-тесты MCP живут в `game/tests/mcp/` (pytest), а не `game/tests/mcp/*.gd` — тесты из 2.5 писать на pytest.

- [x] 2.1 Инвентаризация состояния `mcp_interaction_server.gd` (205 строк): транспорт + диспетч; командная логика уже вынесена в mcp_commands_* *(выполнено при аудите 2026-09-27)*
- [x] 2.2 Реестр команд + роутинг вынесены в `McpCommandDispatcher` (RefCounted, `mcp_command_dispatcher.gd`); сервер — только транспорт/аутентификация/busy; группы получили `tick()`/`shutdown()` (base + system)
- [x] 2.3 Явный lifecycle: идемпотентные `start() -> bool` / `stop()`; `_ready` → `start()`, `_exit_tree` → `stop()`; half-init глобальных при ошибке listen исключён; `_exit_tree` больше не лезет в приваты групп (`group.shutdown()`)
- [x] 2.4 EADDRINUSE: `ERR_ALREADY_IN_USE` → понятная push_error (подсказка про MCP_PORT), сервер остаётся в чистом not-started состоянии; повторный `start()` идемпотентен; peer-утечки нет (старый peer disconnect, буфер/busy сброс)
- [x] 2.5 Тесты: `tests/mcp/test_mcp_server_lifecycle.py` (pytest, raw TCP, headless Godot): reconnect после ухода клиента, unknown command через диспетчер, идемпотентный `start()`, EADDRINUSE-ошибка второй инстанции; gdUnit4 `test_mcp_server.gd` обновлён под `_dispatcher`
- [x] 2.6 Верификация gate + коммит: `--import` clean (exit 0); headless-запуск проекта — 0 script errors, MCP слушает; gdUnit4 MCP-сьюты 24/24 PASSED; новый pytest `test_mcp_server_lifecycle.py` 4/4 PASSED (reconnect, unknown command, idempotent start, EADDRINUSE); полный unit-прогон 1608 кейсов — набор фейлов идентичен базлайну (предсуществующие env-фейлы test_spells_json/test_crisis_events, регрессий 0). Примечание: полный run_all.sh в этой среде не проходится из-за отсутствия godot-mcp (не трекается) и предсуществующих env-фейлов — зафиксировано сравнением с baseline (stash)

## Phase 3 — R4: Типизация ✅

- [x] 3.1 Найти все untyped Variant-поля в WC-контуре (baseline: 7)
  - Фактически найдено 21 поле + 14 сигнатур: world_controller.gd (3),
    hero_lifecycle_system.gd (11 + setup), world_hero_manager.gd (1 + 2 ф-ии),
    world_bootstrap.gd: поля BootstrapResult (6: map_gen, camera, cities,
    battle_coordinator, interaction_controller, persistence).
- [x] 3.2 Типизировать; статический анализ чистый
  - Конкретные типы: CityManager, MapGenerator, WorldEventRouter,
    WorldBattleCoordinator, WorldInteractionController, SuccessionController,
    WorldBootstrap.BootstrapResult, WorldCamera; `instantiate() as MapGenerator`.
  - persistence: WorldPersistence в BootstrapResult, но RefCounted в
    WC/HeroLifecycleSystem (тест-мок _MockPersistence не наследует
    WorldPersistence — RefCounted общий знаменатель).
  - `--import` clean (exit 0); WC-сьюты 49/49 PASSED.
- [x] 3.3 Верификация gate + коммит
  - `--import` clean; WC/hero-сьюты 49/49 + 42/42 PASSED, 0 orphan'ов (Node-моки
    MockBattle/MockInteraction освобождаются в after_test); полный прогон
    1781 кейс — 62 errors + 4 failures, идентично baseline (регрессий 0).

## Phase 4 — R5: DI convergence ✅

- [x] 4.1 Подсчитать call-sites `ServiceContainer.current`
  - **Аудит: 0 call-sites.** `ServiceContainer` в коде отсутствует
    (scripts/tests/tools) — контейнер уже единый: autoload `Services`
    (`scripts/autoload/services.gd`) → `ServiceRegistry`
    (`scripts/core/service_registry.gd`); `Services.resolve` используется в
    26 файлах. Глобального `.current` нет (grep `var current` — только
    локальные переменные).
- [x] 4.2 Мигрировать потребителей на внедрение; `.current` удалить или оставить фасадом (решение по 4.1)
  - **N/A** — дрейф уже устранён в предшествующих циклах; мигрировать нечего.
- [x] 4.3 Верификация gate + коммит
  - Аудит-only (без кодовых изменений); gate — тот же прогон, что по 3.3.

## Phase 5 — R6: Event routing ✅

- [x] 5.1 Перенести разбросанные коннекты мир-событий в `world_event_router.gd`
  - **Аудит: уже выполнено.** `world_event_router.gd` — центр роутинга
    (52 `.connect`, все GameEventBus-подписки мира: battle_won, turn_ended,
    resource_*, ...).
- [x] 5.2 WC не содержит роутинга; регрессия событий покрыта тестами
  - `world_controller.gd`: 0 коннектов GameEventBus (только
    `renderer.fog_refreshed` — рендер-колбэк, не мир-событие).
  - `hero_lifecycle_system.gd`: единственный `hero_died.connect` — осознанный
    (R1: death-flow принадлежит lifecycle-системе).
  - `world_bootstrap.gd`: one-shot composition-root wiring (city_proc →
    GameEventBus) — не роутинг, а сборка графа.
  - Регрессия: сьюты worldcontroller_succession_wiring, legend_chronicle,
    hero_resurrection, hero_lifecycle, hero_survival, world_bootstrap — зелёные.
- [x] 5.3 Верификация gate + коммит
  - Аудит-only (без кодовых изменений); gate — тот же прогон, что по 3.3.

## Phase 6 — R7: Final verification & sync ✅

- [x] 6.1 Полный прогон: compile, run_all.sh, operability CLEAN
  - `--import` exit 0; gdUnit 1781 кейс = baseline (62 errors + 4 failures —
    пре-экзистинг, 0 регрессий); MCP pytest test_mcp_server_lifecycle 4/4;
    структурные проверки (дубли tests/Test*.gd) — нет.
- [x] 6.2 Обновить Acceptance Criteria в proposal.md (все 6 пунктов [x])
- [x] 6.3 `/opsx-sync`: создан main spec `openspec/specs/world-controller/spec.md`
- [x] 6.4 `/opsx-archive world-controller-decoupling` →
  `openspec/changes/archive/2026-09-27-world-controller-decoupling/`
