class_name HeroStatsComponent
extends HeroComponent

var hero_name: String = "Darkstorn"
# social-stats-weapon-tech: 8 статов (4 боевых + int/wis/cha/luk)
var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2, "int": 2, "wis": 2, "cha": 2, "luk": 2}
var hero_race: String = ""
var hero_class: String = ""
var hero_culture: String = ""
var hero_background: String = ""
var path_id: StringName = &""
var resurrected_once: bool = false

func apply_build(profile: HeroBuildProfile) -> void:
	if profile == null:
		return
	hero_name = profile.name if not profile.name.is_empty() else hero_name
	stats = profile.get_stats()
	hero_race = profile.race
	hero_class = profile.character_class
	hero_culture = profile.culture
	hero_background = profile.background

func get_battle_bonus(inventory_mods: Dictionary) -> Dictionary:
	return {
		"attack": int(stats.get("attack", 0)) + int(inventory_mods.get("attack", 0)),
		"defense": int(stats.get("defense", 0)) + int(inventory_mods.get("defense", 0)),
		"spell_power": int(stats.get("spell_power", 0)) + int(inventory_mods.get("spell_power", 0)),
		"knowledge": int(stats.get("knowledge", 0)) + int(inventory_mods.get("knowledge", 0)),
		"luck": int(inventory_mods.get("luck", 0)),
		"morale": int(inventory_mods.get("morale", 0)),
	}

func get_hero_bonus() -> Dictionary:
	return {
		"attack": stats.get("attack", 0),
		"defense": stats.get("defense", 0),
		"spell_power": stats.get("spell_power", 0),
	}

func serialize() -> Dictionary:
	return {
		"hero_name": hero_name,
		"stats": stats.duplicate(),
		"hero_race": hero_race,
		"hero_class": hero_class,
		"hero_culture": hero_culture,
		"hero_background": hero_background,
		"path_id": String(path_id),
		"resurrected_once": resurrected_once,
	}

func deserialize(data: Dictionary) -> void:
	hero_name = str(data.get("hero_name", hero_name))
	var loaded: Dictionary = data.get("stats", stats).duplicate()
	hero_race = str(data.get("hero_race", hero_race))
	hero_class = str(data.get("hero_class", hero_class))
	hero_culture = str(data.get("hero_culture", hero_culture))
	hero_background = str(data.get("hero_background", hero_background))
	path_id = StringName(str(data.get("path_id", path_id)))
	resurrected_once = bool(data.get("resurrected_once", false))
	stats = _migrate_social_stats(loaded)

# social-stats-weapon-tech D6: старый сейв (4 стата) — недостающие социальные
# пересчитываем из HeroBuildProfile.get_stats расы/класса/культуры, не хардкод 2
func _migrate_social_stats(loaded: Dictionary) -> Dictionary:
	const SOCIAL := ["int", "wis", "cha", "luk"]
	if loaded.has(SOCIAL[0]) and loaded.has(SOCIAL[3]):
		return loaded
	var profile := HeroBuildProfile.new()
	profile.race = hero_race
	profile.character_class = hero_class
	profile.culture = hero_culture
	profile.background = hero_background
	var base: Dictionary = profile.get_stats()
	for s in SOCIAL:
		if not loaded.has(s):
			loaded[s] = int(base.get(s, 2))
	return loaded
