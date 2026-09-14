# Аудит проекта: Sigil of the Unwilling (Godot 4.7)

---

## 1. Архитектура

### 1.1. Модульность и разделение ответственности

| Аспект | Оценка | Комментарий |
|---|---|---|
| Слои данных/логики/представления | **Хорошо** | `scripts/data/`, `scripts/systems/`, `scripts/ui/`, `scripts/world/` — чёткое разделение |
| Автозагрузки (автолоады) | **Хорошо** | Реестры (`ArtifactRegistry`, `SpellRegistry`, `ResourceRegistry`) вынесены в синглтоны |
| Сервисный локатор | **Хорошо** | `ServiceRegistry` + `Services` заменяют прямые зависимости |
| Событийная шина | **Хорошо** | `GameEventBus` — единый канал сигналов |
| Городские подпроцессоры | **Отлично** | `CityTurnProcessor` оркестрирует 10 саб-процессоров (паттерн «Стратегия» + «Компоновщик») |
| Герой-контроллер | **Отлично** | Компонентная архитектура: 14 компонентов (`HeroMovementComponent`, `HeroMagicComponent`, …) |
| MCP-сервер | **Удовл.** | `McpCommandsBase` → 5 групп команд; но `_cmd_eval` в `McpCommandsSystem` — нарушение SRP |

**Ключевые паттерны в проекте:**

```
Component       — HeroController (14 компонентов)
Strategy        — CitySubProcessor → 10 реализаций
Observer        — GameEventBus, сигналы
Builder         — BattleStateBuilder
State Machine   — BattleTurnExecutor (enum State)
Service Locator — ServiceRegistry + Services.resolve()
Template Method — TurnPhaseProcessor.get_phase_id() / process()
Flyweight       — UnitStats, ArtifactRegistry (переиспользование определений)
```

### 1.2. Проблемы связности

| Проблема | Файл | Серьёзность |
|---|---|---|
| `WorldController` знает о 10+ подсистемах | `WorldController.gd` | Medium |
| `WorldBootstrap.run()` — 80+ строк, создаёт всё | `WorldBootstrap.gd` | Medium |
| `McpCommandsSystem._cmd_eval` исполняет произвольный GDScript | `mcp_commands_system.gd` | **High** |
| `BattleController` одновременно управляет вводом, визуалом, исполнителем | `BattleController.gd` | Medium |
| `GameNumbers` — мега-фасад из 200+ констант | `GameNumbers.gd` | Low (уже мигрируют) |

### 1.3. Масштабируемость

**Сильные стороны:**
- `TurnScheduler` + `TurnPhaseProcessor` — добавление фазы = новый класс + `register_processor()`
- `TemplateEngine` + `TemplateBootstrap` — новый шаблон заклинания = одна функция `handle()`
- `CitySubProcessor` — новая механика города = один файл в `processors/`

**Слабые стороны:**
- `HeroController._register_components()` — ручная регистрация; нет реестра/автоматического обнаружения
- `BuildingDefs` — определения зданий в JSON (`assets/data/buildings.json`), но `def_by_id()` пересоздаёт `Def` при каждом вызове (нет кэша)

---

## 2. Лучшие практики

### 2.1. Идиомы Godot / GDScript

| Практика | Статус | Пример |
|---|---|---|
| Типизация (`:=`, `-> Type`) | ✅ Повсеместно | `var x: float = 3.0` |
| `class_name` для глобальных классов | ✅ | `class_name BattleState` |
| Сигналы вместо поллинга | ✅ | `GameEventBus`, `city_scale_changed` |
| `@onready` для ссылок на сцену | ✅ | `@onready var _terrain: TileMapLayer = $Terrain` |
| `auto_free` в тестах | ✅ | `var x = auto_free(Node.new())` |
| `process_mode = PROCESS_MODE_ALWAYS` для MCP | ✅ | `mcp_interaction_server.gd:47` |
| Избегание `get_node()` в горячих путях | ⚠️ Частично | `BattleUI` хранит `@onready`-ссылки |

### 2.2. SOLID / DRY / KISS / YAGNI

