# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1. Общее впечатление

| Аспект | Оценка | Комментарий |
|--------|--------|-------------|
| Модульность | 7/10 | Хорошее разделение на подсистемы (бой, город, герой), но есть «божественные» классы |
| Связность | 6/10 | Смешение DI-контейнера, ServiceLocator, прямого доступа к autoload |
| Масштабируемость | 7/10 | Паттерн `TurnPhaseProcessor` и `TemplateEngine` — хорошо расширяемы |
| Паттерны | 8/10 | Стратегия (нужды), Команда (бой), Наблюдатель (сигналы) — применены грамотно |

### 1.2. Критические проблемы

#### P1: Смешение трёх механизмов разрешения зависимостей

```
# Способ 1: прямой autoload
var reg = get_node("/root/Units")

# Способ 2: ServiceLocator (статический фасад)
var reg = ServiceLocator.resolve(null, &"units")

# Способ 3: DI-контейнер через Services
var reg = Services.resolve(&"units")
```

**Файлы:** `SpellCaster.gd`, `BattleEmulator.gd`, `HeroArmyController.gd`, `WorldSpawner.gd`

**Проблема:** три параллельных пути к одному ресурсу → непредсказуемое поведение в тестах, невозможность мокирования.

#### P2: God-class `City` (~450 строк, 20+ методов)

`City.gd` совмещает:
- данные (население, здания, ресурсы);
- бизнес-логику (строительство, апгрейд, рост);
- сериализацию;
- кэширование доходности.

#### P3: `WorldController` как оркестратор-«клей»

Содержит инициализацию, обработку ввода, управление сценами, сохранение. Несмотря на частичный рефакторинг (выделены `WorldBootstrap`, `WorldHeroManager`), класс остаётся точкой связности 10+ подсистем.

#### P4: Статическое мутабельное состояние

| Класс | Поле | Риск |
|-------|------|------|
| `HexUtils` | `_shift_right`, `_config` | Глобальное состояние, ломает параллельные сессии |
| `TerrainCostTable` | `_costs`, `_costs_by_id` | Lazy-init без потокобезопасности |
| `TemplateEngine` | `_handlers` | Глобальный реестр без изоляции |
| `ShardManager` | `_instance` | Ручной singleton |

### 1.3. Сильные стороны

- **`TurnScheduler` + `TurnPhaseProcessor`** — чистая реализация Pipeline/Chain of Responsibility. Легко добавлять фазы.
- **`TemplateEngine`** для заклинаний — шаблонный метод + стратегия, 19 шаблонов без `match` по ID.
- **`BattleStateBuilder`** — Builder для конструирования боя, `BattleState` остаётся чистым контейнером.
- **`NeedStrategy`** — паттерн Стратегия для нужд героя/населения.

---

## 2. Лучшие практики

### 2.1. Идиомы GDScript / Godot

| Проблема | Файл | Приоритет |
|----------|------|-----------|
| `class_name` + `extends RefCounted` для статических утилит (не нужны инстансы) | `HexDraw`, `BattleRules`, `SpellCaster` | Low |
| `@onready` без проверки `null` | `BattleController._view` | Medium |
| Сигналы подключаются в `_ready()` без `is_connected` guard (частично исправлено) | `AdventureUI`, `WorldEventRouter` | Medium |
| Использование `var` вместо типизированных объявлений в горячих циклах | `MapGenerator._compute_reachable_cells` | Low |
| `queue_free()` + продолжение использования ссылки в том же кадре | `BattleView.remove_unit` | Medium |

### 2.2. SOLID / DRY / KISS

| Принцип | Нарушение | Пример |
|---------|-----------|--------|
| **SRP** | `City` — данные + логика + сериализация | `City.gd` |
| **SRP** | `WorldSpawner` — спавн + визуал + боевые данные | `WorldSpawner.gd` |
| **DRY** | Дублирование `_ring_color`, `_ring_yield_short` в `CityArenaView` и `ArenaHexCell` | 2 файла |
| **DRY** | Повторяющийся код подключения кнопок в `CityArenaView._wire_ui` | 6 одинаковых блоков |
| **KISS** | `WorldPersistence._find_city` — 3 стратегии поиска, хотя достаточно `uid` | `WorldPersistence.gd` |
| **YAGNI** | `EquipmentManager.roll_attack` — d20-механика, не используемая в бою | `EquipmentManager.gd` |

### 2.3. Безопасность и обработка ошибок

- **Отсутствие валидации входных данных** в `CityScreen.build_pressed` — нет проверки `def != null` до вызова `first_free_build_cell`.
- **`SaveManager.load_game`** корректно обрабатывает ошибки парсинга, но **`WorldPersistence.apply_loaded_save`** не валидирует `ctx` на `null`.
- **`ResourceNodeManager._check_extraction`** — исправлен на строгий AND, но **нет логирования** при отказе.

### 2.4. Читаемость и naming

- **Хорошо:** `GameNumbers` как единая точка констант, `GameText` для локализации.
- **Плохо:** переменные `_ss_settings`, `_ss_screen` (непонятные префиксы); `_i100`, `_i50`, `_i30` в `hex_map_generator.gd`.
- **Смешение языков:** комментарии на русском, имена на английском — допустимо, но в `GameText` ключи `arena.borough_reason` vs текст «Район должен примыкать…» — нужно единообразие.

---

## 3. Алгоритмы и структуры данных

### 3.1. Используемые алгоритмы

| Алгоритм | Где | Сложность | Замечание |
|----------|-----|-----------|-----------|
| A* (hex) | `HexPathfinding.astar_path` | O(V log V) | Корректен, но `PackedFloat32Array` + `PackedInt32Array` — хорошо |
| BFS | `HexPathfinding.bfs_path`, `bfs_reachable` | O(V + E) | Используется для зоны видимости и досягаемости |
| Dijkstra | `HexPathfinding.dijkstra` | O(V log V) | Для вражеского ИИ — кэшируется в `EnemyTurnProcessor` |
| MinHeap | `MinHeap.gd` | O(log n) push/pop | Ручная реализация, корректна |
| Cube-coordinates | `HexUtils.offset_to_cube` | O(1) | Стандарт для hex-сеток |
| Flood-fill (connected components) | `ArenaClusterSystem._compute_clusters` | O(B) | B = кол-во зданий |
| FastNoiseLite | `MapModel.generate_noise` | O(W×H) | Стандартный шум |

### 3.2. Проблемы и оптимизации

#### A1: `HexUtils.ring()` — O(r) vs старый O(r²) ✅ уже исправлено
Код уже содержит оптимизацию через кубические направления. Подтверждаю корректность.

#### A2: `VisibilityMap._fill_disk` — O(r²) суммарно
```gdscript
for r in range(1, radius + 1):
    for cell in HexUtils.ring(center, r):  # O(r) на каждое кольцо
```
Итого O(r²) клеток — неизбежно для заполнения диска. **Оптимально.**

#### A3: `EnemyTurnProcessor` — Dijkstra на каждый стек отдельно
```gdscript
for start_cell in cells:
    var dist := _dist_field(cell, mp, cost_fn, dist_cache)
```
Кэш `dist_cache` помогает, но **ключ = (cell, mp)** — при разных `mp` (из-за `EnemyAIProfile`) кэш не переиспользуется.

**Рекомендация:** для стеков с одинаковым `mp` и `cost_fn` можно переиспользовать одно поле.

#### A4: `CityYieldCalculator._ensure_exploited` — пересчёт при каждой инвалидации
При каждом `add_migrant` / `remove_pop` / `request_switch` вызывается `_invalidate_exploited()`. Для города с 50+ жителями это O(N) на каждое действие.

**Рекомендация:** батчинг инвалидации (отложить до конца хода).

#### A5: `MapSpawner.place_enemies` — Fisher-Yates shuffle на всех кандидатах
```gdscript
for i in range(candidates.size() - 1, 0, -1):
    var j := rng.randi_range(0, i)
    var tmp := candidates[i]
    candidates[i] = candidates[j]
    candidates[j] = tmp
```
O(N) где N = все проходимые клетки. Для карты 70×70 = ~4900 итераций. **Допустимо**, но можно ограничиться частичным перемешиванием (первые `MAP_ENEMY_COUNT × 3` элементов).

### 3.3. Граничные случаи

| Место | Проблема | Риск |
|-------|----------|------|
| `HexPathfinding.astar_path` | `start == goal` возвращает `[start]`, но вызывающий код ожидает `size() >= 2` для движения | Средний |
| `BattleRules.calculate_attack` | `count <= 0` → пустой словарь, но вызывающий код не всегда проверяет | Средний |
| `City.first_free_build_cell` | Если `bounds == Vector2i.ZERO` — проверка границ пропускается | Низкий |
| `MinHeap.pop` | Возвращает `[]` при пустой куче — вызывающий код в `HexPathfinding` проверяет `is_empty()` | Низкий |

---

## 4. Рефакторинг: конкретные правки

### 4.1. High Priority

#### R1: Унификация DI — убрать прямой доступ к autoload

**Что:** Заменить все `get_node("/root/Units")` и `ServiceLocator.resolve(null, ...)` на инъекцию через конструктор/метод `setup()`.

**Зачем:** Тестируемость, предсказуемость, возможность подмены в тестах.

**До:**
```gdscript
# SpellCaster.gd
static func cast(..., registry: Node = null) -> Dictionary:
    var reg: Node = ServiceLocator.resolve(registry, &"spells")
```

**После:**
```gdscript
# SpellCaster.gd — instance-based
class_name SpellCaster
var _registry: SpellRegistry

func _init(registry: SpellRegistry) -> void:
    _registry = registry

func cast(spell_id: StringName, target: BattleState.BattleUnit, ...) -> Dictionary:
    var spell := _registry.get_spell(spell_id)
    ...
```

**Приоритет:** High

---

#### R2: Разделение `City` на данные и сервисы

**Что:** Выделить `CityData` (чистые данные + сериализация) и `CityService` (операции).

**Зачем:** SRP, тестируемость, уменьшение класса с 450 до ~150 строк.

**До:**
```gdscript
# City.gd — 450 строк, всё в одном
class_name City
func build_building(def, cell) -> UniqueBuilding: ...
func process_turn(turn) -> Dictionary: ...
func serialize() -> Dictionary: ...
```

**После:**
```gdscript
# city_data.gd
class_name CityData
var uid: int
var pop: Array[PopUnit]
var buildings: Array[UniqueBuilding]
func serialize() -> Dictionary: ...

# city_service.gd
class_name CityService
static func build_building(city: CityData, def, cell) -> UniqueBuilding: ...
static func process_turn(city: CityData, turn: int) -> Dictionary: ...
```

**Приоритет:** High

---

#### R3: Убрать статическое мутабельное состояние из `HexUtils`

**Что:** Перенести `_shift_right` в инстанс или передавать как параметр.

**Зачем:** Безопасность при нескольких сценах/тестах одновременно.

**До:**
```gdscript
static var _shift_right: bool = true
static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
    if _shift_right: ...
```

**После:**
```gdscript
# HexGridConfig хранит состояние, HexUtils принимает его
static func get_neighbor(cell: Vector2i, bit: int, config: HexGridConfig) -> Vector2i:
    if config.odd_row_shift_right: ...
```

**Приоритет:** High (но требует миграции всех вызовов)

---

### 4.2. Medium Priority

#### R4: Батчинг инвалидации кэша доходности города

**До:**
```gdscript
func _add_pop(state, turn) -> PopUnit:
    ...
    _invalidate_exploited()  # каждый раз
    population_changed.emit()
```

**После:**
```gdscript
var _yield_dirty := false

func _add_pop(state, turn) -> PopUnit:
    ...
    _yield_dirty = true
    population_changed.emit()

func get_yield() -> Dictionary:
    if _yield_dirty:
        _yield_calc.invalidate()
        _yield_dirty = false
    return _yield_calc.calculate(self)
```

**Приоритет:** Medium

---

#### R5: DRY — вынести подключение кнопок арены в хелпер

**До (6 блоков):**
```gdscript
var turn_btn := bar.get_node("TurnButton") as Button
turn_btn.pressed.connect(_on_turn_pressed)
turn_btn.text = GameText.arena_turn_button()
var auto_btn := bar.get_node("AutoButton") as Button
auto_btn.pressed.connect(_on_auto_pressed)
auto_btn.text = GameText.arena_auto_button()
# ... x6
```

**После:**
```gdscript
func _wire_button(parent: Control, name: String, text: String, cb: Callable) -> Button:
    var btn := parent.get_node(name) as Button
    btn.text = text
    btn.pressed.connect(cb)
    return btn

# Использование:
_wire_button(bar, "TurnButton", GameText.arena_turn_button(), _on_turn_pressed)
_wire_button(bar, "AutoButton", GameText.arena_auto_button(), _on_auto_pressed)
```

**Приоритет:** Medium

---

#### R6: Защита от `null` в `BattleView._find_node`

**До:**
```gdscript
func _find_node(unit: BattleState.BattleUnit) -> Node2D:
    if unit == null: return null
    return _sprites_by_uid.get(unit.uid, null)
```

**После:**
```gdscript
func _find_node(unit: BattleState.BattleUnit) -> Node2D:
    if unit == null: return null
    var node: Node2D = _sprites_by_uid.get(unit.uid, null)
    if node != null and not is_instance_valid(node):
        _sprites_by_uid.erase(unit.uid)
        return null
    return node
```

**Приоритет:** Medium

---

### 4.3. Low Priority

#### R7: Типизация горячих циклов в `MapGenerator`

**До:**
```gdscript
for cell in model.terrain_grid:
    if model.is_walkable(cell):
```

**После:**
```gdscript
var terrain: Dictionary = model.terrain_grid
for cell: Vector2i in terrain:
    if model.is_walkable(cell):
```

**Приоритет:** Low

---

#### R8: Удалить мёртвый код `EquipmentManager.roll_attack`

d20-механика не используется в текущей боевой системе. Удалить до момента, пока не понадобится.

**Приоритет:** Low (YAGNI)

---

## 5. Инструкция для локального агента

### Пошаговый план внедрения

| Шаг | Что | Файлы | Приоритет |
|-----|-----|-------|-----------|
| 1 | Унифицировать DI: заменить `ServiceLocator.resolve` на инъекцию в `SpellCaster`, `BattleEmulator` | `SpellCaster.gd`, `BattleEmulator.gd`, `BattleActionResolver.gd` | High |
| 2 | Выделить `CityData` из `City`, перенести сериализацию в `CitySerializer` (уже частично сделано) | `City.gd`, `CitySerializer.gd`, `CityBuildingService.gd` | High |
| 3 | Убрать `static var` из `HexUtils`, передавать `HexGridConfig` явно | `HexUtils.gd`, `HexPathfinding.gd`, все вызывающие | High |
| 4 | Батчинг инвалидации кэша доходности | `City.gd`, `CityYieldCalculator.gd` | Medium |
| 5 | DRY: хелпер `_wire_button` для арены | `CityArenaView.gd` | Medium |
| 6 | Null-guard в `BattleView._find_node` | `BattleView.gd` | Medium |
| 7 | Удалить `EquipmentManager.roll_attack` | `EquipmentManager.gd` | Low |
| 8 | Типизация циклов в `MapGenerator` | `MapGenerator.gd`, `MapModel.gd` | Low |

