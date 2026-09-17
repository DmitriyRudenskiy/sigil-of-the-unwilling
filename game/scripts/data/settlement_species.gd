extends RefCounted
## Таблица 7 видов поселения (1.1 прототипа, D8: 1:1 из прототипа).
## Bat — заглушка (available: false до заполнения данных).

const SPECIES: Dictionary = {
	"human": {
		"base_resolve": 15, "demand": 30, "decadence": 4,
		"hunger_tolerance": 6, "break_interval": 2,
		"traits": ["adaptable", "rain_sensitive"],
		"dlc": "", "available": true,
	},
	"beaver": {
		"base_resolve": 10, "demand": 30, "decadence": 2,
		"hunger_tolerance": 6, "break_interval": 2,
		"traits": ["hardworking", "honest", "demanding"],
		"dlc": "", "available": true,
	},
	"lizard": {
		"base_resolve": 5, "demand": 15, "decadence": 7,
		"hunger_tolerance": 12, "break_interval": 1,
		"traits": ["hardy", "distrustful"],
		"dlc": "", "available": true,
	},
	"harpy": {
		"base_resolve": 5, "demand": 15, "decadence": 3,
		"hunger_tolerance": 4, "break_interval": 1,
		"traits": ["noble", "fragile", "aggressive"],
		"dlc": "", "available": true,
	},
	"fox": {
		"base_resolve": 5, "demand": 15, "decadence": 5,
		"hunger_tolerance": 3, "break_interval": 2,
		"traits": ["majestic", "mysterious", "forest_bound"],
		"dlc": "", "available": true,
	},
	"frog": {
		"base_resolve": 10, "demand": 25, "decadence": 5,
		"hunger_tolerance": 8, "break_interval": 2,
		"traits": ["proud", "wealth_seeking", "water_loving", "architect"],
		"dlc": "keepers_of_the_stone", "available": true,
	},
	"bat": {
		"base_resolve": 0, "demand": 0, "decadence": 0,
		"hunger_tolerance": 0, "break_interval": 1,
		"traits": [],
		"dlc": "nightwatchers", "available": false,
	},
}

static func all_ids() -> Array:
	return SPECIES.keys()

static func by_id(id: String) -> Dictionary:
	return SPECIES.get(id, {})

static func is_available(id: String, dlc_purchased: Dictionary = {}) -> bool:
	var s: Dictionary = by_id(id)
	if s.is_empty() or not s.get("available", false):
		return false
	var dlc: String = s.get("dlc", "")
	if dlc == "":
		return true
	return dlc_purchased.get(dlc, false)