| Принцип | Нарушение | Файл | Приоритет |
|---|---|---|---|
| **SRP** | `_cmd_eval` в `McpCommandsSystem` — и блокировка паттернов, и компиляция, и исполнение | `mcp_commands_system.gd` | High |
| **SRP** | `WorldBootstrap.run()` создаёт и карту, героя, камеры, спавнеры, города, подсистемы | `WorldBootstrap.gd` | Medium |
| **DRY** | `_find_by_class_recursive()` дублируется в `McpCommandsBase` и используется только в `McpCommandsRender`/`McpCommandsSystem` | `mcp_commands_base.gd` | Low |
| **DRY** | Повторяющийся паттерн `assert_bool(…).is_true().override_failure_message(…)` в тестах | `test_battle_ai.gd` | Low |
| **KISS** | `HexPathfinding` содержит 6 функций (bfs, astar, dijkstra × 3, dijkstra_path) — можно упростить до 3 | `HexPathfinding.gd` | Medium |
| **YAGNI** | `McpCommandsNetwork` — пустой класс-заглушка | `mcp_commands_network.gd` | Low |

### 2.3. Безопасность и обработка ошибок

**Критические проблемы:**

```gdscript
# mcp_commands_system.gd — EVAL_BLOCKED_PATTERNS легко обойти
const EVAL_BLOCKED_PATTERNS: Array[String] = [
    "OS.execute", "OS.shell_open", "FileAccess.open", …
]
# Обход: String("OS") + ".execute" или call-через-метод
```

| Уязвимость | Риск | Рекомендация |
|---|---|---|
| `_cmd_eval` исполняет произвольный код | **Критический** | Убрать `eval` из продакшн-сборки; оставить только в `DEBUG` |
| `_is_allowed_scene_path` проверяет только префикс | Высокий | Добавить валидацию через `ResourceLoader.exists()` |
| `_cmd_script` (`attach`) позволяет подменить скрипт ноды | Высокий | Ограничить список допустимых нод |
| Нет таймаута для `await` в MCP-командах | Средний | `BUSY_TIMEOUT` уже есть (120 с), но `await handler.call(params)` может зависнуть |
| `_cmd_await_signal` — бесконечный цикл без защиты от `tree == null` | Средний | Добавить `max_iterations` |

### 2.4. Читаемость и нейминг

**Хорошие примеры:**
- `ArenaRingSystem.ring_of()`, `ArenaStorm.is_storm_turn()` — самодокументируемые
- Комментарии на русском в `HeroController` описывают инварианты
- `GameLogger` с тегами и цветами

**Замечания:**

| Проблема | Пример | Рекомендация |
|---|---|---|
| `_` в `test_map_model.gd` | `assert_that(a.terrain_grid == b.terrain_grid).is_true()` | Использовать `assert_bool()` |
| Магические числа в `BattleStateBuilder` | `col_step := 1 if is_atk else -1` | Вынести в `const DEPLOY_COL_STEP` |
| Смешение английского/русского в логах | `GameLogger.world("Enemy defeated at %s")` vs `push_error("Не удалось…")` | Единый язык для логов |

---

## 3. Алгоритмы и структуры данных

### 3.1. Обнаруженные алгоритмы

| Алгоритм | Файл | Сложность | Корректность |
|---|---|---|---|
| **A* поиск пути** | `HexPathfinding.astar_path()` | O(V log V) | ✅ Корректен, но `came_from` — `PackedInt32Array` (экономия памяти) |
| **BFS достижимости** | `HexPathfinding.bfs_reachable()` | O(V + E) | ✅ |
| **Dijkstra** | `HexPathfinding.dijkstra()` | O(V log V) | ✅ с `MinHeap` |
| **BFS обход дерева** | `McpCommandsBase._find_by_class_recursive()` | O(V) | ✅ Итеративный (нет переполнения стека) |
| **Кластеризация зданий** | `ArenaClusterSystem._compute_clusters()` | O(V + E) | ✅ DFS по соседним клеткам |
| **Генерация карты шумом** | `MapModel.generate_noise()` | O(W × H) | ✅ 3 слоя `FastNoiseLite` |
| **Сортировка инициативы** | `BattleState.build_queue()` | O(n log n) | ✅ |
| **Минимальная куча** | `MinHeap` | O(log n) на операцию | ✅ |
| **Хеширование координат** | `HexUtils.pos_to_idx()` | O(1) | ✅ `y * w + x` |

