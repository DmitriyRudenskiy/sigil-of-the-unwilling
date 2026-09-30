# Аудит проекта «Sigil of the Unwilling» (Godot 4.7 / GDScript)

---

## 1. Архитектура

### 1.1 Сильные стороны

| Аспект | Оценка | Комментарий |
|---|---|---|
| Компонентная модель героя | ✅ Хорошо | `HeroComponent` + 14 подкомпонентов, чёткий контракт `setup_hero / initialize / end_turn / serialize / deserialize` |
| Разделение боя | ✅ Хорошо | `BattleState` (данные) → `BattleActionResolver` (логика) → `BattleTurnExecutor` (оркестрация) → `BattleView` (рендер) → `BattleInput` (ввод) |
| Service Locator | ✅ Приемлемо | `ServiceRegistry` + `Services.resolve()`, ленивая регистрация автозагрузок |
| Event Bus | ✅ Хорошо | `GameEventBus` — 30+ типизированных сигналов, подписки/отписки в `CursorController`, `EndgameController` |
| Turn Pipeline | ✅ Хорошо | `TurnScheduler` → `TurnPhaseProcessor` с приоритетами, расширяемо |
| Фабрики и builder | ✅ Хорошо | `BattleStateBuilder`, `HeroModelFactory`, `TestFactories` |

### 1.2 Критические проблемы

#### P1: `mcp_interaction_server.gd` — монолит на ~3000 строк

```
_handle_command() → match на 80+ команд → каждый _cmd_* инлайн
```

**Нарушения:** SRP, OCP. Добавление новой команды требует правки `match` + добавление метода в тот же файл.

**Решение:** паттерн «команда-обработчик» + реестр.

#### P2: `CityTurnProcessor._process_city()` — God Method (~80 строк, 8 подсистем)

Обрабатывает: масштаб → ёмкости → зоны → нарушения зон → репутацию → миграцию → рабочих → процветание → рейды → специализацию → события. Любое изменение затрагивает один метод.

#### P3: Дублирование `test_borough_rules.gd`

Два файла с одинаковым содержанием:
- `tests/systems/city/test_borough_rules.gd`
- `tests/unit/world/test_borough_rules.gd`

#### P4: Связность `WorldController` ↔ `HeroLifecycleSystem`

`HeroLifecycleSystem` получает 12 аргументов в `setup()`. Это признак недостающего объекта-контекста.

### 1.3 Диаграмма зависимостей (упрощённая)

```
WorldController
├── WorldBootstrap (фабрика)
│   ├── MapGenerator → MapModel / MapRenderer / MapSpawner
│   ├── CityManager → City → Borough / UniqueBuilding / PopUnit
│   ├── WorldBattleCoordinator → BattleFlow → BattleController
│   ├── WorldEventRouter
│   ├── EndgameController
│   └── WorldUIManager → AdventureUI / CityScreen / MarkerLayer
├── HeroController (компоненты)
│   ├── HeroMovementComponent → HeroMovementController
│   ├── HeroArmyComponent → HeroArmyController
│   ├── HeroMagicComponent → HeroMagic
│   ├── HeroInventoryComponent → HeroInventory
│   └── ... (14 шт.)
└── SaveManager / WorldPersistence / WorldStateDelta
```

---

## 2. Лучшие практики

### 2.1 Идиомы Godot / GDScript

| Проблема | Файл | Строка (примерно) | Приоритет |
|---|---|---|---|
| `extends Node` без `class_name` для MCP-сервера — ок, но нет `@tool`-гарда | `mcp_interaction_server.gd` | 1 | Low |
| `await get_tree().process_frame` в цикле без защиты от `tree == null` | `_cmd_wait`, `_cmd_mouse_drag` | ~600 | Medium |
| `Input.parse_input_event()` без проверки `is_inside_tree()` | `_cmd_click`, `_cmd_key_press` | ~550 | Medium |
| `TileMapLayer` используется вместо `TileMap` (Godot 4.3+) — корректно для 4.7 | `BattleView`, `MapGenerator` | — | ✅ Ок |
| `HexUtils` — `class_name` + `extends RefCounted` + только `static func` — идиоматично | `HexUtils.gd` | — | ✅ Ок |

### 2.2 SOLID / DRY / KISS

| Принцип | Нарушение | Где | Приоритет |
|---|---|---|---|
| **S**RP | `_handle_command` — 80+ веток в одном `match` | `mcp_interaction_server.gd` | **High** |
| **S**RP | `_process_city` — 8 подсистем | `CityTurnProcessor.gd` | **High** |
| **O**CP | Добавление команды MCP = правка `match` | `mcp_interaction_server.gd` | **High** |
| **D**RY | `_json_to_variant` дублирует логику `_json_to_variant_for_property` | `mcp_interaction_server.gd` | Medium |
| **D**RY | `test_borough_rules.gd` × 2 | `tests/` | Medium |
| **K**ISS | `_indent_code` — ручной парсер табов/пробелов для eval | `mcp_interaction_server.gd` | Medium |
| **Y**GI | 19 шаблонов заклинаний, но в бою используется 6 | `TemplateEngine`, `t01..t19` | Low |

### 2.3 Обработка ошибок

| Проблема | Риск | Приоритет |
|---|---|---|
| `_send_response_raw` не проверяет результат `put_data()` | Тихая потеря ответа клиенту | **High** |
| `_cmd_eval` — `GDScript.reload()` без `try/catch` (в GDScript нет, но `reload` возвращает `Error`) — обрабатывается, ок | — | ✅ |
| `SaveManager.load_slot` — `JSON.parse` без проверки `json.data is Dictionary` до `from_dict` | Потенциальный крэш на битом сейве | Medium |
| `WorldPersistence.apply_loaded_save` — нет валидации `ctx.hero != null` перед использованием | Нулл-крэш при повреждённом сейве | Medium |

### 2.4 Naming и структура

| Замечание | Пример | Рекомендация |
|---|---|---|
| `_cmd_*` — 80+ методов в одном классе | `_cmd_screenshot`, `_cmd_csg`, `_cmd_ui_theme` | Сгруппировать по доменам: `McpBattleCmds`, `McpCityCmds`, `McpUICmds` |
| `_mk`, `_req`, `_chain` в `BuildingDefs` — неочевидные сокращения | `_mk()` → `_make_def()` | Переименовать |
| `_sp`, `_rect`, `_ellipse` в `gen_artifact_icons.gd` | — | Ок для генератора, но добавить док-комменты |

---

## 3. Алгоритмы

### 3.1 Инвентарь алгоритмов

| Алгоритм | Где | Сложность | Корректность |
|---|---|---|---|
| **A\*** (hex-grid) | `HexPathfinding.astar_path` | O(V log V) | ✅ Корректен, но `g_score` — `PackedFloat32Array` фикс. размера `w*h` |
| **BFS** (hex-grid) | `HexPathfinding.bfs_path`, `bfs_reachable` | O(V) | ✅ |
| **Dijkstra** | `HexPathfinding.dijkstra`, `dijkstra_path_early` | O(V log V) | ✅ |
| **MinHeap** (ручной) | `MinHeap.gd` | push/pop O(log n) | ✅ Корректен, но нет `decrease_key` — дубли в очереди |
| **BFS-кластеризация** | `ArenaClusterSystem._compute_clusters` | O(B), B — здания | ✅ |
| **Hex-distance** (cube coords) | `HexUtils.hex_distance` | O(1) | ✅ |
| **Cube ↔ Offset** | `HexUtils.offset_to_cube / cube_to_offset` | O(1) | ✅ Оба режима (odd-r / even-r) |
| **Генерация карты** (3 × FastNoiseLite) | `MapModel.generate_noise` | O(W×H) | ✅ |
| **SurfaceTool terrain** | `_terrain_rebuild` | O(W×H) | ⚠️ Полный ребилд на каждое изменение |

### 3.2 Граничные случаи

