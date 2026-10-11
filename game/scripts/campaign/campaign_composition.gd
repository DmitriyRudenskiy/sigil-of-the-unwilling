class_name CampaignComposition
extends RefCounted
## Composition root кампейн-слоя (T-010 пост-условие; T-117 раннер; T-110 сборка).
## Единая проводка для main.gd и cutover-композита (D-157): TurnDriver +
## SettlementProcessor + ThreatSystem + PopulationSystem + шов T-050 +
## Престиж-ledger (prestige.json sources) + сборка секций сейва + победная
## оценка. Проводка живёт здесь ОДНАЖДЫ — раннер проверяет ту же игру, что
## видит игрок (анти-дубль composition root).
## I1: ни ГСЧ сверх seed кампании; одинаковые вводные → байт-идентичное состояние.

const CAMPAIGN_JSON := "res://data/config/balance/campaign.json"
const PRESTIGE_JSON := "res://data/config/balance/prestige.json"

var campaign: TurnDriver
var settlement: SettlementProcessor
var threats: ThreatSystem
var population_system: PopulationSystem
## Престиж = ledger (K-M16): записи {turn, source_type, id, amount};
## сальдо — производная, в сейве не хранится (T-110).
var prestige_ledger: Array = []
var last_battle_report: Dictionary = {}
## Победная оценка (T-117 якорь: ход 21 = финальный рейд отражён/нет).
var final_battle_seen: bool = false
var final_raid_repelled: bool = false
var _boss_prestige_given: bool = false
var _statblocks: Dictionary = {}
var _victory_sources: Dictionary = {}
var _ranks: Array = []


static func from_campaign_config(campaign_seed: int) -> CampaignComposition:
	var c := CampaignComposition.new()
	c._build(campaign_seed)
	return c


func _build(campaign_seed: int) -> void:
	WorldSeasons.reset()
	var scenario := _json(CAMPAIGN_JSON)
	_statblocks = scenario.get("unit_statblocks", {})
	var prestige := _json(PRESTIGE_JSON)
	_victory_sources = prestige.get("sources", {}).get("battle_victory", {})
	_ranks = prestige.get("ranks", [])
	campaign = TurnDriver.new()
	campaign.seed = campaign_seed
	# T-117: стартовое состояние — сценарий campaign.json (R2), не хардкод.
	settlement = SettlementProcessor.new()
	var start: Dictionary = scenario.get("start_state", {})
	var res: Dictionary = start.get("resources", {})
	settlement.stocks = {
		"food": float(res.get("food", 30)),
		"wood": float(res.get("wood", 20)),
		"iron": float(res.get("iron", 10)),
	}
	settlement.population = int(start.get("population", 20))
	settlement.housing = int(start.get("housing", 20))
	settlement.buildings = [
		{"id": "farm", "group": "Земледельцы и Пивовары",
			"output_day": {"food": 1.0}, "efficiency": 1.0},
		{"id": "sawmill", "group": "Инженеры и Строители",
			"output_day": {"wood": 0.5}, "efficiency": 1.0},
		{"id": "mine", "group": "Металлурги и Техники",
			"output_day": {"iron": 0.25}, "efficiency": 1.0},
	]
	threats = ThreatSystem.new(campaign_seed)
	# T-116: реестр жителей — источник истины населения (R2: старт 20).
	population_system = PopulationSystem.new()
	population_system.seed_population(settlement.population)
	campaign.settlement_hook = func() -> Dictionary:
		# T-122 (Q-M31): settlement-фаза — население/события/настроение (позиция 1);
		# production-расчёт — вынесен в production-фазу (позиция 6, post-threats).
		var rep_report: Dictionary = settlement.process_settlement()
		# Ростерь — источник истины: возраста/смерти/рождения/миграция (F-3;
		# Репутация MVP — 0, источник-производная Резонанса — слой за тикетом).
		var pop_report: Dictionary = population_system.process_turn(
			WorldSeasons.DAYS_PER_SEASON, 0.0,
			int(rep_report.get("population_cap", -1)))
		settlement.population = population_system.size()
		rep_report["population"] = pop_report
		return rep_report
	campaign.threats_hook = func() -> Dictionary:
		return threats.process_turn(campaign.current_turn, _threat_context())
	# T-122 (Q-M31): production — позиция 6 (post-threats): рейды бьют
	# pre-production запасы. season_mult — из WorldSeasons (I1: инжест).
	campaign.production_hook = func() -> Dictionary:
		return settlement.process_production(WorldSeasons.production_mult())


