extends GdUnitTestSuite

## R1: точка героя на миникарте.
## Регрессия: `has_method("current_cell")` всегда был false (это свойство, не метод)
## → ранний return до отрисовки → точка никогда не рисовалась.


class _StubHero extends Node:
	var current_cell: Vector2i = Vector2i(3, 4)


class _StubHeroNoCell extends Node:
	var position: Vector2 = Vector2.ZERO


var _map: MapGenerator = null


func after_test() -> void:
	if _map != null:
		_map.free()
		_map = null


func _make_overlay() -> MinimapOverlay:
	var overlay := MinimapOverlay.new()
	add_child(overlay)
	# Карта без generate(): map_to_local → ZERO, _world_to_overlay → world_pos.
	_map = MapGenerator.new()
	overlay.map_ref = _map
	return overlay


func test_hero_dot_reaches_draw_when_cell_property_exists() -> void:
	var overlay := _make_overlay()
	var hero := _StubHero.new()
	add_child(hero)
	overlay.hero_ref = hero
	# _last_hero_cell обновляется только после всех ранних return'ов _draw_hero_dot.
	var ok := false
	for i in 10:
		if overlay._last_hero_cell == Vector2i(3, 4):
			ok = true
			break
		overlay.queue_redraw()
		await get_tree().process_frame
	assert_bool(ok)
	hero.free()
	overlay.free()


func test_hero_dot_skipped_when_no_cell_property() -> void:
	var overlay := _make_overlay()
	var hero := _StubHeroNoCell.new()
	add_child(hero)
	overlay.hero_ref = hero
	overlay.queue_redraw()
	for i in 5:
		await get_tree().process_frame
	assert_that(overlay._last_hero_cell).is_equal(Vector2i.ZERO)
	hero.free()
	overlay.free()
