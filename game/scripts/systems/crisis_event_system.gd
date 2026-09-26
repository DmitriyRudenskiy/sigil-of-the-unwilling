class_name CrisisEventSystem
extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

## Система динамических событий и кризисов (RimWorld + Frostpunk style)
## - Генерация событий на основе состояния поселения
## - Кризисы с обязательным выбором решения (нельзя пропустить ход)
## - Долгосрочные последствия решений

signal crisis_started(event: CrisisEventData)
signal crisis_resolved(event: CrisisEventData, choice_index: int)
signal event_triggered(event: DynamicEventData)

enum CrisisType {
	NATURAL_DISASTER,    # Пожар, наводнение, землетрясение
	RESOURCE_SHORTAGE,   # Нехватка еды, топлива, материалов
	SOCIAL_UNREST,       # Бунты, забастовки, бегство жителей
	EXTERNAL_THREAT,     # Нападение, рейдеры, монстры
	EPIDEMIC,            # Болезни, эпидемии
	MAGICAL_ANOMALY      # Магические катаклизмы
}

enum EventFrequency {
	VERY_RARE = 1,    # 1 раз в 50-100 дней
	RARE = 2,         # 1 раз в 30-50 дней
	UNCOMMON = 3,     # 1 раз в 15-30 дней
	COMMON = 4,       # 1 раз в 7-15 дней
	FREQUENT = 5      # 1 раз в 3-7 дней
}

enum ChoiceImpact {
	POSITIVE_MAJOR,   # +Значительный бонус
	POSITIVE_MINOR,   # +Небольшой бонус
	NEUTRAL,          # Без изменений
	NEGATIVE_MINOR,   # -Небольшой штраф
	NEGATIVE_MAJOR    # -Значительный урон
}

## Безопасные конвертеры из JSON (числа приходят как float): без приведения к int
## присваивание float в типизированное var severity:int — ошибка рантайма.
static func _as_int(v, fallback: int) -> int:
	return int(v) if (v is int or v is float) else fallback

static func _as_float(v, fallback: float) -> float:
	return float(v) if (v is int or v is float) else fallback

static func _as_string(v, fallback: String) -> String:
	return v if v is String else fallback

static func _as_dict(v) -> Dictionary:
	return v if v is Dictionary else {}

static func _as_array(v) -> Array:
	return v if v is Array else []

# Данные выбора в событии
class ChoiceData:
	var text: String
	var tooltip: String
	var impact: ChoiceImpact
	var effects: Dictionary = {}  # Последствия выбора
	var requirements: Dictionary = {}  # Требования для доступности

	func _init(data: Dictionary = {}):
		text = CrisisEventSystem._as_string(data.get("text", ""), "")
		tooltip = CrisisEventSystem._as_string(data.get("tooltip", ""), "")
		impact = CrisisEventSystem._as_int(data.get("impact"), ChoiceImpact.NEUTRAL) as ChoiceImpact
		effects = CrisisEventSystem._as_dict(data.get("effects"))
		requirements = CrisisEventSystem._as_dict(data.get("requirements"))

# Данные события
class DynamicEventData:
	var id: String
	var title: String
	var description: String
	var icon_path: String
	var frequency: EventFrequency
	var min_day: int = 1
	var triggers: Dictionary = {}  # Условия активации
	var choices: Array[ChoiceData] = []
	var weight: float = 1.0

	func _init(data: Dictionary = {}):
		id = CrisisEventSystem._as_string(data.get("id", ""), "")
		title = CrisisEventSystem._as_string(data.get("title", ""), "")
		description = CrisisEventSystem._as_string(data.get("description", ""), "")
		icon_path = CrisisEventSystem._as_string(data.get("icon_path", ""), "")
		frequency = CrisisEventSystem._as_int(data.get("frequency"), EventFrequency.COMMON) as EventFrequency
		min_day = CrisisEventSystem._as_int(data.get("min_day"), 1)
		triggers = CrisisEventSystem._as_dict(data.get("triggers"))
		weight = CrisisEventSystem._as_float(data.get("weight"), 1.0)
		for c in CrisisEventSystem._as_array(data.get("choices")):
			if c is Dictionary:
				choices.append(ChoiceData.new(c))

