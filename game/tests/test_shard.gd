extends SceneTree
## astral-macro Stage 1: ShardState + ShardManager unit tests.

const _ShardState = preload("res://scripts/core/ShardState.gd")
const _ShardManager = preload("res://scripts/core/ShardManager.gd")

var _failed := 0


func _init() -> void:
	_failed += _test_shard_state_defaults()
	_failed += _test_shard_state_custom()
	_failed += _test_shard_state_roundtrip()
	_failed += _test_manager_default_campaign()
	_failed += _test_manager_active_switch()
	_failed += _test_manager_list_ids()

	if _failed == 0:
		print("Shard tests passed")
	else:
		printerr("Shard tests failed: ", _failed)
	await process_frame
	quit(1 if _failed > 0 else 0)


func _test_shard_state_defaults() -> int:
	var e := 0
	var s := _ShardState.new()
	if s.id != &"shard_1":
		printerr("default id: ", str(s.id)); e += 1
	if s.seed != 0:
		printerr("default seed: ", s.seed); e += 1
	if s.completed != false:
		printerr("default completed: ", s.completed); e += 1
	if s.entry_cell != Vector2i(10, 10):
		printerr("default entry_cell: ", s.entry_cell); e += 1
	return e


func _test_shard_state_custom() -> int:
	var e := 0
	var s := _ShardState.new(&"shard_2", "Забвение", 0x2A1F3C7, "waste", Vector2i(3, 4))
	if s.id != &"shard_2":
		printerr("custom id: ", str(s.id)); e += 1
	if s.name != "Забвение":
		printerr("custom name: ", s.name); e += 1
	if s.seed != 0x2A1F3C7:
		printerr("custom seed: ", s.seed); e += 1
	if s.biome_mix != "waste":
		printerr("custom biome: ", s.biome_mix); e += 1
	if s.entry_cell != Vector2i(3, 4):
		printerr("custom entry: ", s.entry_cell); e += 1
	return e


func _test_shard_state_roundtrip() -> int:
	var e := 0
	var s := _ShardState.new(&"shard_2", "Забвение", 0x2A1F3C7, "waste", Vector2i(3, 4))
	s.completed = true
	var d := s.to_dict()
	var s2 := _ShardState.from_dict(d)
	if s2.id != s.id:
		printerr("rt id: ", str(s2.id)); e += 1
	if s2.name != s.name:
		printerr("rt name: ", s2.name); e += 1
	if s2.seed != s.seed:
		printerr("rt seed: ", s2.seed); e += 1
	if s2.biome_mix != s.biome_mix:
		printerr("rt biome: ", s2.biome_mix); e += 1
	if s2.entry_cell != s.entry_cell:
		printerr("rt entry: ", s2.entry_cell); e += 1
	if s2.completed != s.completed:
		printerr("rt completed: ", s2.completed); e += 1
	return e


func _test_manager_default_campaign() -> int:
	var e := 0
	_ShardManager.reset()
	var m := _ShardManager.instance()
	if m.active_id != &"shard_1":
		printerr("default active: ", str(m.active_id)); e += 1
	if m.get_shard(&"shard_1") == null or m.get_shard(&"shard_1").seed != 0:
		printerr("shard_1 seed: ", str(m.get_shard(&"shard_1").seed)); e += 1
	var s2 := m.get_shard(&"shard_2")
	if s2 == null or s2.seed != _ShardManager.SHARD_2_SEED:
		printerr("shard_2 seed: ", str(s2.seed) if s2 != null else "null"); e += 1
	return e


func _test_manager_active_switch() -> int:
	var e := 0
	_ShardManager.reset()
	var m := _ShardManager.instance()
	if m.set_active(&"shard_2") != true:
		printerr("set shard_2 failed"); e += 1
	if m.active_id != &"shard_2":
		printerr("active after switch: ", str(m.active_id)); e += 1
	if m.set_active(&"nope") != false:
		printerr("set bogus should fail"); e += 1
	if m.active_id != &"shard_2":
		printerr("active after bogus: ", str(m.active_id)); e += 1
	m.set_active(&"shard_1")
	return e


func _test_manager_list_ids() -> int:
	var e := 0
	_ShardManager.reset()
	var m := _ShardManager.instance()
	var ids := m.shard_ids()
	if ids.size() != 2:
		printerr("shard count: ", ids.size()); e += 1
	if not (ids.has(&"shard_1") and ids.has(&"shard_2")):
		printerr("shard ids content: ", ids); e += 1
	if m.list().size() != 2:
		printerr("list size: ", m.list().size()); e += 1
	return e
