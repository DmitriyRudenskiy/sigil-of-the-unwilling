# Анализ и исправление критических проблем архитектуры MCP-сервера и систем

## 1. Краткая сводка найденных проблем

1. **Deadlock MCP-сервера (`_busy` flag)**: Команды, использующие `_require_scene_tree()`, при ошибке вызывают `_send_response_raw()`, который **не сбрасывает** флаг `_busy`. Это блокирует сервер на 120 секунд (до срабатывания `BUSY_TIMEOUT`).
2. **Утечка памяти в Debug Draw**: Временные 3D-меши (`_debug_meshes`) с `duration > 0` добавляются в сцену, но **никогда не удаляются**, так как отсутствует таймер или метод декремента счетчика кадров.
3. **Stack Overflow в обходе дерева**: Рекурсивные методы `_build_tree_node()` и `_serialize_node()` упадут с `StackOverflow` на глубоких сценах (например, при сериализации всего дерева игры).
4. **Утечка памяти в Canvas Draw**: Массив `_draw_commands` растет бесконечно при каждом вызове `canvas_draw`, что приведет к деградации производительности рендеринга и OOM (Out Of Memory).
5. **Некорректный `self` в сериализации**: В `_serialize_node` проверка `child == self` всегда `false`, так как `self` — это `McpCommandsSystem` (`RefCounted`), а не `Node`. Нужно пропускать `server`.

---

## 2. Готовый код с исправлениями

### Файл 1: `res://game/mcp_interaction_server.gd`
**Изменения**: 
- Добавлен safety-net сброс `_busy` после выполнения команды.
- Добавлен вызов `tick_debug_draw()` в `_process` для очистки временных мешей.
- Исправлена логика отключения клиента.