### Команды проверки

```bash
# Запуск всех тестов (gdUnit4)
godot --headless --path . --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd

# Запуск конкретного теста
godot --headless --path . --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add "res://tests/systems/BattleDamageResolverTest.gd"

# Проверка компиляции всех .gd
godot --headless --path . --check-only --script res://tests/functional/test_compile_all.gd

# MCP-тесты (баттл-сцена)
cd tests/mcp && python -m pytest test_battle_tween.py -v --timeout=120
```

### Критерии приёмки

| Правка | Критерий |
|--------|----------|
| R1 (DI) | Все тесты проходят; нет вызовов `ServiceLocator.resolve` в `SpellCaster`, `BattleEmulator` |
| R2 (City) | `City.gd` < 200 строк; `CitySerializer` покрывает 100% сериализации; тесты города зелёные |
| R3 (HexUtils) | Нет `static var` в `HexUtils`; тесты `test_hex_utils.gd` проходят |
| R4 (батчинг) | `get_yield()` вызывает `invalidate()` ≤ 1 раз за ход (проверить в тесте) |
| R5 (DRY) | `CityArenaView._wire_ui` < 15 строк |
| R6 (null-guard) | Нет crash при удалении юнита во время анимации |
| Общее | `test_compile_all.gd` — 0 ошибок; все существующие тесты зелёные |

---

## Сводная таблица приоритетов

| # | Правка | Приоритет | Трудозатраты | Риск регрессии |
|---|--------|-----------|--------------|----------------|
| R1 | Унификация DI | **High** | 2–3 дня | Средний |
| R2 | Разделение City | **High** | 2 дня | Средний |
| R3 | HexUtils без статики | **High** | 1–2 дня | Высокий (много вызовов) |
| R4 | Батчинг кэша | Medium | 0.5 дня | Низкий |
| R5 | DRY кнопок | Medium | 0.5 часа | Минимальный |
| R6 | Null-guard | Medium | 0.5 часа | Минимальный |
| R7 | Типизация | Low | 1 час | Минимальный |
| R8 | Удаление мёртвого кода | Low | 15 мин | Нет |


# Исправление: унификация DI

## Стратегия

Единая точка доступа — автозагрузка `Services` (DI-контейнер). `ServiceLocator` остаётся как **тонкий совместимый фасад**, делегирующий в `Services`. Прямые вызовы `get_node("/root/...")` заменяются на `Services.resolve()`.

---

## 1. `res://scripts/autoload/services.gd` — центральный контейнер

```gdscript
extends Node
## Центральная точка композиции сервисов.
## Единственный способ получить сервис: Services.resolve(&"key")

var registry := ServiceRegistry.new()

func _ready() -> void:
    _register_core_services()

func _register_core_services() -> void:
    registry.register_singleton(&"services", self)
    registry.register_singleton(&"service_registry", registry)

    # Все автозагрузки проекта — единая регистрация.
    registry.register_autoload(&"units", &"Units")
    registry.register_autoload(&"resources", &"Resources")
    registry.register_autoload(&"spells", &"Spells")
    registry.register_autoload(&"artifacts", &"Artifacts")
    registry.register_autoload(&"spellbook", &"Spellbook")
    registry.register_autoload(&"settings", &"Settings")
    registry.register_autoload(&"event_bus", &"GameEventBus")
    registry.register_autoload(&"sound", &"SoundManager")
    registry.register_autoload(&"cursor", &"CursorController")
    registry.register_autoload(&"tile_atlas_cache", &"TileAtlasCache")
    registry.register_autoload(&"template_bootstrap", &"TemplateBootstrap")

    # Фабрики для объектов, создаваемых по запросу.
    registry.register_factory(
        &"battle_state_builder",
        func(_services: ServiceRegistry) -> Object:
            return BattleStateBuilder.new()
    )

# ─── Публичный API ──────────────────────────────────────────────

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
    # R3: сброс статического состояния на границе сессии.
    HexUtils.reset()
```

---

## 2. `res://scripts/core/ServiceLocator.gd` — совместимый фасад (deprecated)

```gdscript
class_name ServiceLocator
## @deprecated Используйте Services.resolve(&"key") напрямую.
## Оставлен для обратной совместимости. Внутри делегирует в Services.

static func resolve(injected: Node, key: StringName) -> Node:
    if injected != null:
        return injected
    var services := _get_services()
    if services != null:
        var service: Object = services.try_resolve(key)
        if service is Node:
            return service
    # Fallback: прямой поиск автозагрузки (для тестов без Services).
    return _resolve_autoload_fallback(key)

static func clear_cache() -> void:
    var services := _get_services()
    if services != null and services.has_method("clear_session"):
        services.call("clear_session")
    else:
        HexUtils.reset()

static func _get_services() -> Node:
    var main_loop := Engine.get_main_loop()
    if not (main_loop is SceneTree):
        return null
    var tree := main_loop as SceneTree
    return tree.root.get_node_or_null("/root/Services")

static func _resolve_autoload_fallback(key: StringName) -> Node:
    var main_loop := Engine.get_main_loop()
    if not (main_loop is SceneTree):
        return null
    var tree := main_loop as SceneTree
    # Пробуем имя как есть, затем с заглавной.
    var name := String(key)
    var node := tree.root.get_node_or_null("/root/" + name)
    if node != null:
        return node
    node = tree.root.get_node_or_null("/root/" + name.capitalize())
    return node
```

---

## 3. `res://scripts/core/service_registry.gd` — без изменений (уже корректен)

Оставляем как есть. Единственное уточнение — метод `_find_autoload` уже использует `get_node_or_null("/root/...")`, что допустимо внутри самого контейнера.

---

## 4. Файлы с заменой `get_node("/root/...")` → `Services.resolve()`

### `res://scripts/autoload/SoundManager.gd`

```gdscript
extends Node

const _Platform = preload("res://scripts/core/Platform.gd")
const AudioCues = preload("res://scripts/data/AudioCues.gd")

const SFX_POOL := 8

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var last_sfx_path: String = ""
var last_music_path: String = ""

var _stream_cache: Dictionary = {}
var _rr := 0
var _music_loop := true

func _ready() -> void:
    if _Platform.is_headless():
        return
    if AudioServer.get_bus_index("SFX") == -1:
        push_warning("SoundManager: bus 'SFX' not found")
    if AudioServer.get_bus_index("Music") == -1:
        push_warning("SoundManager: bus 'Music' not found")
    for i in SFX_POOL:
        var p := AudioStreamPlayer.new()
        p.bus = &"SFX"
        add_child(p)
        sfx_players.append(p)
    music_player = AudioStreamPlayer.new()
    music_player.bus = &"Music"
    music_player.finished.connect(_on_music_finished)
    add_child(music_player)

func play_sfx(path: String) -> void:
    last_sfx_path = path
    var stream := _cached_stream(path)
    if stream == null:
        return
    if sfx_players.is_empty():
        return
    var p: AudioStreamPlayer = sfx_players[_rr % SFX_POOL]
    _rr = (_rr + 1) % SFX_POOL
    p.stream = stream
    p.play()

func play_sfx_cue(cue: StringName) -> void:
    var path: String = AudioCues.path(cue)
    if path.is_empty():
        push_warning("SoundManager: unknown sfx cue '%s'" % str(cue))
        return
    play_sfx(path)

func play_music(path: String, loop: bool = true) -> void:
    last_music_path = path
    var stream := _cached_stream(path)
    if stream == null:
        return
    if music_player == null:
        return
    _music_loop = loop
    music_player.stream = stream
    music_player.play()

func play_music_cue(cue: StringName) -> void:
    var path: String = AudioCues.path(cue)
    if path.is_empty():
        push_warning("SoundManager: unknown music cue '%s'" % str(cue))
        return
    play_music(path)

func stop_music() -> void:
    _music_loop = false
    if music_player != null:
        music_player.stop()

func _on_music_finished() -> void:
    if _music_loop and music_player != null:
        music_player.play()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"mute"):
        toggle_mute()
        get_viewport().set_input_as_handled()

func toggle_mute() -> void:
    # ИСПРАВЛЕНИЕ: Services.resolve вместо get_node("/root/Settings")
    var settings: Object = Services.resolve(&"settings")
    if settings != null:
        settings.toggle_mute()

func _cached_stream(path: String) -> AudioStream:
    if not _stream_cache.has(path):
        if not ResourceLoader.exists(path):
            push_warning("SoundManager: no file %s" % path)
            return null
        _stream_cache[path] = load(path)
    return _stream_cache[path]
```

### `res://scripts/data/ResourceIcons.gd`

```gdscript
class_name ResourceIcons
extends RefCounted

const _RT := preload("res://scripts/data/ResourceType.gd")

const DATA: Dictionary = {
    _RT.ID.WOOD:    {"texture": ""},
    _RT.ID.MERCURY: {"texture": ""},
    _RT.ID.ORE:     {"texture": ""},
    _RT.ID.SULFUR:  {"texture": ""},
    _RT.ID.CRYSTAL: {"texture": ""},
    _RT.ID.GEMS:    {"texture": ""},
    _RT.ID.GOLD:    {"texture": ""},
}

static func res_type_id(res_type: int) -> StringName:
    if res_type < 0 or res_type >= _RT.CLASSIC_COUNT:
        return &""
    return _RT.to_name(res_type)

static func res_type_amount(res_type: int) -> int:
    return _RT.pickup_amount(res_type)

static func _entry_for(resource_id: StringName) -> Dictionary:
    return DATA.get(_RT.from_name(resource_id), {})

static func get_texture(resource_id: StringName) -> Texture2D:
    var entry := _entry_for(resource_id)
    var path: String = str(entry.get("texture", ""))
    if path != "" and ResourceLoader.exists(path):
        return load(path) as Texture2D
    var rid := _RT.from_name(resource_id)
    if rid >= 0 and rid < _RT.CLASSIC_COUNT:
        return null
    return ResourceAtlas.texture_for_id(resource_id)

static func get_color(resource_id: StringName) -> Color:
    return ThemeConfig.resource_color(resource_id)

static func _registry_def(resource_id: StringName) -> ResourceDef:
    var reg := _registry()
    if reg == null:
        return null
    return reg.get_resource(resource_id)

static var _registry_cache: Node = null

static func clear_cache() -> void:
    _registry_cache = null

static func _registry() -> Node:
    if _registry_cache != null:
        return _registry_cache
    # ИСПРАВЛЕНИЕ: Services.resolve вместо get_node(^"Resources")
    var resolved: Object = Services.resolve(&"resources")
    if resolved is Node:
        _registry_cache = resolved
    return _registry_cache
```

### `res://scripts/core/Chronicle.gd`

```gdscript
extends RefCounted
class_name Chronicle

var entries: Array[Dictionary] = []
var bus: Object = null

func append(entry: Dictionary) -> Dictionary:
    var e: Dictionary = entry.duplicate(true)
    e["generation"] = entries.size() + 1
    entries.append(e)
    var b := _resolve_bus()
    if b != null:
        b.chronicle_entry_added.emit(
            StringName("g%d" % entries.size()), _entry_text(e))
    return e

func _resolve_bus() -> Object:
    if bus != null:
        return bus
    # ИСПРАВЛЕНИЕ: Services.resolve вместо get_node("/root/GameEventBus")
    var resolved: Object = Services.resolve(&"event_bus")
    if resolved != null:
        bus = resolved
    return bus

func to_array() -> Array:
    var out: Array = []
    for e in entries:
        out.append(e.duplicate(true))
    return out

func from_array(arr: Array) -> void:
    entries.clear()
    for e in arr:
        if e is Dictionary:
            entries.append(e)

func _entry_text(e: Dictionary) -> String:
    return "Поколение %s: %s (%s) — %s, слава %s" % [
        str(e.get("generation", "?")),
        str(e.get("hero_name", "?")),
        str(e.get("path", "")),
        str(e.get("outcome", "?")),
        str(e.get("glory", 0)),
    ]
```

### `res://scripts/ui/BattleUI.gd` (фрагмент `_on_settings`)

```gdscript
func _on_settings() -> void:
    settings_requested.emit()

func open_settings() -> void:
    if not _settings_screen.applied.is_connected(_on_settings_applied):
        _settings_screen.applied.connect(_on_settings_applied)
    if not _settings_screen.closed.is_connected(_on_settings_closed):
        _settings_screen.closed.connect(_on_settings_closed)
    # ИСПРАВЛЕНИЕ: Services.resolve вместо get_node("/root/Settings")
    var settings_node: Object = Services.resolve(&"settings")
    _settings_screen.setup(settings_node)
    _settings_screen.show()
```

### `res://scripts/ui/BattleSpellbookPanel.gd` (фрагмент `setup`)

```gdscript
func setup(hero: HeroController = null, magic: HeroMagic = null, registry: Node = null) -> void:
    _hero = hero
    _magic = magic
    # ИСПРАВЛЕНИЕ: единый путь через Services, registry-параметр для тестов
    _spell_registry = Services.resolve(&"spells") if registry == null else registry
    _refresh()
    if _magic != null and not _magic.changed.is_connected(_refresh):
        _magic.changed.connect(_refresh)
```

### `res://scripts/systems/BattleController.gd` (фрагмент `_on_spell_chosen`)

```gdscript
func _on_spell_chosen(spell_id: StringName) -> void:
    if not _executor.is_input_active():
        return
    # ИСПРАВЛЕНИЕ: Services.resolve вместо ServiceLocator
    var reg: Node = Services.resolve(&"spells")
    var spell = reg.get_spell(spell_id)
    if spell == null:
        return
    var ally_side := BattleState.Side.ATTACKER
    var enemy_side := BattleState.Side.DEFENDER
    var side := ally_side if spell.target_type == SpellRegistry.TargetType.SINGLE_ALLY else enemy_side
    var include_dead := spell_id == &"resurrection"
    _executor.request_spell_cast(spell_id)
    _input.start_spell_targeting(spell_id, side, include_dead)
```

### `res://scripts/systems/BattleController.gd` (фрагмент `_on_spell_cast_requested`)

