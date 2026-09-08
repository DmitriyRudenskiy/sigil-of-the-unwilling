extends GdUnitTestSuite

var _sc: SuccessionController


func before_test() -> void:
	_sc = SuccessionController.new()


func _hero_with_followers() -> HeroController:
	var hero := HeroController.new()
	auto_free(hero)
	hero.path_id = &"warrior"
	var f1 := Follower.new()
	f1.uid = 2
	f1.path = &"warrior"
	var f2 := Follower.new()
	f2.uid = 1
	f2.path = &"warrior"
	var other := Follower.new()
	other.uid = 3
	other.path = &"scholar"
	hero.followers = [f1, f2, other]
	return hero


func test_select_successor_no_followers_returns_null() -> void:
	var hero := HeroController.new()
	auto_free(hero)
	hero.path_id = &"warrior"
	assert_object(_sc.select_successor(hero)).is_null()


func test_select_successor_matches_path_and_sorts_by_uid() -> void:
	var hero := _hero_with_followers()
	var s := _sc.select_successor(hero)
	assert_object(s).is_not_null()
	assert_int(s.uid).is_equal(1)


func test_select_successor_no_matching_path_returns_null() -> void:
	var hero := HeroController.new()
	auto_free(hero)
	hero.path_id = &"mage"
	var f := Follower.new()
	f.uid = 1
	f.path = &"warrior"
	hero.followers = [f]
	assert_object(_sc.select_successor(hero)).is_null()


func test_build_successor_transfers_inventory_and_path() -> void:
	var hero := HeroController.new()
	auto_free(hero)
	hero.path_id = &"warrior"
	var equipped := Artifact.new()
	equipped.id = &"sword"
	equipped.slot = Artifact.Slot.WEAPON
	hero.inventory.equipped[Artifact.Slot.WEAPON] = equipped
	var packed := Artifact.new()
	packed.id = &"ring"
	hero.inventory.backpack.append(packed)
	hero.magic.mana_current = 7
	hero.magic.mana_max = 10

	var succ := _sc.build_successor(hero)
	auto_free(succ)
	assert_that(succ.path_id).is_equal(&"warrior")
	assert_object(succ.inventory.equipped.get(Artifact.Slot.WEAPON)).is_not_null()
	
	assert_object(succ.inventory.equipped[Artifact.Slot.WEAPON]).is_not_same(hero.inventory.equipped[Artifact.Slot.WEAPON])
	assert_array(succ.inventory.backpack).has_size(1)
	assert_that(succ.inventory.backpack[0].id).is_equal(&"ring")
	assert_int(succ.magic.mana_current).is_equal(7)


func test_resurrect_hero_requires_temple() -> void:
	var city := City.new()
	assert_bool(_sc.resurrect_hero(city)).is_false()


func test_resurrect_hero_deducts_storage() -> void:
	var city := City.new()
	city.storage[&"gold"] = 150.0
	city.storage[&"industry"] = 600.0
	var temple := UniqueBuilding.new()
	temple.def = UniqueBuilding.Def.new()
	temple.def.id = &"great_temple"
	temple.level = 1
	city.buildings.append(temple)
	assert_bool(_sc.resurrect_hero(city)).is_true()
	assert_float(city.storage[&"gold"]).is_equal(50.0)
	assert_float(city.storage[&"industry"]).is_equal(100.0)


func test_on_hero_died_returns_successor() -> void:
	var hero := _hero_with_followers()
	var succ := _sc.on_hero_died(hero)
	auto_free(succ)
	assert_object(succ).is_not_null()
	assert_that(succ.path_id).is_equal(&"warrior")
	assert_object(_sc.on_hero_died(null)).is_null()