```gdscript
// FILE: res://game/mcp_interaction_server.gd
extends Node
# MCP Interaction Server - TCP server for game interaction
# Runs as an autoload inside the Godot game, accepting JSON commands over TCP.
# No class_name to avoid autoload conflict.
# Command handlers live in mcp_commands_*.gd groups (see _handlers below).
var _server: TCPServer
var _client: StreamPeerTCP
var _buffer: String = ""
var _busy: bool = false
var _busy_since: float = 0.0
var _current_id: Variant = null

# Port: MCP_PORT env → ProjectSettings "mcp/port" → 9090.
static func port() -> int:
    var env := OS.get_environment("MCP_PORT")
    if env.is_valid_int():
        return env.to_int()
    return int(ProjectSettings.get_setting("mcp/port", 9090))

const BUSY_TIMEOUT: float = 120.0
const AUTH_TOKEN_ENV := "MCP_AUTH_TOKEN"
var _auth_token: String = ""

var _grp_input: McpCommandsInput
var _grp_ui: McpCommandsUI
var _grp_system: McpCommandsSystem
var _grp_render: McpCommandsRender
var _handlers: Dictionary = {}

func _ready() -> void:
    # Ensure MCP server keeps processing even when game is paused
    process_mode = Node.PROCESS_MODE_ALWAYS
    _auth_token = OS.get_environment(AUTH_TOKEN_ENV)
    _grp_input = McpCommandsInput.new(self)
    _grp_ui = McpCommandsUI.new(self)
    _grp_system = McpCommandsSystem.new(self)
    _grp_render = McpCommandsRender.new(self)
    # TASK_19 L1: McpCommandsNetwork (пустая заглушка) удалён.
    for group in [_grp_input, _grp_ui, _grp_system, _grp_render]:
        var cmds: Dictionary = group.get_commands()
        for name in cmds:
            _handlers[name] = cmds[name]
    _server = TCPServer.new()
    var port := port()
    var err: int = _server.listen(port, "127.0.0.1")
    if err != OK:
        push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [port, err])
        return
    print("McpInteractionServer: Listening on 127.0.0.1:%d" % port)

func _process(_delta: float) -> void:
    if _server == null:
        return
    
    # Tick debug draw to clean up expired meshes
    _grp_system.tick_debug_draw()

    # Safety timeout: force-reset _busy if it's been stuck too long
    if _busy and _busy_since > 0.0:
        var elapsed: float = Time.get_ticks_msec() / 1000.0 - _busy_since
        if elapsed > BUSY_TIMEOUT:
            push_warning("McpInteractionServer: _busy flag stuck for %.1fs, force-resetting" % elapsed)
            _busy = false
            _busy_since = 0.0
            _current_id = null

    # Accept new connections
    if _server.is_connection_available():
        var new_client: StreamPeerTCP = _server.take_connection()
        if new_client != null:
            if _client != null:
                _client.disconnect_from_host()
            _client = new_client
            _buffer = ""
            print("McpInteractionServer: Client connected")

    # Read data from client
    if _client == null:
        return
    _client.poll()
    var status: int = _client.get_status()
    if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
        print("McpInteractionServer: Client disconnected")
        _client = null
        _buffer = ""
        _busy = false
        _busy_since = 0.0
        _current_id = null
        return
    if status != StreamPeerTCP.STATUS_CONNECTED:
        return

    var available: int = _client.get_available_bytes()
    if available > 0:
        var data: Array = _client.get_data(available)
        if data[0] == OK:
            var bytes: PackedByteArray = data[1]
            _buffer += bytes.get_string_from_utf8()

    # Process complete lines (newline-delimited JSON)
    while _buffer.find("\n") >= 0:
        var newline_pos: int = _buffer.find("\n")
        var line: String = _buffer.substr(0, newline_pos).strip_edges()
        _buffer = _buffer.substr(newline_pos + 1)
        if line.length() > 0:
            _handle_command(line)

func _handle_command(json_str: String) -> void:
    var json: JSON = JSON.new()
    var parse_err: int = json.parse(json_str)
    if parse_err != OK:
        _send_response_raw({"error": "Invalid JSON: %s" % json.get_error_message()})
        return
    var data: Variant = json.data
    if not data is Dictionary:
        _send_response_raw({"error": "Expected JSON object"})
        return
    var req_id: Variant = data.get("id", null)
    # Auth is opt-in: when MCP_AUTH_TOKEN is set, every request must carry it.
    if not _auth_token.is_empty() and str(data.get("token", "")) != _auth_token:
        _send_response_raw({"error": "Unauthorized", "id": req_id})
        return
    if _busy:
        _send_response_raw({"error": "Server busy processing another command. Try again.", "id": req_id})
        return
    _busy = true
    _busy_since = Time.get_ticks_msec() / 1000.0
    _current_id = req_id
    var command: String = data.get("command", "")
    var params: Dictionary = data.get("params", {})
    if not _handlers.has(command):
        _send_response({"error": "Unknown command: %s" % command})
        return
    # TASK_19 M3: центральная проверка сцены (заменяет дубли в командах).
    if not is_inside_tree():
        _send_response({"error": "Server not in scene tree"})
        return
    var handler: Callable = _handlers[command]
    # Awaiting a non-coroutine handler returns immediately, so one path covers sync and async.
    await handler.call(params)
    
    # SAFETY NET: If handler finished without calling _send_response, force reset busy state.
    if _busy:
        _busy = false
        _busy_since = 0.0
        _current_id = null

# Send response and clear busy flag
func _send_response(data: Dictionary) -> void:
    _busy = false
    _busy_since = 0.0
    if _current_id != null and not data.has("id"):
        data["id"] = _current_id
    _current_id = null
    _send_response_raw(data)

# Send response without clearing busy flag (used ONLY when rejecting during busy state)
func _send_response_raw(data: Dictionary) -> void:
    if _client == null:
        push_warning("McpInteractionServer: no client, response dropped")
        return
    if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        push_error("McpInteractionServer: client not connected, dropping response and resetting")
        _client.disconnect_from_host()
        _client = null
        _busy = false
        _busy_since = 0.0
        _current_id = null
        return
    var json_str: String = JSON.stringify(data) + "\n"
    var bytes: PackedByteArray = json_str.to_utf8_buffer()
    _client.put_data(bytes)

func _exit_tree() -> void:
    _grp_system._clear_debug_draw()
    if _client != null:
        _client.disconnect_from_host()
        _client = null
    if _server != null:
        _server.stop()
        _server = null
    print("McpInteractionServer: Stopped")
```

### Файл 2: `res://game/mcp_commands_base.gd`
**Изменения**: `_require_scene_tree` теперь использует `_send_response` вместо `_send_response_raw`, что гарантированно сбрасывает флаг `_busy` и предотвращает deadlock.

