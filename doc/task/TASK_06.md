# Аудит кодовой базы: Sigil of the Unwilling (Godot 4.7)

---

## 1. Архитектура

### 1.1 Модульность и разделение ответственности

| Компонент | Проблема | Серьёзность |
|---|---|---|
| `BattleState` (~450 строк) | Совмещает состояние боя, размещение армий, управление очередью, кэш достижимости, сетку юнитов, проверку конца боя | **High** |
| `HeroController` (~350 строк) | Агрегирует 8 подсистем (movement, army, resources, magic, skills, tools, time, strategic_resources) — допустимо как Facade, но содержит бизнес-логику `_apply_daily_resource_effects`, `_tick_needs` | **Medium** |
| `WorldBootstrap.run()` (~120 строк) | Статический метод-фабрика, создающий и связывающий ~15 объектов. Трудно тестировать и расширять | **High** |
| `ArenaClusterSystem` | Статический глобальный кэш `_cache: Dictionary` — скрытое глобальное состояние, нарушение инкапсуляции | **High** |
| `City` (~500 строк) | Хранит данные + делегирует в `CityBuildingService`, `CityGrowthService`, `CitySerializer` — рефакторинг R3 выполнен хорошо, но `City` всё ещё содержит `_exploited_cache`, `_yield_cache` | **Medium** |

**Хорошие решения:**
- Паттерн **Strategy** для потребностей (`NeedStrategy` → `RestStrategy`, `SocialStrategy`, `InspirationStrategy`).
- Паттерн **Processor/Pipeline** для ходов (`TurnPhaseProcessor` → `TurnScheduler`).
- `BattleSpellBridge` + `TemplateEngine` + 19 обработчиков шаблонов заклинаний — чистая стратегия.
- `CityBuildingService` / `CityGrowthService` / `CitySerializer` — статические сервисы, вынесенные из `City`.

### 1.2 Связность и связанность

```
WorldController
  ├── WorldBootstrap (статическая фабрика)
  ├── WorldEventRouter (маршрутизация сигналов)
  ├── HeroLifecycleSystem (жизненный цикл героя)
  ├── BattleFlow → BattleController → BattleTurnExecutor
  ├── CityManager → City → CityBuildingService
  ├── WorldBattleCoordinator
  └── EndgameController
```

**Проблемы связанности:**
- `WorldBootstrap.run()` знает о **всех** подсистемах — нарушение **Dependency Inversion**.
- `ServiceLocator` с `_AUTOLOAD` словарём и `_cache` — сервис-локатор вместо DI, допустимо для Godot, но кэш не инвалидируется при смене сцены без явного `clear_cache()`.
- `ArenaClusterSystem._cache` — статический `Dictionary`, привязанный к `city.uid`, но `uid` не уникален между сессиями (см. тест `test_session_reset_caches`).

### 1.3 Соответствие паттернам

| Паттерн | Где применён | Оценка |
|---|---|---|
| Strategy | `NeedStrategy`, `TemplateEngine` handlers | ✅ Хорошо |
| Observer (signals) | `GameEventBus`, все `signal` в узлах | ✅ Идиоматично для Godot |
| Facade | `HeroController`, `CityArenaModel` | ✅ Хорошо |
| Service Locator | `ServiceLocator.resolve()` | ⚠️ Приемлемо, но без DI |
| Singleton (static) | `ArenaClusterSystem._cache`, `TileAtlas` | ❌ Хрупко |
| Template Method | `TurnPhaseProcessor.process()` | ✅ Хорошо |
| Builder | Отсутствует для сложных объектов (`BattleState.place_army` inline) | ⚠️ |

---

## 2. Лучшие практики

### 2.1 Идиомы Godot 4.7

| Проблема | Файл | Пример | Рекомендация |
|---|---|---|---|
| `@onready` в `RefCounted`-классах | `BattleUI.gd` (`extends CanvasLayer` — ок), но `ResourceCollectPopup` использует computed property `get_node()` в `get:` | `_image: TextureRect: get: return get_node(...)` | Допустимо для Control, но создаёт скрытую зависимость от дерева. Лучше `@onready`. |
| `queue_free()` + обращение после | `BattleView.remove_unit()` | `tw.tween_callback(node.queue_free)` | ✅ Корректно, но нет `_kill_unit_tweens` до `queue_free` в `flash_unit`. |
| Статические `var` в GDScript | `ArenaClusterSystem._cache`, `ServiceLocator._cache`, `PlaceholderTexture._cache` | `static var _cache: Dictionary = {}` | Работает, но не сериализуется и не сбрасывается при смене сцены. |
| `class_name` + `preload` одновременно | `BattleActionResolver.gd`: `const ServiceLocator = preload(...)` при наличии `class_name ServiceLocator` | Двойная загрузка | Использовать только `class_name`. |

### 2.2 SOLID

| Принцип | Нарушение | Пример |
|---|---|---|
| **S**RP | `BattleState` — 6+ ответственностей | Состояние, размещение, очередь, кэш, сетка, конец боя |
| **O**CP | `BattleTurnExecutor._on_action_completed` — цепочка `if/elif` для `morale`, `retreat`, `advance` | Добавление нового типа действия требует правки метода |
| **L**SP | `TurnPhaseProcessor.process()` возвращает `Dictionary` без контракта | Каждый процессор возвращает разную структуру |
| **I**SP | `WorldUIManager.setup()` принимает 5 аргументов | Часть не нужна для минимальной инициализации |
| **D**IP | `WorldBootstrap.run()` инстанцирует конкретные классы | Невозможно подменить реализации без правки фабрики |

### 2.3 DRY

- **`_TerrainCostTable.get_cost_with_effects`** и **`get_cost_with_effects_by_id`** — дублирование логики.
- **`BattleRules.calculate_attack`** и **`BattleRules.preview_text`** — повторяющийся расчёт `min_base/max_base/multiplier`. Вынести в `_compute_damage_range()`.
- **`_cells_to_array` / `_array_to_cells`** в `WorldStateDelta` — можно обобщить.

