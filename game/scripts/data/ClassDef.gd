class_name ClassDef
extends RefCounted
const _Self := preload("res://scripts/data/ClassDef.gd")

var id: StringName = &""
var name: String = ""
var hit_die: int = 6
var bab: String = "medium"
var saves: Dictionary = {}
var skill_points: int = 2
var class_skills: Array[String] = []
var spellcasting: Dictionary = {}
var class_resources: Array[Dictionary] = []
var features: Array[String] = []
var archetypes: Array[Dictionary] = []

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"hit_die": hit_die,
		"bab": bab,
		"saves": saves.duplicate(),
		"skill_points": skill_points,
		"class_skills": class_skills.duplicate(),
		"spellcasting": spellcasting.duplicate(),
		"class_resources": class_resources.duplicate(),
		"features": features.duplicate(),
		"archetypes": archetypes.duplicate(),
	}


static func from_dict(data: Dictionary) -> _Self:
	var d := _Self.new()
	d.id = StringName(data.get("id", ""))
	d.name = String(data.get("name", ""))
	d.hit_die = int(data.get("hit_die", 6))
	d.bab = String(data.get("bab", "medium"))
	d.saves = (data.get("saves", {}) as Dictionary).duplicate(true)
	d.skill_points = int(data.get("skill_points", 2))
	var skills: Array[String] = []
	for x in data.get("class_skills", []):
		skills.append(String(x))
	d.class_skills = skills
	var sc_raw = data.get("spellcasting", {})
	d.spellcasting = {} if sc_raw == null else (sc_raw as Dictionary).duplicate(true)
	var resources: Array[Dictionary] = []
	for x in data.get("class_resources", []):
		resources.append(Dictionary(x))
	d.class_resources = resources
	var features: Array[String] = []
	for x in data.get("features", []):
		features.append(String(x))
	d.features = features
	var arches: Array[Dictionary] = []
	for x in data.get("archetypes", []):
		arches.append(Dictionary(x))
	d.archetypes = arches
	return d


func is_spellcaster() -> bool:
	return spellcasting != {} and String(spellcasting.get("type", "")).is_empty() == false


func spellcasting_ability() -> StringName:
	return StringName(String(spellcasting.get("ability", "")))