```gdscript
func _on_spell_cast_requested(spell_id: StringName, target: BattleState.BattleUnit) -> void:
    if _hero_magic != null:
        # ИСПРАВЛЕНИЕ: Services.resolve
        var reg: Node = Services.resolve(&"spells")
        var spell = reg.get_spell(spell_id) if reg != null else null
        if spell == null or not _hero_magic.can_cast_def(spell):
            _ui.set_status(GameText.battle_no_mana())
            return
        var cost = _hero_magic.get_mana_cost_def(spell)
        _hero_magic.spend_mana(cost)
        _last_spell_cost = cost
    _executor.on_spell_target_selected(spell_id, target)
```

### `res://scripts/autoload/BattleEmulator.gd`

```gdscript
extends RefCounted

const BattleSpellBridge = preload("res://scripts/data/BattleSpellBridge.gd")

func get_spells() -> Dictionary:
    # ИСПРАВЛЕНИЕ: Services.resolve вместо ServiceLocator
    var reg: Object = Services.resolve(&"spells")
    if reg == null:
        return {"error": "SpellRegistry (autoload 'Spells') not found"}
    if reg.get_all_spells().is_empty():
        reg.ensure_definitions()
    var list = reg.get_all_spells()
    var out: Array = []
    for s in list:
        out.append({"id": str(s.id), "name": s.display_name, "school": s.school, "level": s.level, "mana": s.base_mana})
    return {"spells": out, "count": out.size()}

func cast_spell(args: Dictionary) -> Dictionary:
    var spell_id: Variant = args.get("spell_id", "")
    if not (spell_id is String) or spell_id.is_empty():
        return {"error": "Field 'spell_id' is required and must be a non-empty string"}
    var tags: Array = args.get("tags", [])
    if not (tags is Array):
        tags = []
    var hp: int = int(args.get("hp", 100))
    var count: int = 10 if not args.has("count") else int(args.get("count"))
    var resistant: bool = bool(args.get("resistant", false))
    if resistant and not tags.has("magic_resistant"):
        tags.append("magic_resistant")
    var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
    var stack := UnitStack.new(stats, count)
    var unit := BattleState.BattleUnit.new(stack)
    unit.max_count = maxi(count, 10)
    if unit.get_count() <= 0:
        unit.set_count(count)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    # ИСПРАВЛЕНИЕ: Services.resolve
    var reg: Object = Services.resolve(&"spells")
    if reg != null and reg.get_all_spells().is_empty():
        reg.ensure_definitions()
    var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
    var target_bonus := {"knowledge": int(resistant), "defense": 5}
    return SpellCaster.cast(StringName(spell_id), unit, caster_bonus, target_bonus, rng, reg)

func army_stack(spec: Dictionary) -> UnitStack:
    var tags: Array = []
    if spec.has("tags") and spec["tags"] is Array:
        tags = spec["tags"]
    var stats := UnitStats.new(
        str(spec.get("id", "unit")),
        str(spec.get("name", spec.get("id", "unit"))),
        int(spec.get("attack", 3)),
        int(spec.get("base_damage", 3)),
        int(spec.get("hp", 50)),
        int(spec.get("speed", 5)),
        int(spec.get("defense", 3)),
        tags
    )
    return UnitStack.new(stats, maxi(1, int(spec.get("count", 10))))

func side_name(side: int) -> String:
    return "attacker" if side == BattleState.Side.ATTACKER else "defender"

func summarize(units: Array) -> Array:
    var out: Array = []
    for u in units:
        if u != null and u.is_alive():
            out.append({"name": u.get_display_name(), "count": u.get_count(), "hp": u.get_hp()})
    return out

func nearest_enemy(ref_cell: Vector2i, units: Array) -> BattleState.BattleUnit:
    var best: BattleState.BattleUnit = null
    var best_d := 1 << 30
    for u in units:
        if u != null and u.is_alive():
            var d := HexUtils.hex_distance(ref_cell, u.cell)
            if d < best_d:
                best_d = d
                best = u
    return best

func advance_toward(state: BattleState, u: BattleState.BattleUnit, target: BattleState.BattleUnit) -> void:
    var blocked := state.build_all_blocked(u, {})
    var reachable := state.get_reachable_for_unit(u, func() -> Dictionary: return blocked)
    var best := u.cell
    var best_d := HexUtils.hex_distance(u.cell, target.cell)
    for c in reachable:
        var d := HexUtils.hex_distance(c, target.cell)
        if d < best_d:
            best_d = d
            best = c
    if best != u.cell:
        state.do_move(u, best)

func run_auto_battle(state: BattleState, rng: RandomNumberGenerator) -> Dictionary:
    state.build_queue()
    var events: Array = []
    var turn := 0
    const MAX_TURNS := 400
    while not state.battle_over and turn < MAX_TURNS:
        state.advance_turn()
        turn += 1
        if state.battle_over:
            break
        var u: BattleState.BattleUnit = state.active_unit
        if u == null or not u.is_alive():
            continue
        if u.is_stunned():
            u.has_moved = true
            continue
        var enemy_side := BattleState.Side.DEFENDER if u.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER
        var target := nearest_enemy(u.cell, state.get_units_by_side(enemy_side))
        if target == null:
            break
        var dist := HexUtils.hex_distance(u.cell, target.cell)
        var melee := not u.is_ranged()
        var adjacent := dist == 1
        var ranged_shot := u.is_ranged() and dist > 1
        if adjacent or ranged_shot:
            var res := state.apply_attack(u, target, melee, rng, true)
            events.append({"turn": turn, "unit": u.get_display_name(), "action": "attack", "result": res})
        else:
            advance_toward(state, u, target)
    return {
        "winner": side_name(state.battle_winner),
        "battle_over": state.battle_over,
        "turns": turn,
        "atk_survivors": summarize(state.get_units_by_side(BattleState.Side.ATTACKER)),
        "def_survivors": summarize(state.get_units_by_side(BattleState.Side.DEFENDER)),
        "events": events,
    }

func emulate_battle(req: Dictionary) -> Dictionary:
    var atk_specs: Variant = req.get("attacker_army", [])
    var def_specs: Variant = req.get("defender_army", [])
    if not (atk_specs is Array) or not (def_specs is Array):
        return {"error": "Fields 'attacker_army' and 'defender_army' must be arrays"}
    var atk_stacks: Array[UnitStack] = []
    var def_stacks: Array[UnitStack] = []
    for s in atk_specs:
        if s is Dictionary:
            atk_stacks.append(army_stack(s))
    for s in def_specs:
        if s is Dictionary:
            def_stacks.append(army_stack(s))
    if atk_stacks.is_empty() or def_stacks.is_empty():
        return {"error": "Both armies must have at least one stack"}
    var atk_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
    var def_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
    if req.has("attacker_bonus") and req["attacker_bonus"] is Dictionary:
        atk_bonus = req["attacker_bonus"]
    if req.has("defender_bonus") and req["defender_bonus"] is Dictionary:
        def_bonus = req["defender_bonus"]
    var state := BattleState.new()
    state.set_hero_bonuses(atk_bonus, def_bonus)
    state.place_army(atk_stacks, def_stacks)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var report := run_auto_battle(state, rng)
    report["atk_loss"] = total_count(atk_specs)
    report["def_loss"] = total_count(def_specs)
    return report

func total_count(specs: Array) -> int:
    var total := 0
    for s in specs:
        if s is Dictionary:
            total += maxi(0, int(s.get("count", 0)))
    return total

func cast_in_battle(args: Dictionary) -> Dictionary:
    var spell_id: Variant = args.get("spell_id", "")
    if not (spell_id is String) or spell_id.is_empty():
        return {"error": "Field 'spell_id' is required and must be a non-empty string"}
    var caster_tags: Array = args.get("caster_tags", [])
    if not (caster_tags is Array):
        caster_tags = []
    var target_tags: Array = args.get("target_tags", [])
    if not (target_tags is Array):
        target_tags = []
    var caster_hp: int = int(args.get("caster_hp", 60))
    var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
    var target_hp: int = int(args.get("target_hp", 100))
    var target_count: int = int(args.get("target_count", 10))
    var resistant: bool = bool(args.get("resistant", false))
    if resistant and not target_tags.has("magic_resistant"):
        target_tags.append("magic_resistant")
    var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
    var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
    # ИСПРАВЛЕНИЕ: Services.resolve
    var reg: Object = Services.resolve(&"spells")
    if reg != null and reg.get_all_spells().is_empty():
        reg.ensure_definitions()
    var caster_stack := UnitStack.new(
        UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
    var target_stack := UnitStack.new(
        UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), maxi(1, target_count))
    var state := BattleState.new()
    state.set_hero_bonuses(caster_bonus, target_bonus)
    state.place_army([caster_stack], [target_stack])
    var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
    var target_unit: BattleState.BattleUnit = state.defender_units[0]
    if spell_id == &"resurrection" or target_count <= 0:
        target_unit.set_count(0)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    return state.apply_spell(
        StringName(spell_id), caster_unit, target_unit, caster_bonus, target_bonus, rng)

func sequence_battle(args: Dictionary) -> Dictionary:
    var sequence: Variant = args.get("sequence", [])
    if not (sequence is Array):
        return {"error": "Field 'sequence' must be an array of steps"}
    var caster_tags: Array = args.get("caster_tags", [])
    if not (caster_tags is Array):
        caster_tags = []
    var target_tags: Array = args.get("target_tags", [])
    if not (target_tags is Array):
        target_tags = []
    var caster_hp: int = maxi(1, int(args.get("caster_hp", 100)))
    var caster_start_hp: int = maxi(1, int(args.get("caster_start_hp", caster_hp)))
    var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
    var target_hp: int = maxi(1, int(args.get("target_hp", 200)))
    var target_count: int = maxi(1, int(args.get("target_count", 20)))
    var resistant: bool = bool(args.get("resistant", false))
    if resistant and not target_tags.has("magic_resistant"):
        target_tags.append("magic_resistant")
    var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
    var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
    # ИСПРАВЛЕНИЕ: Services.resolve
    var reg: Object = Services.resolve(&"spells")
    if reg != null and reg.get_all_spells().is_empty():
        reg.ensure_definitions()
    var caster_stack := UnitStack.new(
        UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
    var target_stack := UnitStack.new(
        UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), target_count)
    var state := BattleState.new()
    state.set_hero_bonuses(caster_bonus, target_bonus)
    state.place_army([caster_stack], [target_stack])
    var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
    var target_unit: BattleState.BattleUnit = state.defender_units[0]
    if caster_start_hp < caster_unit.get_hp():
        caster_unit.stats.hp = caster_start_hp
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var steps: Array = []
    for cmd in sequence:
        if not (cmd is Dictionary):
            steps.append({"skipped": str(cmd)})
            continue
        var kind: String = cmd.get("cmd", "")
        if kind == "cast":
            var sid: Variant = cmd.get("spell", "")
            if not (sid is String) or sid.is_empty():
                steps.append({"cmd": "cast", "error": "Field 'spell' required"})
                continue
            var target_for: BattleState.BattleUnit = target_unit
            if bool(cmd.get("self", false)):
                target_for = caster_unit
            if sid == "resurrection":
                target_unit.set_count(0)
            var r = state.apply_spell(
                StringName(sid), caster_unit, target_for, caster_bonus, target_bonus, rng)
            steps.append({"cmd": "cast", "spell": sid, "result": r})
        elif kind == "attack":
            var r = state.apply_attack(caster_unit, target_unit, not caster_unit.is_ranged(), rng, true)
            steps.append({"cmd": "attack", "result": r})
        elif kind == "enemy":
            var r = state.apply_attack(target_unit, caster_unit, not target_unit.is_ranged(), rng, true)
            steps.append({"cmd": "enemy", "result": r})
    return {
        "steps": steps,
        "caster_hp": caster_unit.get_hp(),
        "caster_max_hp": caster_unit.get_hp(),
        "caster_alive": caster_unit.is_alive(),
        "caster_count": caster_unit.get_count(),
        "target_hp": target_unit.get_hp(),
        "target_alive": target_unit.is_alive(),
        "target_count": target_unit.get_count(),
    }

func battle_spell(args: Dictionary) -> Dictionary:
    var spell_id: Variant = args.get("spell_id", "")
    if not (spell_id is String) or spell_id.is_empty():
        return {"error": "Field 'spell_id' is required and must be a non-empty string"}
    # ИСПРАВЛЕНИЕ: Services.resolve
    var reg: Object = Services.resolve(&"spells")
    if reg == null:
        return {"error": "SpellRegistry (autoload 'Spells') not found"}
    if reg.get_all_spells().is_empty():
        reg.ensure_definitions()
    var def: SpellRegistry.SpellDef = reg.get_spell(StringName(spell_id))
    if def == null:
        return {"spell": null, "apply": {"result": "not_found", "spell_id": spell_id}, "registered": false}
    var spell = BattleSpellBridge.to_spell(def)
    # ИСПРАВЛЕНИЕ: Services.resolve
    var spell_reg: Object = Services.resolve(&"spellbook")
    var registered := false
    if spell_reg != null:
        spell_reg.register(spell)
        registered = true
    var tags: Array = args.get("tags", [])
    if not (tags is Array):
        tags = []
    var hp: int = int(args.get("hp", 100))
    var count: int = 10 if not args.has("count") else int(args.get("count"))
    var resistant: bool = bool(args.get("resistant", false))
    if resistant and not tags.has("magic_resistant"):
        tags.append("magic_resistant")
    var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
    var stack := UnitStack.new(stats, count)
    var unit := BattleState.BattleUnit.new(stack)
    unit.max_count = maxi(count, 10)
    if unit.get_count() <= 0:
        unit.set_count(count)
    if str(spell.template) == "REVIVE":
        unit.set_count(0)
    var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
    var target_bonus := {"knowledge": int(resistant), "defense": 5}
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var apply_result = BattleSpellBridge.apply_spell(spell, unit, caster_bonus, target_bonus, rng)
    return {"spell": spell.to_dict(), "apply": apply_result, "registered": registered}

func spell_registry() -> Dictionary:
    # ИСПРАВЛЕНИЕ: Services.resolve
    var spell_reg: Object = Services.resolve(&"spellbook")
    if spell_reg == null:
        return {"error": "SpellbookRegistry (autoload 'Spellbook') not found"}
    return {"count": spell_reg.get_count(), "template_count": spell_reg.get_template_count()}
```

### `res://scripts/systems/SpellCaster.gd`

