class_name ArenaStorm
extends RefCounted

const City := preload("res://scripts/world/City.gd")


static func is_storm_turn(turn: int) -> bool:
	return turn > 0 and GameNumbers.ARENA_STORM_PERIOD > 0 \
		and turn % GameNumbers.ARENA_STORM_PERIOD == 0


static func _has_walls_lvl2(city: City) -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"walls" and b.level >= 2:
			return true
	return false


static func storm_production_mult(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 1.0
	if _has_walls_lvl2(city):
		return GameNumbers.ARENA_STORM_MITIG_MULT
	return GameNumbers.ARENA_STORM_PROD_MULT


static func storm_food_penalty(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 0.0
	if _has_walls_lvl2(city):
		return GameNumbers.ARENA_STORM_MITIG_FOOD
	return GameNumbers.ARENA_STORM_FOOD
