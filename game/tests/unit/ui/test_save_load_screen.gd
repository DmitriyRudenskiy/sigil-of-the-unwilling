extends BaseTest

const _ScreenScene = preload("res://scenes/ui/save_load_screen.tscn")


var _screen: SaveLoadScreen


func before_test() -> void:
	_clear_slots()
	_screen = _ScreenScene.instantiate()
	add_child(_screen)
	# TASK_19_1 T1: auto_free вместо ручного free/queue_free в after_test.
	auto_free(_screen)


func after_test() -> void:
	_clear_slots()


func _clear_slots() -> void:
	for slot in range(1, MvpSaveManager.SLOT_COUNT + 1):
		MvpSaveManager.delete_slot(slot)


## Минимальное состояние, проходимое `MvpSaveSchema`, — тот же срез, что у
## `tests/smoke/test_mvp_save.gd`. Экран читает из него только `campaign`.
func _state(turn: int, hero_name: String) -> Dictionary:
	return {
		"campaign": {"turn": turn, "seed": 12345, "phase": "player", "hero_name": hero_name},
		"resources": {"food": 30, "wood": 20, "iron": 10},
		"population": {"count": 20, "housing": 20},
		"party": [],
		"city": {"buildings": {}, "districts": []},
		"map": {"region": "R01", "fog": {}, "nodes": {}},
		"prestige": {"ledger": []},
		"sign": {"id": "R1", "progress": 0},
	}


func _slot_nodes(i: int) -> Dictionary:
	return {
		"info": _screen._slot_list.get_node("Slot%d/HBox/Info" % i),
		"load": _screen._slot_list.get_node("Slot%d/HBox/Buttons/LoadButton" % i),
		"del": _screen._slot_list.get_node("Slot%d/HBox/Buttons/DeleteButton" % i),
	}


## Рядов ровно столько, сколько слотов у носителя сейва. Экран держал пять кнопок
## при трёх слотах системы (T-307): два ряда не заполнил бы никогда, и «сохранений
## нет» читалось там, где слота не существует.
func test_rows_match_the_save_store() -> void:
	assert_int(_screen.SLOT_COUNT).is_equal(MvpSaveManager.SLOT_COUNT)
	assert_int(_screen._slot_list.get_child_count()) \
		.is_equal(MvpSaveManager.SLOT_COUNT)


func test_all_slots_empty_when_no_saves() -> void:
	_screen.open()
	for i in MvpSaveManager.SLOT_COUNT:
		var n := _slot_nodes(i)
		assert_bool(n["load"].disabled).is_true()
		assert_bool(n["del"].disabled).is_true()
		assert_that(n["info"].text).is_equal(GameText.no_save_found())


## Строка слота — то, что лежит в кампанийном сейве (ход, имя героя), а не легаси
## `SaveData.hero/.cities`: игра пишет другой формат.
func test_slot_shows_info_and_delete_clears_it() -> void:
	var saved: Dictionary = MvpSaveManager.save_slot(2, _state(7, "TestHero"))
	assert_bool(bool(saved.get("ok", false))).override_failure_message(str(saved)).is_true()
	_screen.open()
	var n := _slot_nodes(1)
	assert_bool(n["load"].disabled).is_false()
	assert_bool(n["del"].disabled).is_false()
	assert_bool(n["info"].text.contains("TestHero")).is_true()
	assert_bool(n["info"].text.contains(GameText.campaign_goal_day(7))).is_true()
	_screen.perform_delete(2)
	assert_bool(MvpSaveManager.has_save_in_slot(2)).is_false()
	n = _slot_nodes(1)
	assert_bool(n["load"].disabled).is_true()
	assert_that(n["info"].text).is_equal(GameText.no_save_found())


## Выключенная кнопка не эмитит, а пустой слот на нажатие отвечает причиной в том
## же экране (столп 1): до этой правки путь «нажалLoad в пустом» был не виден.
func test_press_on_filled_slot_asks_for_that_slot() -> void:
	MvpSaveManager.save_slot(3, _state(1, ""))
	_screen.open()
	var emitted: Array[int] = []
	_screen.load_requested.connect(func(slot: int) -> void: emitted.append(slot))
	(_slot_nodes(2)["load"] as Button).emit_signal("pressed")
	assert_array(emitted).is_equal([3])
