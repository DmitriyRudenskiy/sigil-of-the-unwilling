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
const DISTRICTS_JSON := "res://data/config/balance/districts.json"
const ETHICS_JSON := "res://data/config/balance/ethics.json"
const SIGNS_JSON := "res://data/signs.json"
## campaign-core-loop 2.1: глаголы действия (spec: build/train/move/fight;
## GDD 01-core-loop «Цикл 5 минут»: двинул/решил/построил/снабдил + тренировка).
const ACTION_VERBS := ["build", "train", "move", "fight"]

var campaign: TurnDriver
var settlement: SettlementProcessor
var threats: ThreatSystem
var population_system: PopulationSystem
## T-020/T-021/T-022: регион-граф (MVP-маска S1, movement.json): туман, движение
## по рёбрам, SM героя, one-time loot. Секция сейва "map" → "region".
var region_map: RegionMap
## T-030: районный слой (7 групп, настроение, рабочие, нужды).
var districts: DistrictSystem
var district_config: Dictionary = {}
var district_jobs_by_id: Dictionary = {}
## T-124 Ф4-MVP «этический минимум»: журнал, сверка (ходы 10/20), Репутация.
var ethics: EthicsSystem
var ethics_config: Dictionary = {}
var sign_vectors: Dictionary = {}
## Престиж = ledger (K-M16): записи {turn, source_type, id, amount};
## сальдо — производная, в сейве не хранится (T-110).
var prestige_ledger: Array = []
var last_battle_report: Dictionary = {}
## campaign-core-loop 2.1–2.4: телеметрия лог сессии (GDD 01-core-loop).
## Дизайн-решение #2: события → лог сессии, отчёт — post-hoc (playtest);
## лог — артефакт сессии, НЕ часть сейва. I1: метка времени = ход кампании.
var telemetry: TelemetryLog
## campaign-core-loop 2.2: флаги полного цикла за ход (loop_closed).
## Сбрасываются в конце хода; действия UI между ходами копятся в них.
var _loop_flags: Dictionary = {}
## Отчёт threats-фазы текущего хода (2.2: «увидел угрозу» = рейд ударил).
var last_threat_report: Dictionary = {}
## Победная оценка (T-117 якорь: ход 21 = финальный рейд отражён/нет).
var final_battle_seen: bool = false
var final_raid_repelled: bool = false
## T-060: ростер партии (R1/R2): [{id, class, race, level, xp, stats{}, luck,
## state?, uid?}]. Пусто до T-003 (старт: fighter+ranger) и тренировки
## (CampaignTrainingService — проводка с городским UI, E-5).
var party: Array = []
## Проводка T-110 (cutover, раунд 6): имя героя из создания (pending_new_game);
## sign-слой (что несёт Знак) — за MVP-срезом (T-020).
var hero_name: String = ""
## T-002 «Выбор знака»: id Знака кампании (Signs: spark/time/balance/primal/
## shadow/harmony/cycle/basis); "" — не выбран (вне UI-пути). Сейв-секция "sign".
var sign_id: String = ""
## signs-prestige 2.1/2.2 (T-129): SM знака + фракционные действия.
## sign_id — дублирует sign_system.sign_id (созвместимость с существующим кодом).
var sign_system: SignSystem
## party-characters 3.2 (R7, Q-M75→(б), P-4): снабжение героя — еда в походе.
## Ёмкость 10; расход 1/персонаж/переход; полный (>50%) → +2 к 1-му спасу;
## голод (0) → −2 к атакам. Числа — campaign.json → supply (K-M15).
var supply_system: SupplySystem
var _boss_prestige_given: bool = false
var _statblocks: Dictionary = {}
var _victory_sources: Dictionary = {}
var _ranks: Array = []
var _rank_names: Dictionary = {}


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
	_rank_names = prestige.get("rank_names", {}) as Dictionary
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
	# T-030: районный слой — конфиг districts.json (K-M15) + jobs из каталога зданий.
	district_config = _json(DISTRICTS_JSON)
	district_jobs_by_id = _district_jobs()
	districts = DistrictSystem.new(district_config, district_jobs_by_id)
	# T-124: этический слой — журнал/сверка/Репутация (числа — ethics.json, K-M15).
	ethics_config = _json(ETHICS_JSON)
	sign_vectors = EthicsSystem.load_sign_vectors(_json(SIGNS_JSON))
	ethics = EthicsSystem.new_for_sign(sign_id, ethics_config)
	# signs-prestige 2.1/2.2: SM знака + фракционные действия (≤12, prestige.json).
	sign_system = SignSystem.new()
	sign_system.faction_actions_max = int(prestige.get("faction_actions_max", 12))
	# party-characters 3.2: снабжение героя — еда в походе (R7, Q-M75→(б), P-4).
	# Числа — campaign.json → supply (K-M15); старт с полным запасом.
	supply_system = SupplySystem.from_config(scenario)
	# T-116: реестр жителей — источник истины населения (R2: старт 20).
	population_system = PopulationSystem.new()
	population_system.seed_population(settlement.population)
	# T-003 (R2): стартовая партия — fighter 1 + ranger 1, ур.1 (02-mechanics §3.2).
	# Расы — humans (дефолт; фактические расы/имена старта — с городским UI, остаток T-003).
	# Stats проходят гейты классов (02d §4.2): fighter any(STR≥13), ranger all(DEX≥13, WIS≥13).
	party = [
		{"id": "start_fighter", "class": "fighter", "race": "humans", "level": 1,
		 "xp": 0, "luck": 0,
		 "stats": {"str": 14, "dex": 12, "con": 12, "int": 10, "wis": 10, "cha": 10}},
		{"id": "start_ranger", "class": "ranger", "race": "humans", "level": 1,
		 "xp": 0, "luck": 0,
		 "stats": {"str": 10, "dex": 14, "con": 12, "int": 10, "wis": 14, "cha": 10}},
	]
	# V-5 (D-220): персистентный HP — инициализация полей (max_hp/current_hp).
	for _m in party:
		PartySystem.ensure_hp(_m)
	settlement.party_size = PartySystem.alive_members(party).size()
	campaign.settlement_hook = func() -> Dictionary:
		# V-5 (D-220, D3): REST в городе — живые → max_hp, WOUNDED → READY
		# (DEAD не восстанавливаются). Шов: герой в походе → REST в этом
		# ходу нет → урон переносится между боями.
		if region_map != null and region_map.hero_region == region_map.start_region:
			PartySystem.rest(party)
		# T-122 (Q-M31): settlement-фаза — население/события/настроение (позиция 1);
		# production-расчёт — вынесен в production-фазу (позиция 6, post-threats).
		# T-124: сверка на ходах 10/20 (в начале settlement-фазы — покрывает события
		# от последней сверки; бои текущего хода уходят в следующий интервал).
		# F-3/T-124: миграция — единственный вход Репутация (Э1-3: Престиж — никогда).
		var ethics_rep: Dictionary = {}
		if ethics.needs_reconcile(campaign.current_turn):
			ethics_rep = ethics.reconcile(campaign.current_turn, sign_vectors)
		settlement.reputation = ethics.reputation
		var rep_report: Dictionary = settlement.process_settlement()
		if not ethics_rep.is_empty():
			rep_report["ethics_reconcile"] = ethics_rep
		# Ростерь — источник истины: возраста/смерти/рождения/миграция (F-3;
		# T-124: Репутация — источник миграции (была константа 0)).
		var pop_report: Dictionary = population_system.process_turn(
			WorldSeasons.DAYS_PER_SEASON, float(ethics.reputation),
			int(rep_report.get("population_cap", -1)))
		settlement.population = population_system.size()
		# T-030: районный проход (рабочие/вакансии, нужды, настроение, дезертирство).
		# Дезертирство — счёт в отчёт (канал миграции F-3/T-116: MVP no-op хук,
		# ростерь в MVP не трогает); настроение множит производство (×0.85/×1.10).
		rep_report["districts"] = districts.process_turn(
			settlement.buildings, settlement.population, settlement.party_size,
			str((settlement.sm.get("food", {}) as Dictionary).get("state", "OK")))
		rep_report["population"] = pop_report
		return rep_report
	campaign.threats_hook = func() -> Dictionary:
		var rep := threats.process_turn(campaign.current_turn, _threat_context())
		last_threat_report = rep  # 2.2: «увидел угрозу» (рейд этого хода)
		return rep
	# T-122 (Q-M31): production — позиция 6 (post-threats): рейды бьют
	# pre-production запасы. season_mult — из WorldSeasons (I1: инжест).
	campaign.production_hook = func() -> Dictionary:
		return settlement.process_production(WorldSeasons.production_mult())
	# T-071 (R5): victory — пережить рейд хода 21 при любом запасе > 0.
	# Предикат инжестится в драйвер (TurnDriver не знает про сток); вызов —
	# в конце хода 21 при статусе ongoing (defeat/wipe блокирует раньше, D-190).
	campaign.victory_check_hook = func() -> bool:
		return _any_stock_positive()
	# T-020/T-021: регион-граф — MVP-маска S1 (movement.json), герой в городе (R01).
	# Запас партии на переход — 0 (пополнение из стока поселения — с UI, остаток T-021);
	# headless: герой в городе (авто-рейд на него не ведётся — R5).
	region_map = RegionMap.new()
	region_map.init_campaign(PartySystem.alive_members(party).size(), 0.0)
	# player-фаза: тик времени герой-слоя (авто-режим 2 дня → возврат в город, Y10).
	campaign.player_hook = func() -> void:
		region_map.tick_days(1)
	# campaign-core-loop 2.1: старт сессии — TTFD меряется от game_start
	# до первого action (GDD 01-core-loop).
	telemetry = TelemetryLog.new()
	telemetry.record("game_start", {"turn": 1})


