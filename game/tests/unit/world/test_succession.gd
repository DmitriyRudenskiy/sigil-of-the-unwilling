extends GdUnitTestSuite

const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Artifact = preload("res://scripts/data/Artifact.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := _Follower.new()
	f.uid = uid
	f.name = "F%d" % uid
	f.path = path
	return f

func _succession_hero(path := &"archivist") -> HeroController:
	var h := TestFactories.make_hero(path)
	h.magic.spellbook = [&"firebolt", &"heal"]
	h.magic.schools = {&"air": 1, &"fire": 2}
	h.magic.mana_current = 10
	h.magic.mana_max = 20
	var ring := _Artifact.new(&"ring_of_might", &"Ring of Might", _Artifact.Slot.RING_L,
		_Artifact.Rarity.MINOR, {}, &"mana_regen", false, 100, "")
	h.inventory.backpack.append(ring)
	var blade := _Artifact.new(&"blade_of_light", &"Blade of Light", _Artifact.Slot.WEAPON,
		_Artifact.Rarity.MAJOR, {}, &"", false, 250, "")
	h.inventory.equipped[_Artifact.Slot.WEAPON] = blade
	h.strategic_resources.add(&"wood", 100)
	h.strategic_resources.add(&"stone", 50)
	return h

func _make_city(uid: int, name: StringName, is_capital: bool) -> City:
	var c := _City.new()
	c.uid = uid
	c.display_name = name
	c.is_capital = is_capital
	var b := Borough.new()
	b.uid = uid
	c.boroughs.append(b)
	var ub := UniqueBuilding.new()
	ub.def = UniqueBuilding.Def.new()
	ub.def.id = &"great_temple"
	ub.level = 2
	c.buildings.append(ub)
	c.food_stockpile = 80.0
	c.storage = {"industry": 600.0, "gold": 150.0}
	return c

func test_select_returns_same_path_follower() -> void:
	var h := _succession_hero(&"archivist")
	var f1 := _make_follower(2, &"archivist")
	var f2 := _make_follower(1, &"archivist")
	var outsider := _make_follower(3, &"warrior")
	h.followers = [f1, f2, outsider]

	var succ := _Succession.new().select_successor(h)
	assert_that(succ).is_not_null()
	assert_that(succ.path).is_equal(&"archivist")
	assert_int(succ.uid).is_equal(1)
	h.free()

func test_select_never_different_path() -> void:
	var h := _succession_hero(&"archivist")
	var same := _make_follower(1, &"archivist")
	var other := _make_follower(2, &"warrior")
	h.followers = [same, other]

	var succ := _Succession.new().select_successor(h)
	assert_that(succ).is_not_null()
	assert_that(succ.path).is_equal(&"archivist")
	h.free()

func test_select_null_when_no_eligible() -> void:
	var h := _succession_hero(&"archivist")
	var other := _make_follower(3, &"warrior")
	h.followers = [other]

	var succ := _Succession.new().select_successor(h)
	assert_that(succ).is_null()
	h.free()

func test_select_null_when_no_followers() -> void:
	var h := _succession_hero(&"archivist")
	h.followers = []
	var succ := _Succession.new().select_successor(h)
	assert_that(succ).is_null()
	h.free()

func test_build_copies_path_magic_inventory() -> void:
	var h := _succession_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)
	assert_that(succ).is_not_null()
	assert_that(succ.path_id).is_equal(&"archivist")
	assert_that(succ.magic.spellbook).is_equal([&"firebolt", &"heal"])
	assert_that(succ.magic.schools).is_equal({&"air": 1, &"fire": 2})
	assert_that(succ.magic.mana_current).is_equal(10)
	assert_bool(succ.inventory.backpack.size() == 1).is_true()
	assert_bool(succ.inventory.backpack[0] != h.inventory.backpack[0]).is_true()
	assert_bool(succ.inventory.equipped[_Artifact.Slot.WEAPON] != h.inventory.equipped[_Artifact.Slot.WEAPON]).is_true()
	assert_that(succ.strategic_resources.get_all()).is_equal(h.strategic_resources.get_all())
	h.free(); succ.free()

