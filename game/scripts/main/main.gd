extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

## Главная сцена игры - координирует менеджеры и игровой цикл.
## T-010 пост-условие (12-я итерация): campaign-слой (TurnDriver +
## SettlementProcessor + ThreatSystem) — composition root; каждый тик дня =
## 1 ход кампании. I1: seed = seed кампании (CAMPAIGN_SEED).

@export var day_duration: float = 3.0

const CAMPAIGN_SEED: int = 12345  # I1: seed = seed кампании
var campaign: TurnDriver
var settlement: SettlementProcessor
var threats: ThreatSystem
var _day_timer: float = 0.0
var _is_day_cycle_active: bool = true

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager
@onready var day_label: Label = $CanvasLayer/DayLabel if has_node("CanvasLayer/DayLabel") else null


func _ready():
	_connect_ui()
	_init_campaign()
	GameLogger.info("Игра запущена. День: %d" % game_manager.get_current_day(), "Main")


## T-010 пост-условие: campaign-слой. Т001: старт (еда 30, дерево 20, железо 10,
## население 20); housing 20 (T-030, Q-M28); здания — 7 групп (02e3 §9.4).
func _init_campaign() -> void:
	WorldSeasons.reset()
	campaign = TurnDriver.new()
	campaign.seed = CAMPAIGN_SEED
	settlement = SettlementProcessor.new()
	settlement.stocks = {"food": 30.0, "wood": 20.0, "iron": 10.0}
	settlement.population = 20
	settlement.housing = 20
	settlement.buildings = [
		{"id": "farm", "group": "Земледельцы и Пивовары",
			"output_day": {"food": 1.0}, "efficiency": 1.0},
		{"id": "sawmill", "group": "Инженеры и Строители",
			"output_day": {"wood": 0.5}, "efficiency": 1.0},
		{"id": "mine", "group": "Металлурги и Техники",
			"output_day": {"iron": 0.25}, "efficiency": 1.0},
	]
	threats = ThreatSystem.new(CAMPAIGN_SEED)
	campaign.settlement_hook = func() -> Dictionary:
		return settlement.process_turn(WorldSeasons.production_mult())
	campaign.threats_hook = func() -> Dictionary:
		return threats.process_turn(campaign.current_turn, _threat_context())


func _threat_context() -> Dictionary:
	return {
		"stocks": settlement.stocks,  # ссылка: урон рейда — в стопки поселения
		"has_barracks": false,  # MVP: казармы нет (T-030-слой)
		"hero_in_city": true,  # фаза игрока решает (MVP: герой в городе)
		"battle_handler": _request_battle,
	}


func _request_battle(context: Dictionary) -> void:
	# Шов к T-050 (бой-слой): TurnDriver.request_battle.
	if campaign != null and not campaign.is_done():
		campaign.request_battle(context)


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
	# I1: сезон синхронизирован с ходом драйвера — до settlement-хука.
	if campaign != null and not campaign.is_done():
		WorldSeasons.set_turns(campaign.current_turn)
		campaign.advance_auto_phase()  # settlement (авто) → player
		campaign.end_player_phase()    # player → threats (MVP: авто)
		campaign.advance_auto_phase()  # threats (авто) → finish
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
