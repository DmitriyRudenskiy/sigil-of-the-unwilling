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


## Кризис запущен CrisisEventSystem
func _on_crisis_triggered(crisis_event) -> void:
	if is_crisis_active or crisis_event == null:
		return
	start_crisis({
		"title": crisis_event.title,
		"description": crisis_event.description,
		"severity": crisis_event.severity
	}, crisis_event.id)


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


## Сохранение игры
func save_game(slot: String = "quicksave") -> bool:
	var save_data = {
		"day": current_day,
		"player_data": player_data,
		"world_state": world_state,
		"event_history": event_history,
		"decision_log": decision_log
	}

	var file = FileAccess.open(SAVE_DIR + slot + ".save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		game_saved.emit(slot)
		return true
	return false


## Загрузка игры
func load_game(slot: String = "quicksave") -> bool:
	var file = FileAccess.open(SAVE_DIR + slot + ".save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()

		current_day = save_data.get("day", 1)
		player_data = save_data.get("player_data", {})
		world_state = save_data.get("world_state", {})
		event_history = save_data.get("event_history", [])
		decision_log = save_data.get("decision_log", [])

		game_loaded.emit(slot)
		return true
	return false


## Получить список доступных сохранений
func get_save_slots() -> Array[String]:
	var slots: Array[String] = []
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		var dir = DirAccess.open(SAVE_DIR)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".save"):
				slots.append(file_name.replace(".save", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return slots


## Есть ли здание (для требований событий)
func has_building(building_id: String) -> bool:
	return player_data.get("buildings", []).has(building_id)


## Количество ресурса игрока (для требований событий)
func get_resource(resource: String) -> int:
	return int(player_data.get("resources", {}).get(resource, 0))


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
