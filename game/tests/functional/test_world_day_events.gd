extends BaseTest

## Q-M141 → (а): мир — носитель дня и носитель панели события.
##
## До этой правки у `GameManager.on_day_passed()` был один писатель — кнопка хода
## кампейн-HUD (`scripts/main/main.gd:187`), а сам `GameManager` с `UIManager` и
## `CrisisEventSystem` существовал только как нода `scenes/main/main.tscn`. Снос
## кампейн-шелла (задача 3.2) оставлял каталог `game/data/events/` без вызова
## вообще — ровно та формулировка, которую D-198 назвал ложной.
##
## Провержаются три звена цепи, а не одно:
## 1) носитель — тройка монтируется world-бутстрапом и резолвится группами
##    (`game_manager` / `ui_manager`), как того требует контракт систем;
## 2) драйвер — `EndTurnButton` мира двигает день `GameManager`;
## 3) панель — `trigger_event` поднимает popup `UIManager` (звено, которого в
##    прод-пути не было никогда: `show_decision_panel` не вызывал никто).

const _WORLD_SCENE := "res://scenes/ui/adventure_ui.tscn"

var _main: Node = null


func after_test() -> void:
	# Панель события живёт в /root, а не в носителе; её снимает с себя сам
	# UIManager в `_exit_tree` — здесь только освобождение носителя.
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


func _boot_world() -> Node:
	var window := Engine.get_main_loop().root as Window
	window.size = Vector2i(1920, 1080)
	_main = load(_WORLD_SCENE).instantiate()
	Engine.get_main_loop().root.add_child(_main)
	for i in 120:
		await get_tree().process_frame
		if _main.get("_event_router") != null:
			break
	return _main


func _game_manager() -> Node:
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	assert_that(gm).is_not_null()  # мир обязан монтировать GameManager (Q-M141 (а))
	return gm


func _event_system(gm: Node) -> CrisisEventSystem:
	var es: CrisisEventSystem = gm.get_node_or_null("CrisisEventSystem")
	assert_that(es).is_not_null()
	return es


func test_world_carrier_mounts_the_event_trio() -> void:
	await _boot_world()
	var gm := _game_manager()
	assert_that(gm.get_node_or_null("UIManager")).is_not_null()
	assert_that(get_tree().get_first_node_in_group("ui_manager")).is_not_null()
	var es := _event_system(gm)
	assert_that(es.event_templates).is_not_empty()  # каталог событий загружен


func test_world_end_turn_advances_the_manager_day() -> void:
	var world := await _boot_world()
	var gm := _game_manager()
	var day_before: int = int(gm.current_day)
	world.get("_event_router").request_end_turn()
	assert_int(int(gm.current_day)).is_equal(day_before + 1)


func test_triggered_event_raises_the_decision_panel() -> void:
	await _boot_world()
	var gm := _game_manager()
	var es := _event_system(gm)
	var um: Node = get_tree().get_first_node_in_group("ui_manager")
	assert_that(um.current_decision_popup).is_null()
	es.trigger_event(es.event_templates[0])
	await get_tree().process_frame
	# Событие обязано поднять панель: путь «событие → выбор игрока».
	assert_that(um.current_decision_popup).is_not_null()