### 2.4 Обработка ошибок

| Проблема | Где | Риск |
|---|---|---|
| `assert` вместо graceful fallback | `BattleState._build_units`: `push_error` но `continue` | Юнит молча не размещается, бой может зависнуть |
| `null`-проверки через `if x == null: return {}` | `BattleActionResolver.apply_attack` | Пустой `Dictionary` неотличим от «нет урона» |
| `FileAccess.open` без проверки `null` | `SpellbookRegistry._load_from_json` | Краш при отсутствии файла |
| `JSON.parse_string` без валидации типа | `BuildingDefs._ensure_loaded` | `data is Array` проверяется, но элементы — нет |

### 2.5 Naming

В целом **хорошо**: `snake_case` для методов, `PascalCase` для классов, `UPPER_SNAKE` для констант. Замечания:
- `_i100`, `_i50`, `_i30` в `HexMapGenerator` — нечитаемые имена для индексных карт.
- `_rr` в `SoundManager` — round-robin counter, лучше `_round_robin_index`.
- `_t` в `StatusOrb`, `DestMarker` — время, лучше `_elapsed`.

---

## 3. Алгоритмы

### 3.1 Обзор используемых алгоритмов

| Алгоритм | Файл | Сложность | Оценка |
|---|---|---|---|
| A* (hex grid) | `HexPathfinding.astar_path` | O(V log V) | ✅ Корректен, но `PackedFloat32Array` + `INF` вместо `Dictionary` — экономия памяти, но риск `INF`-арифметики |
| BFS (кратчайший путь) | `HexPathfinding.bfs_path` | O(V + E) | ✅ Корректен |
| BFS достижимость | `HexPathfinding.bfs_reachable` | O(V + E) | ✅ Корректен |
| Dijkstra | `HexPathfinding.dijkstra` | O(V log V) | ✅ Корректен, `MinHeap` самописный |
| MinHeap | `MinHeap.gd` | O(log n) push/pop | ⚠️ Нет `decrease_key`, дубли в очереди допустимы |
| Кластеризация (flood fill) | `ArenaClusterSystem._compute_clusters` | O(B) где B = здания | ✅ Корректен |
| Детерминированный хэш для особенностей | `ArenaRingSystem.cell_feature` | O(1) | ⚠️ `hash()` не криптографический, но для игры допустимо |
| Генерация карты (Simplex noise) | `MapModel.generate_noise` | O(W×H) | ✅ |

### 3.2 Граничные случаи

| Алгоритм | Граничный случай | Статус |
|---|---|---|
| `astar_path` | `start == goal` | ✅ Возвращает `[start]` |
| `bfs_path` | Цель недостижима | ✅ Возвращает `[]` |
| `dijkstra` | `cost_fn` возвращает `INF` | ✅ Пропускает |
| `dijkstra_path` | `dist[goal_idx] == INF` | ✅ Возвращает `[]` |
| `MinHeap.pop` | Пустая куча | ✅ Возвращает `[]` |
| `_compute_clusters` | Город без зданий | ✅ Возвращает `[]` |
| `bfs_reachable` | `steps == 0` | ✅ Возвращает `{}` (старт удалён) |
| `HexUtils.hex_distance` | Отрицательные координаты | ✅ `offset_to_cube` корректен |

### 3.3 Проблемы производительности

**P1: `BattleState._reachable_cache` инвалидируется глобально**
```gdscript
func invalidate_board_cache() -> void:
    _board_version += 1
    _reachable_cache.clear()  # O(1) по ссылке, но пересчёт O(V)
```
Любой ход/атака очищает **весь** кэш. Для 17×11 поля это ~187 клеток × скорость юнита. Допустимо для текущего размера, но не масштабируется.

**P2: `EnemyTurnProcessor._dist_field` кэширует по `Vector3i(cell.x, cell.y, int(mp * 1000.0))`**
```gdscript
var key := Vector3i(cell.x, cell.y, int(mp * 1000.0))
```
Корректно, но `int(mp * 1000.0)` может терять точность для `mp = 5.0005`. Лучше хранить как `int(round(mp * 1000.0))`.

**P3: `HexUtils.get_neighbor` вызывается в горячем цикле A*/BFS**
Оптимизация с `_shift_right: bool` уже применена (кэширование флага калибровки). Это корректно.

### 3.4 Альтернативы

| Текущее | Альтернатива | Выигрыш |
|---|---|---|
| Самописный `MinHeap` | `AStar2D` / `AStarGrid2D` из Godot | Встроенная оптимизация, но потеря контроля над эвристикой |
| `PackedFloat32Array` для Dijkstra | `Dictionary` для разреженных графов | Экономия памяти на больших картах |
| Полный перебор `ring()` в `HexUtils.ring` | Кубические координаты + обход по 6 направлениям | O(r) вместо O(r²) |
| `ArenaClusterSystem._compute_clusters` (flood fill) | Union-Find (DSU) | O(B α(B)) вместо O(B), инкрементальность |

---

## 4. Рефакторинг

### 4.1 Разделение `BattleState` — **High**

**Что:** `BattleState` содержит 6+ ответственностей.  
**Зачем:** Тестируемость, читаемость, возможность замены подсистем.

**До:**
```gdscript
class_name BattleState
extends RefCounted
# 450+ строк: состояние, размещение, очередь, кэш, сетка, конец боя
var attacker_units: Array[BattleUnit] = []
var _reachable_cache: Dictionary = {}
var _unit_grid: Dictionary = {}
func place_army(...) -> void: ...
func build_queue() -> void: ...
func get_reachable(...) -> Dictionary: ...
func check_end() -> Side: ...
```

