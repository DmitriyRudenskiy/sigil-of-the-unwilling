extends GdUnitTestSuite

const WorldLoadContext = preload("res://scripts/world/WorldLoadContext.gd")
const ResourceChainService = preload("res://scripts/world/ResourceChainService.gd")


func test_extraction_keys_cache_and_fingerprint() -> void:
	# Поведение вместо проверки наличия методов: кэш по instance_id + fingerprint героя.
	var chain := ResourceChainService.new()
	var hero := TestFactories.make_hero()
	get_tree().root.add_child(hero)

	var keys1: Dictionary = chain.build_extraction_keys(hero)
	var keys2: Dictionary = chain.build_extraction_keys(hero)
	assert_dict(keys2).is_equal(keys1).override_failure_message("повторный вызов возвращает идентичный кэш")

	# Смена состояния героя (армия) -> fingerprint меняется -> ключи пересчитываются.
	hero.army.army.append(Units.make_fixed_stack("swordsmen", 5))
	var keys3: Dictionary = chain.build_extraction_keys(hero)
	assert_dict(keys3).contains_keys(&"swordsmen").override_failure_message("новые ключи должны учитывать добавленного юнита")
	assert_bool(keys3 != keys1).is_true().override_failure_message("после изменения героя кэш должен пересчитаться")

	chain.invalidate_extraction_cache()
	var keys4: Dictionary = chain.build_extraction_keys(hero)
	assert_dict(keys4).is_equal(keys3).override_failure_message("после invalidate ключи пересчитываются идентично")

	hero.queue_free()



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
