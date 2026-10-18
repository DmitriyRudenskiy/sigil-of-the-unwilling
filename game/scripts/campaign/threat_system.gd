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
# Числа угрозы — raids.json (07-balance §5/§6 зеркало, T-115; K-M15 — не
# хардкод). Имена — snake_case-соответствие ключам конфига.
const RAIDS_CONFIG_PATH := "res://data/config/balance/raids.json"
var pressure_base: float = 4.0  # Base(city) — 07-balance §5
var wealth_per_stock: float = 0.005  # Wealth = clamp(1 + 0.005 × стопки, 0.5, 2.0)
var wealth_min: float = 0.5
var wealth_max: float = 2.0
var anomalies_mult: float = 1.0  # MVP: системы аномалий нет (хук)
var region_history_growth: float = 0.05  # после cooldown: 1 + 0.05 × ходов
var global_phase_mult: Dictionary = {1: 1.0, 2: 1.25, 3: 1.5, 21: 2.0}
var tier_thresholds: Dictionary = {1: 30.0, 2: 100.0, 3: 250.0}  # K-T5 (§5)
var tier_power: Dictionary = {1: 15.0, 2: 30.0, 3: 60.0}  # R6
var defense_barracks: float = 0.2  # R6
var loss_cap_fraction: float = 0.3  # дефолтный кап (ресурс не в loss_caps)
# Per-ресурсные капы за рейд (Q-M58→(в), D-189, T-127): еда ≤40%, железо/дерево ≤30%.
# Заменяет единый loss_cap_fraction = 0.3. Кап — per-рейд, не per-ход.
var loss_caps: Dictionary = {"food": 0.4, "wood": 0.3, "iron": 0.3}
var cooldown_turns: int = 3  # K-T5
var arrival_turns: int = 1  # прибытие в следующую threats-фазу
var camp_k_p: int = 2  # D-130
# Сезон (Q-M29): зима — каждый 4-й ход, enemy_mult 1.25; финал — без бонуса.
var season_length: int = 4
var winter_index: int = 3  # (turn − 1) mod 4 == 3
var enemy_mult_winter: float = 1.25
var final_turn_no_bonus: int = 21
# Сценарные директивы (raids.json, биты 1:1): first_raid/floor, strong_raid/
# window, district, final_raid (boss). Словарь {id: {turn, type, tier_num, ...}}.
var directives: Dictionary = {}
const SCHEMA_VERSION: int = 2  # v2 — текущая: rng_state → campaign_seed (Q-M30 (б): цель — argmin, ГСЧ выведен);
# v1 — только загрузка: rng_state игнорируется (в v2 нет ГСЧ), campaign_seed по умолчанию 1.

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
	_load_raids_config()


func process_turn(turn: int, context: Dictionary = {}) -> Dictionary:
	var stocks: Dictionary = context.get("stocks", {})
	var barracks: bool = bool(context.get("has_barracks", has_barracks))
	var hero: bool = bool(context.get("hero_in_city", hero_in_city))
	var all_ruined: bool = bool(context.get("all_districts_destroyed", false))
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

	# 0. Финальный floor (K-R3, директива final:true в raids.json) переопределяет
	# всё: активная волна и cooldown не блокируют (иначе рейд на 20-м ходу
	# заблокировал бы финал).
	for d in _directives_for(turn):
		if str(d.get("type", "")) == "floor" and bool(d.get("boss", d.get("final", false))) \
				and max_tier_raided < int(d.get("tier_num", 3)):
			wave = {}
			region_cooldown = 0
			accumulator = 0.0
			_spawn_wave(turn, int(d.get("tier_num", 3)), true, report, 0, stocks,
					str(d.get("composition", "boss")))
			report["raid"] = _strike_wave(turn, stocks, barracks, hero, all_ruined, battle_handler, report)
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

	# 2. Активная волна: движение / удар. Директивы — до удара: естественная
	# волна, прибывающая в ход директивы, повышается (бит 17 не съедается).
	if not wave.is_empty():
		_apply_bit_directives(turn, report, stocks, false)
		_set_state(SM_INBOUND, turn, report)
		wave["turns_to_arrival"] = int(wave["turns_to_arrival"]) - 1
		if int(wave["turns_to_arrival"]) <= 0:
			report["raid"] = _strike_wave(turn, stocks, barracks, hero, all_ruined, battle_handler, report)
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
			if accumulator >= float(tier_thresholds[tier]):
				_spawn_wave(turn, tier, false, report, arrival_turns, stocks)
				break

	# 4. Сценарные директивы (raids.json — биты 1:1, K-R3): floor — первый рейд
	# гарантирован (tutorial ≈ ход 7); window — тир директивы гарантирован к
	# ходу (strong_raid — ход 17). district — не рейд (календарный триггер
	# K-M1, city-слой).
	_apply_bit_directives(turn, report, stocks, true)

	report["accumulator"] = accumulator
	report["wave"] = wave.duplicate()
	return report