| Кейс | Статус | Комментарий |
|---|---|---|
| Пустой граф (нет проходимых клеток) | ✅ | `bfs_path` вернёт `[]` |
| Старт == цель | ✅ | Возврат `[start]` |
| `MinHeap.pop()` на пустой куче | ✅ | Возврат `[]` |
| `hex_distance` за границей карты | ⚠️ | Не проверяется, но `get_neighbor` не проверяет границы — вызывающий код проверяет |
| `_terrain_rebuild` при `width < 2` или `depth < 2` | ⚠️ | Цикл `range(depth - 1)` даст 0 итераций — не крэш, но пустой меш |
| `dijkstra` с `max_cost = 0` | ✅ | Вернёт только стартовую клетку |

### 3.3 Предложения по оптимизации

| Что | Текущее | Предложение | Эффект |
|---|---|---|---|
| `MinHeap` без `decrease_key` | Дубли вершин в куче, проверка `cur_g > g_score[idx]` | Ок для текущего размера карт (≤70×70). Для 200×200+ рассмотреть `decrease_key` или `std::priority_queue` через GDExtension | До 2× на больших картах |
| `_terrain_rebuild` — полный ребилд | O(W×H) на каждое изменение высоты | Чанковая система (16×16), ребилд только затронутого чанка | До 10× при локальных правках |
| `ArenaClusterSystem._city_version` — хэш по всем зданиям | O(B) на каждый вызов `clusters()` | Инкрементальный хэш: обновлять при `add/remove building` | O(1) на запрос |
| `_collect_ui_elements` — рекурсивный обход всего дерева | O(N) на каждый вызов `get_ui_elements` | Кэшировать результат, инвалидировать по сигналу `tree_changed` | Актуально для MCP |

---

## 4. Рефакторинг

### 4.1 [High] Разбиение `mcp_interaction_server.gd` на модули

**Что:** Вынести группы команд в отдельные скрипты-обработчики.

**Зачем:** Файл 3000+ строк, `match` на 80+ веток, невозможно добавить команду без правки ядра.

**До:**
```gdscript
# mcp_interaction_server.gd — один файл
func _handle_command(json_str: String) -> void:
    # ...parse...
    match command:
        "screenshot": await _cmd_screenshot()
        "click":      await _cmd_click(params)
        "csg":        _cmd_csg(params)
        "ui_theme":   _cmd_ui_theme(params)
        # ... ещё 76 веток ...

func _cmd_screenshot() -> void: ...
func _cmd_click(params: Dictionary) -> void: ...
# ... 80+ методов ...
```

**После:**
```gdscript
# mcp_interaction_server.gd — только транспорт + диспетчер
var _handlers: Dictionary = {}  # command_name → Callable

func _ready() -> void:
    _register_handlers()
    # ...listen...

func _register_handlers() -> void:
    var battle := McpBattleCommands.new(self)
    var city   := McpCityCommands.new(self)
    var ui     := McpUICommands.new(self)
    var input  := McpInputCommands.new(self)
    var system := McpSystemCommands.new(self)
    for h in [battle, city, ui, input, system]:
        for cmd_name in h.get_commands():
            _handlers[cmd_name] = h

func _handle_command(json_str: String) -> void:
    # ...parse...
    if not _handlers.has(command):
        _send_response({"error": "Unknown command: %s" % command})
        return
    var handler = _handlers[command]
    if handler.is_async(command):
        await handler.execute(command, params)
    else:
        handler.execute(command, params)
```

```gdscript
# mcp_commands_battle.gd
class_name McpBattleCommands
var _server: Node

func _init(server: Node) -> void:
    _server = server

func get_commands() -> Array[String]:
    return ["screenshot", "click", "key_press", "key_hold", "key_release", ...]

func is_async(cmd: String) -> bool:
    return cmd in ["screenshot", "click", "key_press", "wait", "mouse_drag", ...]

func execute(cmd: String, params: Dictionary) -> void:
    match cmd:
        "screenshot": await _screenshot()
        "click":      await _click(params)
        # ...
```

### 4.2 [High] Декомпозиция `CityTurnProcessor._process_city`

**Что:** Разбить на цепочку подпроцессоров, вызываемых последовательно.

**Зачем:** 8 подсистем в одном методе, невозможно тестировать изолированно.

**До:**
```gdscript
func _process_city(city: City, turn: int) -> Dictionary:
    var report := {...}
    # Scale shift (20 строк)
    # Storage capacity (15 строк)
    # Zone multipliers (10 строк)
    # Zone violations (8 строк)
    # Reputation (5 строк)
    # Migration (8 строк)
    # Worker assignment (5 строк)
    # Prosperity + gold + level up (15 строк)
    # Raids (8 строк)
    # Specialization science (4 строки)
    # City events (6 строк)
    return report
```

**После:**
```gdscript
# city_turn_processor.gd
var _sub_processors: Array[CitySubProcessor] = [
    ScaleShiftProcessor.new(),
    StorageCapacityProcessor.new(),
    ZoneProcessor.new(),
    ReputationProcessor.new(),
    MigrationProcessor.new(),
    WorkerProcessor.new(),
    ProsperityProcessor.new(),
    RaidProcessor.new(),
    SpecializationProcessor.new(),
    CityEventProcessor.new(),
]

func _process_city(city: City, turn: int) -> Dictionary:
    var report := {"uid": city.uid}
    for proc in _sub_processors:
        var sub_report := proc.process(city, turn)
        report.merge(sub_report)
        _emit_signals(proc, sub_report)
    return report
```

```gdscript
# city_sub_processor.gd
class_name CitySubProcessor
extends RefCounted

func process(city: City, turn: int) -> Dictionary:
    return {}
```

### 4.3 [High] Защита `_send_response_raw`

**Что:** Проверять результат записи, логировать ошибку, сбрасывать `_busy`.

**До:**
```gdscript
func _send_response_raw(data: Dictionary) -> void:
    if _client == null:
        return
    var json_str: String = JSON.stringify(data) + "\n"
    var bytes: PackedByteArray = json_str.to_utf8_buffer()
    _client.put_data(bytes)  # ← результат игнорируется
```

**После:**
```gdscript
func _send_response_raw(data: Dictionary) -> void:
    if _client == null:
        push_warning("McpServer: no client, response dropped")
        return
    var json_str: String = JSON.stringify(data) + "\n"
    var bytes: PackedByteArray = json_str.to_utf8_buffer()
    var err := _client.put_data(bytes)
    if err != OK:
        push_error("McpServer: put_data failed (err %d), disconnecting" % err)
        _client.disconnect_from_host()
        _client = null
        _busy = false
        _busy_since = 0.0
        _current_id = null
```

### 4.4 [Medium] Устранение дублирования `_json_to_variant` / `_json_to_variant_for_property`

**Что:** `_json_to_variant_for_property` должен делегировать в `_json_to_variant`, а не дублировать `match`.

**До:**
```gdscript
func _json_to_variant_for_property(node: Node, property: String, value: Variant) -> Variant:
    for prop in node.get_property_list():
        if prop["name"] == property:
            var type_id: int = prop.get("type", 0)
            match type_id:
                TYPE_VECTOR2: return _json_to_variant(value, "Vector2")
                TYPE_VECTOR3: return _json_to_variant(value, "Vector3")
                TYPE_COLOR:   return _json_to_variant(value, "Color")
                # ... 12 веток, дублирующих маппинг ...
                TYPE_BOOL: ...
                TYPE_INT: ...
                TYPE_FLOAT: ...
    return _json_to_variant(value)
```

**После:**
```gdscript
const TYPE_TO_HINT: Dictionary = {
    TYPE_VECTOR2: "Vector2", TYPE_VECTOR2I: "Vector2i",
    TYPE_VECTOR3: "Vector3", TYPE_VECTOR3I: "Vector3i",
    TYPE_COLOR: "Color", TYPE_QUATERNION: "Quaternion",
    TYPE_RECT2: "Rect2", TYPE_AABB: "AABB",
    TYPE_BASIS: "Basis", TYPE_TRANSFORM3D: "Transform3D",
    TYPE_TRANSFORM2D: "Transform2D",
}

func _json_to_variant_for_property(node: Node, property: String, value: Variant) -> Variant:
    for prop in node.get_property_list():
        if prop["name"] == property:
            var type_id: int = prop.get("type", 0)
            if TYPE_TO_HINT.has(type_id):
                return _json_to_variant(value, TYPE_TO_HINT[type_id])
            match type_id:
                TYPE_BOOL:  return bool(value) if not value is String else value.to_lower() == "true"
                TYPE_INT:   return int(value)
                TYPE_FLOAT: return float(value)
            break
    return _json_to_variant(value)
```