### 3.2. Проблемы производительности

| Проблема | Файл | Влияние | Рекомендация |
|---|---|---|---|
| `_find_by_class_recursive` в MCP: полный обход дерева на каждый запрос | `mcp_commands_base.gd` | Низкое (отладка) | Кэш по `class_filter` + версия дерева |
| `BuildingDefs.def_by_id()` пересоздаёт `Def` из JSON при каждом вызове | `BuildingDefs.gd` | Среднее | Кэшировать в `static var _cache` |
| `_terrain_rebuild()` пересоздаёт меш целиком при изменении одной клетки | `mcp_commands_system.gd` | Низкое (только в MCP) | Частичное обновление |
| `EconomicTurnProcessor._process_city()` — O(buildings × chains) | `EconomicTurnProcessor.gd` | Среднее при 100+ зданий | Индексация по `chain_id` |
| `VisibilityMap.recompute()` пересчитывает весь `visible` каждый ход | `VisibilityMap.gd` | Среднее | Инкрементальный пересчёт |

### 3.3. Граничные случаи

| Алгоритм | Граничный случай | Статус |
|---|---|---|
| `astar_path` | `start == goal` | ✅ Возвращает `[start]` |
| `astar_path` | Нет пути | ✅ Возвращает `[]` |
| `bfs_reachable` | `steps == 0` | ✅ Возвращает `{}` (исключает `start`) |
| `dijkstra` | `max_cost == 0` | ⚠️ Может вернуть только `start`; нет явной проверки |
| `ArenaClusterSystem.clusters` | `city == null` | ✅ Возвращает `[]` |
| `CityGrowthService.growth_threshold` | `pop_capped() == 0` | ✅ `maxi(1, …)` |
| `MarketSystem.trade` | `amount < MARKET_MIN_AMOUNT` | ✅ Проверка есть |
| `RaidSystem.raid_strength` | Диапазон `5..15` | ✅ `min + absi(h) % span` |

### 3.4. Рекомендуемые альтернативы

| Текущее | Альтернатива | Выигрыш |
|---|---|---|
| `MinHeap` (ручная реализация) | `AStar2D`/`AStar3D` из Godot для тайловых карт | Встроенная оптимизация |
| `_find_by_class_recursive` (полный обход) | `SceneTree.get_nodes_in_group()` + группы | O(1) для часто запрашиваемых типов |
| `Dictionary` для `blocked` клеток | `BitArray` / `PackedByteArray` размером `w*h` | Меньше аллокаций, быстрее `has()` |
| `HeroMovementController._terrain_cost()` — вызов каждый шаг | Предвычисленная таблица стоимости для всей карты | Убрать повторные вызовы `get_terrain_id()` |

---

## 4. Рефакторинг

### 4.1. Приоритет: **High**

#### H1. Убрать `eval` из продакшн-сборки

**Что:** `_cmd_eval` позволяет выполнять произвольный GDScript. В продакшене это критическая уязвимость.

**До:**
```gdscript
# mcp_commands_system.gd
func get_commands() -> Dictionary:
    return {
        "eval": _cmd_eval,
        ...
    }
```

**После:**
```gdscript
# mcp_commands_system.gd
func get_commands() -> Dictionary:
    var commands := {
        "get_scene_tree": _cmd_get_scene_tree,
        ...
    }
    if OS.is_debug_build():
        commands["eval"] = _cmd_eval
        commands["script"] = _cmd_script
    return commands
```

**Зачем:** Исключить возможность удалённого исполнения кода в продакшене.

---

#### H2. Кэшировать `BuildingDefs.def_by_id()`

**Что:** Каждый вызов `def_by_id()` пересоздаёт `UniqueBuilding.Def` из JSON.

**До:**
```gdscript
# BuildingDefs.gd
static func def_by_id(id: StringName) -> UniqueBuilding.Def:
    _ensure_loaded()
    for raw in _raw_cache:
        if raw is Dictionary and String(raw.get("id", "")) == String(id):
            return _build_def(raw)   # ← создаёт новый объект каждый раз
    return null
```

