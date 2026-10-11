class_name PopulationSystem
extends RefCounted
## T-116 — реестр жителей города (остекление счётчика uid из main.gd).
## Числа — data/config/balance/population.json (K-M15; конфиг расширен, не
## перезаписан — D-159). I1: детерминизм (ни ГСЧ; порядок — по uid,
## тай-брейки лексикографические).
##
## Состав (14-я итерация, раунд 2 §2.2):
##   возрастная модель (GDD §3, маппинг D-133): трудоспособные 16–60,
##     наставники 60+, lifespan = «60 + Удача» (лет; естественная смерть при
##     age > lifespan, детерминированно);
##   рождения — схема k_pop (K-M12): births = k_pop × дни × m(жильё) × m(еда)
##     × m(настроение), MVP — все m = 1; аккумулятор с переносом дробей;
##   семьи: family_id = uid основателя семьи; новорождённый — в семью с
##     наименьшим числом членов (тай-брейк — минимальный family_id);
##     ponytail: семейные связи MVP = состав семьи; браки/родословные —
##     слой society-доков (02f-e), не тикета;
##   потребитель шва T-050: battle_report.losses → списание конкретных
##     жителей по character_uid; раненые — не потери (флаг wounded);
##   миграция — формула F-3: вход только Репутация (производная Резонанса);
##     Престиж никогда не влияет (Э1-3) — тест-инвариант;
##   сериализация — секция "population" схемы T-110 (schema_version).

const POPULATION_CONFIG_PATH := "res://data/config/balance/population.json"
const SCHEMA_VERSION: int = 1  # T-110: секция "population"

## Состояние: residents = [{uid: int, age: float (лет), family_id: int,
## wounded: bool, luck: int}]. Порядок массива — порядок uid (детерминизм).
var residents: Array = []
var next_uid: int = 1
var next_family_id: int = 1000  # семьи — отрицательная зона не нужна; старт выше uid
## Числа конфига (snake_case = ключам JSON; дефолты = зеркало конфига).
var k_pop_per_day: float = 0.1  # K-M12
var day_to_turn: int = 1  # K-M12 (константа день↔ход)
var working_min_years: float = 16.0
var working_max_years: float = 60.0
var mentor_min_years: float = 60.0
var lifespan_base_years: float = 60.0
var lifespan_luck_years_per_point: float = 1.0
var days_per_year: float = 365.25
var m_housing: float = 1.0  # K-M12: MVP — все m = 1
var m_food: float = 1.0
var m_mood: float = 1.0
var k_mig_per_turn: float = 0.25  # F-3
var rep_neutral: float = 0.0
var immigrant_age_min_years: float = 16.0
var immigrant_age_span_years: float = 24.0
## Аккумуляторы дробей (перенос между ходами — без ГСЧ).
var _birth_carry: float = 0.0
var _mig_carry: float = 0.0
var _event_log: Array[String] = []


func _init() -> void:
	var cfg := _load_config()
	if cfg.is_empty():
		return
	k_pop_per_day = float(cfg.get("k_pop_per_day", k_pop_per_day))
	day_to_turn = int(cfg.get("day_to_turn", day_to_turn))
	var age: Dictionary = cfg.get("age_model", {})
	working_min_years = float(age.get("working_min_years", working_min_years))
	working_max_years = float(age.get("working_max_years", working_max_years))
	mentor_min_years = float(age.get("mentor_min_years", mentor_min_years))
	lifespan_base_years = float(age.get("lifespan_base_years", lifespan_base_years))
	lifespan_luck_years_per_point = float(
		age.get("lifespan_luck_years_per_point", lifespan_luck_years_per_point))
	days_per_year = float(age.get("days_per_year", days_per_year))
	var bm: Dictionary = cfg.get("birth_multipliers", {})
	m_housing = float(bm.get("housing", m_housing))
	m_food = float(bm.get("food", m_food))
	m_mood = float(bm.get("mood", m_mood))
	var mig: Dictionary = cfg.get("migration", {})
	k_mig_per_turn = float(mig.get("k_mig_per_turn", k_mig_per_turn))
	rep_neutral = float(mig.get("rep_neutral", rep_neutral))
	immigrant_age_min_years = float(
		mig.get("immigrant_age_min_years", immigrant_age_min_years))
	immigrant_age_span_years = float(
		mig.get("immigrant_age_span_years", immigrant_age_span_years))