## Один ход кампании (T-010, T-122): фиксированный 6-фазный порядок
## (GDD-мандат §1, Q-M31): settlement (авто) → player → caravans (no-op) →
## diplomacy (no-op) → threats (авто) → production (авто). post-MVP-фазы —
## каркас-слоты (T-010-состав). I1: сезон синхронизирован с ходом драйвера
## — до settlement-хука.
func advance_turn() -> void:
	if campaign.is_done():
		return
	if telemetry != null:
		telemetry.set_turn(campaign.current_turn)  # 2.1: кампанийное время (I1)
	# T-060: снабжение партии — выбранные едят 1 еду/день (02-mechanics §3.2;
	# MVP: пул = партия, резерв — Post-MVP). Синхронизация до settlement-фазы.
	settlement.party_size = PartySystem.alive_members(party).size()
	WorldSeasons.set_turns(campaign.current_turn)
	campaign.advance_auto_phase()  # settlement (авто) → player
	campaign.end_player_phase()    # player → caravans (MVP: авто, no-op)
	campaign.advance_auto_phase()  # caravans (no-op) → diplomacy (no-op)
	campaign.advance_auto_phase()  # diplomacy (no-op) → threats
	campaign.advance_auto_phase()  # threats (авто) → production
	_evaluate_loop_closed()        # 2.2: цикл хода N (после рейда, до production)
	campaign.advance_auto_phase()  # production (авто) → finish


