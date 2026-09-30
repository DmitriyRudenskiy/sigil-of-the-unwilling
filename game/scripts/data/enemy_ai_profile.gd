class_name EnemyAIProfile
extends RefCounted

const FACTION_MODS: Array[Dictionary] = [
	{"village": 1.0, "resource": 0.6, "hero": 0.8},
	{"village": 0.8, "resource": 1.0, "hero": 1.1},
	{"village": 1.0, "resource": 0.6, "hero": 0.8},
	{"village": 0.9, "resource": 1.1, "hero": 0.7},
	{"village": 1.0, "resource": 0.5, "hero": 0.8},
	{"village": 1.5, "resource": 0.4, "hero": 0.6},
	{"village": 1.0, "resource": 0.6, "hero": 1.1},
]

static func faction_of_army(army: Array, sets: Array) -> int:
	if army.is_empty():
		return 0
	var key: String = army[0].get_key()
	var idx := 0
	while idx < sets.size():
		if sets[idx].has(key):
			return idx
		idx += 1
	return 0

static func for_stack(army: Array, sets: Array) -> Dictionary:
	var f: int = faction_of_army(army, sets)
	return {
		"faction": f,
		"aggro_radius": GameNumbers.ENEMY_AGGRO_RADIUS,
		"mp": float(GameNumbers.ENEMY_MP),
		"weights": FACTION_MODS[f % FACTION_MODS.size()].duplicate(),
	}