static func _load_config() -> Dictionary:
	var f := FileAccess.open(POPULATION_CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("PopulationSystem: нет конфига %s" % POPULATION_CONFIG_PATH)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Стартовое население (R2: 20). Детерминированный возраст: 18 + (i*7 mod 40)
## лет (полоса 18–57), семьи — по трое (household), uid по порядку.
func seed_population(count: int) -> void:
	for i in count:
		var r := _make_resident(18.0 + float((i * 7) % 40), int(i / 3))
		residents.append(r)


func size() -> int:
	return residents.size()


func working_count() -> int:
	var n := 0
	for r in residents:
		if _is_working(r):
			n += 1
	return n


func mentor_count() -> int:
	var n := 0
	for r in residents:
		if float(r["age"]) >= mentor_min_years:
			n += 1
	return n


## Один ход кампании. days — дней в ходу (WorldSeasons.DAYS_PER_SEASON);
## reputation — Репутация (F-3: единственный миграционный вход; MVP — 0,
## источник — производная Резонанса, слой за тикетом); cap — R3-кап
## (settlement.population_cap), <0 — без капа. Возвращает детерминированный отчёт.
func process_turn(days: int, reputation: float = 0.0, cap: int = -1) -> Dictionary:
	var report := {
		"deaths_natural": [] as Array,
		"births": 0,
		"immigrants": 0,
		"emigrants": [] as Array,
		"events": [] as Array,
	}
	# 1. Старение + естественная смерть (age > 60 + Удача).
	var survivors: Array = []
	for r in residents:
		r["age"] = float(r["age"]) + float(days) / days_per_year
		if float(r["age"]) > _lifespan(r):
			report["deaths_natural"].append(int(r["uid"]))
			_log("смерть (возраст %.1f > %.1f): uid %d"
				% [float(r["age"]), _lifespan(r), int(r["uid"])], report)
		else:
			survivors.append(r)
	residents = survivors
	# 2. Рождения (K-M12): k_pop × дни × m×m×m, аккумулятор с переносом.
	var cap_now := cap if cap >= 0 else 999999
	_birth_carry += k_pop_per_day * float(days) * m_housing * m_food * m_mood
	var births := int(_birth_carry)
	_birth_carry -= float(births)
	for b in births:
		if size() >= cap_now:
			_log("рождение отменено: кап %d" % cap_now, report)
			break
		residents.append(_make_resident(0.0, _smallest_family()))
		report["births"] = int(report["births"]) + 1
	# 3. Миграция (F-3): net_за_ход = k_mig × (Репутация − нейтрал), аккумулятор.
	_mig_carry += k_mig_per_turn * (reputation - rep_neutral)
	var net := int(_mig_carry)
	_mig_carry -= float(net)
	if net > 0:
		for m in net:
			if size() >= cap_now:
				break
			var age: float = immigrant_age_min_years \
				+ fmod(float(next_uid), immigrant_age_span_years)
			residents.append(_make_resident(age, next_family_id))
			next_family_id += 1
			report["immigrants"] = int(report["immigrants"]) + 1
	elif net < 0:
		for m in range(-net):
			var e: Variant = _emigrate_one()
			if e == null:
				break
			report["emigrants"].append(int(e["uid"]))
	report["population"] = size()
	return report


## Потребитель шва T-050 (§2.2): потери боя — списание жителей по
## character_uid; раненые — флаг, не потеря. uid < 1 (рейдеры: -1/0) — не жители.
func apply_battle_losses(losses: Array, wounded: Array = []) -> Dictionary:
	var report := {"removed": [] as Array, "missing": [] as Array,
		"wounded": [] as Array}
	var drop := {}
	for uid in losses:
		var u := int(uid)
		if u < 1:
			continue  # рейдер — не житель
		drop[u] = true
	var survivors: Array = []
	for r in residents:
		if drop.has(int(r["uid"])):
			report["removed"].append(int(r["uid"]))
		else:
			survivors.append(r)
	residents = survivors
	var present := {}
	for r in residents:
		present[int(r["uid"])] = r
	for uid in losses:
		var u := int(uid)
		if u >= 1 and not present.has(u) and not report["removed"].has(u):
			report["missing"].append(u)  # чужой uid — потеря записана, жителя нет
	for uid in wounded:
		var u := int(uid)
		if present.has(u):
			present[u]["wounded"] = true
			report["wounded"].append(u)
	return report


## Выдать uid рекруту (реестр жителей — единственный эмитент uid; остекление
## _recruit_uid_counter из main.gd).
func issue_uid() -> int:
	var u := next_uid
	next_uid += 1
	return u


## A5-canon: рекрут = житель (единичный комбатант несёт character_uid
## резидента). Детерминированный выбор: первый трудоспособный незраненый
## по uid; нет жителя — новый uid (потеря такого — missing, не жителя).
## ponytail: статус «под ружьём» не ведётся — мобилизация/возврат слой
## T-001/партии, не тикета.
func conscript() -> int:
	for r in residents:
		if _is_working(r) and not bool(r.get("wounded", false)):
			return int(r["uid"])
	return issue_uid()


func find_resident(uid: int) -> Dictionary:
	for r in residents:
		if int(r["uid"]) == uid:
			return r
	return {}


## Сериализация — секция "population" схемы T-110 (schema_version — миграции).
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"residents": residents.duplicate(true),
		"next_uid": next_uid,
		"next_family_id": next_family_id,
		"birth_carry": _birth_carry,
		"mig_carry": _mig_carry,
	}


