extends BaseTest

## ui-mockup-parity §5.4 — спека battle-hud, «Шквал событий»: количество
## одновременно видимых чисел не превышает установленный предел, элементы
## управления остаются кликабельными.

func _battle() -> Node:
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	auto_free(battle)
	add_child(battle)
	return battle


func test_flood_of_numbers_stays_under_the_limit() -> void:
	var battle := _battle()
	await await_millis(200)
	var view: BattleView = battle.get_node("BattleView")

	for i in BattleView.MAX_SIMULTANEOUS_NUMBERS * 3:
		view.show_floating_text(Vector2i(i % 8, floori(i / 8.0)), "-%d" % (i + 1), Color.RED)

	assert_int(view._numbers.size()).is_between(1, BattleView.MAX_SIMULTANEOUS_NUMBERS)

	await await_millis(50)
	var alive := 0
	for c in view.get_children():
		if c is Label and not c.is_queued_for_deletion():
			alive += 1
	assert_int(alive).is_between(1, BattleView.MAX_SIMULTANEOUS_NUMBERS)


func test_numbers_never_steal_clicks_from_the_controls() -> void:
	# Число живёт над полем и над панелями: если бы оно принимало мышь, кнопка
	# под ним перестала бы нажиматься ровно в момент удара.
	var battle := _battle()
	await await_millis(200)
	var view: BattleView = battle.get_node("BattleView")
	var ui: CanvasLayer = battle.get_node("BattleUI")

	view.show_floating_text(Vector2i(0, 0), "-100", Color.RED)
	await get_tree().process_frame
	# `_numbers` хранит instance id, а не узлы: метка умирает в tween-колбэке, и
	# обращение к освобождённомy узлу из typed-массива — это падение движка, а не
	# проверка (T-206).
	var number: Node = instance_from_id(view._numbers.back())
	assert_bool(is_instance_valid(number)).is_true()
	assert_int(number.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	# Панель действий обязана принимать мышь (спека: «элементы управления остаются
	# кликабельными»). До этого шага её кнопки стояли в MOUSE_FILTER_IGNORE —
	# единственные кликабельные-только-хоткеями кнопки на всю игру.
	for btn in [ui._attack_button, ui._defend_btn, ui._wait_btn, ui._skip_btn, ui._rescue_btn]:
		assert_int(btn.mouse_filter).is_not_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(ui._skip_btn.disabled).is_false()