func test_transfer_preserves_cities_identical() -> void:
	var src := _make_city(1, &"Riverport", false)
	var cap := _make_city(2, &"Highhold", true)
	var other := _make_city(3, &"Gravewater", false)
	var cities: Array[City] = [src, cap, other]

	var h := _succession_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)

	var mgr := _CityManager.new()
	mgr.set_capital(cap)
	mgr.current_turn = 12
	mgr.add_glory(40.0, &"victory")
	for city in cities:
		mgr.register_city(city)

	_Succession.new().transfer_legend(h, succ, cities, mgr)

	assert_that(mgr.cities.size()).is_equal(3)
	var cap_after: City = mgr.get("capital")
	assert_that(cap_after).is_not_null()
	assert_that(cap_after.is_capital).is_equal(true)
	assert_that(mgr.current_turn).is_equal(12)

	var total_storage := 0.0
	for city in mgr.cities:
		total_storage += float(city.storage.get("industry", 0.0))
	assert_float(total_storage).is_equal_approx(1800.0, 0.01)
	h.free(); succ.free(); mgr.free()

func test_transfer_reregisters_fresh_manager() -> void:
	var cap := _make_city(2, &"Highhold", true)
	var cities: Array[City] = [cap]
	var h := _succession_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)

	var dest := _CityManager.new()
	_Succession.new().transfer_legend(h, succ, cities, dest)

	assert_that(dest.cities.size()).is_equal(1)
	var re_cap: City = dest.get("capital")
	assert_that(re_cap).is_not_null()
	assert_bool(re_cap != cap).is_true()
	h.free(); succ.free(); dest.free()

func test_resurrect_requires_temple_and_resources() -> void:
	var no_temple := _make_city(1, &"Village", false)
	no_temple.buildings = []
	no_temple.storage = {"industry": 999.0, "gold": 999.0}
	assert_bool(_Succession.new().resurrect_hero(no_temple)).is_false()

	var temple := _make_city(2, &"TempleTown", true)
	assert_bool(_Succession.new().resurrect_hero(temple)).is_true()
	assert_float(temple.storage.get("industry", 0.0)).is_equal_approx(100.0, 0.01)
	assert_float(temple.storage.get("gold", 0.0)).is_equal_approx(50.0, 0.01)

	var poor := _make_city(3, &"PoorTown", true)
	poor.storage = {"industry": 100.0, "gold": 10.0}
	assert_bool(_Succession.new().resurrect_hero(poor)).is_false()

func test_on_hero_died_returns_successor() -> void:
	var h := _succession_hero(&"archivist")
	var f := _make_follower(1, &"archivist")
	h.followers = [f]

	var cap := _make_city(2, &"Highhold", true)
	var cities: Array[City] = [cap]
	var mgr := _CityManager.new()
	mgr.register_city(cap)

	var controller := _Succession.new()
	var succ := controller.on_hero_died(h, null, cities, mgr)
	assert_that(succ).is_not_null()
	assert_that(succ.path_id).is_equal(&"archivist")
	assert_that(mgr.cities.size()).is_equal(1)
	h.free(); succ.free(); mgr.free()

func test_on_hero_died_null_when_no_follower() -> void:
	var h := _succession_hero(&"archivist")
	h.followers = []
	var empty_cities: Array[City] = []
	var controller := _Succession.new()
	var succ := controller.on_hero_died(h, null, empty_cities, null)
	assert_that(succ).is_null()
	h.free()

func test_save_roundtrip_v4() -> void:
	var d := _SaveData.new()
	d.run_seed = 12345
	d.hero = {"cell": {"x": 3, "y": 4}, "path_id": "archivist"}
	d.successor = {"path": "archivist", "name": "Lyra"}
	d.legend = {"path_id": "archivist", "level": 3, "glory": 120.0}

	var data := d.to_dict()
	assert_that(data["version"]).is_equal(_SaveData.CURRENT_VERSION)

	var d2 := _SaveData.new()
	d2.from_dict(data)
	assert_that(d2.version).is_equal(_SaveData.CURRENT_VERSION)
	assert_that(d2.hero.get("path_id")).is_equal("archivist")
	assert_that(d2.successor.get("path")).is_equal("archivist")
	assert_that(d2.legend.get("level")).is_equal(3)

func test_migrate_v3_to_v4_defaults() -> void:
	var v3 := {"version": 3, "run_seed": 99,
		"hero": {"cell": {"x": 1, "y": 1}, "path_id": "archivist"},
		"world": {}, "cities": [], "characters": []}
	var d := _SaveData.new()
	d.from_dict(v3)
	assert_that(d.version).is_equal(_SaveData.CURRENT_VERSION)
	assert_bool(d.successor is Dictionary).is_true()
	assert_bool(d.legend is Dictionary).is_true()
	assert_that(d.run_seed).is_equal(99)