## campaign-core-loop 2.1: действие игрока (UI → сюда; headless — авто-fight
## в _request_battle). Событие `action{type, choice_count}` в лог сессии
## (GDD 01-core-loop). type — глагол из ACTION_VERBS; choice_count — число
## осмысленных опций (≥2 = «решение» в метрике decision ratio).
func record_action(verb: String, choice_count: int = 1) -> void:
	if telemetry == null:
		return
	if not ACTION_VERBS.has(verb):
		push_warning("CampaignComposition: неизвестный глагол действия: %s" % verb)
		return
	telemetry.record("action", {
		"turn": campaign.current_turn,
		"type": verb,
		"choice_count": maxi(0, int(choice_count)),
	})
	_loop_flags["acted"] = true


## campaign-core-loop 2.2: герой покинул город (UI → сюда, остаток T-021).
## Флаг «поход» для loop_closed (поход → возврат к концу хода).
func record_expedition() -> void:
	_loop_flags["expedition"] = true


## campaign-core-loop 2.3: replan_after_tooltip — перепланировка после
## подсказки «почему так?» (aha-момент, GDD 01-core-loop). Триггер — UI
## (deferred, не headless-верифицируемо); событие и API готовы.
func record_replan_after_tooltip() -> void:
	if telemetry == null:
		return
	telemetry.record("replan_after_tooltip", {"turn": campaign.current_turn})