## Удар активной волны (STRIKE → RESOLVED → COOLDOWN; K-T5: аккумулятор → 0).
## all_ruined (raid-pressure 2.2): все районы разрушены → cooldown ×2
## (частота рейдов −50%); город выживает, floor-директивы не ломаются (K-R3).
func _strike_wave(turn: int, stocks: Dictionary, barracks: bool, hero: bool,
		all_ruined: bool, battle_handler: Callable, report: Dictionary) -> Dictionary:
	_set_state(SM_STRIKE, turn, report)
	var raid := _resolve_raid(turn, stocks, barracks, hero, battle_handler, report)
	_set_state(SM_RESOLVED, turn, report)
	accumulator = 0.0  # K-T5: после рейда аккумулятор → 0
	region_cooldown = effective_cooldown(all_ruined)
	turns_since_last_raid = 0
	_set_state(SM_COOLDOWN, turn, report)
	report["wave"] = {}
	wave = {}
	return raid


## raid-pressure 2.2 (K-R3): cooldown ×2 при «все районы разрушены»
## (частота рейдов −50%); иначе базовый cooldown_turns.
func effective_cooldown(all_ruined: bool) -> int:
	return cooldown_turns * 2 if all_ruined else cooldown_turns


func compute_pressure(turn: int, stocks: Dictionary) -> float:
	var total_stocks: float = 0.0
	for r in RESOURCES:
		total_stocks += float(stocks.get(r, 0.0))
	var wealth: float = clampf(1.0 + wealth_per_stock * total_stocks, wealth_min, wealth_max)
	return pressure_base * wealth * anomalies_mult * _region_history() * _global_phase(turn)


func _region_history() -> float:
	if region_cooldown > 0:
		return 0.0
	if turns_since_last_raid < 0:
		return 1.0
	var after_cooldown: int = maxi(0, turns_since_last_raid - cooldown_turns)
	return 1.0 + region_history_growth * float(after_cooldown)


func _global_phase(turn: int) -> float:
	if turn >= 21:
		return float(global_phase_mult[21])
	if turn >= 14:
		return float(global_phase_mult[3])
	if turn >= 7:
		return float(global_phase_mult[2])
	return float(global_phase_mult[1])


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
		arrival: int, stocks: Dictionary = {}, composition: String = "") -> void:
	var target: String = _pick_target(stocks)
	var camp_id: String = _place_camp(tier, report)
	wave = {
		"tier": tier,
		# Q-M29: зимний enemy_mult к силе волны (финальный ход — без бонуса).
		"power": float(tier_power[tier]) * _enemy_mult(turn),
		"target": target,
		"camp_id": camp_id,
		"turns_to_arrival": arrival,
		"forced": forced,
		# K-R3 директива composition (словарь): цель — слабейший сток.
		"composition": composition if composition != "" else "weakest_stock",
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
	for _depth in range(camp_k_p):
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
			% [camp_id, tier, best, camp_k_p], report)
	return camp_id


## Per-ресурсный кап за рейд (Q-M58→(в), D-189, T-127): еда 0.4, остальное 0.3.
## Ресурс не в loss_caps → дефолт loss_cap_fraction.
func loss_cap_for(resource: String) -> float:
	return float(loss_caps.get(resource, loss_cap_fraction))


func _resolve_raid(turn: int, stocks: Dictionary, barracks: bool, hero: bool,
		battle_handler: Callable, report: Dictionary) -> Dictionary:
	var tier: int = int(wave["tier"])
	var power: float = float(wave["power"])
	var target: String = str(wave["target"])
	var defense: float = defense_barracks if barracks else 0.0
	var loss: float = power * (1.0 - defense)
	var before: float = float(stocks.get(target, 0.0))
	loss = minf(loss, loss_cap_for(target) * before)  # per-ресурсный кап (Q-M58→(в))
	var cap_applied: bool = loss < power * (1.0 - defense) - 1e-9
	# raid-pressure 2.3: рейд по клетке героя → бой; победа → −50% последствий.
	# Бой — до применения урона (исход определяет размер урона).
	var battle_won: bool = false
	if hero and battle_handler.is_valid():
		var outcome: String = str(battle_handler.call({"turn": turn, "tier": tier,
			"cr_range": cr_range(turn), "target": target, "loss": loss}))
		battle_won = (outcome == "win")
	if battle_won:
		loss = loss * 0.5  # победа героя → −50% последствий рейда
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
		"cap_applied": cap_applied,
		"battle_requested": hero,
		"battle_won": battle_won,
		"cr_range": cr_range(turn),
	}
	_log("ход %d: рейд тира %d — цель %s, урон %.1f (power %.0f, defense %.1f)%s%s"
			% [turn, tier, target, loss, power, defense,
				", cap %.0f%%" % (loss_cap_for(target) * 100.0) if cap_applied else "",
				", бой: победа → −50%" if battle_won else ""], report)
	if hero:
		_log("ход %d: герой в городе — бой (CR %s, шов T-050)" % [turn, str(cr_range(turn))], report)
	else:
		_log("ход %d: героя нет — авто-рейд (R5)" % turn, report)
	return result