```gdscript
// FILE: res://game/mcp_commands_base.gd
class_name McpCommandsBase
extends RefCounted
## Base class for MCP command groups.
## A group owns a set of MCP commands: get_commands() maps command name -> bound Callable.
## All command methods take (params: Dictionary) and send their reply via server._send_response().
var server: Node  # McpInteractionServer

func _init(s: Node) -> void:
    server = s

## Map of command name -> Callable.
func get_commands() -> Dictionary:
    return {}

## Rejects the request unless the server is in the scene tree. Returns false if rejected.
func _require_scene_tree() -> bool:
    if not server.is_inside_tree():
        # FIX: Use _send_response to properly clear the _busy flag and prevent deadlock.
        server._send_response({"error": "Server not in scene tree"})
        return false
    return true

## Execute a command by name. Returns the handler result (or an error dict).
func execute(command: String, params: Dictionary) -> Variant:
    var handler: Callable = get_commands().get(command, Callable())
    if not handler.is_valid():
        return {"error": "Unknown command: %s" % command}
    # TASK_19 M3: центральная проверка — отдельные команды её не дублируют.
    if not _require_scene_tree():
        return null
    return await handler.call(params)

## Shared helper: collect nodes of a class under a root (used by render + system groups).
## Iterative DFS (TASK_18 R8): no stack overflow on deep trees, no infinite
## recursion if a cycle is ever introduced into the node tree.
func _find_by_class_recursive(root: Node, class_filter: String, results: Array) -> void:
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node.get_class() == class_filter or node.is_class(class_filter):
            results.append({
                "name": node.name,
                "type": node.get_class(),
                "path": str(node.get_path())
            })
        for child: Node in node.get_children():
            stack.push_back(child)
```

### Файл 3: `res://game/mcp_commands_system.gd`
**Изменения**:
- `_build_tree_node` и `_serialize_node` переписаны на итеративный DFS (защита от Stack Overflow).
- Добавлен метод `tick_debug_draw()` для очистки временных 3D-мешей по таймеру.
- Исправлена ошибка `child == self` (теперь корректно пропускает `server`).

