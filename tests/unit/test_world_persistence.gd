extends "../test_base.gd"
## Tests for WorldLoadContext and ResourceChainService (static fields tested via main runner).

const WorldLoadContext = preload("res://scripts/world/WorldLoadContext.gd")
const ResourceChainService = preload("res://scripts/world/ResourceChainService.gd")

# ----- ResourceChainService tests -----

func test_chain_service_has_methods() -> void:
	var chain := ResourceChainService.new()
	assert_true(chain.has_method("build_discovery_keys"), "has build_discovery_keys")
	assert_true(chain.has_method("build_extraction_keys"), "has build_extraction_keys")
	assert_true(chain.has_method("invalidate_extraction_cache"), "has invalidate_extraction_cache")
	assert_true(chain.has_method("try_extract"), "has try_extract")


func test_extraction_cache_invalidation() -> void:
	var chain := ResourceChainService.new()
	chain.invalidate_extraction_cache()
	assert_true(chain.get_script() == ResourceChainService, "service intact after invalidation")


# ----- WorldLoadContext tests -----

func test_load_context_fields() -> void:
	var ctx := WorldLoadContext.new()
	ctx.map_gen = null
	ctx.spawner = null
	ctx.resource_node_manager = null
	ctx.ui_manager = null
	ctx.camera = null
	ctx.hero = null
	ctx.world_delta = WorldStateDelta.new()
	assert_not_null(ctx.world_delta, "world_delta set")


func test_load_context_creation() -> void:
	var ctx := WorldLoadContext.new()
	assert_true(ctx != null, "WorldLoadContext instance")


# ----- SaveData apply parity test -----
func test_save_data_apply_roundtrip() -> void:
	# Build a SaveData with known delta state and verify deserialization
	var delta := WorldStateDelta.new()
	var enemy_cell := Vector2i(5, 5)
	var village_cell := Vector2i(3, 3)
	delta.add_defeated_enemy(enemy_cell)
	delta.add_village(village_cell)

	var serialized := delta.serialize()
	assert_not_empty(serialized, "serialized delta not empty")

	# Deserialize into a fresh delta
	var delta2 := WorldStateDelta.new()
	delta2.deserialize(serialized)

	assert_eq(delta2.defeated_enemies.size(), 1, "one defeated enemy")
	assert_eq(delta2.captured_villages.size(), 1, "one captured village")
