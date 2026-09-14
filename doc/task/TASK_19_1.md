# Аудит: следующий раунд замечаний

Проанализировал базу знаний. Ниже — неисправленные проблемы и новые находки.

---

## 1. Безопасность — **КРИТИЧНО**

### S1. `eval` и `script` доступны без `OS.is_debug_build()`

**Файл:** `mcp_commands_system.gd`

В `get_commands()` обе команды регистрируются **безусловно**:

```gdscript
func get_commands() -> Dictionary:
    return {
        "eval": _cmd_eval,          # ← доступно в релизе
        "script": _cmd_script,      # ← доступно в релизе
        ...
    }
```

**Правка:**

```gdscript
func get_commands() -> Dictionary:
    var commands := {
        "get_scene_tree": _cmd_get_scene_tree,
        "get_property": _cmd_get_property,
        # ... все безопасные команды ...
        "locale": _cmd_locale,
    }
    if OS.is_debug_build():
        commands["eval"] = _cmd_eval
        commands["script"] = _cmd_script
    return commands
```

**Приоритет:** 🔴 High

---

### S2. `_cmd_await_signal` — бесконечный цикл

**Файл:** `mcp_commands_system.gd`, метод `_cmd_await_signal`

```gdscript
while not result[0] and timer.time_left > 0:
    await server.get_tree().process_frame
```

Если дерево на паузе или `process_frame` не наступает (headless без `PROCESS_MODE_ALWAYS`), цикл зависает навсегда.

**Правка:**

```gdscript
func _cmd_await_signal(params: Dictionary) -> void:
    # ... валидация ...
    var timer: SceneTreeTimer = server.get_tree().create_timer(timeout)
    var result: Array = [false, []]
    var cb: Callable = func(): result[0] = true
    node.connect(signal_name, cb, CONNECT_ONE_SHOT)
    
    var max_frames := 30_000  # ~500 секунд при 60 FPS
    var frames := 0
    while not result[0] and timer.time_left > 0:
        await server.get_tree().process_frame
        frames += 1
        if frames >= max_frames:
            break
    
    if node.is_connected(signal_name, cb):
        node.disconnect(signal_name, cb)
    # ... ответ ...
```

**Приоритет:** 🔴 High

---

### S3. `_create_draw_script()` — генерация кода из строки

**Файл:** `mcp_commands_ui.gd`, метод `_create_draw_script()`

Метод конструирует `GDScript` из многострочной строки и вызывает `reload()`. Это эквивалентно `eval` без блэк-листа.

**Правка:** Заменить на обычный класс:

```gdscript
# Новый файл: scripts/ui/McpCanvasDrawNode.gd
class_name McpCanvasDrawNode
extends Node2D

var draw_commands: Array = []

func _draw() -> void:
    for cmd in draw_commands:
        var p: Dictionary = cmd.params
        var c: Color = cmd.color
        match cmd.action:
            "line":
                var f: Dictionary = p.get("from", {})
                var t: Dictionary = p.get("to", {})
                draw_line(
                    Vector2(float(f.get("x", 0)), float(f.get("y", 0))),
                    Vector2(float(t.get("x", 0)), float(t.get("y", 0))),
                    c, float(p.get("width", 2))
                )
            # ... остальные ветки ...
```

Затем в `_cmd_canvas_draw` заменить `_create_draw_script()` на `McpCanvasDrawNode.new()`.

**Приоритет:** 🔴 High

---

## 2. Производительность

### P1. `VisibilityMap._fill_disk` пересчитывает смещения кольца каждый раз

**Файл:** `core/VisibilityMap.gd`

`HexUtils.ring(center, r, shift_right)` строит массив для каждого радиуса. При перемещении героя на 1 клетку пересчитываются все диски.

**Правка:** Кэшировать смещения колец:

```gdscript
var _ring_offsets_cache: Dictionary = {}  # {radius: Array[Vector2i]}

func _get_ring_offsets(radius: int, shift_right: bool) -> Array[Vector2i]:
    var key := Vector2i(radius, int(shift_right))
    if _ring_offsets_cache.has(key):
        return _ring_offsets_cache[key]
    var offsets := HexUtils.ring(Vector2i.ZERO, radius, shift_right)
    _ring_offsets_cache[key] = offsets
    return offsets

func _fill_disk(center: Vector2i, radius: int, out: Dictionary, shift_right: bool = true) -> void:
    if radius < 0:
        return
    if is_in_bounds(center):
        out[center] = 1
    for r in range(1, radius + 1):
        var offsets := _get_ring_offsets(r, shift_right)
        for offset in offsets:
            var cell := center + offset
            if is_in_bounds(cell):
                out[cell] = 1
```

