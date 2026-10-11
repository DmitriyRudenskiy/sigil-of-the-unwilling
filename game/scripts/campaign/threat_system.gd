class_name ThreatSystem
extends RefCounted
## T-070 — фаза угроз кампании: функция давления (K-T5), аккумулятор города,
## волны тиров 1–3, динамические лагеря (D-130), SM рейда, директивы K-R3.
## MVP: 1 город → 1 аккумулятор. I1: детерминизм (seed = seed кампании,
## лексикографический порядок, лог событий).
##
## Давление (K-T5, 07-balance §5 — канон чисел):
##   pressure(city, t) = Base × Wealth × Anomalies × Region_History × Global_Phase
##   Wealth — видимое богатство (стопки); Global_Phase — фаза кампании
##   (конфиг, не календарь; границы — CR-фазовые якоря 07-balance §5).
## Аккумулятор (K-T5): каждый ход прибавляется pressure; пересечение порога
## тира (1–3) → генерация волны. Cooldown: после рейда аккумулятор → 0.
##
## Волна (T-070 AC): power = 15/30/60 (тиры 1/2/3, R6); loss = power × (1 − defense);
##   defense = 0.2 при казарме, иначе 0 (R6); target: слабейший запас —
##   argmin(stocks) по реестру K-R2, тай-брейк лексикографический (Q-M30 (б),
##   K-R3; веса 0.5/0.3/0.2 аннулированы в AC T-070 — 13-я итерация);
##   cap ≤30%/день на ресурс; герой в городе → бой (CR 1/2/6, шов T-050);
##   предупреждение — в хронике в ход генерации (day-1 на гранулярности хода).
##
## Лагеря (D-130): спавн при пересечении порога тира; сухие узлы в радиусе
##   k_p = 2 (взвешенные рёба графа смежности), обходя город/донжон/аномалию/
##   лагерь; тай-брейк — лексикографический ID (I1); tier = tier волны;
##   уничтожение — мини-донжон (шов T-050); после — региональный cooldown.
##
## SM рейда (02e4 §13.1): IDLE → CHARGING → INBOUND → STRIKE → RESOLVED
## → COOLDOWN → IDLE.
## Директивы (K-R3, не календарь): floor — первый рейд ≈ ход 7 (tutorial-тир,
## гарантирован); window — финальный тир гарантирован к ход 21.

const RESOURCES: Array = ["food", "wood", "iron"]  # K-R2
const BASE_PRESSURE: float = 4.0  # Base(city) — 07-balance §5
const WEALTH_PER_STOCK: float = 0.005  # Wealth = clamp(1 + 0.005 × стопки, 0.5, 2.0)
const WEALTH_MIN: float = 0.5
const WEALTH_MAX: float = 2.0
const ANOMALIES_MULT: float = 1.0  # MVP: системы аномалий нет (хук)
const REGION_HISTORY_GROWTH: float = 0.05  # после cooldown: 1 + 0.05 × ходов
const GLOBAL_PHASE_MULT: Dictionary = {1: 1.0, 2: 1.25, 3: 1.5, 21: 2.0}
const TIER_THRESHOLDS: Dictionary = {1: 30.0, 2: 100.0, 3: 250.0}  # K-T5 (§5)
const TIER_POWER: Dictionary = {1: 15.0, 2: 30.0, 3: 60.0}  # R6
const DEFENSE_BARRACKS: float = 0.2  # R6
const LOSS_CAP_FRACTION: float = 0.3  # cap ≤30%/день
const COOLDOWN_TURNS: int = 3  # K-T5
const ARRIVAL_TURNS: int = 1  # прибытие в следующую threats-фазу
const FIRST_RAID_FLOOR_TURN: int = 7  # floor (K-R3)
const FINAL_RAID_TURN: int = 21  # window (K-R3)
const CAMP_K_P: int = 2  # D-130
const SCHEMA_VERSION: int = 2  # v2: rng_state → campaign_seed (Q-M30 (б): цель — argmin, ГСЧ выведен)

const SM_IDLE := "IDLE"
const SM_CHARGING := "CHARGING"
const SM_INBOUND := "INBOUND"
const SM_STRIKE := "STRIKE"
const SM_RESOLVED := "RESOLVED"
const SM_COOLDOWN := "COOLDOWN"