# Данные кризиса
class CrisisEventData:
	var id: String
	var title: String
	var description: String
	var crisis_type: CrisisType
	var severity: int = 1  # 1-5 масштаб кризиса
	var duration_days: int = 1  # Сколько длится
	var icon_path: String
	var min_day: int = 1
	var triggers: Dictionary = {}  # Условия активации (как у DynamicEventData)
	var choices: Array[ChoiceData] = []
	var ongoing_effects: Dictionary = {}  # Эффекты во время кризиса
	var resolution_effects: Dictionary = {}  # Эффекты после разрешения

	func _init(data: Dictionary = {}):
		id = CrisisEventSystem._as_string(data.get("id", ""), "")
		title = CrisisEventSystem._as_string(data.get("title", ""), "")
		description = CrisisEventSystem._as_string(data.get("description", ""), "")
		crisis_type = CrisisEventSystem._as_int(data.get("crisis_type"), CrisisType.NATURAL_DISASTER) as CrisisType
		severity = clampi(CrisisEventSystem._as_int(data.get("severity"), 1), 1, 5)
		duration_days = maxi(1, CrisisEventSystem._as_int(data.get("duration_days"), 1))
		icon_path = CrisisEventSystem._as_string(data.get("icon_path", ""), "")
		min_day = CrisisEventSystem._as_int(data.get("min_day"), 1)
		triggers = CrisisEventSystem._as_dict(data.get("triggers"))
		ongoing_effects = CrisisEventSystem._as_dict(data.get("ongoing_effects"))
		resolution_effects = CrisisEventSystem._as_dict(data.get("resolution_effects"))
		for c in CrisisEventSystem._as_array(data.get("choices")):
			if c is Dictionary:
				choices.append(ChoiceData.new(c))

# Состояние системы
var current_crisis: CrisisEventData = null
var active_events: Array[DynamicEventData] = []
var event_history: Array[Dictionary] = []
var day_counter: int = 0
var next_event_day: int = 5
var crisis_cooldown_days: int = 20
var last_crisis_day: int = -crisis_cooldown_days
## День начала текущего кризиса (O(1)-проверка duration в process_ongoing_crisis).
## var — а не const-выражение на месте использования, чтобы deserialize_state
## мог восстановить его из истории при загрузке сейва.
var _crisis_start_day: int = 0

# Конфигурация
var base_event_chance: float = 0.3  # Базовый шанс события каждый день
var crisis_chance_multiplier: float = 0.05  # Шанс кризиса растёт со временем
var max_active_events: int = 3

# Загруженные данные
var event_templates: Array[DynamicEventData] = []
var crisis_templates: Array[CrisisEventData] = []

## Law system (unlocked via event choices, apply passive modifiers).
var law_manager: LawManager = null

## Зависимости внедряются явно (см. GameManager._connect_signals и Main) либо
## резолвятся через группы ("game_manager", "ui_manager"), которые менеджеры
## регистрируют в своих _ready. Обход дерева через get_parent()/магические
## пути запрещен конвенциями проекта (слабая связанность).
var game_manager: Node = null
var ui_manager: Node = null

func _ready():
	load_event_templates()
	load_crisis_templates()
	update_next_event_day()
	if law_manager == null:
		law_manager = LawManager.new()
		law_manager.load_default_catalog()
	# UIManager регистрирует группу "ui_manager" в своем _ready.
	if ui_manager == null:
		ui_manager = get_tree().get_first_node_in_group("ui_manager") \
			if get_tree() != null else null

## Разрешение game_manager: явно внедрённый → группа "game_manager"
## (работает и для смонтированного на /root в тестах, и для ноды в main.tscn).
## Резолв ленивый и кэшируется.
func _gm() -> Node:
	if game_manager != null and is_instance_valid(game_manager):
		return game_manager
	game_manager = null
	if get_tree() == null:
		return null
	var candidate := get_tree().get_first_node_in_group("game_manager")
	if candidate != null and candidate.has_method("modify_resource"):
		game_manager = candidate
	return game_manager

## Сериализация состояния (события/кризис/законы) для сохранения.
## Объекты событий/кризисов хранятся по id — шаблоны перезагружаются при старте.
func serialize_state() -> Dictionary:
	var active_ids: Array[String] = []
	for e in active_events:
		active_ids.append(e.id)
	return {
		"day_counter": day_counter,
		"next_event_day": next_event_day,
		"last_crisis_day": last_crisis_day,
		"current_crisis_id": current_crisis.id if current_crisis else "",
		"active_event_ids": active_ids,
		"event_history": event_history.duplicate(true),
		"law": law_manager.to_dict() if law_manager else {},
	}

