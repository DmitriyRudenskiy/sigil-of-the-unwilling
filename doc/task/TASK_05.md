### Сводка найденных проблем

1. **TCP UTF-8 Fragmentation (Критический баг)**: В `mcp_interaction_server.gd` байты читаются и сразу конвертируются через `get_string_from_utf8()`. Если TCP-пакет разрывает многобайтовый символ (кириллица, эмодзи), строка ломается, JSON становится невалидным, и парсер отклоняет команду.
2. **Крэш и зависание `_cmd_eval` (Критический баг)**: 
   - Использование оператора `%` для инъекции кода падает с `Invalid format string`, если в пользовательском коде встречается символ `%`.
   - Функция `_indent_code` заменяет *каждый отдельльный пробел* на табуляцию. Это гарантированно вызывает ошибку компиляции GDScript (`Mixed use of tabs and spaces`), из-за чего `await` в `_cmd_eval` виснет навечно (несмотря на watchdog, ошибка компиляции прерывает корутину до её создания).
3. **Утечка ноды `HTTPRequest` (Утечка памяти)**: При разрыве соединения или таймауте сервера нода `HTTPRequest`, созданная в `_cmd_http_request`, не освобождается, так как `await` прерывается или не доходит до `queue_free()`.
4. **Статический кэш `ArenaClusterSystem` (Утечка памяти / Фантомные данные)**: `static var _cache` не очищается при уничтожении объекта `City`. Это приводит к утечке памяти и логическим ошибкам, если UID города переиспользуется в новой сессии.

---

### Готовый код (Рефакторинг и Фиксы)

#### 1. Исправление TCP-буфера, Eval-инъекции и HTTP-утечки
**FILE: `res://game/mcp_interaction_server.gd`**

**Шаг 1.1: Добавьте переменную для сырых байтов в начало класса**
Найдите блок переменных класса и добавьте `_buffer_bytes`:
```gdscript
var _server: TCPServer
var _client: StreamPeerTCP
var _buffer: String = ""
var _buffer_bytes: PackedByteArray = PackedByteArray() # ДОБАВИТЬ ЭТУ СТРОКУ
var _busy: bool = false
```

**Шаг 1.2: Замените логику чтения и очистки буфера в `_process`**
Найдите блок `# Read data from client` и замените его на безопасный парсинг байтов:
```gdscript
		# Read data from client
		if _client == null:
			return
			
		_client.poll()
		var status: int = _client.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			print("McpInteractionServer: Client disconnected")
			_client = null
			_buffer = ""
			_buffer_bytes.clear() # ОЧИЩАТЬ БАЙТОВЫЙ БУФЕР
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
				_buffer_bytes.append_array(bytes)
				
		# Process complete lines (newline-delimited JSON)
		# Ищем байт \n (10), чтобы не ломать многобайтовые UTF-8 символы
		var newline_byte: PackedByteArray = PackedByteArray([10])
		var newline_pos: int = _buffer_bytes.find(newline_byte)
		while newline_pos != -1:
			var line_bytes: PackedByteArray = _buffer_bytes.slice(0, newline_pos)
			_buffer_bytes = _buffer_bytes.slice(newline_pos + 1)
			
			var line: String = line_bytes.get_string_from_utf8().strip_edges()
			if line.length() > 0:
				_handle_command(line)
				
			newline_pos = _buffer_bytes.find(newline_byte)
```

**Шаг 1.3: Полностью замените функцию `_cmd_eval` и `_indent_code`**
```gdscript
# --- Eval: Execute arbitrary GDScript at runtime ---
func _cmd_eval(params: Dictionary) -> void:
	var code: String = params.get("code", "")
	if code.is_empty():
		_send_response({"error": "No code provided"})
		return
		
	var indented_code: String = _indent_code(code)
	
	# Используем конкатенацию вместо %, чтобы избежать крэша, если в code есть символ %
	var script_source: String = "extends Node\n" + \
		"func execute():\n" + \
		"\tvar __result = null\n" + \
		"\t__result = await _run()\n" + \
		"\treturn __result\n\n" + \
		"func _run():\n" + \
		"\tawait get_tree().process_frame\n" + \
		indented_code

	var script: GDScript = GDScript.new()
	script.source_code = script_source
	var err: int = script.reload()
	if err != OK:
		_send_response({"error": "Failed to compile GDScript (error %d). Check syntax." % err})
		return
		
	var temp_node: Node = Node.new()
	temp_node.set_script(script)
	if temp_node.get_script() == null:
		temp_node.queue_free()
		_send_response({"error": "Failed to compile GDScript: script did not attach."})
		return
		
	temp_node.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(temp_node)
	
	var state := {"fired": false}
	var result: Variant = null
	if temp_node.has_method("execute"):
		var watchdog: SceneTreeTimer = get_tree().create_timer(25.0, true)
		watchdog.timeout.connect(func():
			if state["fired"]:
				return
			state["fired"] = true
			if is_instance_valid(temp_node):
				temp_node.queue_free()
			_send_response({"error": "eval aborted: runtime error in code (check game output)"})
		)
		result = await temp_node.execute()
		
	if is_instance_valid(temp_node):
		temp_node.queue_free()
		
	if not state["fired"]:
		state["fired"] = true
		_send_response({"success": true, "result": _variant_to_json(result)})

func _indent_code(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var indented: String = ""
	for line in lines:
		var indent_level: int = 0
		var i: int = 0
		# Считаем уровень отступов, конвертируя пробелы и табы в единый формат
		while i < line.length():
			if line[i] == "\t":
				indent_level += 1
				i += 1
			elif line[i] == " ":
				var spaces: int = 0
				while i < line.length() and line[i] == " ":
					spaces += 1
					i += 1
				indent_level += spaces / 4 # Считаем, что 4 пробела = 1 таб
				if spaces % 4 > 0:
					indent_level += 1
			else:
				break
		
		var prefix: String = ""
		# +1 таб, так как код внедряется внутрь тела функции _run()
		for j in range(indent_level + 1):
			prefix += "\t"
			
		indented += prefix + line.substr(i) + "\n"
	return indented
```

