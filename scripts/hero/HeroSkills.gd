extends RefCounted
class_name HeroSkills
## Hero exploration skills: levels 0-3.
## nature_sense, keen_eye, navigation, geology, alchemy.

signal skills_changed

var levels: Dictionary = {
	"nature_sense": 0,
	"keen_eye": 0,
	"navigation": 0,
	"geology": 0,
	"alchemy": 0,
}


func get(skill: StringName) -> int:
	return levels.get(skill, 0)


func set(skill: StringName, value: int) -> void:
	levels[skill] = clampi(value, 0, 3)
	skills_changed.emit()


func add_point(skill: StringName) -> void:
	set(skill, get(skill) + 1)


func has_detection_key(skill: StringName) -> bool:
	return get(skill) >= 1


func get_yield_multiplier(skill: StringName) -> float:
	"""Level 0 = 0, Level 1 = 1.0, Level 2 = 1.5, Level 3 = 2.0"""
	var lvl := get(skill)
	if lvl == 0:
		return 0.0
	return 1.0 + (lvl - 1) * 0.5


func get_all() -> Dictionary:
	return levels.duplicate()


func reset() -> void:
	for skill in levels:
		levels[skill] = 0
	skills_changed.emit()
