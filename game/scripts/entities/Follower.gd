class_name Follower
extends RefCounted
## city-in-world: именованный последатель героя. Индивид, вышедший из
## населения города: имя, черты (id из TraitRegistry), путь героя (class path),
## раса (матрица рас-классов Pathfinder).
## Раса/класс/архетип назначаются при найме (FollowerSystem.recruit); раса даёт
## модификаторы характеристик (stat_modifiers), класс — способности (abilities).
## Чистый RefCounted — персистентность через serialize/deserialize.

var uid := 0
var name := ""
## Раса (один из 7 в races_classes.json), напр. &"elf".
var race: StringName = &"human"
## Класс (один из 16), напр. &"wizard".
var path: StringName = &"unaligned"
## Архетип класса (пусто = базовый класс), напр. &"arcane_tradition".
var archetype: StringName = &""
## Ids черт (TraitRegistry). Храним id — разбор на TraitDef делает UI/системы
## через реестр (Follower не зависит от конкретного реестра).
var trait_ids: Array[StringName] = []
## Модификаторы характеристик от расы: StringName (STR/DEX/CON/INT/WIS/CHA) → int.
var stat_modifiers: Dictionary = {}
## Способности: features класса + traits расы (подписи, как StringName).
var abilities: Array[StringName] = []


func serialize() -> Dictionary:
	var abils: Array[String] = []
	for a in abilities:
		abils.append(String(a))
	return {
		"uid": uid,
		"name": name,
		"race": String(race),
		"path": String(path),
		"archetype": String(archetype),
		"traits": trait_ids.duplicate(),
		"stat_modifiers": _mods_to_array(),
		"abilities": abils,
	}


func _mods_to_array() -> Array:
	var out: Array = []
	for k in stat_modifiers:
		out.append([String(k), int(stat_modifiers[k])])
	return out


## JSON-совместимый словарь (сокет GET_STATE / ответ CITY_HIRE):
## StringName → String, traits/abilities — Array[String], stat_modifiers — Array[[k,v]].
func to_dict() -> Dictionary:
	var traits: Array[String] = []
	for id in trait_ids:
		traits.append(String(id))
	var abils: Array[String] = []
	for a in abilities:
		abils.append(String(a))
	var mods: Array = []
	for k in stat_modifiers:
		mods.append([String(k), int(stat_modifiers[k])])
	return {
		"uid": uid,
		"name": name,
		"race": String(race),
		"path": String(path),
		"archetype": String(archetype),
		"traits": traits,
		"stat_modifiers": mods,
		"abilities": abils,
	}


func deserialize(data: Dictionary) -> void:
	uid = int(data.get("uid", 0))
	name = String(data.get("name", name))
	race = StringName(data.get("race", "human"))
	path = StringName(data.get("path", "unaligned"))
	archetype = StringName(data.get("archetype", ""))
	trait_ids.clear()
	for id in data.get("traits", []):
		trait_ids.append(StringName(id))
	stat_modifiers.clear()
	for kv in data.get("stat_modifiers", []):
		if kv is Array and kv.size() == 2:
			stat_modifiers[kv[0]] = int(kv[1])
	abilities.clear()
	for a in data.get("abilities", []):
		abilities.append(StringName(a))


## Человекочитаемая строка для UI: «Имя (Раса, Класс, [Архетип], черты)».
func describe(registry: Variant = null) -> String:
	var out := name
	var parts: Array[String] = []
	if not race.is_empty():
		parts.append(race)
	if not path.is_empty():
		parts.append(path)
	if not archetype.is_empty():
		parts.append(archetype)
	if not parts.is_empty():
		out += " (" + ", ".join(parts) + ")"
	if registry != null and registry.has_method("get_trait"):
		var labels: Array = []
		for id in trait_ids:
			var t = registry.get_trait(id)
			if t != null:
				labels.append(t.display_name)
		if not labels.is_empty():
			out += ", " + ", ".join(labels)
	return out