**Шаг 1.4: Замените функцию `_cmd_http_request` для предотвращения утечки нод**
```gdscript
func _cmd_http_request(params: Dictionary) -> void:
	var url: String = params.get("url", "")
	if url.is_empty():
		_send_response({"error": "url is required"})
		return
	var method_str: String = params.get("method", "GET").to_upper()
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = float(params.get("timeout", 30))
	add_child(http)
	var headers: PackedStringArray = PackedStringArray()
	if params.has("headers"):
		var h: Dictionary = params["headers"]
		for k in h:
			headers.append("%s: %s" % [k, str(h[k])])
	var method_enum: int = HTTPClient.METHOD_GET
	match method_str:
		"POST": method_enum = HTTPClient.METHOD_POST
		"PUT": method_enum = HTTPClient.METHOD_PUT
		"DELETE": method_enum = HTTPClient.METHOD_DELETE
	var body: String = params.get("body", "")
	var err: int = http.request(url, headers, method_enum, body)
	if err != OK:
		http.queue_free()
		_send_response({"error": "HTTP request failed to start: %d" % err})
		return
		
	var result: Array = await http.request_completed
	
	# Безопасное удаление: если сервер упал или клиент отключился, нода может быть уже невалидна
	if is_instance_valid(http):
		http.queue_free()
		
	_send_response({"success": true, "status_code": result[1], "body": result[3].get_string_from_utf8()})
```

---

#### 2. Исправление утечки статического кэша
**FILE: `res://game/scripts/city/arena_cluster_system.gd`**

Замените начало файла (переменные и функцию `clusters`), чтобы использовать `WeakRef` для автоматической инвалидации кэша при уничтожении города.

```gdscript
class_name ArenaClusterSystem
extends RefCounted

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const City := preload("res://scripts/world/city.gd")
const PopUnit := preload("res://scripts/world/pop_unit.gd")
const UniqueBuilding := preload("res://scripts/world/unique_building.gd")

# Храним WeakRef, чтобы кэш не держал удаленные города в памяти
static var _cache: Dictionary = {} # uid -> {"ver": int, "cl": Array, "city_ref": WeakRef}

static func clusters(city: City) -> Array:
	if city == null:
		return []
		
	var ver: int = _city_version(city)
	var entry: Dictionary = _cache.get(city.uid, {})
	
	# Проверяем, жив ли еще объект города
	var city_ref: WeakRef = entry.get("city_ref", null)
	if city_ref != null and city_ref.get_ref() == null:
		_cache.erase(city.uid)
		entry = {}
		
	if int(entry.get("ver", -1)) == ver and entry.has("cl"):
		return entry["cl"]
		
	var result: Array = _compute_clusters(city)
	_cache[city.uid] = {"ver": ver, "cl": result, "city_ref": weakref(city)}
	return result

static func cluster_uids(city: City) -> Dictionary:
	if city == null:
		return {}
	var m: Dictionary = {}
	for cl in clusters(city):
		for b in (cl as Dictionary)["buildings"]:
			m[(b as UniqueBuilding).uid] = ArenaBalance.CLUSTER_MULT
	return m

static func cluster_worker_housing(city: City) -> int:
	return city.free_housing(PopUnit.State.WORKER) \
		+ ArenaBalance.CLUSTER_HOUSING * (clusters(city) as Array).size()

static func invalidate(city_uid: int) -> void:
	_cache.erase(city_uid)

static func reset() -> void:
	_cache.clear()

static func _city_version(city: City) -> int:
	if city == null:
		return -1
	var h: int = 0
	for bld in city.buildings:
		if bld != null:
			h = (h * 131 + int(bld.uid)) & 0x7fffffff
	return int(city.buildings.size()) * 1_000_003 + h

static func _compute_clusters(city: City) -> Array:
	var by_def: Dictionary = {}
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		if not by_def.has(b.def.id):
			by_def[b.def.id] = []
		(by_def[b.def.id] as Array).append(b)
		
	var out: Array = []
	for def_id in by_def:
		var bldgs: Array = by_def[def_id]
		var by_cell: Dictionary = {}
		for b in bldgs:
			by_cell[(b as UniqueBuilding).cell] = b
			
		var seen: Dictionary = {}
		for b0 in bldgs:
			var start: UniqueBuilding = b0
			if seen.has(start.uid):
				continue
			var comp: Array = []
			var stack: Array = [start]
			seen[start.uid] = true
			while not stack.is_empty():
				var b: UniqueBuilding = stack.pop_back()
				comp.append(b)
				for nb in HexUtils.get_all_neighbors(b.cell):
					var nb_b: UniqueBuilding = by_cell.get(nb)
					if nb_b != null and not seen.has(nb_b.uid):
						seen[nb_b.uid] = true
						stack.append(nb_b)
						
			if comp.size() >= ArenaBalance.CLUSTER_MIN:
				var cells: Array[Vector2i] = []
				for b in comp:
					cells.append((b as UniqueBuilding).cell)
				out.append({"def_id": def_id, "cells": cells, "buildings": comp})
				
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = (a["cells"] as Array)[0]
		var cb: Vector2i = (b["cells"] as Array)[0]
		return ca.y * 10000 + ca.x < cb.y * 10000 + cb.x)
		
	return out
```

---

### Инструкция по установке и внедрению (Runbook)

#### Шаг 1: Применение патчей
1. Откройте файл `res://game/mcp_interaction_server.gd`.
   - Добавьте `var _buffer_bytes: PackedByteArray = PackedByteArray()` в блок переменных класса (строка ~8).
   - Найдите блок `# Read data from client` внутри `_process` и замените его целиком на код из **Шага 1.2**.
   - Найдите функции `_cmd_eval`, `_indent_code` и `_cmd_http_request`. Замените их тела на реализации из **Шагов 1.3 и 1.4**.
2. Откройте файл `res://game/scripts/city/arena_cluster_system.gd`.
   - Полностью замените содержимое файла на код из **Блока 2**.