## Один ход кампании (T-010, T-122): фиксированный 6-фазный порядок
## (GDD-мандат §1, Q-M31): settlement (авто) → player → caravans (no-op) →
## diplomacy (no-op) → threats (авто) → production (авто). post-MVP-фазы —
## каркас-слоты (T-010-состав). I1: сезон синхронизирован с ходом драйвера
## — до settlement-хука.
func advance_turn() -> void:
	if campaign.is_done():
		return
	WorldSeasons.set_turns(campaign.current_turn)
	campaign.advance_auto_phase()  # settlement (авто) → player
	campaign.end_player_phase()    # player → caravans (MVP: авто, no-op)
	campaign.advance_auto_phase()  # caravans (no-op) → diplomacy (no-op)
	campaign.advance_auto_phase()  # diplomacy (no-op) → threats
	campaign.advance_auto_phase()  # threats (авто) → production
	campaign.advance_auto_phase()  # production (авто) → finish


func _threat_context() -> Dictionary:
	return {
		"stocks": settlement.stocks,  # ссылка: урон рейда — в стопки поселения
		"has_barracks": false,  # MVP: казармы нет (T-030-слой)
		"hero_in_city": true,  # фаза игрока решает (MVP: герой в городе)
		"battle_handler": _request_battle,
	}


## Шов T-050 (акт 12-й итерации §2.2): бой K-канона — единичные комбатанты,
## лестница 02d, без RNG. Статблоки — баланс-конфиг (K-M15, числа — T-041).
func _request_battle(context: Dictionary) -> void:
	if campaign == null or campaign.is_done():
		return
	campaign.request_battle(context)
	if _statblocks.is_empty():
		return  # статблоков нет (баланс-конфиг) — бой не разрешается
	var tier: int = int(context.get("tier", 1))
	var hero := CampaignBattle.make_recruit(
		_statblocks.get("warrior", {}), population_system.conscript())
	var raider := CampaignBattle.make_combatant(
		_statblocks.get("raider_tier_%d" % tier, _statblocks.get("raider_final", {})))
	raider["id"] = "raider_t%d" % tier
	raider["character_uid"] = -1  # рейдер — не житель (потерь населению нет)
	last_battle_report = CampaignBattle.resolve(hero, raider, _on_battle_losses)
	if tier >= 3:  # финальный рейд (raids.json final_raid: tier 3, босс K-R3)
		final_battle_seen = true
		final_raid_repelled = str(last_battle_report.get("outcome", "")) == "win"
	_record_battle_prestige(context, last_battle_report)


## Хук населения (§2.2): потери боя списывают конкретных жителей по
## character_uid (раненые — не потери); скаляр settlement синхронизируется
## с ростерью (источник истины — T-116).
func _on_battle_losses(losses: Array, _report: Dictionary) -> void:
	if losses.is_empty():
		return
	population_system.apply_battle_losses(losses)
	settlement.population = population_system.size()


## Престиж-ledger (K-M16, prestige.json sources.battle_victory; числа — из
## конфига, K-M15). ponytail: parity_le_0.8 не начисляется — parity требует CR
## в статблоках (T-041), не молча: пропуск зафиксирован тестом состава ledger.
func _record_battle_prestige(context: Dictionary, report: Dictionary) -> void:
	if str(report.get("outcome", "")) != "win":
		return
	var turn := int(context.get("turn", campaign.current_turn))
	var tier := int(context.get("tier", 1))
	var mods: Dictionary = _victory_sources.get("modifiers", {})
	_add_ledger(turn, "raid_t%d" % tier, float(_victory_sources.get("base", 0)))
	if (report.get("losses", []) as Array).is_empty():
		_add_ledger(turn, "no_losses_t%d" % tier, float(mods.get("no_losses", 0)))
	if tier >= 2:
		_add_ledger(turn, "camp_tier_ge_2_t%d" % tier, float(mods.get("camp_tier_ge_2", 0)))
	if tier >= 3 and not _boss_prestige_given:
		_boss_prestige_given = true
		_add_ledger(turn, "boss_final", float(mods.get("boss_once_per_campaign", 0)))