### 4.5 [Medium] Инкрементальный хэш для `ArenaClusterSystem`

**Что:** Заменить полный пересчёт хэша на инкрементальный.

**До:**
```gdscript
static func _city_version(city: City) -> int:
    var h: int = 0
    for bld in city.buildings:        # O(B) на каждый вызов
        h = (h * 131 + int(bld.uid)) & 0x7fffffff
        # ... 7 операций на здание ...
    return int(city.buildings.size()) * 1_000_003 + h
```

**После:**
```gdscript
# В City: signal buildings_changed
# В ArenaClusterSystem:
static func invalidate_city(city: City) -> void:
    if city != null and city.has_meta(&"arena_clusters_cache"):
        city.remove_meta(&"arena_clusters_cache")

# Подключить в City.build_building / remove_building:
# buildings_changed.connect(ArenaClusterSystem.invalidate_city.bind(self))
```

### 4.6 [Low] Удаление дублирующего теста

**Что:** Удалить `tests/systems/city/test_borough_rules.gd` (дубль `tests/unit/world/test_borough_rules.gd`).

### 4.7 [Low] Типизация `var` в горячих путях

**Что:** Заменить `var x = ...` на `var x: Type = ...` в циклах обхода.

**До:**
```gdscript
for child in node.get_children():
    _collect_ui_elements(child, elements)
```

**После:**
```gdscript
for child: Node in node.get_children():
    _collect_ui_elements(child, elements)
```

---

## 5. Инструкция для локального агента

### Фаза 1 — Критические правки (1–2 дня)

| # | Действие | Файл | Проверка |
|---|---|---|---|
| 1.1 | Добавить проверку `put_data` в `_send_response_raw` | `mcp_interaction_server.gd:~230` | Запустить игру, подключиться по TCP, послать невалидный JSON → убедиться, что сервер не зависает |
| 1.2 | Удалить дубль `tests/systems/city/test_borough_rules.gd` | `tests/systems/city/` | `gdunit4 run tests/` — все тесты зелёные |
| 1.3 | Добавить `is_inside_tree()` гард в `_cmd_click`, `_cmd_key_press` | `mcp_interaction_server.gd:~550–600` | Юнит-тест: вызвать `_cmd_click` без дерева → не крэшится |

**Команды проверки:**
```bash
# Запуск тестов
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --ignoreHeadlessMode

# Проверка компиляции всех скриптов
godot --headless --check-only --script res://tests/unit/test_compile_all.gd
```

### Фаза 2 — Разбиение MCP-сервера (3–5 дней)

| # | Действие | Файлы |
|---|---|---|
| 2.1 | Создать `mcp_commands_base.gd` с интерфейсом `get_commands() / is_async() / execute()` | Новый файл |
| 2.2 | Вынести группы команд в 5 файлов: `mcp_commands_input.gd`, `mcp_commands_battle.gd`, `mcp_commands_city.gd`, `mcp_commands_ui.gd`, `mcp_commands_system.gd` | Новые файлы |
| 2.3 | Переписать `_handle_command` на диспетчер через `_handlers: Dictionary` | `mcp_interaction_server.gd` |
| 2.4 | Перенести `_variant_to_json`, `_json_to_variant` в `mcp_serialization.gd` | Новый файл |

**Критерий приёмки:**
```bash
# MCP-тесты (если есть)
cd tests/mcp && python -m pytest -xvs

# Ручная проверка: подключиться по TCP, выполнить "get_scene_tree", "screenshot"
echo '{"id":1,"command":"get_scene_tree"}' | nc 127.0.0.1 9090
```

### Фаза 3 — Декомпозиция `CityTurnProcessor` (2–3 дня)

| # | Действие | Файлы |
|---|---|---|
| 3.1 | Создать `city_sub_processor.gd` — базовый класс | Новый файл |
| 3.2 | Вынести 10 подпроцессоров в отдельные файлы | `scripts/city/processors/` |
| 3.3 | Переписать `_process_city` как цикл по подпроцессорам | `CityTurnProcessor.gd` |
| 3.4 | Перенести сигналы в соответствующие подпроцессоры | Каждый процессор |

**Критерий приёмки:**
```bash
# Все существующие тесты города должны пройти
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/unit/world/test_city_processor.gd \
  --add tests/unit/world/test_city_systems.gd \
  --add tests/unit/world/test_city_level.gd \
  --ignoreHeadlessMode
```

### Фаза 4 — Оптимизации (по необходимости)

| # | Действие | Файл | Приоритет |
|---|---|---|---|
| 4.1 | Заменить `_city_version` на инвалидацию по сигналу | `ArenaClusterSystem.gd` | Medium |
| 4.2 | Добавить чанки в `_terrain_rebuild` | `WorldController.gd` | Low (если нет жалоб на FPS) |
| 4.3 | Типизировать циклы `for child in get_children()` | Все файлы с `_collect_*` | Low |

**Финальная проверка:**
```bash
# Полный прогон тестов
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --ignoreHeadlessMode

# MCP E2E
cd tests/mcp && python -m pytest -xvs

# Компиляция
godot --headless --check-only --path . 2>&1 | grep -c "ERROR"  # должно быть 0
```

### Сводка приоритетов

| Приоритет | Кол-во правок | Суть |
|---|---|---|
| **High** | 3 | Защита `_send_response_raw`, разбиение MCP, декомпозиция `CityTurnProcessor` |
| **Medium** | 4 | Дедупликация `_json_to_variant`, инкрементальный хэш, типизация, `is_inside_tree` гарды |
| **Low** | 3 | Удаление дубля теста, чанки террейна, типизация циклов |

# Аудит тестов: структура, покрытие, логика

---

## 1. Текущая структура тестов

### 1.1 Дерево каталогов

