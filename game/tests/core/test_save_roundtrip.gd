extends GdUnitTestSuite

const _SaveData = preload("res://scripts/core/SaveData.gd")
const _WorldStateDelta = preload("res://scripts/world/WorldStateDelta.gd")
const _SaveManager = preload("res://scripts/core/SaveManager.gd")

var _sm: SaveManager
var _parent: Node

func before_test() -> void:
	_parent = Node.new()
	_parent.name = "TestParent"
	add_child(_parent)
	_sm = _SaveManager.new()
	_sm.name = "SaveManager"
	_parent.add_child(_sm)
	_sm.call("delete_save")

func after_test() -> void:
	_sm.call("delete_save")
	_sm.queue_free()
	_parent.queue_free()

func test_save_data_roundtrip() -> void:
	var data := _SaveData.new()
	data.run_seed = 42
	data.date = {"month": 5, "week": 2, "day": 10}
	data.hero = {"cell": {"x": 10, "y": 20}, "move_points": 15}
	data.world = {"captured_villages": [{"x": 3, "y": 4}]}

	var dict := data.to_dict()

	var data2 := _SaveData.new()
	data2.from_dict(dict)

	assert_that(data2.run_seed).is_equal(42)
	assert_that(data2.hero["cell"]["x"]).is_equal(10)
	assert_bool(data2.is_valid()).is_true()

func test_world_delta_roundtrip() -> void:
	var delta := _WorldStateDelta.new()
	delta.add_village(Vector2i(1, 2))
	delta.add_defeated_enemy(Vector2i(5, 5))
	delta.add_removed_resource(Vector2i(3, 3))
	delta.add_opened_chest(Vector2i(7, 8))

	var dict := delta.serialize()

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)

	assert_that(delta2.captured_villages.size()).is_equal(1)
	assert_that(delta2.defeated_enemies[0]).is_equal(Vector2i(5, 5))
	assert_that(delta2.opened_chests.size()).is_equal(1)
	assert_that(delta2.removed_resources[0]).is_equal(Vector2i(3, 3))

func test_save_manager_roundtrip() -> void:
	var data := _SaveData.new()
	data.run_seed = 12345
	data.hero = {"cell": {"x": 5, "y": 5}, "move_points": 10}
	data.world = {"captured_villages": []}

	var err: int = _sm.call("save_game", data)
	assert_that(err).is_equal(SaveManager.SaveError.OK)

	var loaded: Dictionary = _sm.call("load_game")
	assert_that(loaded.get("error")).is_equal(SaveManager.SaveError.OK)
	var data2: SaveData = loaded.get("data")
	assert_that(data2).is_not_null()
	assert_that(data2.run_seed).is_equal(12345)

	assert_that(int(data2.hero["cell"]["x"])).is_equal(5)

func test_load_missing_returns_file_not_found() -> void:
	var loaded: Dictionary = _sm.call("load_game")
	assert_that(loaded.get("error")).is_equal(SaveManager.SaveError.FILE_NOT_FOUND)
	assert_that(loaded.get("data")).is_null()

func test_delete_save_removes_file_from_disk() -> void:
	var data := _SaveData.new()
	data.run_seed = 999
	data.hero = {"cell": {"x": 1, "y": 1}, "move_points": 5}
	data.world = {"captured_villages": []}
	assert_that(_sm.call("save_game", data)).is_equal(SaveManager.SaveError.OK)

	var path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	assert_bool(FileAccess.file_exists(path)).is_true()

	var deleted: bool = _sm.call("delete_save")
	assert_bool(deleted).is_true()
	assert_bool(not FileAccess.file_exists(path)).is_true()

	var again: bool = _sm.call("delete_save")
	assert_bool(again).is_false()