## Восстановление состояния из сохранения. Шаблоны должны быть загружены.
func deserialize_state(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	day_counter = int(data.get("day_counter", 0))
	next_event_day = int(data.get("next_event_day", 5))
	last_crisis_day = int(data.get("last_crisis_day", -crisis_cooldown_days))
	event_history.clear()
	for h in data.get("event_history", []):
		if h is Dictionary:
			event_history.append(h)
	current_crisis = _find_crisis_template(str(data.get("current_crisis_id", "")))
	# Восстановление дня начала кризиса из записи истории (serialize_state её
	# не хранит явно); без этого duration-таймер стартовал бы с 0 и кризис
	# разрешался автоматически в первый же день после загрузки.
	_crisis_start_day = day_counter
	if current_crisis != null:
		for i in range(event_history.size() - 1, -1, -1):
			var record: Dictionary = event_history[i]
			if record.get("type") == "crisis" and record.get("id") == current_crisis.id \
					and not bool(record.get("resolved", false)):
				_crisis_start_day = int(record.get("day", day_counter))
				break
	active_events.clear()
	for eid in data.get("active_event_ids", []):
		var ev := _find_event_template(str(eid))
		if ev != null:
			active_events.append(ev)
	if law_manager != null:
		law_manager.from_dict(data.get("law", {}))

func _find_crisis_template(id: String) -> CrisisEventData:
	if id == "":
		return null
	for c in crisis_templates:
		if c.id == id:
			return c
	return null

func _find_event_template(id: String) -> DynamicEventData:
	if id == "":
		return null
	for e in event_templates:
		if e.id == id:
			return e
	return null

## Загрузка шаблонов событий из JSON.
## Формат: один файл = одно событие (event_*.json). events_database.json —
## легаси-сборник другого формата, загрузчиком игнорируется (см. комментарий).
func load_event_templates():
	event_templates.clear()
	var dir = DirAccess.open("res://data/events/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# "crisis_" — кризисы; "events_database" — легаси-формат без поля id.
			if file_name.ends_with(".json") and not file_name.begins_with("crisis_") \
					and not file_name.begins_with("events_database"):
				var event_data = load_event_json("res://data/events/" + file_name)
				if event_data:
					event_templates.append(DynamicEventData.new(event_data))
			file_name = dir.get_next()
	GameLogger.info("Loaded %d event templates" % event_templates.size(), "CrisisEvents")

## Загрузка шаблонов кризисов
func load_crisis_templates():
	crisis_templates.clear()
	var dir = DirAccess.open("res://data/events/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("crisis_") and file_name.ends_with(".json"):
				var crisis_data = load_crisis_json("res://data/events/" + file_name)
				if crisis_data:
					crisis_templates.append(CrisisEventData.new(crisis_data))
			file_name = dir.get_next()
	GameLogger.info("Loaded %d crisis templates" % crisis_templates.size(), "CrisisEvents")

## Загрузка JSON события
func load_event_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return json.data
	return {}

## Загрузка JSON кризиса
func load_crisis_json(path: String) -> Dictionary:
	return load_event_json(path)

## Вызов каждый игровой день
func on_day_passed(day: int):
	day_counter = day
	
	# Проверка активного кризиса
	if current_crisis != null:
		process_ongoing_crisis()
		return  # Во время кризиса обычные события не触发
	
	# Проверка шанса кризиса
	if can_trigger_crisis() and should_trigger_crisis():
		trigger_random_crisis()
		return
	
	# Проверка обычных событий
	if day >= next_event_day and active_events.size() < max_active_events:
		try_trigger_event()
		update_next_event_day()

## Обновление следующего дня события
func update_next_event_day():
	var frequency_modifier = 1.0
	if not active_events.is_empty():
		frequency_modifier = 1.5  # Реже если уже есть активные события
	
	var base_interval = int(7.0 / base_event_chance * frequency_modifier)
	var variability = randi() % 4 - 2  # -2 to +2 дня
	next_event_day = day_counter + max(3, base_interval + variability)

## Попытка触发事件
func try_trigger_event():
	var available_events = get_available_events()
	if available_events.is_empty():
		return
	
	# Выбор взвешенного случайного события
	var total_weight = 0.0
	for event in available_events:
		total_weight += event.weight
	
	var roll = randf() * total_weight
	var cumulative = 0.0
	for event in available_events:
		cumulative += event.weight
		if roll <= cumulative:
			trigger_event(event)
			break

## Получение доступных событий
func get_available_events() -> Array[DynamicEventData]:
	var available = []
	for event in event_templates:
		if event.min_day > day_counter:
			continue
		if is_event_recently_occurred(event.id):
			continue
		if not check_event_triggers(event):
			continue
		available.append(event)
	return available

## Проверка триггеров события
func check_event_triggers(event: DynamicEventData) -> bool:
	return _check_triggers(event.triggers)

## Проверка триггеров кризиса (те же условия, что и у обычных событий — DRY).
func check_crisis_triggers(crisis: CrisisEventData) -> bool:
	return _check_triggers(crisis.triggers)

## Общая проверка триггеров: события и кризисы имеют одинаковую структуру.
func _check_triggers(triggers: Dictionary) -> bool:
	if triggers.is_empty():
		return true

	var game_manager := _gm()
	if not game_manager:
		# Без GameManager проверить условия нельзя — не блокируем.
		return true

	if triggers.has("population_min"):
		if game_manager.get_population() < int(triggers["population_min"]):
			return false

	if triggers.has("resource_low"):
		var low = triggers["resource_low"]
		if low is Dictionary and low.has("resource") and low.has("threshold"):
			if game_manager.get_resource(str(low["resource"])) >= int(low["threshold"]):
				return false

	if triggers.has("building_required"):
		var building = triggers["building_required"]
		if not game_manager.has_building(str(building)):
			return false

	return true

## Trigger события
func trigger_event(event: DynamicEventData):
	active_events.append(event)
	_record_history("event", event.id)
	event_triggered.emit(event)
	show_event_panel(event)

## Максимум записей истории (история растёт неограниченно при длинной партии;
## для cooldown-проверок и serialize хватает хвоста).
const MAX_HISTORY_ENTRIES := 200

func _record_history(type: String, id: String) -> void:
	event_history.append({"type": type, "id": id, "day": day_counter, "resolved": false})
	if event_history.size() > MAX_HISTORY_ENTRIES:
		event_history.pop_front()

func _mark_resolved(type: String, id: String, choice_index: int = -1) -> void:
	for i in range(event_history.size() - 1, -1, -1):
		var record: Dictionary = event_history[i]
		if record.get("type") == type and record.get("id") == id \
				and not bool(record.get("resolved", false)):
			record["resolved"] = true
			if choice_index >= 0:
				record["choice"] = choice_index
			return

## Проверка возможности кризиса
func can_trigger_crisis() -> bool:
	return day_counter - last_crisis_day >= crisis_cooldown_days

## Проверка шанса кризиса
func should_trigger_crisis() -> bool:
	# Шанс растёт со временем и от сложности
	var base_chance = crisis_chance_multiplier
	var time_factor = float(day_counter) / 100.0  # Увеличивается каждые 100 дней
	var total_chance = base_chance + time_factor
	return randf() < total_chance

## Trigger случайного кризиса
func trigger_random_crisis():
	var available_crises = get_available_crises()
	if available_crises.is_empty():
		return
	
	var crisis = available_crises[randi() % available_crises.size()]
	current_crisis = crisis
	last_crisis_day = day_counter
	_crisis_start_day = day_counter

	crisis_started.emit(crisis)
	_record_history("crisis", crisis.id)

	show_crisis_panel(crisis)

## Получение доступных кризисов
func get_available_crises() -> Array[CrisisEventData]:
	var available = []
	for crisis in crisis_templates:
		if crisis.min_day > day_counter:
			continue
		if not check_crisis_triggers(crisis):
			continue
		available.append(crisis)
	return available

## Обработка продолжающегося кризиса
func process_ongoing_crisis():
	if current_crisis == null:
		return
	# Применение ongoing эффектов
	apply_crisis_effects(current_crisis.ongoing_effects)

	# Проверка завершения
	if day_counter - _crisis_start_day >= current_crisis.duration_days:
		resolve_crisis(-1)  # Автоматическое разрешение если игрок бездействовал

## День начала текущего кризиса (O(1); синхронизируется с историей при load).
func get_crisis_start_day() -> int:
	return _crisis_start_day

## Разрешение ui_manager: явно внедрённый → группа "ui_manager" (UIManager
## регистрирует её в _ready). Резолв ленивый и кэшируется; обход дерева
## через get_parent() запрещен конвенциями проекта.
func _ui() -> Node:
	if ui_manager != null and is_instance_valid(ui_manager):
		return ui_manager
	ui_manager = null
	if get_tree() == null:
		return null
	var candidate := get_tree().get_first_node_in_group("ui_manager")
	if candidate != null and candidate.has_method("show_decision_panel"):
		ui_manager = candidate
	return ui_manager

## Применение эффектов кризиса
func apply_crisis_effects(effects: Dictionary):
	var game_manager := _gm()
	if not game_manager:
		return
	
	for effect_type in effects:
		var value = effects[effect_type]
		if effect_type == "resource_drain":
			for resource in value:
				game_manager.modify_resource(resource, -value[resource])
		elif effect_type == "morale_penalty":
			game_manager.modify_global_morale(value)
		elif effect_type == "production_reduction":
			game_manager.apply_production_modifier(value)

## Разрешение кризиса с выбором
func resolve_crisis(choice_index: int):
	if current_crisis == null:
		return
	
	var choice = null
	if choice_index >= 0 and choice_index < current_crisis.choices.size():
		choice = current_crisis.choices[choice_index]
		apply_choice_effects(choice.effects)
	
	# Применение resolution эффектов
	apply_crisis_effects(current_crisis.resolution_effects)
	
	crisis_resolved.emit(current_crisis, choice_index)
	
	# Обновление истории
	for i in range(event_history.size() - 1, -1, -1):
		if event_history[i]["type"] == "crisis" and event_history[i]["id"] == current_crisis.id:
			event_history[i]["resolved"] = true
			event_history[i]["choice"] = choice_index
			break
	
	current_crisis = null
	hide_crisis_panel()

## Применение эффектов выбора
func apply_choice_effects(effects: Dictionary):
	var game_manager := _gm()
	if not game_manager:
		return
	
	for effect_type in effects:
		var value = effects[effect_type]
		if effect_type == "resource_change":
			for resource in value:
				game_manager.modify_resource(resource, value[resource])
		elif effect_type == "morale_change":
			game_manager.modify_global_morale(value)
		elif effect_type == "population_change":
			game_manager.modify_population(value)
		elif effect_type == "unlock_building":
			game_manager.unlock_building(value)
		elif effect_type == "permanent_modifier":
			game_manager.add_permanent_modifier(value["id"], value["effect"])
		elif effect_type == "unlock_law":
			if law_manager:
				law_manager.unlock_law(str(value))

## Показать панель события (UI).
## Словарь-адаптер вместо объекта: show_decision_panel ожидает Dictionary
## (title/description/choices), передача DynamicEventData вызывала ошибку
## типов в рантайме.
func show_event_panel(event: DynamicEventData):
	var um := _ui()
	if um != null:
		um.show_decision_panel(_event_to_panel_data(event), event.id)

static func _event_to_panel_data(event) -> Dictionary:
	var choices: Array = []
	for c in event.choices:
		choices.append({"text": c.text, "tooltip": c.tooltip})
	return {
		"title": event.title,
		"description": event.description,
		"icon_path": event.icon_path,
		"choices": choices,
	}

## Показать панель кризиса (UI).
## Панель показывает CrisisEventSystem (владелец данных); GameManager через
## _on_crisis_triggered управляет только состоянием паузы — иначе popup
## рендерился бы дважды. close-метод UIManager называется
## close_crisis_panel (hide_crisis_panel у него нет).
func show_crisis_panel(crisis: CrisisEventData):
	var um := _ui()
	if um != null:
		var data := _event_to_panel_data(crisis)
		data["severity"] = crisis.severity
		data["time_limit"] = crisis.duration_days
		um.show_crisis_panel(data, crisis.id)

## Скрыть панель кризиса
func hide_crisis_panel():
	var um := _ui()
	if um != null and um.has_method("close_crisis_panel"):
		um.close_crisis_panel()

## Проверка было ли событие недавно
func is_event_recently_occurred(event_id: String) -> bool:
	var cooldown_days = 30
	for record in event_history:
		if record["id"] == event_id and record["type"] == "event":
			if day_counter - record["day"] < cooldown_days:
				return true
	return false

## Получить историю событий
func get_event_history() -> Array[Dictionary]:
	return event_history

## Сброс системы (новая игра)
func reset():
	current_crisis = null
	active_events.clear()
	event_history.clear()
	day_counter = 0
	next_event_day = 5
	last_crisis_day = -crisis_cooldown_days
	_crisis_start_day = 0