```
tests/
├── core/                          # 5 файлов
│   ├── test_algorithm_optimizations.gd
│   ├── test_artifact_system.gd
│   ├── test_battle_rules.gd
│   ├── test_characters.gd
│   ├── test_error_handling.gd
│   ├── test_hex_pathfinding.gd
│   ├── test_hex_utils.gd
│   ├── test_keys_matrix.gd
│   ├── test_logger.gd
│   ├── test_production_chain.gd
│   ├── test_race_class_matrix.gd
│   ├── test_resource_context.gd
│   ├── test_save_roundtrip.gd
│   ├── test_save_v3.gd
│   ├── test_season.gd
│   ├── test_shard.gd
│   ├── test_spell_registry.gd
│   ├── test_spells_json.gd
│   ├── test_status_effects.gd
│   ├── test_time_system.gd
│   ├── test_trait_registry.gd
│   ├── test_turn_scheduler.gd
│   └── test_visibility_map.gd
├── functional/                    # 12 файлов
│   ├── test_battle_balance.gd
│   ├── test_battle_emulator.gd
│   ├── test_benchmarks.gd
│   ├── test_camera_clamp.gd
│   ├── test_city_arena_view.gd
│   ├── test_city_navigation.gd
│   ├── test_city_screen.gd
│   ├── test_compile_all.gd
│   ├── test_memory_profile.gd
│   ├── test_perf_resource_icons.gd
│   ├── test_refactoring_regression.gd
│   ├── test_resource_collect_popup.gd
│   ├── test_runtime_integration.gd
│   ├── test_scene_boot.gd
│   ├── test_scene_refs.gd
│   ├── test_session_reset.gd
│   ├── test_tileset_integrity.gd
│   ├── test_ui_animator.gd
│   ├── test_world_scenario.gd
│   └── test_zoom_levels.gd
├── fakes/                         # 4 файла
│   ├── fake_battle_flow.gd
│   ├── fake_battle_map.gd
│   ├── fake_hero.gd
│   └── MockBattleView.gd
├── helpers/                       # 2 файла
│   ├── factories.gd
│   └── test_factories.gd
├── integration/                   # 9 файлов
│   ├── test_battle_input.gd
│   ├── test_city_cycle.gd
│   ├── test_city_economy.gd
│   ├── test_event_router.gd
│   ├── test_hero_resurrection.gd
│   ├── test_legend_chronicle.gd
│   ├── test_worldcontroller_succession_wiring.gd
│   └── ...
├── mcp/                           # 11 файлов (через godot-mcp)
│   ├── conftest.py
│   ├── godot_mcp.py
│   ├── pyproject.toml
│   ├── pytest.ini
│   ├── test_battle_full_e2e.py
│   ├── test_battle_profiling.py
│   ├── test_battle_tween.py
│   ├── test_hexutils_perf.py
│   ├── test_resource_and.py
│   ├── test_save_load_continue.py
│   ├── test_scene_transitions.py
│   ├── test_session_reset.py
│   └── test_shard_pruning.py
├── spell_validation/              # 2 файла
│   ├── SpellValidator.gd
│   └── ValidationReport.gd
├── systems/city/                  # 1 файл
│   └── test_borough_rules.gd
├── unit/                          # ~55 файлов
│   ├── core/
│   │   ├── test_static_caches.gd
│   │   └── test_visibility_map.gd
│   ├── data/
│   │   ├── test_audio_world_entry.gd
│   │   ├── test_hero_build_profile.gd
│   │   ├── test_resource_registry.gd
│   │   ├── test_spell_system.gd
│   │   └── test_terrain_cost_table.gd
│   ├── entities/
│   │   ├── test_army_stat_integrity.gd
│   │   ├── test_capacity.gd
│   │   ├── test_follower_race_class.gd
│   │   ├── test_hero_serialize.gd
│   │   ├── test_hero_survival.gd
│   │   ├── test_magic.gd
│   │   ├── test_scroll.gd
│   │   └── ...
│   ├── systems/
│   │   ├── test_applied_fixes.gd
│   │   ├── test_battle_action_resolver.gd
│   │   ├── test_battle_ai.gd
│   │   ├── test_battle_coordinator.gd
│   │   ├── test_battle_cursor.gd
│   │   ├── test_battle_flow.gd
│   │   ├── test_battle_fox.gd
│   │   ├── test_battle_handoff.gd
│   │   ├── test_battle_integration.gd
│   │   ├── test_battle_retreat_queue.gd
│   │   ├── test_battle_retreat_smoke.gd
│   │   ├── test_battle_spell_executor.gd
│   │   ├── test_battle_spell_flow.gd
│   │   ├── test_battle_spell_targeting.gd
│   │   ├── test_battle_state_cache.gd
│   │   ├── test_battle_state.gd
│   │   ├── test_battle_view.gd
│   │   ├── test_endgame.gd
│   │   ├── test_enemy_world_ai.gd
│   │   ├── test_hero_combat_death.gd
│   │   ├── test_hero_lifecycle.gd
│   │   ├── test_hero_movement.gd
│   │   ├── test_hero_planned_route.gd
│   │   ├── test_magic_resistance.gd
│   │   ├── test_refactoring_round2.gd
│   │   ├── test_saltpeter.gd
│   │   ├── test_spellbook_guards.gd
│   │   ├── test_unit_abilities.gd
│   │   └── ...
│   ├── ui/
│   │   ├── test_battle_ui_onready.gd
│   │   ├── test_minimap_overlay.gd
│   │   └── test_save_load_screen.gd
│   └── world/
│       ├── test_borough_rules.gd          # ← дубль!
│       ├── test_city_arena.gd
│       ├── test_city_building_service.gd
│       ├── test_city_chains.gd
│       ├── test_city_events_relocation.gd
│       ├── test_city_growth_service.gd
│       ├── test_city_housing.gd
│       ├── test_city_income_processor.gd
│       ├── test_city_level.gd
│       ├── test_city_manager.gd
│       ├── test_city_persistence.gd
│       ├── test_city_processor.gd
│       ├── test_city_reputation.gd
│       ├── test_city_serializer.gd
│       ├── test_city_systems.gd
│       ├── test_city_yield_calculator.gd
│       ├── test_city_yield_table.gd
│       ├── test_city.gd
│       ├── test_demographic_processor.gd
│       ├── test_economic_processor.gd
│       ├── test_fog_of_war.gd
│       ├── test_follower_path_id.gd
│       ├── test_follower.gd
│       ├── test_glory_tracker.gd
│       ├── test_map_connectivity.gd
│       ├── test_map_generator_seed.gd
│       ├── test_map_model.gd
│       ├── test_map_spawner.gd
│       ├── test_market_walls_raids.gd
│       ├── test_pop_unit.gd
│       ├── test_resource_chain_service.gd
│       ├── test_resource_node_manager.gd
│       ├── test_succession.gd
│       └── ...
└── test_args.gd
```

### 1.2 Количественная сводка

| Категория | Файлов | Тестовых функций (оценка) |
|---|---|---|
| `tests/core/` | 23 | ~180 |
| `tests/functional/` | 20 | ~120 |
| `tests/fakes/` | 4 | — (вспомогательные) |
| `tests/helpers/` | 2 | — (вспомогательные) |
| `tests/integration/` | 9 | ~50 |
| `tests/mcp/` | 11 (py + conftest) | ~30 |
| `tests/spell_validation/` | 2 | — (инструмент) |
| `tests/systems/city/` | 1 | ~10 |
| `tests/unit/` | ~55 | ~450 |
| **Итого** | **~127** | **~840** |

---

## 2. Покрытие кода тестами

### 2.1 Карта покрытия по модулям