**После:**
```gdscript
# battle_state.gd — только данные
class_name BattleState
extends RefCounted
var attacker_units: Array[BattleUnit] = []
var defender_units: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var battle_over := false
var battle_winner: Side = Side.NONE
var attacker_hero_bonus: Dictionary = {}
var defender_hero_bonus: Dictionary = {}

# battle_placement.gd — размещение
class_name BattlePlacement
static func place_army(state: BattleState, atk: Array[UnitStack], def: Array[UnitStack], ...) -> void: ...

# battle_queue.gd — очередь инициативы
class_name BattleQueue
static func build(state: BattleState) -> void: ...
static func advance(state: BattleState) -> void: ...

# battle_reachability.gd — кэш достижимости
class_name BattleReachability
var _cache: Dictionary = {}
func get_reachable(state: BattleState, unit: BattleUnit, blocked_fn: Callable) -> Dictionary: ...
func invalidate() -> void: _cache.clear()
```

### 4.2 Устранение статического кэша `ArenaClusterSystem` — **High**

**Что:** `static var _cache: Dictionary = {}` — глобальное состояние, не привязанное к жизненному циклу.  
**Зачем:** Утечки памяти, пересечение UID между сессиями.

**До:**
```gdscript
class_name ArenaClusterSystem
static var _cache: Dictionary = {}
static func clusters(city: City) -> Array:
    var entry: Dictionary = _cache.get(city.uid, {})
    var city_ref: WeakRef = entry.get("city_ref", null)
    if city_ref != null and city_ref.get_ref() == null:
        _cache.erase(city.uid)
    ...
```

**После:**
```gdscript
class_name ArenaClusterSystem
extends RefCounted
var _cache: Dictionary = {}  # инстанс-уровень

func clusters(city: City) -> Array:
    # та же логика, но без static
    ...
# Город хранит ссылку:
# var _cluster_system: ArenaClusterSystem = ArenaClusterSystem.new()
```

### 4.3 Вынос расчёта урона из `BattleRules` — **Medium**

**Что:** Дублирование `min_base/max_base/multiplier` в `calculate_attack` и `preview_text`.  
**Зачем:** DRY, единая точка изменения формулы.

**До:**
```gdscript
static func calculate_attack(...) -> Dictionary:
    var min_base: int = stats.base_damage
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25))
    ...
static func preview_text(...) -> String:
    var min_base: int = stats.base_damage * count
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25)) * count
    ...
```

**После:**
```gdscript
static func _damage_range(attacker: BattleState.BattleUnit) -> Vector2i:
    var stats: UnitStats = attacker.stack.stats
    var count: int = attacker.get_count()
    var min_base: int = stats.base_damage * count
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25)) * count
    return Vector2i(min_base, max_base)

static func calculate_attack(...) -> Dictionary:
    var range := _damage_range(attacker)
    var base_total: int = rng.randi_range(range.x, range.y)
    ...
static func preview_text(...) -> String:
    var range := _damage_range(attacker)
    ...
```

### 4.4 Инвалидация `ServiceLocator._cache` при смене сцены — **Medium**

**Что:** Кэш не сбрасывается автоматически.  
**Зачем:** После `change_scene_to_file` автозагрузки могут быть пересозданы.

**До:**
```gdscript
static var _cache: Dictionary = {}
static func resolve(injected: Node, key: StringName) -> Node:
    if _cache.has(key):
        return _cache[key]
    ...
```

**После:**
```gdscript
static var _cache: Dictionary = {}
static var _scene_tree_id: int = -1

static func resolve(injected: Node, key: StringName) -> Node:
    var ml := Engine.get_main_loop()
    if ml is SceneTree:
        var tree_id: int = (ml as SceneTree).get_instance_id()
        if tree_id != _scene_tree_id:
            _cache.clear()
            _scene_tree_id = tree_id
    if _cache.has(key):
        return _cache[key]
    ...
```

### 4.5 Типизированный контракт для `TurnPhaseProcessor.process()` — **Low**

**Что:** Каждый процессор возвращает произвольный `Dictionary`.  
**Зачем:** Безопасность, автодополнение.

```gdscript
# После:
class_name TurnPhaseResult
extends RefCounted
var phase_id: StringName
var data: Dictionary
var errors: Array[String] = []
```

### 4.6 `HexUtils.ring()` — оптимизация с O(r²) до O(r) — **Low**

**До:**
```gdscript
static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
    for y in range(center.y - r, center.y + r + 1):
        for x in range(center.x - r, center.x + r + 1):
            if hex_distance(center, c) == r: ...
```

**После:**
```gdscript
static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
    if r <= 0: return [center]
    var out: Array[Vector2i] = []
    var dirs := [Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1),
                 Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)]
    var cube := offset_to_cube(center)
    var cur := cube + Vector3i(dirs[4].x, -dirs[4].x - dirs[4].y, dirs[4].y) * r
    for i in 6:
        for _j in r:
            out.append(cube_to_offset(cur))
            cur += Vector3i(dirs[i].x, -dirs[i].x - dirs[i].y, dirs[i].y)
    return out
```

---

## 5. Инструкция для локального агента

### Пошаговый план внедрения

| Шаг | Приоритет | Файлы | Действие | Проверка |
|---|---|---|---|---|
| 1 | **High** | `scripts/systems/BattleState.gd` | Разделить на `BattleState` (данные), `BattlePlacement`, `BattleQueue`, `BattleReachability` | `gdunit4 tests/systems/`, `tests/test_battle_state.gd` |
| 2 | **High** | `scripts/city/ArenaClusterSystem.gd` | Заменить `static var _cache` на инстанс-переменную; обновить все вызовы | `tests/functional/test_session_reset.gd` |
| 3 | **High** | `scripts/world/WorldBootstrap.gd` | Вынести создание подсистем в отдельные методы `_create_battle()`, `_create_cities()`, `_create_ui()` | Ручной запуск `World.tscn` |
| 4 | **Medium** | `scripts/core/BattleRules.gd` | Вынести `_damage_range()` | `tests/core/BattleRulesTest.gd` |
| 5 | **Medium** | `scripts/core/ServiceLocator.gd` | Добавить автоинвалидацию по `SceneTree.get_instance_id()` | `tests/functional/test_perf_service_locator.gd` |
| 6 | **Medium** | `scripts/autoload/SpellbookRegistry.gd` | Добавить `null`-проверку `FileAccess.open` | Ручной тест без `spells.json` |
| 7 | **Low** | `scripts/core/HexUtils.gd` | Оптимизировать `ring()` до O(r) | `tests/test_hex_utils.gd` |
| 8 | **Low** | `scripts/world/WorldStateDelta.gd` | Обобщить `_cells_to_array` / `_array_to_cells` в `static func serialize_cells(cells: Array[Vector2i]) -> Array` | `tests/unit/test_world_persistence.gd` |

