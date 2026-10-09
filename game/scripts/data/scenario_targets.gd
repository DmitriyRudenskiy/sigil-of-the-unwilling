class_name ScenarioTargets
extends RefCounted
## autopilot-scenario-matrix (D3): цели ролей — const-таблица.
## Калибровка — правкой этих чисел по отчётам (фаза 5), не кодом.

const ROLES := {
	"collector": {
		"name": "Собиратель",
		"max_turns": 60,
		"rare_ids": [4, 5, 6],  # crystal, gems, gold
		"rare_goal": 10,
	},
	"traveler": {
		"name": "Путешественник",
		"max_turns": 90,
		"distance_goal": 25,
		"biome_goal": 2,
	},
	"trader": {
		"name": "Торговец",
		"max_turns": 90,
		"gold_goal": 1000,
		"gold_start": 30,
	},
	"adventurer": {
		"name": "Приключенец",
		"max_turns": 90,
		"kill_goal": 5,
		"boss_ring": 2,
	},
	"builder": {
		"name": "Городостроитель",
		"max_turns": 90,
		"population_goal": 8,
		"city_level_goal": 2,
		"buildings_goal": 2,
	},
}

const CLASSES := [
	"barbarian", "fighter", "monk", "paladin", "priest",
	"druid", "cipher", "wizard", "ranger", "rogue", "chanter",
]

static func role_ids() -> Array:
	return (ROLES as Dictionary).keys()

static func role(id: String) -> Dictionary:
	return (ROLES as Dictionary).get(id, {})

static func max_turns(id: String) -> int:
	return int((ROLES as Dictionary).get(id, {}).get("max_turns", 60))

## seed = f(класс, роль): разные клетки матрицы — разные карты (design, open Q).
static func seed_for(class_id: String, role_id: String) -> int:
	var key := "%s|%s" % [class_id, role_id]
	var h := 1469598103
	for i in key.length():
		h = (h ^ key.unicode_at(i)) * 947 % 2147483647
	return int(h) + 1000000
