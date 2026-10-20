class_name PregameFlowModel
extends RefCounted

## pregame-flow (Q18, 6 шагов до хода 1): headless-логика предыгрового потока.
## Чистая логика (без сцены) — UI (конструктор, земной шар, города, партия,
## тренировка) привязывается к этим функциям; headless-тестируемо (4.x).
##
## 6 шагов (00-overview «Предыгровой поток (Q18) [КАНОН]»):
##   конструктор → знак → земной шар → города → партия → тренировка.
## Реализовано ранее: конструктор (character_creation_ui.gd), знак (T-002),
## земной шар (region-graph-map). Здесь — headless-логика шагов: playable-маска,
## штраф оккупации, стартовая партия, тренировка-как-база.

## C-15 (владелец 2026-10-04): playable slice 3 — люди/полуорки/эльфы.
## Маска не эксплицитна в mvp_catalog.json (7 рас) → фиксируем здесь (задача 2.1).
const PLAYABLE_RACES: Array[String] = ["humans", "half_orcs", "elves"]

## 02-mechanics §3.2: партия ≤5 (попутчики).
const MAX_COMPANIONS := 5

## 02-mechanics §3.1: города — сколько угодно; за каждый город ПОСЛЕ ВТОРОГО —
## возрастающий штраф оккупации. Первые 2 города — без штрафа.
const FREE_CITIES := 2

## Штраф оккупации: базовый шаг (за город сверх FREE_CITIES).
## ⚠ [ПРЕДЛОЖЕНИЕ / TBD-баланс]: кривая не канонизирована (02-mechanics §3.1
## «кривая — TBD, баланс») → дефолт 10, линейный рост. Вердикт владельца.
const OCCUPATION_PENALTY_BASE := 10

## 2.5 (Q18): источники юнитов для тренировки (город = база тренировки).
## «Попутчики тренируются, а не нанимаются»; модель наёмного рынка вытеснена.
const TRAINING_SOURCES: Array[String] = ["city_resident", "companion", "event_npc"]


## 2.1/3.2 (C-15): playable-раса? (маска 3: люди/полуорки/эльфы).
static func is_playable_race(race_id: String) -> bool:
	return PLAYABLE_RACES.has(race_id)


## 2.3: штраф оккупации за N городов. 0 за 1–2 города; с 3-го — возрастающий
## (линейный [ПРЕДЛОЖЕНИЕ]: (N − FREE_CITIES) × base).
static func occupation_penalty(city_count: int, base: int = OCCUPATION_PENALTY_BASE) -> int:
	var over := maxi(city_count - FREE_CITIES, 0)
	return over * maxi(base, 0)


## 2.4: валидация стартовой партии: ≤5 попутчиков, у каждого класс/раса/внешний
## вид (§3.2). Возвращает {valid, errors[]}.
static func validate_starting_party(companions: Array) -> Dictionary:
	var errors: Array = []
	if companions.size() > MAX_COMPANIONS:
		errors.append("party_exceeds_%d" % MAX_COMPANIONS)
	for i in range(companions.size()):
		var c = companions[i]
		if not (c is Dictionary):
			errors.append("companion_%d_not_dict" % i)
			continue
		if str(c.get("class", "")).is_empty():
			errors.append("companion_%d_no_class" % i)
		if str(c.get("race", "")).is_empty():
			errors.append("companion_%d_no_race" % i)
		if str(c.get("appearance", "")).is_empty():
			errors.append("companion_%d_no_appearance" % i)
	return {"valid": errors.is_empty(), "errors": errors}


## 2.5: допустимые источники тренировки (канон Q18).
static func training_sources() -> Array:
	return TRAINING_SOURCES.duplicate()


## 2.5: источник допустим для тренировки (не наём)?
static func is_trainable_source(source: String) -> bool:
	return TRAINING_SOURCES.has(source)
