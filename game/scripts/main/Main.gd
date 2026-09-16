extends Node

## Главная сцена игры - координирует менеджеры и игровой цикл

@export var day_duration: float = 3.0

var _day_timer: float = 0.0
var _is_day_cycle_active: bool = true

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager
@onready var day_label: Label = $CanvasLayer/DayLabel if has_node("CanvasLayer/DayLabel") else null


func _ready():
	_connect_ui()
	print("🎮 Игра запущена! День: %d" % game_manager.get_current_day())


func _connect_ui():
	if game_manager:
		game_manager.day_passed.connect(_on_day_passed)
		game_manager.crisis_started.connect(_on_crisis_started)
		game_manager.crisis_ended.connect(_on_crisis_ended)


func _process(delta: float):
	if not _is_day_cycle_active or game_manager.is_crisis_active_now():
		return
	_day_timer += delta
	if _day_timer >= day_duration:
		_day_timer = 0.0
		_advance_day()


func _advance_day():
	if game_manager:
		game_manager.on_day_passed()
	if day_label:
		day_label.text = "День: %d" % game_manager.get_current_day()


func _on_day_passed(day: int):
	print("📅 Наступил день %d" % day)


func _on_crisis_started(crisis_id: String):
	_is_day_cycle_active = false
	print("⚠️ КРИЗИС НАЧАЛСЯ: %s" % crisis_id)


func _on_crisis_ended(crisis_id: String, resolved: bool):
	_is_day_cycle_active = true
	print("✅ Кризис завершен: %s" % ("успешно" if resolved else "провалено"))
