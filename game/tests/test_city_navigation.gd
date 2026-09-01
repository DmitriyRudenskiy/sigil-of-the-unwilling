extends "res://tests/test_base.gd"
## city-navigation: второй стартовый город, навигационные значки городов на
## MarkerLayer (всегда видны, без порога), кнопка «Выход из города» CityScreen,
## роутинг клика по значку -> прокладка пути (WorldEventRouter).
## Headless: ноды добавляются в реальный root (Engine.get_main_loop().root) —
## _ready генерирует карту/строит UI синхронно при add_child.

const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")
const _MarkerLayer = preload("res://scripts/ui/MarkerLayer.gd")
const _WorldBootstrap = preload("res://scripts/world/WorldBootstrap.gd")
const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")
const _WorldEventRouter = preload("res://scripts/world/WorldEventRouter.gd")
const _City = preload("res://scripts/world/City.gd")

var holder: Node2D = null


func _main_root() -> Node:
	return Engine.get_main_loop().root


func before_each() -> void:
	holder = Node2D.new()
	holder.name = "NavTestHolder"
	_main_root().add_child(holder)


func after_each() -> void:
	if holder != null and is_instance_valid(holder):
		holder.free()
	holder = null


func _make_two_cities() -> Dictionary:
	# {cities: CityManager, capital: City, second: City}
	var mg := _MapGenerator.new()
	mg.name = "MapGenerator"
	mg.seed_value = 42
	holder.add_child(mg)  # _ready -> generate(): model + tilemap
	assert_true(mg.has_valid_tilemap(), "tilemap готов")
	var R = _WorldBootstrap.BootstrapResult.new()
	R.map_gen = mg
	_WorldBootstrap._create_cities(holder, R)
	var capital: City = R.cities.capital
	var second: City = null
	for c in R.cities.cities:
		if c != capital:
			second = c
	return {"mg": mg, "cities": R.cities, "capital": capital, "second": second}


# ==================== BOOTSTRAP: ДВА ГОРОДА ====================

func test_bootstrap_creates_two_cities() -> void:
	var w: Dictionary = _make_two_cities()
	var cities = w.cities
	assert_eq(cities.cities.size(), 2, "два города на старте")
	var capital: City = w.capital
	assert_not_null(capital, "есть столица")
	assert_true(capital.is_capital, "флаг столицы")
	assert_eq(capital.display_name, "Перворечье", "имя столицы")
	var capitals := 0
	for c in cities.cities:
		if c.is_capital:
			capitals += 1
	assert_eq(capitals, 1, "ровно одна столица")
	var second: City = w.second
	assert_not_null(second, "второй город есть")
	assert_false(second.is_capital, "второй — не столица")
	assert_eq(second.display_name, "Город 2", "имя второго города (на значке)")
	assert_eq(second.owner, &"player", "второй город принадлежит игроку")
	var d := HexUtils.hex_distance(capital.center, second.center)
	assert_gt(d, 8, "второй город ~15 гексов от столицы (d=%d > 8)" % d)
	assert_lt(d, 25, "второй город не улетел с карты (d=%d < 25)" % d)
	assert_true(w.mg.is_walkable(second.center), "центр второго города проходим")
	assert_true(w.mg.is_walkable(capital.center), "центр столицы проходим")


# ==================== MARKER LAYER: ЗНАЧКИ ====================

func test_city_markers_shown_and_resolved() -> void:
	var w: Dictionary = _make_two_cities()
	var mg = w.mg
	var ml := _MarkerLayer.new()
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(mg)
	ml.set_city_markers(w.cities.cities)
	assert_eq(ml._city_marks.size(), 2, "два значка")
	assert_eq(ml.city_at_cell(w.second.center), w.second, "значок второго города по клетке")
	assert_eq(ml.city_at_cell(w.capital.center), w.capital, "значок столицы по клетке")
	assert_null(ml.city_at_cell(Vector2i(0, 0)), "пустая клетка — без значка")


func test_city_marker_click_emits_city_and_consumes_input() -> void:
	var w: Dictionary = _make_two_cities()
	var ml := _MarkerLayer.new()
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	var clicked: Array = [null]
	ml.city_marker_clicked.connect(func(c: City) -> void: clicked[0] = c)
	# _handle_left_click — та же ветка, что и в _unhandled_input (без мыши
	# в headless): клик по клетке города эмитит city_marker_clicked.
	ml._handle_left_click(w.second.center)
	assert_eq(clicked[0], w.second, "клик по значку эмитит город")


