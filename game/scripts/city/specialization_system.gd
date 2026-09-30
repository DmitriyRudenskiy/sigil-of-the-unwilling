class_name SpecializationSystem
extends RefCounted

const MIN_LEVEL := 2
const FOOD_YIELD_MULT := 1.5
const TRADE_RATE_MULT := 1.25
const DEFENSE_BONUS := 5
const SCIENCE_PER_TURN := 2.0

const SPECIALIZATIONS: Array[StringName] = [
	&"agrarian", &"merchant", &"militarist", &"scholar",
]

static func is_available(city: City) -> bool:
	return city.level >= MIN_LEVEL

static func is_valid(id: StringName) -> bool:
	return SPECIALIZATIONS.has(id)

static func set_specialization(city: City, id: StringName) -> bool:
	if not is_valid(id) or not is_available(city):
		return false
	city.specialization = id

	city._invalidate_exploited()
	return true

static func is_active(city: City, id: StringName) -> bool:
	return city.specialization == id

static func food_yield_multiplier(city: City) -> float:
	return FOOD_YIELD_MULT if is_active(city, &"agrarian") else 1.0

static func trade_rate_multiplier(city: City) -> float:
	return TRADE_RATE_MULT if is_active(city, &"merchant") else 1.0

static func defense_bonus(city: City) -> int:
	return DEFENSE_BONUS if is_active(city, &"militarist") else 0

static func science_per_turn(city: City) -> float:
	return SCIENCE_PER_TURN if is_active(city, &"scholar") else 0.0
