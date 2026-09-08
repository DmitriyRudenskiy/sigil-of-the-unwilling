class_name Follower
extends RefCounted

var uid := 0
var name := ""
var race: StringName = &"human"
var path: StringName = &"unaligned"
var archetype: StringName = &""
var trait_ids: Array[StringName] = []
var stat_modifiers: Dictionary = {}
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
