# TASK_18 B2.3: WorldBootstrap — бутстрап мира и связность результата.
extends BaseTest


var _nodes: Array[Node] = []

func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

# Бут: World.tscn + помпа реальных кадров. _ready контроллера содержит await-цепочку,
# поэтому ждём, пока finalize доберётся до _event_router (до 120 кадров).
func _boot_world() -> WorldController:
	var res: Resource = ResourceLoader.load("res://scenes/world.tscn")
	var node: Node = res.instantiate()
	node.name = "TestWorld"
	get_tree().root.add_child(node)
	_nodes.append(node)
	var wc := node as WorldController
	for i in 120:
		await get_tree().process_frame
		if wc._event_router != null:
			break
	return wc

func test_boot_produces_bootstrap_result() -> void:
	var wc := await _boot_world()
	var R = wc._bootstrap_result
	assert_that(R).is_not_null()
	for field in ["map_gen", "hero", "camera", "input_controller", "spawner",
			"cities", "battle_coordinator", "interaction_controller", "endgame"]:
		assert_that(R.get(field)).is_not_null() \
				.override_failure_message("bootstrap missing: " + field)

func test_boot_session_and_map_rect() -> void:
	var wc := await _boot_world()
	var R = wc._bootstrap_result
	assert_that(R.session).is_not_null()
	assert_int(R.session.run_seed).is_greater(0)
	assert_float(R.map_rect.size.x).is_greater(0.0)
	assert_float(R.map_rect.size.y).is_greater(0.0)

func test_boot_finalized_with_event_router() -> void:
	var wc := await _boot_world()
	assert_that(wc._event_router).is_not_null()
	assert_that(wc._hero).is_not_null()
	assert_that(wc._map_gen).is_not_null()
	assert_that(wc._hero_mgr).is_not_null()
	assert_that(wc._save_svc).is_not_null()

func test_boot_hero_is_hero_controller() -> void:
	var wc := await _boot_world()
	var hero := wc.get_hero()
	assert_that(hero).is_not_null()
	assert_bool(hero is HeroController).is_true()
	assert_int(hero._components.size()).is_equal(14)

func test_boot_endgame_wired() -> void:
	var wc := await _boot_world()
	var R = wc._bootstrap_result
	assert_bool(R.endgame is EndgameController).is_true()
