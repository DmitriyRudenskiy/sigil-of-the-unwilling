# Design — Полный аудит проекта (5 измерений)

Проект: гексовая стратегия в духе Heroes of Might and Magic III, Godot 4.7.
Объём: ~175 `.gd`-файлов в `game/scripts/` (~28k строк без тестов), 1010 тест-методов.
Архитектурный чётко документирован (`docs/architecture/`). Аудит измеряет **разрыв**
между декларацией и кодом.

---

## 1. Architecture (modularity, separation of concerns, coupling/cohesion, patterns)

### 1.1 [HIGH] WorldController — координатор с тяжёлой логикой (нарушение контракта)

`ARCHITECTURE.md` прямо заявляет: *«Координаторы не содержат тяжёлую логику»*.
`WorldController.gd` (602 строки) нарушает это: ~200 строк — доменная логика
наследования/смерти/воскрешения/летописи.

**Before (фрагмент `WorldController`):**
```gdscript
func _install_hero(hero: HeroController) -> void:
	_hero = hero
	add_child(hero)
	hero.city_manager = _cities
	if _map_gen != null: ...
	if is_instance_valid(battle_coordinator): battle_coordinator.hero = hero
	if is_instance_valid(interaction_controller): interaction_controller.hero = hero
	if _bootstrap_result != null:
		if _bootstrap_result.enemy_proc != null: _bootstrap_result.enemy_proc._hero = hero
		if _bootstrap_result.input_controller != null: _bootstrap_result.input_controller.hero = hero
		if _bootstrap_result.shortcuts != null: _bootstrap_result.shortcuts._hero = hero
	if _event_router != null: _event_router.hero = hero; _event_router._connect_hero_signals()
	if _ui_manager != null: ...
```
`_install_hero` жёстко знает о 8+ потребителях героя — это tight coupling и
нарушение single-responsibility. При добавлении нового потребителя легко забыть
переподключить → use-after-free/краш.

**After (предложение):** вынести в `HeroLifecycleSystem` (RefCounted, headless-safe,
по образцу `SuccessionController`). Герои-потребители регистрируются через
`IHeroConsumer`-интерфейс (`on_hero_changed(old, new)`), а не через жёсткие поля.
`WorldController` только держает рефы и делегирует:
```gdscript
func _on_hero_died(cause: StringName) -> void:
	_hero_lifecycle.on_hero_died(cause)   # вся логика внутри системы
```

### 1.2 [HIGH] SocketController — монологика в autoload (глобальное состояние)

Autoload = глобальный синглтон, стартующий на каждом запуске. `SocketController`
(899 строк) совмещает парсинг/роутинг команд, эмуляцию боя, каст спеллов,
сериализацию состояния. Нарушен принцип *«логика принятия решений не работает с
внутренностями систем»*.

**After:** таблица команд + отдельные эмуляторы (см. spec). Autoloading остаётся
только у реестров (`UnitRegistry`, `SpellRegistry`, …) и шины `GameEventBus`.

### 1.3 [MEDIUM] `ServiceContainer.current` — глобальный доступ рядом с DI

`ARCHITECTURE.md` §8 описывает DI (инъекция → `ServiceContainer` → autoload), но
`ServiceContainer.current` даёт глобальный доступ «немибилизованного» кода. Два
пути доставки сервисов → риск расхождения (DRY для сервисов нарушен).

**After:** инвентаризировать использования `ServiceContainer.current`, там где
возможно — перейти на явную инъекцию; оставить как fallback с пометкой `@deprecated`.

### 1.4 [LOW] 13 autoloadов — глобальное состояние

`SoundManager, Settings, GameEventBus, Spellbook, CursorController, TemplateBootstrap,
SocketController, Units, Artifacts, Spells, Resources` — 13 глобальных синглтонов.
Большинство легитимны (реестры), но `CursorController`/`SocketController` в autoloadе
усложняют headless-тесты (стартуют побочные эффекты: сокет, ввод).

**After:** вынести `SocketController` из autoload в lazy-init по флагу.

---

## 2. Best Practices (idioms, SOLID/DRY/KISS/YAGNI, security/error handling, readability)