### Команды проверки

```bash
# Запуск всех GdUnit4-тестов
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add res://tests/ --continue-on-error

# Проверка конкретного модуля
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add res://tests/systems/ --continue-on-error

# MCP-тесты (бой + мировая сцена)
cd tests/mcp && python -m pytest test_battle_tween.py -v
cd tests/mcp && python -m pytest test_shard_pruning.py -v

# Валидация заклинаний
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless -s res://tests/spell_validation/run_validation.gd

# Тюнинг арены (проверка что баланс не сломан)
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless -s res://scripts/build/tune_city_arena.gd -- --dry-run --evals 100
```

### Критерии приёмки

| Критерий | Метрика |
|---|---|
| Все существующие тесты проходят | `0 failures` в выводе GdUnit4 |
| `BattleState` после разделения | Каждый новый файл ≤ 150 строк |
| `ArenaClusterSystem` без `static var` | `grep -r "static var" scripts/city/ArenaClusterSystem.gd` → пусто |
| `ServiceLocator` автоинвалидация | Тест `test_clear_cache_forces_relookup` проходит без явного `clear_cache()` |
| A* на карте 80×80 | Среднее время < 200 мс (тест `test_astar_pathfinding_performance`) |
| Бой 7v7 | Завершается < 1000 мс (тест `test_battle_7v7_performance`) |
| Нет regressions в MCP-тестах | Все `test_battle_tween.py`, `test_resource_and.py` зелёные |

Ниже — **готовый целевой код** для решения трёх проблем:

1. **Service Locator → DI-контейнер**  
   Добавляем `ServiceRegistry` и автозагрузку `Services`. Старый `ServiceLocator` остаётся совместимым, но уже без собственного статического кэша и с возможностью перехода на DI.

2. **Builder для сложных объектов**  
   Выносим инлайновую сборку `BattleState.place_army()` в `BattleStateBuilder`.

3. **Хрупкие статические синглтоны**  
   - `ArenaClusterSystem._cache` убираем полностью: кэш привязывается к самому объекту `City` через metadata.
   - Для `TileAtlas` добавляем управляемый кэш `TileAtlasCache` и совместимый статический мост без статического `var`-кэша.

---

# 1. DI / Service Registry

## Файл: `res://scripts/core/service_registry.gd`

```gdscript
class_name ServiceRegistry
extends RefCounted
## Небольшой DI-контейнер.
##
## Использование:
##   var services: ServiceRegistry = Services.registry
##   var units = services.resolve(&"units")
##
## Регистрация:
##   services.register_singleton(&"units", Units)
##   services.register_factory(&"battle_state_builder", func(reg): return BattleStateBuilder.new())
##
## Внедрение:
##   Если у объекта есть метод inject_services(registry), он будет вызван.

signal service_registered(key: StringName)
signal service_unregistered(key: StringName)

var _singletons: Dictionary = {}
var _factories: Dictionary = {}
var _resolving: Dictionary = {}


func register_singleton(key: StringName, service: Object) -> void:
    if key == StringName(""):
        push_error("ServiceRegistry: попытка зарегистрировать сервис с пустым ключом.")
        return

    _singletons[key] = service
    service_registered.emit(key)


func register_factory(key: StringName, factory: Callable) -> void:
    if key == StringName(""):
        push_error("ServiceRegistry: попытка зарегистрировать фабрику с пустым ключом.")
        return

    if not factory.is_valid():
        push_error("ServiceRegistry: фабрика для ключа '%s' невалидна." % String(key))
        return

    _factories[key] = factory
    service_registered.emit(key)


func register_autoload(key: StringName, autoload_name: StringName) -> void:
    register_factory(
        key,
        func(_registry: ServiceRegistry) -> Object:
            return _find_autoload(autoload_name)
    )


func unregister(key: StringName) -> void:
    var had := false

    if _singletons.has(key):
        _singletons.erase(key)
        had = true

    if _factories.has(key):
        _factories.erase(key)
        had = true

    if had:
        service_unregistered.emit(key)


func clear() -> void:
    _singletons.clear()
    _factories.clear()
    _resolving.clear()


func has_service(key: StringName) -> bool:
    return _singletons.has(key) or _factories.has(key)


func try_resolve(key: StringName) -> Object:
    if key == StringName(""):
        return null

    if _singletons.has(key):
        return _singletons[key]

    if _factories.has(key):
        if _resolving.has(key):
            push_error("ServiceRegistry: циклическое создание сервиса '%s'." % String(key))
            return null

        _resolving[key] = true

        var factory: Callable = _factories[key]
        var service: Object = factory.call(self)

        _resolving.erase(key)

        if service != null:
            _singletons[key] = service

        return service

    return null


func resolve(key: StringName) -> Object:
    var service := try_resolve(key)

    if service == null:
        push_error("ServiceRegistry: сервис не найден: %s" % String(key))

    return service


func inject(target: Object) -> void:
    if target == null:
        return

    if target.has_method("inject_services"):
        target.inject_services(self)


func _find_autoload(autoload_name: StringName) -> Object:
    var main_loop := Engine.get_main_loop()

    if not (main_loop is SceneTree):
        return null

    var tree := main_loop as SceneTree
    var path := "/root/" + String(autoload_name)

    return tree.root.get_node_or_null(path)
```

---

## Файл: `res://scripts/autoload/services.gd`

Добавить в **Автозагрузку**:

- Имя: `Services`
- Путь: `res://scripts/autoload/services.gd`

