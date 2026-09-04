class_name ArenaStorm
extends RefCounted
## Механика шторма (M3): шторм на каждом STORM_PERIOD-м ходе снижает
## производство (STORM_PRODUCTION_MULT, смягчается стенами ур. 2+) и съедает
## еду (STORM_FOOD, смягчается до STORM_MITIGATED_FOOD). Перенос из
## CityArenaModel.

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const City := preload("res://scripts/world/City.gd")


## Шторм на каждом STORM_PERIOD-м ходе (turn % N == 0, turn > 0).
static func is_storm_turn(turn: int) -> bool:
	return turn > 0 and ArenaBalance.STORM_PERIOD > 0 \
		and turn % ArenaBalance.STORM_PERIOD == 0


static func _has_walls_lvl2(city: City) -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"walls" and b.level >= 2:
			return true
	return false


## Множитель производства в шторм (1.0 = шторма нет).
static func storm_production_mult(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 1.0
	if _has_walls_lvl2(city):
		return ArenaBalance.STORM_MITIGATED_PRODUCTION_MULT
	return ArenaBalance.STORM_PRODUCTION_MULT


## Потери еды от шторма (вычитается после экономики).
static func storm_food_penalty(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 0.0
	if _has_walls_lvl2(city):
		return ArenaBalance.STORM_MITIGATED_FOOD
	return ArenaBalance.STORM_FOOD
