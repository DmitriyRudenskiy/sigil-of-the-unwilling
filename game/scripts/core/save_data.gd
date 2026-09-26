extends RefCounted
class_name SaveData

const CURRENT_VERSION := 7
const CURRENT_GENERATOR_VERSION := 1

var version: int = CURRENT_VERSION
var generator_version: int = CURRENT_GENERATOR_VERSION
var run_seed: int = 0
var date: Dictionary = {"month": 1, "week": 1, "day": 1}
var hero: Dictionary = {}
var world: Dictionary = {}
var cities: Array = []
var characters: Array = []
var successor: Dictionary = {}
var legend: Dictionary = {}
var session: Dictionary = {}
var chronicle: Array = []
var shards: Dictionary = {}
var active_shard_id: StringName = &"shard_1"

func to_dict() -> Dictionary:
	return {
		"version": version,
		"generator_version": generator_version,
		"run_seed": run_seed,
		"date": date,
		"hero": hero,
		"world": world,
		"cities": cities,
		"characters": characters,
		"successor": successor,
		"legend": legend,
		"session": session,
		"chronicle": chronicle,
		"shards": shards,
		"active_shard_id": str(active_shard_id),
	}

func from_dict(data: Dictionary) -> void:
	version = int(data.get("version", 1))
	generator_version = int(data.get("generator_version", 1))

	if version < 2:
		_migrate_v1_to_v2(data)
	if version < 3:
		_migrate_v2_to_v3(data)
	if version < 4:
		_migrate_v3_to_v4(data)
	if version < 5:
		_migrate_v4_to_v5(data)
	if version < 6:
		_migrate_v5_to_v6(data)
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
	var raw_hero = data.get("hero", {})
	hero = raw_hero if raw_hero is Dictionary else {}
	var raw_world = data.get("world", {})
	world = raw_world if raw_world is Dictionary else {}
	var raw_cities = data.get("cities", [])
	cities = raw_cities if raw_cities is Array else []
	var raw_chars = data.get("characters", [])
	characters = raw_chars if raw_chars is Array else []
	successor = data.get("successor", {})
	if not (successor is Dictionary):
		successor = {}
	legend = data.get("legend", {})
	if not (legend is Dictionary):
		legend = {}
	session = data.get("session", {})
	if not (session is Dictionary):
		session = {}
	chronicle = data.get("chronicle", [])
	if not (chronicle is Array):
		chronicle = []
	shards = data.get("shards", {})
	if not (shards is Dictionary):
		shards = {}
	var _ashard: String = str(data.get("active_shard_id", "shard_1"))
	active_shard_id = StringName(_ashard) if _ashard else &"shard_1"

func _migrate_v1_to_v2(data: Dictionary) -> void:
	if not data.has("hero"):
		data["hero"] = {}
	if not data["hero"].has("time_mp_spent"):
		data["hero"]["time_mp_spent"] = 0.0

func _migrate_v2_to_v3(data: Dictionary) -> void:
	if not data.has("cities") or not (data["cities"] is Array):
		data["cities"] = []
	if not data.has("characters") or not (data["characters"] is Array):
		data["characters"] = []

func _migrate_v3_to_v4(data: Dictionary) -> void:
	if not data.has("successor") or not (data["successor"] is Dictionary):
		data["successor"] = {}
	if not data.has("legend") or not (data["legend"] is Dictionary):
		data["legend"] = {}

	if not data["hero"].has("path_id"):
		data["hero"]["path_id"] = ""

func _migrate_v4_to_v5(data: Dictionary) -> void:
	if not data.has("session") or not (data["session"] is Dictionary):
		data["session"] = {}

func _migrate_v5_to_v6(data: Dictionary) -> void:
	if not data.has("chronicle") or not (data["chronicle"] is Array):
		data["chronicle"] = []

	if not data.has("shards") or not (data["shards"] is Dictionary):
		data["shards"] = {}

func is_valid() -> bool:
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
