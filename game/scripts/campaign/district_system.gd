## T-030: районный слой города (MVP-ядро K-M1, MVP-scope строка 55).
## 7 районов = 7 канонических экономических групп (SettlementProcessor.GROUPS);
## здание привязано к району через поле "group" (T-030-слой остатка T-040).
## Настроение района: шкала 0–100, старт 70, дельты и пороги — districts.json
## (02g §5 «Настроение», 07-balance §5; K-M15). Рабочие: вакансии останавливают
## здание (02g §3, приказ владельца); нужды — MVP-вырезка 1 на группу (02g §5.4).
## I1: чистый RefCounted — конфиг и jobs-резолвер инжектятся, ГСЧ нет.
class_name DistrictSystem
extends RefCounted

const SettlementProcessorScript := preload("res://scripts/campaign/settlement_processor.gd")

var config: Dictionary
var jobs_by_id: Dictionary
## group -> настроение (float 0–100).
var mood: Dictionary = {}
## group -> {"present": bool, "below_days": int} — состояние распада (2.2, D-235).
## Район остаётся проекцией города; персистится только гистерезис «сколько ходов
## подряд группа без зданий». Ключ — 7 канонических групп, строка «без группы»
## районами не считается (это отсутствие района).
var district_state: Dictionary = {}


func _init(p_config: Dictionary = {}, p_jobs_by_id: Dictionary = {}) -> void:
	config = p_config
	jobs_by_id = p_jobs_by_id
	for g in SettlementProcessorScript.GROUPS + [SettlementProcessorScript.UNGROUPED]:
		mood[str(g)] = float(config.get("mood_start", 70.0))


## Назначение рабочих (авто, 02g §5.3): стабильный порядок — GROUPS, затем
## индекс здания; вакансии (workers < jobs) останавливают здание (поле workers).
## Возвращает {assigned, vacancies}.
func assign_workers(buildings: Array, available_workers: int) -> Dictionary:
	var order: Array = []
	for gi in range(SettlementProcessorScript.GROUPS.size() + 1):
		var grp: String = (
			str(SettlementProcessorScript.GROUPS[gi])
			if gi < SettlementProcessorScript.GROUPS.size()
			else SettlementProcessorScript.UNGROUPED
		)
		for i in buildings.size():
			if str(buildings[i].get("group", SettlementProcessorScript.UNGROUPED)) == grp:
				order.append(i)
	var remaining: int = available_workers
	var vacancies: int = 0
	for i in order:
		var b: Dictionary = buildings[i]
		var jobs: int = int(jobs_by_id.get(str(b.get("id", "")), 0))
		b["jobs"] = jobs
		var w: int = mini(jobs, remaining)
		b["workers"] = w
		remaining -= w
		vacancies += jobs - w
	return {"assigned": available_workers - remaining, "vacancies": vacancies}


