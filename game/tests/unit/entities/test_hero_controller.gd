# TASK_18 B2.1: HeroController — компоненты, проброс сигналов, бой, сериализация.
extends BaseTest


var _hero: HeroController

func before_test() -> void:
	_hero = HeroController.new()
	_hero.name = "TestHero"
	add_child(_hero)

func after_test() -> void:
	if is_instance_valid(_hero):
		_hero.free()
	_hero = null

func test_all_components_registered() -> void:
	assert_int(_hero._components.size()).is_equal(14)
	for comp_name in [&"Movement", &"Army", &"Magic", &"Resources", &"Visual",
			&"Needs", &"Inventory", &"Skills", &"Tools", &"Time",
			&"StrategicResources", &"Followers", &"Combat", &"Stats"]:
		assert_that(_hero.get_component(str(comp_name))).is_not_null() \
				.override_failure_message("missing component: " + str(comp_name))

func test_get_component_unknown_is_null() -> void:
	assert_that(_hero.get_component("NoSuchComponent")).is_null()

func test_resources_changed_forwarded() -> void:
	var got := []
	_hero.resources_changed.connect(func(r): got.append(r))
	_hero.resources_comp.resources_changed.emit({"gold": 10})
	assert_int(got.size()).is_equal(1)
	assert_int(got[0].get("gold", -1)).is_equal(10)

func test_hero_moved_forwarded() -> void:
	var cells := []
	_hero.hero_moved.connect(func(c): cells.append(c))
	_hero.movement_comp.hero_moved.emit(Vector2i(3, 4))
	assert_int(cells.size()).is_equal(1)
	assert_that(cells[0]).is_equal(Vector2i(3, 4))

func test_time_changed_forwarded() -> void:
	var hours := []
	_hero.time_changed.connect(func(h): hours.append(h))
	_hero.time_comp.time_changed.emit(12.5)
	assert_int(hours.size()).is_equal(1)
	assert_float(hours[0]).is_equal(12.5)

func test_combat_dead_lifecycle() -> void:
	_hero.combat_comp.max_combat_hp = 100
	_hero.set_combat_hp(10)
	assert_bool(_hero.is_combat_dead()).is_false()
	_hero.mark_combat_dead()
	assert_bool(_hero.is_combat_dead()).is_true()
	_hero.set_combat_hp(10)
	assert_bool(_hero.is_combat_dead()).is_false()

func test_revive_at_null_city() -> void:
	_hero.combat_comp.max_combat_hp = 100
	_hero.mark_combat_dead()
	_hero.revive_at(null)
	assert_bool(_hero.is_combat_dead()).is_false()
	assert_int(_hero.combat_comp.combat_hp).is_equal(100)

func test_get_daily_movement_points_positive() -> void:
	assert_float(_hero.get_daily_movement_points()).is_greater(0.0)

func test_has_artifact_effect_false_on_empty_inventory() -> void:
	assert_bool(_hero.has_artifact_effect(&"whatever")).is_false()

func test_serialize_contains_core_keys() -> void:
	var data := _hero.serialize()
	assert_that(data.has("cell")).is_true().override_failure_message("missing 'cell'")
	assert_that(data.has("combat_hp")).is_true().override_failure_message("missing 'combat_hp'")

func test_serialize_deserialize_roundtrip_combat() -> void:
	_hero.combat_comp.max_combat_hp = 100
	_hero.set_combat_hp(42)
	var data := _hero.serialize()
	var other = auto_free(HeroController.new())
	other.deserialize(data)
	assert_int(other.combat_comp.combat_hp).is_equal(42)
	assert_bool(other.is_combat_dead()).is_false()

func test_end_turn_emits_movement_points() -> void:
	var hits: Array = []
	_hero.movement_points_changed.connect(func(c, m): hits.append([c, m]))
	_hero.end_turn()
	assert_int(hits.size()).is_equal(1)