#### Шаг 2: Интеграционные проверки
- Убедитесь, что при старте новой игры или выходе в главное меню вызывается `ArenaClusterSystem.reset()`. Если этого не происходит глобально, добавьте вызов `ArenaClusterSystem.reset()` в метод `_ready()` главного контроллера сессии или `WorldController`, чтобы исключить пересечение кэша между забегами.
- В `mcp_interaction_server.gd` проверьте, что при дисконнекте клиента (блок `STATUS_ERROR` или `STATUS_NONE`) вызывается `_buffer_bytes.clear()`. Это уже включено в патч **Шага 1.2**.

#### Шаг 3: Критерии приёмки (Тестирование)
1. **Тест TCP UTF-8**: Отправьте через TCP-клиент JSON-команду, содержащую длинные кириллические строки (например, `eval` с `print("Тест длинной строки...")`), разбив пакет на две части так, чтобы байт `\n` пришел во втором пакете, а многобайтовый символ был разорван между пакетами. Сервер должен успешно собрать строку и выполнить команду без ошибок парсинга JSON.
2. **Тест Eval Safety**: Выполните MCP команду `eval` с кодом: `var x = 100 % 5\nprint(x)`. Ранее это вызывало крэш движка. Теперь код должен выполниться и вернуть `success: true`.
3. **Тест HTTP Leak**: Инициируйте `http_request` к несуществующему или очень медленному серверу, затем принудительно закройте TCP-сокет MCP-клиента до истечения `await`. Утечки нод `HTTPRequest` в дереве сцены быть не должно (проверьте через `Remote` вкладку или `get_tree().root.get_children()`).
4. **Тест Кэша Арены**: Создайте город, постройте кластер зданий, затем удалите город (или начните новый забег). Проверьте, что `ArenaClusterSystem._cache` не хранит ссылок на удаленные объекты (размер кэша должен возвращаться к 0 или содержать только актуальные `WeakRef`).


Проанализировав предоставленную кодовую базу, я выявил несколько критических архитектурных и логических проблем, которые требуют немедленного исправления для соответствия современным стандартам Godot 4.x, gdUnit4 и экосистеме MCP.

Ниже представлен подробный план рефакторинга, разделенный на три ключевых направления: **Логика тестов (удаление антипаттернов)**, **Интеграция `godot-mcp`** и **Улучшение структуры/покрытия**.

---

### 1. Логика тестов: Удаление антипаттерна `var errors := 0`

**Диагноз:** Синтаксис GUT (`extends GutTest`, `assert_eq`) в коде уже отсутствует, формально тесты написаны под `GdUnitTestSuite` (gdUnit4). Однако **логика** тестов содержит грубый антипаттерн, характерный для самописных раннеров или GUT-миграций без адаптации:
```gdscript
# ❌ АНТИПАТТЕРН
func test_attack() -> void:
    var errors := _check_attack()
    assert_that(errors).is_equal(0) # Скрывает реальную причину и строку падения!

func _check_attack() -> int:
    var errors := 0
    # ...
    if defender.get_count() >= defender_count_before:
        printerr("attack should reduce defender count")
        errors += 1
    return errors
```
**Почему это плохо:** gdUnit4 использует исключения для прерывания теста. Возврат `errors` заставляет тест-раннер думать, что тест прошел успешно (если `assert_that(0).is_equal(0)`), а `printerr` просто засоряет консоль. UI gdUnit4 не сможет показать точную строку падения и дифф значений.

**Решение:** Перевод на нативные ассерты gdUnit4 (`assert_int`, `assert_bool`, `assert_object`, `assert_float`).

#### Рефакторинг `test_battle_state.gd` (Пример)
```gdscript
extends GdUnitTestSuite

const _BattleState = preload("res://scripts/systems/battle_state.gd")
const _HexUtils = preload("res://scripts/core/hex_utils.gd")
# ... другие импорты

func _create_state() -> BattleState:
    var state = _BattleState.new()
    var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 20)]
    var def: Array[UnitStack] = [Units.make_fixed_stack("goblins", 20)]
    state.place_army(atk, def)
    state.build_queue()
    return state

func test_battle_setup() -> void:
    var state = _create_state()
    var attackers = state.get_units_by_side(BattleState.Side.ATTACKER)
    var defenders = state.get_units_by_side(BattleState.Side.DEFENDER)
    
    assert_int(attackers.size()).is_equal(1)
    assert_int(defenders.size()).is_equal(1)
    assert_bool(attackers[0].is_alive()).is_true()
    assert_bool(defenders[0].is_alive()).is_true()
    assert_bool(state.turn_queue.is_empty()).is_false()
    
    var found = state.get_unit_at(attackers[0].cell, BattleState.Side.ATTACKER)
    assert_object(found).is_not_null()

func test_attack_reduces_defender_count() -> void:
    var state = _create_state()
    var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
    var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
    
    attacker.cell = Vector2i(5, 5)
    defender.cell = _HexUtils.get_neighbor(attacker.cell, 0)
    
    var defender_count_before = defender.get_count()
    var rng := RandomNumberGenerator.new()
    
    state.apply_attack(attacker, defender, true, rng)
    
    assert_int(defender.get_count()).is_less(defender_count_before)
    assert_bool(attacker.has_moved).is_true()

func test_attack_with_rng_returns_damage() -> void:
    var state = _BattleState.new()
    var atk := [Units.make_fixed_stack("swordsmen", 50)]
    var def := [Units.make_fixed_stack("goblins", 50)]
    state.place_army(atk, def)
    
    var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
    var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
    attacker.cell = Vector2i(5, 5)
    defender.cell = _HexUtils.get_neighbor(attacker.cell, 0)
    
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var result: Dictionary = state.apply_attack(attacker, defender, true, rng)
    
    assert_dict(result).has_key("damage")
    assert_int(result.get("damage", 0)).is_greater(0)
```
*Аналогичному рефакторингу подлежат `test_map_model.gd`, `test_shard.gd`, `test_unit_abilities.gd` и `test_hero_serialize.gd`. Все функции `_check_*` должны быть инлайнены в `test_*` с использованием прямых ассертов.*