**После:**
```gdscript
# BuildingDefs.gd
static var _def_cache: Dictionary = {}

static func def_by_id(id: StringName) -> UniqueBuilding.Def:
    _ensure_loaded()
    if _def_cache.has(id):
        return _def_cache[id]
    for raw in _raw_cache:
        if raw is Dictionary and String(raw.get("id", "")) == String(id):
            var def := _build_def(raw)
            _def_cache[id] = def
            return def
    return null

static func reset_cache() -> void:
    _def_cache.clear()
    _raw_cache.clear()
```

**Зачем:** Убрать O(n) пересоздание объектов при каждом запросе (вызывается в `ArenaTurnRunner`, `CityBuildingService`, тестах).

---

#### H3. Защитить `_cmd_await_signal` от бесконечного цикла

**Что:** `while not result[0] and timer.time_left > 0` может крутиться вечно, если `process_frame` не наступает (пауза без `PROCESS_MODE_ALWAYS`).

**До:**
```gdscript
func _cmd_await_signal(params: Dictionary) -> void:
    ...
    while not result[0] and timer.time_left > 0:
        await server.get_tree().process_frame
```

**После:**
```gdscript
func _cmd_await_signal(params: Dictionary) -> void:
    ...
    var max_frames := 10_000
    var frames := 0
    while not result[0] and timer.time_left > 0:
        await server.get_tree().process_frame
        frames += 1
        if frames >= max_frames:
            break
```

---

### 4.2. Приоритет: **Medium**

#### M1. Разделить `WorldBootstrap.run()` на фазы

**Что:** `run()` — 80 строк, создаёт 8 объектов. Разбить на подфункции.

**До:**
```gdscript
static func run(parent, platform, rng, shard_seed, ui_manager) -> BootstrapResult:
    var R := BootstrapResult.new()
    # 80 строк создания объектов
    return R
```

**После:**
```gdscript
static func run(parent, platform, rng, shard_seed, ui_manager) -> BootstrapResult:
    var R := BootstrapResult.new()
    R.rng = rng
    R.ui_manager = ui_manager
    _init_services(parent, R)
    R.loaded_save = _resolve_session(R, shard_seed)
    _create_world(parent, R)          # карта, герой, камера, ввод, спавнер
    _create_city_layer(parent, R)     # города, ресурсы
    _create_battle_layer(parent, R)   # координатор боя
    _create_endgame(parent, R)
    return R
```

#### M2. Заменить `Dictionary` для блокированных клеток на `PackedByteArray`

**Что:** `blocked: Dictionary` используется в `HexPathfinding` для проверки `has()`. `Dictionary.has()` — O(1), но с большим оверхедом на хэширование `Vector2i`.

**До:**
```gdscript
var blocked: Dictionary = {}
blocked[Vector2i(5, 5)] = true
if blocked.has(cell): ...
```

**После:**
```gdscript
var blocked := PackedByteArray()
blocked.resize(w * h)
blocked[HexUtils.pos_to_idx(cell, w)] = 1
if blocked[HexUtils.pos_to_idx(cell, w)] == 1: ...
```

**Зачем:** В `dijkstra`/`astar` вызывается ~10⁵ раз; экономия на аллокациях хэш-таблицы.

#### M3. Извлечь валидацию параметров в `McpCommandsBase`

**Что:** Каждая команда повторяет паттерн `if not _require_scene_tree(): return`.

**До:**
```gdscript
func _cmd_click(params: Dictionary) -> void:
    if not _require_scene_tree():
        return
    ...
```

**После:**
```gdscript
# В McpCommandsBase
func execute(command: String, params: Dictionary) -> Variant:
    var handler: Callable = get_commands().get(command, Callable())
    if not handler.is_valid():
        return {"error": "Unknown command: %s" % command}
    if not _require_scene_tree():
        return {"error": "Server not in scene tree"}
    return await handler.call(params)
```

#### M4. Убрать дублирование в `ArenaClusterSystem.clusters()`

