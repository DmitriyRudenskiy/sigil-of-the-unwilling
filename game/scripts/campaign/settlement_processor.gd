class_name SettlementProcessor
extends RefCounted
## T-040 — settlement-фаза кампании: stock/flow-экономика (K-D5), 3 ресурса (K-R2).
## Формулы — 06-economy (без изменений):
##   production(r) = Σ_zдания output_day × clamp(эффективность, 0.2, 2.5) × season_mult
##   consumption(еда) = k_pop × population + party_size × 1/день; дерево/железо — 0 (MVP)
##   B(r, t) = B(r, t−1) + production − consumption
##   population-кап (R3) = min(жильё, floor(продовольствие_в_неделю / 0.7))
##   рождения (K-M12) = k_pop × m(жильё) × m(еда) × m(настроение); MVP: все m = 1
## SM дефицита (06-economy): OK→WARN (B < 7 дней потребления); WARN→OK (B ≥ 7 дней);
##   WARN→DEFICIT (B ≤ 0); DEFICIT→OK (B > 0 три дня подряд); DEFICIT: производство 25% (12.2).
##   COLLAPSE — Post-MVP (не в MVP-SM).
## 1 ход = DAYS_PER_SEASON = 20 дней (Q-M26, 07-balance §2 — единственная конверсия).
## Миграция (F-3): формула — Репутация (T-116); MVP — no-op хук (репутация передаётся в контекст).
## I1: детерминизм — без ГСЧ, стабильный порядок, лог событий.

const RESOURCES: Array = ["food", "wood", "iron"]
const K_POP: float = 0.1  # еда/житель/день (06-economy, K-M12)
const UNIT_EAT: float = 1.0  # еда/юнит/день (06-economy: партия 1/день/юнит)
const FOOD_PER_RESIDENT_WEEK: float = 0.7  # R3: ед. продовольствия на жителя/нед.
const DAYS_PER_WEEK: int = 7
const EFFICIENCY_MIN: float = 0.2  # 07-balance §6
const EFFICIENCY_MAX: float = 2.5
const WARN_DAYS: float = 7.0  # SM: WARN при B < 7 дней потребления
const DEFICIT_PROD_MULT: float = 0.25  # DEFICIT: производство 25% (12.2)
const DEFICIT_RECOVER_DAYS: int = 3  # DEFICIT→OK: B > 0 три дня подряд
const SCHEMA_VERSION: int = 1

## Состояние (K-D5: state = stocks vector + производные).
var stocks: Dictionary = {"food": 0.0, "wood": 0.0, "iron": 0.0}
var population: int = 0
var housing: int = 0
var party_size: int = 0
## Здания: [{id: String, output_day: {food, wood, iron}, efficiency: float (дефолт 1.0)}].
var buildings: Array = []
## SM дефицита per resource: {state: "OK"/"WARN"/"DEFICIT", days_positive: int, days_negative: int}.
var sm: Dictionary = {}
## F-3 (T-116): миграционная формула — Репутация; MVP — no-op (хук для T-116).
var migration_hook: Callable
var _event_log: Array[String] = []


## Один ход settlement-фазы: DAYS_PER_SEASON дней. season_mult — из WorldSeasons
## (инжект, не глобальное чтение — I1/детерминизм). Возвращает детерминированный отчёт.
func process_turn(season_mult: float = 1.0) -> Dictionary:
	var days: int = WorldSeasons.DAYS_PER_SEASON
	var report := {
		"days": days,
		"production": {"food": 0.0, "wood": 0.0, "iron": 0.0},
		"consumption": {"food": 0.0, "wood": 0.0, "iron": 0.0},
		"events": [] as Array,
	}
	for i in days:
		_process_day(i + 1, season_mult, report)  # дни 1..DAYS_PER_SEASON (1-based, лог/отчёт)
	_end_of_turn(report)
	report["stocks"] = stocks.duplicate()
	report["population"] = population
	report["population_cap"] = _population_cap()
	report["sm"] = _sm_states()
	return report


func _process_day(day: int, season_mult: float, report: Dictionary) -> void:
	for r in RESOURCES:
		var prod: float = 0.0
		for b in buildings:
			var out: float = float(b.get("output_day", {}).get(r, 0.0))
			if out <= 0.0:
				continue
			var eff: float = clampf(float(b.get("efficiency", 1.0)), EFFICIENCY_MIN, EFFICIENCY_MAX)
			prod += out * eff * season_mult
		if _sm_state(r) == "DEFICIT":
			prod *= DEFICIT_PROD_MULT
		var cons: float = 0.0
		if r == "food":
			cons = K_POP * population + party_size * UNIT_EAT
		report["production"][r] += prod
		report["consumption"][r] += cons
		stocks[r] = float(stocks[r]) + prod - cons
		_update_sm(r, cons, day, report)


