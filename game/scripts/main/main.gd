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
var last_battle_report: Dictionary = {}
var _recruit_uid_counter: int = 1  # реестр жителей — счётчик (T-116 остеклит)
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
	# T-116: модель населения (источник истины population); k_pop — population.json
	# (K-M12: 0.1/день; D-161: конфиг прочитан, версия — 1.0).
	var pop_config: Dictionary = CitizenRegistry.load_config()
	settlement.k_pop_per_day = float(pop_config.get("k_pop_per_day", 0.1))
	settlement.registry = CitizenRegistry.new()
	settlement.registry.create_initial(20)  # T-001: население 20
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
	# T-122 (Q-M31): settlement — население/события (без production);
	# production-расчёт — отдельный хук ПОСЛЕ threats (GDD-мандат §1).
	campaign.settlement_hook = func() -> Dictionary:
		return settlement.process_settlement()
	campaign.threats_hook = func() -> Dictionary:
		return threats.process_turn(campaign.current_turn, _threat_context())
	campaign.production_hook = func() -> Dictionary:
		return settlement.process_production(WorldSeasons.production_mult())
	# F-3 (T-116): миграция — Репутация (единственный вход, Э1-3); MVP — no-op
	# (Q-M32: формула TBD). Хук процессора → registry-сеам.
	settlement.migration_hook = func(ctx: Dictionary) -> void:
		settlement.registry.apply_migration(float(ctx.get("reputation", 0)))


func _threat_context() -> Dictionary:
	return {
		"stocks": settlement.stocks,  # ссылка: урон рейда — в стопки поселения
		"has_barracks": false,  # MVP: казармы нет (T-030-слой)
		"hero_in_city": true,  # фаза игрока решает (MVP: герой в городе)
		"battle_handler": _request_battle,
	}


## Шов T-050 (акт 12-й итерации §2.2): бой K-канона — единичные комбатанты,
## лестница 02d, без RNG. Статблоки — баланс-конфиг (K-M15, числа — T-041).
## battle_report обязателен к {losses: [character_uid]} и эмитится в хук
## населения с дня первого боя (потребитель зреет до T-116).
func _request_battle(context: Dictionary) -> void:
	if campaign == null or campaign.is_done():
		return
	campaign.request_battle(context)
	var blocks := _load_statblocks()
	if blocks.is_empty():
		return  # статблоков нет (баланс-конфиг) — бой не разрешается
	var tier: int = int(context.get("tier", 1))
	var hero := CampaignBattle.make_recruit(
		blocks.get("warrior", {}), _recruit_uid_counter)
	var raider := CampaignBattle.make_combatant(
		blocks.get("raider_tier_%d" % tier, blocks.get("raider_final", {})))
	raider["id"] = "raider_t%d" % tier
	raider["character_uid"] = -1  # рейдер — не житель (потерь населению нет)
	last_battle_report = CampaignBattle.resolve(hero, raider, _on_battle_losses)
	GameLogger.info("бой: %s за %d раунд(ов), потери %s"
		% [last_battle_report.get("outcome", "?"),
			last_battle_report.get("rounds", 0),
			str(last_battle_report.get("losses", []))], "Main")


## Хук населения (§2.2, T-116): потери боя — вычитание жителей по
## character_uid (T-050 шов); раненые — не потери (CampaignBattle: losses —
## только dead; стабилизированный — ранен, в losses не попадает).
## Эмит с дня первого боя, даже пустой.
func _on_battle_losses(losses: Array, _report: Dictionary) -> void:
	if losses.is_empty():
		return
	var removed: int = settlement.registry.apply_losses(losses)
	settlement.population = settlement.registry.count()  # зеркало (источник — registry)
	_recruit_uid_counter += losses.size()
	GameLogger.info("население: потери %s (вычтено %d)" % [str(losses), removed], "Main")


func _load_statblocks() -> Dictionary:
	var f := FileAccess.open("res://data/config/balance/campaign.json", FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data.get("unit_statblocks", {})


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
	# Ход кампании (T-010, T-122): 6 фаз GDD-мандата §1 (Q-M31):
	# settlement (население/события) → player (движение) → caravans (no-op)
	# → diplomacy (no-op) → threats (бой/рейды) → production (расчёт).
	# I1: сезон синхронизирован с ходом драйвера — до settlement-хука.
	if campaign != null and not campaign.is_done():
		WorldSeasons.set_turns(campaign.current_turn)
		campaign.advance_auto_phase()  # settlement (авто) → player
		campaign.end_player_phase()    # player → caravans (MVP: авто)
		campaign.advance_auto_phase()  # caravans (no-op) → diplomacy
		campaign.advance_auto_phase()  # diplomacy (no-op) → threats
		campaign.advance_auto_phase()  # threats (авто) → production
		campaign.advance_auto_phase()  # production (авто) → finish
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