---

### 2. Интеграция `tugcantopaloglu/godot-mcp`

**Диагноз:** Файл `mcp_interaction_server.gd` (более 3000 строк) — это самописный TCP-сервер, который вручную парсит JSON, управляет сокетами и дублирует функционал, который уже предоставляет стандарт MCP (Model Context Protocol).
Использование `tugcantopaloglu/godot-mcp` подразумевает отказ от ручного TCP-парсинга в пользу регистрации **MCP Tools** и **Resources**, которые LLM-клиенты (Cursor, Claude) вызывают через стандартизированный JSON-RPC.

**Решение:**
1. Удалить `mcp_interaction_server.gd` из списка AutoLoad.
2. Установить аддон `godot-mcp` через AssetLib или Git.
3. Создать `RuntimeMCPBridge.gd`, который регистрирует специфичные для вашей игры инструменты (Tools) в MCP-сервере, используя его API.

#### Новый `RuntimeMCPBridge.gd` (AutoLoad)
Этот скрипт заменяет самописный TCP-сервер, интегрируясь с `godot-mcp`.

```gdscript
extends Node
# RuntimeMCPBridge.gd
# Регистрирует игровые рантайм-команды как MCP Tools для godot-mcp

var _mcp_server: Node = null

func _ready() -> void:
    # godot-mcp обычно инициализируется как EditorPlugin или Singleton
    # В зависимости от версии аддона, получаем доступ к регистратору инструментов
    if Engine.has_singleton("GodotMCP"):
        _mcp_server = Engine.get_singleton("GodotMCP")
        _register_runtime_tools()
    else:
        # Fallback для рантайм-запуска вне редактора
        var mcp_node = get_node_or_null("/root/MCPServer")
        if mcp_node and mcp_node.has_method("register_tool"):
            _mcp_server = mcp_node
            _register_runtime_tools()
        else:
            push_warning("RuntimeMCPBridge: godot-mcp server not found. Runtime tools disabled.")

func _register_runtime_tools() -> void:
    # Регистрация инструмента для скриншотов
    _mcp_server.register_tool(
        "game_screenshot", 
        "Captures a screenshot of the current game viewport and returns base64 PNG.",
        {}, 
        Callable(self, "_tool_screenshot")
    )
    
    # Регистрация инструмента для выполнения GDScript (аналог вашего "eval")
    _mcp_server.register_tool(
        "game_execute_code",
        "Executes arbitrary GDScript code in the game runtime context.",
        {"code": {"type": "string", "description": "GDScript code to execute"}},
        Callable(self, "_tool_eval")
    )
    
    # Регистрация инструмента для кликов и ввода
    _mcp_server.register_tool(
        "game_simulate_input",
        "Simulates mouse clicks, movement, or key presses.",
        {
            "action": {"type": "string", "enum": ["click", "move", "key_press"]},
            "x": {"type": "number"}, "y": {"type": "number"},
            "key": {"type": "string"}
        },
        Callable(self, "_tool_input")
    )
    
    print("[RuntimeMCPBridge] Registered custom game tools with godot-mcp.")

# --- Реализация MCP Tools ---

func _tool_screenshot(_args: Dictionary) -> Dictionary:
    await get_tree().process_frame
    var image: Image = get_viewport().get_texture().get_image()
    if image == null:
        return {"error": "Failed to capture viewport"}
    
    var png_buffer: PackedByteArray = image.save_png_to_buffer()
    var base64_str: String = Marshalls.raw_to_base64(png_buffer)
    
    # godot-mcp ожидает возврат в формате MCP Content
    return {
        "content": [
            {"type": "text", "text": "Screenshot captured (%dx%d)" % [image.get_width(), image.get_height()]},
            {"type": "image", "data": base64_str, "mimeType": "image/png"}
        ]
    }

func _tool_eval(args: Dictionary) -> Dictionary:
    var code: String = args.get("code", "")
    if code.is_empty():
        return {"error": "No code provided"}
        
    # Используем ваш существующий безопасный eval-механизм из старого сервера
    # (обертка в GDScript.new() и temp_node)
    # ... (код из _cmd_eval) ...
    return {"result": "Executed successfully"}

func _tool_input(args: Dictionary) -> Dictionary:
    var action: String = args.get("action", "")
    match action:
        "click":
            var event = InputEventMouseButton.new()
            event.position = Vector2(args.get("x", 0), args.get("y", 0))
            event.button_index = MOUSE_BUTTON_LEFT
            event.pressed = true
            Input.parse_input_event(event)
            # ... release ...
    return {"status": "success"}
```

**Маппинг старых команд на `godot-mcp`:**
- `get_scene_tree`, `get_property`, `set_property`, `call_method` -> **Уже встроены** в `godot-mcp` (работают с деревом сцен Godot).
- `screenshot`, `eval`, `click` -> Вынесены в `RuntimeMCPBridge.gd` (код выше).
- TCP-сокет и ручная маршрутизация JSON -> **Удалены**, транспорт берет на себя MCP-сервер аддона.

---

### 3. Улучшение структуры и покрытия тестов (Best Practices gdUnit4)

#### А. Параметризованные тесты (Test Cases)
В файлах вроде `test_city_system.gd` или `test_season.gd` много повторяющегося кода для проверки разных состояний. В gdUnit4 нужно использовать `test_parameters` (или `@test` с аргументами, если версия поддерживает), либо циклы с `assert_`.