var accumulator: float = 0.0
var region_cooldown: int = 0
var turns_since_last_raid: int = -1  # −1: рейдов не было
var wave: Dictionary = {}
var camps: Array = []  # [{id, tier, node}]
var raids_count: int = 0
var max_tier_raided: int = 0
var raid_state: String = SM_IDLE
## Инжект (I1): город, граф смежности {node: […]} (T-020), занятые узлы.
var city_node: String = "city"
var adjacency: Dictionary = {}
var occupied_nodes: Array[String] = []
var hero_in_city: bool = true
var has_barracks: bool = false

var campaign_seed: int  # I1 (seed кампании; бой наследует — T-050)
var _event_log: Array[String] = []


func _init(seed: int = 12345) -> void:
	campaign_seed = seed  # I1


func process_turn(turn: int, context: Dictionary = {}) -> Dictionary:
	var stocks: Dictionary = context.get("stocks", {})
	var barracks: bool = bool(context.get("has_barracks", has_barracks))
	var hero: bool = bool(context.get("hero_in_city", hero_in_city))
	var battle_handler: Callable = context.get("battle_handler", Callable())
	var report := {
		"turn": turn,
		"pressure": 0.0,
		"accumulator": 0.0,
		"raid_state": raid_state,
		"raid": {},
		"wave": wave.duplicate(),
		"events": [] as Array,
	}

	# 0. window (K-R3): финальный тир гарантирован к ход 21 (финальный рейд —
	# floor, тир 3). Финал переопределяет всё: активная волна и cooldown не
	# блокируют (иначе рейд на 20-м ходу заблокировал бы финал).
	if turn == FINAL_RAID_TURN and max_tier_raided < 3:
		wave = {}
		region_cooldown = 0
		accumulator = 0.0
		_spawn_wave(turn, 3, true, report, 0, stocks)
		report["raid"] = _strike_wave(turn, stocks, barracks, hero, battle_handler, report)
		report["wave"] = wave.duplicate()
		report["accumulator"] = 0.0
		return report

	# 1. Тики времени + cooldown (K-T5; SM: COOLDOWN → IDLE).
	if turns_since_last_raid >= 0:
		turns_since_last_raid += 1  # _strike_wave сбрасывает в 0 (после инкремента)
	if region_cooldown > 0:
		region_cooldown -= 1
		if region_cooldown == 0 and raid_state == SM_COOLDOWN:
			_set_state(SM_IDLE, turn, report)

	# 2. Активная волна: движение / удар.
	if not wave.is_empty():
		_set_state(SM_INBOUND, turn, report)
		wave["turns_to_arrival"] = int(wave["turns_to_arrival"]) - 1
		if int(wave["turns_to_arrival"]) <= 0:
			report["raid"] = _strike_wave(turn, stocks, barracks, hero, battle_handler, report)
		report["accumulator"] = accumulator
		report["wave"] = wave.duplicate()
		return report

	# 3. Давление (K-T5) + пересечение порога тира.
	if region_cooldown == 0:
		var pressure: float = compute_pressure(turn, stocks)
		report["pressure"] = pressure
		accumulator += pressure
		_set_state(SM_CHARGING, turn, report)
		for tier in [3, 2, 1]:
			if accumulator >= float(TIER_THRESHOLDS[tier]):
				_spawn_wave(turn, tier, false, report, ARRIVAL_TURNS, stocks)
				break

	# 4. floor (K-R3): первый рейд ≈ ход 7 (tutorial-тир, гарантирован).
	if turn == FIRST_RAID_FLOOR_TURN and raids_count == 0 and wave.is_empty() \
			and region_cooldown == 0:
		_spawn_wave(turn, 1, true, report, ARRIVAL_TURNS, stocks)

	report["accumulator"] = accumulator
	report["wave"] = wave.duplicate()
	return report


## Удар активной волны (STRIKE → RESOLVED → COOLDOWN; K-T5: аккумулятор → 0).
func _strike_wave(turn: int, stocks: Dictionary, barracks: bool, hero: bool,
		battle_handler: Callable, report: Dictionary) -> Dictionary:
	_set_state(SM_STRIKE, turn, report)
	var raid := _resolve_raid(turn, stocks, barracks, hero, battle_handler, report)
	_set_state(SM_RESOLVED, turn, report)
	accumulator = 0.0  # K-T5: после рейда аккумулятор → 0
	region_cooldown = COOLDOWN_TURNS
	turns_since_last_raid = 0
	_set_state(SM_COOLDOWN, turn, report)
	report["wave"] = {}
	wave = {}
	return raid