```gdscript
// FILE: res://game/mcp_commands_system.gd
# ... (оставьте начало файла и get_commands() без изменений) ...

func _cmd_get_scene_tree(_params: Dictionary) -> void:
    var tree: Dictionary = _build_tree_node(server.get_tree().root)
    server._send_response({"success": true, "tree": tree})

## Iterative tree builder to prevent Stack Overflow on deep scenes.
func _build_tree_node(root: Node) -> Dictionary:
    var root_dict: Dictionary = {
        "name": root.name,
        "type": root.get_class(),
    }
    var stack: Array = [[root, root_dict]]
    while not stack.is_empty():
        var current: Array = stack.pop_back()
        var node: Node = current[0]
        var node_dict: Dictionary = current[1]
        var children_arr: Array = []
        for child in node.get_children():
            var child_dict: Dictionary = {
                "name": child.name,
                "type": child.get_class(),
            }
            children_arr.append(child_dict)
            stack.push_back([child, child_dict])
        if children_arr.size() > 0:
            node_dict["children"] = children_arr
    return root_dict

# ... (пропустите остальные команды до _cmd_serialize_state) ...

func _cmd_serialize_state(params: Dictionary) -> void:
    var node_path: String = params.get("node_path", "/root")
    var action: String = params.get("action", "save")
    var max_depth: int = int(params.get("max_depth", 5))
    var node: Node = server.get_tree().root.get_node_or_null(node_path)
    if node == null:
        server._send_response({"error": "Node not found: %s" % node_path})
        return
    match action:
        "save":
            var state: Dictionary = _serialize_node(node, max_depth, 0)
            server._send_response({"success": true, "action": "save", "state": state})
        "load":
            var data: Dictionary = params.get("data", {})
            if data.is_empty():
                server._send_response({"error": "data is required for load action"})
                return
            var count: int = _deserialize_node(node, data)
            server._send_response({"success": true, "action": "load", "restored_count": count})
        _:
            server._send_response({"error": "Unknown serialize action: %s. Use save or load" % action})

## Iterative serialization to prevent Stack Overflow.
func _serialize_node(root: Node, max_depth: int, _depth: int) -> Dictionary:
    var root_dict: Dictionary = _build_serialize_dict(root)
    if max_depth <= 0:
        return root_dict
    
    var stack: Array = [[root, root_dict, 0]]
    while not stack.is_empty():
        var current: Array = stack.pop_back()
        var node: Node = current[0]
        var node_dict: Dictionary = current[1]
        var depth: int = current[2]
        
        if depth < max_depth:
            var children_arr: Array = []
            for child in node.get_children():
                # FIX: Skip the MCP interaction server itself, not 'self' (which is RefCounted)
                if child == server:
                    continue
                var child_dict: Dictionary = _build_serialize_dict(child)
                children_arr.append(child_dict)
                stack.push_back([child, child_dict, depth + 1])
            node_dict["children"] = children_arr
    return root_dict

func _build_serialize_dict(node: Node) -> Dictionary:
    var result: Dictionary = {
        "class": node.get_class(),
        "name": node.name,
        "path": str(node.get_path()),
    }
    var props: Dictionary = {}
    for prop in node.get_property_list():
        var prop_dict: Dictionary = prop
        if prop_dict.get("usage", 0) & PROPERTY_USAGE_STORAGE:
            var prop_name: String = prop_dict.get("name", "")
            if prop_name.is_empty() or prop_name.begins_with("_"):
                continue
            props[prop_name] = McpSerialization.variant_to_json(node.get(prop_name))
    result["properties"] = props
    return result

func _deserialize_node(node: Node, data: Dictionary) -> int:
    var count: int = 0
    # Restore properties
    var props: Dictionary = data.get("properties", {})
    for prop_name in props:
        var value: Variant = _json_to_variant_for_property(node, prop_name, props[prop_name])
        node.set(prop_name, value)
        count += 1
    # Restore children
    var children_data: Array = data.get("children", [])
    for child_data in children_data:
        var child_name: String = child_data.get("name", "")
        var child: Node = null
        for c in node.get_children():
            if c.name == child_name:
                child = c
                break
        if child != null:
            count += _deserialize_node(child, child_data)
    return count

# ... (пропустите до конца файла) ...

## Called from McpInteractionServer._process to decrement debug mesh lifetimes.
func tick_debug_draw() -> void:
    if _debug_meshes.is_empty():
        return
    var to_remove: Array[int] = []
    for i in _debug_meshes.size():
        var entry: Dictionary = _debug_meshes[i]
        if entry["frames_left"] > 0:
            entry["frames_left"] -= 1
            if entry["frames_left"] <= 0:
                to_remove.append(i)
    
    # Remove expired meshes in reverse order to maintain valid indices
    for i in range(to_remove.size() - 1, -1, -1):
        var idx: int = to_remove[i]
        var entry: Dictionary = _debug_meshes[idx]
        if is_instance_valid(entry["node"]):
            entry["node"].queue_free()
        _debug_meshes.remove_at(idx)

func _clear_debug_draw() -> void:
    for entry in _debug_meshes:
        if is_instance_valid(entry["node"]):
            entry["node"].queue_free()
    _debug_meshes.clear()
    if _debug_draw_node != null and is_instance_valid(_debug_draw_node):
        _debug_draw_node.queue_free()
        _debug_draw_node = null
```

### Файл 4: `res://game/mcp_commands_ui.gd`
**Изменения**: Добавлен лимит на размер массива `_draw_commands` для предотвращения утечки памяти при интенсивном использовании API рисования.