static func from_dict(data: Dictionary) -> PopulationSystem:
	var p := PopulationSystem.new()
	p.residents = data.get("residents", []).duplicate(true)
	p.next_uid = int(data.get("next_uid", 1))
	p.next_family_id = int(data.get("next_family_id", 1000))
	p._birth_carry = float(data.get("birth_carry", 0.0))
	p._mig_carry = float(data.get("mig_carry", 0.0))
	return p


# --- внутреннее -------------------------------------------------------------

func _make_resident(age: float, family_id: int) -> Dictionary:
	var uid := issue_uid()
	return {"uid": uid, "age": age, "family_id": family_id,
		"wounded": false, "luck": 0}


func _lifespan(r: Dictionary) -> float:
	return lifespan_base_years \
		+ float(r.get("luck", 0)) * lifespan_luck_years_per_point


func _is_working(r: Dictionary) -> bool:
	var a := float(r["age"])
	return a >= working_min_years and a < working_max_years


## Семья с наименьшим числом членов; тай-брейк — минимальный family_id.
func _smallest_family() -> int:
	if residents.is_empty():
		var f := next_family_id
		next_family_id += 1
		return f
	var counts := {}
	for r in residents:
		var f := int(r["family_id"])
		counts[f] = int(counts.get(f, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	var best: int = keys[0]
	for f in keys:
		if int(counts[f]) < int(counts[best]):
			best = int(f)
	return best


## Эмигрант: старший по возрасту (тай-брейк — максимальный uid).
func _emigrate_one() -> Variant:
	if residents.is_empty():
		return null
	var idx := 0
	for i in residents.size():
		var a := float(residents[i]["age"])
		var b := float(residents[idx]["age"])
		if a > b or (a == b and int(residents[i]["uid"]) > int(residents[idx]["uid"])):
			idx = i
	return residents.pop_at(idx)


func _log(msg: String, report: Dictionary) -> void:
	_event_log.append(msg)
	report["events"].append(msg)


func event_log() -> Array[String]:
	return _event_log
