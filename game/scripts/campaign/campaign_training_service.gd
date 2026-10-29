class_name CampaignTrainingService
extends RefCounted

const CatalogPath := "res://assets/data/mvp_catalog.json"
const BalanceConfigPath := "res://data/config/balance/campaign.json"
const PARTY_CAPACITY := 5

## 2.4 [ПРЕДЛОЖЕНИЕ] (02-mechanics §3.3 EC3): «10 жителей на юнит». Число —
## предложение, ждёт вердикта автора; носитель — campaign.json
## training.population_per_unit, фолбэк — эта константа.
const DEFAULT_POPULATION_PER_UNIT := 10
## Уровень замены мёртвых (party-characters 2.3): в MVP — 1 (C-1: «уровень
## города − 1» — мёртвая ссылка, K-M3).
const DEFAULT_REPLACEMENT_LEVEL := 1

static var _balance_config: Dictionary = {}

## D-221 (V-6, 2026-10-20): лимит партии и гейтинг — alive-модель.
## DEAD не занимают активный слот и не блокируют тренировку/рекрутинг;
## согласовано с party_screen_model (alive) и campaign_composition
## (settlement.party_size = alive_members).

## Единственный вход сервиса — живой носитель (T-170 вариант (а), T-171):
## опции `available_training_actions_city`, заявка `request_training`, тик и
## выдача `advance_training_turn`, порог `population_gate_city`. T-110-форма
## (`train`/`available_training_actions`/`population_gate`/`_building_instances`)
## читателя не имела и держала вытесненную семантику: боец попадал в партию
## сразу, минуя SM REQUESTED → TRAINING → READY, ёмкость партии отказывала на
## заявке (spec: полный состав → рекрут ждёт слот), канон-время класса не
## проверялось. Отсутствие проверяет test_dict_entry_points_are_gone.

## Число порога из конфига (campaign.json training.population_per_unit).
static func population_per_unit() -> int:
	var block: Variant = _balance().get("training", {})
	if not (block is Dictionary):
		return DEFAULT_POPULATION_PER_UNIT
	return int((block as Dictionary).get("population_per_unit", DEFAULT_POPULATION_PER_UNIT))


## Уровень замены мёртвых из конфига (party-characters 2.3).
static func replacement_level() -> int:
	var block: Variant = _balance().get("training", {})
	if not (block is Dictionary):
		return DEFAULT_REPLACEMENT_LEVEL
	return maxi(1, int((block as Dictionary).get("replacement_level", DEFAULT_REPLACEMENT_LEVEL)))


## Множитель одновременности N (формула 02-mechanics §3.3: progress +=
## tick / (t_тренировки × N)). Числа в GDD нет → 1 и строка в реестре
## 07-balance §10.
static func concurrency_n() -> int:
	var block: Variant = _balance().get("training", {})
	if not (block is Dictionary):
		return 1
	return maxi(1, int((block as Dictionary).get("concurrency_n", 1)))


## Время тренировки класса в днях (07-balance «Базовые бойцы MVP», K-M15).
## 0.0 — числа нет (волшебник, T-041): тренировка этого класса не генерируется.
static func training_days(class_id: String) -> float:
	var block: Variant = _balance().get("training", {})
	if not (block is Dictionary):
		return 0.0
	var days: Variant = (block as Dictionary).get("days", {})
	if not (days is Dictionary) or not (days as Dictionary).has(class_id):
		return 0.0
	return float((days as Dictionary)[class_id])


## ─── Живой носитель (T-170, вариант (а)) ──────────────────────────────────────
## Те же проверки, что у T-110-формы, но над объектом City: его видит экран
## города, его сериализует CitySerializer, его тикает композиция. Состояние —
## `city.campaign_training`; партия в City не живёт, поэтому число живых и
## свободные слоты приходят параметрами.

## SM рекрута (02-mechanics §3.3): REQUESTED → TRAINING → (PAUSED) → READY.
const STATE_REQUESTED := "REQUESTED"
const STATE_TRAINING := "TRAINING"
const STATE_PAUSED := "PAUSED"
const STATE_READY := "READY"

## Один ход = сутки (`campaign.turn_length_days` = 1, `ticks_per_day` в коде не
## читает никто). Субсуточный тик — Q-M101, здесь он не изобретается.
const TickDays := 1.0


static func training_queue(city: City) -> Array[Dictionary]:
	return city.campaign_training


## Постройка «жива» = активна и достроена (та же мера, что в
## available_training_actions(): недострой и руины сеть не держат).
static func _building_is_live(instance: Dictionary) -> bool:
	return String(instance.get("state", "active")) == "active" \
			and int(instance.get("construction_turns_remaining", 0)) <= 0