## campaign-core-loop 2.2: loop_closed — полный цикл за ход (GDD 01-core-loop
## «Цикл сессии»): увидел угрозу (рейд ударил) → решил (действие игрока)
## → поход (герой покинул город) → возврат (герой в городе к концу хода)
## → пережил рейд (кампания ongoing). Headless: без игрока флаги не копятся
## (авто-fight даёт acted, но expedition не ставится) → событие не fires
## (дизайн-решение #2: метрики — за телеметрией, не за симуляцией).
func _evaluate_loop_closed() -> void:
	if telemetry == null:
		return
	var raid := _raid_happened_this_turn()
	var hero_home := region_map == null \
		or region_map.hero_region == region_map.start_region
	var acted := bool(_loop_flags.get("acted", false))
	var expedition := bool(_loop_flags.get("expedition", false))
	if acted and expedition and raid and hero_home \
			and campaign.campaign_status == "ongoing":
		telemetry.record("loop_closed", {
			"turn": campaign.current_turn,
			"raid": true, "acted": true, "expedition": true,
		})
	_loop_flags = {}  # флаги следующего хода (действия UI между ходами)


## 2.2: рейд ударил в этом ходу (threats-фаза) — «увидел угрозу».
func _raid_happened_this_turn() -> bool:
	return not (last_threat_report.get("raid", {}) as Dictionary).is_empty()


func _threat_context() -> Dictionary:
	return {
		"stocks": settlement.stocks,  # ссылка: урон рейда — в стопки поселения
		"has_barracks": _has_barracks(),  # T-030: казарма из зданий поселения
		# T-020: герой в городе (R01) → бой (CR 1/2/6); в походе → авто-рейд (R5).
		"hero_in_city": region_map == null
			or region_map.hero_region == region_map.start_region,
		# raid-pressure 2.2 (K-R3): все районы разрушены → cooldown ×2 (город выживает).
		"all_districts_destroyed": _all_districts_destroyed(),
		"battle_handler": _request_battle,
	}


## raid-pressure 2.2 (K-R3): «все районы разрушены» = все 7 канон-групп без
## зданий (AFK-каскад: город выживает, cooldown ×2, production −50%).
func _all_districts_destroyed() -> bool:
	var present: Dictionary = {}
	for b in settlement.buildings:
		if b is Dictionary:
			present[str((b as Dictionary).get("group", ""))] = true
	for g in SettlementProcessor.GROUPS:
		if present.has(str(g)):
			return false
	return true


## T-071 (R5): условие victory — любой запас поселения > 0 (K-R2-реестр
## ресурсов). Сток — после production-фазы хода 21 (рейды бьют pre-production
## запасы, T-122; production ход 21 — в итог).
func _any_stock_positive() -> bool:
	for r in ThreatSystem.RESOURCES:
		if float(settlement.stocks.get(r, 0.0)) > 0.0:
			return true
	return false


