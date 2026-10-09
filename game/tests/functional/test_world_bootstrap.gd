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

func test_boot_hero_has_city_manager_for_need_recovery() -> void:
	var wc := await _boot_world()
	var hero := wc.get_hero()
	var cities: CityManager = wc._bootstrap_result.cities
	assert_bool(hero.city_manager == cities).is_true()
	assert_bool(cities.city_at(cities.capital.center) == cities.capital).is_true()
	hero.movement_comp.set_current_cell(cities.capital.center)
	hero.needs_comp.needs.needs[NeedType.ID.REST] = 0.5
	hero.needs_comp.end_turn()
	assert_that(hero.needs_comp.get_need(NeedType.ID.REST)).is_greater(0.5)

func test_new_world_resets_scenario_counters_after_previous_scenario() -> void:
	var persistence = Services.resolve(&"persistence")
	if persistence != null:
		persistence.pending_save = null
	BattleTrophyService.reset_for_session()
	var first_trophy: Dictionary = BattleTrophyService.roll_trophy()
	BattleTrophyService.roll_trophy()
	WorldSeasons.set_turns(90)
	var wc := await _boot_world()
	assert_that(wc._bootstrap_result.loaded_save).is_null()
	assert_that(WorldSeasons.get_turns()).is_equal(0)
	assert_that(BattleTrophyService.roll_trophy()).is_equal(first_trophy)
	BattleTrophyService.reset_for_session()

func test_boot_seeds_city_random_systems_from_session_rng() -> void:
	var wc := await _boot_world()
	var session_rng: RandomNumberGenerator = wc._bootstrap_result.rng
	assert_bool(CharismaEvents._rng == session_rng).is_true()
	assert_bool(ReputationSystem._rng == session_rng).is_true()
	assert_bool(CityService._rng_override == session_rng).is_true()
	assert_bool(WeaponTechService._rng == session_rng).is_true()

func test_boot_hero_is_hero_controller() -> void:
	var wc := await _boot_world()
	var hero := wc.get_hero()
	assert_that(hero).is_not_null()
	assert_bool(hero is HeroController).is_true()
	assert_int(hero._components.size()).is_equal(16)

func test_boot_endgame_wired() -> void:
	var wc := await _boot_world()
	var R = wc._bootstrap_result
	assert_bool(R.endgame is EndgameController).is_true()