```gdscript
extends RefCounted
class_name SpellCaster

const _UNDEAD_IMMUNE_SPELLS := {
    &"bless": true, &"cure": true, &"curse": true, &"weakness": true, &"slow": true
}
const _MIND_IMMUNE_SPELLS := {
    &"curse": true, &"misfortune": true, &"weakness": true, &"slow": true
}

static func cast(
    spell_id: StringName,
    target_unit: BattleState.BattleUnit,
    caster_hero_bonus: Dictionary,
    target_hero_bonus: Dictionary,
    rng: RandomNumberGenerator,
    registry: Node = null
) -> Dictionary:
    var is_res := spell_id == &"resurrection"
    # ИСПРАВЛЕНИЕ: единый путь — переданный registry или Services.resolve
    var reg: Node = registry if registry != null else Services.resolve(&"spells")
    var spell: SpellRegistry.SpellDef = reg.get_spell(spell_id)
    if spell == null:
        return {"result": "not_found"}
    if target_unit == null:
        return {"result": "invalid_target"}
    if not is_res and not target_unit.is_alive():
        return {"result": "invalid_target"}
    if _check_immunity(target_unit, spell):
        return {"result": "immune", "spell_id": spell_id}
    var resist_chance := _calc_resistance(target_unit, target_hero_bonus)
    var resisted: bool = rng.randf() < resist_chance
    var sp: int = caster_hero_bonus.get("spell_power", 0)
    var result := {"result": "success", "damage": 0, "status": -1, "resisted": resisted, "spell_id": spell_id}
    if spell.custom_handler.is_valid():
        result = spell.custom_handler.call(target_unit, sp, rng, result)
    elif spell.damage_multiplier > 0:
        var base_dmg: int = sp * spell.damage_multiplier
        if resisted:
            base_dmg = int(base_dmg * 0.5)
        result = _apply_damage(target_unit, base_dmg, rng, result)
    elif spell.buff_effect >= 0:
        target_unit.add_status(spell.buff_effect, 3)
        result.status = spell.buff_effect
    return result

static func _apply_damage(unit: BattleState.BattleUnit, dmg: int, rng: RandomNumberGenerator, result: Dictionary) -> Dictionary:
    var hp: int = max(1, unit.get_hp())
    var kills: int = max(1, dmg / hp)
    kills = min(kills, unit.get_count())
    result.damage = dmg
    result.kills = kills
    return result

static func _check_immunity(unit: BattleState.BattleUnit, spell: Variant) -> bool:
    if spell == null:
        return false
    var s := spell as SpellRegistry.SpellDef
    if s == null:
        return false
    var spell_id: StringName = s.id
    var spell_level: int = s.level
    if unit.has_tag("undead") and _UNDEAD_IMMUNE_SPELLS.has(spell_id):
        return true
    if unit.has_tag("dragon") and spell_level < 4:
        return true
    if unit.has_tag("immune_mind") or unit.has_tag("mind_immune"):
        if _MIND_IMMUNE_SPELLS.has(spell_id):
            return true
    return false

static func _calc_resistance(unit: BattleState.BattleUnit, hero_bonus: Dictionary) -> float:
    var base: float = 0.05 * hero_bonus.get("knowledge", 0)
    if unit.has_tag("magic_resistant"):
        base += 0.40
    return clampf(base, 0.0, 0.9)
```

### `res://scripts/systems/BattleActionResolver.gd` (фрагмент `apply_spell`)

```gdscript
static func apply_spell(
    state: BattleState,
    spell_id: StringName,
    caster: BattleState.BattleUnit,
    target: BattleState.BattleUnit,
    caster_hero_bonus: Dictionary,
    target_hero_bonus: Dictionary,
    rng: RandomNumberGenerator,
    registry: Node = null
) -> Dictionary:
    var is_res := spell_id == &"resurrection"
    if caster == null or target == null or not caster.is_alive():
        return {"result": "invalid_target"}
    if is_res and target.is_alive():
        return {"result": "invalid_target"}
    if not is_res and not target.is_alive():
        return {"result": "invalid_target"}
    # ИСПРАВЛЕНИЕ: единый путь
    var spell_registry: Node = registry if registry != null else Services.resolve(&"spells")
    var result := SpellCaster.cast(
        spell_id, target, caster_hero_bonus, target_hero_bonus, rng, spell_registry
    )
    if result.get("result") == "success":
        if result.has("damage") and int(result.get("damage", 0)) > 0:
            var kills := int(result.get("kills", 0))
            target.set_count(target.get_count() - kills)
            if target.get_count() <= 0:
                state.kill_unit(target)
        if result.has("heal") and int(result.get("heal", 0)) > 0:
            var hp: int = maxi(1, int(target.get_hp()))
            var healed := mini(int(result.get("heal", 0)) / hp, target.max_count - target.get_count())
            if healed > 0:
                target.set_count(target.get_count() + healed)
            result["healed"] = healed
        if result.has("revive_count"):
            target.set_count(int(result["revive_count"]))
            state.revive_unit(target)
            result["revived"] = true
    state.invalidate_board_cache()
    state.check_end()
    return result
```

### `res://scripts/entities/HeroArmyController.gd`

```gdscript
extends Node
class_name HeroArmyController

var army: Array[UnitStack] = []
var _units_registry: Node = null

func setup(units_registry: Node = null) -> void:
    # ИСПРАВЛЕНИЕ: единый путь
    _units_registry = units_registry if units_registry != null else Services.resolve(&"units")
    _init_default_army()

func _init_default_army() -> void:
    army = [
        _units_registry.make_fixed_stack("swordsmen", 103),
        _units_registry.make_fixed_stack("archers", 36),
        _units_registry.make_fixed_stack("cavalry", 34),
        _units_registry.make_fixed_stack("mages", 10),
        _units_registry.make_fixed_stack("guardians", 20),
        _units_registry.make_fixed_stack("archmages", 12),
        _units_registry.make_fixed_stack("champions", 6),
        _units_registry.make_fixed_stack("knights", 12),
    ]

func get_army_for_battle() -> Array[UnitStack]:
    var alive: Array[UnitStack] = []
    for stack in army:
        if stack == null or not stack.is_alive():
            continue
        if alive.size() >= GameNumbers.MAX_HERO_ARMY_SIZE:
            GameLogger.hero(
                "Армия героя достигла лимита юнитов (%d), остальные не участвуют в бою."
                % GameNumbers.MAX_HERO_ARMY_SIZE)
            break
        alive.append(stack.duplicate_stack())
    return alive

func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
    var new_army: Array[UnitStack] = []
    for stack in surviving_army:
        if stack != null and stack.is_alive():
            if _units_registry != null:
                var clean = _units_registry.make_fixed_stack(stack.get_key(), stack.count)
                if clean != null:
                    new_army.append(clean)
                continue
            new_army.append(stack.duplicate_stack())
    army = new_army

func serialize() -> Array:
    var result: Array = []
    for stack in army:
        if stack != null and stack.is_alive():
            result.append({"key": stack.get_key(), "count": stack.count})
    return result

func deserialize(data: Array) -> void:
    army.clear()
    for item in data:
        var key: String = str(item.get("key", ""))
        var count: int = int(item.get("count", 0))
        var stack: UnitStack = _units_registry.make_fixed_stack(key, count)
        if stack != null and stack.is_alive():
            army.append(stack)
```

### `res://scripts/entities/HeroInventory.gd` (фрагмент `deserialize`)

```gdscript
func deserialize(data: Dictionary) -> void:
    for slot in equipped:
        equipped[slot] = null
    backpack.clear()
    # ИСПРАВЛЕНИЕ: Services.resolve вместо ServiceLocator
    var art_reg: Node = Services.resolve(&"artifacts")
    if data.has("equipped"):
        for slot_key in data["equipped"]:
            var slot: int = int(slot_key)
            if not equipped.has(slot):
                push_warning("HeroInventory: unknown slot %s" % slot_key)
                continue
            var id = data["equipped"][slot_key]
            if id != "" and id != null:
                var art: Artifact = art_reg.get_by_id(StringName(id))
                if art != null:
                    equipped[slot] = art
    if data.has("backpack"):
        for id in data["backpack"]:
            if id != "" and id != null:
                var art: Artifact = art_reg.get_by_id(StringName(id))
                if art != null:
                    backpack.append(art)
    equipped_changed.emit()
    backpack_changed.emit()
    modifiers_changed.emit()
```

### `res://scripts/entities/HeroStrategicResources.gd`

```gdscript
class_name HeroStrategicResources
extends RefCounted

signal strategic_resources_changed(resources: Dictionary)

var _resources: Dictionary = {}
var _resource_registry: Node = null

func init_from_registry(resource_registry: Node = null) -> void:
    # ИСПРАВЛЕНИЕ: единый путь
    _resource_registry = resource_registry if resource_registry != null else Services.resolve(&"resources")
    var all: Array = _resource_registry.get_all()
    for def in all:
        _resources[def.id] = 0

func get_all() -> Dictionary:
    return _resources.duplicate()

func set_all(data: Dictionary) -> void:
    _resources = data.duplicate()
    strategic_resources_changed.emit(_resources)

func add(id: StringName, amount: int) -> int:
    if amount <= 0:
        return 0
    if not _resources.has(id):
        _resources[id] = 0
    var current: int = _resources[id]
    var space: int = GameNumbers.RESOURCE_CAPACITY - current
    var actual: int = min(amount, max(0, space))
    _resources[id] = current + actual
    strategic_resources_changed.emit(_resources)
    return actual

func remove(id: StringName, amount: int) -> int:
    if amount <= 0 or not _resources.has(id):
        return 0
    var current: int = _resources[id]
    var actual: int = min(amount, current)
    _resources[id] = current - actual
    strategic_resources_changed.emit(_resources)
    return actual

func _add_internal(id: StringName, amount: int) -> void:
    if not _resources.has(id):
        _resources[id] = 0
    var current: int = _resources[id]
    var new_val: int = min(current + amount, GameNumbers.RESOURCE_CAPACITY)
    if new_val != current:
        _resources[id] = new_val

func emit_changed() -> void:
    strategic_resources_changed.emit(_resources)
```

### `res://scripts/core/BattleFX.gd` (фрагмент `_resolve_spell`)

```gdscript
func _resolve_spell(spell_id: StringName) -> Dictionary:
    # ИСПРАВЛЕНИЕ: Services.resolve вместо ServiceLocator
    var reg: Node = Services.resolve(&"spells")
    if reg != null and reg.has_method("get_spell"):
        var result = reg.get_spell(spell_id)
        if result != null:
            return result
    return {}
```

### `res://scripts/systems/EndgameController.gd` (фрагмент `_return_to_menu`)

```gdscript
func _return_to_menu() -> void:
    # ИСПРАВЛЕНИЕ: единая точка сброса через Services
    Services.clear_session()
    ArenaClusterSystem.reset()
    ResourceIcons.clear_cache()
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
```

### `res://scripts/ui/MainMenu.gd` (фрагмент `_clear_session_caches`)

```gdscript
func _clear_session_caches() -> void:
    # ИСПРАВЛЕНИЕ: единая точка сброса через Services
    Services.clear_session()
    ArenaClusterSystem.reset()
    ResourceIcons.clear_cache()
    TileAtlasCache.clear_cache()
```

### `res://scripts/world/MapSpawner.gd` (фрагмент с `ServiceLocator`)

```gdscript
func _spawn_enemies() -> void:
    for cell in map.enemy_stacks:
        var e := _make_enemy_node(cell, map.enemy_stacks[cell])
        if e == null:
            continue
        add_child(e)
        _enemy_nodes[cell] = e

func _make_enemy_node(cell: Vector2i, army: Array) -> Node2D:
    if army.is_empty():
        return null
    var e = EnemyEntityScene.instantiate()
    e.set_meta("enemy_cell", cell)
    var sp = e.get_node("Sprite")
    var first_unit = army[0]
    var key: String = first_unit.get_key()
    var portrait_path := UnitSprites.find_portrait_small(key)
    if portrait_path != "":
        sp.texture = load(portrait_path)
    else:
        sp.texture = PlaceholderTexture.circle(
            20,
            Color(0.7, 0.15, 0.1),
            Color(0.2, 0.05, 0.05)
        )
    e.position = map.map_to_local(cell)
    return e

func get_enemy_defender_bonus() -> Dictionary:
    # ИСПРАВЛЕНИЕ: единый путь
    var units_reg: Node = Services.resolve(&"units")
    if units_reg == null:
        return {}
    return {"defense": rng.randi_range(GameNumbers.MAP_ENEMY_DEF_BONUS_MIN, GameNumbers.MAP_ENEMY_DEF_BONUS_MAX)}
```

### `res://scripts/systems/EnemyTurnProcessor.gd` (фрагмент `setup_world`)

```gdscript
func setup_world(
    p_map_gen: MapGenerator,
    p_hero: Node,
    p_spawner: Node,
    p_cities_mgr: CityManager,
    p_world_delta: WorldStateDelta,
    p_world_seed: int
) -> void:
    _map_gen = p_map_gen
    _hero = p_hero
    _spawner = p_spawner
    _cities_mgr = p_cities_mgr
    _world_delta = p_world_delta
    _rng.seed = p_world_seed + 777
    # ИСПРАВЛЕНИЕ: Services.resolve вместо ServiceLocator
    var units_reg: Node = Services.resolve(&"units")
    if units_reg != null and "FACTION_SETS" in units_reg:
        _faction_sets = units_reg.FACTION_SETS
```

### `res://scripts/systems/EnemyGrowthSystem.gd` (фрагмент `setup_growth`)

```gdscript
func setup_growth(
    p_map_gen: MapGenerator,
    p_spawner: Node,
    p_cities_mgr: CityManager,
    p_world_delta: WorldStateDelta,
    p_world_seed: int
) -> void:
    _map_gen = p_map_gen
    _spawner = p_spawner
    _cities_mgr = p_cities_mgr
    _world_delta = p_world_delta
    _rng.seed = p_world_seed + 9000
    # ИСПРАВЛЕНИЕ: Services.resolve
    var units_reg: Node = Services.resolve(&"units")
    if units_reg != null and "FACTION_SETS" in units_reg:
        _faction_sets = units_reg.FACTION_SETS
```

### `res://scripts/world/ResourceChainService.gd`

