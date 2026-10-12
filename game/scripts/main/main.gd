extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

## Главная сцена игры - координирует менеджеры и игровой цикл.
## T-010 пост-условие (12-я итерация): campaign-слой — composition root
## (CampaignComposition, 14-я раунд 4: та же проводка у main.gd и у
## cutover-композита D-157); каждый тик дня = 1 ход кампании.
## I1: seed = seed кампании (CAMPAIGN_SEED).

@export var day_duration: float = 3.0

const CAMPAIGN_SEED: int = 12345  # I1: seed = seed кампании
var composition: CampaignComposition
var _day_timer: float = 0.0
var _is_day_cycle_active: bool = true

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager
@onready var day_label: Label = $CanvasLayer/DayLabel if has_node("CanvasLayer/DayLabel") else null


func _ready():
	_connect_ui()
	_init_campaign()
	GameLogger.info("Игра запущена. День: %d" % game_manager.get_current_day(), "Main")


## T-010 пост-условие: campaign-слой. Проводка систем, шов T-050, ledger
## Престижа, сборка сейва T-110 и победная оценка — в CampaignComposition
## (единый корень: раннер D-157 проверяет ту же игру, что видит игрок).
func _init_campaign() -> void:
	composition = CampaignComposition.from_campaign_config(CAMPAIGN_SEED)
	_consume_pending()


## Т-110-проводка (раунд 11 §1.2): (б) кампанийный сейв из Continue/Load →
## load_save_state (состояние систем восстанавливается); (а) профиль
## конструктора → партийный слот (K-M5/§7). Сейв приоритетнее: загрузка
## существующей кампании — профиль устаревший, очищаем.
func _consume_pending() -> void:
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	if persistence == null:
		return
	if not persistence.pending_campaign_save.is_empty():
		composition.load_save_state(persistence.pending_campaign_save)
		persistence.pending_campaign_save = {}
		persistence.pending_new_game = null
	elif persistence.pending_new_game != null:
		composition.set_hero_identity(persistence.pending_new_game.to_identity())
		persistence.pending_new_game = null


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
	# Ход кампании (T-010): settlement (авто) → player → threats (авто).
	# I1: сезон синхронизирован с ходом драйвера — внутри advance_turn().
	if composition != null:
		composition.advance_turn()
	if game_manager:
		game_manager.on_day_passed()
	if day_label:
		day_label.text = "День: %d" % game_manager.get_current_day()


func _on_day_passed(day: int):
	GameLogger.world("Наступил день %d" % day)


func _on_crisis_started(crisis_id: String):
	_is_day_cycle_active = false
	GameLogger.warn("КРИЗИС НАЧАЛСЯ: %s" % crisis_id, "Main")


func _on_crisis_ended(crisis_id: String, resolved: bool):
	_is_day_cycle_active = true
	GameLogger.info("Кризис завершен: %s" % ("успешно" if resolved else "провалено"), "Main")