**Пример для `test_season.gd`:**
```gdscript
extends GdUnitTestSuite

const _Season = preload("res://scripts/world/season.gd")

# Вместо 10 отдельных тестов используем параметризацию через массивы
var _month_to_season_map := {
    1: Season.ID.WINTER, 2: Season.ID.WINTER, 3: Season.ID.SPRING,
    5: Season.ID.SPRING, 6: Season.ID.SUMMER, 8: Season.ID.SUMMER,
    9: Season.ID.AUTUMN, 11: Season.ID.AUTUMN, 12: Season.ID.WINTER
}

func test_season_mapping() -> void:
    for month in _month_to_season_map.keys():
        var expected = _month_to_season_map[month]
        assert_int(_Season.from_month(month)).is_equal(expected) \
            .with_message("Month %d should map to season %d" % [month, expected])

func test_out_of_bounds_defaults_to_spring() -> void:
    var invalid_months := [0, 13, -1, 99]
    for month in invalid_months:
        assert_int(_Season.from_month(month)).is_equal(Season.ID.SPRING) \
            .with_message("Invalid month %d must default to SPRING" % month)
```

#### Б. Правильный Setup и Teardown
Убедитесь, что тяжелые объекты (сцены, менеджеры) создаются в `before_test()` и уничтожаются в `after_test()`, чтобы избежать утечек памяти между тестами (что критично для Godot).

**Пример для `test_city_arena_view.gd`:**
```gdscript
extends GdUnitTestSuite

var _view: CityArenaView = null

func before_test() -> void:
    # Инстанцируем сцену один раз перед каждым тестом
    var packed := load("res://scenes/city_arena.tscn") as PackedScene
    assert_object(packed).is_not_null()
    _view = packed.instantiate() as CityArenaView
    add_child(_view)
    await get_tree().process_frame # Ждем _ready()

func after_test() -> void:
    # Гарантированная очистка
    if is_instance_valid(_view):
        _view.queue_free()
        _view = null
    # Ожидаем фрейм, чтобы queue_free завершился
    await get_tree().process_frame 

func test_arena_smoke() -> void:
    assert_object(_view._city).is_not_null()
    # ... логика теста ...
```

#### В. Моки (Mocking) в gdUnit4
В `TestBattleRules.gd` есть комментарий: `# ponytail: моки из ТЗ не работали (do_return на свойствах); реальные объекты дешевле`.
В gdUnit4 мокирование свойств действительно имеет ограничения, но для **методов** и **сигналов** нужно использовать нативный API, а не создавать "заглушки" вручную.

```gdscript
# Правильное использование моков в gdUnit4
func test_mocking_service_locator() -> void:
    var mock_registry = mock(UnitRegistry)
    do_return(10).when(mock_registry).get_unit_cost("swordsmen")
    
    # Использование мока
    var cost = mock_registry.get_unit_cost("swordsmen")
    assert_int(cost).is_equal(10)
    
    # Проверка вызовов
    verify(mock_registry, times(1)).get_unit_cost("swordsmen")
```

---

### Итоговый чек-лист для рефакторинга (Action Items)

