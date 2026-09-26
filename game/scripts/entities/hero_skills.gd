extends RefCounted
class_name HeroSkills

signal skills_changed

var levels: Dictionary = {
	"nature_sense": 0,
	"keen_eye": 0,
	"navigation": 0,
	"geology": 0,
	"alchemy": 0,
}

func get_skill(skill: StringName) -> int:
	return levels.get(skill, 0)

func set_skill(skill: StringName, value: int) -> void:
	levels[skill] = clampi(value, 0, 3)
	skills_changed.emit()

func add_point(skill: StringName) -> void:
	set_skill(skill, get_skill(skill) + 1)

func has_detection_key(skill: StringName) -> bool:
	return get_skill(skill) >= 1

func get_yield_multiplier(skill: StringName) -> float:
	"""Level 0 = 0, Level 1 = 1.0, Level 2 = 1.5, Level 3 = 2.0"""
	var lvl: int = get_skill(skill)
	if lvl == 0:
		return 0.0
	return 1.0 + (lvl - 1) * 0.5

func get_all() -> Dictionary:
	return levels.duplicate()

func reset() -> void:
	for skill in levels:
		levels[skill] = 0
	skills_changed.emit()