**Что:** `cluster_uids()` и `cluster_worker_housing()` каждый раз вызывают `clusters()`, который проверяет кэш. Но `_city_version()` инкрементируется только в `bump_version()`.

**До:**
```gdscript
static func cluster_uids(city: City) -> Dictionary:
    ...
    for cl in clusters(city):  # ← каждый раз полный пересчёт при изменении
```

**После:** Уже кэшируется через `city.set_meta(&"arena_clusters_cache", …)` — **OK**, но добавить инвалидацию при `remove_building`:
```gdscript
# В City.build_building / City.remove_building
ArenaClusterSystem.bump_version(self)
```

#### M5. Типизировать `Variant` в `EconomicTurnProcessor`

**Что:** `var auto: Dictionary = city_report.get("auto", {})` — `Variant` без проверки.

**До:**
```gdscript
var auto: Dictionary = city_report.get("auto", {})
```

**После:**
```gdscript
var auto_raw: Variant = city_report.get("auto", {})
var auto: Dictionary = auto_raw if auto_raw is Dictionary else {}
```

---

### 4.3. Приоритет: **Low**

| # | Что | Где | Действие |
|---|---|---|---|
| L1 | Пустой `McpCommandsNetwork` | `mcp_commands_network.gd` | Удалить файл и регистрацию в `mcp_interaction_server.gd` |
| L2 | `_leading_ws_len` можно заменить на `line.length() - line.lstrip(" \t").length()` | `mcp_commands_system.gd` | Убрать функцию |
| L3 | `GameNumbers` — мега-фасад | `GameNumbers.gd` | Уже мигрируют в `GameNumbersBattle`/`City`/`Hero`/`Map`; завершить миграцию |
| L4 | Тесты используют `auto_free` для каждого `Node` | `test_*.gd` | Создать `BaseTest.make_node()` — уже есть |
| L5 | `_HexDraw.points()` создаёт `PackedVector2Array` каждый вызов | `HexDraw.gd` | Кэшировать для фиксированных радиусов |

---

## 5. Инструкция для локального агента

### 5.1. Пошаговый план

```
Фаза 1 — Безопасность (1 день)
├── Шаг 1.1: Ограничить _cmd_eval только для debug-сборки
│   Файл: game/mcp_commands_system.gd
│   Блок: get_commands()
│   Критерий: в релизной сборке команда "eval" не зарегистрирована
│   Тест: запуск тестов без --debug → eval возвращает "Unknown command"
│
├── Шаг 1.2: Добавить лимит итераций в _cmd_await_signal
│   Файл: game/mcp_commands_system.gd
│   Блок: _cmd_await_signal()
│   Критерий: после 10 000 кадров цикл прерывается
│
└── Шаг 1.3: Валидация сцен в _is_allowed_scene_path
    Файл: game/mcp_commands_system.gd
    Блок: _is_allowed_scene_path()
    Добавить: ResourceLoader.exists(path)
    Тест: test_scene_path_whitelist (уже существует)

Фаза 2 — Производительность (2 дня)
├── Шаг 2.1: Кэшировать BuildingDefs.def_by_id()
│   Файл: game/scripts/data/BuildingDefs.gd
│   Критерий: повторный вызов возвращает тот же объект (===)
│   Тест: добавить в test_city_building_service.gd
│
├── Шаг 2.2: Заменить Dictionary blocked на PackedByteArray в HexPathfinding
│   Файл: game/scripts/core/HexPathfinding.gd
│   Затрагивает: astar_path, bfs_path, bfs_reachable, dijkstra*
│   Бенчмарк: test_astar_pathfinding_performance (уже есть)
│   Критерий: время не увеличилось, результаты идентичны
│
└── Шаг 2.3: Инкрементальный пересчёт VisibilityMap
    Файл: game/scripts/core/VisibilityMap.gd
    Блок: recompute()
    Критерий: при перемещении героя на 1 клетку пересчитывается
    только дельта, а не вся карта

Фаза 3 — Рефакторинг архитектуры (2 дня)
├── Шаг 3.1: Разбить WorldBootstrap.run() на 5 подфункций
│   Файл: game/scripts/world/WorldBootstrap.gd
│   Критерий: run() ≤ 20 строк, подфункции приватные
│
├── Шаг 3.2: Вынести валидацию сцены из каждой команды в execute()
│   Файл: game/mcp_commands_base.gd
│   Затрагивает: все _cmd_* в 5 группах команд
│   Критерий: из каждого _cmd_* убрана строка _require_scene_tree()
│
└── Шаг 3.3: Удалить пустой McpCommandsNetwork
    Файлы: mcp_commands_network.gd, mcp_interaction_server.gd
    Критерий: файл удалён, регистрация убрана, тесты проходят

Фаза 4 — Тестирование (1 день)
├── Шаг 4.1: Запустить полный набор тестов
│   Команда:
│   $ godot --headless --script tests/run_all.gd
│   Ожидаемый результат: 0 ошибок, 0 предупреждений
│
├── Шаг 4.2: Запустить MCP-интеграционные тесты
│   Команда:
│   $ cd tests/mcp && python -m pytest -xvs
│   Ожидаемый результат: все тесты зелёные
│
└── Шаг 4.3: Бенчмарки производительности
    Команда:
    $ godot --headless --script tests/functional/test_benchmarks.gd
    Критерий: все бенчмарки ≤ порогов из тестов
```

