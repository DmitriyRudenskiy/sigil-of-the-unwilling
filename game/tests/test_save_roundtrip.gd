extends "res://tests/gut_base.gd"
## Save/Load roundtrip: SaveData → SaveManager → roundtrip.
##
## SaveManager API (by design): save_game -> SaveError code,
## load_game -> {"error": SaveError, "data": SaveData|null, "message": String}.

const _SaveData = preload("res://scripts/core/SaveData.gd")
const _WorldStateDelta = preload("res://scripts/world/WorldStateDelta.gd")
const _SaveManager = preload("res://scripts/core/SaveManager.gd")

var _sm: SaveManager
var _parent: Node


func before_each() -> void:
	_parent = Node.new()
	_parent.name = "TestParent"
	add_child(_parent)
	_sm = _SaveManager.new()
	_sm.name = "SaveManager"
	_parent.add_child(_sm)
	_sm.call("delete_save")


func after_each() -> void:
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

	assert_eq(data2.run_seed, 42, "run_seed roundtrip")
	assert_eq(data2.hero["cell"]["x"], 10, "hero cell roundtrip")
	assert_true(data2.is_valid(), "is_valid after roundtrip")


func test_world_delta_roundtrip() -> void:
	var delta := _WorldStateDelta.new()
	delta.add_village(Vector2i(1, 2))
	delta.add_defeated_enemy(Vector2i(5, 5))
	delta.add_removed_resource(Vector2i(3, 3))
	delta.add_opened_chest(Vector2i(7, 8))

	var dict := delta.serialize()

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)

	assert_eq(delta2.captured_villages.size(), 1, "village count")
	assert_eq(delta2.defeated_enemies[0], Vector2i(5, 5), "enemy cell")
	assert_eq(delta2.opened_chests.size(), 1, "chest count")
	assert_eq(delta2.removed_resources[0], Vector2i(3, 3), "resource cell")


func test_save_manager_roundtrip() -> void:
	var data := _SaveData.new()
	data.run_seed = 12345
	data.hero = {"cell": {"x": 5, "y": 5}, "move_points": 10}
	data.world = {"captured_villages": []}

	var err: int = _sm.call("save_game", data)
	assert_eq(err, SaveManager.SaveError.OK, "save_game returns OK")

	var loaded: Dictionary = _sm.call("load_game")
	assert_eq(loaded.get("error"), SaveManager.SaveError.OK, "load_game error OK")
	var data2: SaveData = loaded.get("data")
	assert_not_null(data2, "load_game data present")
	assert_eq(data2.run_seed, 12345, "loaded run_seed")
	assert_eq(data2.hero["cell"]["x"], 5, "loaded hero cell")


func test_load_missing_returns_file_not_found() -> void:
	var loaded: Dictionary = _sm.call("load_game")
	assert_eq(loaded.get("error"), SaveManager.SaveError.FILE_NOT_FOUND, "missing save -> FILE_NOT_FOUND")
	assert_null(loaded.get("data"), "missing save -> null data")

## delete_save(): реальное удаление файла с диска + false при отсутствии.
func test_delete_save_removes_file_from_disk() -> void:
	var data := _SaveData.new()
	data.run_seed = 999
	data.hero = {"cell": {"x": 1, "y": 1}, "move_points": 5}
	data.world = {"captured_villages": []}
	assert_eq(_sm.call("save_game", data), SaveManager.SaveError.OK, "save ok")

	var path: String = ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	assert_true(FileAccess.file_exists(path), "файл есть на диске перед удалением")

	var deleted: bool = _sm.call("delete_save")
	assert_true(deleted, "delete_save -> true при наличии")
	assert_true(not FileAccess.file_exists(path), "файл удалён с диска")

	# Повторное удаление отсутствующего -> false, без ошибки.
	var again: bool = _sm.call("delete_save")
	assert_false(again, "delete_save -> false когда файла нет")
