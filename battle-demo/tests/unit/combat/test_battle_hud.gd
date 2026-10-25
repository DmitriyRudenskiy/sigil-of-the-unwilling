#extends GdUnitTestSuite
# tests/unit/combat/test_battle_hud.gd
# Интерфейс по макету: панель показывает то, что считает ядро.
#
# Проверяются значения, а не пиксели: полоса состава = число юнитов боя, ячейки
# воли = focus активного, команда гаснет по причине ядра (кулдаун), рассадка —
# по разным клеткам сетки, свои слева от противника.

extends GdUnitTestSuite

## Юнит с кулдауном: после применения кнопка обязана погаснуть с подписью.
const COOLDOWN := 3


func _screen() -> BattleScreen:
	var screen := auto_free(load("res://scenes/battle.tscn").instantiate()) as BattleScreen
	add_child(screen)
	return screen


func _combat() -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([
			BattleFactory.stats(
				&"hero_a", 100, 20, 5, 90,
				[BattleFactory.ability(&"smite", 1, COOLDOWN)]
			),
			BattleFactory.stats(&"hero_b", 80, 10, 5, 40),
		]),
		[BattleFactory.stats(&"foe_a", 400, 1, 5, 60)],
		7
	)


func test_strip_has_one_card_per_unit() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.strip_count()).is_equal(combat.units.size())


func test_focus_pips_match_the_active_unit() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.active_focus_pips()).is_equal(combat.current.focus)


## Кольцо держит номер играемого хода. `+ 1` в нём был off-by-one: кольцо
## обновляется уже после `turn_index += 1`, и на кадре результата спорило с
## «Ходов:» (22 против 21, read-отчёт 2026-10-26).
func test_round_counter_follows_the_queue() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.round_number()).is_equal(maxi(combat.turn_index, 1))
	combat.perform(BattleAction.skip(combat.current))
	assert_int(screen.hud.round_number()).is_equal(combat.turn_index)


## Те же ходы в двух местах экрана: кольцо на поле и «Ходов:» на результате
## обязаны назвать одно число.
func test_round_counter_agrees_with_the_result_note() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_str(screen.result_view.note_text()).is_equal(
		"Ходов: %d" % screen.hud.round_number()
	)


## Цвет полосы HP кодирует сторону: правый блок не обязан притворяться своим
## (полосы на поле это делали всегда, панели полководцев — нет).
func test_hp_bar_colour_encodes_the_side() -> void:
	var screen := _screen()
	screen.run(_combat())
	var mine := screen.hud.commander_hp_color(BattleUnit.SIDE_PLAYER)
	assert_bool(mine == BattleHud.HP_FILL).is_true()
	var enemy := screen.hud.commander_hp_color(BattleUnit.SIDE_ENEMY)
	assert_bool(enemy == BattleHud.HP_FILL_ENEMY).is_true()


func test_ability_button_goes_dark_on_cooldown() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var actor := combat.current
	assert_bool(screen.hud.command_enabled(&"smite")).is_true()
	screen.hud.command(&"smite").emit_signal(&"pressed")
	# Панель показывает команды активного юнита: за кулдауном смотрим в тот ход,
	# когда способность снова принадлежит активному юниту.
	while not combat.finished and combat.current != actor:
		combat.perform(BattleAction.skip(combat.current))
	assert_str(screen.hud.command_reason(&"smite")).is_equal("перезарядка")
	assert_bool(screen.hud.command_enabled(&"smite")).is_false()


func test_dead_units_leave_the_order_strip() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var victim: BattleUnit = combat.foes_of(combat.current)[0]
	victim.hp = 0
	screen.hud.refresh()
	assert_int(screen.hud.strip_count()).is_equal(combat.units.size() - 1)


## После конца боя воевать нечем: `CombatState.perform` на финише утверждает,
## поэтому висящая кнопка была бы падением, а не ходом.
func test_no_commands_once_the_battle_is_over() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_int(screen.hud.command_count()).is_equal(0)
	# И подпись-причина тоже уходит: без кнопок она повисает сиротой у края.
	assert_bool(not screen.hud.reason.visible)


## Ход противника разыгрывается внутри `_advance` (ИИ ходит сразу, как только
## очередь до него доходит), поэтому UI чужого хода не видит вовсе: панель
## команд заполняется только своим юнитом. Специка 9.6 — «для юнита противника
## действий нет».
func test_the_ui_never_gets_an_enemy_turn() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	for _turn in 12:
		if combat.finished:
			break
		assert_int(combat.current.side).is_equal(BattleUnit.SIDE_PLAYER)
		assert_int(screen.hud.command_count()).is_greater(0)
		combat.perform(BattleAction.skip(combat.current))