static func _live_instances(city: City) -> Array:
	var instances: Array = []
	for raw in city.campaign_buildings:
		if raw is Dictionary:
			instances.append(raw)
	return instances


static func _instance_by_uid(city: City, building_uid: int) -> Dictionary:
	for raw in city.campaign_buildings:
		if raw is Dictionary and int((raw as Dictionary).get("uid", -1)) == building_uid:
			return raw
	return {}


## Порог населения над живым городом: жители = city.pop (PopUnit-ы), порог =
## per_unit × (живые в партии + очередь + один новый).
static func population_gate_city(city: City, party_alive: int, per_unit: int = 0) -> Dictionary:
	var per := per_unit
	if per <= 0:
		per = population_per_unit()
	var required := per * (party_alive + training_queue(city).size() + 1)
	var have: int = city.pop.size()
	return {
		"ok": have >= required,
		"required": required,
		"population": have,
		"missing": maxi(0, required - have),
	}


## Опции тренировки города-носителя (гейты те же, что у dict-формы: постройка
## жива, prerequisites, одобренный класс, плюс 2.4 — порог населения и 2.1 —
## наличие канон-времени у класса).
static func available_training_actions_city(city: City, building_catalog: Dictionary,
		scenario_flags: Array = [], admin_capacity: int = 0, party_alive: int = 0,
		population_per_unit: int = 0) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not bool(population_gate_city(city, party_alive, population_per_unit)
			.get("ok", false)):
		return options
	var catalog := _load_catalog()
	var instances := _live_instances(city)
	var built_ids: Array[String] = []
	for raw in instances:
		var standing: Dictionary = raw
		if int(standing.get("construction_turns_remaining", 0)) > 0 \
				or String(standing.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(standing.get("id", "")))
	for raw in instances:
		var instance: Dictionary = raw
		if not _building_is_live(instance):
			continue
		var definition := _find_building(building_catalog, String(instance.get("id", "")))
		if definition.is_empty():
			continue
		if not CampaignBuildingCatalog.check_prerequisites(
				definition, built_ids, scenario_flags, admin_capacity).ok:
			continue
		for action in definition.get("training", []):
			if not (action is Dictionary):
				continue
			var class_id := String(action.get("class_id", ""))
			if _approved_class(catalog, class_id).is_empty() \
					or training_days(class_id) <= 0.0:
				continue
			var costs: Variant = action.get("costs", {})
			if not (costs is Dictionary):
				continue
			options.append({
				"building_uid": int(instance.get("uid", -1)),
				"building_id": String(instance.get("id", "")),
				"class_id": class_id,
				"costs": (costs as Dictionary).duplicate(true),
				"days": training_days(class_id),
			})
	return options