| Модуль (скрипт) | Тесты | Покрытие | Приоритет |
|---|---|---|---|
| **Ядро** | | | |
| `HexUtils.gd` | `test_hex_utils.gd` | ✅ Полное | — |
| `HexPathfinding.gd` | `test_hex_pathfinding.gd`, `test_algorithm_optimizations.gd` | ✅ Полное | — |
| `MinHeap.gd` | `test_hex_pathfinding.gd` | ✅ Достаточно | — |
| `VisibilityMap.gd` | `test_visibility_map.gd` (×2: core + unit) | ✅ Полное | — |
| `TurnScheduler.gd` | `test_turn_scheduler.gd` | ✅ Полное | — |
| `TurnPhaseProcessor.gd` | Косвенно через тесты процессоров | ✅ Достаточно | — |
| `SaveData.gd` | `test_save_roundtrip.gd`, `test_save_v3.gd`, `test_succession.gd` | ✅ Полное | — |
| `SaveManager.gd` | `test_save_roundtrip.gd` | ✅ Достаточно | — |
| `ServiceRegistry.gd` | ❌ **Нет** | ❌ | **High** |
| `StaticCaches.gd` | `test_static_caches.gd` | ✅ | — |
| `GameLogger.gd` | `test_logger.gd` | ✅ | — |
| `Platform.gd` | ❌ **Нет** | ❌ | Low |
| `GameSession.gd` | `test_endgame.gd` | ✅ | — |
| `GameEventBus.gd` | `test_event_bus.gd` | ✅ | — |
| **Данные** | | | |
| `Artifact.gd` | `test_artifact_system.gd` | ✅ Полное | — |
| `ArtifactRegistry (autoload)` | `test_artifact_system.gd` | ✅ | — |
| `ResourceDef.gd` | `test_resource_registry.gd` | ✅ | — |
| `ResourceRegistry (autoload)` | `test_resource_registry.gd`, `test_keys_matrix.gd` | ✅ | — |
| `ResourceType.gd` | Косвенно | ⚠️ Частичное | Medium |
| `ResourceContext.gd` | `test_resource_context.gd` | ✅ Полное | — |
| `ProductionChain.gd` | `test_production_chain.gd` | ✅ Полное | — |
| `SpellRegistry.gd` | `test_spell_registry.gd` | ✅ | — |
| `SpellbookRegistry.gd` | `test_spell_system.gd`, `test_spells_json.gd` | ✅ Полное | — |
| `SpellbookDef.gd` | `test_spell_system.gd` | ✅ | — |
| `SpellEnums.gd` | `test_spell_system.gd` | ✅ | — |
| `TemplateEngine.gd` | `test_spell_system.gd` | ✅ | — |
| `SpellResolver.gd` | `test_spell_system.gd` | ✅ | — |
| `StatusEffects.gd` | `test_status_effects.gd` | ✅ | — |
| `TerrainCostTable.gd` | `test_terrain_cost_table.gd` | ✅ Полное | — |
| `TerrainResourceManager.gd` | `test_terrain_resource_manager.gd` | ✅ Полное | — |
| `NeedType.gd` | Косвенно через демографию | ⚠️ Частичное | Medium |
| `TraitDef.gd` | `test_trait_registry.gd` | ✅ | — |
| `TraitRegistry.gd` | `test_trait_registry.gd` | ✅ Полное | — |
| `ClassDef.gd`, `RaceDef.gd` | `test_race_class_matrix.gd` | ✅ | — |
| `RaceClassRegistry.gd` | `test_race_class_matrix.gd` | ✅ Полное | — |
| `HeroBuildProfile.gd` | `test_hero_build_profile.gd` | ✅ Полное | — |
| `BuildingDefs.gd` | Косвенно через городские тесты | ⚠️ Частичное | Medium |
| `EnemyAIProfile.gd` | `test_enemy_world_ai.gd` | ✅ | — |
| `AudioCues.gd` | `test_audio.gd` | ✅ | — |
| `ScrollRules.gd` | `test_scroll.gd` | ✅ | — |
| `TimeSystem.gd` | `test_time_system.gd` | ✅ Полное | — |
| `Season.gd` | `test_season.gd` | ✅ | — |
| `GameNumbers.gd` | Косвенно | ⚠️ Нет прямых | Low |
| `ThemeConfig.gd` | ❌ **Нет** | ❌ | Low |
| `GameText.gd` | ❌ **Нет** | ❌ | Low |
| **Сущности** | | | |
| `UnitStats.gd` | `test_unit_registry.gd` | ✅ | — |
| `UnitStack.gd` | `test_unit_registry.gd` | ✅ | — |
| `UnitRegistry (autoload)` | `test_unit_registry.gd` | ✅ Полное | — |
| `UnitSprites.gd` | ❌ **Нет** | ❌ | Low |
| `ResourceNode.gd` | `test_resource_node_manager.gd` | ⚠️ Частичное | Medium |
| `ResourceNodeManager.gd` | `test_resource_node_manager.gd` | ✅ | — |
| `Follower.gd` | `test_follower.gd`, `test_follower_race_class.gd` | ✅ Полное | — |
| `HeroInventory.gd` | `test_artifact_system.gd`, `test_settings_guard.gd` | ✅ Полное | — |
| `HeroMagic.gd` | `test_magic.gd` | ✅ Полное | — |
| `HeroNeeds.gd` | `test_hero_survival.gd` | ✅ Полное | — |
| `HeroSkills.gd` | Косвенно | ⚠️ Частичное | Medium |
| `HeroTools.gd` | ❌ **Нет** | ❌ | Medium |
| `HeroResources.gd` | `test_hero_serialize.gd` | ✅ | — |
| `HeroStrategicResources.gd` | `test_capacity.gd` | ✅ Полное | — |
| `HeroMovementController.gd` | `test_hero_movement.gd`, `test_hero_planned_route.gd` | ✅ Полное | — |
| `HeroArmyController.gd` | `test_hero_serialize.gd`, `test_army_stat_integrity.gd` | ✅ | — |
| `HeroVisualController.gd` | ❌ **Нет** | ❌ | Low |
| `HeroController.gd` | `test_hero_survival.gd`, `test_hero_serialize.gd` | ⚠️ Частичное | **High** |
| **Город** | | | |
| `City.gd` | `test_city.gd`, `test_city_serializer.gd` | ✅ | — |
| `CityData.gd` | Косвенно | ✅ | — |
| `CityService.gd` | Косвенно через `test_city.gd` | ⚠️ Частичное | Medium |
| `CityBuildingService.gd` | `test_city_building_service.gd` | ✅ | — |
| `CityGrowthService.gd` | `test_city_growth_service.gd` | ✅ | — |
| `CitySerializer.gd` | `test_city_serializer.gd` | ✅ | — |
| `CityFactory.gd` | `test_city_persistence.gd` | ✅ | — |
| `CityManager.gd` | `test_city_manager.gd` | ✅ Полное | — |
| `CityYieldCalculator.gd` | `test_city_yield_calculator.gd` | ✅ Полное | — |
| `CityYieldTable.gd` | `test_city_yield_table.gd` | ✅ Полное | — |
| `CityTurnProcessor.gd` | `test_city_processor.gd`, `test_city_level.gd` | ✅ Полное | — |
| `CityCheck.gd` | Косвенно | ✅ | — |
| `CityEvents.gd` | `test_city_events_relocation.gd` | ✅ | — |
| `CityIncomeProcessor.gd` | `test_city_income_processor.gd` | ✅ Полное | — |
| `Borough.gd` | Косвенно | ✅ | — |
| `BoroughRules.gd` | `test_borough_rules.gd` (×2 — дубль!) | ✅ | **Удалить дубль** |
| `PopUnit.gd` | `test_pop_unit.gd`, `test_follower_path_id.gd` | ✅ Полное | — |
| `UniqueBuilding.gd` | Косвенно | ⚠️ Частичное | Medium |
| `AdjacencySystem.gd` | `test_city_chains.gd` | ✅ | — |
| `ArenaClusterSystem.gd` | `test_city_arena.gd` | ✅ Полное | — |
| `ArenaRingSystem.gd` | `test_city_arena.gd` | ✅ Полное | — |
| `ArenaStorm.gd` | `test_city_arena.gd` | ✅ | — |
| `ArenaTurnRunner.gd` | `test_city_arena.gd` | ✅ | — |
| `ArenaDemoScenario.gd` | `test_city_arena.gd` | ✅ | — |
| `LogisticsCalculator.gd` | `test_city_systems.gd` | ✅ Полное | — |
| `MarketSystem.gd` | `test_market_walls_raids.gd` | ✅ Полное | — |
| `ProsperitySystem.gd` | `test_city_level.gd` | ✅ Полное | — |
| `RaidSystem.gd` | `test_market_walls_raids.gd` | ✅ Полное | — |
| `ReputationSystem.gd` | `test_city_reputation.gd` | ✅ Полное | — |
| `ScaleShiftManager.gd` | `test_city_systems.gd` | ✅ | — |
| `SpecializationSystem.gd` | `test_city_events_relocation.gd` | ✅ | — |
| `WorkerAssignment.gd` | `test_city_housing.gd`, `test_city_chains.gd` | ✅ | — |
| `ZoningSystem.gd` | `test_city_systems.gd` | ✅ Полное | — |
| **Экономика** | | | |
| `EconomicTurnProcessor.gd` | `test_economic_processor.gd` | ✅ Полное | — |
| `ResourceContext.gd` | `test_resource_context.gd` | ✅ Полное | — |
| `ProductionChain.gd` | `test_production_chain.gd` | ✅ Полное | — |
| **Демография** | | | |
| `Character.gd` | `test_characters.gd` | ✅ Полное | — |
| `CharacterRegistry.gd` | `test_characters.gd` | ✅ Полное | — |
| `DemographicTurnProcessor.gd` | `test_demographic_processor.gd` | ✅ Полное | — |
| **Бой** | | | |
| `BattleState.gd` | `test_battle_state.gd`, `test_battle_state_cache.gd` | ✅ Полное | — |
| `BattleActionResolver.gd` | `test_battle_action_resolver.gd` | ✅ Полное | — |
| `BattleAI.gd` | `test_battle_ai.gd` | ✅ Полное | — |
| `BattleDamageResolver.gd` | `test_battle_damage_resolver.gd` | ✅ Полное | — |
| `BattleTurnExecutor.gd` | `test_battle_retreat_queue.gd`, `test_battle_spell_executor.gd` | ✅ | — |
| `BattleInput.gd` | `test_battle_input.gd` | ✅ | — |
| `BattleView.gd` | `test_battle_view.gd` | ✅ | — |
| `BattleFX.gd` | `test_battle_fox.gd` | ✅ | — |
| `BattleController.gd` | `test_battle_spell_flow.gd` | ⚠️ Частичное | **High** |
| `BattleFlow.gd` | `test_battle_flow.gd` | ✅ | — |
| `BattleStateBuilder.gd` | Косвенно | ⚠️ Частичное | Medium |
| `BattleHandoff.gd` | `test_battle_handoff.gd` | ✅ Полное | — |
| `BattleRules.gd` | `test_battle_rules.gd` | ✅ Полное | — |
| `BattleRetreatPolicy.gd` | Косвенно через `test_battle_retreat_queue.gd` | ✅ | — |
| `SpellCaster.gd` | `test_magic_resistance.gd` | ✅ | — |
| **Мир** | | | |
| `MapModel.gd` | `test_map_model.gd`, `test_map_generator_seed.gd` | ✅ | — |
| `MapGenerator.gd` | `test_map_generator_seed.gd`, `test_map_connectivity.gd` | ✅ | — |
| `MapRenderer.gd` | ❌ **Нет** | ❌ | Medium |
| `MapSpawner.gd` | `test_map_spawner.gd` | ⚠️ Частичное | Medium |
| `WorldCamera.gd` | `test_camera_clamp.gd`, `test_zoom_levels.gd` | ✅ | — |
| `WorldInput.gd` | ❌ **Нет** | ❌ | **High** |
| `WorldSpawner.gd` | `test_fog_of_war.gd` | ⚠️ Частичное | Medium |
| `WorldController.gd` | `test_world_scenario.gd`, `test_refactoring_round2.gd` | ⚠️ Частичное | **High** |
| `WorldBootstrap.gd` | `test_map_connectivity.gd` | ⚠️ Частичное | Medium |
| `WorldBattleCoordinator.gd` | `test_battle_coordinator.gd`, `test_battle_handoff.gd` | ✅ | — |
| `WorldEventRouter.gd` | `test_event_router.gd` | ✅ | — |
| `WorldHeroManager.gd` | ❌ **Нет** | ❌ | Medium |
| `WorldInteractionController.gd` | `test_fog_of_war.gd`, `test_resource_collect_popup.gd` | ⚠️ Частичное | Medium |
| `WorldLoadContext.gd` | `test_world_persistence.gd` | ✅ | — |
| `WorldPersistence.gd` | `test_world_persistence.gd`, `test_succession.gd` | ✅ | — |
| `WorldSaveLoadService.gd` | ❌ **Нет** | ❌ | Medium |
| `WorldShortcuts.gd` | ❌ **Нет** | ❌ | Medium |
| `WorldStateDelta.gd` | `test_fog_of_war.gd`, `test_world_persistence.gd` | ✅ | — |
| `EnemyTurnProcessor.gd` | `test_enemy_world_ai.gd` | ✅ Полное | — |
| `EnemyGrowthSystem.gd` | `test_enemy_world_ai.gd` | ✅ | — |
| `EndgameController.gd` | `test_endgame.gd` | ✅ Полное | — |
| `HeroLifecycleSystem.gd` | `test_hero_lifecycle.gd` | ✅ | — |
| `SuccessionController.gd` | `test_succession.gd` | ✅ Полное | — |
| `LegendTracker.gd` | `test_succession.gd`, `test_legend_chronicle.gd` | ✅ Полное | — |
| `ShardManager.gd` | `test_shard.gd` | ✅ Полное | — |
| `ShardState.gd` | `test_shard.gd` | ✅ Полное | — |
| `GloryTracker.gd` | `test_glory_tracker.gd` | ✅ Полное | — |
| `CursorController.gd` | `test_cursor.gd` | ✅ Полное | — |
| **Системы** | | | |
| `ResourceChainService.gd` | `test_resource_chain_service.gd` | ✅ Полное | — |
| `SerializationUtils.gd` | Косвенно | ✅ | — |
| **Автозагрузки** | | | |
| `services.gd` | ❌ **Нет** | ❌ | **High** |
| `Settings.gd` | `test_settings_persist.gd`, `test_settings_guard.gd` | ✅ | — |
| `SoundManager.gd` | `test_audio.gd` | ✅ | — |
| `hex_grid.gd` | `test_hex_utils.gd` | ✅ | — |
| `BattleEmulator.gd` | `test_battle_emulator.gd` | ✅ Полное | — |
| `TileAtlasCache.gd` | ❌ **Нет** | ❌ | Low |
| `TemplateBootstrap.gd` | Косвенно через `test_spell_system.gd` | ✅ | — |
| `ArtifactRegistry (autoload)` | `test_artifact_system.gd` | ✅ | — |
| **UI** | | | |
| `AdventureUI.gd` | ❌ **Нет** | ❌ | **High** |
| `ArmyPanel.gd` | ❌ **Нет** | ❌ | Medium |
| `ArenaHexCell.gd` | ❌ **Нет** | ❌ | Medium |
| `BattleSpellbookPanel.gd` | `test_spellbook_guards.gd` | ⚠️ Минимальное | Medium |
| `BattleUI.gd` | `test_battle_ui_onready.gd` | ⚠️ Частичное | **High** |
| `CharacterCreationUI.gd` | ❌ **Нет** | ❌ | **High** |
| `ChronicleScreen.gd` | `test_legend_chronicle.gd` | ⚠️ Частичное | Medium |
| `CityArenaView.gd` | `test_city_arena_view.gd` | ✅ | — |
| `CityScreen.gd` | `test_city_screen.gd` | ⚠️ Частичное | Medium |
| `DeathSequence.gd` | `test_legend_chronicle.gd` | ⚠️ Частичное | Medium |
| `GameOverScreen.gd` | ❌ **Нет** | ❌ | Medium |
| `HeroModelFactory.gd` | ❌ **Нет** | ❌ | Low |
| `HeroStatusPanel.gd` | `test_hero_survival.gd` | ⚠️ Частичное | Medium |
| `HighlightOverlay.gd` | Косвенно | ⚠️ | Low |
| `CursorOverlay.gd` | `test_battle_cursor.gd` | ✅ | — |
| `InfoPanel.gd` | ❌ **Нет** | ❌ | Medium |
| `MainMenu.gd` | ❌ **Нет** | ❌ | **High** |
| `MarkerLayer.gd` | `test_refactoring_round2.gd` | ⚠️ Частичное | Medium |
| `MinimapOverlay.gd` | `test_minimap_overlay.gd` | ✅ | — |
| `MinimapPanel.gd` | ❌ **Нет** | ❌ | Medium |
| `ResourceBar.gd` | ❌ **Нет** | ❌ | Low |
| `ResourceCollectPopup.gd` | `test_resource_collect_popup.gd` | ✅ | — |
| `ResourcesPanel.gd` | ❌ **Нет** | ❌ | Low |
| `SaveLoadScreen.gd` | `test_save_load_screen.gd` | ✅ | — |
| `SettingsScreen.gd` | `test_settings_persist.gd`, `test_settings_guard.gd` | ✅ | — |
| `SkillsPanel.gd` | ❌ **Нет** | ❌ | Low |
| `ToolsPanel.gd` | ❌ **Нет** | ❌ | Low |
| `UIAnimator.gd` | `test_ui_animator.gd` | ✅ | — |
| `WorldUIManager.gd` | ❌ **Нет** | ❌ | **High** |
| **MCP-сервер** | | | |
| `mcp_interaction_server.gd` | ❌ **Нет** | ❌ | **High** |
| **Генераторы** | | | |
| `gen_artifact_icons.gd` | ❌ **Нет** | ❌ | Low |
| `gen_inventory_scene.gd` | ❌ **Нет** | ❌ | Low |
| `gen_sound_wav.gd` | ❌ **Нет** | ❌ | Low |
| `tune_city_arena.gd` | ❌ **Нет** | ❌ | Low |