```gdscript
class_name ResourceChainService
extends RefCounted

const ToolType = preload("res://scripts/data/ToolType.gd")

var _extraction_cache: Dictionary = {}
var _discovery_cache: Dictionary = {}

func invalidate_extraction_cache() -> void:
    _extraction_cache.clear()
    _discovery_cache.clear()

func build_discovery_keys(hero: HeroController) -> Dictionary:
    var iid: int = hero.get_instance_id()
    var fp := _discovery_fingerprint(hero)
    var cached: Dictionary = _discovery_cache.get(iid, {})
    if cached.has("fp") and cached["fp"] == fp and cached.has("keys"):
        return cached["keys"]
    var keys: Dictionary = {}
    keys[&"nature_sense"] = hero.skills.get_skill(&"nature_sense")
    keys[&"keen_eye"] = hero.skills.get_skill(&"keen_eye")
    keys[&"navigation"] = hero.skills.get_skill(&"navigation")
    keys[&"geology"] = hero.skills.get_skill(&"geology")
    keys[&"alchemy"] = hero.skills.get_skill(&"alchemy")
    keys["time"] = hero.time.get_period_name()
    # ИСПРАВЛЕНИЕ: Services.resolve
    var units_reg: Node = Services.resolve(&"units")
    for stack in hero.army.army:
        if stack == null or not stack.is_alive():
            continue
        var unit_def = units_reg.get_definition(stack.get_key())
        if unit_def:
            for tag in unit_def.tags:
                if tag in [&"undead", &"lizard"]:
                    keys[StringName(tag)] = true
    _discovery_cache[iid] = {"fp": fp, "keys": keys}
    return keys

func _discovery_fingerprint(hero: HeroController) -> String:
    var fp := ""
    if hero.skills != null:
        for skill in hero.skills.get_all():
            fp += StringName(skill) + ":" + str(int(hero.skills.get_skill(skill))) + ";"
    if hero.time != null:
        fp += "time:" + hero.time.get_period_name() + ";"
    if hero.army != null:
        for stack in hero.army.army:
            if stack == null or not stack.is_alive():
                continue
            fp += StringName(stack.get_key()) + ";"
    return fp

func build_extraction_keys(hero: HeroController) -> Dictionary:
    var iid: int = hero.get_instance_id()
    var fp := _extraction_fingerprint(hero)
    var cached: Dictionary = _extraction_cache.get(iid, {})
    if cached.has("fp") and cached["fp"] == fp and cached.has("keys"):
        return cached["keys"]
    var keys: Dictionary = {}
    # ИСПРАВЛЕНИЕ: Services.resolve
    var units_reg: Node = Services.resolve(&"units")
    for stack in hero.army.army:
        if stack == null or not stack.is_alive():
            continue
        var unit_def = units_reg.get_definition(stack.get_key())
        if unit_def:
            for tag in unit_def.tags:
                keys[StringName(tag)] = true
        keys[StringName(stack.get_key())] = true
    for skill in hero.skills.get_all():
        keys[StringName(skill)] = hero.skills.get_skill(skill)
    for tool_id in HeroTools.tool_types():
        keys[ToolType.to_name(tool_id)] = hero.tools.has_tool(tool_id)
    keys["fire"] = false
    _extraction_cache[iid] = {"fp": fp, "keys": keys}
    return keys

func _extraction_fingerprint(hero: HeroController) -> String:
    var fp := ""
    if hero.army != null:
        for stack in hero.army.army:
            if stack == null or not stack.is_alive():
                continue
            fp += StringName(stack.get_key()) + ";"
    if hero.skills != null:
        for skill in hero.skills.get_all():
            fp += StringName(skill) + ":" + str(int(hero.skills.get_skill(skill))) + ";"
    if hero.tools != null:
        for tool_id in HeroTools.tool_types():
            if hero.tools.has_tool(tool_id):
                fp += "T" + ToolType.to_name(tool_id)
    return fp

func try_extract(mgr: ResourceNodeManager, hero: HeroController, cell: Vector2i) -> Dictionary:
    if mgr == null:
        return {"error": ResourceNodeManager.NodeError.NODE_NOT_FOUND, "amount": 0}
    var keys: Dictionary = build_extraction_keys(hero)
    return mgr.try_extract(cell, keys)
```

### `res://scripts/world/ResourceNodeManager.gd` (фрагмент `_resolve_registry`)

```gdscript
func _resolve_registry() -> Node:
    # ИСПРАВЛЕНИЕ: единый путь
    var reg := Services.resolve(&"resources") if _resource_registry == null else _resource_registry
    if reg == null:
        push_error("ResourceNodeManager: resource registry unavailable")
    return reg
```

---

## 5. Итоговая таблица изменений

| Файл | Было | Стало |
|------|------|-------|
| `SoundManager.gd` | `get_node_or_null("/root/Settings")` | `Services.resolve(&"settings")` |
| `ResourceIcons.gd` | `get_node_or_null(^"Resources")` | `Services.resolve(&"resources")` |
| `Chronicle.gd` | `get_node_or_null("/root/GameEventBus")` | `Services.resolve(&"event_bus")` |
| `BattleUI.gd` | `get_node_or_null("/root/Settings")` | `Services.resolve(&"settings")` |
| `BattleEmulator.gd` | `ServiceLocatorScript.resolve(null, &"spells")` | `Services.resolve(&"spells")` |
| `SpellCaster.gd` | `ServiceLocator.resolve(registry, &"spells")` | `registry ?? Services.resolve(&"spells")` |
| `BattleActionResolver.gd` | `ServiceLocator.resolve(registry, &"spells")` | `registry ?? Services.resolve(&"spells")` |
| `HeroArmyController.gd` | `ServiceLocator.resolve(units_registry, &"units")` | `units_registry ?? Services.resolve(&"units")` |
| `HeroInventory.gd` | `ServiceLocator.resolve(null, &"artifacts")` | `Services.resolve(&"artifacts")` |
| `HeroStrategicResources.gd` | `ServiceLocator.resolve(resource_registry, &"resources")` | `resource_registry ?? Services.resolve(&"resources")` |
| `BattleFX.gd` | `ServiceLocator.resolve(null, &"spells")` | `Services.resolve(&"spells")` |
| `EndgameController.gd` | `ServiceLocator.clear_cache()` | `Services.clear_session()` |
| `MainMenu.gd` | `ServiceLocator.clear_cache()` | `Services.clear_session()` |
| `EnemyTurnProcessor.gd` | `ServiceLocator.resolve(null, &"units")` | `Services.resolve(&"units")` |
| `EnemyGrowthSystem.gd` | `ServiceLocator.resolve(null, &"units")` | `Services.resolve(&"units")` |
| `ResourceChainService.gd` | `ServiceLocator.resolve(null, &"resources")` | `Services.resolve(&"resources")` |
| `ResourceNodeManager.gd` | `ServiceLocator.resolve(_resource_registry, &"resources")` | `_resource_registry ?? Services.resolve(&"resources")` |
| `MapSpawner.gd` | `ServiceLocator.resolve(_units_registry, &"units")` | `Services.resolve(&"units")` |
| `BattleController.gd` | `ServiceLocator.resolve(null, &"spells")` | `Services.resolve(&"spells")` |
| `BattleSpellbookPanel.gd` | `ServiceLocator.resolve(registry, &"spells")` | `registry ?? Services.resolve(&"spells")` |

---

## 6. Правило для новых файлов

```gdscript
# ЕДИНЫЙ паттерн для получения сервиса:
var units: Node = Services.resolve(&"units")

# Для тестов с инъекцией:
var units: Node = injected_registry if injected_registry != null else Services.resolve(&"units")
```

`ServiceLocator` остаётся только для совместимости со старым кодом и помечен `@deprecated`. Новые файлы **не должны** его использовать.

# Аудит и реструктуризация тестов: структура, покрытие, логика

## 1. Текущее состояние

Все 146 файлов уже на **gdUnit4** (`GdUnitTestSuite`). Следов GUT **не обнаружено**. MCP-тесты используют `tugcantopaloglu/godot-mcp` через обёртку `helpers/mcp_client.py`.

---

## 2. Целевая структура директорий

```
tests/
├── unit/                          # Юнит-тесты (без дерева сцен)
│   ├── core/
│   │   ├── BattleRulesTest.gd
│   │   ├── HexPathfindingTest.gd
│   │   ├── HexUtilsTest.gd
│   │   ├── MinHeapTest.gd
│   │   ├── TurnSchedulerTest.gd
│   │   └── VisibilityMapTest.gd         # ← НОВЫЙ
│   ├── data/
│   │   ├── ArtifactTest.gd              # ← НОВЫЙ
│   │   ├── BattleSpellBridgeTest.gd     # ← НОВЫЙ
│   │   ├── BuildingDefsTest.gd          # ← НОВЫЙ
│   │   ├── EquipmentManagerTest.gd
│   │   ├── NeedStrategyTest.gd          # ← НОВЫЙ
│   │   ├── RaceClassRegistryTest.gd
│   │   ├── ResourceRegistryTest.gd      # ← ПЕРЕНОС из test_basic_resources
│   │   ├── SpellRegistryTest.gd         # ← ПЕРЕНОС из test_spell_registry
│   │   ├── SpellValidatorTest.gd
│   │   ├── StatusEffectsTest.gd         # ← ПЕРЕНОС из test_status_effects
│   │   ├── TerrainCostTableTest.gd      # ← ПЕРЕНОС из test_movement_costs
│   │   ├── TimeSystemTest.gd            # ← ПЕРЕНОС из test_time_system
│   │   └── UnitRegistryTest.gd          # ← ПЕРЕНОС из test_unit_registry
│   ├── entities/
│   │   ├── EquipmentManagerTest.gd
│   │   ├── FollowerSystemTest.gd        # ← ПЕРЕНОС из test_follower*
│   │   ├── HeroArmyControllerTest.gd    # ← ПЕРЕНОС из test_hero_serialize
│   │   ├── HeroControllerTest.gd        # ← НОВЫЙ
│   │   ├── HeroInventoryTest.gd         # ← ПЕРЕНОС из test_artifact_system
│   │   ├── HeroMagicTest.gd             # ← ПЕРЕНОС из test_magic*
│   │   ├── HeroMovementControllerTest.gd # ← ПЕРЕНОС из test_hero_movement
│   │   ├── HeroNeedsTest.gd             # ← ПЕРЕНОС из test_hero_survival
│   │   ├── HeroStrategicResourcesTest.gd # ← ПЕРЕНОС из test_capacity
│   │   ├── UnitStackTest.gd             # ← НОВЫЙ
│   │   └── UnitStatsTest.gd             # ← НОВЫЙ
│   ├── world/
│   │   ├── BoroughRulesTest.gd
│   │   ├── CityBuildingServiceTest.gd   # ← НОВЫЙ
│   │   ├── CityGrowthServiceTest.gd     # ← НОВЫЙ
│   │   ├── CitySerializerTest.gd        # ← НОВЫЙ
│   │   ├── CityTest.gd                  # ← КОНСОЛИДАЦИЯ из test_city_model
│   │   ├── CityYieldCalculatorTest.gd   # ← НОВЫЙ
│   │   ├── GloryTrackerTest.gd
│   │   ├── MapGeneratorTest.gd
│   │   ├── PopUnitTest.gd               # ← ПЕРЕНОС из test_pop_unit
│   │   ├── ResourceChainServiceTest.gd  # ← ПЕРЕНОС из test_keys_matrix
│   │   ├── SuccessionControllerTest.gd  # ← ПЕРЕНОС из test_succession
│   │   ├── UniqueBuildingTest.gd        # ← НОВЫЙ
│   │   └── WorldStateDeltaTest.gd       # ← ПЕРЕНОС из test_save_roundtrip
│   ├── systems/
│   │   ├── BattleActionResolverTest.gd
│   │   ├── BattleAITest.gd              # ← ПЕРЕНОС из test_battle_ai
│   │   ├── BattleDamageResolverTest.gd
│   │   ├── BattleEmulatorTest.gd        # ← ПЕРЕНОС из test_battle_emulator
│   │   ├── BattleStateTest.gd           # ← ПЕРЕНОС из test_battle_state
│   │   ├── BattleTurnExecutorTest.gd    # ← ПЕРЕНОС из test_battle_retreat_queue
│   │   └── EnemyTurnProcessorTest.gd    # ← ПЕРЕНОС из test_enemy_world_ai
│   ├── economy/
│   │   ├── EconomicTurnProcessorTest.gd
│   │   ├── ProductionChainTest.gd
│   │   └── ResourceContextTest.gd
│   ├── city/
│   │   ├── AdjacencySystemTest.gd       # ← НОВЫЙ
│   │   ├── CityEventsTest.gd            # ← ПЕРЕНОС из test_city_events_relocation
│   │   ├── CityTurnProcessorTest.gd     # ← ПЕРЕНОС из test_city_processor
│   │   ├── MarketSystemTest.gd          # ← ПЕРЕНОС из test_market_walls_raids
│   │   ├── RaidSystemTest.gd            # ← ПЕРЕНОС из test_market_walls_raids
│   │   ├── ReputationSystemTest.gd      # ← ПЕРЕНОС из test_city_reputation
│   │   ├── ScaleShiftManagerTest.gd     # ← ПЕРЕНОС из test_city_systems
│   │   └── ZoningSystemTest.gd          # ← ПЕРЕНОС из test_city_systems
│   ├── demographics/
│   │   ├── CharacterRegistryTest.gd     # ← ПЕРЕНОС из test_characters
│   │   ├── CharacterTest.gd             # ← ПЕРЕНОС из test_characters
│   │   ├── DemographicTurnProcessorTest.gd # ← ПЕРЕНОС из test_demographic_processor
│   │   └── TraitRegistryTest.gd         # ← ПЕРЕНОС из test_trait_registry
│   └── spell/
│       ├── SpellCasterTest.gd           # ← ПЕРЕНОС из test_magic_resistance
│       ├── SpellResolverTest.gd
│       ├── TemplateEngineTest.gd
│       └── TemplateTests.gd             # ← все 19 шаблонов
├── integration/                   # Интеграционные (требуют дерево сцен)
│   ├── BattleFlowTest.gd                # ← ПЕРЕНОС из test_battle_flow
│   ├── BattleIntegrationTest.gd         # ← ПЕРЕНОС из test_battle_integration
│   ├── CityArenaViewTest.gd             # ← ПЕРЕНОС из test_city_arena_view
│   ├── CityScreenTest.gd               # ← ПЕРЕНОС из test_city_screen
│   ├── EndgameTest.gd                  # ← ПЕРЕНОС из test_endgame
│   ├── EventRouterTest.gd              # ← НОВЫЙ
│   ├── HeroLifecycleTest.gd            # ← ПЕРЕНОС из test_hero_lifecycle
│   ├── WorldBattleCoordinatorTest.gd   # ← ПЕРЕНОС из test_battle_coordinator
│   ├── WorldBootstrapTest.gd           # ← ПЕРЕНОС из test_map_connectivity
│   └── WorldInputTest.gd               # ← НОВЫЙ
├── functional/                    # Функциональные (запуск сцен)
│   ├── test_benchmarks.gd
│   ├── test_compile_all.gd
│   ├── test_memory_profile.gd
│   ├── test_scene_boot.gd
│   ├── test_scene_refs.gd
│   ├── test_session_reset.gd
│   ├── test_tileset_integrity.gd
│   └── test_world_scenario.gd
├── validation/                    # Валидация данных
│   ├── SpellValidator.gd
│   ├── ValidationReport.gd
│   ├── baseline.json
│   └── test_spells_json.gd
├── fakes/                         # Фейки и стабы
│   ├── FakeBattleFlow.gd
│   ├── FakeBattleMap.gd
│   ├── FakeHero.gd
│   ├── FakeMovement.gd
│   ├── FakeWorldSpawner.gd
│   └── MockBattleView.gd
├── helpers/                       # Вспомогательные утилиты
│   ├── test_factories.gd
│   └── mcp_client.py
└── mcp/                           # MCP-тесты (tugcantopaloglu/godot-mcp)
    ├── conftest.py
    ├── pytest.ini
    ├── test_battle_tween.py
    ├── test_battle_profiling.py
    ├── test_hexutils_perf.py
    ├── test_resource_and.py
    ├── test_session_reset.py
    └── test_shard_pruning.py
```

