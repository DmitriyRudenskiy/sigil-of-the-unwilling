extends "res://tests/gut_base.gd"
## city-in-world: персистентность городов.
##  - round-trip serialize/deserialize: owner + display_name (city-in-world fix);
##  - гарнизон (MILITIA) переживает round-trip через pop-массив;
##  - CityFactory.village_name детерминирован по (seed, cell);
##  - CityManager: провайдер выходов для города, зарегистрированного ПОСЛЕ
##    set_tile_yield_provider (city-in-world fix);
##  - порядок uids при загрузке: столица (0) → деревни в порядке захвата.

const _City = preload("res://scripts/world/City.gd")
const _CityFactory = preload("res://scripts/world/CityFactory.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")

## CityManager — Node (не RefCounted). 
var manager: Node = null


func before_each() -> void:
	manager = _CityManager.new()


func after_each() -> void:
	if manager != null:
		manager.free()
		manager = null


# ==================== ROUND-TRIP ====================

func test_roundtrip_owner_and_display_name() -> void:
	# city-in-world fix: owner раньше терялся, display_name — не восстанавливался.
	var c := _City.new()
	c.display_name = "Заречье"
	c.center = Vector2i(3, 4)
	c.owner = &"player"
	c.level = 2
	c.storage[&"industry"] = 42.0
	var c2 := _City.new()
	c2.deserialize(c.serialize())
	assert_eq(c2.owner, &"player", "owner round-trip")
	assert_eq(c2.display_name, "Заречье", "display_name round-trip")
	assert_eq(c2.center, Vector2i(3, 4), "center round-trip")
	assert_eq(c2.level, 2, "level round-trip")
	assert_approx(float(c2.storage.get(&"industry", 0.0)), 42.0, 0.0001, "storage round-trip")


func test_roundtrip_owner_none_default() -> void:
	var c := _City.new()
	c.display_name = "Песочница"
	var c2 := _City.new()
	c2.deserialize(c.serialize())
	assert_eq(c2.owner, &"none", "owner none round-trip")
	assert_eq(c2.display_name, "Песочница", "display_name round-trip")


func test_roundtrip_garrison_via_pop() -> void:
	# Гарнизон — производный (count_state(MILITIA)); в сейве живёт как pop-массив.
	var c := _City.new()
	c.display_name = "Крепость"
	for i in 3:
		c.add_migrant(PopUnit.State.MILITIA, -1)
	assert_eq(c.garrison_count(), 3, "гарнизон до")
	var c2 := _City.new()
	c2.deserialize(c.serialize())
	assert_eq(c2.garrison_count(), 3, "гарнизон после round-trip")
	assert_eq(c2.pop.size(), 3, "pop сохранён")


# ==================== ИМЯ ДЕРЕВНИ ====================

func test_village_name_deterministic() -> void:
	assert_eq(_CityFactory.village_name(12345, Vector2i(7, 9)),
		_CityFactory.village_name(12345, Vector2i(7, 9)), "один (seed, cell) → одно имя")
	assert_not_empty(_CityFactory.village_name(12345, Vector2i(7, 9)), "имя не пустое")


func test_village_name_differs_by_seed() -> void:
	assert_true(_CityFactory.village_name(1, Vector2i(5, 5))
		!= _CityFactory.village_name(2, Vector2i(5, 5)), "разный seed → разное имя")


func test_village_name_spread_across_cells() -> void:
	var names: Dictionary = {}
	for i in 200:
		names[_CityFactory.village_name(42, Vector2i(i % 10, i / 10))] = true
	assert_gt(names.size(), 1, "имена распределяются по клеткам")


# ==================== CITYMANAGER: ПРОВАЙДЕР И city_at ====================

func test_provider_applied_to_later_registered_city() -> void:
	# city-in-world fix: register_city обязан ставить провайдер, установленный
	# до него (захваченные после бутстрапа деревни не должны остаться без выходов).
	manager.set_tile_yield_provider(func(_cell: Vector2i) -> Dictionary:
		return _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS))
	var capital := _City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	manager.register_city(capital, true)
	var village := _City.new()
	village.display_name = "Дальний Посад"
	village.center = Vector2i(20, 20)
	manager.register_city(village)  # ПОСЛЕ set_tile_yield_provider
	assert_not_null(capital.tile_yield_fn, "столица: провайдер есть")
	assert_not_null(village.tile_yield_fn, "поздний город: провайдер есть")
	var y: Dictionary = village.tile_yield_fn.call(Vector2i(21, 20))
	assert_approx(float(y.get(&"food", 0.0)), 3.0, 0.0001, "выход травы через провайдер")


func test_city_at_finds_registered_city() -> void:
	var v := _City.new()
	v.display_name = "Кряж"
	v.center = Vector2i(15, 17)
	manager.register_city(v)
	assert_eq(manager.city_at(Vector2i(15, 17)), v, "city_at по центру")
	assert_null(manager.city_at(Vector2i(16, 17)), "рядом — null")


# ==================== ПОРЯДОК UIDS (ЗАГРУЗКА) ====================

func test_restore_order_capital_then_captured_villages() -> void:
	# Симуляция _restore_cities: столица регистрируется первой (uid 0),
	# деревни — в порядке captured_villages; повторный захват той же клетки
	# не дублирует город.
	var seed := 777
	var captured := [Vector2i(20, 20), Vector2i(30, 30)]
	var save_names: Dictionary = {}
	var save_centers: Dictionary = {}

	var m1 := _CityManager.new()
	var capital := _City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	capital.owner = &"player"
	m1.register_city(capital, true)
	assert_eq(capital.uid, 0, "столица uid 0")
	for cell in captured:
		var v := _CityFactory.create_village(cell, _CityFactory.village_name(seed, cell), seed)
		m1.register_city(v)
		save_names[v.uid] = v.display_name
		save_centers[v.uid] = v.center
	assert_eq(m1.cities.size(), 3, "столица + 2 деревни")
	assert_eq(m1.get_city_by_uid(1).center, Vector2i(20, 20), "uid 1 — первый захват")
	assert_eq(m1.get_city_by_uid(2).center, Vector2i(30, 30), "uid 2 — второй захват")
	m1.free()

	# Загрузка: та же последовательность → uids/имена/центры совпадают.
	var m2 := _CityManager.new()
	var cap2 := _City.new()
	cap2.display_name = "Столица"
	cap2.center = Vector2i(10, 10)
	m2.register_city(cap2, true)
	for cell in captured:
		var v2 := _CityFactory.create_village(cell, _CityFactory.village_name(seed, cell), seed)
		m2.register_city(v2)
		assert_eq(save_names[v2.uid], v2.display_name, "имя совпадает по uid")
		assert_eq(save_centers[v2.uid], v2.center, "центр совпадает по uid")
	assert_eq(m2.cities.size(), 3, "после загрузки 3 города (dedup в WorldStateDelta)")
	m2.free()