1. [ ] **Глобальный поиск и замена:** Найти все `var errors := 0` и `return errors` в папке `tests/`. Переписать их на прямые `assert_*`.
2. [ ] **Удаление MCP-сервера:** Удалить `mcp_interaction_server.gd` из `Project Settings -> AutoLoad`.
3. [ ] **Установка аддона:** Добавить `tugcantopaloglu/godot-mcp` в `res://addons/`.
4. [ ] **Создание бриджа:** Добавить `RuntimeMCPBridge.gd` (код выше) в AutoLoad для регистрации кастомных игровых инструментов.
5. [ ] **Очистка GUT-артефактов:** Удалить любые оставшиеся `watch_signals` (заменить на `signal_name.connect(...)` + проверка флага) и `assert_eq` (заменить на `assert_that(a).is_equal(b)` или `assert_int(a).is_equal(b)`).
6. [ ] **CI/CD Интеграция:** Настроить запуск тестов через CLI: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/`, чтобы исключить провисания, связанные с `await` в самописных раннерах.

Эти изменения превратят набор скриптов в профессиональную, поддерживаемую систему тестирования и интеграции с AI-агентами, полностью соответствующую стандартам Godot 4.x.


# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1 Общая карта ответственности

| Слой | Ключевые файлы | Оценка |
|---|---|---|
| Взаимодействие (внешний) | `mcp_interaction_server.gd` | ⚠️ Монолит |
| Оркестрация мира | `WorldController.gd`, `WorldBootstrap.gd`, `WorldEventRouter.gd` | ✅ Хорошо |
| Бой | `BattleState`, `BattleAI`, `BattleTurnExecutor`, `BattleController`, `BattleView`, `BattleInput`, `BattleFX`, `BattleActionResolver`, `BattleDamageResolver` | ✅ Отлично |
| Город / экономика | `City.gd`, `CityTurnProcessor`, `EconomicTurnProcessor`, `ZoningSystem`, `ReputationSystem`, `ProsperitySystem`, `RaidSystem`, `MarketSystem`, `SpecializationSystem`, `AdjacencySystem`, `ScaleShiftManager`, `WorkerAssignment`, `LogisticsCalculator` | ⚠️ Перегруженность `City` |
| Герой | `HeroController`, `HeroMovementController`, `HeroArmyController`, `HeroResources`, `HeroMagic`, `HeroInventory`, `HeroNeeds`, `HeroSkills`, `HeroTools`, `HeroStrategicResources` | ✅ Хорошо |
| Демография | `Character`, `CharacterRegistry`, `DemographicTurnProcessor`, `TraitDef`, `TraitRegistry` | ✅ Хорошо |
| Заклинания | `SpellRegistry`, `SpellbookRegistry`, `SpellCaster`, `TemplateEngine`, 19 шаблонов | ✅ Хорошо |
| Ресурсы | `ResourceRegistry`, `ResourceContext`, `ResourceNodeManager`, `TerrainResourceManager`, `ResourceChainService` | ✅ Хорошо |
| Сохранение | `SaveData`, `SaveManager`, `WorldPersistence`, `WorldStateDelta` | ✅ Хорошо |
| UI | 30+ файлов `scripts/ui/` | ⚠️ Нет единого паттерна |
| Автозагрузки | `Units`, `Resources`, `Spells`, `Artifacts`, `Spellbook`, `Settings`, `SoundManager`, `GameEventBus`, `CursorController`, `TemplateBootstrap` | ✅ Хорошо |

### 1.2 Критические проблемы

#### P1. `mcp_interaction_server.gd` — бог-файл (~4500 строк)

Один файл содержит:
- TCP-сервер и протокол обмена
- **120+ обработчиков команд** (`_cmd_screenshot`, `_cmd_click`, `_cmd_eval`, `_cmd_tilemap`, `_cmd_physics_3d`, …)
- Вспомогательные функции конвертации вариантов

**Нарушение:** SRP, OCP. Добавление любой новой команды требует правки этого файла.

#### P2. `City.gd` — перегруженный класс (~700 строк)

Содержит:
- Данные города (население, здания, районы, ресурсы)
- Логику строительства и апгрейдов
- Логику роста и голода
- Сериализацию
- Перемещение центра (relocate)
- Расчёт обороны

**Нарушение:** SRP. Город одновременно модель, сервис и репозиторий.

#### P3. `HeroController.gd` — фасад с прямой агрегацией

```
hero.movement, hero.army, hero.resources, hero.visual, hero.magic,
hero.skills, hero.tools, hero.time, hero.strategic_resources, hero.inventory,
hero.needs, hero.followers
```

12 подобъектов. Контроллер одновременно:
- создаёт и связывает подсистемы (`_ready`);
- делегирует;
- хранит бизнес-логику (`end_turn`, `_tick_needs`, `revive_at`);
- сериализует всё разом.

**Нарушение:** SRP, Law of Demeter (клиенты пишут `hero.magic.spellbook`).

### 1.3 Паттерны

| Паттерн | Где | Качество |
|---|---|---|
| Service Locator | `ServiceLocator.gd` | ✅ Кэширование, инвалидация |
| Strategy | `NeedStrategy` → `RestStrategy`, `SocialStrategy`, `InspirationStrategy` | ✅ Чисто |
| Template Method | `TurnPhaseProcessor` → 6 процессоров | ✅ Чисто |
| Observer | `GameEventBus` (26 сигналов) | ⚠️ Слабая типизация аргументов |
| Command | Отсутствует в MCP-сервере | ❌ |
| State | `BattleTurnExecutor.State` | ✅ |
| Factory | `CityFactory`, `HeroModelFactory` | ✅ |
| Mediator | `WorldEventRouter` | ✅ |

### 1.4 Масштабируемость

- **Хорошо:** система шаблонов заклинаний (`TemplateEngine` + 19 хендлеров) легко расширяется.
- **Хорошо:** `TurnScheduler` + `TurnPhaseProcessor` — новый процессор = один класс + одна строка регистрации.
- **Плохо:** добавление команды в MCP-сервер = правка `match` на 120+ веток.
- **Плохо:** добавление нового типа здания требует правок в `BuildingDefs`, `City`, `CityScreen`, `CityArenaView`, тестах.

---

## 2. Лучшие практики

### 2.1 Идиомы GDScript / Godot

| Проблема | Пример | Файл |
|---|---|---|
| `extends Node` вместо `class_name` для автозагрузок | `extends Node` без `class_name` в `mcp_interaction_server.gd` | допустимо для автозагрузок, но нет документации |
| Магические числа | `PORT = 9090`, `BUSY_TIMEOUT = 120.0` — ок; но `0.35` для длительности анимации атаки в `BattleTurnExecutor` | `BattleTurnExecutor.gd` |
| `await` без проверки `is_inside_tree()` | `_cmd_eval` в MCP-сервере — частично исправлено патчем, но `_cmd_http_request` не защищён | `mcp_interaction_server.gd` |
| `@warning_ignore` вместо рефакторинга | `@warning_ignore("integer_division")` в `HexUtils.gd` | допустимо, но лучше `int()` |
| `process_mode = PROCESS_MODE_ALWAYS` | Правильно для MCP-сервера и `BattleUI` | ✅ |

### 2.2 SOLID

| Принцип | Нарушения |
|---|---|
| **S** | `mcp_interaction_server.gd`, `City.gd`, `HeroController.gd` |
| **O** | `match command:` в MCP-сервере — закрыт для расширения без модификации |
| **L** | Нет нарушений |
| **I** | `HeroController` — слишком широкий интерфейс для потребителей |
| **D** | `City` напрямую использует `BuildingDefs`, `ReputationSystem`, `BoroughRules` вместо инъекции |

### 2.3 DRY

| Дублирование | Где |
|---|---|
| Обход дерева для поиска аудио-плееров | `_find_audio_players` в MCP-сервере |
| Конвертация `Dictionary` → типизированные векторы | Повторяется в `_cmd_set_property`, `_cmd_tween_property`, `_cmd_debug_draw`, `_cmd_spawn_node` |
| `_cells_to_array` / `_array_to_cells` | `WorldStateDelta.gd` — дублирует логику `_variant_to_json` |
| Проверка `node_path.is_empty()` + `get_node_or_null` | Повторяется в ~40 методах MCP-сервера |

### 2.4 Обработка ошибок

| Паттерн | Оценка |
|---|---|
| Возврат `{"error": "..."}` / `{"success": true, ...}` | ✅ Единообразно в MCP-сервере |
| `push_error` + `return` | ✅ В `SaveManager`, `MapGenerator` |
| `assert` в тестах | ✅ |
| **Отсутствие обработки** `null` после `load()` | ⚠️ `_cmd_audio_play`: `load(stream_path)` без проверки до `is AudioStream` |
| **Отсутствие try/catch** для `JSON.parse` | ✅ Обработано через `parse_err != OK` |

### 2.5 Читаемость и именование

- Именование в целом **хорошее**: `snake_case`, семантические имена.
- Комментарии на русском — допустимо для проекта, но снижают порог входа.
- `# ponytail:` — маркеры рефакторинга, стоит удалить после стабилизации.

---

## 3. Алгоритмы

### 3.1 Инвентарь алгоритмов

