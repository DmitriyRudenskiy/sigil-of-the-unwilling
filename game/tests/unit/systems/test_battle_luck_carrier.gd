extends BaseTest

## T-221 → D-268: Удача донесена до `BattleState.BattleUnit`.
##
## До среза мод Удачи был писателем без читателя: `artifact_registry.gd` выдаёт
## `{"luck": 1}`, `BattleStateBuilder._apply_artifact_effects` читал из мода только
## `stack_hp` / `stack_hp_percent` / `stack_speed`, а требование
## `Enemy stats visible` (M1) назвало удачу в перечне карточки — показать её было
## нечем. Срез закрывает разрыв с обеих сторон: писатель кладёт мод и источник на
## бойца, карточка печатает строку только когда источник есть.
##
## Ключевой инвариант — не «число доехало», а «число без носителя не печатается»:
## `luck = 0` при пустом `luck_source` означает «мод не применялся», и напечатать
## его как удачу означало бы соврать (тот же M1-принцип, что и скрытая строка
## способностей у не-dnd юнита). Поэтому отдельный кейс на «мод есть, источника
## нет» — строка обязана остаться скрытой.

const _BATTLE_UI := preload("res://scenes/ui/battle_ui.tscn")


func _stack(hp: int) -> UnitStack:
	var stats := UnitStats.new()
	stats.hp = hp
	stats.attack = 3
	stats.defense = 4
	var stack := UnitStack.new(stats, 1)
	return stack


func _state(mods: Dictionary) -> BattleState:
	var state := BattleState.new()
	state.place_army([_stack(20)], [_stack(18)], mods, mods)
	return state


func _ui() -> CanvasLayer:
	var ui: CanvasLayer = _BATTLE_UI.instantiate()
	auto_free(ui)
	add_child(ui)
	return ui


func test_luck_mod_reaches_the_unit_with_a_source() -> void:
	var state := _state({"luck": 1})
	var unit = state.defender_units[0]
	assert_bool(unit.has_luck()).is_true().override_failure_message(
		"мод Удачи не доехал до бойца — карточка по-прежнему нечем показать Удачу"
	)
	assert_int(unit.luck).is_equal(1)
	assert_str(String(unit.luck_source)).is_equal("artifact")


func test_attacker_side_gets_its_own_mod() -> void:
	var state := BattleState.new()
	state.place_army([_stack(20)], [_stack(18)], {"luck": 2}, {})
	assert_int(state.attacker_units[0].luck).is_equal(2)
	assert_bool(state.defender_units[0].has_luck()).is_false()


func test_no_mod_means_no_carrier_not_a_fake_zero() -> void:
	var unit = _state({}).defender_units[0]
	assert_bool(unit.has_luck()).is_false()
	assert_int(unit.luck).is_equal(0)


func test_card_hides_luck_row_without_carrier() -> void:
	var ui: CanvasLayer = _ui()
	var unit = _state({}).defender_units[0]
	ui.show_target_card(unit, "Противник")
	var row: Control = ui.get_node("target_card/tc_box/tc_luck_row")
	assert_bool(row.visible).is_false().override_failure_message(
		"строка «Удача» показана без носителя — это выдуманное число, M1 нарушен"
	)


func test_card_prints_the_signed_modifier() -> void:
	var ui: CanvasLayer = _ui()
	var unit = _state({"luck": 1}).defender_units[0]
	ui.show_target_card(unit, "Противник")
	var row: Control = ui.get_node("target_card/tc_box/tc_luck_row")
	var value: Label = ui.get_node("target_card/tc_box/tc_luck_row/tc_luck")
	assert_bool(row.visible).is_true()
	assert_str(value.text).is_equal("+1")


func test_negative_modifier_keeps_its_sign() -> void:
	var ui: CanvasLayer = _ui()
	var unit = _state({"luck": -1}).defender_units[0]
	ui.show_target_card(unit, "Противник")
	var value: Label = ui.get_node("target_card/tc_box/tc_luck_row/tc_luck")
	assert_str(value.text).is_equal("-1")


## Инвариант пары: источник важнее числа. Кто-то, кто проставит `luck`, минуя
## писателя, не должен получать строку в карточке — иначе «ноль из ниоткуда»
## вернётся тем же путём, каким его закрыл этот срез.
func test_modifier_without_source_stays_hidden() -> void:
	var ui: CanvasLayer = _ui()
	var unit := BattleState.BattleUnit.new()
	unit.stack = _stack(20)
	unit.luck = 3
	ui.show_target_card(unit, "Противник")
	var row: Control = ui.get_node("target_card/tc_box/tc_luck_row")
	assert_bool(row.visible).is_false()