func compute_pressure(turn: int, stocks: Dictionary) -> float:
	var total_stocks: float = 0.0
	for r in RESOURCES:
		total_stocks += float(stocks.get(r, 0.0))
	var wealth: float = clampf(1.0 + WEALTH_PER_STOCK * total_stocks, WEALTH_MIN, WEALTH_MAX)
	return BASE_PRESSURE * wealth * ANOMALIES_MULT * _region_history() * _global_phase(turn)


func _region_history() -> float:
	if region_cooldown > 0:
		return 0.0
	if turns_since_last_raid < 0:
		return 1.0
	var after_cooldown: int = maxi(0, turns_since_last_raid - COOLDOWN_TURNS)
	return 1.0 + REGION_HISTORY_GROWTH * float(after_cooldown)


func _global_phase(turn: int) -> float:
	if turn >= 21:
		return float(GLOBAL_PHASE_MULT[21])
	if turn >= 14:
		return float(GLOBAL_PHASE_MULT[3])
	if turn >= 7:
		return float(GLOBAL_PHASE_MULT[2])
	return float(GLOBAL_PHASE_MULT[1])


## CR-диапазон по фазам (07-balance §5): 1 (1–6): ¼–1; 2 (7–13): 1–2;
## 3 (14–20): 2–4; ход 21: 6–8.
func cr_range(turn: int) -> Array:
	if turn >= 21:
		return [6, 8]
	if turn >= 14:
		return [2, 4]
	if turn >= 7:
		return [1, 2]
	return [0.25, 1]


func _spawn_wave(turn: int, tier: int, forced: bool, report: Dictionary,
		arrival: int = ARRIVAL_TURNS, stocks: Dictionary = {}) -> void:
	var target: String = _pick_target(stocks)
	var camp_id: String = _place_camp(tier, report)
	wave = {
		"tier": tier,
		"power": float(TIER_POWER[tier]),
		"target": target,
		"camp_id": camp_id,
		"turns_to_arrival": arrival,
		"forced": forced,
	}
	_set_state(SM_INBOUND, turn, report)
	var cause: String = "floor (K-R3)" if forced else "порог тира %d (K-T5)" % tier
	_log("ход %d: предупреждение — волна тира %d в пути (прибытие через %d ход(ов), %s)"
			% [turn, tier, arrival, cause], report)


## Цель рейда (Q-M30 (б), K-R3): слабейший запас = argmin(stocks) по реестру
## K-R2; при равенстве минимумов — лексикографический порядок ресурсов
## (I1-тай-брейк, прецедент лагерей). Чистая функция состояния: ГСЧ не нужен.
func _pick_target(stocks: Dictionary) -> String:
	var best: String = str(RESOURCES[0])
	var best_val: float = float(stocks.get(best, 0.0))
	for r in RESOURCES:
		var v: float = float(stocks.get(r, 0.0))
		if v < best_val or (is_equal_approx(v, best_val) and str(r) < best):
			best = str(r)
			best_val = v
	return best


## Размещение лагеря (D-130): BFS от города до глубины k_p = 2; сухие узлы
## (не город/донжон/аномалия/лагерь); ближайшая глубина, внутри —
## лексикографический ID (I1). MVP: BFS по хопам (юнит-веса); взвешенные рёба —
## при подключении графа T-020.
func _place_camp(tier: int, report: Dictionary) -> String:
	var occupied: Dictionary = {city_node: true}
	for n in occupied_nodes:
		occupied[n] = true
	for c in camps:
		occupied[str(c["node"])] = true
	var best: String = ""
	var visited: Dictionary = {city_node: true}
	var frontier: Array = [city_node]
	for _depth in range(CAMP_K_P):
		var next_frontier: Array = []
		var candidates: Array = []
		for node in frontier:
			for neighbor in adjacency.get(str(node), []):
				var n: String = str(neighbor)
				if visited.has(n):
					continue
				visited[n] = true
				next_frontier.append(n)
				if not occupied.has(n):
					candidates.append(n)
		if not candidates.is_empty():
			candidates.sort()  # лексикографический тай-брейк (I1)
			best = str(candidates[0])
			break
		frontier = next_frontier
	if best == "":
		best = "%s_unplaced" % city_node
		_log("лагерь без узла (граф не подключён, T-020), тир %d" % tier, report)
	var camp_id: String = "camp_%s" % best
	camps.append({"id": camp_id, "tier": tier, "node": best})
	_log("лагерь %s (тир %d) на узле %s (k_p=%d, D-130)"
			% [camp_id, tier, best, CAMP_K_P], report)
	return camp_id