func test_set_city_markers_empty_and_replaces() -> void:
	var w: Dictionary = _make_two_cities()
	var ml := _MarkerLayer.new()
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers([])
	assert_eq(ml._city_marks.size(), 0, "пустой список — без значков")
	ml.set_city_markers(w.cities.cities)
	assert_eq(ml._city_marks.size(), 2, "обновление — ровно 2 значка")
	ml.set_city_markers([w.capital])
	assert_eq(ml._city_marks.size(), 1, "частичное обновление — 1 значок")
	assert_eq(ml.city_at_cell(w.second.center), null, "старый значок убран")


# ==================== CITY SCREEN: КНОПКА ВЫХОДА ====================

func test_exit_button_renamed_and_closes() -> void:
	# city-navigation решение 4: кнопка «✕ Закрыть» → «✕ Выход из города».
	var city := _City.new()
	city.display_name = "Перворечье"
	city.center = Vector2i(10, 10)
	city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	var hero = preload("res://scripts/entities/HeroController.gd").new()
	hero.name = "Hero"
	holder.add_child(hero)
	var screen = preload("res://scripts/ui/CityScreen.gd").new()
	holder.add_child(screen)
	screen.setup(city, hero, Vector2i(10, 10), _seeded(42))
	var btn := screen.get_node("CityScreenBackground/CityScreenCenter/CityScreenPanel/CityScreenBox/CityScreenButtons/Close") as Button
	assert_not_null(btn, "кнопка выхода найдена")
	assert_true(btn.text.contains("Выход из города"), "текст «Выход из города»")
	var closed: Array = [false]
	screen.close_requested.connect(func() -> void: closed[0] = true)
	btn.emit_signal("pressed")
	assert_true(closed[0], "close_requested эмитится")
	if is_instance_valid(screen):
		screen.free()
	if is_instance_valid(hero):
		hero.free()


# ==================== EVENT ROUTER: НАВИГАЦИЯ (D2/D3) ====================

## Лёгкий герой-заглушка: ловит on_map_clicked, не лезет в pathfinding.
## Повторяет сигналы, к которым WorldEventRouter делает _connect_hero_signals,
## чтобы в headless-сканировании логов не было SCRIPT ERROR.
class NavMockMovement extends Node:
	signal reach_preview_changed(path: Array)
	signal reach_preview_cleared()

class NavMockHero extends Node:
	signal hero_moved(cell: Vector2i)
	signal hero_entered_village(cell: Vector2i)
	var current_cell := Vector2i(-1, -1)
	var clicked: Array = []
	var movement: NavMockMovement
	func _init_moved() -> void:
		movement = NavMockMovement.new()
		movement.name = "MockMovement"
		add_child(movement)
	func on_map_clicked(cell: Vector2i) -> void:
		clicked.append(cell)


func _make_router(mg: MapGenerator, cities: CityManager, hero: NavMockHero) -> WorldEventRouter:
	var r := _WorldEventRouter.new()
	r.name = "EventRouter"
	_main_root().add_child(r)
	# resource_registry — null: resolve вернёт null, _on_city_marker_clicked её не трогает.
	r.setup(hero, mg, null, cities, null, null, null, null, null, null, null, null)
	return r


func test_city_marker_click_routes_path_to_city() -> void:
	var w := _make_two_cities()
	var hero := NavMockHero.new()
	hero.current_cell = Vector2i(0, 0)
	hero._init_moved()
	var router := _make_router(w.mg, w.cities, hero)
	var ml := _MarkerLayer.new()
	ml.name = "MarkerLayer"
	_main_root().add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	ml.city_marker_clicked.connect(router._on_city_marker_clicked)
	ml.city_marker_clicked.emit(w.second)
	assert_eq(hero.clicked.size(), 1, "клик по значку -> маршрут герою")
	var target: Vector2i = hero.clicked[0]
	assert_true(w.mg.is_walkable(target), "целевая клетка проходимая (у центра)")
	assert_true(target != hero.current_cell, "маршрут не на месте")
	router.free()
	ml.free()
	hero.free()


func test_city_marker_click_to_unwalkable_center_uses_nearby() -> void:
	var w := _make_two_cities()
	# Столица: искуственно делаем её непроходимой -> роутер берёт проходимую рядом.
	var capital: City = w.capital
	w.mg.model.set_terrain(capital.center, HexUtils.Terrain.MOUNTAIN)
	var hero := NavMockHero.new()
	hero.current_cell = Vector2i(0, 0)
	hero._init_moved()
	var router := _make_router(w.mg, w.cities, hero)
	var ml := _MarkerLayer.new()
	ml.name = "MarkerLayer"
	_main_root().add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	ml.city_marker_clicked.connect(router._on_city_marker_clicked)
	ml.city_marker_clicked.emit(capital)
	assert_eq(hero.clicked.size(), 1, "маршрут построен и для столицы")
	assert_true(w.mg.is_walkable(hero.clicked[0]), "маршрут к проходимой у центра")
	router.free()
	ml.free()
	hero.free()


func _seeded(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