func _end_of_turn(report: Dictionary) -> void:
	# R3-кап + рождения (K-M12, MVP: все m = 1).
	var cap: int = _population_cap()
	var births: int = int(K_POP * float(WorldSeasons.DAYS_PER_SEASON))
	var prev_pop: int = population
	population = clampi(population + births, 0, cap)
	if population != prev_pop:
		_log("end_of_turn: population %d → %d (births %d, cap %d)" % [prev_pop, population, births, cap], report)
	# Миграция (F-3: формула — Репутация, T-116): MVP — no-op хук.
	if migration_hook.is_valid():
		migration_hook.call({"reputation": 0, "context": "end_of_turn", "population": population})


## R3: min(жильё, floor(продовольствие_в_неделю / 0.7)).
## продовольствие_в_неделю = базовое производство еды (без season_mult — стабильный кап).
func _population_cap() -> int:
	var weekly_food: float = 0.0
	for b in buildings:
		var out: float = float(b.get("output_day", {}).get("food", 0.0))
		var eff: float = clampf(float(b.get("efficiency", 1.0)), EFFICIENCY_MIN, EFFICIENCY_MAX)
		weekly_food += out * eff * float(DAYS_PER_WEEK)
	# +1e-6 — защита от float-представления (R3: floor; 14/0.7 = 20, не 19.999…)
	return mini(housing, int(weekly_food / FOOD_PER_RESIDENT_WEEK + 1e-6))


func _sm_state(r: String) -> String:
	return str(sm.get(r, {}).get("state", "OK"))


func _sm_states() -> Dictionary:
	var out := {}
	for r in RESOURCES:
		out[r] = _sm_state(r)
	return out


func _update_sm(r: String, cons: float, day: int, report: Dictionary) -> void:
	if not sm.has(r):
		sm[r] = {"state": "OK", "days_positive": 0, "days_negative": 0}
	var s: Dictionary = sm[r]
	var supply_days: float = float(stocks[r]) / cons if cons > 0.0 else INF
	var prev: String = s["state"]
	var next: String = prev
	match prev:
		"OK":
			if supply_days < WARN_DAYS:
				next = "WARN"
		"WARN":
			if float(stocks[r]) <= 0.0:
				next = "DEFICIT"
			elif supply_days >= WARN_DAYS:
				next = "OK"
		"DEFICIT":
			if float(stocks[r]) > 0.0:
				s["days_positive"] = int(s["days_positive"]) + 1
				if int(s["days_positive"]) >= DEFICIT_RECOVER_DAYS:
					next = "OK"
			else:
				s["days_positive"] = 0
				s["days_negative"] = int(s["days_negative"]) + 1
				# DEFICIT → COLLAPSE (B < 0 три дня подряд) — Post-MVP, в MVP-SM нет.
	if next != prev:
		s["state"] = next
		s["days_positive"] = 0
		s["days_negative"] = 0
		_log("day %d: %s %s→%s (B=%.1f)" % [day, r, prev, next, float(stocks[r])], report)


func _log(msg: String, report: Dictionary) -> void:
	_event_log.append(msg)
	report["events"].append(msg)

func event_log() -> Array[String]:
	return _event_log


## Сериализация (схема T-110: секции "resources"/"population"; schema_version — миграции).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"stocks": stocks.duplicate(),
		"population": population,
		"housing": housing,
		"party_size": party_size,
		"buildings": buildings.duplicate(true),
		"sm": sm.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SettlementProcessor:
	var p := SettlementProcessor.new()
	p.stocks = {"food": 0.0, "wood": 0.0, "iron": 0.0}
	for r in RESOURCES:
		p.stocks[r] = float(data.get("stocks", {}).get(r, 0.0))
	p.population = int(data.get("population", 0))
	p.housing = int(data.get("housing", 0))
	p.party_size = int(data.get("party_size", 0))
	p.buildings = data.get("buildings", []).duplicate(true)
	p.sm = data.get("sm", {}).duplicate(true)
	for r in RESOURCES:
		if not p.sm.has(r):
			p.sm[r] = {"state": "OK", "days_positive": 0, "days_negative": 0}
	return p
