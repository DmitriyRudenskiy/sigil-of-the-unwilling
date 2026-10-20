class_name CampaignGoalTracker
extends RefCounted

## mvp-ui-flow 2.3 (M3): логика панели целей первых 3 дней. Чистая логика
## (без сцены) — визуальный слой привязывается к visible()/pending();
## headless-тестируемо (mvp-ui-flow 5.2).
##
## Канон: 07-ui-ux (M3), mvp-ui-flow spec «Three-day goal panel».
##   День 1 — построить ферму и казармы;
##   День 2 — тренировка воина (K-M15; тренировка, не наём — Q18);
##   День 3 — посетить руины.
## Панель видна, пока не выполнены все цели; после выполнения не показывается
## снова (цели только помечаются done, не сбрасываются).
## TTFD покрывает первое действие (не цель панели).

signal goal_completed(goal_id: String)

## Типы целей.
const GOAL_BUILDING := "building"
const GOAL_TRAIN := "train"
const GOAL_REGION := "region"

## MVP-цели: [{id, day, type, target, done}].
var goals: Array = []


func _init(p_goals: Array = []) -> void:
	if p_goals.is_empty():
		goals = default_mvp_goals()
	else:
		for g in p_goals:
			if g is Dictionary:
				var copy: Dictionary = g.duplicate(true)
				if not copy.has("done"):
					copy["done"] = false
				goals.append(copy)


## Стандартный набор целей MVP (M3). ruins_region — id региона руин
## (из данных region-graph; имя задаёт слой данных из-за несовпадения
## именованиев R0x/E-N, см. Q-M91-семью). Пустая строка = цель «выйти в поле».
static func default_mvp_goals(ruins_region: String = "") -> Array:
	return [
		{"id": "farm", "day": 1, "type": GOAL_BUILDING, "target": "campaign_farm", "done": false},
		{"id": "barracks", "day": 1, "type": GOAL_BUILDING, "target": "campaign_barracks", "done": false},
		{"id": "train_warrior", "day": 2, "type": GOAL_TRAIN, "target": "fighter", "done": false},
		{"id": "ruins", "day": 3, "type": GOAL_REGION, "target": ruins_region, "done": false},
	]


## Событие: здание построено.
func note_building_built(building_id: String) -> void:
	_complete(GOAL_BUILDING, building_id)


## Событие: тренировка завершена (класс).
func note_training_completed(class_id: String) -> void:
	_complete(GOAL_TRAIN, class_id)


## Событие: регион посещён. Пустой target цели = любой посещённый регион.
func note_region_visited(region_id: String) -> void:
	_complete(GOAL_REGION, region_id)


func _complete(type: String, target: String) -> void:
	for g in goals:
		if g["type"] != type or bool(g["done"]):
			continue
		var goal_target: String = g["target"]
		var matches := goal_target == target or (goal_target == "" and target != "")
		if matches:
			g["done"] = true
			goal_completed.emit(g["id"])


## Выполнена ли конкретная цель (по id).
func is_complete(goal_id: String) -> bool:
	for g in goals:
		if g["id"] == goal_id:
			return bool(g["done"])
	return false


## Выполнены ли все цели.
func all_complete() -> bool:
	for g in goals:
		if not bool(g["done"]):
			return false
	return true


## Панель видна, пока не выполнены все цели.
func visible() -> bool:
	return not all_complete()


## Невыполненные цели (копия, для отображения).
func pending() -> Array:
	var out: Array = []
	for g in goals:
		if not bool(g["done"]):
			out.append(g.duplicate(true))
	return out


## Цели конкретного дня (копия).
func goals_for_day(day: int) -> Array:
	var out: Array = []
	for g in goals:
		if int(g["day"]) == day:
			out.append(g.duplicate(true))
	return out


func to_dict() -> Dictionary:
	return {"goals": goals.duplicate(true)}


static func from_dict(data: Dictionary) -> CampaignGoalTracker:
	# Пустой сейв (нет ключа goals) → свежий трекер с целями по умолчанию.
	if not data.has("goals"):
		return CampaignGoalTracker.new()
	var tracker := CampaignGoalTracker.new([])
	tracker.goals.clear()
	var gs: Variant = data.get("goals", [])
	if gs is Array:
		for g in gs:
			if g is Dictionary:
				tracker.goals.append(g.duplicate(true))
	return tracker
