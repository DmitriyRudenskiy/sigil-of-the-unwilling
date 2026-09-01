extends "res://tests/test_base.gd"
## city-in-world: экран управления городом (CityScreen) — списочный UI.
##  - setup/open/close; close_requested по кнопке «Выход из города»;
##  - build (успех/нехватка ресурсов/нет клетки) мутирует РЕАЛЬНЫЙ City;
##  - hire: город отдаёт FOLLOWER, герой получает Follower; исчерпание;
##  - level-up: условия ProsperitySystem, максимум уровня.
## Headless: экран добавляется в реальный root (Engine.get_main_loop().root) —
## _ready строит UI-дерево синхронно при add_child.

const _City = preload("res://scripts/world/City.gd")
const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")

var screen: CityScreen = null
var city: RefCounted = null
var hero: Node2D = null


func _main_root() -> Node:
	return Engine.get_main_loop().root


func before_each() -> void:
	screen = CityScreen.new()
	_main_root().add_child(screen)  # _ready строит UI-дерево
	city = _City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	city.storage[&"industry"] = 30.0
	hero = HeroController.new()
	hero.name = "Hero"
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), _seeded(42))


func after_each() -> void:
	# free() сам снимает ноду с родителя (без has_child — Window в headless-раннере
	# не всегда отдаёт полный Node-API).
	if screen != null and is_instance_valid(screen):
		screen.free()
		screen = null
	if hero != null and is_instance_valid(hero):
		hero.free()
		hero = null
	city = null


# ==================== SETUP / OPEN / CLOSE ====================

func test_setup_binds_city_and_hero() -> void:
	assert_eq(screen.city, city, "город привязан")
	assert_eq(screen.hero, hero, "герой привязан")
	assert_false(screen.is_open(), "сначала закрыт")
	screen.open()
	assert_true(screen.is_open(), "открыт")
	assert_true(screen.visible, "видим")
	screen.close()
	assert_false(screen.is_open(), "закрыт")
	assert_false(screen.visible, "скрыт")


func test_close_button_emits_close_requested() -> void:
	# Лямбда в GDScript захватывает скаляры по значению — флаги в Array.
	var emitted: Array = [false]
	screen.close_requested.connect(func(): emitted[0] = true)
	var btn := screen.get_node("CityScreenBackground/CityScreenCenter/CityScreenPanel/CityScreenBox/CityScreenButtons/Close") as Button
	assert_not_null(btn, "кнопка Close найдена")
	# Godot 4: нет Button.press(); эмулируем клик сигналом (в связке _ready
	# pressed → _on_close_pressed → close_requested).
	btn.emit_signal("pressed")
	assert_true(emitted[0], "close_requested эмитится")


# ==================== BUILD ====================

func test_build_farm_success() -> void:
	var r: Dictionary = screen.build_pressed(&"farm")
	assert_true(bool(r.get("ok", false)), "построено: %s" % str(r.get("reason", "")))
	assert_eq(r.get("building"), "farm", "ид здания")
	assert_eq(int(r.get("level", 0)), 1, "уровень 1")
	assert_eq(city.buildings.size(), 1, "здание в городе")
	assert_approx(float(r.get("industry_left", -1.0)), 18.0, 0.0001, "30 − 12 = 18")
	var cell: Dictionary = r.get("cell", {})
	assert_eq(HexUtils.hex_distance(Vector2i(int(cell.x), int(cell.y)), city.center), 1, "клетка рядом с центром")


func test_build_mine_cost() -> void:
	var r: Dictionary = screen.build_pressed(&"mine")
	assert_true(bool(r.get("ok", false)), "шахта построена")
	assert_approx(float(r.get("industry_left", -1.0)), 10.0, 0.0001, "30 − 20 = 10")


func test_build_fails_without_industry() -> void:
	city.storage[&"industry"] = 5.0  # дешевле 12
	var r: Dictionary = screen.build_pressed(&"farm")
	assert_false(bool(r.get("ok", false)), "не построено")
	assert_true(str(r.get("reason", "")).contains("Промышленность"), "причина — промышленность")
	assert_eq(city.buildings.size(), 0, "здания нет")


func test_build_fails_without_free_cell() -> void:
	# Центр в углу и bounds (1,1): всё кольцо за пределами карты.
	city.center = Vector2i(0, 0)
	screen.setup(city, hero, Vector2i(0, 0), _seeded(42), Vector2i(1, 1))
	var r: Dictionary = screen.build_pressed(&"farm")
	assert_false(bool(r.get("ok", false)), "не построено")
	assert_true(str(r.get("reason", "")).contains("клетки"), "причина — нет клетки")


func test_build_unknown_def_fails() -> void:
	var r: Dictionary = screen.build_pressed(&"nope")
	assert_false(bool(r.get("ok", false)), "неизвестное здание отклонено")


# ==================== HIRE ====================

func test_hire_moves_follower_to_hero() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r: Dictionary = screen.hire_pressed()
	assert_true(bool(r.get("ok", false)), "нанят: %s" % str(r.get("reason", "")))
	var f: Dictionary = r.get("follower", {})
	assert_not_empty(f.get("name", ""), "имя в ответе")
	assert_true(String(f.get("race", "")).length() > 0, "раса в ответе")
	assert_eq(hero.followers.size(), 1, "у героя 1")
	assert_eq(city.count_state(PopUnit.State.FOLLOWER), 1, "в городе остался 1")


func test_hire_depletes_then_fails() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r1: Dictionary = screen.hire_pressed()
	assert_true(bool(r1.get("ok", false)), "первый найм ок")
	var r2: Dictionary = screen.hire_pressed()
	assert_false(bool(r2.get("ok", false)), "второй найм — пусто")
	assert_true(str(r2.get("reason", "")).contains("последователей"), "причина — нет последователей")
	assert_eq(hero.followers.size(), 1, "у героя всё ещё 1")


# ==================== LEVEL UP ====================

func test_level_up_fresh_village_fails() -> void:
	# Свежая деревня: prosperity 50 < 60, население < 12, зданий < 2.
	var r: Dictionary = screen.level_up_pressed()
	assert_false(bool(r.get("ok", false)), "свежая деревня не улучшается")
	assert_true(str(r.get("reason", "")).length() > 0, "есть причина")
	assert_eq(city.level, 1, "уровень не изменился")


func test_level_up_when_conditions_met() -> void:
	# Удовлетворяем: prosperity 70, 12 рабочих, 2 здания (ферма + шахта).
	city.prosperity = 70.0
	city.storage[&"industry"] = 40.0
	for i in 12:
		city.add_migrant(PopUnit.State.WORKER, -1)
	screen.build_pressed(&"farm")
	screen.build_pressed(&"mine")
	assert_eq(city.buildings.size(), 2, "2 здания")
	var r: Dictionary = screen.level_up_pressed()
	assert_true(bool(r.get("ok", false)), "улучшено: %s" % str(r.get("reason", "")))
	assert_eq(int(r.get("level", 0)), 2, "уровень 2")
	assert_eq(city.level, 2, "уровень города 2")


func test_level_up_max_level_fails() -> void:
	city.level = ProsperitySystem.CITY_LEVEL_MAX
	var r: Dictionary = screen.level_up_pressed()
	assert_false(bool(r.get("ok", false)), "макс. уровень")
	assert_true(str(r.get("reason", "")).contains("максимальном"), "причина — максимум")


func _seeded(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