## Заявка на тренировку (живой город). Стоимость списывается с ресурсов города
## сразу и при паузе не возвращается (02-mechanics §3.3). Кандидат приходит с
## характеристиками — гейт класса проверяется на заявки, а не на выдаче.
static func request_training(city: City, building_catalog: Dictionary, building_uid: int,
		class_id: String, trainee: Dictionary, party_alive: int,
		scenario_flags: Array = [], admin_capacity: int = 0,
		population_per_unit: int = 0) -> Dictionary:
	var catalog := _load_catalog()
	var approved_class := _approved_class(catalog, class_id)
	if approved_class.is_empty():
		return _failure("unsupported_class:%s" % class_id)
	if training_days(class_id) <= 0.0:
		return _failure("no_training_time:%s" % class_id)
	var race := _first_tier_race(catalog, String(trainee.get("race", "")))
	if race.is_empty():
		return _failure("unsupported_race:%s" % String(trainee.get("race", "")))
	var stats: Variant = trainee.get("stats", {})
	if not (stats is Dictionary):
		return _failure("invalid_stats")
	var gate_result := _check_class_gate(approved_class, stats)
	if not gate_result.ok:
		return _failure(String(gate_result.reason))
	var trainee_id := String(trainee.get("id", "")).strip_edges()
	if trainee_id.is_empty():
		return _failure("trainee_id_required")
	var instance := _instance_by_uid(city, building_uid)
	if instance.is_empty() or not _building_is_live(instance):
		return _failure("training_building_unavailable")
	var definition := _find_building(building_catalog, String(instance.get("id", "")))
	if definition.is_empty():
		return _failure("unknown_building:%s" % String(instance.get("id", "")))
	var action := _find_training_action(definition, class_id)
	if action.is_empty():
		return _failure("class_not_trained_here:%s" % class_id)
	var built_ids: Array[String] = []
	for raw in _live_instances(city):
		var standing: Dictionary = raw
		if int(standing.get("construction_turns_remaining", 0)) > 0 \
				or String(standing.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(standing.get("id", "")))
	var prerequisite_check := CampaignBuildingCatalog.check_prerequisites(
		definition, built_ids, scenario_flags, admin_capacity)
	if not prerequisite_check.ok:
		return {"ok": false, "reason": "prerequisite_missing",
			"missing": prerequisite_check.missing}
	var people := population_gate_city(city, party_alive, population_per_unit)
	if not bool(people.get("ok", false)):
		return _failure("population_below_threshold:%d<%d"
			% [int(people.get("population", 0)), int(people.get("required", 0))])
	var costs: Variant = action.get("costs", {})
	if not (costs is Dictionary):
		return _failure("invalid_training_costs")
	for resource_id in costs:
		if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
			return _failure("unregistered_training_resource:%s" % String(resource_id))
		var amount: Variant = costs[resource_id]
		if (typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT) \
				or not is_finite(float(amount)) or float(amount) <= 0.0:
			return _failure("invalid_training_cost:%s" % String(resource_id))
	var resources := city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true))
	var paid: Dictionary = {"ok": true}
	if not (costs as Dictionary).is_empty():
		paid = resources.transact(costs, {}, "training:%s/class:%s" % [trainee_id, class_id])
	if not bool(paid.get("ok", false)):
		return {"ok": false, "reason": String(paid.get("reason", "payment_failed")),
			"missing": paid.get("missing", {})}
	var record := {
		"uid": _next_training_uid(city),
		"class_id": class_id,
		"race_id": String(race.get("id", trainee.get("race", ""))),
		"trainee": trainee.duplicate(true),
		"training_building_uid": building_uid,
		"state": STATE_REQUESTED,
		"progress": 0.0,
		"cost": (costs as Dictionary).duplicate(true),
	}
	city.campaign_training.append(record)
	return {"ok": true, "recruit": record}


## Замена мёртвого (party-characters 2.3): «a DEAD character SHALL be replaced by
## a companion of the same class via training, level 1 in MVP» — класс берётся из
## покойного, уровень назначается конфигом, а не заявителем. Расу спецификация не
## фиксирует — кандидат приходит со своей. Слот партии DEAD не занимает (alive-
## модель V-6/D-221), поэтому `party_alive` считается как обычно.
static func request_replacement(city: City, building_catalog: Dictionary, building_uid: int,
		dead_member: Dictionary, candidate: Dictionary, party_alive: int,
		scenario_flags: Array = [], admin_capacity: int = 0,
		population_per_unit: int = 0) -> Dictionary:
	if String(dead_member.get("state", PartySystem.STATE_READY)) != PartySystem.STATE_DEAD:
		return _failure("member_not_dead")
	var class_id := String(dead_member.get("class", ""))
	if class_id.is_empty():
		return _failure("dead_member_class_missing")
	var trainee := candidate.duplicate(true)
	trainee["level"] = replacement_level()
	return request_training(city, building_catalog, building_uid, class_id, trainee,
		party_alive, scenario_flags, admin_capacity, population_per_unit)


## Тик очереди (production-фаза). SM: REQUESTED→TRAINING на следующем ходу,
## PAUSED при разрыве сети (прогресс и списанная стоимость сохраняются), READY
## ждёт свободного слота партии. `members` — готовые словари членов; запись
## покидает очередь только вместе с ними.
static func advance_training_turn(city: City, party_free_slots: int = PARTY_CAPACITY,
		speed_n: float = 0.0) -> Dictionary:
	var report := {"advanced": 0, "paused": 0, "resumed": 0, "ready": 0,
		"waiting_slot": 0, "members": []}
	var n := speed_n if speed_n > 0.0 else float(maxi(1, concurrency_n()))
	var slots := party_free_slots
	var finished: Array = []
	for raw in training_queue(city):
		if not (raw is Dictionary):
			continue
		var record: Dictionary = raw
		var state := String(record.get("state", STATE_REQUESTED))
		if state != STATE_READY:
			var instance := _instance_by_uid(city, int(record.get("training_building_uid", -1)))
			if instance.is_empty() or not _building_is_live(instance):
				if state != STATE_PAUSED:
					record["state"] = STATE_PAUSED
					report["paused"] = int(report["paused"]) + 1
			else:
				if state == STATE_REQUESTED:
					record["state"] = STATE_TRAINING
					report["advanced"] = int(report["advanced"]) + 1
				elif state == STATE_PAUSED:
					record["state"] = STATE_TRAINING
					report["resumed"] = int(report["resumed"]) + 1
				var days := training_days(String(record.get("class_id", "")))
				if days <= 0.0:
					days = TickDays
				record["progress"] = minf(1.0, float(record.get("progress", 0.0))
						+ TickDays / (days * n))
				if float(record.get("progress", 0.0)) >= 1.0:
					record["state"] = STATE_READY
					report["ready"] = int(report["ready"]) + 1
		if String(record.get("state", "")) == STATE_READY:
			if slots <= 0:
				report["waiting_slot"] = int(report["waiting_slot"]) + 1
			else:
				(report["members"] as Array).append(_materialize(record))
				slots -= 1
				finished.append(int(record.get("uid", -1)))
	if not finished.is_empty():
		var kept: Array[Dictionary] = []
		for raw in training_queue(city):
			if not finished.has(int((raw as Dictionary).get("uid", -1))):
				kept.append(raw)
		city.campaign_training = kept
	return report


