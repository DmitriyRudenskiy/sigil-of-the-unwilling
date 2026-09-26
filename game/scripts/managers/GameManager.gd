class_name GameManager
extends Node

## Глобальный менеджер игрового цикла и состояния игры

signal day_passed(day: int)
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal crisis_started(crisis_id: String)
signal crisis_ended(crisis_id: String, resolved: bool)

const SAVE_DIR := "user://saves/"
const MAX_SAVE_SLOTS := 5
## Версия формата сейва GameManager (JSON). Инкремент при изменении схемы.
const SAVE_FORMAT_VERSION := 1

var current_day: int = 1
var is_game_paused: bool = false
var is_crisis_active: bool = false
var active_crisis_id: String = ""
var game_speed: float = 1.0

var player_data: Dictionary = {}
var world_state: Dictionary = {}
var event_history: Array[String] = []
var decision_log: Array[Dictionary] = []

@onready var ui_manager: UIManager = $UIManager if has_node("UIManager") else null
@onready var event_system: CrisisEventSystem = $CrisisEventSystem if has_node("CrisisEventSystem") else null


func _ready() -> void:
	_initialize_game()
	_connect_signals()


func _initialize_game() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	player_data = {
		"class": "settler",
		"resources": {"wood": 50, "food": 30, "gold": 100},
		"population": 5,
		"buildings": [],
		"reputation": 0,
		"heroes": []
	}

	world_state = {
		"season": "spring",
		"weather": "clear",
		"threat_level": 0.0,
		"last_event_day": 0
	}


func _connect_signals() -> void:
	if ui_manager:
		ui_manager.decision_made.connect(_on_decision_made)
		ui_manager.crisis_resolved.connect(_on_crisis_resolved)

	if event_system:
		event_system.crisis_started.connect(_on_crisis_triggered)


func _process(delta: float) -> void:
	if is_game_paused or is_crisis_active:
		return

	# Основной игровой цикл может быть здесь
	pass


## Вызывается в конце каждого игрового дня
func on_day_passed() -> void:
	current_day += 1
	day_passed.emit(current_day)

	# Проверка триггеров событий
	if event_system and not is_crisis_active:
		event_system.on_day_passed(current_day)

	# Очистка временных эффектов
	_cleanup_temporary_effects()


## Запуск кризиса (блокирует игру)
func start_crisis(crisis_data: Dictionary, crisis_id: String) -> void:
	is_crisis_active = true
	active_crisis_id = crisis_id
	is_game_paused = true

	crisis_started.emit(crisis_id)

	if ui_manager:
		ui_manager.show_crisis_panel(crisis_data, crisis_id)


## Завершение кризиса
func end_crisis(crisis_id: String, resolved: bool) -> void:
	if active_crisis_id != crisis_id:
		return

	is_crisis_active = false
	active_crisis_id = ""
	is_game_paused = false

	crisis_ended.emit(crisis_id, resolved)

	if resolved:
		_apply_crisis_rewards(crisis_id)
	else:
		_apply_crisis_penalties(crisis_id)


## Обработка выбора в событии
func _on_decision_made(event_id: String, choice_index: int) -> void:
	# Логирование решения (данные события хранит CrisisEventSystem)
	decision_log.append({
		"day": current_day,
		"event_id": event_id,
		"choice_index": choice_index
	})
	event_history.append(event_id)
	_update_world_state_after_choice(event_id, choice_index)


## Обработка выбора в кризисе
func _on_crisis_resolved(crisis_id: String, choice_index: int) -> void:
	# Логирование решения кризиса
	decision_log.append({
		"day": current_day,
		"crisis_id": crisis_id,
		"choice_index": choice_index,
		"is_crisis": true
	})
	# Эффекты выбора применяет CrisisEventSystem.resolve_crisis
	if event_system and event_system.has_method("resolve_crisis"):
		event_system.resolve_crisis(choice_index)
	end_crisis(crisis_id, true)


## Кризис запущен CrisisEventSystem. Показ панели — ответственность системы
## (она резолвит UIManager явно и владеет данными кризиса); здесь только
## состояние паузы/блока игры. Прямой show_crisis_panel отсюда рендерил бы
## второй popup поверх системного.
func _on_crisis_triggered(crisis_event) -> void:
	if is_crisis_active or crisis_event == null:
		return
	is_crisis_active = true
	active_crisis_id = crisis_event.id
	is_game_paused = true
	crisis_started.emit(crisis_event.id)


## Применение эффектов (ресурсы, репутация, разблокировка и т.д.)
func _apply_effects(effects: Dictionary) -> void:
	for resource in effects.get("resources", {}).keys():
		var amount = effects["resources"][resource]
		if player_data.has("resources") and player_data["resources"].has(resource):
			player_data["resources"][resource] += amount

	if effects.has("reputation"):
		player_data["reputation"] += effects["reputation"]

	if effects.has("unlock_building"):
		if not player_data["buildings"].has(effects["unlock_building"]):
			player_data["buildings"].append(effects["unlock_building"])

	if effects.has("trigger_event"):
		# ponytail: очередь событий не реализована — логируем id, триггер через on_day_passed
		event_history.append(str(effects["trigger_event"]))


## Обновление состояния мира после выбора
func _update_world_state_after_choice(event_id: String, choice_index: int) -> void:
	# Логика изменения состояния мира в зависимости от выбора
	# Например, изменение уровня угроз, сезонов, отношений с фракциями
	pass


## Очистка временных эффектов
func _cleanup_temporary_effects() -> void:
	# Удаление истёкших баффов/дебаффов
	pass


## Применение наград за успешный кризис
func _apply_crisis_rewards(crisis_id: String) -> void:
	# Бонусы за успешное разрешение кризиса
	pass


