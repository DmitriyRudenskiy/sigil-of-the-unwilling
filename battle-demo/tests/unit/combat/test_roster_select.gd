extends GdUnitTestSuite
# tests/unit/combat/test_roster_select.gd
# [AI]: сгенерировано по задаче 9.2 tasks.md.
#
# Выбор набора: отличия видно до выбора (спека `battle-demo-ui`), выбор живёт в
# маршруте демо, переход — одна клавиатура.


func _select() -> RosterSelect:
	var screen := auto_free(load("res://scenes/roster_select.tscn").instantiate()) as RosterSelect
	add_child(screen)
	return screen


func test_both_rosters_are_described_before_choice() -> void:
	var screen := _select()
	for id in DataLibrary.ROSTER_IDS:
		var roster := DataLibrary.load_roster(String(id))
		var text := screen.card_text(String(id))
		assert_bool(roster.title in text).is_true()
		assert_bool(roster.difference in text).is_true()
		for stats in roster.units:
			assert_bool(stats.display_name in text).is_true()


func test_selection_moves_between_cards() -> void:
	var screen := _select()
	assert_str(screen.selected_id()).is_equal("a")
	screen._unhandled_input(_action("ui_right"))
	assert_str(screen.selected_id()).is_equal("b")
	screen._unhandled_input(_action("ui_left"))
	assert_str(screen.selected_id()).is_equal("a")


## Событие действия, а не клавиша: проверяем обработчик выбора, а не маппинг
## движка (клавиши смотрятся кадром приёмки, задача 10.3).
func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func test_choice_is_written_to_the_flow() -> void:
	var screen := _select()
	var saved := DemoFlow.roster_id
	screen.select("b")
	screen.commit_choice()
	assert_str(DemoFlow.roster_id).is_equal("b")
	DemoFlow.roster_id = saved
