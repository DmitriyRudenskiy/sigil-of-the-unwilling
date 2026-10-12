extends BaseTest

const _ScreenScene = preload("res://scenes/ui/save_load_screen.tscn")


## Т-110-проводка (раунд 11 §1): бэкенд экрана — MvpSaveManager (3 слота);
## legacy SaveManager (5 слотов) — замороженный world-слой (Q-M31), здесь
## покрывается только test_slot_paths_clamped (его собственный API).
var _screen: SaveLoadScreen

func before_test() -> void:
	for s in range(1, MvpSaveManager.SLOT_COUNT + 1):
		MvpSaveManager.delete_slot(s)
	_screen = _ScreenScene.instantiate()
	add_child(_screen)
	# TASK_19_1 T1: auto_free вместо ручного free/queue_free в after_test.
	auto_free(_screen)

func after_test() -> void:
	for s in range(1, MvpSaveManager.SLOT_COUNT + 1):
		MvpSaveManager.delete_slot(s)

func _campaign_state(hero_name: String = "TestHero", turn: int = 3) -> Dictionary:
	return {
		"campaign": {"turn": turn, "seed": 12345, "phase": "exploration"},
		"resources": {"food": 30, "wood": 20, "iron": 10},
		"population": {"count": 20, "housing": 20},
		"party": [{"id": "hero_1", "hero_name": hero_name, "class": "fighter", "race": "gnome", "level": 1, "xp": 0, "stats": {"str": 15, "dex": 10, "con": 14, "int": 12, "wis": 11, "cha": 8}, "luck": 0}],
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

func test_all_slots_empty_when_no_saves() -> void:
	_screen.open("load")
	for i in SaveLoadScreen.SLOT_COUNT:
		var n := _slot_nodes(i)
		assert_bool(n["load"].disabled).is_true()
		assert_bool(n["del"].disabled).is_true()
		assert_that(n["info"].text).is_equal(GameText.no_save_found())
	# Сцена рисует 5 слотов (legacy); кампанийных — 3: лишние скрыты.
	for i in range(SaveLoadScreen.SLOT_COUNT, 5):
		var extra: Control = _screen._slot_list.get_node_or_null("Slot%d" % i)
		assert_object(extra).is_not_null()
		assert_bool(extra.visible).is_false()

func test_slot_shows_info_and_delete_clears_it() -> void:
	var result: Dictionary = MvpSaveManager.save_slot(2, _campaign_state("TestHero", 3))
	assert_that(bool(result.get("ok", false))).is_true().override_failure_message(str(result.get("message", "")))
	_screen.open("load")
	var n := _slot_nodes(1)
	assert_bool(n["load"].disabled).is_false()
	assert_bool(n["del"].disabled).is_false()
	assert_bool(n["info"].text.contains("TestHero")).is_true()
	assert_bool(n["info"].text.contains("3")).is_true()  # ход
	_screen.perform_delete(2)
	assert_bool(MvpSaveManager.has_save_in_slot(2)).is_false()
	n = _slot_nodes(1)
	assert_bool(n["load"].disabled).is_true()
	assert_that(n["info"].text).is_equal(GameText.no_save_found())

func test_slot_paths_clamped() -> void:
	assert_that(SaveManager.get_slot_path(1)).is_equal("user://save_slot_1.json")
	assert_that(SaveManager.get_slot_path(5)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(99)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(0)).is_equal("user://save_slot_1.json")