- **Типизация:** код в целом строго типизирован (174 `class_name`, принцип
  «данные — типизированные объекты, не Dictionary» соблюдён в домене). Но в
  `WorldController` 7 полей — `Variant` (`var _persistence = null`, `_visibility`,
  `_world_delta`, `_resource_chain`, `_succession`, `_death_seq`, `_chronicle_screen`)
  — потеряна compile-time безопасность. **After:** типизировать через локальные
  preloads (паттерн уже есть в том же файле для `_succession`).
- **Сериализация vs домен:** `SaveData` намеренно использует `Dictionary` для
  персистентности (v1→v7 миграции) — это допустимо (формат хранения), но граничит
  с принципом «no Dictionary**. Тензия не критична, зафиксировать как осознанное решение.
- **Error handling:** `SocketController` только логирует ошибку `listen` (EADDRINUSE=22),
  не пытается переподключиться/выбрать порт. Логика обработки ошибок разронена
  (`push_warning`/`push_error` в `GameLogger`), но не везде. **After:** единая
  стратегия ретрая для сокета; `push_error` вместо `print` для реальных ошибок.
- **Naming/readability:** комментарии на русском, самодокументирующие классы — хорошо.
  `@warning_ignore("integer_division")` в `HexUtils` — осзано; но стоит проверить,
  что деление нацело действительно задумано.

---

## 3. Algorithms (correctness, edge cases, complexity)

### 3.1 [STRENGTH] Pathfinding в `HexUtils.gd` — на высоком уровне
- `bfs_path` — O(V+E), корректно (check start==goal, bounds, blocked, unreachable→[]).
- `astar_path` — O((V+E) log V) с MinHeap, допустимая эвристика
  (`hex_distance`), взвешенная (`ASTAR_HEURISTIC_WEIGHT`), обработка stale-записей.
- `dijkstra`/`dijkstra_path` — O((V+E) log V) с float-стоимостями входа.
- `bfs_reachable` — O(V+E), «кольцо» доступности.
- **Edge cases** обработаны хорошо (boundary, unreachable, stale heap).
- **Замечание (LOW):** `astar_path`, `dijkstra`, `bfs_path` живут отдельно, выбор
  между ними разброшен по вызывающим. **After:** единый entry-point
  `find_path(start, goal, {weighted, cost_fn})` → dispatch. Уберёт дублирование
  реконструкции пути.
- **LOW:** `ring(center, r)` сканирует bounding box O(r²). Для гексов есть O(r)
  генерация кольца. Преимущество O(r²) — простота и детерминированный порядок
  (используется для авто-расстановки зданий). Оптимизировать не обязательно.

### 3.2 MinHeap
Ручная реализация бинарной кучи — разумно (в GDScript нет built-in priority queue).
Корректна (sift-up/sift-down). Замечание: `pop()` при пустой куче не гвардится —
вызывающие проверяют `is_empty()`, но стоит добавить guard для robustness.

### 3.3 RNG / детерминизм
Политика в `TurnContext` (сид от `(turn, uid)` при `rng == null`) + `GameSession`
(единый `run_seed`) — сильное решение для воспроизводимости. Тесты подтверждают
(одинаковый `run_seed` → одинаковые результаты).

---

## 4. Refactoring (конкретные_fix_ с before/after и приоритетом)

| # | Приоритет | Объект | Что | Эффект |
|---|-----------|--------|-----|--------|
| R1 | **High** | `WorldController` | Вынести succession/death/resurrection/chronicle → `HeroLifecycleSystem` | 602→~380 строк; единая ответственность; тестируемость |
| R2 | **High** | `SocketController` | Таблица команд + эмуляторы (`BattleEmulator`, `CityStateSerializer`) | 899→модули; слабая связность |
| R3 | Medium | `WorldController` | Типизировать 7 `Variant`-полей preload-ами | compile-time safety |
| R4 | Medium | `ServiceContainer.current` | Инвентаризация → DI, fallback `@deprecated` | единый путь сервисов |
| R5 | Medium | `HexUtils` | Единый `find_path()` dispatch | убрать дup реконструкции |
| R6 | Low | `SocketController` | Резолвет порта (`--socket-server`), ретрай | чистая консоль |
| R7 | Low | `HexUtils.MinHeap` | Guard пустой кучи в `pop()` | robustness |
| R8 | Low | `HexUtils.ring` | (не обязательно) O(r) генерация | перф. (низкий приоритет) |