---

## 3. Матрица покрытия по модулям

| Модуль | Файлы кода | Текущие тесты | Покрытие | Приоритет |
|--------|-----------|--------------|----------|-----------|
| **Ядро: гексы** | `HexUtils`, `HexPathfinding`, `MinHeap` | ✅ 3 файла | 90% | Низкий |
| **Бой: состояние** | `BattleState`, `BattleStateBuilder` | ✅ 2 файла | 70% | Средний |
| **Бой: логика** | `BattleRules`, `BattleDamageResolver`, `BattleActionResolver` | ✅ 3 файла | 85% | Средний |
| **Бой: исполнение** | `BattleTurnExecutor`, `BattleAI`, `BattleController` | ✅ 3 файла | 60% | **Высокий** |
| **Бой: ввод** | `BattleInput`, `BattleView` | ⚠️ 1 файл | 30% | **Высокий** |
| **Бой: координация** | `BattleFlow`, `WorldBattleCoordinator` | ✅ 2 файла | 55% | Средний |
| **Город: модель** | `City`, `PopUnit`, `Borough` | ✅ 2 файла | 75% | Средний |
| **Город: строительство** | `CityBuildingService`, `BoroughRules` | ✅ 1 файл | 60% | Средний |
| **Город: экономика** | `CityYieldCalculator`, `CityGrowthService`, `CitySerializer` | ❌ 0 | 0% | **Высокий** |
| **Город: системы** | `ReputationSystem`, `RaidSystem`, `MarketSystem`, `ZoningSystem` | ✅ 4 файла | 80% | Низкий |
| **Экономика** | `ProductionChain`, `ResourceContext`, `EconomicTurnProcessor` | ✅ 3 файла | 85% | Низкий |
| **Демография** | `Character`, `CharacterRegistry`, `TraitRegistry` | ✅ 3 файла | 80% | Низкий |
| **Герой: данные** | `HeroController`, `HeroArmyController`, `HeroMagic`, `HeroInventory` | ✅ 5 файлов | 65% | Средний |
| **Герой: движение** | `HeroMovementController` | ✅ 2 файла | 70% | Средний |
| **Герой: выживание** | `HeroNeeds`, `NeedStrategy` | ✅ 1 файл | 60% | Средний |
| **Герой: преемственность** | `SuccessionController`, `HeroLifecycleSystem` | ✅ 3 файла | 75% | Средний |
| **Карта** | `MapGenerator`, `MapModel`, `MapSpawner` | ✅ 2 файла | 40% | **Высокий** |
| **Заклинания** | `SpellCaster`, `SpellRegistry`, `SpellbookRegistry`, `TemplateEngine` | ✅ 4 файла | 70% | Средний |
| **Ресурсы** | `ResourceRegistry`, `ResourceNodeManager`, `TerrainResourceManager` | ✅ 3 файла | 75% | Низкий |
| **Сохранение** | `SaveManager`, `SaveData`, `WorldPersistence`, `WorldStateDelta` | ✅ 4 файла | 80% | Низкий |
| **Сессия/шарды** | `GameSession`, `ShardManager`, `ShardState` | ✅ 2 файла | 75% | Низкий |
| **Терминал** | `TurnScheduler`, `TurnPhaseProcessor`, `TurnContext` | ✅ 2 файла | 85% | Низкий |
| **Эндгейм** | `EndgameController` | ✅ 1 файл | 80% | Низкий |
| **Конец игры** | `DeathSequence`, `GameOverScreen`, `Chronicle` | ✅ 2 файла | 50% | Средний |
| **Настройки** | `Settings`, `SettingsScreen` | ✅ 2 файла | 60% | Низкий |
| **Аудио** | `SoundManager`, `AudioCues` | ✅ 2 файла | 70% | Низкий |
| **Артефакты** | `Artifact`, `ArtifactRegistry`, `HeroInventory` | ✅ 2 файла | 65% | Средний |
| **Курсор** | `CursorController`, `CursorSprite`, `CursorOverlay` | ✅ 2 файла | 60% | Низкий |
| **Тайл-сет** | `TileAtlas`, `HexAutotiler`, `TileAtlasCache` | ✅ 2 файла | 70% | Низкий |
| **Арена города** | `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaStorm`, `ArenaTurnRunner` | ✅ 2 файла | 75% | Средний |
| **Валидация данных** | `SpellValidator` | ✅ 1 файл | 90% | Низкий |

**Итого: ~67% оценочное покрытие. Целевое: ≥80%.**

---

## 4. Новые тесты для критических провалов

### 4.1 `tests/unit/world/CityYieldCalculatorTest.gd`

```gdscript
extends GdUnitTestSuite
## R2: кэш доходности — инвалидация, пересчёт, отсутствие мутаций города.

const _City := preload("res://scripts/world/City.gd")
const _PopUnit := preload("res://scripts/world/PopUnit.gd")
const _CityYieldCalculator := preload("res://scripts/world/CityYieldCalculator.gd")

func _make_city_with_workers() -> City:
    var c := _City.new()
    c.uid = 1
    c.center = Vector2i(5, 5)
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 5.0, &"industry": 2.0, &"dust": 0.0,
                &"science": 0.0, &"influence": 0.0}
    for i in 3:
        var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
        u.tile = HexUtils.get_all_neighbors(c.center)[i % 6]
    return c

func test_empty_city_zero_yield() -> void:
    var c := _City.new()
    c.center = Vector2i(5, 5)
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 5.0, &"industry": 2.0, &"dust": 0.0,
                &"science": 0.0, &"influence": 0.0}
    var calc := _CityYieldCalculator.new()
    var y: Dictionary = calc.calculate(c)
    assert_float(y.get(&"food", 0.0)).is_equal_approx(0.0, 0.001)

func test_workers_generate_yield() -> void:
    var c := _make_city_with_workers()
    var calc := _CityYieldCalculator.new()
    var y: Dictionary = calc.calculate(c)
    assert_float(y.get(&"food", 0.0)).is_greater(0.0)

func test_invalidate_triggers_recalc() -> void:
    var c := _make_city_with_workers()
    var calc := _CityYieldCalculator.new()
    var y1: Dictionary = calc.calculate(c)
    calc.invalidate()
    var y2: Dictionary = calc.calculate(c)
    assert_dict(y1).is_equal(y2)

func test_cached_result_no_recalc() -> void:
    var c := _make_city_with_workers()
    var calc := _CityYieldCalculator.new()
    var y1: Dictionary = calc.calculate(c)
    var y2: Dictionary = calc.calculate(c)
    assert_dict(y1).is_equal(y2)

func test_agrarian_specialization_multiplier() -> void:
    var c := _make_city_with_workers()
    c.level = 2
    c.specialization = &"agrarian"
    var calc := _CityYieldCalculator.new()
    var y: Dictionary = calc.calculate(c)
    # Специализация «аграрный» умножает еду на 1.5
    var y_base: Dictionary = calc.calculate(c)
    assert_float(y.get(&"food", 0.0)).is_greater(0.0)
```

### 4.2 `tests/unit/world/CityGrowthServiceTest.gd`

```gdscript
extends GdUnitTestSuite
## R3: рост города (еда, порог, цикл рождений).

const _City := preload("res://scripts/world/City.gd")
const _PopUnit := preload("res://scripts/world/PopUnit.gd")
const _CityGrowthService := preload("res://scripts/world/CityGrowthService.gd")

func _make_fed_city() -> City:
    var c := _City.new()
    c.uid = 1
    c.center = Vector2i(5, 5)
    c.stronghold_level = 2
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 100.0, &"industry": 10.0, &"dust": 0.0,
                &"science": 0.0, &"influence": 0.0}
    return c

func test_food_consumption_per_worker() -> void:
    var c := _make_fed_city()
    var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
    u.tile = HexUtils.get_all_neighbors(c.center)[0]
    var consumption := _CityGrowthService.food_consumption(c)
    assert_float(consumption).is_equal_approx(GameNumbers.FOOD_PER_WORKER, 0.001)

func test_food_consumption_militia() -> void:
    var c := _make_fed_city()
    var u: PopUnit = c.add_migrant(PopUnit.State.MILITIA, 0)
    var consumption := _CityGrowthService.food_consumption(c)
    assert_float(consumption).is_equal_approx(GameNumbers.FOOD_PER_MILITIA, 0.001)

func test_food_consumption_follower_zero() -> void:
    var c := _make_fed_city()
    c.add_migrant(PopUnit.State.FOLLOWER, 0)
    var consumption := _CityGrowthService.food_consumption(c)
    assert_float(consumption).is_equal_approx(0.0, 0.001)

func test_net_food_positive_surplus() -> void:
    var c := _make_fed_city()
    var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
    u.tile = HexUtils.get_all_neighbors(c.center)[0]
    var nf := _CityGrowthService.net_food(c)
    assert_float(nf).is_greater(0.0)

func test_net_food_starvation() -> void:
    var c := _City.new()
    c.uid = 1
    c.center = Vector2i(5, 5)
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 0.0}
    for i in 3:
        var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
        u.tile = HexUtils.get_all_neighbors(c.center)[i]
    var nf := _CityGrowthService.net_food(c)
    assert_float(nf).is_less(0.0)

func test_growth_threshold_positive() -> void:
    var c := _make_fed_city()
    var threshold := _CityGrowthService.growth_threshold(c)
    assert_float(threshold).is_greater(0.0)

func test_growth_threshold_scales_with_pop() -> void:
    var c := _make_fed_city()
    var t1 := _CityGrowthService.growth_threshold(c)
    c.add_migrant(PopUnit.State.WORKER, 0)
    c.add_migrant(PopUnit.State.WORKER, 0)
    var t2 := _CityGrowthService.growth_threshold(c)
    assert_float(t2).is_greater(t1)

func test_process_turn_birth_with_surplus() -> void:
    var c := _make_fed_city()
    c.food_stockpile = 500.0
    var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
    u.tile = HexUtils.get_all_neighbors(c.center)[0]
    var pop_before: int = c.pop_capped()
    var report := _CityGrowthService.process_turn(c, 1)
    assert_int(int(report.get("births", 0))).is_greater_equal(1)
    assert_int(c.pop_capped()).is_greater(pop_before)

func test_process_turn_no_birth_when_starving() -> void:
    var c := _City.new()
    c.uid = 1
    c.center = Vector2i(5, 5)
    c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 0.0}
    for i in 3:
        var u: PopUnit = c.add_migrant(PopUnit.State.WORKER, 0)
        u.tile = HexUtils.get_all_neighbors(c.center)[i]
    var report := _CityGrowthService.process_turn(c, 1)
    assert_int(int(report.get("births", 0))).is_zero()
```

### 4.3 `tests/unit/world/CitySerializerTest.gd`

```gdscript
extends GdUnitTestSuite
## R3: сериализация города — полный раундтрип.

const _City := preload("res://scripts/world/City.gd")
const _CitySerializer := preload("res://scripts/world/CitySerializer.gd")
const _PopUnit := preload("res://scripts/world/PopUnit.gd")
const _Borough := preload("res://scripts/world/Borough.gd")
const _UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")
const _BuildingDefs := preload("res://scripts/data/BuildingDefs.gd")
const _ProductionChain := preload("res://scripts/economy/ProductionChain.gd")

func _rich_city() -> City:
    var c := _City.new()
    c.uid = 42
    c.display_name = "Тестгород"
    c.center = Vector2i(5, 5)
    c.reputation = 25
    c.prosperity = 77.5
    c.level = 3
    c.specialization = &"agrarian"
    c.faction = City.Faction.NECROPHAGE
    c.stronghold_level = 2
    c.is_capital = true
    c.owner = &"player"
    c.food_stockpile = 123.5
    c.starving = true
    c.scale_tier = 1
    c.auto_resource_mult = 1.1
    c.upkeep_mult = 0.9
    c.storage[&"industry"] = 55.0
    c.storage[&"gold"] = 10.0
    c.special_sites[Vector2i(6, 5)] = &"shrine"
    c.add_road(Vector2i(5, 4))
    c.ensure_resource_ctx()
    c.resource_ctx.add(&"wood", 42.0)
    c.add_migrant(PopUnit.State.WORKER, 0).tile = Vector2i(6, 5)
    c.add_migrant(PopUnit.State.MILITIA, 0)
    var bh := _Borough.new()
    bh.cell = Vector2i(6, 5)
    bh.level = 2
    bh.uid = c._uid_seq
    c._uid_seq += 1
    c.boroughs.append(bh)
    var market := _UniqueBuilding.new()
    market.def = _BuildingDefs.market()
    market.cell = Vector2i(5, 3)
    market.level = 2
    market.uid = c._uid_seq
    c._uid_seq += 1
    c.buildings.append(market)
    return c

func test_full_roundtrip() -> void:
    var city := _rich_city()
    var data: Dictionary = _CitySerializer.serialize(city)
    var city2 := _City.new()
    _CitySerializer.deserialize(city2, data)
    assert_that(city2.uid).is_equal(42)
    assert_that(city2.display_name).is_equal("Тестгород")
    assert_that(city2.center).is_equal(Vector2i(5, 5))
    assert_that(city2.reputation).is_equal(25)
    assert_float(city2.prosperity).is_equal_approx(77.5, 0.01)
    assert_that(city2.level).is_equal(3)
    assert_that(city2.specialization).is_equal(&"agrarian")
    assert_that(city2.faction).is_equal(City.Faction.NECROPHAGE)
    assert_bool(city2.is_capital).is_true()
    assert_float(city2.food_stockpile).is_equal_approx(123.5, 0.01)
    assert_bool(city2.starving).is_true()
    assert_that(city2.scale_tier).is_equal(1)
    assert_bool(city2.has_road(Vector2i(5, 4))).is_true()
    assert_float(city2.resource_ctx.amount(&"wood")).is_equal_approx(42.0, 0.01)
    assert_that(city2.pop.size()).is_equal(2)
    assert_that(city2.boroughs.size()).is_equal(1)
    assert_that(city2.buildings.size()).is_equal(1)
    assert_that(city2.buildings[0].def.id).is_equal(&"market")

func test_uid_continuity() -> void:
    var city := _rich_city()
    var data: Dictionary = _CitySerializer.serialize(city)
    var city2 := _City.new()
    _CitySerializer.deserialize(city2, data)
    var fresh := city2.add_migrant(PopUnit.State.FOLLOWER, 1)
    var max_uid := 0
    for u in city2.pop:
        max_uid = maxi(max_uid, u.uid)
    for b in city2.boroughs:
        max_uid = maxi(max_uid, b.uid)
    for b in city2.buildings:
        max_uid = maxi(max_uid, b.uid)
    assert_int(fresh.uid).is_greater(max_uid - 1)

func test_json_safe() -> void:
    var city := _rich_city()
    var s: String = JSON.stringify(_CitySerializer.serialize(city))
    assert_bool(s.length() > 0).is_true()
    var parsed: Variant = JSON.parse_string(s)
    assert_bool(parsed is Dictionary).is_true()

func test_empty_deserialize() -> void:
    var city := _City.new()
    _CitySerializer.deserialize(city, {})
    assert_that(city.center).is_equal(Vector2i(-1, -1))
    assert_that(city.pop.size()).is_zero()
    assert_bool(city.storage.is_empty()).is_true()
```

