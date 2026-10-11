class_name WorldSeasons
extends RefCounted
## Ранняя игра: климатическое давление (early-game-foundation, world-threat-rings).
##
## T-010: счётчик ходов делегирован в WorldClock (единственный источник числа хода;
## канонический календарь «ход = сезон, 4 хода = год» — там). «Сезоны» здесь —
## климатический цикл из 3 состояний (наименование — TBD владельцу; канонические
## 4 сезона — WorldClock.season()).

const TURN_LENGTH := 20
# id -> (название, множитель продуктивности городов)
const SEASONS := [
	{"id": "clear", "mult": 1.0},
	{"id": "drizzle", "mult": 1.2},
	{"id": "storm", "mult": 0.4},
]
# Буря как окно опасности: множитель численности вражеских стаек
const STORM_ENEMY_MULT := 1.25

## T-010: счётчик ходов — WorldClock (единственный источник).

static func season_index() -> int:
	return int(WorldClock.get_turn() / TURN_LENGTH) % SEASONS.size()

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

static func advance_turn() -> int:
	return WorldClock.advance_turn()

static func reset() -> void:
	WorldClock.reset()

## save-load-coverage-expansion 3.2: static-счётчик персистится через
## WorldStateDelta.season_turns (save → load), чтобы сезон/враждебность
## не сбрасывались при перезагрузке.
static func get_turns() -> int:
	return WorldClock.get_turn()

static func set_turns(turns: int) -> void:
	WorldClock.set_turn(turns)

# Враждебность мира растёт со временем партии (early-game-foundation)
const HOSTILITY_BASE := 1.0
const HOSTILITY_GROWTH_PER_TURN := 0.02
const HOSTILITY_CAP := 2.0

static func hostility_mult() -> float:
	return minf(HOSTILITY_BASE + float(WorldClock.get_turn()) * HOSTILITY_GROWTH_PER_TURN, HOSTILITY_CAP)
