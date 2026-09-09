class_name HeroNeeds
extends RefCounted

var needs: Dictionary = {}
var zero_streak: Dictionary = {}

func _init() -> void: reset()

func tick(in_city: bool, city: City = null) -> StringName:
	for id in NeedType.all_ids():
		var strat: NeedStrategy = NeedType.strategies()[id]
		var delta := -strat.decay_rate + strat.get_recovery_hero(in_city, city)
		needs[id] = clampf(float(needs.get(id, 1.0)) + delta, 0.0, 1.0)
	for id in NeedType.all_ids():
		if float(needs[id]) <= 0.0001:
			zero_streak[id] = int(zero_streak.get(id, 0)) + 1
		else:
			zero_streak[id] = 0
	for id in NeedType.all_ids():
		if int(zero_streak[id]) >= 3:
			return NeedType.strategies()[id].get_death_cause()
	return &""

func is_critical(id: int) -> bool: return float(needs.get(id, 0.0)) < 0.2
func get_need(id: int) -> float: return float(needs.get(id, 0.0))

func reset() -> void:
	for id in NeedType.all_ids():
		needs[id] = 1.0
		zero_streak[id] = 0

func serialize() -> Dictionary:
	var out := {}
	for id in NeedType.all_ids():
		out[String(NeedType.to_name(id))] = float(needs.get(id, 1.0))
	return out

func deserialize(d: Dictionary) -> void:
	for id in NeedType.all_ids():
		var key := String(NeedType.to_name(id))
		needs[id] = clampf(float(d.get(key, 1.0)), 0.0, 1.0)
		zero_streak[id] = 0