## Сезонный проход района (вызывается из settlement-фазы после синхронизации
## ростери). food_state — SM-состояние еды ("OK"/"WARN"/"DEFICIT").
func process_turn(
	buildings: Array,
	population: int,
	party_size: int,
	food_state: String = "OK"
) -> Dictionary:
	var days: int = WorldSeasons.DAYS_PER_SEASON
	var deltas: Dictionary = config.get("deltas_per_day", {})
	var need_cfg: Dictionary = config.get("need", {})
	assign_workers(buildings, population)
	# 1. Множитель настроения по району — по настроению НАЧАЛА сезона.
	var mult_by_group := {}
	for g in mood.keys():
		mult_by_group[g] = _prod_mult(float(mood[g]))
	for b in buildings:
		b["mood_mult"] = float(mult_by_group.get(
			str(b.get("group", SettlementProcessorScript.UNGROUPED)), 1.0))
	# 2. Нужды (MVP-вырезка: Еда на группу) + агрегаты района.
	var districts := {}
	for g in SettlementProcessorScript.GROUPS + [SettlementProcessorScript.UNGROUPED]:
		districts[str(g)] = {
			"mood": float(mood.get(str(g), config.get("mood_start", 70.0))),
			"buildings": 0, "workers": 0, "jobs": 0,
			"need_cap": 0.0, "need_dem": 0.0,
			# Жив ли район этот ход (2.2). Строка «без группы» всегда true: распад
			# применяется только к 7 каноническим группам.
			"present": true,
		}
	var food_net: float = 0.0
	for b in buildings:
		var d: Dictionary = districts[str(b.get("group", SettlementProcessorScript.UNGROUPED))]
		d["buildings"] = int(d["buildings"]) + 1
		d["jobs"] = int(d["jobs"]) + int(b.get("jobs", 0))
		var staffed: bool = int(b.get("workers", 0)) >= int(b.get("jobs", 0))
		if staffed:
			d["workers"] = int(d["workers"]) + int(b.get("workers", 0))
			d["need_cap"] = float(d["need_cap"]) + float(
				need_cfg.get("supply_cap_by_id", {}).get(str(b.get("id", "")), 0.0))
		if staffed and b.get("output_day", {}) is Dictionary:
			food_net += float((b.get("output_day") as Dictionary).get("food", 0.0)) \
				* float(b.get("efficiency", 1.0)) * float(b.get("mood_mult", 1.0))
	for g in districts.keys():
		var d: Dictionary = districts[g]
		d["need_dem"] = float(d["workers"]) * float(need_cfg.get("demand_per_worker_per_day", 1.0))
		d["need_ok"] = float(d["need_cap"]) >= float(d["need_dem"])
	# 3. Дельты настроения (за сезон = суточные × DAYS_PER_SEASON; 02g §5).
	var events: Array[String] = []
	var consumption: float = SettlementProcessorScript.K_POP * float(population) \
		+ SettlementProcessorScript.UNIT_EAT * float(party_size)
	food_net -= consumption
	var report_events := []
	for g in districts.keys():
		var delta: float = 0.0
		var d: Dictionary = districts[g]
		# Голод = DEFICIT запаса И отрицательный поток (02g §5). Запас ≤0 при
		# положительном потоке — пайка (тормоз петли: «пайка, таверна, провизия»).
		if food_state == "DEFICIT" and food_net < 0.0:
			delta += float(deltas.get("food_deficit", 0.0)) * float(days)
		elif food_net >= float(deltas.get("food_surplus_min_net", 5.0)):
			delta += float(deltas.get("food_surplus", 0.0)) * float(days)
		# Таверна: +2/день, максимум +4 (число таверн района ×2, кап config).
		var taverns: int = 0
		for b in buildings:
			if str(b.get("group", "")) == g and str(b.get("id", "")) in need_cfg.get("tavern_ids", []):
				taverns += 1
		delta += minf(float(taverns) * float(deltas.get("tavern", 0.0)),
			float(deltas.get("tavern_cap", 0.0))) * float(days)
		# Нужда не покрыта → дельта за сезон (адаптация при приёмке, districts.json).
		if int(d["buildings"]) > 0 and not bool(d["need_ok"]):
			delta += float(need_cfg.get("unmet_per_season", 0.0))
		if delta != 0.0:
			var next: float = clampf(float(mood[g]) + delta,
				float(config.get("mood_min", 0.0)), float(config.get("mood_max", 100.0)))
			report_events.append("%s: настроение %s → %s" % [g, str(mood[g]), str(next)])
			mood[g] = next
		d["mood"] = float(mood[g])
	# 4. Дезертирство (<40: 1 поп / 2 дня, 02g) — поселенческое (D-134: настроение
	# — шкала поселения), один счёт на проход. MVP: только счёт в отчёт — канал
	# изменения населения это миграция (F-3/T-116, no-op хук), ростерь не трогаем.
	var desertion: int = 0
	var low: bool = false
	for g in districts.keys():
		if int(districts[g]["buildings"]) > 0 and float(mood[g]) < float(config.get("threshold_low", 40.0)):
			low = true
	if low:
		desertion = int(float(days) / 2.0) * int(config.get("desertion_per_two_days_low", 1))
	# 5. Распад района (2.2, D-235): «теги ниже порога 3 дня подряд → район снят».
	# Мерой «тегов собраны» в носителе служит наличие у группы хотя бы одного
	# здания — радиуса и перечня тегов у проекции нет (расхождение зафиксировано
	# в carrier notes спеки). Смысл гистерезиса: здание вернули за 3 хода — район
	# жив и его настроение (а значит и множитель производства) сохранено; дольше —
	# запись района уничтожена, настроение сброшено к стартовому.
	var disbanded: Array = []
	# D-240: рождение района — переход «нет зданий → есть здания». Первый проход
	# служит базовой линией: стартовые пять зданий не «созданные районы», иначе
	# ход 1 выдал бы игроку записи о том, чего он не делал. Признаком «базовая
	# линия взята» служит сам district_state: он пуст только до первого прохода
	# и восстановлен из сейва (то есть после загрузки базовая линия уже взята).
	var created: Array = []
	var presence_taken := not district_state.is_empty()
	var below_limit: int = int(config.get("disband_below_days", 3))
	for g in SettlementProcessorScript.GROUPS:
		var grp := str(g)
		var st: Dictionary = district_state.get(grp, {"present": false, "below_days": 0})
		if int((districts[grp] as Dictionary)["buildings"]) > 0:
			if presence_taken and not bool(st["present"]):
				created.append(grp)
			st["present"] = true
			st["below_days"] = 0
		elif bool(st["present"]):
			st["below_days"] = int(st["below_days"]) + 1
			if int(st["below_days"]) >= below_limit:
				st["present"] = false
				st["below_days"] = 0
				mood[grp] = float(config.get("mood_start", 70.0))
				(districts[grp] as Dictionary)["mood"] = float(mood[grp])
				disbanded.append(grp)
		else:
			st["present"] = false
			st["below_days"] = 0
		district_state[grp] = st
		(districts[grp] as Dictionary)["present"] = bool(st["present"])
	return {
		"districts": districts,
		"disbanded": disbanded,
		"created": created,
		"desertion": desertion,
		"food_net_per_day": food_net,
		"events": report_events,
	}