### 2.2 Сводка покрытия

| Уровень | Покрыто | Не покрыто | Частично |
|---|---|---|---|
| Ядро | 14 | 2 | 1 |
| Данные | 33 | 3 | 4 |
| Сущности | 14 | 3 | 3 |
| Город | 37 | 0 | 4 |
| Экономика | 3 | 0 | 0 |
| Демография | 3 | 0 | 0 |
| Бой | 14 | 0 | 3 |
| Мир | 16 | 6 | 7 |
| Автозагрузки | 7 | 2 | 1 |
| UI | 9 | 16 | 8 |
| MCP | 0 | 1 | 0 |
| Генераторы | 0 | 4 | 0 |
| **Итого** | **~150** | **~37** | **~31** |

**Оценка покрытия:** ~65% модулей имеют тесты. Критические пробелы: `ServiceRegistry`, `services.gd`, `mcp_interaction_server.gd`, `WorldInput`, `WorldController`, UI-панели.

---

## 3. Анализ логики тестов

### 3.1 Сильные стороны

| Паттерн | Где | Оценка |
|---|---|---|
| **Изолированные юнит-тесты** | `test_hex_utils.gd`, `test_min_heap.gd` | ✅ Чистые функции, без зависимостей |
| **Фабрики** | `tests/helpers/factories.gd` (`TestFactories`) | ✅ Единообразное создание объектов |
| **Детерминированный RNG** | `TestFactories.seeded(seed)` | ✅ Воспроизводимость |
| **Группировка по доменам** | `tests/unit/world/`, `tests/unit/systems/` | ✅ Логичная структура |
| **Интеграция через TurnScheduler** | `test_city_chains.gd`, `test_city_processor.gd` | ✅ Тестирование пайплайна |
| **Валидация данных (спеллы)** | `tests/spell_validation/` | ✅ Отдельный инструмент с кодами ошибок |
| **MCP E2E** | `tests/mcp/` | ✅ Полный цикл: старт → бой → сейв → загрузка |

