extends Node
class_name UIManager

## Менеджер пользовательского интерфейса для отображения панелей решений и кризисов

signal decision_made(event_id: String, choice_index: int)
signal crisis_resolved(crisis_id: String, choice_index: int)

var decision_panel: PackedScene
var crisis_panel: PackedScene
var current_decision_popup: Control
var current_crisis_popup: Control

func _ready():
	# Контракт поиска для CrisisEventSystem (см. его _ready/_ui): в main.tscn
	# UIManager — дочерняя нода Main, а не autoload, поэтому /root/UIManager
	# никогда не резолвится; группа — канонический способ найти менеджер.
	add_to_group("ui_manager")
	# Предзагрузка сцен панелей (пути могут быть изменены при создании UI)
	decision_panel = load("res://assets/ui/panels/decision_panel.tscn") if ResourceLoader.exists("res://assets/ui/panels/decision_panel.tscn") else null
	crisis_panel = load("res://assets/ui/panels/crisis_panel.tscn") if ResourceLoader.exists("res://assets/ui/panels/crisis_panel.tscn") else null

## Показать панель принятия решения для события
## @param event_data Данные события (заголовок, описание, варианты выбора)
## @param event_id Уникальный идентификатор события
func show_decision_panel(event_data: Dictionary, event_id: String):
	if current_decision_popup != null:
		current_decision_popup.queue_free()
	
	if decision_panel == null:
		_create_simple_decision_panel(event_data, event_id)
		return
	
	var popup = decision_panel.instantiate()
	get_tree().root.add_child(popup)
	current_decision_popup = popup
	
	# Настройка контента панели
	if popup.has_method("setup"):
		popup.setup(event_data, event_id)
		popup.connect("choice_selected", _on_decision_choice_selected.bind(event_id))

## Показать панель кризиса (блокирующую игру)
## @param crisis_data Данные кризиса (заголовок, описание, срочные варианты)
## @param crisis_id Уникальный идентификатор кризиса
func show_crisis_panel(crisis_data: Dictionary, crisis_id: String):
	if current_crisis_popup != null:
		current_crisis_popup.queue_free()
	
	if crisis_panel == null:
		_create_simple_crisis_panel(crisis_data, crisis_id)
		return
	
	var popup = crisis_panel.instantiate()
	get_tree().root.add_child(popup)
	current_crisis_popup = popup
	
	# Настройка контента панели кризиса
	if popup.has_method("setup"):
		popup.setup(crisis_data, crisis_id)
		popup.connect("crisis_resolved", _on_crisis_choice_selected.bind(crisis_id))

## Закрыть текущую панель решения
func close_decision_panel():
	if current_decision_popup != null:
		current_decision_popup.queue_free()
		current_decision_popup = null

## Закрыть текущую панель кризиса
func close_crisis_panel():
	if current_crisis_popup != null:
		current_crisis_popup.queue_free()
		current_crisis_popup = null

## Обработчик выбора в решении
func _on_decision_choice_selected(choice_index: int, event_id: String):
	decision_made.emit(event_id, choice_index)
	close_decision_panel()

## Обработчик выбора в кризисе
func _on_crisis_choice_selected(choice_index: int, crisis_id: String):
	crisis_resolved.emit(crisis_id, choice_index)
	close_crisis_panel()

## Создание простой панели решения программно (если сцена не найдена)
func _create_simple_decision_panel(event_data: Dictionary, event_id: String):
	var popup = Window.new()
	popup.title = event_data.get("title", "Событие")
	popup.size = Vector2(600, 400)
	popup.position = (get_viewport().get_visible_rect().size - popup.size) / 2
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = event_data.get("title", "Событие")
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)
	
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = event_data.get("description", "")
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	
	var choices_container = VBoxContainer.new()
	for i in range(event_data.get("choices", []).size()):
		var btn = Button.new()
		var choice = event_data["choices"][i]
		btn.text = choice.get("text", "Вариант %d" % (i + 1))
		btn.connect("pressed", _on_decision_choice_selected.bind(i, event_id))
		choices_container.add_child(btn)
	
	vbox.add_child(choices_container)
	
	get_tree().root.add_child(popup)
	current_decision_popup = popup
	popup.show()

## Создание простой панели кризиса программно (если сцена не найдена)
func _create_simple_crisis_panel(crisis_data: Dictionary, crisis_id: String):
	var popup = Window.new()
	popup.title = "⚠️ КРИЗИС: " + crisis_data.get("title", "Угроза")
	popup.size = Vector2(700, 500)
	popup.position = (get_viewport().get_visible_rect().size - popup.size) / 2
	popup.exclusive = true # Блокирует другие окна
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	popup.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "⚠️ КРИЗИС: " + crisis_data.get("title", "Угроза")
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var timer_label = Label.new()
	timer_label.text = "Время на решение: %d дн." % crisis_data.get("time_limit", 3)
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(timer_label)
	
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = crisis_data.get("description", "")
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	
	var choices_container = VBoxContainer.new()
	for i in range(crisis_data.get("choices", []).size()):
		var btn = Button.new()
		var choice = crisis_data["choices"][i]
		btn.text = choice.get("text", "Решение %d" % (i + 1))
		btn.custom_minimum_size.y = 60
		btn.connect("pressed", _on_crisis_choice_selected.bind(i, crisis_id))
		choices_container.add_child(btn)
	
	vbox.add_child(choices_container)
	
	get_tree().root.add_child(popup)
	current_crisis_popup = popup
	popup.show()