```gdscript
extends Node
## Центральная точка композиции сервисов.
##
## Важно:
## - Это НЕ статический singleton.
## - Кэш сервисов живёт в экземпляре автозагрузки.
## - При смене сессии можно вызывать clear_session().

var registry := ServiceRegistry.new()


func _ready() -> void:
    _register_core_services()


func _register_core_services() -> void:
    registry.register_singleton(&"services", self)
    registry.register_singleton(&"service_registry", registry)

    # Старые автозагрузки проекта.
    registry.register_autoload(&"units", &"Units")
    registry.register_autoload(&"resources", &"Resources")
    registry.register_autoload(&"spells", &"Spells")
    registry.register_autoload(&"artifacts", &"Artifacts")
    registry.register_autoload(&"spellbook", &"Spellbook")
    registry.register_autoload(&"settings", &"Settings")
    registry.register_autoload(&"event_bus", &"GameEventBus")

    # Фабрики для новых объектов.
    registry.register_factory(
        &"battle_state_builder",
        func(_services: ServiceRegistry) -> Object:
            return BattleStateBuilder.new()
    )


func resolve(key: StringName) -> Object:
    return registry.try_resolve(key)


func try_resolve(key: StringName) -> Object:
    return registry.try_resolve(key)


func register_singleton(key: StringName, service: Object) -> void:
    registry.register_singleton(key, service)


func register_factory(key: StringName, factory: Callable) -> void:
    registry.register_factory(key, factory)


func register_autoload(key: StringName, autoload_name: StringName) -> void:
    registry.register_autoload(key, autoload_name)


func inject(target: Object) -> void:
    registry.inject(target)


func clear_session() -> void:
    registry.clear()
    _register_core_services()
```

---

## Файл: `res://scripts/core/service_locator.gd`

Это **замена старого `ServiceLocator.gd`**.  
Старый API сохраняется, но внутренний статический кэш убирается.

```gdscript
class_name ServiceLocator
extends RefCounted
## Совместимый фасад над новым DI-контейнером.
##
## Старый код можно не переписывать сразу:
##   ServiceLocator.resolve(injected, &"units")
##
## Новый код лучше писать через:
##   Services.resolve(&"units")

const _AUTOLOAD: Dictionary = {
    &"units": "Units",
    &"resources": "Resources",
    &"spells": "Spells",
    &"artifacts": "Artifacts",
    &"spellbook": "Spellbook",
    &"settings": "Settings",
    &"event_bus": "GameEventBus",
}


static func resolve(injected: Node, key: StringName) -> Node:
    if injected != null:
        return injected

    var services := _get_services_autoload()

    if services != null and services.has_method("try_resolve"):
        var service: Variant = services.call("try_resolve", key)

        if service is Node:
            return service

    return _resolve_autoload_fallback(key)


static func clear_cache() -> void:
    var services := _get_services_autoload()

    if services != null and services.has_method("clear_session"):
        services.call("clear_session")


static func _get_services_autoload() -> Node:
    var main_loop := Engine.get_main_loop()

    if not (main_loop is SceneTree):
        return null

    var tree := main_loop as SceneTree
    return tree.root.get_node_or_null("/root/Services")


static func _resolve_autoload_fallback(key: StringName) -> Node:
    var autoload_name: String = _AUTOLOAD.get(key, "")

    if autoload_name.is_empty():
        return null

    var main_loop := Engine.get_main_loop()

    if not (main_loop is SceneTree):
        return null

    var tree := main_loop as SceneTree
    return tree.root.get_node_or_null("/root/" + autoload_name)
```

---

# 2. Builder для `BattleState`

## Файл: `res://scripts/systems/battle_state_builder.gd`

