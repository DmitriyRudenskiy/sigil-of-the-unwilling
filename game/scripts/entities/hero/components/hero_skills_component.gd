class_name HeroSkillsComponent
extends HeroComponent

var skills: HeroSkills = HeroSkills.new()

signal skills_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	skills.skills_changed.connect(skills_changed.emit)

func set_skills(v: HeroSkills) -> void:
	skills = v

func get_skill(skill: StringName) -> int:
	return skills.get_skill(skill)

func set_skill(skill: StringName, value: int) -> void:
	skills.set_skill(skill, value)

func add_point(skill: StringName) -> void:
	skills.add_point(skill)

func has_detection_key(skill: StringName) -> bool:
	return skills.has_detection_key(skill)

func get_yield_multiplier(skill: StringName) -> float:
	return skills.get_yield_multiplier(skill)

func get_all() -> Dictionary:
	return skills.get_all()

func reset() -> void:
	skills.reset()

func serialize() -> Dictionary:
	return {"skills": skills.get_all()}

func deserialize(data: Dictionary) -> void:
	var saved: Dictionary = data.get("skills", {})
	for sk in saved:
		skills.set_skill(StringName(sk), int(saved[sk]))