## Событийная дельта настроения района (worker_death / building_destroyed /
## catastrophe / raid_repelled — ключи districts.json deltas_per_day).
func apply_event(group: String, delta_key: String) -> void:
	if not mood.has(group):
		return
	var deltas: Dictionary = config.get("deltas_per_day", {})
	mood[group] = clampf(float(mood[group]) + float(deltas.get(delta_key, 0.0)),
		float(config.get("mood_min", 0.0)), float(config.get("mood_max", 100.0)))


## Числовая дельта настроения на всё поселение (Q-M78 → (а), D-197): приёмник
## канала `morale_change`/`morale_penalty` каталога событий. Шкала 02g (0–100),
## clamp — districts.json (mood_min/mood_max).
func apply_mood_delta(amount: float) -> void:
	for g in mood.keys():
		mood[g] = clampf(float(mood[g]) + amount,
			float(config.get("mood_min", 0.0)), float(config.get("mood_max", 100.0)))


## Дельта на все районы (отражённый рейд — поселенческое событие, 02g).
func apply_event_to_all(delta_key: String) -> void:
	for g in mood.keys():
		apply_event(str(g), delta_key)


func _prod_mult(m: float) -> float:
	if m < float(config.get("threshold_low", 40.0)):
		return float(config.get("prod_mult_low", 0.85))
	if m >= float(config.get("threshold_high", 80.0)):
		return float(config.get("prod_mult_high", 1.1))
	return 1.0


## Слияние «три в одном» (02g §4.1; MVP-scope: «в схеме»). Результат уже
## построен, компоненты (recipe.components) стоят вплотную-в-схеме MVP:
## совпадение по id. Возвращает {ok, buildings, reason}.
static func merge_three(buildings: Array, catalog: Dictionary, result_id: String) -> Dictionary:
	var result_def: Dictionary = {}
	for r in catalog.get("buildings", []):
		if str(r.get("id", "")) == result_id:
			result_def = r
			break
	if result_def.is_empty() or not (result_def.get("merge") is Dictionary) \
			or (result_def.get("merge") as Dictionary).is_empty():
		return {"ok": false, "buildings": buildings, "reason": "result has no merge recipe"}
	var expected: Array = (result_def.get("merge") as Dictionary).get("components", [])
	var result_idx: int = -1
	var component_idxs: Array[int] = []
	var used := {}
	for i in buildings.size():
		var id := str(buildings[i].get("id", ""))
		if id == result_id and result_idx < 0:
			result_idx = i
			continue
		for c in range(expected.size()):
			if str(expected[c]) == id and not used.has(c):
				used[c] = i
				component_idxs.append(i)
				break
	if result_idx < 0:
		return {"ok": false, "buildings": buildings, "reason": "result building not built"}
	if used.size() != expected.size():
		return {"ok": false, "buildings": buildings, "reason": "components missing"}
	var out := {}
	for recipe in result_def.get("recipes", []):
		for k in (recipe as Dictionary).get("outputs", {}):
			out[str(k)] = float(out.get(str(k), 0.0)) + float((recipe as Dictionary)["outputs"][k])
	var merged: Dictionary = {
		"id": result_id,
		"group": str(buildings[result_idx].get("group", "")),
		"output_day": out,
		"efficiency": 1.0,
		"tier": 2,
	}
	var drop := {}
	drop[result_idx] = true
	for i in component_idxs:
		drop[i] = true
	var next: Array = []
	for i in buildings.size():
		if not drop.has(i):
			next.append(buildings[i])
	next.append(merged)
	return {"ok": true, "buildings": next, "reason": ""}


func to_dict() -> Dictionary:
	return {
		"mood": mood.duplicate(true),
		# 2.2 (D-235): гистерезис распада — состояние, не производная: без него
		# «3 хода подряд» перезапускались бы каждой загрузкой сейва.
		"district_state": district_state.duplicate(true),
	}


static func from_dict(data: Dictionary, p_config: Dictionary = {}, p_jobs_by_id: Dictionary = {}) -> DistrictSystem:
	var sys := DistrictSystem.new(p_config, p_jobs_by_id)
	for g in (data.get("mood", {}) as Dictionary).keys():
		if sys.mood.has(str(g)):
			sys.mood[str(g)] = float((data.get("mood") as Dictionary)[g])
	for g in (data.get("district_state", {}) as Dictionary).keys():
		var grp := str(g)
		var raw: Dictionary = (data.get("district_state") as Dictionary)[g]
		# JSON round-trip теряет int (см. _to_json_types в campaign_composition).
		sys.district_state[grp] = {
			"present": bool(raw.get("present", false)),
			"below_days": int(raw.get("below_days", 0)),
		}
	return sys
