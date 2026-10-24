#extends GdUnitTestSuite
# tests/unit/combat/test_battle_screen.gd
# [AI]: сгенерировано по задачам 9.3–9.4 tasks.md, проверено человеком.
# Синхронность экрана с моделью: полоса HP = hp/max_hp в том же кадре, у мёртвого
# полоса пуста, метка и имя активного идут за очередью ходов.
#
# Экран намеренно проверяется без принятых картинок: он подписан на сигналы ядра,
# а не на дорожки, и отсутствие спрайтов (7.4) не должно менять значения.

extends GdUnitTestSuite

## Внутренняя ширина полосы: 96 px минус по пикселю поля с каждой стороны
## (метрика `docs/ui-spec.md`).
const BAR_INNER := 94.0


func _screen() -> BattleScreen:
	var screen := auto_free(load("res://scenes/battle.tscn").instantiate()) as BattleScreen
	add_child(screen)
	return screen


func _combat() -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([
			BattleFactory.stats(&"hero_a", 100, 20, 5, 90),
			BattleFactory.stats(&"hero_b", 80, 10, 5, 40),
		]),
		[BattleFactory.stats(&"foe_a", 120, 15, 5, 60)],
		7
	)


func _assert_bars_match(screen: BattleScreen, combat: CombatState) -> void:
	for unit in combat.units:
		var expected := BAR_INNER * float(unit.hp) / unit.stats.max_hp
		assert_float(screen.bar_of(unit).size.x).is_equal_approx(expected, 0.01)


func test_bars_match_the_model_after_every_action() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	_assert_bars_match(screen, combat)
	BattleFactory.auto_play(combat)
	_assert_bars_match(screen, combat)


func test_dead_unit_keeps_an_empty_bar() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	var fallen: Array[BattleUnit] = []
	for unit in combat.units:
		if not unit.is_alive():
			fallen.append(unit)
	assert_int(fallen.size()).is_greater(0)
	for unit in fallen:
		assert_float(screen.bar_of(unit).size.x).is_zero()


func test_marker_and_name_follow_the_queue() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var first := combat.current
	assert_float(screen.marker.position.x).is_equal(
		screen.field.view_of(first).position.x - 48.0
	)
	assert_str(screen.active_label.text).is_equal(first.stats.display_name)
	combat.perform(BattleAction.skip(first))
	var next := combat.current
	assert_float(screen.marker.position.x).is_equal(
		screen.field.view_of(next).position.x - 48.0
	)
	assert_str(screen.active_label.text).is_equal(next.stats.display_name)
