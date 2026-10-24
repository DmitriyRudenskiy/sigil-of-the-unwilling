extends BaseTest
class_name TestMarkerLayerFog

## T-165: маркерный слой рисовал шахты (⛏/✗), названия городов и дуги угрозы по
## всей карте, не зная про туман — сквозь туман была видно содержимое
## неисследованных клеток. Канон — docs/02g §2.1: неисследованная клетка пуста,
## «без ресурсов и маркеров».


class _StubMap extends MapGenerator:
	## Минимальная карта: слой маркеров требует валидный тайлмап, но рисует сам
	## только по клеткам, поэтому тайлсет заглушке не нужен.
	func has_valid_tilemap() -> bool:
		return true

	func map_to_local(cell: Vector2i) -> Vector2:
		return Vector2(cell) * 82.0


func _fog(explored_cells: Array) -> VisibilityMap:
	var fog := VisibilityMap.new()
	fog.set_map_size(20, 20)
	for c in explored_cells:
		fog.explored[c] = 1
	return fog


func _layer() -> MarkerLayer:
	var layer := MarkerLayer.new()
	add_child(layer)
	return layer


func test_without_fog_markers_are_shown() -> void:
	# Обратная совместимость: слой без переданного тумана (юнит-сборка, старые
	# вызывающие) ничего не прячет.
	var layer := _layer()
	assert_bool(layer.marker_visible_at(Vector2i(7, 3))).is_true()


func test_unexplored_cell_hides_marker() -> void:
	var layer := _layer()
	layer.set_fog(_fog([Vector2i(7, 3)]))
	assert_bool(layer.marker_visible_at(Vector2i(7, 3))).is_true()
	assert_bool(layer.marker_visible_at(Vector2i(9, 9))).is_false()


func test_fog_update_reveals_marker() -> void:
	# Туман пересчитывается каждый ход героя: слой обязан подхватить новое
	# исследование, а не запоминать первое состояние.
	var layer := _layer()
	var fog := _fog([])
	layer.set_fog(fog)
	assert_bool(layer.marker_visible_at(Vector2i(4, 4))).is_false()
	fog.explored[Vector2i(4, 4)] = 1
	assert_bool(layer.marker_visible_at(Vector2i(4, 4))).is_true()


func test_city_behind_fog_is_not_clickable() -> void:
	# Кликабельность идёт по той же границе: город за туманом не видно, значит
	# и клика по его маркеру быть не может.
	var layer := _layer()
	var city := City.new()
	layer._city_marks.append({"cell": Vector2i(2, 2), "pos": Vector2.ZERO, "city": city})
	layer.set_fog(_fog([]))
	assert_object(layer.city_at_cell(Vector2i(2, 2))).is_null()
	layer.set_fog(_fog([Vector2i(2, 2)]))
	assert_object(layer.city_at_cell(Vector2i(2, 2))).is_same(city)


func test_threat_markers_keep_cells_not_positions() -> void:
	# Фильтр по туману работает по клеткам, поэтому слой обязан хранить именно
	# клетки (иначе маркер нельзя проверить на исследованность), а не позиции.
	var layer := _layer()
	var map := _StubMap.new()
	add_child(map)
	layer.setup(map)
	layer.set_threat_markers([Vector2i(1, 1), Vector2i(1, 2), "мусор"])
	assert_int(layer._threat_cells.size()).is_equal(2)
	assert_vector(layer._threat_cells[0]).is_equal(Vector2i(1, 1))


func test_threat_markers_without_tilemap_are_dropped() -> void:
	# Ранний выход без валидного тайлмапа — прежнее поведение: маркеров нет,
	# вызов не падает.
	var layer := _layer()
	layer.set_threat_markers([Vector2i(1, 1)])
	assert_int(layer._threat_cells.size()).is_equal(0)