**Приоритет:** 🟡 Medium

---

### P2. `ResourceIcons._registry_cache` не инвалидируется при `Services.clear_session()`

**Файл:** `data/ResourceIcons.gd`, `core/StaticCaches.gd`

`ResourceIcons._registry_cache` хранит ссылку на `Resources`-ноду, но `StaticCaches.reset_all()` вызывает только `ResourceIcons.clear_cache()`, который **не сбрасывает** `_registry_cache`.

**Правка в `ResourceIcons.gd`:**

```gdscript
static func clear_cache() -> void:
    _cache.clear()  # уже есть
    _registry_cache = null  # ← добавить
```

**Приоритет:** 🟡 Medium

---

### P3. `TerrainCostTable.ensure()` вызывается в каждой функции

**Файл:** `data/TerrainCostTable.gd`

`ensure()` проверяет `_costs.is_empty()` на каждый вызов `get_cost()`. В горячем цикле пути (`dijkstra`, `astar`) это лишняя проверка.

**Правка:** Вызвать `ensure()` один раз при инициализации мира, убрать из публичных методов:

```gdscript
# В WorldBootstrap._init_services():
TerrainCostTable.ensure()

# В get_cost / get_cost_with_effects / get_cost_with_effects_by_id:
# убрать вызов ensure(), добавить ассерт:
static func get_cost(terrain: String) -> float:
    # ensure() — убрать, таблица инициализирована при старте
    if terrain == "water":
        return WATER
    return _costs.get(terrain, GRASS)
```

**Приоритет:** 🟢 Low

---

## 3. Архитектура

### A1. `mcp_commands_system.gd` — 40+ команд в одном классе

**Файл:** `mcp_commands_system.gd`

Класс содержит команды для сигналов, анимации, физики, навигации, локали, сериализации. Это нарушение SRP.

**Правка:** Разделить на группы:

| Новый класс | Команды |
|---|---|
| `McpCommandsScene` | `get_scene_tree`, `instantiate_scene`, `remove_node`, `reparent_node`, `spawn_node`, `find_nodes_by_class` |
| `McpCommandsSignals` | `connect_signal`, `disconnect_signal`, `emit_signal`, `await_signal`, `list_signals` |
| `McpCommandsAnimation` | `play_animation`, `tween_property`, `create_animation` |
| `McpCommandsPhysics` | `raycast`, `navigate_path`, `physics_body`, `create_joint`, `add_collision` |
| `McpCommandsSystem` | `os_info`, `time_scale`, `process_mode`, `pause`, `get_performance`, `locale` |

**Приоритет:** 🟡 Medium

---

### A2. `BattleController` — бог-объект

**Файл:** `systems/BattleController.gd`

Владеет: состоянием боя, исполнителем, вводом, эффектами, магией, препятствиями. 12 полей, 15+ методов.

**Правка:** Выделить `BattleSetup` (инициализация состояния и препятствий) и `BattleMagicGate` (проверка и списание маны).

**Приоритет:** 🟢 Low

---

## 4. Баги и граничные случаи

### B1. `HexPathfinding.dijkstra` — `visited` не очищается

**Файл:** `core/HexPathfinding.gd`

`visited` как `Dictionary` накапливает ключи `cur_idx`, но не удаляется. При многократных вызовах `dijkstra` в одном кадре (несколько юнитов) память растёт.

**Правка:** Заменить `Dictionary` на `PackedByteArray` фиксированного размера:

```gdscript
static func dijkstra(start: Vector2i, max_cost: float, cost_fn: Callable,
                     w: int, h: int, shift_right: bool = true) -> PackedFloat32Array:
    var n := w * h
    var dist := PackedFloat32Array()
    dist.resize(n)
    dist.fill(INF)
    
    var visited := PackedByteArray()  # ← вместо Dictionary
    visited.resize(n)
    
    var start_idx := HexUtils.pos_to_idx(start, w)
    dist[start_idx] = 0.0
    var open := MinHeap.new()
    open.push([0.0, start])
    
    while not open.is_empty():
        var cur: Array = open.pop()
        var cur_d: float = cur[0]
        var cur_cell: Vector2i = cur[1]
        var cur_idx := HexUtils.pos_to_idx(cur_cell, w)
        
        if visited[cur_idx] == 1:
            continue
        visited[cur_idx] = 1
        
        if cur_d > dist[cur_idx] or cur_d > max_cost:
            continue
        
        for bit in 6:
            var nxt := HexUtils.get_neighbor(cur_cell, bit, shift_right)
            if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
                continue
            var enter_cost: float = cost_fn.call(nxt)
            if enter_cost >= INF:
                continue
            var new_d: float = cur_d + enter_cost
            var nxt_idx := HexUtils.pos_to_idx(nxt, w)
            if new_d < dist[nxt_idx] and new_d <= max_cost:
                dist[nxt_idx] = new_d
                open.push([new_d, nxt])
    
    # Финальная чистка: обрезаем значения > max_cost
    for i in n:
        if dist[i] > max_cost + 0.001:
            dist[i] = INF
    return dist
```