## Уничтожение лагеря — мини-донжон (шов T-050); после — региональный cooldown
## («лагеря помнят», D-130).
func destroy_camp(camp_id: String, report: Dictionary = {"events": []}) -> bool:
	for i in camps.size():
		if str(camps[i]["id"]) == camp_id:
			camps.remove_at(i)
			region_cooldown = cooldown_turns
			if raid_state != SM_COOLDOWN:
				_set_state(SM_COOLDOWN, 0, report)
			_log("лагерь %s уничтожен — региональный cooldown %d ход(ов) (D-130)"
					% [camp_id, cooldown_turns], report)
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


## Зимний enemy_mult (Q-M29): сезон = 4 хода, зима — индекс 3 ((turn−1) mod 4);
## финальный ход — без бонуса (сложность финала — тир волны, K-T5).
func _enemy_mult(turn: int) -> float:
	if turn == final_turn_no_bonus:
		return 1.0
	if (turn - 1) % season_length == winter_index:
		return enemy_mult_winter
	return 1.0


## Сценарные директивы хода (raids.json; 0/несколько на ход).
func _directives_for(turn: int) -> Array:
	var out: Array = []
	for k in directives:
		var d: Dictionary = directives[k]
		if int(d.get("turn", -1)) == turn:
			out.append(d)
	return out


## Сценарные директивы битов (K-R3): floor — первый рейд гарантирован;
## window — тир директивы гарантирован к биту. Недостаточная волна в пути
## повышается (лагерь сохраняется); спавн — только при allow_spawn и пустой
## волне. Гарантии сильнее cooldown: cooldown дозирует естественные волны,
## а не сценарные директивы (бит 17 не «съедается» рейдом на 15-м).
func _apply_bit_directives(turn: int, report: Dictionary, stocks: Dictionary,
		allow_spawn: bool) -> void:
	for d in _directives_for(turn):
		var kind: String = str(d.get("type", ""))
		if kind == "district" or bool(d.get("boss", d.get("final", false))):
			continue
		var d_tier: int = int(d.get("tier_num", 1))
		var satisfied: bool = (raids_count > 0) if kind == "floor" \
				else (max_tier_raided >= d_tier)
		if satisfied:
			continue
		var comp: String = str(d.get("composition", ""))
		if not wave.is_empty():
			if int(wave.get("tier", 0)) >= d_tier:
				continue
			wave["tier"] = d_tier
			wave["power"] = float(tier_power[d_tier]) * _enemy_mult(turn)
			wave["forced"] = true
			if comp != "":
				wave["composition"] = comp
			report["wave"] = wave.duplicate()
			continue
		if not allow_spawn:
			continue
		region_cooldown = 0
		_spawn_wave(turn, d_tier, true, report, arrival_turns, stocks, comp)


static func _num_keys(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[int(str(k))] = float(src[k])
	return out


## T-115: числа угрозы — raids.json (07-balance §5/§6 зеркало). Конфиг —
## источник; значения по умолчанию выше — только fallback при отсутствии файла.
func _load_raids_config() -> void:
	if not FileAccess.file_exists(RAIDS_CONFIG_PATH):
		return
	var f := FileAccess.open(RAIDS_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var cfg: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(cfg) != TYPE_DICTIONARY:
		return
	var pr: Dictionary = cfg.get("pressure", {})
	pressure_base = float(pr.get("base", pressure_base))
	wealth_per_stock = float(pr.get("wealth_per_stock", wealth_per_stock))
	wealth_min = float(pr.get("wealth_min", wealth_min))
	wealth_max = float(pr.get("wealth_max", wealth_max))
	anomalies_mult = float(pr.get("anomalies_mult", anomalies_mult))
	region_history_growth = float(pr.get("region_history_growth", region_history_growth))
	if pr.get("global_phase", {}) != {}:
		global_phase_mult = _num_keys(pr.get("global_phase", {}))
	var tiers: Dictionary = cfg.get("tiers", {})
	tier_thresholds = _num_keys(tiers.get("thresholds", tier_thresholds))
	tier_power = _num_keys(tiers.get("power", tier_power))
	defense_barracks = float(cfg.get("defense_barracks", defense_barracks))
	# Дефолтный кап — loss_cap_per_day (raids.json); per-ресурсные — loss_caps
	# (Q-M58→(в), D-189, T-127): еда 0.4, железо/дерево 0.3.
	loss_cap_fraction = float(cfg.get("loss_cap_per_day", loss_cap_fraction))
	var caps: Dictionary = cfg.get("loss_caps", {})
	if caps != {}:
		loss_caps = caps.duplicate()
	cooldown_turns = int(cfg.get("cooldown_turns", cooldown_turns))
	arrival_turns = int(cfg.get("arrival_turns", arrival_turns))
	camp_k_p = int(cfg.get("camp_k_p", camp_k_p))
	var season: Dictionary = cfg.get("season", {})
	season_length = int(season.get("length", season_length))
	winter_index = int(season.get("winter_index", winter_index))
	enemy_mult_winter = float(season.get("enemy_mult_winter", enemy_mult_winter))
	final_turn_no_bonus = int(season.get("final_turn_no_bonus", final_turn_no_bonus))
	directives = cfg.get("directives", directives)


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