## Панель полководца противника не пустеет после победы: на ней остаётся
## поверженный с нулём HP. Прочерк вместо имени — потерянное значение (кадр
## `a_result`, read-агент 2026-10-26).
func test_defeated_commander_stays_on_his_panel() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_str(screen.hud.commander_name(BattleUnit.SIDE_ENEMY)).is_equal("foe_a")
	assert_str(screen.hud.commander_note(BattleUnit.SIDE_ENEMY)).contains("0 / 400")
	# Воля у поверженного не горит: залитые пипсы читались как живой ресурс.
	assert_int(screen.hud.commander_focus_pips(BattleUnit.SIDE_ENEMY)).is_zero()


func test_units_stand_on_distinct_hexes_of_their_own_flank() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var cells := {}
	for unit in combat.units:
		var cell: Vector2i = screen.field.cell_of(unit)
		assert_bool(str(cell) in cells).is_false()
		cells[str(cell)] = true
	var foes: Array[BattleUnit] = combat.foes_of(combat.units[0])
	assert_float(screen.field.view_of(combat.units[0]).position.x).is_less(
		screen.field.view_of(foes[0]).position.x
	)


## 10.13: команды — колонкой за правым краем поля. 1500 px — правый край самого
## правого силуэта (клетка col 7 + половина фигуры в масштабе 2.2); строкой
## внизу кнопки ложились на сетку и на волков.
func test_commands_stand_clear_of_the_field() -> void:
	var screen := _screen()
	screen.run(_combat())
	var shown := 0
	for button in screen.hud.commands.get_children():
		if not is_instance_valid(button) or not button.visible:
			continue
		shown += 1
		var rect: Rect2 = button.get_rect()
		# Правый край — в кадре (24 px от кромки), левый — за правым силуэтом
		# поля: клетка col 7 плюс половина фигуры в текущем масштабе (~1590 px).
		assert_bool(rect.position.x >= 1600.0)
		assert_bool(rect.end.x <= screen.hud.VIEWPORT_WIDTH - 24.0)
		# Подпись не залезает на рамку пилюли: «Танец кинжалов» на 216 px
		# выступал за кнопку (read-агент 2026-10-25, `a_start`).
		var text_w: float = button.get_theme_font("font").get_string_size(
			button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			button.get_theme_font_size("font")).x
		assert_bool(text_w <= rect.size.x - 24.0)
	assert_int(shown).is_greater(0)


## Итерация 2 (read-агент 2026-10-25): круг счётчика лежал на верхнем ряду
## гексов, подпись активного юнита — на нижнем. Оба стоят в тёмной полосе над
## полем: нижняя кромка не касается верхней вершины сетки, подпись не залезает
## ни на панели командиров, ни на счётчик.
func test_the_top_band_holds_the_counter_and_the_name() -> void:
	var screen := _screen()
	var field_top: float = BattleField.HEX_ORIGIN.y - BattleField.HEX_RADIUS
	var strip_bottom: float = screen.hud.STRIP_TOP + screen.hud.STRIP_CELL
	var counter: Rect2 = screen.hud.counter_rect()
	assert_bool(counter.position.y >= strip_bottom)
	assert_bool(counter.end.y <= field_top)
	var name_rect: Rect2 = screen.active_label.get_rect()
	assert_bool(name_rect.position.y >= strip_bottom)
	assert_bool(name_rect.end.y <= field_top)
	assert_bool(not name_rect.intersects(counter))


## Полоса противника отличается от своей: зелёная у обеих сторон читалась как
## «свои» (read-агент: «враг-волк справа с зелёной полосой как свои»).
func test_enemy_bars_are_a_different_colour() -> void:
	var screen := _screen()
	screen.run(_combat())
	var mine: ColorRect = null
	var foe: ColorRect = null
	for unit in screen.combat.units:
		if unit.side == BattleUnit.SIDE_PLAYER:
			mine = screen.bar_of(unit)
		else:
			foe = screen.bar_of(unit)
	assert_bool(mine.color != foe.color)
	assert_bool(foe.color != screen.BAR_TRACK)


## Карточка текущего юнита обведена золотом, и отметка идёт за очередью. Тест
## был заявлен в `docs/ui-review-2026-10-25.md`, но не написан — написан здесь.
func test_the_current_card_is_outlined_in_gold() -> void:
	var screen := _screen()
	screen.run(_combat())
	assert_str(screen.hud.marked_card_uid()).is_equal(screen.combat.current.uid())
	screen.combat.perform(BattleAction.skip(screen.combat.current))
	assert_str(screen.hud.marked_card_uid()).is_equal(screen.combat.current.uid())
