extends BaseTest

## 3.8 (референс композиции): порядок отрисовки фигур — по ряду, иначе перекрывающиеся
## силуэты читаются кашей, а не глубиной.


func test_unit_z_follows_row() -> void:
	assert_int(BattleView.unit_z(0)).is_less(BattleView.unit_z(1)) \
		.override_failure_message("ближний к нижнему краю ряд обязан рисоваться поверх дальнего")
	assert_int(BattleView.unit_z(0)).is_greater(5) \
		.override_failure_message("фигуры обязаны быть поверх подсветки поля (z=5)")
	assert_int(BattleView.unit_z(BattleState.BH - 1)).is_less(20) \
		.override_failure_message("фигуры не имеют права перекрывать подписи урона (z=20)")
