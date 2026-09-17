class_name CharismaEvents
extends RefCounted
## social-systems-delta D4: негативные события низкой харизмы лидера.
## cha 6–7 — нужны стимулы (набор требует оплаты/еды);
## cha 4–5 — мораль −1 (отток уже в ReputationSystem.process_migration);
## cha 1–3 — d20 vs 18 (~1 раз в 10 ходов): побег/дезертирство/отказ приказа.

const GameNumbers = preload("res://scripts/constants/GameNumbers.gd")

static var _rng := RandomNumberGenerator.new()

static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng

## cha < 0 — лидера нет в городе, событий нет.
## Возвращает {needs_incentives, morale, event, detail}
static func process(city: City, cha: int) -> Dictionary:
	var out := {"needs_incentives": false, "morale": 0, "event": "", "detail": ""}
	if cha < 0:
		return out
	if cha >= 6 and cha <= 7:
		out["needs_incentives"] = true
		out["detail"] = "Люди неохотно идут: нужны еда, золото, защита."
		return out
	if cha >= 4:
		out["morale"] = -1
		out["detail"] = "Недоверие: мораль снижена."
		return out
	# cha 1–3: страх/презрение — бунты, побеги, дезертирство
	var roll: int = _rng.randi_range(1, 20)
	if roll >= GameNumbers.CHA_MUTINY_DC:
		var event: String = _pick_event(city)
		_apply_event(city, event)
		out["event"] = event
		out["detail"] = _event_detail(event)
	return out

static func _pick_event(city: City) -> String:
	var has_militia: bool = city.count_state(PopUnit.State.MILITIA) > 0
	if has_militia and _rng.randi_range(1, 100) <= 50:
		return "desertion"
	if city.pop_total() > 0:
		return "flight"
	return "refusal"

static func _apply_event(city: City, event: String) -> void:
	if event == "desertion":
		_remove_state(city, PopUnit.State.MILITIA)
	elif event == "flight":
		if not _remove_state(city, PopUnit.State.WORKER):
			_remove_state(city, PopUnit.State.FOLLOWER)

static func _remove_state(city: City, state: int) -> bool:
	for i in range(city.pop.size() - 1, -1, -1):
		if city.pop[i].state == state:
			city.pop.remove_at(i)
			city.population_changed.emit()
			return true
	return false

static func _event_detail(event: String) -> String:
	match event:
		"desertion": return "Милиционер дезертировал."
		"flight": return "Житель сбежал из города."
		"refusal": return "Приказ проигнорирован."
	return ""
