class_name HeroBuildProfile
extends RefCounted

const _Races = preload("res://scripts/data/hero_races.gd")
const _Classes = preload("res://scripts/data/hero_classes.gd")
const _Cultures = preload("res://scripts/data/hero_cultures.gd")

var name: String = ""
var sex: String = "male"
var race: String = ""
var subrace: String = ""
var character_class: String = ""
var culture: String = ""
var background: String = ""

# social-stats-weapon-tech: 4 боевых + 4 социальных (int/wis/cha/luk)
var base_stats: Dictionary = {"attack": 2, "defense": 2, "spell_power": 2, "knowledge": 2,
	"int": 2, "wis": 2, "cha": 2, "luk": 2}

func is_valid() -> bool:
	return not name.is_empty() and not race.is_empty() \
		and not character_class.is_empty() and not culture.is_empty() \
		and not background.is_empty()

func get_stats() -> Dictionary:
	var s := base_stats.duplicate()
	s = _add_bonuses(race, _Races.RACES, s)
	s = _add_bonuses(character_class, _Classes.CLASSES, s)
	s = _add_bonuses(culture, _Cultures.CULTURES, s)
	s = _add_bonuses(background, _Cultures.BACKGROUNDS, s)
	return s

func summary() -> Dictionary:
	return {
		"name": name if not name.is_empty() else "—",
		"sex": GameText.creation_sex_male() if sex == "male" else GameText.creation_sex_female(),
		"race": _label(_Races.RACES, race),
		"subrace": _label_subrace(race),
		"class": _label(_Classes.CLASSES, character_class),
		"culture": _label(_Cultures.CULTURES, culture),
		"background": _label(_Cultures.BACKGROUNDS, background),
		"stats": get_stats(),
	}

func to_identity() -> Dictionary:
	return {
		"hero_name": name,
		"hero_race": race,
		"hero_class": character_class,
		"hero_culture": culture,
		"hero_background": background,
		"hero_stats": get_stats(),
	}

func _add_bonuses(key: String, table: Dictionary, s: Dictionary) -> Dictionary:
	if not table.has(key):
		return s
	var bonuses: Dictionary = table[key].get("bonuses", {})
	for stat in bonuses:
		s[stat] = int(s.get(stat, 0)) + int(bonuses[stat])
	return s

func _label(table: Dictionary, key: String) -> String:
	if key.is_empty() or not table.has(key):
		return "—"
	return table[key].get("name", key)

func _label_subrace(race_key: String) -> String:
	if race_key.is_empty() or not _Races.RACES.has(race_key):
		return ""
	var subraces: Array = _Races.RACES[race_key].get("subraces", [])
	if subraces.is_empty():
		return ""
	if subrace.is_empty():
		return subraces[0].get("name", "")
	for sub in subraces:
		if sub.get("id", "") == subrace:
			return sub.get("name", subrace)
	return subrace