```gdscript
class_name BattleStateBuilder
extends RefCounted
## Builder для BattleState.
##
## Ответственность:
## - валидация входных стеков;
## - лимит юнитов на сторону;
## - раскладка юнитов по клеткам;
## - применение артефактных модификаторов;
## - инициализация живых счётчиков и сетки.
##
## Использование:
##   var state: BattleState = BattleStateBuilder.new() \
##       .set_attacker_army(atk_army) \
##       .set_defender_army(def_army) \
##       .set_attacker_hero_bonus(atk_bonus) \
##       .set_defender_hero_bonus(def_bonus) \
##       .set_attacker_artifact_mods(atk_mods) \
##       .set_defender_artifact_mods(def_mods) \
##       .build()

var _attacker_stacks: Array = []
var _defender_stacks: Array = []

var _attacker_bonus: Dictionary = {}
var _defender_bonus: Dictionary = {}

var _attacker_artifact_mods: Dictionary = {}
var _defender_artifact_mods: Dictionary = {}

var _has_hero_bonuses := false

var _max_units_per_side: int = BattleConfig.BATTLE_MAX_UNITS_PER_SIDE
var _board_width: int = BattleState.BW
var _board_height: int = BattleState.BH


func set_attacker_army(stacks: Array) -> BattleStateBuilder:
    _attacker_stacks.clear()
    _attacker_stacks.assign(stacks)
    return self


func set_defender_army(stacks: Array) -> BattleStateBuilder:
    _defender_stacks.clear()
    _defender_stacks.assign(stacks)
    return self


func set_hero_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> BattleStateBuilder:
    _attacker_bonus = attacker_bonus.duplicate(true)
    _defender_bonus = defender_bonus.duplicate(true)
    _has_hero_bonuses = true
    return self


func set_attacker_hero_bonus(bonus: Dictionary) -> BattleStateBuilder:
    _attacker_bonus = bonus.duplicate(true)
    _has_hero_bonuses = true
    return self


func set_defender_hero_bonus(bonus: Dictionary) -> BattleStateBuilder:
    _defender_bonus = bonus.duplicate(true)
    _has_hero_bonuses = true
    return self


func set_attacker_artifact_mods(mods: Dictionary) -> BattleStateBuilder:
    _attacker_artifact_mods = mods.duplicate(true)
    return self


func set_defender_artifact_mods(mods: Dictionary) -> BattleStateBuilder:
    _defender_artifact_mods = mods.duplicate(true)
    return self


func set_max_units_per_side(value: int) -> BattleStateBuilder:
    _max_units_per_side = maxi(1, value)
    return self


func set_board_size(width: int, height: int) -> BattleStateBuilder:
    _board_width = maxi(3, width)
    _board_height = maxi(3, height)
    return self


func build() -> BattleState:
    var state := BattleState.new()
    build_into(state)
    return state


func build_into(state: BattleState) -> void:
    if state == null:
        push_error("BattleStateBuilder: build_into(null)")
        return

    state._uid = 0

    var attacker_units := _build_units(state, _attacker_stacks, true)
    var defender_units := _build_units(state, _defender_stacks, false)

    _apply_artifact_effects(attacker_units, _attacker_artifact_mods)
    _apply_artifact_effects(defender_units, _defender_artifact_mods)

    if _has_hero_bonuses:
        state.set_hero_bonuses(_attacker_bonus, _defender_bonus)

    state.attacker_units.clear()
    state.attacker_units.assign(attacker_units)

    state.defender_units.clear()
    state.defender_units.assign(defender_units)

    state._attacker_alive_count = state.attacker_units.size()
    state._defender_alive_count = state.defender_units.size()

    state._rebuild_unit_grid()
    state.invalidate_board_cache()
    state.check_end()


func _build_units(state: BattleState, stacks: Array, is_attacker: bool) -> Array:
    var units: Array = []

    var current_col := 0 if is_attacker else _board_width - 1
    var col_step := 1 if is_attacker else -1
    var current_row := 0

    for i in stacks.size():
        if i >= _max_units_per_side:
            GameLogger.battle(
                "%s: лимит юнитов в бою (%d) достигнут."
                % ["Атакующие" if is_attacker else "Защитники", _max_units_per_side]
            )
            break

        var input_stack = stacks[i]

        if input_stack == null or not input_stack.is_alive():
            continue

        var stack: UnitStack = input_stack.duplicate_stack()

        if stack == null or stack.stats == null:
            push_error("[BattleStateBuilder] Invalid UnitStack received")
            continue

        var placed := false

        while current_col >= 0 and current_col < _board_width:
            while current_row < _board_height:
                if not _cell_taken(current_col, current_row, units):
                    placed = true
                    break

                current_row += 1

            if placed:
                break

            current_col += col_step
            current_row = 0

        if not placed:
            push_error(
                "[BattleStateBuilder] Cannot place stack %d: no free cells in deployment zone." % i
            )
            continue

        var unit := BattleState.BattleUnit.new(stack)
        unit.cell = Vector2i(current_col, current_row)
        unit.side = BattleState.Side.ATTACKER if is_attacker else BattleState.Side.DEFENDER
        unit.alive = true
        unit.has_moved = false
        unit.max_count = stack.count
        unit.uid = state._uid

        state._uid += 1
        units.append(unit)

        current_row += 1

        if current_row >= _board_height:
            current_row = 0
            current_col += col_step

    return units


func _cell_taken(col: int, row: int, units: Array) -> bool:
    for unit in units:
        if unit.cell.x == col and unit.cell.y == row:
            return true

    return false


func _apply_artifact_effects(units: Array, mods: Dictionary) -> void:
    if mods.is_empty():
        return

    var flat_hp: int = int(mods.get("stack_hp", 0))
    var percent_hp: float = float(mods.get("stack_hp_percent", 0.0))
    var speed_bonus: int = int(mods.get("stack_speed", 0))

    if flat_hp == 0 and absf(percent_hp) <= 0.0001 and speed_bonus == 0:
        return

    for unit in units:
        if unit == null:
            continue

        if unit.stack == null or unit.stack.stats == null:
            continue

        var stats: UnitStats = unit.stack.stats
        var new_stats: UnitStats = stats.copy()

        if flat_hp > 0 or percent_hp > 0.0:
            var hp := float(new_stats.hp)
            hp += float(flat_hp)
            hp *= 1.0 + percent_hp
            new_stats.hp = int(roundf(hp))

        if speed_bonus > 0:
            new_stats.speed += speed_bonus

        unit.stack.stats = new_stats
```

---

## Патч в `res://scripts/systems/BattleState.gd`

Замените текущий `place_army()` на этот:

```gdscript
func place_army(
    attacker_stacks: Array[UnitStack],
    defender_stacks: Array[UnitStack],
    attacker_artifact_mods: Dictionary = {},
    defender_artifact_mods: Dictionary = {}
) -> void:
    var builder := BattleStateBuilder.new()

    builder.set_attacker_army(attacker_stacks)
    builder.set_defender_army(defender_stacks)
    builder.set_attacker_artifact_mods(attacker_artifact_mods)
    builder.set_defender_artifact_mods(defender_artifact_mods)

    builder.build_into(self)
```

После этого старые приватные функции можно удалить или оставить как мёртвый код:

- `_build_units()`
- `_apply_artifact_effects()`
- `_cell_taken()`

Но для чистоты лучше удалить.

---

## Опциональный переход на Builder в `BattleController`

В `BattleController.start_battle()` можно создавать состояние так:

```gdscript
func _init_state() -> void:
    var builder := BattleStateBuilder.new()

    builder.set_hero_bonuses(attacker_bonus, defender_bonus)
    builder.set_attacker_artifact_mods(attacker_artifact_mods)
    builder.set_defender_artifact_mods(defender_artifact_mods)
    builder.set_attacker_army(atk_stacks)
    builder.set_defender_army(def_stacks)

    _state = builder.build()
    _ai = BattleAI.new()
```

Но если не хотите менять `BattleController`, оставьте совместимый `state.place_army()` выше.

---

# 3. Убираем хрупкий статический кэш `ArenaClusterSystem`

## Файл: `res://scripts/city/ArenaClusterSystem.gd`

Полная замена.

