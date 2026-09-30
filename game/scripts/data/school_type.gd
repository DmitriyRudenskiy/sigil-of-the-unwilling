class_name SchoolType
extends RefCounted

enum ID { AIR = 0, FIRE = 1, WATER = 2, EARTH = 3 }
const COUNT := 4

static func to_key(id: int) -> String:
	match id:
		ID.AIR: return "air"
		ID.FIRE: return "fire"
		ID.WATER: return "water"
		ID.EARTH: return "earth"
	return ""

static func to_display(id: int) -> String:
	return to_key(id).capitalize()

static func from_key(value: Variant) -> int:
	if value is int:
		return value if is_valid(value) else -1
	match str(value).to_lower():
		"air": return ID.AIR
		"fire": return ID.FIRE
		"water": return ID.WATER
		"earth": return ID.EARTH
	return -1

static func is_valid(id: int) -> bool: return id >= 0 and id < COUNT
static func all_ids() -> Array[int]: return [ID.AIR, ID.FIRE, ID.WATER, ID.EARTH]