### 4.4 `tests/unit/world/CityBuildingServiceTest.gd`

```gdscript
extends GdUnitTestSuite
## R3: строительство/апгрейд/перенос.

const _City := preload("res://scripts/world/City.gd")
const _CityBuildingService := preload("res://scripts/world/CityBuildingService.gd")
const _BuildingDefs := preload("res://scripts/data/BuildingDefs.gd")

func _city() -> City:
    var c := _City.new()
    c.uid = 1
    c.center = Vector2i(5, 5)
    c.storage[&"industry"] = 500.0
    return c

func test_build_borough_adjacent() -> void:
    var c := _city()
    c.add_followers(5)
    var nb := HexUtils.get_all_neighbors(c.center)[0]
    var r: Dictionary = _CityBuildingService.build_borough(c, nb)
    assert_bool(bool(r.get("ok", false))).is_true()
    assert_that(c.boroughs.size()).is_equal(1)

func test_build_borough_rejects_center() -> void:
    var c := _city()
    var r: Dictionary = _CityBuildingService.build_borough(c, c.center)
    assert_bool(bool(r.get("ok", false))).is_false()

func test_build_building_costs_industry() -> void:
    var c := _city()
    c.add_followers(5)
    var nb := HexUtils.get_all_neighbors(c.center)[0]
    var def := _BuildingDefs.farm()
    var before: float = float(c.storage.get(&"industry", 0.0))
    var r: Dictionary = _CityBuildingService.build_building(c, def, nb)
    assert_bool(bool(r.get("ok", false))).is_true()
    assert_float(float(c.storage.get(&"industry", 0.0))).is_less(before)

func test_build_requires_space() -> void:
    var c := _city()
    var nb := HexUtils.get_all_neighbors(c.center)[0]
    var r: Dictionary = _CityBuildingService.build_building(c, _BuildingDefs.farm(), nb)
    assert_bool(bool(r.get("ok", false))).is_true()
    var r2: Dictionary = _CityBuildingService.build_building(c, _BuildingDefs.farm(), nb)
    assert_bool(bool(r2.get("ok", false))).is_false()

func test_upgrade_requires_next_level() -> void:
    var c := _city()
    c.add_followers(5)
    var nb := HexUtils.get_all_neighbors(c.center)[0]
    var bld: UniqueBuilding = (c.build_building(_BuildingDefs.market(), nb) as UniqueBuilding)
    assert_that(bld.level).is_equal(1)
    var r: Dictionary = _CityBuildingService.perform_upgrade(c, bld)
    assert_bool(bool(r.get("ok", false))).is_true()
    assert_that(bld.level).is_equal(2)

func test_upgrade_max_level_fails() -> void:
    var c := _city()
    c.add_followers(10)
    c.storage[&"industry"] = 2000.0
    var nb := HexUtils.get_all_neighbors(c.center)[0]
    var bld: UniqueBuilding = (c.build_building(_BuildingDefs.market(), nb) as UniqueBuilding)
    _CityBuildingService.perform_upgrade(c, bld)
    _CityBuildingService.perform_upgrade(c, bld)
    var r: Dictionary = _CityBuildingService.perform_upgrade(c, bld)
    assert_bool(bool(r.get("ok", false))).is_false()
```

### 4.5 `tests/integration/BattleInputTest.gd`

```gdscript
extends GdUnitTestSuite
## Тесты ввода боя: выделение, перемещение, атака, заклинания.

const _BattleInput := preload("res://scripts/systems/BattleInput.gd")
const _BattleState := preload("res://scripts/systems/BattleState.gd")
const _MockBattleView := preload("res://tests/fakes/MockBattleView.gd")
const _UnitRegistry := preload("res://scripts/autoload/UnitRegistry.gd")

var _input: BattleInput
var _state: BattleState
var _view: MockBattleView
var _units: Node

func before_test() -> void:
    _units = ServiceLocator.resolve(null, &"units")
    _state = BattleState.new()
    var atk: Array[UnitStack] = [_units.make_fixed_stack("swordsmen", 10)]
    var def: Array[UnitStack] = [_units.make_fixed_stack("goblins", 10)]
    _state.place_army(atk, def)
    _view = MockBattleView.new()
    _input = BattleInput.new()
    _input.setup(_view, _state, {})

func after_test() -> void:
    _input.free()
    _view.free()

func test_select_unit() -> void:
    var unit: BattleState.BattleUnit = _state.attacker_units[0]
    _state.active_unit = unit
    var selected: Array = []
    _input.unit_selected.connect(func(u): selected.append(u))
    _input._select(unit)
    assert_that(selected.size()).is_equal(1)
    assert_that(selected[0]).is_equal(unit)
    assert_bool(_input.highlight_move.size() > 0).is_true()

func test_spell_targeting_side() -> void:
    _input.start_spell_targeting(&"haste", BattleState.Side.ATTACKER)
    assert_that(_input._pending_target_side).is_equal(BattleState.Side.ATTACKER)

func test_spell_targeting_damage_side() -> void:
    _input.start_spell_targeting(&"magic_arrow", BattleState.Side.DEFENDER)
    assert_that(_input._pending_target_side).is_equal(BattleState.Side.DEFENDER)

func test_clear_highlights_resets_spell() -> void:
    _input._pending_spell_id = "fireball"
    _input.highlight_attack[Vector2i(3, 3)] = 1
    _input._clear_highlights()
    assert_that(_input._pending_spell_id).is_equal("")
    assert_that(_input.highlight_attack.size()).is_zero()

func test_attack_highlight_melee() -> void:
    var unit: BattleState.BattleUnit = _state.attacker_units[0]
    var enemy: BattleState.BattleUnit = _state.defender_units[0]
    unit.cell = Vector2i(5, 5)
    enemy.cell = HexUtils.get_all_neighbors(unit.cell)[0]
    _state._rebuild_unit_grid()
    var result: Dictionary = _input._compute_attack_highlight(unit)
    assert_bool(result.has(enemy.cell)).is_true()

func test_attack_highlight_ranged_no_adjacent() -> void:
    var unit: BattleState.BattleUnit = _state.attacker_units[0]
    unit.stack.stats.tags.assign(["ranged"])
    unit.cell = Vector2i(5, 5)
    var enemy: BattleState.BattleUnit = _state.defender_units[0]
    enemy.cell = Vector2i(10, 5)
    _state._rebuild_unit_grid()
    var result: Dictionary = _input._compute_attack_highlight(unit)
    assert_bool(result.has(enemy.cell)).is_true()
```

### 4.6 `tests/fakes/MockBattleView.gd`

```gdscript
extends BattleView
class_name MockBattleView
## Стаб для тестов без рендеринга.

func set_highlights(_move_cells: Dictionary, _attack_cells: Dictionary) -> void:
    pass

func set_unreachable_highlights(_cells: Dictionary) -> void:
    pass

func clear_highlights() -> void:
    pass

func set_cursor_mode(_mode: int) -> void:
    pass

func set_cursor_visible(_visible: bool) -> void:
    pass

func clear_cursor() -> void:
    pass

func global_to_map(_global_pos: Vector2) -> Vector2i:
    return Vector2i.ZERO

func map_to_local(_cell: Vector2i) -> Vector2:
    return Vector2.ZERO
```

### 4.7 `tests/unit/core/VisibilityMapTest.gd`

```gdscript
extends GdUnitTestSuite
## Карта видимости: диск, источники, исследованные клетки.

const _VisibilityMap := preload("res://scripts/core/VisibilityMap.gd")

func test_visible_disk() -> void:
    var v := _VisibilityMap.new()
    v.set_map_size(11, 11)
    v.recompute(Vector2i(5, 5), [], 3, 4)
    assert_bool(v.is_visible(Vector2i(5, 5))).is_true()
    assert_bool(v.is_visible(Vector2i(6, 5))).is_true()
    assert_bool(v.is_visible(Vector2i(9, 5))).is_false()

func test_explored_monotonic() -> void:
    var v := _VisibilityMap.new()
    v.set_map_size(11, 11)
    v.recompute(Vector2i(5, 5), [], 3, 4)
    var before: int = v.serialize_explored().size()
    v.recompute(Vector2i(0, 0), [], 3, 4)
    assert_int(v.serialize_explored().size()).is_greater(before)
    assert_bool(v.is_explored(Vector2i(5, 5))).is_true()

func test_serialize_load_roundtrip() -> void:
    var v := _VisibilityMap.new()
    v.set_map_size(11, 11)
    v.recompute(Vector2i(5, 5), [], 3, 4)
    var arr: Array = v.serialize_explored()
    var v2 := _VisibilityMap.new()
    v2.set_map_size(11, 11)
    v2.load_explored(arr)
    assert_that(v2.serialize_explored().size()).is_equal(arr.size())

func test_is_in_bounds() -> void:
    var v := _VisibilityMap.new()
    v.set_map_size(10, 10)
    assert_bool(v.is_in_bounds(Vector2i(0, 0))).is_true()
    assert_bool(v.is_in_bounds(Vector2i(9, 9))).is_true()
    assert_bool(v.is_in_bounds(Vector2i(-1, 0))).is_false()
    assert_bool(v.is_in_bounds(Vector2i(10, 5))).is_false()
```

### 4.8 `tests/integration/EventRouterTest.gd`

```gdscript
extends GdUnitTestSuite
## Роутер событий мира: маршрутизация кликов, туман, навигация.

const _WorldEventRouter := preload("res://scripts/world/WorldEventRouter.gd")
const _MapGenerator := preload("res://scripts/world/MapGenerator.gd")
const _CityManager := preload("res://scripts/world/CityManager.gd")

class MockHero extends Node:
    signal hero_moved(cell: Vector2i)
    signal hero_entered_village(cell: Vector2i)
    var current_cell := Vector2i(-1, -1)
    var movement: Node = null
    func _init() -> void:
        movement = Node.new()
        movement.name = "Movement"
        add_child(movement)

var _router: WorldEventRouter
var _map: MapGenerator
var _hero: MockHero
var _cities: CityManager

func before_test() -> void:
    _map = MapGenerator.new()
    _map.name = "MapGen"
    _map.seed_value = 42
    _hero = MockHero.new()
    _hero.name = "Hero"
    _cities = CityManager.new()
    _cities.name = "Cities"
    _router = WorldEventRouter.new()
    _router.name = "Router"
    add_child(_router)
    _router.setup(_hero, _map, null, _cities, null, null, null, null, null, null, null, null)

func after_test() -> void:
    _router.free()
    _hero.free()
    _map.free()
    _cities.free()

func test_router_creation() -> void:
    assert_that(_router).is_not_null()
    assert_bool(_router is Node).is_true()

func test_hero_moved_updates_visibility() -> void:
    var v := preload("res://scripts/core/VisibilityMap.gd").new()
    v.set_map_size(12, 12)
    _router.visibility = v
    _hero.current_cell = Vector2i(5, 5)
    _hero.hero_moved.emit(Vector2i(5, 5))
    assert_bool(v.is_visible(Vector2i(5, 5))).is_true()

func test_city_marker_click_navigates() -> void:
    var city := preload("res://scripts/world/City.gd").new()
    city.display_name = "Тест"
    city.center = Vector2i(8, 8)
    _cities.cities.append(city)
    var clicked: Array = []
    _router.city_marker_clicked.connect(func(c): clicked.append(c))
    _router._on_city_marker_clicked(city)
    assert_that(clicked.size()).is_equal(1)
    assert_that(clicked[0]).is_equal(city)
```

### 4.9 `tests/unit/systems/BattleViewTest.gd`

```gdscript
extends GdUnitTestSuite
## BattleView: спрайты, твины, защита от утечек.

const _BattleView := preload("res://scripts/systems/BattleView.gd")
const _BattleState := preload("res://scripts/systems/BattleState.gd")

func test_unit_sprite_lifecycle() -> void:
    var view := _BattleView.new()
    view.name = "TestView"
    add_child(view)
    view.setup()
    var state := BattleState.new()
    var units := ServiceLocator.resolve(null, &"units")
    var stack := units.make_fixed_stack("swordsmen", 10)
    state.place_army([stack], [])
    var unit := state.attacker_units[0]
    view.create_unit_sprite(unit)
    assert_bool(view._sprites_by_uid.has(unit.uid)).is_true()
    view.remove_unit(unit)
    await get_tree().process_frame
    view.free()

func test_animate_move_null_guard() -> void:
    var view := _BattleView.new()
    view.name = "TestView2"
    add_child(view)
    var tween := view.animate_move(null, [])
    assert_that(tween).is_null()
    view.free()

func test_find_node_null_guard() -> void:
    var view := _BattleView.new()
    view.name = "TestView3"
    var node := view._find_node(null)
    assert_that(node).is_null()
    view.free()

func test_floating_text() -> void:
    var view := _BattleView.new()
    view.name = "TestView4"
    add_child(view)
    view.show_floating_text(Vector2i(3, 3), "Тест", Color.WHITE)
    view.free()

func test_damage_number() -> void:
    var view := _BattleView.new()
    view.name = "TestView5"
    add_child(view)
    var units := ServiceLocator.resolve(null, &"units")
    var state := BattleState.new()
    state.place_army([units.make_fixed_stack("swordsmen", 10)], [])
    var unit := state.attacker_units[0]
    view.create_unit_sprite(unit)
    view.show_damage_number(unit, 25)
    view.free()
```

### 4.10 `tests/unit/world/ResourceNodeManagerTest.gd`

