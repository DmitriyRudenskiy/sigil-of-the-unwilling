extends BaseTest
## Носитель: scripts/data/building_defs.gd — разбор определений построек:
## минимальный уровень города у определения и военная цепочка (`military_chain`).
## Тесты переехали из `unit/test_city_tech_tree.gd` (шаг 5 T-305, 2026-10-30): найм
## ушёл в `unit/world/test_city_service_recruit.gd`, уровни города — в
## `unit/city/test_prosperity_system.gd`, тирование стеков — в
## `unit/test_unit_registry.gd`.

func _city_at(level: int) -> City:
	var c := City.new()
	c.display_name = "Тест"
	c.center = Vector2i(10, 10)
	c.level = level
	c.storage[&"industry"] = 100.0
	c.storage[&"silver"] = 100.0
	return c

func test_building_min_city_level_gate() -> void:
	# Driver — CityBuildingService: предмет проверки, min_city_level, читается из
	# определения, а сервис только применяет его.
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
