extends BaseTest


func _load(dict: Dictionary) -> RefCounted:
	var sd := SaveData.new()
	sd.from_dict(dict)
	return sd

func test_from_dict_garbage_hero() -> void:
	var sd := _load({"version": 7, "run_seed": 1, "hero": "oops", "world": {}})
	assert_bool(sd.hero is Dictionary).is_true()

func test_from_dict_garbage_world() -> void:
	var sd := _load({"version": 7, "run_seed": 1, "hero": {"cell": {"x": 0, "y": 0}}, "world": "oops"})
	assert_bool(sd.world is Dictionary).is_true()

func test_from_dict_missing_hero() -> void:
	var sd := _load({"version": 7, "run_seed": 1})
	assert_bool(sd.is_valid()).is_false()

func test_from_dict_future_version() -> void:
	var sd := _load({"version": 999, "run_seed": 1, "hero": {"cell": {"x": 0, "y": 0}}, "world": {}})
	assert_that(sd.version).is_equal(SaveData.CURRENT_VERSION)

func test_from_dict_garbage_collections() -> void:
	var sd := _load({
		"version": 1, "run_seed": 42,
		"hero": {"cell": {"x": 1, "y": 1}, "time_mp_spent": 0.0},
		"world": {"shard": 1},
		"cities": "oops", "characters": 5, "chronicle": "oops", "shards": "oops",
	})
	assert_bool(sd.cities is Array).is_true()
	assert_bool(sd.characters is Array).is_true()
	assert_bool(sd.chronicle is Array).is_true()
	assert_bool(sd.shards is Dictionary).is_true()
	assert_bool(sd.is_valid()).is_true()

func test_from_dict_garbage_date() -> void:
	var sd := _load({"version": 7, "run_seed": 1, "hero": {"cell": {"x": 0, "y": 0}}, "world": {}, "date": "oops"})
	assert_that(sd.date.get("month", 0)).is_equal(1)
