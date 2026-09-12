extends BaseTest

# Ранняя игра: дымовая города (early-game-foundation, city-tech-tree).

func _city_at(level: int) -> City:
	var c := City.new()
	c.display_name = "Тест"
	c.center = Vector2i(10, 10)
	c.level = level
	c.storage[&"industry"] = 100.0
	c.storage[&"silver"] = 100.0
	return c


func _solo_hero() -> HeroController:
	var hero := TestFactories.make_hero()
	_main_root().add_child(hero)
	hero.get_army().setup(Services.resolve(&"units"), true)
	return hero

func _main_root() -> Node:
	return Engine.get_main_loop().root


func _range_bld(level: int) -> UniqueBuilding:
	var bld := UniqueBuilding.new()
	bld.def = BuildingDefs.def_by_id(&"range")
	bld.level = level
	bld.cell = Vector2i(11, 10)
	return bld


func test_level_max_is_11() -> void:
	assert_int(GameNumbers.CITY_LEVEL_MAX).is_equal(11)


func test_level_up_req_scales() -> void:
	var first: float = ProsperitySystem.level_up_req(2)
	var last: float = ProsperitySystem.level_up_req(11)
	assert_bool(last > first).is_true()


func test_can_level_up_blocked_at_max() -> void:
	var c := _city_at(11)
	var check: Dictionary = ProsperitySystem.can_level_up(c)
	assert_bool(bool(check.get("ok", false))).is_false()


func test_building_min_city_level_gate() -> void:
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []
	var stables: UniqueBuilding.Def = BuildingDefs.def_by_id(&"stables")
	assert_that(stables).is_not_null()
	assert_int(stables.min_city_level).is_equal(6)
	var c3 := _city_at(3)
	var cell := Vector2i(11, 10)
	var check: CityCheck = CityBuildingService.can_build_building(c3, stables, cell)
	assert_bool(check.ok).is_false()
	var c6 := _city_at(6)
	var check6: CityCheck = CityBuildingService.can_build_building(c6, stables, cell)
	assert_bool(check6.ok).is_true()
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []


func test_military_chain_parsed() -> void:
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []
	var range_def: UniqueBuilding.Def = BuildingDefs.def_by_id(&"range")
	assert_that(range_def).is_not_null()
	assert_bool(not range_def.military_chain.is_empty()).is_true()
	assert_that(range_def.military_chain.get("unit_key")).is_equal("archers")
	var tiers: Array = range_def.military_chain.get("tiers", [])
	assert_int(int(tiers[0])).is_equal(1)
	assert_int(int(tiers[2])).is_equal(3)
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []


func test_make_recruit_stack_tiers() -> void:
	var reg: Node = Services.resolve(&"units")
	var base: UnitStats = reg.get_definition("swordsmen")
	var t1: UnitStack = reg.make_recruit_stack("swordsmen", 20, 1)
	var t2: UnitStack = reg.make_recruit_stack("swordsmen", 20, 2)
	var t3: UnitStack = reg.make_recruit_stack("swordsmen", 20, 3)
	assert_int(t1.stats.attack).is_equal(base.attack)
	assert_int(t2.stats.attack).is_equal(int(round(base.attack * 1.6)))
	assert_int(t3.stats.attack).is_equal(int(round(base.attack * 2.66)))
	assert_bool(t3.stats.tags.has("magic_weapon")).is_true()
	assert_bool(t1.stats.tags.has("magic_weapon")).is_false()
	assert_int(t1.count).is_equal(20)


func test_recruit_military_flow() -> void:
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []
	var c := _city_at(3)
	c.buildings.append(_range_bld(1))
	var hero := _solo_hero()
	var before: int = hero.get_army().army.size()

	var check: CityCheck = CityService.recruit_military(c, _range_bld(1), hero)
	assert_bool(check.ok).is_true()
	assert_int(int(check.payload.get("count", 0))).is_equal(GameNumbers.RECRUIT_BATCH_SIZE)
	assert_int(int(check.payload.get("tier", 0))).is_equal(1)
	assert_int(hero.get_army().army.size()).is_equal(before + 1)
	assert_float(float(c.storage.get(&"silver", 0.0))).is_equal(100.0 - 8.0)
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []


func test_recruit_tier_follows_city_level() -> void:
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []
	var hero := _solo_hero()
	var c3 := _city_at(3)
	var check: CityCheck = CityService.recruit_military(c3, _range_bld(1), hero)
	assert_int(int(check.payload.get("tier", 0))).is_equal(1)
	var c6 := _city_at(6)
	var check2: CityCheck = CityService.recruit_military(c6, _range_bld(1), hero)
	assert_int(int(check2.payload.get("tier", 0))).is_equal(2)
	var c9 := _city_at(9)
	var check3: CityCheck = CityService.recruit_military(c9, _range_bld(1), hero)
	assert_int(int(check3.payload.get("tier", 0))).is_equal(3)
	var stack: UnitStack = hero.get_army().army[2]
	assert_bool(stack.stats.tags.has("magic_weapon")).is_true()
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []


func test_recruit_military_army_full() -> void:
	var c := _city_at(3)
	var hero := _solo_hero()
	for i in GameNumbers.HERO_ARMY_MAX_STACKS:
		hero.get_army().army.append(
			Services.resolve(&"units").make_fixed_stack("swordsmen", 5))
	var check: CityCheck = CityService.recruit_military(c, _range_bld(1), hero)
	assert_bool(check.ok).is_false()


func test_recruit_military_no_funds() -> void:
	var c := _city_at(3)
	c.storage[&"silver"] = 0.0
	var hero := _solo_hero()
	var check: CityCheck = CityService.recruit_military(c, _range_bld(1), hero)
	assert_bool(check.ok).is_false()