### 5.2. Команды проверки

```bash
# Все модульные тесты
godot --headless --path game -s res://tests/run_all.gd

# Конкретный файл тестов
godot --headless --path game -s res://tests/unit/systems/test_battle_rules.gd

# MCP-тесты (нужен Python + mcp)
cd game/tests/mcp
python -m pytest test_battle_full_e2e.py -xvs

# Бенчмарки
godot --headless --path game -s res://tests/functional/test_benchmarks.gd

# Проверка синтаксиса (без запуска)
godot --headless --path game --check-only --script res://scripts/systems/BattleState.gd
```

### 5.3. Критерии приёмки

| Критерий | Метрика |
|---|---|
| Все тесты проходят | `0 failed, 0 errors` |
| `eval` недоступен в релизе | Команда возвращает `{"error": "Unknown command: eval"}` |
| `BuildingDefs.def_by_id()` кэшируется | `def_by_id(x) === def_by_id(x)` возвращает `true` |
| A* не замедлился | Бенчмарк `test_astar_pathfinding_performance` ≤ 200 мс |
| `WorldBootstrap.run()` ≤ 20 строк | Ручная проверка |
| Нет пустых классов-заглушек | `McpCommandsNetwork` удалён |
| Покрытие тестами новых функций | ≥ 80% для изменённых файлов |

### 5.4. Риски при внедрении

| Риск | Вероятность | Митигация |
|---|---|---|
| `BuildingDefs` кэш ломает сериализацию | Низкая | Тест `test_building_defs_cache_serialization` |
| `PackedByteArray` вместо `Dictionary` меняет порядок обхода | Средняя | Не обходить `blocked` — только `has()` |
| Удаление `eval` ломает MCP-тесты | Высокая | Оставить `eval` при `OS.is_debug_build()` |
| Разбиение `WorldBootstrap` меняет порядок инициализации | Средняя | Сохранить порядок: сервисы → сессия → карта → герой → города |

---

## Итоговая оценка

| Направление | Оценка | Примечание |
|---|---|---|
| Архитектура | **8/10** | Чистое разделение на слои; компонентный герой; шаблонизатор заклинаний |
| Лучшие практики | **7/10** | Типизация, сигналы, тесты; но `eval` в продакшене и дубли в `BuildingDefs` |
| Алгоритмы | **8/10** | Корректные A*/BFS/Dijkstra; граничные случаи обработаны |
| Производительность | **7/10** | Есть кэш кластеров, но `BuildingDefs` и `VisibilityMap` требуют оптимизации |
| Тестовое покрытие | **9/10** | 200+ тестов, включая MCP-интеграцию и бенчмарки |
| Безопасность | **5/10** | `eval` с чёрным списком паттернов — критическая уязвимость |

**Главный приоритет:** убрать `eval` из продакшен-сборки и кэшировать `BuildingDefs`. Остальное — планомерная оптимизация.