class_name WorldSeasons
extends RefCounted
## Ранняя игра: глобальный сезонный цикл (early-game-foundation, world-threat-rings).

const TURN_LENGTH := 20
# id -> (название, множитель продуктивности городов)
const SEASONS := [
	{"id": "clear", "mult": 1.0},
	{"id": "drizzle", "mult": 1.2},
	{"id": "storm", "mult": 0.4},
]
# Буря как окно опасности: множитель численности вражеских стаек
const STORM_ENEMY_MULT := 1.25

static var _turns_in_season := 0

static func season_index() -> int:
	return int(_turns_in_season / TURN_LENGTH) % SEASONS.size()

static func current() -> Dictionary:
	return SEASONS[season_index()]

static func season_name() -> String:
	var id := String(current()["id"])
	if id == "drizzle":
		return "Морось"
	if id == "storm":
		return "Буря"
	return "Ясный сезон"

static func production_mult() -> float:
	return float(current()["mult"])

static func enemy_mult() -> float:
	return STORM_ENEMY_MULT if current()["id"] == "storm" else 1.0

static func advance_turn() -> void:
	_turns_in_season += 1

static func reset() -> void:
	_turns_in_season = 0

# Враждебность мира растёт со временем партии (early-game-foundation)
const HOSTILITY_BASE := 1.0
const HOSTILITY_GROWTH_PER_TURN := 0.02
const HOSTILITY_CAP := 2.0

static func hostility_mult() -> float:
	return minf(HOSTILITY_BASE + float(_turns_in_season) * HOSTILITY_GROWTH_PER_TURN, HOSTILITY_CAP)
