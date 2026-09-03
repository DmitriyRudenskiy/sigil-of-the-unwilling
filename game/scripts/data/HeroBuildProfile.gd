class_name HeroBuildProfile
extends RefCounted
## Профиль создания героя: имя, пол, раса, подраса, класс, культура, прошлое
## и выведенные характеристики. Чистая функция «сборка -> статы».
##
## Источник данных: hero_races.gd / hero_classes.gd / hero_cultures.gd.
##
## ponytail: ability->stat маппинг задокументирован ниже. Базовые статы равны,
## бонусы расы/класса/культуры/прошлого складываются. Никаких «скрытых»
## формул — get_stats() детерминирован по составу сборки.
##
## Маппинг (бонусы из полей «bonuses» таблиц данных):
##   race.bonuses, class.bonuses, culture.bonuses, background.bonuses
##   -> складываются по ключу (attack / defense / spell_power / knowledge)
##   с базовыми {attack:2, defense:2, spell_power:2, knowledge:2}.

const _Races = preload("res://scripts/data/hero_races.gd")
const _Classes = preload("res://scripts/data/hero_classes.gd")
const _Cultures = preload("res://scripts/data/hero_cultures.gd")

var name: String = ""
var sex: String = "male"
var race: String = ""          # ключ в _Races.RACES
var subrace: String = ""
var character_class: String = ""  # ключ в _Classes.CLASSES
var culture: String = ""       # ключ в _Cultures.CULTURES
var background: String = ""    # ключ в _Cultures.BACKGROUNDS

var base_stats: Dictionary = {"attack": 2, "defense": 2, "spell_power": 2, "knowledge": 2}

func is_valid() -> bool:
	return not name.is_empty() and not race.is_empty() \
		and not character_class.is_empty() and not culture.is_empty() \
		and not background.is_empty()

## Детерминированные характеристики по составу сборки.
func get_stats() -> Dictionary:
	var s := base_stats.duplicate()
	s = _add_bonuses(race, _Races.RACES, s)
	s = _add_bonuses(character_class, _Classes.CLASSES, s)
	s = _add_bonuses(culture, _Cultures.CULTURES, s)
	s = _add_bonuses(background, _Cultures.BACKGROUNDS, s)
	return s

## Отображаемые названия для сводки конструктора (RU).
func summary() -> Dictionary:
	return {
		"name": name if not name.is_empty() else "—",
		"sex": "Мужской" if sex == "male" else "Женский",
		"race": _label(_Races.RACES, race),
		"subrace": _label_subrace(race),
		"class": _label(_Classes.CLASSES, character_class),
		"culture": _label(_Cultures.CULTURES, culture),
		"background": _label(_Cultures.BACKGROUNDS, background),
		"stats": get_stats(),
	}

## Словарь идентичности героя для применения в WorldBootstrap / сериализации.
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
