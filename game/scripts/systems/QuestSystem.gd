class_name QuestSystem
extends RefCounted
## quests-reputation-system: процедурные квесты (kill/gather/deliver/escort),
## прогресс, награды, провалы, цепочки, журнал.
## State (Serializable): {
##   "active": {quest_id: {quest..., "progress": int, "starts_day": int}},
##   "completed": {quest_id: {quest...}},
##   "failed": {quest_id: {quest...}},
##   "next_id": int,
## }

const QuestTemplates = preload("res://scripts/data/quest_templates.gd")
const FactionReputation = preload("res://scripts/systems/FactionReputation.gd")

## Свежий state.
static func new_state() -> Dictionary:
	return {"active": {}, "completed": {}, "failed": {}, "next_id": 1}

## Генерация 1–3 квестов для фракции. Без дублей активных (по target+type).
## Возвращает массив сгенерированных квестов (уже добавлены в state["active"]).
static func generate_quests(state: Dictionary, faction_id: String, ring: int,
		rng: RandomNumberGenerator, count: int = 3) -> Array:
	var result := []
	var attempts := 0
	while result.size() < count and attempts < count * 5:
		attempts += 1
		var id := "q%d" % int(state["next_id"])
		state["next_id"] = int(state["next_id"]) + 1
		var q: Dictionary = QuestTemplates.generate(id, faction_id, ring, rng)
		if _is_duplicate(state, q):
			continue
		q["progress"] = 0
		q["starts_day"] = 0
		state["active"][id] = q
		result.append(q)
	return result

static func _is_duplicate(state: Dictionary, q: Dictionary) -> bool:
	for id: String in state["active"]:
		var a: Dictionary = state["active"][id]
		if str(a.get("type", "")) == str(q["type"]) and str(a.get("target", "")) == str(q["target"]):
			return true
	return false

## Прогресс квеста. kill: +1 за убийство цели; gather: +1 за единицу ресурса
## (при сдаче ресурсы списываются); deliver/escort: +1 при достижении цели.
## Возвращает true, если квест стал выполненным.
static func add_progress(state: Dictionary, quest_id: String, amount: int = 1) -> bool:
	var active: Dictionary = state["active"]
	if not active.has(quest_id):
		return false
	var q: Dictionary = active[quest_id]
	var target: int = int(q["target_count"])
	q["progress"] = mini(int(q["progress"]) + amount, target)
	return int(q["progress"]) >= target

## Сдача квеста: награда (xp/gold/reputation) + перенос в completed + цепочка.
## rep_state — состояние репутации (модифицируется), race — раса героя (бонус).
## Возвращает {quest, reward, next_quest_id}.
static func complete_quest(state: Dictionary, quest_id: String,
		rep_state: Dictionary = {}, race: String = "") -> Dictionary:
	var active: Dictionary = state["active"]
	if not active.has(quest_id):
		return {}
	var q: Dictionary = active[quest_id]
	if int(q["progress"]) < int(q["target_count"]):
		return {}
	var reward: Dictionary = q["reward"]
	active.erase(quest_id)
	state["completed"][quest_id] = q
	if not rep_state.is_empty():
		var faction: String = str(q["faction_id"])
		FactionReputation.apply(rep_state, faction, int(reward.get("reputation", 0)), race)
		FactionReputation.log(state.get("rep_history", []), faction, int(reward.get("reputation", 0)), "quest:%s" % quest_id)
	return {"quest": q, "reward": reward, "next_quest_id": str(q.get("next_quest_id", ""))}

## Провал квеста: перенос в failed + штраф репутации.
## reason: "timeout" (−10) или "escort_dead" (−20).
## Возвращает {quest, penalty}.
static func fail_quest(state: Dictionary, quest_id: String, reason: String,
		rep_state: Dictionary = {}, race: String = "") -> Dictionary:
	var active: Dictionary = state["active"]
	if not active.has(quest_id):
		return {}
	var q: Dictionary = active[quest_id]
	var penalty := -10
	if reason == "escort_dead":
		penalty = -20
	active.erase(quest_id)
	state["failed"][quest_id] = q
	if not rep_state.is_empty():
		var faction: String = str(q["faction_id"])
		FactionReputation.apply(rep_state, faction, penalty, race)
		FactionReputation.log(state.get("rep_history", []), faction, penalty, "quest_failed:%s" % quest_id)
	return {"quest": q, "penalty": penalty}

## Ежедневная проверка таймеров: квесты с превышением deadline проваливаются.
## Возвращает массив проваленных quest_id.
static func check_deadlines(state: Dictionary, current_day: int) -> Array:
	var failed := []
	var ids: Array = state["active"].keys()
	for quest_id in ids:
		var q: Dictionary = state["active"][quest_id]
		var deadline: int = int(q.get("deadline", 0))
		var starts: int = int(q.get("starts_day", 0))
		if deadline > 0 and current_day - starts > deadline:
			fail_quest(state, str(quest_id), "timeout")
			failed.append(quest_id)
	return failed

## Подключение цепочки: quest_a.next_quest_id = quest_b.id.
static func link_chain(state: Dictionary, from_id: String, to_id: String) -> void:
	var active: Dictionary = state["active"]
	if active.has(from_id):
		active[from_id]["next_quest_id"] = to_id

## Журнал: активные квесты с прогрессом (для UI).
static func journal(state: Dictionary) -> Array:
	var out := []
	for quest_id: String in state["active"]:
		var q: Dictionary = state["active"][quest_id]
		out.append({
			"id": quest_id,
			"title": str(q.get("title", quest_id)),
			"faction": str(q.get("faction_id", "")),
			"progress": int(q.get("progress", 0)),
			"target": int(q.get("target_count", 0)),
			"reward": q.get("reward", {}),
			"deadline": int(q.get("deadline", 0)),
		})
	return out

## Сериализация — state уже Dictionary, ничего делать не нужно (save/load).
