class_name EnemyAIProfile
extends RefCounted
## Профиль ИИ вражеского стека: радиус агрессии, MP, веса целей.
## Факция определяется по составу стека (UnitRegistry.FACTION_SETS) —
## хардкода ключей юнитов здесь нет, только веса-модификаторы по факультетам.
## RAIDER — повышенный вес деревень, SEEKER — повышенный вес героя.

const FACTION_MODS: Array[Dictionary] = [
	{"village": 1.0, "resource": 0.6, "hero": 0.8},  # 0: смешанная пехота
	{"village": 0.8, "resource": 1.0, "hero": 1.1},  # 1: лес (SEEKER)
	{"village": 1.0, "resource": 0.6, "hero": 0.8},  # 2: нежить
	{"village": 0.9, "resource": 1.1, "hero": 0.7},  # 3: големы (добывают ресурсы)
	{"village": 1.0, "resource": 0.5, "hero": 0.8},  # 4: звериные народы
	{"village": 1.5, "resource": 0.4, "hero": 0.6},  # 5: рейдеры (RAIDER)
	{"village": 1.0, "resource": 0.6, "hero": 1.1},  # 6: элементали (SEEKER)
]


## Индекс фракции по первому юниту стека. sets — UnitRegistry.FACTION_SETS.
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


## Полный профиль стека.
static func for_stack(army: Array, sets: Array) -> Dictionary:
	var f: int = faction_of_army(army, sets)
	return {
		"faction": f,
		"aggro_radius": MapConfig.ENEMY_AGGRO_RADIUS,
		"mp": float(MapConfig.ENEMY_MP),
		"weights": FACTION_MODS[f % FACTION_MODS.size()].duplicate(),
	}