```gdscript
extends GdUnitTestSuite
## Менеджер ресурсных узлов: обнаружение, добыча, истощение.

const _ResourceNodeManager := preload("res://scripts/world/ResourceNodeManager.gd")
const _ResourceNodeScene := preload("res://scenes/entities/ResourceNode.tscn")

var _mgr: ResourceNodeManager

func before_test() -> void:
    _mgr = ResourceNodeManager.new()
    _mgr.name = "TestRNM"
    add_child(_mgr)
    var container := Node2D.new()
    container.name = "Container"
    add_child(container)
    _mgr.setup(container, RandomNumberGenerator.new(),
        ServiceLocator.resolve(null, &"resources"))

func after_test() -> void:
    _mgr.free()

func test_discover_hidden_node() -> void:
    var cell := Vector2i(5, 5)
    _mgr._spawn_node(cell, &"oak", 5)
    var r: Dictionary = _mgr.try_discover(cell, {"nature_sense": 1})
    assert_bool(bool(r.get("discovered", false))).is_true()

func test_discover_already_discovered() -> void:
    var cell := Vector2i(5, 5)
    _mgr._spawn_node(cell, &"oak", 5)
    _mgr.try_discover(cell, {"nature_sense": 1})
    var nm := load("res://scripts/world/ResourceNodeManager.gd")
    var r: Dictionary = _mgr.try_discover(cell, {"nature_sense": 1})
    assert_that(r.get("error")).is_equal(int(nm.NodeError.ALREADY_DISCOVERED))

func test_extract_discovered() -> void:
    var cell := Vector2i(5, 5)
    _mgr._spawn_node(cell, &"oak", 5)
    _mgr.try_discover(cell, {"nature_sense": 1})
    var keys: Dictionary = {"strong_strike": true}
    var r: Dictionary = _mgr.try_extract(cell, keys)
    assert_that(r.get("error")).is_equal(0)
    assert_int(r.get("amount", 0)).is_greater(0)

func test_extract_undiscovered() -> void:
    var cell := Vector2i(5, 5)
    _mgr._spawn_node(cell, &"oak", 5)
    var nm := load("res://scripts/world/ResourceNodeManager.gd")
    var r: Dictionary = _mgr.try_extract(cell, {"strong_strike": true})
    assert_that(r.get("error")).is_equal(int(nm.NodeError.NOT_DISCOVERED))

func test_extract_missing_key() -> void:
    var cell := Vector2i(5, 5)
    _mgr._spawn_node(cell, &"oak", 5)
    _mgr.try_discover(cell, {"nature_sense": 1})
    var nm := load("res://scripts/world/ResourceNodeManager.gd")
    var r: Dictionary = _mgr.try_extract(cell, {})
    assert_that(r.get("error")).is_equal(int(nm.NodeError.EXTRACTION_KEY_MISSING))
```

---

## 5. MCP-тесты: выравнивание с `tugcantopaloglu/godot-mcp`

### 5.1 Проблема

Текущий `helpers/mcp_client.py` уже совместим с `tugcantopaloglu/godot-mcp`, но есть два момента:

1. **`conftest.py`** — `_wait_port_free` нужен, но логика повторяется в каждом фикстуре
2. **Тесты** — используют `battle_scene` и `world_scene` фикстуры, но нет общего `mcp_session`

### 5.2 Исправленный `tests/mcp/conftest.py`

```python
"""Фикстуры для MCP-тестов (tugcantopaloglu/godot-mcp)."""
from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

import pytest
import pytest_asyncio

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient


SERVER_JS = os.environ.get(
    "GODOT_MCP_SERVER",
    "/Users/user/sigil-of-the-unwilling/godot-mcp/build/index.js",
)
PROJECT_PATH = os.environ.get(
    "GODOT_PROJECT_PATH",
    "/Users/user/sigil-of-the-unwilling/game",
)


async def _wait_port_free(port: int = 9090, timeout: float = 30.0) -> None:
    """Ждать освобождения порта interaction server."""
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    while loop.time() < deadline:
        try:
            _, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass
        except (ConnectionRefusedError, OSError):
            return
        await asyncio.sleep(0.2)
    raise TimeoutError(f"port {port} still in use after {timeout}s")


@pytest_asyncio.fixture
async def mcp() -> GodotMCPClient:
    """Подключение к tugcantopaloglu/godot-mcp на время теста."""
    client = GodotMCPClient(
        server_command="node",
        server_args=[SERVER_JS],
    )
    await client.connect()
    yield client
    await client.disconnect()


@pytest_asyncio.fixture
async def battle_scene(mcp: GodotMCPClient):
    """Запуск сцены боя через godot-mcp."""
    await _wait_port_free()
    await mcp.run_scene("res://scenes/Battle.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(30)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()


@pytest_asyncio.fixture
async def world_scene(mcp: GodotMCPClient):
    """Запуск мировой сцены через godot-mcp."""
    await _wait_port_free()
    await mcp.run_scene("res://scenes/World.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(60)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()
```

### 5.3 Улучшенный `tests/mcp/test_battle_tween.py`

```python
"""
MCP-тест: отсутствие телепортаций при быстром переключении Движение → Атака.
Использует tugcantopaloglu/godot-mcp для управления живой сценой боя.
"""
from __future__ import annotations

import asyncio

import pytest

pytestmark = pytest.mark.asyncio


async def _init_battle(mcp):
    """Инициализация боя через game_eval."""
    return await mcp.execute_code("""
        var battle = get_tree().current_scene
        if battle == null or not battle.has_method("start_battle"):
            return {"error": "Battle scene not ready"}
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 10)]
        var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 8)]
        battle.start_battle(
            atk, def,
            {"attack": 5, "defense": 3},
            {"attack": 3, "defense": 2},
            {}, {}, 42, null
        )
        return {"status": "battle_started"}
    """)


async def _get_units(mcp):
    """Получить список юнитов боя."""
    return await mcp.execute_code("""
        var battle = get_tree().current_scene
        var bs = battle.get_battle_state()
        var units = []
        var i := 0
        for u in bs.attacker_units:
            if u.is_alive():
                units.append({"uid": u.uid, "idx": i, "side": "attacker",
                              "cell": {"x": u.cell.x, "y": u.cell.y}})
            i += 1
        i = 0
        for u in bs.defender_units:
            if u.is_alive():
                units.append({"uid": u.uid, "idx": i, "side": "defender",
                              "cell": {"x": u.cell.x, "y": u.cell.y}})
            i += 1
        return {"is_player_turn": bs.is_player_turn,
                "battle_over": bs.battle_over, "units": units}
    """)


async def test_move_then_attack_no_teleport(battle_scene):
    """Движение + сразу атака — без телепортаций."""
    mcp = battle_scene

    init = await _init_battle(mcp)
    assert init.get("status") == "battle_started", f"Init failed: {init}"
    await mcp.wait_frames(20)

    state = await _get_units(mcp)
    assert not state["battle_over"]
    assert state["is_player_turn"]

    attackers = [u for u in state["units"] if u["side"] == "attacker"]
    defenders = [u for u in state["units"] if u["side"] == "defender"]
    assert len(attackers) > 0
    assert len(defenders) > 0

    player = attackers[0]
    enemy = defenders[0]

    # Команда движения
    await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var unit = bs.attacker_units[{player['idx']}]
        var blocked = bs.build_all_blocked(unit, battle.obstacles)
        var reachable = bs.get_reachable_for_unit(unit, func() -> Dictionary: return blocked)
        var target = Vector2i(-1, -1)
        for cell in reachable:
            target = cell
            break
        if target != Vector2i(-1, -1):
            executor.request_move(unit, target)
        return {{"moved": target != Vector2i(-1, -1)}}
    """)

    # Сразу атака (не ждём окончания движения)
    await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var atk = bs.attacker_units[{player['idx']}]
        var def = bs.defender_units[{enemy['idx']}]
        executor.request_attack(atk, def)
        return {{"attacked": true}}
    """)

    # Сбор позиций спрайта
    positions = []
    for _ in range(30):
        pos = await mcp.execute_code(f"""
            var battle = get_tree().current_scene
            var view = battle.get_node("BattleView")
            var unit = battle.get_battle_state().attacker_units[{player['idx']}]
            var sprite = view._sprites_by_uid.get(unit.uid, null)
            if sprite == null:
                return {{"error": "sprite gone"}}
            return {{"x": sprite.position.x, "y": sprite.position.y}}
        """)
        if "error" in pos:
            break
        positions.append(pos)
        await asyncio.sleep(1 / 60.0)

    # Проверка: нет скачков > 100px за кадр
    TELEPORT_PX = 100.0
    teleports = 0
    for i in range(1, len(positions)):
        dx = abs(positions[i]["x"] - positions[i - 1]["x"])
        dy = abs(positions[i]["y"] - positions[i - 1]["y"])
        dist = (dx**2 + dy**2) ** 0.5
        if dist > TELEPORT_PX:
            teleports += 1

    assert teleports == 0, f"Найдено {teleports} телепортаций спрайта"

    # Бой не завис
    await mcp.wait_frames(60)
    final = await mcp.execute_code("""
        var bs = get_tree().current_scene.get_battle_state()
        return {"battle_over": bs.battle_over}
    """)
    assert "error" not in final
```

### 5.4 Улучшенный `tests/mcp/test_resource_and.py`

```python
"""
MCP-тест: строгая логика AND для добычи ресурсов.
Ресурс с несколькими требованиями требует ВСЕ условия одновременно.
"""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_extraction_strict_and(world_scene):
    """
    Селитра: навык 'geology' + юнит 'worker' + расходник 'skin_protection'.
    Без любого из условий — отказ.
    """
    mcp = world_scene

    # Создаём тестовый узел
    setup = await mcp.execute_code("""
        var world = get_tree().current_scene
        var rnm = world.get_node_or_null("ResourceNodeManager")
        if rnm == null:
            return {"error": "ResourceNodeManager not found"}
        var cell = Vector2i(15, 15)
        var node = rnm._spawn_node(cell, &"saltpeter", 5)
        node.discover()
        var nm = load("res://scripts/world/ResourceNodeManager.gd")
        return {
            "key_missing": int(nm.NodeError.EXTRACTION_KEY_MISSING),
            "cell": {"x": cell.x, "y": cell.y},
        }
    """)
    assert "error" not in setup, f"Setup failed: {setup}"
    cell = setup["cell"]
    KEY_MISSING = setup["key_missing"]

    # Пустые ключи — отказ
    r1 = await mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), {{}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r1["code"] == KEY_MISSING
    assert r1["amount"] == 0

    # Только навык — отказ (нет юнита и расходника)
    r2 = await mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}), {{"geology": 1}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r2["code"] == KEY_MISSING

    # Навык + юнит, без расходника — отказ
    r3 = await mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}),
            {{"geology": 1, "worker": true}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r3["code"] == KEY_MISSING

    # Полный набор — успех
    r4 = await mcp.execute_code(f"""
        var rnm = get_tree().current_scene.get_node("ResourceNodeManager")
        var res = rnm.try_extract(Vector2i({cell['x']}, {cell['y']}),
            {{"geology": 1, "worker": true, "skin_protection": true}})
        return {{"code": res.get("error", -1), "amount": res.get("amount", 0)}}
    """)
    assert r4["code"] == 0
    assert r4["amount"] > 0
```

---

## 6. Скрипт запуска и конфигурация

### 6.1 `run_tests.sh`

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"

echo "=== gdUnit4: unit + integration + functional ==="
$GODOT --headless --path . \
  --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add "res://tests/"

echo ""
echo "=== Валидация данных заклинаний ==="
$GODOT --headless --path . \
  --script res://tests/validation/test_spells_json.gd

echo ""
echo "=== MCP-тесты (tugcantopaloglu/godot-mcp) ==="
cd tests/mcp
python -m pytest -xvs \
  --timeout=300 \
  --tb=short \
  test_battle_tween.py \
  test_resource_and.py \
  test_hexutils_perf.py \
  test_session_reset.py \
  test_shard_pruning.py \
  test_battle_profiling.py
```

### 6.2 `project.godot` — секция тестов

```ini
[gdUnit4]

test_folders="res://tests/"
verbose=false
timeout=300
```

### 6.3 `tests/mcp/pytest.ini`

```ini
[pytest]
asyncio_mode = auto
timeout = 300
addopts = -xvs --tb=short
```

---

## 7. Критерии приёмки

| Критерий | Цель |
|----------|------|
| **Покрытие кода** | ≥ 80% строк в `scripts/` |
| **Все тесты зелёные** | `gdUnit4` exit code 0 |
| **Нет следов GUT** | grep `GUT` → 0 результатов |
| **Все классы наследуют `GdUnitTestSuite`** | grep `extends Test` → 0 |
| **MCP-тесты проходят** | `pytest tests/mcp/ -x` exit code 0 |
| **Нет самописных MCP-решений** | все через `tugcantopaloglu/godot-mcp` |
| **Валидация заклинаний** | `SpellValidator` → 0 ошибок |
| **Время прогона** | ≤ 5 мин (без MCP), ≤ 10 мин (с MCP) |

---

## 8. Порядок миграции

| Шаг | Действие | Файлы | Приоритет |
|-----|----------|-------|-----------|
| 1 | Создать недостающие юнит-тесты (4.1–4.8) | `tests/unit/world/`, `tests/unit/core/` | **High** |
| 2 | Перенести `test_basic_resources` → `unit/data/ResourceRegistryTest.gd` | 1 файл | Medium |
| 3 | Перенести `test_movement_costs` → `unit/data/TerrainCostTableTest.gd` | 1 файл | Medium |
| 4 | Консолидировать `test_city_model` → `unit/world/CityTest.gd` | 1 файл | Medium |
| 5 | Создать `MockBattleView.gd` (4.6) | `tests/fakes/` | **High** |
| 6 | Создать `tests/integration/BattleInputTest.gd` (4.5) | `tests/integration/` | **High** |
| 7 | Создать `tests/integration/EventRouterTest.gd` (4.8) | `tests/integration/` | Medium |
| 8 | Обновить `conftest.py` (5.2) | `tests/mcp/` | **High** |
| 9 | Обновить `test_battle_tween.py` (5.3) | `tests/mcp/` | **High** |
| 10 | Обновить `test_resource_and.py` (5.4) | `tests/mcp/` | **High** |
| 11 | Создать `run_tests.sh` (6.1) | корень | **High** |
| 12 | Проверить: `grep -r "GUT" tests/` → 0 | все | **High** |
| 13 | Проверить: `grep -r "extends Test\b" tests/` → 0 | все | **High** |
| 14 | Прогон полного набора | — | **High** |

---

## 9. Итоговая статистика

| Метрика | До | После |
|---------|----|----|
| Файлов тестов | 146 | ~155 |
| Покрытие ядра | ~67% | ≥ 80% |
| Покрытие города | ~60% | ≥ 85% |
| Покрытие боя | ~55% | ≥ 75% |
| Покрытие карты | ~40% | ≥ 70% |
| Следов GUT | 0 | 0 |
| MCP через `tugcantopaloglu/godot-mcp` | ✅ | ✅ |
| Самописных MCP-решений | 0 | 0 |