### 3.2 Проблемы

#### P1: Дублирование `test_borough_rules.gd`

Два файла с одинаковым содержанием:
- `tests/systems/city/test_borough_rules.gd`
- `tests/unit/world/test_borough_rules.gd`

Оба используют `GdUnitTestSuite`, оба тестируют `BoroughRules`. Запускаются дважды, замедляют прогон.

**Решение:** удалить `tests/systems/city/test_borough_rules.gd`, оставить `tests/unit/world/`.

#### P2: Тесты с зависимостью от дерева сцены

```gdscript
# test_legend_chronicle.gd
func test_hero_status_panel_with_hero() -> void:
    var panel := load("res://scenes/ui/hero_status_panel.tscn").instantiate()
    add_child(panel)   # ← зависит от текущего дерева
    ...
    panel.free()
    h.free()
```

**Проблема:** `add_child` в тесте привязывает ноду к `SceneTree`. Если тест запускается в `--headless` без `SceneTree` или параллельно с другими тестами — нестабильность.

**Решение:** для тестов, не требующих рендера, использовать `Node`-контейнер без `add_child`:
```gdscript
func test_panel() -> void:
    var panel := HeroStatusPanel.new()
    # Не добавляем в дерево, тестируем только логику
    panel.set_hero(hero)
    assert_that(panel._title.text).contains("Darkstorn")
    panel.free()
```

#### P3: Глобальное состояние в тестах

```gdscript
# test_settings_guard.gd
func test_apply_display_mode_headless_safe() -> void:
    var settings = _Settings.new()
    settings.fullscreen = true
    settings.apply_display_mode()  # ← вызывает DisplayServer
```

**Проблема:** `DisplayServer.window_set_mode` в headless-режиме может не работать или падать. Тест зависит от окружения.

**Решение:** мокировать `DisplayServer` или тестировать только `_Platform.is_headless()`-ветку.

#### P4: Нет тестов на `ServiceRegistry` и `services.gd`

`ServiceRegistry` — критический инфраструктурный компонент. Нет тестов на:
- `register_singleton` / `try_resolve`
- `register_autoload` с ленивым разрешением
- `clear()` и повторная регистрация
- Разрешение автозагрузки через `Engine.get_main_loop()`

#### P5: Нет тестов на `mcp_interaction_server.gd`

Файл на ~3000 строк без единого теста. Функциональные тесты через `godot-mcp` тестируют только верхнеуровневые сценарии (старт боя, сохранение), но не:
- `_handle_command` (парсинг JSON, диспетчеризация)
- `_send_response` / `_send_response_raw` (обработка ошибок записи)
- `_indent_code` (парсер отступов для `eval`)
- Таймаут `_busy`
- Обработку неизвестных команд

#### P6: Нестабильные функциональные тесты

```gdscript
# test_world_scenario.gd
func test_new_game_save_load_death_succession() -> void:
    var world := load(_WORLD_SCENE).instantiate()
    get_tree().root.add_child(world)
    # ... ожидание, пока ботстрап завершится
    assert_bool(await _wait_until(
        func(): return wc != null and wc.get_hero() != null and wc._save_svc != null
    )).is_true()
```

**Проблема:** зависит от скорости загрузки, таймеров, порядка `_ready`. На медленных машинах может падать по таймауту.

**Решение:** вынести ожидание в хелпер с явным увеличенным таймаутом и логированием.

#### P7: Тесты без `after_test` (утечки)

```gdscript
# test_battle_coordinator.gd
func before_test() -> void:
    coordinator = null
    coordinator = _Coordinator.new()
    coordinator.name = "TestCoordinator"
# ← нет after_test, coordinator не освобождается
```

**Решение:** всегда добавлять `after_test()` с `queue_free()` или `free()`.

#### P8: Тесты-заглушки без реальных проверок

```gdscript
# test_settings_guard.gd
func test_backpack_single_source() -> void:
    assert_that(HeroInventory.MAX_BACKPACK).is_equal(GameNumbers.MAX_BACKPACK_SIZE)
    assert_that(GameNumbers.MAX_BACKPACK_SIZE).is_equal(16)
```

Это не тест логики, а тест констант. Полезен как контрактный тест, но не несёт ценности при рефакторинге.

#### P9: Отсутствие негативных тестов

Для `ResourceChainService.build_extraction_keys`:
- ✅ Есть тест на кэширование
- ❌ Нет теста на `null`-героя
- ❌ Нет теста на героя без `army`

Для `BattleHandoff.collect`:
- ✅ Есть `test_collect_null_hero_invalid`
- ❌ Нет теста на `null`-rng (должен использовать `randi()`)

#### P10: Нет тестов на сериализацию/десериализацию с битыми данными

```gdscript
# Нет теста: что будет, если JSON содержит "version": 999?
# Нет теста: что будет, если "hero" содержит не-Dictionary?
# Нет теста: что будет, если "pop" содержит элементы без "state"?
```

---

## 4. Анализ MCP-тестов

### 4.1 Структура

```
tests/mcp/
├── conftest.py                    # Фикстуры: mcp, battle_scene, world_scene, full_game
├── godot_mcp.py                   # Клиент: GodotMCPClient, MCPError
├── pyproject.toml                 # Зависимости: pytest, mcp, anyio
├── pytest.ini                     # addopts = -xvs --tb=short
├── test_battle_full_e2e.py        # Полный бой через MCP
├── test_battle_profiling.py       # Профилирование кластеров
├── test_battle_tween.gd.py        # Твин-анимация без телепортаций
├── test_hexutils_perf.py          # Производительность A*, BFS, get_neighbor
├── test_resource_and.py           # Логика "И" для добычи ресурсов
├── test_save_load_continue.py     # Сейв → загрузка → продолжение
├── test_scene_transitions.py      # World → Battle → World
├── test_session_reset.py          # Сброс кэшей между сессиями
└── test_shard_pruning.py          # Обрезка шардов при сохранении
```

### 4.2 Качество фикстур

```python
# conftest.py
@pytest.fixture
def mcp():
    # Запускает godot-mcp сервер, ждёт готовности
    # Проблема: нет обработки случая, когда порт 9090 уже занят
    # Проблема: нет логирования при таймауте
    ...

@pytest.fixture
def full_game(mcp):
    # Запускает World, ждёт ботстрапа
    # Проблема: таймаут 120 секунд, но нет прогресс-логирования
    ...
```

**Проблемы:**
1. `wait_port_free` вызывается только в `run_scene`, но не перед стартом нового сервера в фикстуре `mcp`
2. `full_game` ждёт до 120 секунд без промежуточного логирования — при зависании непонятно, на каком этапе
3. Нет фикстуры для `MainMenu` (нельзя тестировать меню → создание персонажа → мир)