## Шов T-050 (акт 12-й итерации §2.2): бой K-канона — единичные комбатанты,
## лестница 02d, без RNG. Статблоки — баланс-конфиг (K-M15, числа — T-041).
## raid-pressure 2.3: возвращает исход боя ("win"/"lose"/"draw") — победа героя
## снижает последствия рейда на 50% (читает threat_system через battle_handler).
func _request_battle(context: Dictionary) -> String:
	if campaign == null or campaign.is_done():
		return ""
	campaign.request_battle(context)
	# campaign-core-loop 2.1: глагол fight — MVP: авто-оборона (choice_count 1,
	# не «решение» в метрике decision ratio).
	record_action("fight", 1)
	if _statblocks.is_empty():
		return ""  # статблоков нет (баланс-конфиг) — бой не разрешается
	var tier: int = int(context.get("tier", 1))
	# V-5 (D-220, D1): герой боя = первый живой член ростера (детерминированно).
	# character_uid — uid самого героя (житель), либо −1 (только-ростерный
	# член — потерь населению нет; двойной смерти не возникает, условие 2).
	var hero_member: Dictionary = {}
	var alive: Array = PartySystem.alive_members(party)
	if not alive.is_empty():
		hero_member = alive[0]
	var hero_uid: int = int(hero_member.get("uid", -1))
	var hero := CampaignBattle.make_recruit(
		_statblocks.get("warrior", {}), hero_uid)
	# V-5 (D-220): бой начинается с текущим current_hp (живой: кламп ≥ 1).
	if not hero_member.is_empty():
		hero["hp"] = maxi(int(hero_member.get("current_hp", int(hero["hp"]))), 1)
		hero["max_hp"] = int(hero_member.get("max_hp", int(hero["max_hp"])))
	# party-characters 3.2 / campaign-core-loop 3.2 (P-4): голод (0 еды) →
	# −2 к атакам; штраф из SupplySystem, держится до resupply в городе.
	hero["hunger_penalty"] = supply_system.attack_penalty()
	# dnd-battle-ladder 4.2 (02d §4): Удача — пул ОУ = 1 + modLuck; MVP-бой —
	# авто-режим, политика Удачи героя (детерминистичная, K2): Save / Fate
	# Shift. Рейдер (враг) Удачу не тратьёт (сценарии спека — про игрока).
	hero["auto_luck"] = true
	var raider_spec: Dictionary = _statblocks.get(
		"raider_tier_%d" % tier, _statblocks.get("raider_final", {}))
	var raider := CampaignBattle.make_combatant(raider_spec)
	raider["id"] = "raider_t%d" % tier
	raider["character_uid"] = -1  # рейдер — не житель (потерь населению нет)
	# parity_le_0.8 (T-041, разморозка): бой «против превосходящих» —
	# CR героя ≤ 0.8 × CR рейдера (cr — в статблоках, K-M15/cr_anchors;
	# make_combatant cr не несёт — читается из спека).
	var parity: bool = float(_statblocks.get("warrior", {}).get("cr", 0)) \
		<= 0.8 * float(raider_spec.get("cr", 0))
	last_battle_report = CampaignBattle.resolve(hero, raider, _on_battle_losses)
	# V-5 (D-220): результат героя → член партии (персистентный HP / WOUNDED /
	# DEAD). До apply_party_battle_losses: uid-механизм не дублирует смерть
	# (apply_losses пропускает уже DEAD).
	if not hero_member.is_empty():
		PartySystem.apply_battle_result(
			hero_member, int(hero.get("hp", 0)), bool(hero.get("dead", false)))
		# party_size = живые (инвариант party_screen_model): смерть героя с
		# uid −1 не попадает в losses — синк здесь, не только в apply_losses.
		settlement.party_size = PartySystem.alive_members(party).size()
		# V-5 (R1): конец = wipe партии. Смерть героя с uid −1 обходит
		# apply_party_battle_losses (losses пуст) — проверка здесь (defeat()
		# идемпотентен: повторный вызов — no-op).
		if PartySystem.is_wiped(party):
			campaign.defeat("party_wiped")
	# T-060: партия — XP (после боя, 02-mechanics §3.2 EC3) и потери
	# (R1: wipe = DEFEAT; сейв и Престиж сохраняются).
	record_party_xp(last_battle_report, float(raider_spec.get("cr", 0.0)))
	apply_party_battle_losses(last_battle_report)
	# party-characters 3.1 (K-M10): Ветеран — счётчик пережитых боёв (после
	# потерь: павшие в этом бою неincrement-ятся; статус → +1 ступень в T-116).
	PartySystem.record_battle_survival(party)
	if tier >= 3:  # финальный рейд (raids.json final_raid: tier 3, босс K-R3)
		final_battle_seen = true
		final_raid_repelled = str(last_battle_report.get("outcome", "")) == "win"
		if final_raid_repelled:
			districts.apply_event_to_all("raid_repelled")  # +5/район (02g §5)
	# T-124: бои MVP — оборона поселения; победа → Резонанс, победа с Долгом
	# судьбы (trace.debt > 0 у героя) → метка «свобода/риск» (ось Свобода).
	if str(last_battle_report.get("outcome", "")) == "win":
		ethics.record_defense_win(campaign.current_turn)
		if _report_has_fate_debt(last_battle_report, str(hero.get("id", ""))):
			ethics.record_fate_debt_win(campaign.current_turn)
	_record_battle_prestige(context, last_battle_report, parity)
	return str(last_battle_report.get("outcome", ""))


