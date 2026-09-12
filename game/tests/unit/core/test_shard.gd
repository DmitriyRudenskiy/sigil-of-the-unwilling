extends BaseTest








var _hero: Node = null

func after_test() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	_hero = null

func test_shard_state_defaults() -> void:
	var s := ShardState.new()
	assert_bool(s.id == &"shard_1").is_true().override_failure_message("default id should be shard_1")
	assert_int(s.seed_val).is_zero().override_failure_message("default seed should be 0")
	assert_bool(s.completed).is_false().override_failure_message("default completed should be false")
	assert_bool(s.entry_cell == Vector2i(10, 10)).is_true().override_failure_message("default entry_cell should be (10, 10)")

func test_shard_state_custom() -> void:
	var s := ShardState.new(&"shard_2", "Забвение", 0x2A1F3C7, "waste", Vector2i(3, 4))
	assert_bool(s.id == &"shard_2").is_true().override_failure_message("custom id should be shard_2")
	assert_str(s.name).is_equal("Забвение").override_failure_message("custom name should be 'Забвение'")
	assert_int(s.seed_val).is_equal(0x2A1F3C7).override_failure_message("custom seed mismatch")
	assert_str(s.biome_mix).is_equal("waste").override_failure_message("custom biome_mix should be 'waste'")
	assert_bool(s.entry_cell == Vector2i(3, 4)).is_true().override_failure_message("custom entry_cell should be (3, 4)")

func test_shard_state_roundtrip() -> void:
	var s := ShardState.new(&"shard_2", "Забвение", 0x2A1F3C7, "waste", Vector2i(3, 4))
	s.completed = true
	var d := s.to_dict()
	var s2 := ShardState.from_dict(d)
	assert_bool(s2.id == s.id).is_true().override_failure_message("roundtrip id mismatch")
	assert_str(s2.name).is_equal(s.name).override_failure_message("roundtrip name mismatch")
	assert_int(s2.seed_val).is_equal(s.seed_val).override_failure_message("roundtrip seed mismatch")
	assert_str(s2.biome_mix).is_equal(s.biome_mix).override_failure_message("roundtrip biome_mix mismatch")
	assert_bool(s2.entry_cell == s.entry_cell).is_true().override_failure_message("roundtrip entry_cell mismatch")
	assert_bool(s2.completed == s.completed).is_true().override_failure_message("roundtrip completed mismatch")

func test_manager_default_campaign() -> void:
	ShardManager.reset()
	var m := ShardManager.instance()
	assert_bool(m.active_id == &"shard_1").is_true().override_failure_message("default active should be shard_1")
	var s1 = m.get_shard(&"shard_1")
	assert_object(s1).is_not_null().override_failure_message("shard_1 not found")
	assert_int(s1.seed_val).is_zero().override_failure_message("shard_1 seed should be 0")
	var s2 := m.get_shard(&"shard_2")
	assert_object(s2).is_not_null().override_failure_message("shard_2 not found")
	assert_int(s2.seed_val).is_equal(ShardManager.SHARD_2_SEED).override_failure_message("shard_2 seed should be SHARD_2_SEED")

func test_manager_active_switch() -> void:
	ShardManager.reset()
	var m := ShardManager.instance()
	assert_bool(m.set_active(&"shard_2")).is_true().override_failure_message("set_active(shard_2) should succeed")
	assert_bool(m.active_id == &"shard_2").is_true().override_failure_message("active should be shard_2 after switch")
	assert_bool(m.set_active(&"nope")).is_false().override_failure_message("set_active with unknown id should fail")
	assert_bool(m.active_id == &"shard_2").is_true().override_failure_message("active should stay shard_2 after failed switch")
	m.set_active(&"shard_1")

func test_manager_list_ids() -> void:
	ShardManager.reset()
	var m := ShardManager.instance()
	var ids := m.shard_ids()
	assert_int(ids.size()).is_equal(2).override_failure_message("should have 2 shards")
	assert_bool(ids.has(&"shard_1") and ids.has(&"shard_2")).is_true().override_failure_message("shard ids content mismatch")
	assert_int(m.list().size()).is_equal(2).override_failure_message("list() should return 2 shards")

func test_save_preserves_other_shards() -> void:
	ShardManager.reset()
	var m := ShardManager.instance()
	var sm = auto_free( SaveManager.new())
	sm.delete_save()
	var p := WorldPersistence.new(sm)
	p.session = GameSession.new(1)
	p.world_delta = WorldStateDelta.new()
	var hero = auto_free( HeroController.new())
	_hero = hero
	add_child(hero)

	assert_bool(p.save_game(hero)).is_true().override_failure_message("save shard_1 failed")

	m.set_active(&"shard_2")
	assert_bool(p.save_game(hero)).is_true().override_failure_message("save shard_2 failed")

	var res: Dictionary = sm.load_game()
	var sd = res.get("data", null)
	assert_object(sd).is_not_null().override_failure_message("no save on disk")
	var found: Dictionary = {}
	for k in sd.shards:
		found[str(k)] = true
	assert_bool(found.has("shard_1")).is_true().override_failure_message("shard_1 lost after save to shard_2")
	assert_bool(found.has("shard_2")).is_true().override_failure_message("shard_2 missing")
	assert_str(str(sd.active_shard_id)).is_equal("shard_2").override_failure_message("active_shard_id should be shard_2")

	sm.delete_save()
	sm.free()