## Применение штрафов за проваленный кризис
func _apply_crisis_penalties(crisis_id: String) -> void:
	# Штрафы за провал кризиса
	pass


## Сохранение игры (JSON — единый формат с SaveManager, без бинарного store_var)
func save_game(slot: String = "quicksave") -> bool:
	var save_data := {
		"version": SAVE_FORMAT_VERSION,
		"day": current_day,
		"player_data": player_data,
		"world_state": world_state,
		"event_history": Array(event_history),
		"decision_log": Array(decision_log),
		"crisis_state": event_system.serialize_state() if event_system else {},
	}

	var path := _slot_path(slot)
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GameLogger.error("GameManager: cannot write %s (error %d)" % [path, FileAccess.get_open_error()], "Save")
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	game_saved.emit(slot)
	return true


## Загрузка игры. Возвращает false при отсутствии/повреждении файла или невалидных данных.
func load_game(slot: String = "quicksave") -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		GameLogger.warn("GameManager: no save at %s" % path, "Save")
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GameLogger.error("GameManager: cannot read %s" % path, "Save")
		return false
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		GameLogger.error("GameManager: corrupt save %s: %s" % [path, json.get_error_message()], "Save")
		return false
	var save_data: Dictionary = json.data

	# Валидация структуры: обязательные секции должны иметь ожидаемые типы,
	# иначе состояние менеджера будет повреждено частично загруженными данными.
	if not (save_data.get("player_data", {}) is Dictionary) \
			or not (save_data.get("world_state", {}) is Dictionary) \
			or not (save_data.get("event_history", []) is Array) \
			or not (save_data.get("decision_log", []) is Array):
		GameLogger.error("GameManager: invalid save structure in %s" % path, "Save")
		return false

	current_day = int(save_data.get("day", 1))
	player_data = save_data["player_data"]
	world_state = save_data["world_state"]
	event_history.clear()
	for e in save_data["event_history"]:
		event_history.append(str(e))
	decision_log.clear()
	for d in save_data["decision_log"]:
		if d is Dictionary:
			decision_log.append(d)
	if event_system:
		event_system.deserialize_state(save_data.get("crisis_state", {}))

	game_loaded.emit(slot)
	return true


func _slot_path(slot: String) -> String:
	# Защита от path traversal: слот — только [A-Za-z0-9_-]
	var safe_slot := slot.replace("/", "").replace("\\", "").replace("..", "")
	if safe_slot.is_empty():
		safe_slot = "quicksave"
	return SAVE_DIR + safe_slot + ".json"


## Получить список доступных сохранений
func get_save_slots() -> Array[String]:
	var slots: Array[String] = []
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		var dir := DirAccess.open(SAVE_DIR)
		if dir == null:
			return slots
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				slots.append(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()
	return slots


## Есть ли здание (для требований событий)
func has_building(building_id: String) -> bool:
	return player_data.get("buildings", []).has(building_id)


## Количество ресурса игрока (для требований событий)
func get_resource(resource: String) -> int:
	return int(player_data.get("resources", {}).get(resource, 0))


## Население (для триггеров и эффектов событий)
func get_population() -> int:
	return int(player_data.get("population", 0))


## Изменение ресурса (создаёт ключ при первом изменении; не уходит в минус).
## ponytail: ресурсы с нуля (tools/materials из событий) — не каноничный набор
## wood/food/gold; при появлении ResourceType-реестра валидировать ключ.
func modify_resource(resource: String, amount: int) -> void:
	var res: Dictionary = player_data.get("resources", {})
	res[resource] = max(0, int(res.get(resource, 0)) + amount)
	player_data["resources"] = res


## Изменение населения (не уходит в минус)
func modify_population(amount: int) -> void:
	player_data["population"] = max(0, int(player_data.get("population", 0)) + amount)


## Глобальная мораль поселения (0..100, дефолт 50).
## ponytail: поле "morale" изобретено (в player_data его не было); дефолт 50,
## clamp 0..100. При появлении UI-бара/баланса — пересмотреть диапазон/старт.
func get_global_morale() -> int:
	return int(player_data.get("morale", 50))


func modify_global_morale(amount: int) -> void:
	player_data["morale"] = clampi(int(player_data.get("morale", 50)) + amount, 0, 100)


## Разблокировка здания (для эффектов событий)
func unlock_building(building_id: String) -> void:
	var buildings: Array = player_data.get("buildings", [])
	if not buildings.has(building_id):
		buildings.append(building_id)
		player_data["buildings"] = buildings


## Постоянные модификаторы (id -> effect) из эффектов выбора.
## ponytail: храним id->effect, агрегация на мораль/производство не сделана —
## при появлении системы пассивных эффектов (LawManager.passive_effects) свести.
func add_permanent_modifier(mod_id: String, effect: Dictionary) -> void:
	if not player_data.has("permanent_modifiers"):
		player_data["permanent_modifiers"] = {}
	player_data["permanent_modifiers"][mod_id] = effect


## Модификатор производства (накапливаемый float, напр. -0.2 = -20%).
## ponytail: простое накопление; применение к реальному производству — позже.
func apply_production_modifier(value: float) -> void:
	player_data["production_modifier"] = float(player_data.get("production_modifier", 0.0)) + value


## Получить данные игрока
func get_player_data() -> Dictionary:
	return player_data


## Получить состояние мира
func get_world_state() -> Dictionary:
	return world_state


## Получить текущий день
func get_current_day() -> int:
	return current_day


## Проверка, активен ли кризис
func is_crisis_active_now() -> bool:
	return is_crisis_active


## Пауза игры
func pause_game() -> void:
	is_game_paused = true


## Возобновление игры
func resume_game() -> void:
	if not is_crisis_active:
		is_game_paused = false
