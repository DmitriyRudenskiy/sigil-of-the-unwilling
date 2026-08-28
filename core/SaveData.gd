extends RefCounted
class_name SaveData
## Save file data container.

const CURRENT_VERSION := 2
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

	# Migrate save data across versions
	if version < 2:
		_migrate_v1_to_v2(data)
	version = CURRENT_VERSION

	run_seed = int(data.get("run_seed", 0))
	var raw_date = data.get("date", {})
	if not (raw_date is Dictionary):
		raw_date = {}

	date = {
		"month": int(raw_date.get("month", 1)),
		"week": int(raw_date.get("week", 1)),
		"day": int(raw_date.get("day", 1)),
	}
	hero = data.get("hero", {})
	world = data.get("world", {})

func _migrate_v1_to_v2(data: Dictionary) -> void:
	## v2: ensure hero.time_mp_spent exists for mana persistence
	if not data.has("hero"):
		data["hero"] = {}
	if not data["hero"].has("time_mp_spent"):
		data["hero"]["time_mp_spent"] = 0.0


func is_valid() -> bool:
	# Version is already migrated in from_dict(); we only need structural checks
	if run_seed <= 0:
		return false
	if not (hero is Dictionary) or hero.is_empty():
		return false
	if not hero.has("cell"):
		return false
	if not (hero["cell"] is Dictionary):
		return false
	if not (world is Dictionary):
		return false
	return true