**Приоритет:** 🟡 Medium

---

### B2. `BattleFX.play_attack_sequence` возвращает `null` вне дерева

**Файл:** `core/BattleFX.gd`

```gdscript
func play_attack_sequence(...) -> SceneTreeTimer:
    if not is_inside_tree():
        push_warning("BattleFX.play_attack_sequence: not in tree — sequence skipped")
        return null  # ← вызывающий код может не обработать
```

В `BattleController._on_execute_attack`:

```gdscript
await _fx.play_attack_sequence(atk, def, result)
if not is_inside_tree():
    return
```

Если `play_attack_sequence` вернёт `null`, `await null` завершится мгновенно, но `is_inside_tree()` может быть `false`.

**Правка:** Проверять результат:

```gdscript
func _on_execute_attack(atk, def, result) -> void:
    _show_damage_feedback(def, result)
    var timer := _fx.play_attack_sequence(atk, def, result)
    if timer == null:
        if is_instance_valid(_executor):
            _executor.on_attack_completed()
        return
    await timer
    if not is_inside_tree():
        return
    if is_instance_valid(_executor):
        _executor.on_attack_completed()
```

**Приоритет:** 🟡 Medium

---

## 5. Рефакторинг

### R1. Удаление `GameNumbers`-шима

**Файл:** `constants/GameNumbers.gd`

Шим на 300+ строк перенаправляет все константы в доменные классы (`GameNumbersBattle`, `GameNumbersCity`, и т.д.). После миграции всех потребителей его можно удалить.

**План:**
1. Найти все `GameNumbers.` в коде (кроме самого шима).
2. Заменить на прямые ссылки (`GameNumbersBattle.`, `GameNumbersCity.`, и т.д.).
3. Удалить `GameNumbers.gd`.

**Приоритет:** 🟢 Low (требует массовой миграции)

---

### R2. `BuildingDefs.def_by_id()` создаёт `Def` на каждый вызов

**Файл:** `data/BuildingDefs.gd`

```gdscript
static func def_by_id(id: StringName) -> UniqueBuilding.Def:
    _ensure_loaded()
    for raw in _raw_cache:
        if raw is Dictionary and String(raw.get("id", "")) == String(id):
            return _build_def(raw)  # ← новый объект каждый раз
    return null
```

**Правка:**

```gdscript
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

Вызвать `BuildingDefs.reset_cache()` в `StaticCaches.reset_all()`.

**Приоритет:** 🟡 Medium

---

## 6. Тесты

### T1. `test_save_load_screen.gd` — утечка `_sm`

**Файл:** `tests/unit/ui/test_save_load_screen.gd`

В `before_test()` создаётся `_sm = SaveManager.new()`, добавляется через `add_child(_sm)`. В `after_test()` вызывается `_screen.free()` и `_sm.queue_free()`, но `_sm` может не успеть освободиться до следующего теста.

**Правка:** Использовать `auto_free(_sm)` вместо ручного управления.

**Приоритет:** 🟢 Low

---

### T2. `test_settings_screen_cancel_restores_volume` — нет очистки `_ss_screen`

**Файл:** `tests/unit/test_settings_persist.gd`

`_ss_screen` создаётся через `load(...).instantiate()` и добавляется в корень, но не удаляется в `after_test()`.

**Правка:** Добавить в `after_test()`:

```gdscript
func after_test() -> void:
    # ... существующий код ...
    if _ss_screen != null and is_instance_valid(_ss_screen):
        _ss_screen.queue_free()
        _ss_screen = null
    if _ss_settings != null and is_instance_valid(_ss_settings):
        _ss_settings.free()
        _ss_settings = null
