extends BaseTest

const _Scene := preload("res://scenes/battle_view.tscn")

var _view: BattleView
var _state: BattleState
var _unit: BattleState.BattleUnit

func before_test() -> void:
	_view = _Scene.instantiate()
	add_child(_view)
	_view.setup()
	_state = BattleState.new()
	_unit = BattleState.BattleUnit.new(UnitStack.new(UnitStats.new("swordsmen", "S", 5, 3, 5, 3, 2), 5))
	_unit.side = BattleState.Side.ATTACKER
	_unit.uid = 1
	_unit.cell = Vector2i(2, 2)
	_state.attacker_units.append(_unit)

func after_test() -> void:
	if is_instance_valid(_view):
		_view.free()

func test_create_unit_sprite() -> void:
	_view.create_unit_sprite(_unit)
	assert_that(_view._sprites_by_uid.has(1)).is_true()

func test_remove_unit() -> void:
	_view.create_unit_sprite(_unit)
	_view.remove_unit(_unit)
	assert_that(_view._sprites_by_uid.has(1)).is_false()

func test_set_highlights_no_crash() -> void:
	_view.set_highlights({Vector2i(1, 1): 1}, {Vector2i(2, 1): 1})
	_view.set_unreachable_highlights({Vector2i(3, 1): 1})
	_view.clear_highlights()

func test_cursor_mode() -> void:
	_view.set_cursor_mode(BattleView.CursorMode.ATTACK)
	_view.set_cursor_mode(BattleView.CursorMode.SPELL)
	_view.set_cursor_visible(true)
	_view.set_cursor_visible(false)

func test_find_node_null_safe() -> void:
	assert_that(_view._find_node(null)).is_null()
	_view.remove_unit(null)

func test_animate_move_null_guard() -> void:

	var tw := _view.animate_move(null, [])
	assert_that(tw).is_null()

func test_fit_camera_centers_on_field() -> void:
	_view.paint_field()
	_view.fit_camera()
	var cam: Camera2D = _view.get_node("Camera")
	var used: Rect2i = _view._tile_map.get_used_rect()
	assert_bool(used.size.x > 0 and used.size.y > 0).is_true()
	var p0: Vector2 = _view._tile_map.map_to_local(used.position)
	var p1: Vector2 = _view._tile_map.map_to_local(used.position + used.size - Vector2i(1, 1))
	var expected: Vector2 = (p0 + p1) / 2.0
	assert_bool(cam.position.distance_to(expected) < 0.01).is_true()


func test_floating_text() -> void:

	_view.show_floating_text(Vector2i(3, 3), "Тест", Color.WHITE)

func test_damage_number() -> void:

	_view.create_unit_sprite(_unit)
	_view.show_damage_number(_unit, 25)
