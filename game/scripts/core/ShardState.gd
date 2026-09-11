extends RefCounted
class_name ShardState
const _Self := preload("res://scripts/core/ShardState.gd")

var id: StringName = &"shard_1"
var name: String = "Shard"
var seed: int = 0
var biome_mix: String = ""
var entry_cell: Vector2i = Vector2i(10, 10)
var completed: bool = false

func _init(
	_id: StringName = &"shard_1",
	_name: String = "Shard",
	_seed: int = 0,
	_biome: String = "",
	_entry: Vector2i = Vector2i(10, 10)
) -> void:
	id = _id
	name = _name
	seed = _seed
	biome_mix = _biome
	entry_cell = _entry

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"seed": seed,
		"biome_mix": biome_mix,
		"entry_cell": [entry_cell.x, entry_cell.y],
		"completed": completed,
	}

static func from_dict(d: Dictionary) -> _Self:
	var e: Array = d.get("entry_cell", [10, 10])
	var s := _Self.new(
		d.get("id", &"shard_1"),
		d.get("name", "Shard"),
		int(d.get("seed", 0)),
		str(d.get("biome_mix", "")),
		Vector2i(int(e[0]), int(e[1])) if e.size() >= 2 else Vector2i(10, 10))
	s.completed = bool(d.get("completed", false))
	return s
