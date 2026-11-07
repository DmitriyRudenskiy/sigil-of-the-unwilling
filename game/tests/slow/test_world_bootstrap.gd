# TASK_18 B2.3: WorldBootstrap — бутстрап мира и связность результата.
extends BaseTest

## Слой `slow` (срез test-suite-restructure): 4.5 с на 8 проверок при медиане сюиты
## ~0.2 с (замер 2026-11-02, «Стоимость прогона» в docs/mvp/TEST-MAP.md) — строит мир.
## В `--tier=fast` не входит, собирается `full`.


var _nodes: Array[Node] = []

func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

	# Знак — состояние autoload-персистентности: не отдавать его следующему тесту.
	Services.resolve(&"persistence").pending_sign_id = ""

# Бут: World.tscn + помпа реальных кадров. _ready контроллера содержит await-цепочку,
# поэтому ждём, пока finalize доберётся до _event_router (до 120 кадров).
func _boot_world() -> WorldController:
	var res: Resource = ResourceLoader.load("res://scenes/ui/adventure_ui.tscn")
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

func test_pending_sign_reaches_the_hero() -> void:
	# remove-campaign-mechanic 1.3: Знак из предыгры доезжает до героя мира
	# (до сноса кампейна его читал только main.gd).
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	persistence.pending_sign_id = "spark"
	var wc := await _boot_world()
	var hero := wc.get_hero()
	assert_that(hero).is_not_null()
	assert_str(hero.sign_id).is_equal("spark") \
			.override_failure_message("pending_sign_id не дожил до героя мира")
	assert_str(persistence.pending_sign_id).is_equal("")


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

# --- пара городов из бутстрапа (прежний дом — functional/test_city_navigation.gd,
# шаг 7 T-305, 2026-10-30): предмет — WorldBootstrap._create_cities.

func _make_two_cities() -> Dictionary:
	# Прежний дом — functional/test_city_navigation.gd (шаг 7 T-305, 2026-10-30).
	var h := Node2D.new()
	h.name = "TwoCitiesHolder"
	get_tree().root.add_child(h)
	_nodes.append(h)
	var mg: MapGenerator = MapGenerator.new()
	mg.name = "MapGenerator"
	mg.seed_value = 42
	h.add_child(mg)
	assert_bool(mg.has_valid_tilemap()).is_true()
	var R = WorldBootstrap.BootstrapResult.new()
	R.map_gen = mg
	WorldBootstrap._create_cities(h, R)
	var capital: City = R.cities.capital
	var second: City = null
	for city in R.cities.cities:
		if city != capital:
			second = city
	return {"mg": mg, "cities": R.cities, "capital": capital, "second": second}

func test_bootstrap_creates_two_cities() -> void:
	var w: Dictionary = _make_two_cities()
	var cities = w.cities
	assert_that(cities.cities.size()).is_equal(2)
	var capital: City = w.capital
	assert_that(capital).is_not_null()
	assert_bool(capital.is_capital).is_true()
	assert_that(capital.display_name).is_equal("Перворечье")
	var capitals := 0
	for city in cities.cities:
		if city.is_capital:
			capitals += 1
	assert_that(capitals).is_equal(1)
	var second: City = w.second
	assert_that(second).is_not_null()
	assert_bool(second.is_capital).is_false()
	assert_that(second.display_name).is_equal("Город 2")
	assert_that(second.owner).is_equal(&"player")
	var d := HexUtils.hex_distance(capital.center, second.center)
	assert_int(d).is_greater(8)
	assert_int(d).is_less(25)
	assert_bool(w.mg.is_walkable(second.center)).is_true()
	assert_bool(w.mg.is_walkable(capital.center)).is_true()