```

**Приоритет:** 🟢 Low

---

## Сводная таблица

| # | Проблема | Файл | Приоритет | Категория |
|---|---|---|---|---|
| S1 | `eval`/`script` без `is_debug_build()` | `mcp_commands_system.gd` | 🔴 High | Безопасность |
| S2 | `_cmd_await_signal` бесконечный цикл | `mcp_commands_system.gd` | 🔴 High | Безопасность |
| S3 | `_create_draw_script()` генерация кода | `mcp_commands_ui.gd` | 🔴 High | Безопасность |
| P1 | `VisibilityMap` пересчёт смещений | `VisibilityMap.gd` | 🟡 Medium | Производительность |
| P2 | `ResourceIcons._registry_cache` не сбрасывается | `ResourceIcons.gd` | 🟡 Medium | Производительность |
| B1 | `dijkstra` утечка через `visited` | `HexPathfinding.gd` | 🟡 Medium | Память |
| B2 | `BattleFX` возврат `null` | `BattleFX.gd` | 🟡 Medium | Надёжность |
| R2 | `BuildingDefs.def_by_id()` без кэша | `BuildingDefs.gd` | 🟡 Medium | Производительность |
| A1 | `mcp_commands_system` — 40 команд | `mcp_commands_system.gd` | 🟡 Medium | Архитектура |
| P3 | `TerrainCostTable.ensure()` в горячем цикле | `TerrainCostTable.gd` | 🟢 Low | Производительность |
| A2 | `BattleController` — бог-объект | `BattleController.gd` | 🟢 Low | Архитектура |
| R1 | `GameNumbers`-шим | `GameNumbers.gd` | 🟢 Low | Рефакторинг |
| T1 | Утечка `_sm` в тесте | `test_save_load_screen.gd` | 🟢 Low | Тесты |
| T2 | Нет очистки `_ss_screen` | `test_settings_persist.gd` | 🟢 Low | Тесты |

---

## Инструкция для локального агента

```
Фаза 1 — Безопасность (срочно)
├── Шаг 1.1: Обернуть "eval" и "script" в if OS.is_debug_build()
│   Файл: mcp_commands_system.gd → get_commands()
│   Критерий: в релизной сборке эти команды отсутствуют
│   Тест: запустить с --release, вызвать "eval" → ошибка "Unknown command"
│
├── Шаг 1.2: Добавить счётчик кадров в _cmd_await_signal
│   Файл: mcp_commands_system.gd → _cmd_await_signal()
│   Критерий: после 30 000 кадров цикл прерывается
│
└── Шаг 1.3: Заменить _create_draw_script() на класс
    Файл: новый файл scripts/ui/McpCanvasDrawNode.gd
    Файл: mcp_commands_ui.gd → _cmd_canvas_draw()
    Критерий: нет вызовов GDScript.new() + reload() из строк

Фаза 2 — Производительность
├── Шаг 2.1: Кэш смещений колец в VisibilityMap
│   Файл: core/VisibilityMap.gd
│   Критерий: _fill_disk не вызывает HexUtils.ring для каждого радиуса
│
├── Шаг 2.2: Сброс _registry_cache в ResourceIcons.clear_cache()
│   Файл: data/ResourceIcons.gd
│   Критерий: после clear_cache() следующий вызов _registry() пересоздаёт ссылку
│
├── Шаг 2.3: Кэш в BuildingDefs.def_by_id()
│   Файл: data/BuildingDefs.gd
│   Критерий: повторный вызов возвращает тот же объект (===)
│   Добавить вызов в StaticCaches.reset_all()
│
└── Шаг 2.4: Заменить visited в dijkstra на PackedByteArray
    Файл: core/HexPathfinding.gd
    Критерий: бенчмарк A* не деградирует

Фаза 3 — Надёжность
├── Шаг 3.1: Обработка null из BattleFX.play_attack_sequence
│   Файл: systems/BattleController.gd → _on_execute_attack()
│   Критерий: при возврате null вызывается on_attack_completed()
│
└── Шаг 3.2: Убрать ensure() из горячих методов TerrainCostTable
    Файл: data/TerrainCostTable.gd
    Вызвать ensure() в WorldBootstrap._init_services()

Фаза 4 — Проверка
├── Запуск полного набора тестов
├── Бенчмарк A* (не более 200 мс)
└── Проверка отсутствия eval в релизной сборке
```

**Критерии приёмки:**
- Все тесты проходят: `0 failed, 0 errors`
- В релизе `eval`/`script` возвращают `"Unknown command"`
- Бенчмарк A* ≤ 200 мс
- `BuildingDefs.def_by_id("farm") is BuildingDefs.def_by_id("farm")` → `true`

Готов детализировать любую правку или перейти к реализации.