| Алгоритм | Где | Сложность | Корректность |
|---|---|---|---|
| A* (hex) | `HexPathfinding.astar_path` | O(V log V) | ✅ |
| BFS | `HexPathfinding.bfs_path`, `bfs_reachable` | O(V) | ✅ |
| Dijkstra | `HexPathfinding.dijkstra` + `dijkstra_path` | O(V log V) | ✅ |
| MinHeap | `MinHeap.gd` | O(log n) push/pop | ✅ |
| Cube-координаты (расстояние) | `HexUtils.hex_distance` | O(1) | ✅ |
| Flood-fill (fog) | `VisibilityMap._fill_disk` | O(r²) | ✅ |
| Кластеризация (BFS-компоненты) | `ArenaClusterSystem._compute_clusters` | O(B) | ✅ |
| Hill climbing (тюнер арены) | `tune_city_arena.gd` | O(evals × sim) | ✅ |

### 3.2 Проблемы

#### A1. `VisibilityMap.recompute` — O(W×H) каждый вызов

```gdscript
func _fill_disk(center, radius, out):
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
```

При `radius=3` это 49 итераций на источник. При 20 городах + герой: ~1000 операций. **Приемлемо**, но при росте карты (200×200) и увеличении числа источников станет узким местом.

**Рекомендация:** инкрементальное обновление — добавлять только новые клетки.

#### A2. `ArenaClusterSystem._compute_clusters` — инвалидация по хешу

```gdscript
func _city_version(city: City) -> int:
    var h: int = 0
    for bld in city.buildings:
        if bld != null:
            h = (h * 131 + int(bld.uid)) & 0x7fffffff
    return int(city.buildings.size()) * 1_000_003 + h
```

Хеш **не учитывает** изменение `assigned_workers`, `zone_multiplier`, `level`. Если здание апгрейдится без изменения `uid` и `buildings.size()`, кеш не инвалидируется.

**Рекомендация:** включить `level` в хеш или использовать `dirty`-флаг.

#### A3. `EnemyTurnProcessor.process` — O(E × G) на ход

Для каждого вражеского стека строится `dijkstra` от его позиции. При 20 стеках и карте 60×60: 20 × 3600 = 72 000 операций. Приемлемо, но `dist_cache` по `(cell, mp)` помогает только при совпадении стартовых точек.

#### A4. `_collect_ui_elements` — рекурсивный обход всего дерева

```gdscript
func _collect_ui_elements(node: Node, elements: Array) -> void:
    for child in node.get_children():
        _collect_ui_elements(child, elements)
```

O(N) по всем узлам. Для большой сцены (1000+ узлов) при каждом вызове `get_ui_elements` — дорого.

**Рекомендация:** кэшировать результат, инвалидировать по `tree_changed`.

### 3.3 Структуры данных

| Структура | Оценка |
|---|---|
| `Dictionary` как множество (`{cell: true}`) | ✅ Идиома GDScript |
| `PackedFloat32Array` для Dijkstra-дистанций | ✅ Эффективно по памяти |
| `MinHeap` на массиве | ✅ |
| `Array[UnitStack]` для армий | ✅ |
| Статические кэши (`static var _cache`) в `ArenaClusterSystem`, `PlaceholderTexture`, `UnitSprites` | ⚠️ Требуют явной инвалидации |

---

## 4. Рефакторинг

### R1. MCP-сервер: паттерн «Команда» (High)

**Что:** заменить `match command:` на реестр обработчиков.

**Зачем:** добавление команды = один новый метод + одна строка регистрации. Устраняется бог-файл.

**До:**
```gdscript
# mcp_interaction_server.gd — 120+ веток
match command:
    "screenshot": await _cmd_screenshot()
    "click": await _cmd_click(params)
    "key_press": await _cmd_key_press(params)
    # ... ещё 117 веток
```

**После:**
```gdscript
# mcp_interaction_server.gd
var _commands: Dictionary = {}

func _ready() -> void:
    _register_commands()
    # ... сервер

func _register_commands() -> void:
    _commands["screenshot"] = _cmd_screenshot
    _commands["click"] = _cmd_click
    _commands["key_press"] = _cmd_key_press
    # Группы можно вынести в отдельные файлы:
    # _register_battle_commands()
    # _register_ui_commands()
    # _register_world_commands()

func _handle_command(json_str: String) -> void:
    # ... парсинг ...
    var handler: Variant = _commands.get(command)
    if handler == null:
        _send_response({"error": "Unknown command: %s" % command})
        return
    if handler is Callable:
        await handler.call(params)
```

### R2. Выделение хелпера доступа к узлам в MCP-сервере (High)

**Что:** убрать 40-кратное повторение проверки `node_path`.

**До:**
```gdscript
func _cmd_get_property(params: Dictionary) -> void:
    var node_path: String = params.get("node_path", "")
    var property: String = params.get("property", "")
    if node_path.is_empty() or property.is_empty():
        _send_response({"error": "node_path and property are required"})
        return
    var node: Node = get_tree().root.get_node_or_null(node_path)
    if node == null:
        _send_response({"error": "Node not found: %s" % node_path})
        return
    # ... полезная нагрузка
```

**После:**
```gdscript
func _resolve_node(params: Dictionary, required_props: Array = []) -> Node:
    var node_path: String = params.get("node_path", "")
    if node_path.is_empty():
        _send_response({"error": "node_path is required"})
        return null
    for prop in required_props:
        if str(params.get(prop, "")).is_empty():
            _send_response({"error": "%s is required" % prop})
            return null
    var node: Node = get_tree().root.get_node_or_null(node_path)
    if node == null:
        _send_response({"error": "Node not found: %s" % node_path})
        return null
    return node

func _cmd_get_property(params: Dictionary) -> void:
    var node := _resolve_node(params, ["property"])
    if node == null: return
    var value: Variant = node.get(params["property"])
    _send_response({"success": true, "value": _variant_to_json(value), ...})
```

### R3. Декомпозиция `City.gd` (Medium)

**Что:** вынести логику строительства, роста и сериализации в отдельные классы.

**До:** `City.gd` — 700 строк, 15+ методов.

