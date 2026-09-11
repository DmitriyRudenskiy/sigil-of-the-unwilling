extends GdUnitTestSuite

const _ScreenScene = preload("res://scenes/ui/SaveLoadScreen.tscn")
const _SaveManager = preload("res://scripts/core/SaveManager.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")

var _sm: SaveManager
var _screen: SaveLoadScreen

func before_test() -> void:
	_sm = _SaveManager.new()
	add_child(_sm)
	for s in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(s)
	_screen = _ScreenScene.instantiate()
	add_child(_screen)

func after_test() -> void:
	for s in range(1, SaveManager.SLOT_COUNT + 1):
		SaveManager.delete_slot(s)
	_screen.free()
	_sm.queue_free()

func _slot_nodes(i: int) -> Dictionary:
	return {
		"info": _screen._slot_list.get_node("Slot%d/HBox/Info" % i),
		"load": _screen._slot_list.get_node("Slot%d/HBox/Buttons/LoadButton" % i),
		"del": _screen._slot_list.get_node("Slot%d/HBox/Buttons/DeleteButton" % i),
	}

func test_all_slots_empty_when_no_saves() -> void:
	_screen.open("load")
	for i in SaveManager.SLOT_COUNT:
		var n := _slot_nodes(i)
		assert_bool(n["load"].disabled).is_true()
		assert_bool(n["del"].disabled).is_true()
		assert_that(n["info"].text).is_equal(GameText.no_save_found())

func test_slot_shows_info_and_delete_clears_it() -> void:
	var data := _SaveData.new()
	data.run_seed = 42
	data.hero = {"hero_name": "TestHero", "cell": {"x": 1, "y": 2}}
	data.cities = [{"uid": 1}, {"uid": 2}]
	assert_that(_sm.save_to_slot(data, 2)).is_equal(SaveManager.SaveError.OK)
	_screen.open("load")
	var n := _slot_nodes(1)
	assert_bool(n["load"].disabled).is_false()
	assert_bool(n["del"].disabled).is_false()
	assert_bool(n["info"].text.contains("TestHero")).is_true()
	_screen.perform_delete(2)
	assert_bool(SaveManager.has_save_in_slot(2)).is_false()
	n = _slot_nodes(1)
	assert_bool(n["load"].disabled).is_true()
	assert_that(n["info"].text).is_equal(GameText.no_save_found())

func test_slot_paths_clamped() -> void:
	assert_that(SaveManager.get_slot_path(1)).is_equal("user://save_slot_1.json")
	assert_that(SaveManager.get_slot_path(5)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(99)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(0)).is_equal("user://save_slot_1.json")
