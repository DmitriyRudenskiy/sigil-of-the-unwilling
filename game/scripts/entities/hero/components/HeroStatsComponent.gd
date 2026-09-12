class_name HeroStatsComponent
extends HeroComponent

var hero_name: String = "Darkstorn"
var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2}
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
	stats = data.get("stats", stats).duplicate()
	hero_race = str(data.get("hero_race", hero_race))
	hero_class = str(data.get("hero_class", hero_class))
	hero_culture = str(data.get("hero_culture", hero_culture))
	hero_background = str(data.get("hero_background", hero_background))
	path_id = StringName(str(data.get("path_id", path_id)))
	resurrected_once = bool(data.get("resurrected_once", false))
