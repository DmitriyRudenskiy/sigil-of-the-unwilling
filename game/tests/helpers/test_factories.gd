extends GdUnitTestSuite

func test_make_battle_state_places_both_sides() -> void:
	var bs := TestFactories.make_battle_state()
	assert_that(bs.attacker_units.size()).is_equal(1)
	assert_that(bs.defender_units.size()).is_equal(1)
	assert_that(bs.attacker_units[0].get_key()).is_equal("swordsmen")
	assert_that(bs.defender_units[0].get_key()).is_equal("goblins")
	assert_that(bs.attacker_units[0].get_count()).is_equal(20)

func test_make_battle_state_custom_keys() -> void:
	var bs := TestFactories.make_battle_state("archers", "skeleton", 3, 4)
	assert_that(bs.attacker_units[0].get_key()).is_equal("archers")
	assert_that(bs.defender_units[0].get_count()).is_equal(4)

func test_make_city_with_temple() -> void:
	var city := TestFactories.make_city_with_temple()
	var found := false
	for building in city.buildings:
		if building.def != null and building.def.id == &"great_temple" and building.level == 2:
			found = true
	assert_bool(found).is_true()

func test_make_hero_and_follower() -> void:
	var h := TestFactories.make_hero(&"warrior")
	assert_that(h.path_id).is_equal(&"warrior")
	var f := TestFactories.make_follower(7)
	assert_that(f.uid).is_equal(7)
	h.free()
