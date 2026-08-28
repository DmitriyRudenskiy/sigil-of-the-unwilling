extends "res://tests/test_base.gd"
## ResourceRegistry keys matrix: discovery & extraction key validation.



func test_oak_discovery_by_nature_sense() -> void:
	var def = Resources.get_resource(&"oak")
	assert_not_null(def, "oak exists")
	assert_eq(def.discovery_skill, &"nature_sense", "nature_sense key")
	assert_eq(def.discovery_time, "", "no time req")

func test_silver_discovery_by_keen_eye() -> void:
	var def = Resources.get_resource(&"silver")
	assert_not_null(def, "silver exists")
	assert_eq(def.discovery_skill, &"keen_eye", "keen_eye key")
	assert_eq(def.discovery_time, "night", "night req")

func test_quartz_extraction() -> void:
	var def = Resources.get_resource(&"quartz")
	assert_not_null(def, "quartz exists")
	assert_eq(def.extraction_unit, &"worker", "worker tag")
	assert_eq(def.extraction_tool, &"cart", "cart tag")

func test_saltpeter_extraction() -> void:
	var def = Resources.get_resource(&"saltpeter")
	assert_not_null(def, "saltpeter exists")
	assert_eq(def.extraction_unit, &"worker", "worker tag")
	assert_eq(def.extraction_consumable, &"skin_protection", "consumable")

func test_turquoise_extraction() -> void:
	var def = Resources.get_resource(&"turquoise")
	assert_not_null(def, "turquoise exists")
	assert_eq(def.extraction_tag, &"precise_strike", "precise_strike")

func test_limonite_extraction() -> void:
	var def = Resources.get_resource(&"limonite")
	assert_not_null(def, "limonite exists")
	assert_true(def.extraction_fire, "fire extraction")

func test_coal_extraction() -> void:
	var def = Resources.get_resource(&"coal")
	assert_not_null(def, "coal exists")
	assert_eq(def.extraction_unit, &"miner", "miner tag")

func test_gold_ore_extraction() -> void:
	var def = Resources.get_resource(&"gold_ore")
	assert_not_null(def, "gold_ore exists")
	assert_eq(def.extraction_unit, &"miner", "miner tag")
	assert_eq(def.extraction_tool, &"precise_strike", "precise_strike")

func test_coal_swamp_auto() -> void:
	var def = Resources.get_resource(&"coal_swamp")
	assert_not_null(def, "coal_swamp exists")
	assert_true(def.discovery_auto, "auto discovery")
	assert_true(&"undead" in def.discovery_auto_tags, "undead tag")
	assert_true(&"lizard" in def.discovery_auto_tags, "lizard tag")

func test_bog_iron_extraction() -> void:
	var def = Resources.get_resource(&"bog_iron")
	assert_not_null(def, "bog_iron exists")

func test_cinnabar_extraction() -> void:
	var def = Resources.get_resource(&"cinnabar")
	assert_not_null(def, "cinnabar exists")
	assert_eq(def.extraction_tag, &"poison_immune", "poison_immune")

func test_wood_basic() -> void:
	var def = Resources.get_resource(&"wood")
	assert_not_null(def, "wood exists")

func test_stone_basic() -> void:
	var def = Resources.get_resource(&"stone")
	assert_not_null(def, "stone exists")

func test_hidden_vs_basic() -> void:
	assert_true(Resources.is_hidden_resource(&"oak"), "oak hidden")
	assert_true(Resources.is_hidden_resource(&"silver"), "silver hidden")
	assert_false(Resources.is_hidden_resource(&"wood"), "wood not hidden")
	assert_false(Resources.is_hidden_resource(&"stone"), "stone not hidden")

func test_get_hidden_ids() -> void:
	var ids = Resources.get_hidden_resource_ids()
	assert_eq(ids.size(), 11, "11 hidden resources")

func test_get_all() -> void:
	var all = Resources.get_all()
	assert_eq(all.size(), 13, "13 total")

func test_biome_grass() -> void:
	var defs = Resources.get_by_biome("grass")
	assert_true(defs.size() >= 3, "grass has oak, silver, wood")

func test_biome_snow() -> void:
	var defs = Resources.get_by_biome("snow")
	assert_true(defs.size() >= 3, "snow has limonite, coal, gold_ore")