### R1 — детали (пример)
**Before:** `WorldController._install_hero` переподключает 8+ потребителей вручную.
**After:**
```gdscript
# HeroLifecycleSystem
func _install_hero(hero: HeroController) -> void:
	for consumer in _consumers:
		consumer.on_hero_changed(_hero, hero)
	_hero = hero
```
Герои-потребители (`BattleController`, `InteractionController`, …) реализуют
`IHeroConsumer`, регистрируются в `_consumers`. `WorldController` об этом не знает.

---

## 5. Local-Agent Implementation Instructions

### Step 0. Разрешить вопросы (до кода)
- R1: `HeroLifecycleSystem` — один класс или фасад над `SuccessionController`+`DeathSequence`?
  (предложение: единый класс, держащий рефы на существующие `SuccessionController`/`DeathSequence`.)
- R2: эмуляторы — новые классы или вынесенные методы в `BattleEmulator`?

### Step 1. R1 — extraction (высокий приоритет)
1. Создать `game/scripts/world/HeroLifecycleSystem.gd` (RefCounted).
2. Перенести `_on_hero_died`, `_plan_succession`, `_execute_succession`,
   `_find_resurrection_city`, `_on_resurrection_chosen`, `_free_deceased`,
   `_detach_hero`, `_remove_hero`, `_reincarnate`, `_append_succession_entry`,
   `_on_death_chronicle_requested`, `_on_death_return_to_menu`, `_run_summary`,
   `_show_death_sequence`.
3. Ввести `IHeroConsumer` (`func on_hero_changed(old, new)`); переподключение героя
   через consumers.
4. В `WorldController` заменить тела на делегацию `_hero_lifecycle.*`.
5. Типизировать поля (`var _hero_lifecycle: HeroLifecycleSystem`).

### Step 2. R3 — типизация полей `WorldController`
Замкнуть 7 `Variant`-полей на preload-классы (`WorldPersistence`, `VisibilityMap`, …).

### Step 3. R2 — декомпозиция `SocketController`
1. Ввести `_COMMANDS: Dictionary<StringName, Callable>`; `_route_command` — lookup.
2. Вынести `_run_auto_battle`/`_emulate_battle` → `BattleEmulator.gd`.
3. Вынести `_city_state_dict`/`_resolve_city` → `CityStateSerializer.gd`.
4. `_get_state`/`_move_to`/`_end_turn` → `WorldStateSerializer.gd`.

### Step 4. R6 — резолвет порта `SocketController`
Старт только по `--socket-server`; без флага — не слушать (без ошибки в консоли).

### Step 5. R4/R5/R7 — medium/low
Инвентаризация `ServiceContainer.current`; единый `find_path()`; guard `MinHeap.pop()`.

### Verification
```bash
# 1. Компиляция всех сцен/скриптов
Godot --headless --path game -s game/tools/compile_all.gd
# 2. Юнит-тесты (фильтр по имени файла при необходимости)
Godot --headless --path game -s tests/run_tests.gd
# 3. Оперативность (headless, фоновый запуск + опрос ~15-20 мин)
nohup bash game/tools/shell/run_operability.sh > /tmp/op_run.log 2>&1 &
# 4. Проверка чистоты консоли (без учёта пре-existing SocketServer listen error)
bash game/tools/shell/check_console_clean.sh
```

### Acceptance Criteria
- `WorldController` ≤ 400 строк, ни одного метода из списка R1 (только делегация).
- `HeroLifecycleSystem` тестируется изолированно (новый `test_hero_lifecycle.gd`).
- `_install_hero`/переподключение через `IHeroConsumer` — ни одной жёсткой ссылки
  на 8+ потребителей.
- `SocketController` роутит команды через `_COMMANDS`; эмуляторы — отдельные классы.
- Запуск без `--socket-server` не печатает `Failed to listen`.
- `run_operability.sh` → CLEAN; 1010 тестов — зелёные; без новых `SCRIPT ERROR`.
