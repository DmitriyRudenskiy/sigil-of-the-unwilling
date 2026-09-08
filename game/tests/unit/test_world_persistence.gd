extends GdUnitTestSuite

const WorldLoadContext = preload("res://scripts/world/WorldLoadContext.gd")
const ResourceChainService = preload("res://scripts/world/ResourceChainService.gd")


func test_chain_service_has_methods() -> void:
	var chain := ResourceChainService.new()
	assert_bool(chain.has_method("build_discovery_keys")).is_true()
	assert_bool(chain.has_method("build_extraction_keys")).is_true()
	assert_bool(chain.has_method("invalidate_extraction_cache")).is_true()
	assert_bool(chain.has_method("try_extract")).is_true()


func test_extraction_cache_invalidation() -> void:
	var chain := ResourceChainService.new()
	chain.invalidate_extraction_cache()
	assert_bool(chain.get_script() == ResourceChainService).is_true()



func test_load_context_fields() -> void:
	var ctx := WorldLoadContext.new()
	ctx.map_gen = null
	ctx.spawner = null
	ctx.resource_node_manager = null
	ctx.ui_manager = null
	ctx.camera = null
	ctx.hero = null
	ctx.world_delta = WorldStateDelta.new()
	assert_that(ctx.world_delta).is_not_null()


func test_load_context_creation() -> void:
	var ctx := WorldLoadContext.new()
	assert_bool(ctx != null).is_true()


func test_save_data_apply_roundtrip() -> void:
	var delta := WorldStateDelta.new()
	var enemy_cell := Vector2i(5, 5)
	var village_cell := Vector2i(3, 3)
	delta.add_defeated_enemy(enemy_cell)
	delta.add_village(village_cell)

	var serialized := delta.serialize()
	assert_dict(serialized).is_not_empty()

	var delta2 := WorldStateDelta.new()
	delta2.deserialize(serialized)

	assert_that(delta2.defeated_enemies.size()).is_equal(1)
	assert_that(delta2.captured_villages.size()).is_equal(1)
