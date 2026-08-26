extends RefCounted
class_name SaveData
## Save file data container.

const CURRENT_VERSION := 1
const CURRENT_GENERATOR_VERSION := 1

var version: int = CURRENT_VERSION
var generator_version: int = CURRENT_GENERATOR_VERSION
var run_seed: int = 0
var date: Dictionary = {"month": 1, "week": 1, "day": 1}
var hero: Dictionary = {}
var world: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": version,
		"generator_version": generator_version,
		"run_seed": run_seed,
		"date": date,
		"hero": hero,
		"world": world,
	}


func from_dict(data: Dictionary) -> void:
	version = int(data.get("version", 1))
	generator_version = int(data.get("generator_version", 1))
	run_seed = int(data.get("run_seed", 0))
	date = data.get("date", {"month": 1, "week": 1, "day": 1})
	hero = data.get("hero", {})
	world = data.get("world", {})


func is_valid() -> bool:
	return version == CURRENT_VERSION and run_seed > 0