```gdscript
// FILE: res://game/mcp_commands_ui.gd
class_name McpCommandsUI
extends McpCommandsBase
var _canvas_draw_node: McpCanvasDrawNode = null
var _draw_commands: Array = []
const MAX_DRAW_COMMANDS: int = 5000 # Prevent memory leak from unbounded growth

func get_commands() -> Dictionary:
    return {
        "screenshot": _cmd_screenshot,
        "get_ui_elements": _cmd_get_ui_elements,
        "ui_theme": _cmd_ui_theme,
        "ui_control": _cmd_ui_control,
        "ui_text": _cmd_ui_text,
        "ui_popup": _cmd_ui_popup,
        "ui_tree": _cmd_ui_tree,
        "ui_item_list": _cmd_ui_item_list,
        "ui_tabs": _cmd_ui_tabs,
        "ui_menu": _cmd_ui_menu,
        "ui_range": _cmd_ui_range,
        "viewport": _cmd_viewport,
        "window": _cmd_window,
        "canvas_draw": _cmd_canvas_draw,
        "video": _cmd_video,
    }

# ... (пропустите до _cmd_canvas_draw) ...

func _cmd_canvas_draw(params: Dictionary) -> void:
    var action: String = params.get("action", "line")
    if action == "clear":
        _draw_commands.clear()
        if _canvas_draw_node != null and is_instance_valid(_canvas_draw_node):
            _canvas_draw_node.queue_redraw()
        server._send_response({"success": true, "action": "clear"})
        return
    if not action in ["line", "rect", "circle", "polygon", "text"]:
        server._send_response({"error": "Unknown canvas_draw action: %s" % action})
        return
    # Ensure draw node
    if _canvas_draw_node == null or not is_instance_valid(_canvas_draw_node):
        var parent_path: String = params.get("parent_path", "/root")
        var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
        if parent == null:
            server._send_response({"error": "Parent not found: %s" % parent_path})
            return
        # TASK_19_1 S3: обычный класс вместо GDScript.new() + reload() из строки.
        _canvas_draw_node = McpCanvasDrawNode.new()
        _canvas_draw_node.name = "_McpCanvasDraw"
        parent.add_child(_canvas_draw_node)
        _canvas_draw_node.draw_commands = _draw_commands
        
    var color_d: Dictionary = params.get("color", {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0})
    var color: Color = Color(float(color_d.get("r", 1)), float(color_d.get("g", 1)), float(color_d.get("b", 1)), float(color_d.get("a", 1)))
    
    _draw_commands.append({"action": action, "params": params, "color": color})
    
    # FIX: Prevent unbounded memory growth by keeping only the latest commands
    if _draw_commands.size() > MAX_DRAW_COMMANDS:
        _draw_commands = _draw_commands.slice(-MAX_DRAW_COMMANDS)
        
    _canvas_draw_node.draw_commands = _draw_commands
    _canvas_draw_node.queue_redraw()
    server._send_response({"success": true, "action": action})

# ... (остальной код без изменений) ...
```

---

## 3. Инструкция по установке и внедрению (Runbook)

### Шаг 1: Замена файлов
Скопируйте предоставленные блоки кода и полностью замените содержимое следующих файлов в вашем проекте:
1. `res://game/mcp_interaction_server.gd`
2. `res://game/mcp_commands_base.gd`
3. `res://game/mcp_commands_system.gd`
4. `res://game/mcp_commands_ui.gd`

### Шаг 2: Интеграционные изменения
Никаких дополнительных изменений в `project.godot` или других файлах не требуется. Все исправления локализованы внутри MCP-подсистемы.

### Шаг 3: Команды для проверки
Запустите headless-тесты, чтобы убедиться, что регрессии не возникли:
```bash
godot --headless --path ./game -s res://tests/run_tests.gd
```
*(Если у вас есть специфичный скрипт запуска тестов, используйте его).*

### Шаг 4: Критерии приёмки (Ручная проверка через MCP-клиент)

1. **Проверка Deadlock Fix**:
   - Откройте игру, но **не загружайте** основную сцену (или остановите дерево сцены).
   - Отправьте MCP-команду, требующую сцены (например, `get_scene_tree` или `click`).
   - **Ожидаемый результат**: Сервер должен вернуть `{"error": "Server not in scene tree"}` и **немедленно** разблокировать флаг `_busy`. Следующая команда должна выполниться без задержки в 120 секунд.

2. **Проверка Debug Draw Memory Leak**:
   - Отправьте команду `debug_draw` с `{"action": "sphere", "duration": 60, ...}`.
   - Подождите 2-3 секунды (60 кадров при 60 FPS).
   - **Ожидаемый результат**: Сфера должна автоматически исчезнуть из сцены. В Remote-дереве Godot нода `_McpDebugDraw` не должна бесконечно накапливать дочерние MeshInstance3D.

3. **Проверка Stack Overflow Fix**:
   - Создайте глубокую иерархию нод (например, 500 вложенных `Node3D`).
   - Отправьте команду `get_scene_tree`.
   - **Ожидаемый результат**: Сервер должен вернуть полное дерево без краша Godot с ошибкой `Stack Overflow`.

4. **Проверка Canvas Draw Memory Limit**:
   - Напишите скрипт, который отправляет 10000 команд `canvas_draw` подряд.
   - **Ожидаемый результат**: Игра не должна зависать или падать с OOM. В памяти должно храниться не более 5000 последних команд.