```gdscript
class_name ArenaClusterSystem
extends RefCounted
## Кластеры зданий.
##
## Старая проблема:
##   static var _cache: Dictionary = {}
##
## Новое решение:
##   Кэш хранится в самом объекте City через metadata.
##   Это убирает глобальный статический словарь и пересечение кэшей между сессиями.

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const PopUnit := preload("res://scripts/world/PopUnit.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

const CACHE_META := &"_arena_cluster_cache"


class CacheData extends RefCounted:
    var version: int = -1
    var clusters: Array = []


static func clusters(city: City) -> Array:
    if city == null:
        return []

    var version := _city_version(city)
    var cache := _get_cache(city)

    if cache.version == version:
        return cache.clusters

    var result := _compute_clusters(city)

    cache.version = version
    cache.clusters = result

    return result


static func cluster_uids(city: City) -> Dictionary:
    if city == null:
        return {}

    var result: Dictionary = {}

    for cluster in clusters(city):
        var cluster_dict := cluster as Dictionary

        if cluster_dict.is_empty():
            continue

        var buildings := cluster_dict.get("buildings", [])

        for building in buildings:
            var unique_building := building as UniqueBuilding

            if unique_building != null:
                result[unique_building.uid] = ArenaBalance.CLUSTER_MULT

    return result


static func cluster_worker_housing(city: City) -> int:
    if city == null:
        return 0

    return city.free_housing(PopUnit.State.WORKER) \
        + ArenaBalance.CLUSTER_HOUSING * clusters(city).size()


## Старый API принимает uid.
## Теперь кэш привязан к City, поэтому по одному uid очистить кэш нельзя.
## Это намеренно: при изменении города версия кэша сама станет невалидной.
static func invalidate(_city_uid: int) -> void:
    pass


## Новый API, если нужно принудительно сбросить кэш конкретного города.
static func invalidate_city(city: City) -> void:
    if city == null:
        return

    if city.has_meta(CACHE_META):
        city.remove_meta(CACHE_META)


## Оставлен для совместимости со старыми вызовами reset().
## Глобального кэша больше нет, поэтому сбрасывать нечего.
static func reset() -> void:
    pass


static func _get_cache(city: City) -> CacheData:
    if city.has_meta(CACHE_META):
        var cached: Variant = city.get_meta(CACHE_META)

        if cached is CacheData:
            return cached

    var cache := CacheData.new()
    city.set_meta(CACHE_META, cache)

    return cache


static func _compute_clusters(city: City) -> Array:
    var by_def: Dictionary = {}

    for building in city.buildings:
        if building == null or building.def == null:
            continue

        if not by_def.has(building.def.id):
            by_def[building.def.id] = []

        (by_def[building.def.id] as Array).append(building)

    var out: Array = []

    for def_id in by_def:
        var buildings: Array = by_def[def_id]

        var by_cell: Dictionary = {}

        for building in buildings:
            var unique_building := building as UniqueBuilding

            if unique_building != null:
                by_cell[unique_building.cell] = unique_building

        var seen: Dictionary = {}

        for building in buildings:
            var start := building as UniqueBuilding

            if start == null or seen.has(start.uid):
                continue

            var component: Array = []
            var stack: Array = [start]

            seen[start.uid] = true

            while not stack.is_empty():
                var current := stack.pop_back() as UniqueBuilding

                if current == null:
                    continue

                component.append(current)

                for neighbor_cell in HexUtils.get_all_neighbors(current.cell):
                    var neighbor: UniqueBuilding = by_cell.get(neighbor_cell)

                    if neighbor != null and not seen.has(neighbor.uid):
                        seen[neighbor.uid] = true
                        stack.append(neighbor)

            if component.size() >= ArenaBalance.CLUSTER_MIN:
                var cells: Array[Vector2i] = []

                for building in component:
                    var unique_building := building as UniqueBuilding

                    if unique_building != null:
                        cells.append(unique_building.cell)

                out.append(
                    {
                        "def_id": def_id,
                        "cells": cells,
                        "buildings": component,
                    }
                )

    out.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool:
            var a_cells := a.get("cells", []) as Array
            var b_cells := b.get("cells", []) as Array

            if a_cells.is_empty() or b_cells.is_empty():
                return false

            var ca: Vector2i = a_cells[0]
            var cb: Vector2i = b_cells[0]

            return ca.y * 10000 + ca.x < cb.y * 10000 + cb.x
    )

    return out


static func _city_version(city: City) -> int:
    if city == null:
        return -1

    var hash_value: int = 0

    for building in city.buildings:
        if building != null:
            hash_value = (hash_value * 131 + int(building.uid)) & 0x7fffffff
            hash_value = (hash_value * 137 + building.level) & 0x7fffffff
            hash_value = (hash_value * 139 + building.assigned_workers) & 0x7fffffff

    return int(city.buildings.size()) * 1_000_003 + hash_value
```

---

# 4. Убираем хрупкий статический кэш `TileAtlas`

Ниже — безопасный управляемый кэш и совместимый статический мост.

---

## Файл: `res://scripts/autoload/tile_atlas_cache.gd`

Добавить в **Автозагрузку**:

- Имя: `TileAtlasCache`
- Путь: `res://scripts/autoload/tile_atlas_cache.gd`

```gdscript
extends Node
## Управляемый кэш TileAtlas.
##
## Раньше кэш мог жить в статическом поле/синглтоне.
## Теперь кэш принадлежит автозагрузке и может быть явно очищен:
##   TileAtlasCache.clear_cache()

var _hex_tileset: TileSet = null


func build_hex_tileset() -> TileSet:
    if _hex_tileset != null:
        return _hex_tileset

    _hex_tileset = _build_tileset()
    return _hex_tileset


func clear_cache() -> void:
    _hex_tileset = null


func _build_tileset() -> TileSet:
    var atlas_script := load("res://scripts/world/tile_atlas.gd")

    if atlas_script == null:
        push_error("TileAtlasCache: не найден скрипт атласа.")
        return null

    var atlas = atlas_script.new()

    if atlas == null:
        push_error("TileAtlasCache: не удалось создать экземпляр атласа.")
        return null

    if atlas.has_method("build"):
        var ok: Variant = atlas.call("build")

        if ok is bool and not ok:
            push_error("TileAtlasCache: build() вернул false.")
            return null

    if atlas.has_method("get_tileset"):
        return atlas.call("get_tileset")

    if "_tileset" in atlas:
        return atlas.get("_tileset")

    push_error("TileAtlasCache: TileAtlas не отдаёт тайлсет. Добавьте метод get_tileset().")
    return null
```

