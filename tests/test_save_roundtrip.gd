extends SceneTree
## Save/Load roundtrip: SaveData → SaveManager → roundtrip.

const _SaveData = preload("res://scripts/core/SaveData.gd")
const _WorldStateDelta = preload("res://scripts/world/WorldStateDelta.gd")
const _SaveManager = preload("res://scripts/core/SaveManager.gd")

func _init() -> void:
	var failed := 0
	failed += _test_save_data_roundtrip()
	failed += _test_world_delta_roundtrip()
	failed += _test_save_manager_write()

	if failed == 0:
		print("Save roundtrip tests passed")
	else:
		printerr("Save roundtrip tests failed: ", failed)
	await process_frame
	quit(1 if failed > 0 else 0)


func _test_save_data_roundtrip() -> int:
	var errors := 0
	var data := _SaveData.new()
	data.run_seed = 42
	data.date = {"month": 5, "week": 2, "day": 10}
	data.hero = {"cell": {"x": 10, "y": 20}, "move_points": 15}
	data.world = {"captured_villages": [{"x": 3, "y": 4}]}

	var dict := data.to_dict()

	var data2 := _SaveData.new()
	data2.from_dict(dict)

	if data2.run_seed != 42:
		printerr("run_seed mismatch")
		errors += 1
	if data2.hero["cell"]["x"] != 10:
		printerr("hero cell mismatch")
		errors += 1
	if not data2.is_valid():
		printerr("is_valid should be true")
		errors += 1

	return errors


func _test_world_delta_roundtrip() -> int:
	var errors := 0
	var delta := _WorldStateDelta.new()
	delta.add_village(Vector2i(1, 2))
	delta.add_defeated_enemy(Vector2i(5, 5))
	delta.add_removed_resource(Vector2i(3, 3))
	delta.add_opened_chest(Vector2i(7, 8))

	var dict := delta.serialize()

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)

	if delta2.captured_villages.size() != 1:
		printerr("village count mismatch")
		errors += 1
	if delta2.defeated_enemies[0] != Vector2i(5, 5):
		printerr("enemy cell mismatch")
		errors += 1
	if delta2.opened_chests.size() != 1:
		printerr("chest count mismatch")
		errors += 1

	return errors


func _test_save_manager_write() -> int:
	var errors := 0

	# Create a parent node for SaveManager (needs to be a Node)
	var parent := Node.new()
	parent.name = "TestParent"
	root.add_child(parent)

	var sm := _SaveManager.new()
	sm.name = "SaveManager"
	parent.add_child(sm)

	var data := _SaveData.new()
	data.run_seed = 12345
	data.hero = {"cell": {"x": 5, "y": 5}, "move_points": 10}
	data.world = {"captured_villages": []}

	var ok := sm.call("save_game", data) as bool
	if not ok:
		printerr("save_game failed")
		errors += 1

	var loaded: Variant = sm.call("load_game")
	if loaded == null:
		printerr("load_game returned null")
		errors += 1
	elif loaded.run_seed != 12345:
		printerr("loaded run_seed mismatch")
		errors += 1

	# Cleanup — синхронное освобождение
	sm.call("delete_save")
	sm.free()
	parent.free()

	return errors