## Выдача: снимок кандидата → член партии той же формы, что стартовая партия
## (`id, class, race, level, xp, luck, stats`) + HP через PartySystem.ensure_hp.
static func _materialize(record: Dictionary) -> Dictionary:
	var raw_trainee: Variant = record.get("trainee", {})
	var member: Dictionary = (raw_trainee as Dictionary).duplicate(true) \
			if raw_trainee is Dictionary else {}
	member["class"] = String(record.get("class_id", ""))
	member["race"] = String(record.get("race_id", ""))
	member["level"] = maxi(1, int(member.get("level", 1)))
	member["xp"] = maxi(0, int(member.get("xp", 0)))
	member["luck"] = int(member.get("luck", 0))
	PartySystem.ensure_hp(member)
	return member


## uid очереди — своя последовательность: City._uid_seq сериализатор пересчитывает
## по постройкам и резидентам и про очередь тренировки не знает.
static func _next_training_uid(city: City) -> int:
	var highest := 0
	for raw in training_queue(city):
		if raw is Dictionary:
			highest = maxi(highest, int((raw as Dictionary).get("uid", 0)))
	return highest + 1

## Баланс-конфиг кампании (campaign.json); кэш на процесс, фолбэк — константы.
static func _balance() -> Dictionary:
	if _balance_config.is_empty():
		var file := FileAccess.open(BalanceConfigPath, FileAccess.READ)
		if file == null:
			push_warning("CampaignTrainingService: %s не найден — фолбэк порога"
				% BalanceConfigPath)
			return _balance_config
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_balance_config = parsed
		else:
			push_warning("CampaignTrainingService: campaign.json не распарсился — фолбэк")
	return _balance_config


static func _load_catalog() -> Dictionary:
	if not FileAccess.file_exists(CatalogPath):
		return {}
	var file := FileAccess.open(CatalogPath, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func _approved_class(catalog: Dictionary, class_id: String) -> Dictionary:
	for class_record in catalog.get("classes", []):
		if class_record is Dictionary and String(class_record.get("id", "")) == class_id \
				and bool(class_record.get("hireable", false)):
			return class_record
	return {}

static func _first_tier_race(catalog: Dictionary, race_id: String) -> Dictionary:
	for race in catalog.get("races", []):
		if race is Dictionary and String(race.get("id", "")) == race_id \
				and bool(race.get("first_tier", false)):
			return race
	return {}

static func _check_class_gate(class_record: Dictionary, stats: Dictionary) -> Dictionary:
	var gate: Dictionary = class_record.get("gate", {})
	var requirements: Array = gate.get("reqs", [])
	var mode := String(gate.get("mode", "all"))
	var met := 0
	var failures: Array[String] = []
	for requirement in requirements:
		if not (requirement is Array) or requirement.size() != 2:
			return {"ok": false, "reason": "invalid_class_gate"}
		var ability := String(requirement[0]).to_lower()
		var needed := int(requirement[1])
		var actual := int(stats.get(ability, -1))
		if actual >= needed:
			met += 1
		else:
			failures.append("%s:%d<%d" % [ability, actual, needed])
	var ok := met > 0 if mode == "any" else failures.is_empty()
	return {"ok": ok, "reason": "class_gate:%s" % ",".join(failures)}

static func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if building is Dictionary and String(building.get("id", "")) == building_id:
			return building
	return {}

static func _find_training_action(definition: Dictionary, class_id: String) -> Dictionary:
	for action in definition.get("training", []):
		if action is Dictionary and String(action.get("class_id", "")) == class_id:
			return action
	return {}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
