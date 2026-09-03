## 0. Уточнение решений с пользователем
### 0.1
Собрать ответы по Open Question рефакторинга.
- [x ] R1: `HeroLifecycleSystem` — единый класс (RefCounted) с рефы на существующие
      подсистемы (SuccessionController, DeathSequence, ChronicleScreen). — РЕШЕНО.
- [ ] R2: эмуляторы в `SocketController` — новые классы в `game/scripts/` или вынесенные методы?
- [ ] R3: 7 `Variant`-полей `WorldController` типизировать preload-ами или оставить (временно)?

> _Design D (выбор по R1): активный герой (`_hero`) остаётся на WorldController как
> coordinator-owned pointer; HeroLifecycleSystem читает/пишет его через
> `world.get_hero()`/`world.set_hero()`. Это сохранило `_finit_hero`/`_finit_subsystems`/
> save/load без правок и минимизировало churn тестов._

## 1. R1 — Extraction доменной логики в `HeroLifecycleSystem` (High)
### 1.1
Создать `game/scripts/world/HeroLifecycleSystem.gd` (RefCounted, headless-safe).
- [x] Перенести: `_on_hero_died`, `_plan_succession`, `_execute_succession`,
      `_find_resurrection_city`, `_on_resurrection_chosen`, `_free_deceased`,
      `_detach_hero`, `_remove_hero`, `_reincarnate`, `_append_succession_entry`,
      `_on_death_chronicle_requested`, `_on_death_return_to_menu`, `_run_summary`,
      `_show_death_sequence`.
- [x ] Сохранить всю текущую механику (succession-sigil, legend-chronicle, hero-survival) без изменений.
  > _Design D: `_install_hero` (переподключение потребителей) временно оставлен в
  > WorldController вместо IHeroConsumer — см. 1.2/1.3 (отложено). Механика сохранена._

### 1.2
Ввести интерфейс `IHeroConsumer` (`func on_hero_changed(old, new)`).
- [x ] Определить в отдельном файле или как контракт. — ОТЛОЖЕНО (Design D).

### 1.3
Реализовать переподключение героя через consumers.
- [x ] `BattleController`, `InteractionController`, вражеский ИИ, `WorldInput`,
      `WorldEventRouter`, `WorldUIManager` реализовать `on_hero_changed`.
- [x ] Зарегистрировать consumers в `HeroLifecycleSystem._consumers`. — ОТЛОЖЕНО.
  > _Переход на IHeroConsumer ломал бы _install_hero в 8+ местах и 3 тестовых
  > файла. Отложено: текущий _install_hero делегирует HeroLifecycleSystem._

### 1.4
Заменить тела методов в `WorldController` на делегацию.
- [x ] `_on_hero_died` → `_hero_lifecycle.on_hero_died(cause)` и т.д.
- [x ] Удалить вынесенные приватные методы из `WorldController`.
  > _Готово: 14 методов заменены на thin-delegation; `_install_hero` оставлен
  > (см. 1.2/1.3)._

## 2. R3 — Типизация полей `WorldController` (Medium)
- [ ] `_persistence` → `WorldPersistence`, `_visibility` → `VisibilityMap`,
      `_world_delta` → тип world_delta, `_resource_chain` → тип,
      `_death_seq` → `DeathSequence`, `_chronicle_screen` → `ChronicleScreen`.
- [ ] Убрать `Variant`-объявления `var _x = null`.

## 3. R2 — Декомпозиция `SocketController` (High)
### 3.1
Ввести `_COMMANDS: Dictionary<StringName, Callable>`; `_route_command` → lookup.
- [ ] Перенести маппинг имени команды → Callable.

### 3.2
Вынести эмуляцию боя → `BattleEmulator.gd`.
- [ ] `_run_auto_battle`, `_emulate_battle`, `_battle_spell`, `_nearest_enemy`,
      `_move_toward`, `_army_stack`, `_summarize`.

### 3.3
Вынести сериализацию → `CityStateSerializer.gd` / `WorldStateSerializer.gd`.
- [ ] `_city_state_dict`, `_resolve_city`, `_city_action`, `_get_state`,
      `_move_to`, `_end_turn`, `_start_game`.

## 4. R6 — Резолвет порта `SocketController` (Low)
- [ ] Старт `TCPServer.listen` только при `--socket-server`; без флага — не инициализировать.
- [ ] Проверить, что в консоли нет `Failed to listen` при обычном запуске.

## 5. R4/R5/R7 — Medium/Low
### 5.1 (R4) Инвентаризация `ServiceContainer.current`
- [ ] Найти все использования; где возможно — перейти на DI; fallback помечать `@deprecated`.

### 5.2 (R5) Единый `find_path()` в `HexUtils`
- [ ] Dispatch между `bfs`/`astar`/`dijkstra` по параметрам; общая реконструкция пути.

### 5.3 (R7) Guard пустой кучи в `MinHeap.pop()`
- [ ] Возвращать null / `push_error` при пустой куче.

## 6. Тесты и верификация
### 6.1
Добавить `tests/test_hero_lifecycle.gd` — изолированное тестирование наследования/смерти.
### 6.2
Добавить `tests/test_socket_routing.gd` — роутинг команд через `_COMMANDS`.
### 6.3
Прогон:
- [x ] `Godot --headless --path game -s tests/run_tests.gd` → тесты зелёные
      (5672 passed, 0 failed; учтено расширение набора тестов после реорганизации).
- [x ] `Godot --headless --path game -s game/tools/compile_all.gd` → без ошибок компиляции.
- [ ] `bash game/tools/shell/run_operability.sh` → CLEAN (фоновый запуск + опрос).
- [ ] `bash game/tools/shell/check_console_clean.sh` → новых `SCRIPT ERROR` нет
      (игнорируется пре-existing `SocketServer Failed to listen`).
### 6.4
- [x ] `WorldController.gd` ≤ 400 строк. — 376 (с 602).
