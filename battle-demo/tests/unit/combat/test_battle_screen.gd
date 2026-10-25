#extends GdUnitTestSuite
# tests/unit/combat/test_battle_screen.gd
# [AI]: сгенерировано по задачам 9.3–9.4 tasks.md.
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


## После конца боя активного нет: обводка клетки и подпись не должны висеть
## над полем (кадр `b_result`: «сирота-подпись без панели-носителя»). Обводка
## и подпись — единственный признак хода с задачи 10.12, полоски под ногами
## больше нет.
func test_active_cell_follows_the_queue() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_bool(screen.field.active_cell == screen.field.cell_of(combat.current))
	assert_str(screen.active_label.text).is_equal(combat.current.stats.display_name)
	combat.perform(BattleAction.skip(combat.current))
	assert_bool(screen.field.active_cell == screen.field.cell_of(combat.current))
	assert_str(screen.active_label.text).is_equal(combat.current.stats.display_name)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_int(screen.field.active_cell.x).is_equal(-1)
	assert_str(screen.active_label.text).is_empty()



## 10.11 (итерация 2): пустая полоса погибшего — тот же серый трек, что у
## живых, плюс крест над ней (read-агент: багряная полоса читалась как залитый
## HP, а без знака гибель не читалась вовсе).
func test_fallen_unit_is_marked_with_a_cross() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	var fallen := 0
	for unit in combat.units:
		var fill: ColorRect = screen.bar_of(unit)
		var track: ColorRect = fill.get_parent()
		var mark: Label = screen._marks[unit.uid()]
		assert_bool(track.color == screen.BAR_TRACK)
		if unit.is_alive():
			assert_bool(not mark.visible)
		else:
			fallen += 1
			# Гибель — пустая полоса + крест над ней. Багряная дорожка (10.11)
			# читалась как залитый HP, поэтому у мёртвого дорожка остаётся
			# штатной, а знак — отдельный.
			assert_float(fill.size.x).is_equal(0.0)
			assert_bool(mark.visible)
			assert_str(mark.text).is_equal(screen.DEATH_MARK)
	assert_int(fallen).is_greater(0)


## 10.10 (выбор владельца — мельчающие юниты): полоса HP нижнего ряда не лежит
## на спрайте верхнего и висит над головой своего. Считается от констант, а не
## от кадра: кто поднимет `UNIT_SCALE` или опустит `BAR_LIFT`, увидит падение
## здесь, а не через read-агента на `a_mid`.
func test_hp_bar_clears_the_row_above() -> void:
	# Холст кадра комплекта — 512, ступни в (256, 448); на экран он попадает с
	# масштабом вьюера, поэтому мировые расстояния считаются как
	# `(холст + смещение) × ENGINE_SCALE × UNIT_SCALE`.
	var canvas := 512.0
	var unit_scale := BattleField.UNIT_SCALE
	var view_scale := BattleUnitView.ENGINE_SCALE * unit_scale
	var pitch := sqrt(3.0) * BattleField.HEX_RADIUS  # шаг ряда odd-r
	var sprite_bottom := (canvas + BattleUnitView.FEET_OFFSET.y) * view_scale
	var bar_top := pitch - BattleScreen.BAR_LIFT * unit_scale - BattleScreen.BAR_SIZE.y
	# Полоса над головой своего юнита (спека: зазор ≥ 8 px).
	assert_float((BattleScreen.BAR_LIFT + BattleUnitView.FEET_OFFSET.y * BattleUnitView.ENGINE_SCALE)
			* unit_scale).is_greater_equal(8.0)
	# И не касается силуэта верхнего ряда.
	assert_float(bar_top - sprite_bottom).is_greater_equal(8.0)


## Гибель обесцвечивается тем же сигналом, что и полоса: `_process` вьюера
## догонял гибель кадром позже, и съёмка ловила цветного погибшего.
func test_the_fallen_sprite_is_desaturated_at_once() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	var fallen := 0
	for unit in combat.units:
		if not unit.is_alive():
			fallen += 1
			var view: BattleUnitView = screen.field.view_of(unit)
			assert_bool(view.modulate.is_equal_approx(BattleUnitView.DEAD_MODULATE))
	assert_int(fallen).is_greater(0)
