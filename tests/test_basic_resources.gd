extends "res://tests/test_base.gd"
## Basic resource registry tests: wood/stone definitions.

func test_wood_definition() -> void:
	var def := Resources.get_resource(&"wood")
	assert_not_null(def, "wood exists")
	assert_eq(def.display_name, "Дерево", "wood name")
	assert_eq(def.yield_min, 2, "wood yield min")
	assert_eq(def.yield_max, 2, "wood yield max")
	assert_eq(def.weight_per_unit, 0.0, "wood zero weight")


func test_stone_definition() -> void:
	var def := Resources.get_resource(&"stone")
	assert_not_null(def, "stone exists")
	assert_eq(def.display_name, "Камень", "stone name")
	assert_eq(def.yield_min, 2, "stone yield min")
	assert_eq(def.yield_max, 2, "stone yield max")
	assert_eq(def.weight_per_unit, 0.0, "stone zero weight")


func test_all_resources_count() -> void:
	var all := Resources.get_all()
	# 13 жил + 7 городских ресурсов цепочек (Спринт 8).
	assert_eq(all.size(), 20, "20 total resources")


func test_hidden_resources_count() -> void:
	var ids := Resources.get_hidden_resource_ids()
	assert_eq(ids.size(), 11, "11 hidden resources")


func test_oak_definition() -> void:
	var def := Resources.get_resource(&"oak")
	assert_not_null(def, "oak exists")
	assert_eq(def.yield_min, 3, "oak yield min")
	assert_eq(def.yield_max, 5, "oak yield max")
	assert_eq(def.weight_per_unit, 2.0, "oak weight")


func test_saltpeter_definition() -> void:
	var def := Resources.get_resource(&"saltpeter")
	assert_not_null(def, "saltpeter exists")
	assert_eq(def.yield_min, 2, "saltpeter yield min")
	assert_eq(def.yield_max, 3, "saltpeter yield max")


func test_biome_filter_sand() -> void:
	var sand := Resources.get_by_biome("sand")
	assert_true(sand.size() >= 3, "sand has resources")


func test_biome_filter_snow() -> void:
	var snow := Resources.get_by_biome("snow")
	assert_true(snow.size() >= 3, "snow has resources")


func test_biome_filter_swamp() -> void:
	var swamp := Resources.get_by_biome("swamp")
	assert_true(swamp.size() >= 3, "swamp has resources")


func test_biome_filter_grass() -> void:
	var grass := Resources.get_by_biome("grass")
	assert_true(grass.size() >= 2, "grass has resources")