func _resolve_raid(turn: int, stocks: Dictionary, barracks: bool, hero: bool,
		battle_handler: Callable, report: Dictionary) -> Dictionary:
	var tier: int = int(wave["tier"])
	var power: float = float(wave["power"])
	var target: String = str(wave["target"])
	var defense: float = DEFENSE_BARRACKS if barracks else 0.0
	var loss: float = power * (1.0 - defense)
	var before: float = float(stocks.get(target, 0.0))
	loss = minf(loss, LOSS_CAP_FRACTION * before)  # cap ≤30%/день
	stocks[target] = before - loss
	raids_count += 1
	max_tier_raided = maxi(max_tier_raided, tier)
	var result := {
		"turn": turn,
		"tier": tier,
		"power": power,
		"defense": defense,
		"target": target,
		"loss": loss,
		"cap_applied": loss < power * (1.0 - defense) - 1e-9,
		"battle_requested": false,
		"cr_range": cr_range(turn),
	}
	_log("ход %d: рейд тира %d — цель %s, урон %.1f (power %.0f, defense %.1f)%s"
			% [turn, tier, target, loss, power, defense,
				", cap 30%%" if result["cap_applied"] else ""], report)
	if hero:
		result["battle_requested"] = true
		_log("ход %d: герой в городе — бой (CR %s, шов T-050)" % [turn, str(cr_range(turn))], report)
		if battle_handler.is_valid():
			battle_handler.call({"turn": turn, "tier": tier, "cr_range": cr_range(turn),
				"power": power, "target": target, "loss": loss})
	else:
		_log("ход %d: героя нет — авто-рейд (R5)" % turn, report)
	return result


## Уничтожение лагеря — мини-донжон (шов T-050); после — региональный cooldown
## («лагеря помнят», D-130).
func destroy_camp(camp_id: String, report: Dictionary = {"events": []}) -> bool:
	for i in camps.size():
		if str(camps[i]["id"]) == camp_id:
			camps.remove_at(i)
			region_cooldown = COOLDOWN_TURNS
			if raid_state != SM_COOLDOWN:
				_set_state(SM_COOLDOWN, 0, report)
			_log("лагерь %s уничтожен — региональный cooldown %d ход(ов) (D-130)"
					% [camp_id, COOLDOWN_TURNS], report)
			return true
	return false


func _set_state(next: String, turn: int, report: Dictionary) -> void:
	if next == raid_state:
		return
	raid_state = next
	_log("ход %d: SM рейда → %s" % [turn, next], report)


func _log(msg: String, report: Dictionary) -> void:
	_event_log.append(msg)
	report["events"].append(msg)


func event_log() -> Array[String]:
	return _event_log


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"accumulator": accumulator,
		"region_cooldown": region_cooldown,
		"turns_since_last_raid": turns_since_last_raid,
		"wave": wave.duplicate(),
		"camps": camps.duplicate(true),
		"raids_count": raids_count,
		"max_tier_raided": max_tier_raided,
		"raid_state": raid_state,
		"city_node": city_node,
		"campaign_seed": campaign_seed,
	}


static func from_dict(data: Dictionary) -> ThreatSystem:
	var t := ThreatSystem.new(1)
	t.accumulator = float(data.get("accumulator", 0.0))
	t.region_cooldown = int(data.get("region_cooldown", 0))
	t.turns_since_last_raid = int(data.get("turns_since_last_raid", -1))
	t.wave = data.get("wave", {}).duplicate()
	t.camps = data.get("camps", []).duplicate(true)
	t.raids_count = int(data.get("raids_count", 0))
	t.max_tier_raided = int(data.get("max_tier_raided", 0))
	t.raid_state = str(data.get("raid_state", SM_IDLE))
	t.city_node = str(data.get("city_node", "city"))
	t.campaign_seed = int(data.get("campaign_seed", 1))
	return t
