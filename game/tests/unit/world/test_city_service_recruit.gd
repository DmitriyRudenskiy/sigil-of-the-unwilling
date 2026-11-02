extends BaseTest
## Носитель: scripts/world/city_service.gd — найм военного стека (`recruit_military`):
## пачка, тир по уровню города, трата серебра, отказы «армия полна» и «нет серебра».
## Тесты переехали из `unit/test_city_tech_tree.gd` (шаг 5 T-305, 2026-10-30):
## определения построек ушли в `unit/data/test_building_defs.gd`, тирование стеков —
## в `unit/test_unit_registry.gd`, уровни города — в `unit/city/test_prosperity_system.gd`.

const TestFactories = preload("res://tests/helpers/factories.gd")

func _city_at(level: int) -> City:
	var c := City.new()
	c.display_name = "Тест"
	c.center = Vector2i(10, 10)
	c.level = level
	c.storage[&"industry"] = 100.0
	c.storage[&"silver"] = 100.0
	return c

func _main_root() -> Node:
	return Engine.get_main_loop().root

func _solo_hero() -> HeroController:
	var hero := TestFactories.make_hero()
	_main_root().add_child(hero)
	hero.get_army().setup(Services.resolve(&"units"), true)
	# social-stats-weapon-tech: cha 20 — cap 7 стеков (тесты набирают до 3+)
	hero.stats["cha"] = 20
	return hero

func _range_bld(level: int) -> UniqueBuilding:
	var bld := UniqueBuilding.new()
	bld.def = BuildingDefs.def_by_id(&"range")
	bld.level = level
	bld.cell = Vector2i(11, 10)
	return bld

func test_recruit_military_flow() -> void:
	CityService.set_rng(TestFactories.seeded(1))
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
	CityService.set_rng(TestFactories.seeded(1))
	BuildingDefs._def_cache.clear()
	BuildingDefs._raw_cache = []
	var hero := _solo_hero()
	var c3 := _city_at(3)
	var check: CityCheck = CityService.recruit_military(c3, _range_bld(1), hero)
	assert_int(int(check.payload.get("tier", 0))).is_equal(1)
	# social-systems-delta: fallback тира сдвинут (+1 к железному и выше)
	var c6 := _city_at(6)
	var check2: CityCheck = CityService.recruit_military(c6, _range_bld(1), hero)
	assert_int(int(check2.payload.get("tier", 0))).is_equal(3)
	var c9 := _city_at(9)
	var check3: CityCheck = CityService.recruit_military(c9, _range_bld(1), hero)
	assert_int(int(check3.payload.get("tier", 0))).is_equal(4)
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