static func _report_has_fate_debt(report: Dictionary, hero_id: String) -> bool:
	for t in report.get("trace", []):
		if int(t.get("debt", 0)) > 0 and str(t.get("actor", "")) == hero_id:
			return true
	return false


## T-060 (07-balance §3): XP партии — бой `100×CR×(1+0.1n)` (только победа:
## ничья = опыт 0, 07-balance §4/D-128; MVP 1v1 → n=1) + «рейд пережит» 300
## (outcome != "lose": город пережил рейд; MVP-прокси выживания партии —
## боевой слой 1v1, партия в бою — за срезом). Начисляется всем живым членам
## (якорь K-M13 «ход 21 = 5×ур.5» — командный пейсинг).
func record_party_xp(report: Dictionary, raider_cr: float) -> void:
	var alive := PartySystem.alive_members(party)
	if alive.is_empty():
		return
	var outcome := str(report.get("outcome", ""))
	var xp := 0
	if outcome == "win":
		xp += PartySystem.xp_from_battle(raider_cr, 1)
	if outcome != "lose":
		xp += PartySystem.raid_survived_xp()
	if xp <= 0:
		return
	for member in alive:
		PartySystem.grant_xp(member, xp)


## T-060 (R1): потери боя → партия (совпадение по uid жителя или id члена).
## Wipe — конец кампании (DEFEAT); повторный вызов после DONE — no-op.
func apply_party_battle_losses(report: Dictionary) -> void:
	var losses: Array = report.get("losses", [])
	if losses.is_empty():
		return
	PartySystem.apply_losses(party, losses)
	settlement.party_size = PartySystem.alive_members(party).size()
	if PartySystem.is_wiped(party):
		campaign.defeat("party_wiped")


## Хук населения (§2.2): потери боя списывают конкретных жителей по
## character_uid (раненые — не потери); скаляр settlement синхронизируется
## с ростерью (источник истины — T-116).
func _on_battle_losses(losses: Array, _report: Dictionary) -> void:
	if losses.is_empty():
		return
	# T-124: потери защитника → метка Диссонанса (журнал этики, отдельная секция).
	ethics.record_losses(campaign.current_turn)
	population_system.apply_battle_losses(losses)
	settlement.population = population_system.size()


## Престиж-ledger (K-M16, prestige.json sources.battle_victory; числа — из
## конфига, K-M15). parity_le_0.8 — разморожен T-041 (CR в статблоках).
func _record_battle_prestige(context: Dictionary, report: Dictionary, parity: bool = false) -> void:
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
	if parity:
		_add_ledger(turn, "parity_t%d" % tier, float(mods.get("parity_le_0.8", 0)))
	if tier >= 3 and not _boss_prestige_given:
		_boss_prestige_given = true
		_add_ledger(turn, "boss_final", float(mods.get("boss_once_per_campaign", 0)))