func _add_ledger(turn: int, id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	prestige_ledger.append({
		"turn": turn, "source_type": "battle_victory", "id": id, "amount": amount,
	})


## ---- T-110: сборка секций кампании (контракт MvpSaveSchema) ----
## Только входные величины; производные (saldо Престижа, скаляр population)
## не храним — пересчёт при загрузке. Угрозы — секция "map" (регион/узлы:
## лагеря, волна, состояние рейдов).

func build_save_state() -> Dictionary:
	var campaign_section: Dictionary = campaign.to_dict()
	campaign_section["final_battle_seen"] = final_battle_seen
	campaign_section["final_raid_repelled"] = final_raid_repelled
	var state := {
		"campaign": campaign_section,
		"resources": settlement.stocks.duplicate(),
		"population": population_system.to_dict(),
		"party": [],  # партия героя — вне MVP-среза (R1: 1 герой, не 5)
		"city": {
			"housing": settlement.housing,
			"buildings": settlement.buildings.duplicate(true),
			"sm": settlement.sm.duplicate(true),
			"party_size": settlement.party_size,
		},
		"map": {"threats": threats.to_dict()},
		"prestige": {"ledger": prestige_ledger.duplicate(true)},
		"sign": {},  # состояние Знака (R1) — слой T-020
	}
	# Нормализация int→float: JSON round-trip теряет тип int (числа → float);
	# нормализуем при сборке — сейв байтово равен roundtrip-у (контракт T-110).
	return _to_json_types(state)


static func _to_json_types(value: Variant) -> Variant:
	if value is Dictionary:
		var d := {}
		for k in (value as Dictionary).keys():
			d[k] = _to_json_types((value as Dictionary)[k])
		return d
	if value is Array:
		var arr: Array = []
		for e in value as Array:
			arr.append(_to_json_types(e))
		return arr
	if value is int:  # float(int) точен для целых сейва (uid/turn/housing)
		return float(value)
	return value


func load_save_state(state: Dictionary) -> void:
	campaign = TurnDriver.from_dict(state.get("campaign", {}))
	final_battle_seen = bool(state.get("campaign", {}).get("final_battle_seen", false))
	final_raid_repelled = bool(state.get("campaign", {}).get("final_raid_repelled", false))
	population_system = PopulationSystem.from_dict(state.get("population", {}))
	var city: Dictionary = state.get("city", {})
	settlement = SettlementProcessor.from_dict({
		"stocks": state.get("resources", {}),
		"housing": city.get("housing", 0),
		"buildings": city.get("buildings", []),
		"sm": city.get("sm", {}),
		"party_size": city.get("party_size", 0),
		# population — производная ростери (T-110: не храним), восстанавливаем:
		"population": population_system.size(),
	})
	threats = ThreatSystem.from_dict(state.get("map", {}).get("threats", {}))
	prestige_ledger = (state.get("prestige", {}) as Dictionary).get("ledger", []).duplicate(true)
	_boss_prestige_given = false
	for e in prestige_ledger:
		if str(e.get("id", "")) == "boss_final":
			_boss_prestige_given = true


## Победная оценка MVP-среза (campaign.json scenario.victory): якорь «ход 21 =
## финальный рейд отражён/нет» + Престиж-якорь по ledger («Почитаемый» —
## ranks[2]..ranks[3], числа prestige.json, K-M15). Достижение коридора —
## калибровка T-041; здесь — детерминированная оценка, не настройка чисел.
func victory_assessment() -> Dictionary:
	var balance := 0.0
	for e in prestige_ledger:
		balance += float(e.get("amount", 0.0))
	var lo: float = float(_ranks[2]) if _ranks.size() > 2 else 0.0
	var hi: float = float(_ranks[3]) if _ranks.size() > 3 else lo
	return {
		"campaign_done": campaign.is_done(),
		"final_battle_seen": final_battle_seen,
		"final_raid_repelled": final_raid_repelled,
		"prestige_balance": balance,
		"prestige_anchor_met": balance >= lo and balance < hi,
		"victory": final_raid_repelled,
	}


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}
