class_name RaceDef
extends RefCounted
const _Self := preload("res://scripts/data/RaceDef.gd")

var id: StringName = &""
var name: String = ""
var size: String = "medium"
var speed: int = 30
var ability_adjustments: Dictionary = {}
var traits: Array[String] = []
var subraces: Array[Dictionary] = []

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"size": size,
		"speed": speed,
		"ability_adjustments": ability_adjustments.duplicate(),
		"traits": traits.duplicate(),
		"subraces": subraces.duplicate(),
	}


static func from_dict(data: Dictionary) -> _Self:
	var d := _Self.new()
	d.id = StringName(data.get("id", ""))
	d.name = String(data.get("name", ""))
	d.size = String(data.get("size", "medium"))
	d.speed = int(data.get("speed", 30))
	var mods: Dictionary = {}
	var src_mods: Dictionary = data.get("ability_adjustments", {}) as Dictionary
	for k in src_mods:
		mods[k] = int(src_mods[k])
	d.ability_adjustments = mods
	var traits: Array[String] = []
	for x in data.get("traits", []):
		traits.append(String(x))
	d.traits = traits
	var subs: Array[Dictionary] = []
	for x in data.get("subraces", []):
		subs.append(Dictionary(x))
	d.subraces = subs
	return d
