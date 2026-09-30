class_name DecisionPanel
extends Control

const CrisisEventSystem = preload("res://scripts/systems/crisis_event_system.gd")


## UI панель для отображения событий и кризисов
## Блокирует возможность пропуска хода во время кризиса

signal decision_made(choice_index: int)

@export var title_label: Label
@export var description_label: Label
@export var icon_texture: TextureRect
@export var choices_container: VBoxContainer
@export var crisis_timer: Label
@export var severity_indicator: HBoxContainer

var current_event_data = null
var is_crisis: bool = false
var days_remaining: int = 0
var _pause_token: int = 0

func _ready():
	hide()
	for child in choices_container.get_children():
		child.queue_free()

## Показать обычное событие
func show_event(event):
	is_crisis = false
	current_event_data = event
	
	title_label.text = event.title
	description_label.text = event.description
	
	if event.icon_path and ResourceLoader.exists(event.icon_path):
		icon_texture.texture = load(event.icon_path)
	else:
		icon_texture.texture = null
	
	show_choices(event.choices)
	show()
	
	# Блокируем игровой цикл через PauseController (reference-counted),
	# чтобы избежать «залипшей паузы» при смене сцены.
	_release_pause()
	_pause_token = PauseController.acquire(&"DecisionPanel.event")

## Показать кризис
func show_crisis(crisis):
	is_crisis = true
	current_event_data = crisis
	days_remaining = crisis.duration_days
	
	title_label.text = crisis.title
	description_label.text = crisis.description
	
	if crisis.icon_path and ResourceLoader.exists(crisis.icon_path):
		icon_texture.texture = load(crisis.icon_path)
	else:
		icon_texture.texture = null
	
	show_choices(crisis.choices)
	update_severity_indicator(crisis.severity)
	crisis_timer.visible = true
	crisis_timer.text = "Дней осталось: %d" % days_remaining
	
	show()
	_release_pause()
	_pause_token = PauseController.acquire(&"DecisionPanel.crisis")

func _release_pause() -> void:
	if _pause_token != 0:
		PauseController.release(_pause_token, &"DecisionPanel")
		_pause_token = 0


## Показать варианты выбора
func show_choices(choices: Array):
	# Очистить старые кнопки
	for child in choices_container.get_children():
		child.queue_free()
	
	# Создать новые кнопки
	for i in range(choices.size()):
		var choice = choices[i]
		
		var button = Button.new()
		button.text = choice.text
		button.custom_minimum_size = Vector2(400, 60)
		button.add_theme_font_size_override("font_size", 16)
		
		# Проверка доступности выбора
		if not is_choice_available(choice):
			button.disabled = true
			button.text += " (недоступно)"
		
		button.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(button)
		
		# Добавить tooltip
		if choice.tooltip != "":
			button.tooltip_text = choice.tooltip

## Проверка доступности выбора
func is_choice_available(choice) -> bool:
	if choice.requirements.is_empty():
		return true
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return true
	
	if choice.requirements.has("building_required"):
		if not game_manager.has_building(choice.requirements["building_required"]):
			return false
	
	if choice.requirements.has("resource_min"):
		var resource = choice.requirements["resource_min"]["resource"]
		var min_amount = choice.requirements["resource_min"]["amount"]
		if game_manager.get_resource(resource) < min_amount:
			return false
	
	return true

## Обновление индикатора серьёзности кризиса
func update_severity_indicator(severity: int):
	for child in severity_indicator.get_children():
		child.queue_free()
	
	for i in range(5):
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(20, 20)
		
		if i < severity:
			if severity <= 2:
				color_rect.color = Color.GREEN
			elif severity <= 4:
				color_rect.color = Color.ORANGE
			else:
				color_rect.color = Color.RED
		else:
			color_rect.color = Color.GRAY
		
		severity_indicator.add_child(color_rect)

## Обработка выбора
func _on_choice_selected(choice_index: int):
	decision_made.emit(choice_index)
	_release_pause()
	hide()

## Обновление таймера кризиса (вызывается каждый день)
func update_crisis_timer(days_left: int):
	days_remaining = days_left
	if crisis_timer.visible:
		crisis_timer.text = "Дней осталось: %d" % days_remaining

## Закрыть панель без выбора (только для обычных событий)
func close_without_choice():
	if not is_crisis:
		_release_pause()
		hide()