---

## Патч в `res://scripts/world/tile_atlas.gd`

Добавьте или замените служебные методы в конце `TileAtlas`:

```gdscript
func get_tileset() -> TileSet:
    return _tileset


static func build_hex_tileset() -> TileSet:
    # Совместимый статический мост.
    # Он не хранит статический кэш внутри TileAtlas.
    # Кэш живёт в управляемой автозагрузке TileAtlasCache.
    var main_loop := Engine.get_main_loop()

    if main_loop is SceneTree:
        var tree := main_loop as SceneTree
        var cache := tree.root.get_node_or_null("/root/TileAtlasCache")

        if cache != null and cache.has_method("build_hex_tileset"):
            return cache.call("build_hex_tileset")

    # Fallback для тестов и сцен без автозагрузки TileAtlasCache.
    var atlas := TileAtlas.new()
    atlas.build()
    return atlas.get_tileset()


static func clear_cache() -> void:
    var main_loop := Engine.get_main_loop()

    if main_loop is SceneTree:
        var tree := main_loop as SceneTree
        var cache := tree.root.get_node_or_null("/root/TileAtlasCache")

        if cache != null and cache.has_method("clear_cache"):
            cache.call("clear_cache")
```

Если в вашем `TileAtlas` уже есть `static func build_hex_tileset()`, замените его полностью на этот.

---

# 5. Обновление сброса сессионных кэшей

В местах выхода в меню / смены сессии используйте единый сброс.

Например, в `MainMenu`:

```gdscript
func _clear_session_caches() -> void:
    ServiceLocator.clear_cache()
    ArenaClusterSystem.reset()
    ResourceIcons.clear_cache()

    var tile_cache := Engine.get_main_loop().root.get_node_or_null("/root/TileAtlasCache")

    if tile_cache != null and tile_cache.has_method("clear_cache"):
        tile_cache.call("clear_cache")
```

И аналогично в `EndgameController._return_to_menu()` перед сменой сцены.

---

# 6. Пример нового DI-использования

В новых системах лучше не вызывать `ServiceLocator.resolve()`, а внедрять зависимости.

Пример:

```gdscript
class_name SomeNewSystem
extends RefCounted

var services: ServiceRegistry = null


func inject_services(registry: ServiceRegistry) -> void:
    services = registry


func do_something() -> void:
    if services == null:
        push_error("SomeNewSystem: services не внедрены.")
        return

    var units = services.resolve(&"units")

    if units == null:
        push_error("SomeNewSystem: units не найдены.")
        return
```

Создание и внедрение:

```gdscript
var system := SomeNewSystem.new()
Services.inject(system)
```

---

# 7. Обязательные шаги интеграции

## 1. Добавить автозагрузки

В `Project -> Project Settings -> Autoload`:

| Имя | Путь |
|---|---|
| `Services` | `res://scripts/autoload/services.gd` |
| `TileAtlasCache` | `res://scripts/autoload/tile_atlas_cache.gd` |

Рекомендуемый порядок:

1. `GameEventBus`
2. `Settings`
3. `Units`
4. `Resources`
5. `Spells`
6. `Artifacts`
7. `Spellbook`
8. `Services`
9. `TileAtlasCache`

Если порядок автозагрузок нельзя поменять, ничего страшного: `ServiceRegistry` использует ленивый поиск автозагрузок через фабрику.

---

## 2. Заменить файлы

Заменить:

- `res://scripts/core/service_locator.gd`
- `res://scripts/city/ArenaClusterSystem.gd`

Добавить:

- `res://scripts/core/service_registry.gd`
- `res://scripts/autoload/services.gd`
- `res://scripts/systems/battle_state_builder.gd`
- `res://scripts/autoload/tile_atlas_cache.gd`

---

## 3. Патчить существующие файлы

В `BattleState.gd`:

- заменить `place_army()`;
- удалить старые `_build_units()`, `_apply_artifact_effects()`, `_cell_taken()` при желании.

В `TileAtlas.gd`:

- добавить `get_tileset()`;
- заменить `build_hex_tileset()`;
- добавить `clear_cache()`.

---

# 8. Проверка

## Быстрая проверка в редакторе

1. Запустить проект.
2. Войти в бой.
3. Проверить расстановку юнитов.
4. Выйти в меню.
5. Начать новую сессию.
6. Проверить город/арену, где используются кластеры.

## Тесты

Если используются GdUnit4:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add res://tests/ --continue-on-error
```

Минимальные критерии приёмки:

| Критерий | Ожидание |
|---|---|
| Старый `ServiceLocator.resolve()` работает | без изменений существующих вызовов |
| Новый `Services.resolve()` работает | возвращает автозагрузки |
| `BattleState` создаётся через builder | бой запускается, юниты размещены |
| `ArenaClusterSystem` не имеет `static var _cache` | `grep "static var _cache"` пуст |
| Кластеры не текут между сессиями | новый город не видит старые кластеры |
| `TileAtlas` не использует статический кэш | кэш только в `TileAtlasCache` |
| Очистка сессии | `ServiceLocator.clear_cache()` и `TileAtlasCache.clear_cache()` проходят без ошибок |

---

# 9. Итог

После этих правок:

- **Service Locator** становится управляемым и получает путь к **DI**.
- **BattleState** больше не собирается инлайново внутри `place_army()`.
- **ArenaClusterSystem** больше не имеет глобального статического кэша.
- **TileAtlas** получает безопасный управляемый кэш с возможностью очистки.