### 4.3 Пробелы в MCP-тестах

| Сценарий | Тест | Статус |
|---|---|---|
| Полный бой до победы | `test_battle_full_e2e.py` | ✅ |
| Сохранение и загрузка | `test_save_load_continue.py` | ✅ |
| Переход сцен | `test_scene_transitions.py` | ✅ |
| Создание персонажа → мир | ❌ | **Нет** |
| Городской цикл (построить → ход → урожай) | ❌ | **Нет** |
| Смерть героя → наследник | ❌ | **Нет** |
| Смерть героя → воскресение | ❌ | **Нет** |
| Захват деревни | ❌ | **Нет** |
| Торговля на рынке | ❌ | **Нет** |
| Рейд на город | ❌ | **Нет** |
| Демографический цикл | ❌ | **Нет** |
| Артефакт из сундука | ❌ | **Нет** |
| Свиток заклинания | ❌ | **Нет** |
| Вражеский ход (ИИ) | ❌ | **Нет** |

---

## 5. Рекомендации по рефакторингу тестов

### 5.1 [High] Удалить дубль `test_borough_rules.gd`

**Файл:** `tests/systems/city/test_borough_rules.gd` — удалить.

### 5.2 [High] Добавить тесты `ServiceRegistry`

**Файл:** `tests/unit/core/test_service_registry.gd` (новый)

```gdscript
extends GdUnitTestSuite

func test_register_and_resolve() -> void:
    var reg := ServiceRegistry.new()
    var obj := Node.new()
    reg.register_singleton(&"test", obj)
    assert_that(reg.try_resolve(&"test")).is_equal(obj)
    obj.free()

func test_resolve_unknown_returns_null() -> void:
    var reg := ServiceRegistry.new()
    assert_that(reg.try_resolve(&"nonexistent")).is_null()

func test_empty_key_rejected() -> void:
    var reg := ServiceRegistry.new()
    reg.register_singleton(&"", Node.new())
    assert_that(reg.try_resolve(&"")).is_null()

func test_clear_removes_all() -> void:
    var reg := ServiceRegistry.new()
    reg.register_singleton(&"a", Node.new())
    reg.clear()
    assert_that(reg.try_resolve(&"a")).is_null()
```

### 5.3 [High] Добавить тесты `mcp_interaction_server.gd`

**Файл:** `tests/unit/core/test_mcp_server.gd` (новый)

Тестировать через инстанцирование сервера без реального TCP:
- `_handle_command` с валидным/невалидным JSON
- `_indent_code` с разными отступами
- `_variant_to_json` для всех типов
- `_json_to_variant` с `type_hint`
- `_send_response` при `_client == null`

### 5.4 [High] Добавить тесты `WorldInput`

**Файл:** `tests/unit/world/test_world_input.gd` (новый)

- Обработка клика по карте
- Обработка ПКМ (отмена пути)
- Обработка колеса мыши (зум)
- Игнорирование ввода при открытом оверлее

### 5.5 [Medium] Стандартизировать `after_test`

Во всех тестах, создающих ноды:

```gdscript
func after_test() -> void:
    if _node != null and is_instance_valid(_node):
        _node.free()
    _node = null
```

### 5.6 [Medium] Вынести ожидание ботстпа в хелпер

**Файл:** `tests/helpers/wait_helpers.gd` (новый)

```gdscript
class_name TestWait

static func wait_for(condition: Callable, timeout_ms: int = 10000) -> bool:
    var deadline := Time.get_ticks_msec() + timeout_ms
    while Time.get_ticks_msec() < deadline:
        if condition.call():
            return true
        await Engine.get_main_loop().process_frame
    return condition.call()
```

### 5.7 [Medium] Добавить тесты на сериализацию с битыми данными

**Файл:** `tests/unit/core/test_save_data_garbage.gd` (новый)

```gdscript
extends GdUnitTestSuite

func test_from_dict_garbage_hero() -> void:
    var sd := SaveData.new()
    sd.from_dict({"version": 7, "run_seed": 1, "hero": "oops", "world": {}})
    assert_bool(sd.hero is Dictionary).is_true()

func test_from_dict_missing_hero() -> void:
    var sd := SaveData.new()
    sd.from_dict({"version": 7, "run_seed": 1})
    assert_bool(sd.is_valid()).is_false()

func test_from_dict_future_version() -> void:
    var sd := SaveData.new()
    sd.from_dict({"version": 999, "run_seed": 1, "hero": {"cell": {"x": 0, "y": 0}}, "world": {}})
    assert_that(sd.version).is_equal(SaveData.CURRENT_VERSION)
```

### 5.8 [Medium] Расширить MCP-тесты

Добавить в `tests/mcp/`:

| Файл | Сценарий |
|---|---|
| `test_city_cycle.py` | Построить ферму → ход → проверить урожай |
| `test_hero_death.py` | Убить героя → проверить наследника |
| `test_village_capture.py` | Подойти к деревне → захватить |
| `test_market_trade.py` | Построить рынок → продать ресурс |
| `test_raid.py` | Симулировать рейд |

### 5.9 [Low] Убрать тесты-константы

Заменить `test_backpack_single_source` на контрактный тест с комментарием:

```gdscript
# Контракт: лимит рюкзака определён в одном месте
# Если меняете — обновите оба значения
func test_backpack_limit_contract() -> void:
    assert_that(HeroInventory.MAX_BACKPACK).is_equal(GameNumbers.MAX_BACKPACK_SIZE)
```

---

## 6. Инструкция для локального агента

### Фаза 1: Критические правки (1 день)

| # | Действие | Файл |
|---|---|---|
| 1.1 | Удалить `tests/systems/city/test_borough_rules.gd` | Удалить файл |
| 1.2 | Создать `tests/unit/core/test_service_registry.gd` | Новый файл |
| 1.3 | Создать `tests/unit/core/test_save_data_garbage.gd` | Новый файл |
| 1.4 | Добавить `after_test()` во все тесты без него | ~15 файлов |

**Проверка:**
```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --ignoreHeadlessMode
```

### Фаза 2: Новые тесты для непокрытых модулей (2–3 дня)

| # | Действие | Файл |
|---|---|---|
| 2.1 | Тесты `mcp_interaction_server.gd` | `tests/unit/core/test_mcp_server.gd` |
| 2.2 | Тесты `WorldInput` | `tests/unit/world/test_world_input.gd` |
| 2.3 | Тесты `MapRenderer` | `tests/unit/world/test_map_renderer.gd` |
| 2.4 | Тесты `WorldSaveLoadService` | `tests/unit/world/test_save_load_service.gd` |
| 2.5 | Тесты `WorldShortcuts` | `tests/unit/world/test_world_shortcuts.gd` |

### Фаза 3: Расширение MCP-тестов (2–3 дня)

| # | Действие | Файл |
|---|---|---|
| 3.1 | Тест городского цикла | `tests/mcp/test_city_cycle.py` |
| 3.2 | Тест смерти героя | `tests/mcp/test_hero_death.py` |
| 3.3 | Тест захвата деревни | `tests/mcp/test_village_capture.py` |
| 3.4 | Фикстура для полного цикла (меню → персонаж → мир) | `tests/mcp/conftest.py` |

### Фаза 4: Рефакторинг существующих тестов (1–2 дня)

| # | Действие | Файл |
|---|---|---|
| 4.1 | Вынести `TestWait.wait_for` в хелпер | `tests/helpers/wait_helpers.gd` |
| 4.2 | Заменить `add_child` на прямой инстанс в тестах без рендера | ~10 файлов |
| 4.3 | Добавить негативные тесты для `ResourceChainService` | `tests/unit/world/test_resource_chain_service.gd` |
| 4.4 | Добавить тесты `HeroTools` | `tests/unit/entities/test_hero_tools.gd` |

**Финальная проверка:**
```bash
# Все юнит-тесты
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/ --ignoreHeadlessMode

# MCP E2E
cd tests/mcp && python -m pytest -xvs --tb=short

# Проверка компиляции
godot --headless --check-only --script res://tests/functional/test_compile_all.gd
```