func _add_ledger(turn: int, id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	prestige_ledger.append({
		"turn": turn, "source_type": "battle_victory", "id": id, "amount": amount,
	})
	_sign_system_prestige_sync()


## ---- T-110: сборка секций кампании (контракт MvpSaveSchema) ----
## Только входные величины; производные (saldо Престижа, скаляр population)
## не храним — пересчёт при загрузке. Угрозы — секция "map" (регион/узлы:
## лагеря, волна, состояние рейдов).

func build_save_state() -> Dictionary:
	var campaign_section: Dictionary = campaign.to_dict()
	campaign_section["final_battle_seen"] = final_battle_seen
	campaign_section["final_raid_repelled"] = final_raid_repelled
	campaign_section["hero_name"] = hero_name
	# T-124: журнал/аккумуляторы/Репутация — состояние (события не пересчитываются
	# при загрузке, I1); секция словарная — schema_version не тронут (T-110).
	campaign_section["ethics"] = ethics.to_dict()
	# party-characters 3.2: снабжение героя (еда в походе) — под-ключ секции
	# "campaign" (не топ-уровневая секция: старая схема валидирует только
	# известные топ-секции; под-ключ не ломает минимальные тест-состояния).
	campaign_section["supply"] = supply_system.to_dict()
	var state := {
		"campaign": campaign_section,
		"resources": settlement.stocks.duplicate(),
		"population": population_system.to_dict(),
		"party": party.duplicate(true),  # T-060: партия — состояние (R1); схема party = TYPE_ARRAY
		"city": {
			"housing": settlement.housing,
			"buildings": settlement.buildings.duplicate(true),
			"sm": settlement.sm.duplicate(true),
			"party_size": settlement.party_size,
			# T-030: настроение районов — состояние (не производная), в сейве.
			"districts": districts.to_dict(),
		},
		"map": {"threats": threats.to_dict(), "region": region_map.to_dict()},  # T-020: регион-граф
		"prestige": {"ledger": prestige_ledger.duplicate(true)},
		"sign": _sign_save_section(),
	}
	# Нормализация int→float: JSON round-trip теряет тип int (числа → float);
	# нормализуем при сборке — сейв байтово равен roundtrip-у (контракт T-110).
	return _to_json_types(state)


## Секция сейва "sign": sign_id (composition, источник истины) + состояние
## SignSystem (SM, фракционные действия). Backward compat: ключ "id".
func _sign_save_section() -> Dictionary:
	var section: Dictionary = {"id": sign_id}
	if sign_system != null:
		# Синхронизация: sign_id (composition) — источник истины.
		sign_system.sign_id = sign_id
		var ss := sign_system.to_dict()
		for k in ss.keys():
			if k != "sign_id":  # sign_id уже в "id"
				section[k] = ss[k]
	return section


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
	hero_name = str(state.get("campaign", {}).get("hero_name", ""))
	# signs-prestige 2.1/2.2: SM знака + фракционные действия (секция "sign").
	# Backward compat: старый сейв {id} → sign_id; новый {sign_id, state, ...}.
	var sign_data: Dictionary = state.get("sign", {})
	if not sign_data.has("sign_id") and sign_data.has("id"):
		sign_data["sign_id"] = sign_data["id"]
	sign_system = SignSystem.from_dict(sign_data)
	sign_id = sign_system.sign_id
	# party-characters 3.2: снабжение героя (под-ключ "supply" секции "campaign");
	# старый сейв без него → старт с полным запасом (ёмкость из конфига).
	var supply_cfg: Dictionary = _json(CAMPAIGN_JSON)
	var supply_data: Dictionary = (state.get("campaign", {}) as Dictionary).get("supply", {})
	if supply_data.is_empty():
		supply_system = SupplySystem.from_config(supply_cfg)
	else:
		supply_system = SupplySystem.from_dict(supply_data)
	# Синхронизация SM с балансом (старый сейв: баланс > 0 → ACTIVE).
	if sign_system.sign_id != "":
		_sign_system_prestige_sync()
	final_battle_seen = bool(state.get("campaign", {}).get("final_battle_seen", false))
	final_raid_repelled = bool(state.get("campaign", {}).get("final_raid_repelled", false))
	population_system = PopulationSystem.from_dict(state.get("population", {}))
	party = (state.get("party", []) as Array).duplicate(true)  # T-060
	# T-110: level — производная от xp (пересчёт на загрузке; T-060/K-M13).
	for member in party:
		if member is Dictionary:
			member["level"] = PartySystem.level_for_xp(int(member.get("xp", 0)))
			# V-5 (D-220): миграция персистентного HP (идемпотентная; старый
			# сейв без current_hp → полный; DEAD — не воскрешаем).
			PartySystem.ensure_hp(member)
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
	# T-020: регион-граф — секция "map".region (старый сейв без неё → старт R01).
	region_map = RegionMap.from_dict((state.get("map", {}) as Dictionary).get("region", {}))
	# T-030: районный слой — конфиг/каталог те же (сейв хранит только настроение).
	district_config = _json(DISTRICTS_JSON)
	district_jobs_by_id = _district_jobs()
	districts = DistrictSystem.from_dict(
		city.get("districts", {}), district_config, district_jobs_by_id)
	prestige_ledger = (state.get("prestige", {}) as Dictionary).get("ledger", []).duplicate(true)
	_boss_prestige_given = false
	for e in prestige_ledger:
		if str(e.get("id", "")) == "boss_final":
			_boss_prestige_given = true
	# T-124: этический слой — нет секции (старый сейв) → дефолты (Репутация 0).
	ethics_config = _json(ETHICS_JSON)
	sign_vectors = EthicsSystem.load_sign_vectors(_json(SIGNS_JSON))
	ethics = EthicsSystem.from_dict(
		(state.get("campaign", {}) as Dictionary).get("ethics", {}), ethics_config)
	ethics.sign_id = sign_id
	settlement.reputation = ethics.reputation


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


## T-030: jobs здания → слоты рабочих. Источник — каталог campaign_building_catalog;
## стартовые id (farm/sawmill/mine) вне каталога — jobs_fallback из districts.json.
func _district_jobs() -> Dictionary:
	var jobs := {}
	for b in CampaignBuildingCatalog.load_catalog().get("buildings", []):
		if int(b.get("jobs", 0)) > 0:
			jobs[str(b.get("id", ""))] = int(b["jobs"])
	for k in (district_config.get("jobs_fallback", {}) as Dictionary).keys():
		jobs[str(k)] = int(district_config["jobs_fallback"][k])
	return jobs


## T-002/T-124: выбор Знака — одна точка входа (знак несёт и этический референс).
## signs-prestige 2.1: DORMANT→ACTIVE (выбор); один знак на носителя (инвариант).
func set_sign(id: String) -> void:
	if sign_system != null:
		sign_system.select_sign(id)
		sign_id = sign_system.sign_id
	else:
		sign_id = id
	if ethics != null:
		ethics.sign_id = sign_id


## Престиж-сальдо (производная: sum ledger; T-110: не хранится в сейве).
func prestige_balance() -> int:
	var balance := 0.0
	for e in prestige_ledger:
		balance += float(e.get("amount", 0.0))
	return int(balance)


## Престиж-ранг (индекс 0..4: Безымянный/Знаемый/Почитаемый/Славный/Легендарный).
## Падение ниже порога = понижение (K-M16).
func prestige_rank() -> int:
	var balance := prestige_balance()
	var rank := 0
	for i in _ranks.size():
		if balance >= int(_ranks[i]):
			rank = i
	return rank


## Престиж-титул (имя ранга из prestige.json rank_names).
func prestige_rank_name() -> String:
	var rank := prestige_rank()
	var key := str(int(_ranks[rank])) if rank < _ranks.size() else "0"
	return str(_rank_names.get(key, "Безымянный"))


## signs-prestige 2.2: фракционное действие знака (≤12, штраф стиля за повтор).
## Возвращает amount (0 если: SLEEPING/DORMANT, лимит исчерпан, повтор).
func perform_sign_action(id: String, amount: float) -> float:
	if sign_system == null:
		return 0.0
	var granted := sign_system.perform_faction_action(id, int(amount), campaign.current_turn)
	if granted > 0:
		_add_ledger(campaign.current_turn, "faction_%s" % id, float(granted))
		_sign_system_prestige_sync()
	return float(granted)


## SM знака: синхронизация с балансом Престижа (ACTIVE→SLEEPING при ≤0).
func _sign_system_prestige_sync() -> void:
	if sign_system != null:
		sign_system.on_prestige_changed(prestige_balance())


func _has_barracks() -> bool:
	for b in settlement.buildings:
		if str(b.get("id", "")).contains("barracks"):
			return true
	return false


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}
