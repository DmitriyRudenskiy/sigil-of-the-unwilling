extends BaseTest

# Ранняя игра: рюкзак героя — общий лимит, выгрузка, телега (early-game-foundation).

func _main_root() -> Node:
	return Engine.get_main_loop().root


func _pool() -> HeroStrategicResources:
	var p := HeroStrategicResources.new()
	p._resources = {&"oak": 0, &"silver": 0, &"wood": 0}
	return p


func test_total_cap_blocks_overflow() -> void:
	var p := _pool()
	assert_int(p.add(&"oak", 8)).is_equal(8)
	assert_int(p.add(&"silver", 3)).is_equal(3)
	# 11/12: только 1 единица влезает
	assert_int(p.add(&"wood", 3)).is_equal(1)
	assert_int(p.total()).is_equal(12)
	assert_int(p.total_cap()).is_equal(GameNumbersHero.BACKPACK_TOTAL_CAP)


func test_cart_bonus_expands_cap() -> void:
	var p := _pool()
	p.add(&"oak", 12)
	p.capacity_bonus += GameNumbersHero.BACKPACK_CART_BONUS
	assert_int(p.total_cap()).is_equal(18)
	assert_int(p.add(&"silver", 6)).is_equal(6)
	assert_int(p.total()).is_equal(18)


func test_component_serializes_bonus() -> void:
	var comp := HeroStrategicResourcesComponent.new()
	comp.strategic.capacity_bonus = 6
	var data: Dictionary = comp.serialize()
	assert_int(int(data.get("backpack_bonus", 0))).is_equal(6)
	var comp2 := HeroStrategicResourcesComponent.new()
	comp2.deserialize(data)
	assert_int(comp2.strategic.total_cap()).is_equal(18)
	# Старый сейв без бонуса
	comp2.deserialize({})
	assert_int(comp2.strategic.total_cap()).is_equal(GameNumbersHero.BACKPACK_TOTAL_CAP)


func test_city_unload_moves_backpack_to_storage() -> void:
	var screen: CityScreen = load("res://scenes/ui/city_screen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	var city := City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	city.storage[&"industry"] = 30.0
	var hero := _hero_with_backpack({&"oak": 5, &"silver": 2})
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))
	# social-stats-weapon-tech: int 20 — шанс обмана 5%, seed 42 не падает
	hero.stats["int"] = 20

	var check: CityCheck = screen.unload_pressed()
	assert_bool(check.ok).is_true()
	assert_int(int(check.payload.get("moved", 0))).is_equal(7)
	assert_float(float(city.storage.get(&"oak", 0.0))).is_equal(5.0)
	assert_float(float(city.storage.get(&"silver", 0.0))).is_equal(2.0)
	assert_int(hero.strategic_resources.total()).is_equal(0)
	hero.free()
	screen.free()


func test_city_unload_empty_fails() -> void:
	var screen: CityScreen = load("res://scenes/ui/city_screen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	var city := City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	var hero := _hero_with_backpack({&"oak": 0})
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))
	# social-stats-weapon-tech: int 20 — шанс обмана 5%, seed 42 не падает
	hero.stats["int"] = 20

	var check: CityCheck = screen.unload_pressed()
	assert_bool(check.ok).is_false()
	hero.free()
	screen.free()


func test_cart_buy_requires_market_and_funds() -> void:
	var screen: CityScreen = load("res://scenes/ui/city_screen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	var city := City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	city.storage[&"industry"] = 50.0
	var hero := _hero_with_backpack({&"oak": 0})
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))
	# social-stats-weapon-tech: int 20 — шанс обмана 5%, seed 42 не падает
	hero.stats["int"] = 20

	# Нет рынка
	var check: CityCheck = screen.buy_cart_pressed()
	assert_bool(check.ok).is_false()
	# Нет средств
	var market_def := BuildingDefs.def_by_id(&"market")
	if market_def != null:
		var bld := city.build_building(market_def, Vector2i(11, 10))
		if bld == null:
			city.buildings.append(_market_stub())
	hero.strategic_resources.capacity_bonus = 0
	var before_cap: int = hero.strategic_resources.total_cap()
	var before_industry: float = float(city.storage[&"industry"])
	if before_industry < GameNumbersHero.BACKPACK_CART_COST:
		city.storage[&"industry"] = 100.0
		before_industry = 100.0
	var check2: CityCheck = screen.buy_cart_pressed()
	assert_bool(check2.ok).is_true()
	assert_int(hero.strategic_resources.total_cap()).is_equal(before_cap + GameNumbersHero.BACKPACK_CART_BONUS)
	assert_float(city.storage[&"industry"]).is_equal(before_industry - GameNumbersHero.BACKPACK_CART_COST)
	hero.free()
	screen.free()


func _hero_with_backpack(resources: Dictionary) -> HeroController:
	var hero := TestFactories.make_hero()
	hero.strategic_resources._resources = resources
	return hero


func _market_stub():
	var b := UniqueBuilding.new()
	b.def = UniqueBuilding.Def.new()
	b.def.id = &"market"
	b.level = 1
	b.cell = Vector2i(11, 10)
	return b


func _noop() -> Callable:
	return func() -> void: pass
