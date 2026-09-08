extends GdUnitTestSuite
# TASK_09 / 4.5: BattleInput — выбор юнита, подсветка, таргетинг заклинаний.

const MockBattleView := preload("res://tests/fakes/MockBattleView.gd")

var _input: BattleInput
var _view: MockBattleView
var _state: BattleState
var _unit_a: BattleState.BattleUnit


func _make_unit(key: String, count: int, side: BattleState.Side) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(UnitStack.new(UnitStats.new(key, key, 5, 3, 5, 3, 2), count))
	u.side = side
	u.max_count = count
	return u


func before_test() -> void:
	_input = BattleInput.new()
	_view = MockBattleView.new()
	_state = BattleState.new()
	_unit_a = _make_unit("swordsmen", 5, BattleState.Side.ATTACKER)
	_unit_a.cell = Vector2i(2, 2)
	_state.attacker_units.append(_unit_a)


func test_select_populates_highlights() -> void:
	_input.setup(_view, _state, {})
	_input._select(_unit_a)
	assert_that(_view.move_cells.size() > 0).is_true()
	assert_that(_view.atk_cells.size() >= 0).is_true()


func test_spell_targeting_highlight() -> void:
	_input.setup(_view, _state, {})
	_input._select(_unit_a)
	_input.start_spell_targeting(&"fireball", BattleState.Side.ATTACKER)
	# REGRESSION TASK_09: после старта таргетинга id жив (раньше его
	# сбрасывал _clear_highlights — заклинания не срабатывали).
	assert_that(String(_input._pending_spell_id)).is_equal("fireball")
	assert_that(_input._pending_target_side == BattleState.Side.ATTACKER).is_true()


func test_spell_targeting_marks_target_side() -> void:
	_input.setup(_view, _state, {})
	_input.start_spell_targeting(&"fireball", BattleState.Side.ATTACKER)
	assert_that(_view.atk_cells.has(_unit_a.cell)).is_true()
	assert_that(String(_input._pending_spell_id)).is_equal("fireball")


func test_clear_highlights_resets_visuals_and_state() -> void:
	_input.setup(_view, _state, {})
	_input.start_spell_targeting(&"fireball", BattleState.Side.ATTACKER)
	_input.clear_highlights()
	assert_that(_view.atk_cells.size()).is_equal(0)
	assert_that(String(_input._pending_spell_id)).is_equal("")


func test_attack_highlight_melee() -> void:
	# 4.5: ближний бой подсвечивает соседних врагов
	_input.setup(_view, _state, {})
	var enemy := _make_unit("goblins", 5, BattleState.Side.DEFENDER)
	enemy.cell = HexUtils.get_all_neighbors(_unit_a.cell)[0]
	_state.defender_units.append(enemy)
	_state._rebuild_unit_grid()
	var result: Dictionary = _input._compute_attack_highlight(_unit_a)
	assert_that(result.has(enemy.cell)).is_true()


func test_attack_highlight_ranged_no_adjacent() -> void:
	# 4.5: дальнобойный без соседей бьёт любого врага в поле
	_input.setup(_view, _state, {})
	var ranged := _make_unit("archers", 5, BattleState.Side.ATTACKER)
	ranged.stack.stats.tags.append("ranged")
	ranged.cell = Vector2i(2, 8)
	_state.attacker_units.append(ranged)
	var enemy := _make_unit("goblins", 5, BattleState.Side.DEFENDER)
	enemy.cell = Vector2i(10, 10)
	_state.defender_units.append(enemy)
	_state._rebuild_unit_grid()
	var result: Dictionary = _input._compute_attack_highlight(ranged)
	assert_that(result.has(enemy.cell)).is_true()


func after_test() -> void:
	if is_instance_valid(_input):
		_input.free()
	if is_instance_valid(_view):
		_view.free()
