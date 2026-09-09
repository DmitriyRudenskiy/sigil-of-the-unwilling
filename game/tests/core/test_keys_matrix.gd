extends GdUnitTestSuite

func test_oak_discovery_by_nature_sense() -> void:
	var def = Resources.get_resource(&"oak")
	assert_that(def).is_not_null()
	assert_that(def.discovery_skill).is_equal(&"nature_sense")
	assert_that(def.discovery_time).is_equal("")

func test_silver_discovery_by_keen_eye() -> void:
	var def = Resources.get_resource(&"silver")
	assert_that(def).is_not_null()
	assert_that(def.discovery_skill).is_equal(&"keen_eye")
	assert_that(def.discovery_time).is_equal("night")

func test_quartz_extraction() -> void:
	var def = Resources.get_resource(&"quartz")
	assert_that(def).is_not_null()
	assert_that(def.extraction_unit).is_equal(&"worker")
	assert_that(def.extraction_tool).is_equal(&"cart")

func test_saltpeter_extraction() -> void:
	var def = Resources.get_resource(&"saltpeter")
	assert_that(def).is_not_null()
	assert_that(def.extraction_unit).is_equal(&"worker")
	assert_that(def.extraction_consumable).is_equal(&"skin_protection")

func test_turquoise_extraction() -> void:
	var def = Resources.get_resource(&"turquoise")
	assert_that(def).is_not_null()
	assert_that(def.extraction_tag).is_equal(&"precise_strike")

func test_limonite_extraction() -> void:
	var def = Resources.get_resource(&"limonite")
	assert_that(def).is_not_null()
	assert_bool(def.extraction_fire).is_true()

func test_coal_extraction() -> void:
	var def = Resources.get_resource(&"coal")
	assert_that(def).is_not_null()
	assert_that(def.extraction_unit).is_equal(&"miner")

func test_gold_ore_extraction() -> void:
	var def = Resources.get_resource(&"gold_ore")
	assert_that(def).is_not_null()
	assert_that(def.extraction_unit).is_equal(&"miner")
	assert_that(def.extraction_tool).is_equal(&"precise_strike")

func test_coal_swamp_auto() -> void:
	var def = Resources.get_resource(&"coal_swamp")
	assert_that(def).is_not_null()
	assert_bool(def.discovery_auto).is_true()
	assert_bool(&"undead" in def.discovery_auto_tags).is_true()
	assert_bool(&"lizard" in def.discovery_auto_tags).is_true()

func test_bog_iron_extraction() -> void:
	var def = Resources.get_resource(&"bog_iron")
	assert_that(def).is_not_null()

func test_cinnabar_extraction() -> void:
	var def = Resources.get_resource(&"cinnabar")
	assert_that(def).is_not_null()
	assert_that(def.extraction_tag).is_equal(&"poison_immune")

func test_wood_basic() -> void:
	var def = Resources.get_resource(&"wood")
	assert_that(def).is_not_null()

func test_stone_basic() -> void:
	var def = Resources.get_resource(&"stone")
	assert_that(def).is_not_null()

func test_hidden_vs_basic() -> void:
	assert_bool(Resources.is_hidden_resource(&"oak")).is_true()
	assert_bool(Resources.is_hidden_resource(&"silver")).is_true()
	assert_bool(Resources.is_hidden_resource(&"wood")).is_false()
	assert_bool(Resources.is_hidden_resource(&"stone")).is_false()

func test_get_hidden_ids() -> void:
	var ids = Resources.get_hidden_resource_ids()
	assert_that(ids.size()).is_equal(11)

func test_get_all() -> void:
	var all = Resources.get_all()
	assert_that(all.size()).is_equal(20)

func test_biome_grass() -> void:
	var defs = Resources.get_by_biome("grass")
	assert_bool(defs.size() >= 3).is_true()

func test_biome_snow() -> void:
	var defs = Resources.get_by_biome("snow")
	assert_bool(defs.size() >= 3).is_true()