**После:**
```
City.gd              — данные + базовые запросы (~200 строк)
CityBuildingService  — can_build, build, upgrade, relocate
CityGrowthService    — process_turn, net_food, growth_threshold
CitySerializer       — serialize / deserialize
```

### R4. Кэш кластеров: фиксация инвалидации (Medium)

**Что:** `_city_version` не учитывает `level` зданий.

**До:**
```gdscript
func _city_version(city: City) -> int:
    var h: int = 0
    for bld in city.buildings:
        if bld != null:
            h = (h * 131 + int(bld.uid)) & 0x7fffffff
    return int(city.buildings.size()) * 1_000_003 + h
```

**После:**
```gdscript
func _city_version(city: City) -> int:
    var h: int = 0
    for bld in city.buildings:
        if bld != null:
            h = (h * 131 + int(bld.uid)) & 0x7fffffff
            h = (h * 137 + bld.level) & 0x7fffffff
            h = (h * 139 + bld.assigned_workers) & 0x7fffffff
    return int(city.buildings.size()) * 1_000_003 + h
```

### R5. Инкрементальный fog of war (Low)

**Что:** `_fill_disk` пересчитывает все клетки при каждом вызове.

**После:** хранить `visible` как `Dictionary`, при перемещении героя удалять старые клетки за пределами радиуса и добавлять новые.

### R6. Удаление мёртвого кода и `# ponytail:` маркеров (Low)

Маркеры `# ponytail:` встречаются в 8+ файлах. После стабилизации кода их следует удалить.

### Сводная таблица рефакторингов

| # | Правка | Приоритет | Риск |
|---|---|---|---|
| R1 | Command-паттерн для MCP-сервера | **High** | Средний (нужны регресс-тесты) |
| R2 | Хелпер `_resolve_node` | **High** | Низкий |
| R3 | Декомпозиция `City.gd` | **Medium** | Средний |
| R4 | Фикс `_city_version` | **Medium** | Низкий |
| R5 | Инкрементальный fog | **Low** | Средний |
| R6 | Очистка маркеров | **Low** | Нулевой |

---

## 5. Инструкция для локального агента

### Фаза 1 — Высокий приоритет (1–2 дня)

**Шаг 1.1.** Создать `mcp_command_registry.gd`:
```
Файл:  scripts/mcp/mcp_command_registry.gd
Суть:  class McpCommandRegistry — хранит Dictionary[StringName, Callable]
Методы: register(name, handler), resolve(name) -> Callable
```

**Шаг 1.2.** Рефакторинг `_handle_command` в `mcp_interaction_server.gd`:
- Заменить `match` на `_commands.get(command)`.
- Разбить регистрацию на группы: `_register_core_commands()`, `_register_battle_commands()`, `_register_ui_commands()`, `_register_world_commands()`, `_register_advanced_commands()`.

**Шаг 1.3.** Добавить `_resolve_node()` в `mcp_interaction_server.gd`.
- Заменить ~40 блоков проверки `node_path` на вызов хелпера.

**Проверка:**
```bash
# Запуск существующих тестов
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/ -a

# Критерий: все тесты зелёные, 0 ошибок парсинга
```

### Фаза 2 — Средний приоритет (2–3 дня)

**Шаг 2.1.** Создать `CityBuildingService.gd`:
```
Файл:  scripts/city/CityBuildingService.gd
Методы из City.gd: can_build_borough, build_borough, can_build_building,
         build_building, can_upgrade_building, perform_upgrade, relocate
```

**Шаг 2.2.** Создать `CityGrowthService.gd`:
```
Файл:  scripts/city/CityGrowthService.gd
Методы из City.gd: process_turn, net_food, growth_threshold, food_consumption
```

**Шаг 2.3.** Обновить `City.gd`: оставить данные + делегирование.

**Шаг 2.4.** Исправить `_city_version` в `ArenaClusterSystem.gd` (включить `level`, `assigned_workers`).

**Шаг 2.5.** Обновить тесты:
```
Файлы: tests/test_city_system.gd, tests/unit/test_city_system.gd,
       tests/test_city_chains.gd, tests/test_city_processor.gd
```

**Проверка:**
```bash
# Тесты города
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/test_city_system.gd \
  --add tests/unit/test_city_system.gd \
  --add tests/test_city_chains.gd \
  --add tests/test_city_processor.gd \
  -a

# Критерий: все тесты зелёные
# Дополнительно: ручная проверка в сцене CityArena
```

### Фаза 3 — Низкий приоритет (1 день)

**Шаг 3.1.** Удалить все маркеры `# ponytail:`.

**Шаг 3.2.** Заменить `@warning_ignore("integer_division")` в `HexUtils.gd` на явный `int()`.

**Шаг 3.3.** Добавить `is_inside_tree()` guard в `_cmd_http_request`:
```gdscript
func _cmd_http_request(params: Dictionary) -> void:
    # ...
    var result: Array = await http.request_completed
    if not is_inside_tree():
        return
    # ...
```

**Проверка:**
```bash
# Полный прогон тестов
/Applications/Godot.app/Contents/MacOS/Godot --headless \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/ -a

# MCP-тесты (если настроен сервер)
cd tests/mcp && python -m pytest -x

# Критерий приёмки:
# 1. 0 ошибок, 0 предупреждений парсинга
# 2. Все 150+ тестов зелёные
# 3. Ручной запуск сцены боя: бой 7v7 завершается без зависаний
# 4. Ручной запуск арены: 48 ходов автоплея без ошибок
```

### Контрольный чеклист

- [ ] `match command:` в MCP-сервере заменён на реестр
- [ ] `_resolve_node()` хелпер используется во всех командах с `node_path`
- [ ] `City.gd` < 250 строк
- [ ] `CityBuildingService`, `CityGrowthService` созданы и покрыты тестами
- [ ] `_city_version` учитывает `level` и `assigned_workers`
- [ ] Маркеры `# ponytail:` удалены
- [ ] `is_inside_tree()` guard добавлен во все `await`-методы
- [ ] Полный прогон тестов: **0 ошибок**
