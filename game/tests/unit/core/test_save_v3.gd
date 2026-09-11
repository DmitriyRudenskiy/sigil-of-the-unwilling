extends BaseTest
const TestFactories := preload("res://tests/helpers/factories.gd")

func test_version_is_current() -> void:
	assert_bool(SaveData.CURRENT_VERSION >= 6).is_true()

func test_v2_migration_adds_empty_cities() -> void:
	var v2 := {
		"version": 2,
		"run_seed": 42,
		"date": {"month": 3, "week": 2, "day": 5},
		"hero": {"cell": {"x": 1, "y": 2}, "time_mp_spent": 3.0},
		"world": {"captured_villages": []},
	}
	var sd := SaveData.new()
	sd.from_dict(v2)
	assert_that(sd.version).is_equal(SaveData.CURRENT_VERSION)
	assert_bool(sd.cities is Array).is_true()
	assert_that((sd.cities as Array).size()).is_equal(0)
	assert_that((sd.characters as Array).size()).is_equal(0)
	assert_bool(sd.is_valid()).is_true()
	assert_that(sd.run_seed).is_equal(42)

func test_v3_roundtrip_json() -> void:
	var sd := SaveData.new()
	sd.run_seed = 7
	sd.date = {"month": 1, "week": 1, "day": 1}
	sd.hero = {"cell": {"x": 0, "y": 0}}
	var city := TestFactories.make_city(0)
	city.add_followers(3)
	var chars: Array = []
	var ch := Character.new()
	ch.uid = 1
	ch.name = "Торм"
	ch.pop_uid = 0
	chars.append(ch.serialize())
	sd.cities = [city.serialize()]
	sd.characters = chars

	var json_str := JSON.stringify(sd.to_dict())
	var parsed: Variant = JSON.parse_string(json_str)
	assert_bool(parsed is Dictionary).is_true()

	var sd2 := SaveData.new()
	sd2.from_dict(parsed)
	assert_that(sd2.version).is_equal(SaveData.CURRENT_VERSION)
	assert_that(sd2.run_seed).is_equal(7)
	assert_that(sd2.cities.size()).is_equal(1)
	assert_that(sd2.characters.size()).is_equal(1)
	var cd: Dictionary = sd2.cities[0]
	assert_that(int(cd.get("uid", -1))).is_equal(0)
	assert_that((cd.get("pop", []) as Array).size()).is_equal(3)

func test_from_dict_garbage_collections() -> void:
	var sd := SaveData.new()
	sd.from_dict({"version": 3, "cities": "oops", "characters": 5, "hero": {"cell": {"x": 0, "y": 0}}, "run_seed": 1})
	assert_that(sd.cities.size()).is_equal(0)
	assert_that(sd.characters.size()).is_equal(0)

func test_popunit_roundtrip() -> void:
	var u := PopUnit.new()
	u.uid = 7
	u.state = PopUnit.State.WORKER
	u.tile = Vector2i(3, 4)
	u.patrol = false
	u.pending_state = -1
	u.assigned_to = 12
	u.born_turn = 9
	u.character_uid = 33
	var d := u.serialize()
	var u2: PopUnit = PopUnit.deserialize(d)
	assert_that(u2.uid).is_equal(7)
	assert_that(u2.state).is_equal(PopUnit.State.WORKER)
	assert_that(u2.tile).is_equal(Vector2i(3, 4))
	assert_that(u2.assigned_to).is_equal(12)
	assert_that(u2.born_turn).is_equal(9)
	assert_that(u2.character_uid).is_equal(33)

func test_popunit_pending_roundtrip() -> void:
	var u := PopUnit.new()
	u.uid = 1
	u.state = PopUnit.State.FOLLOWER
	u.request_switch(PopUnit.State.MILITIA)
	var d := u.serialize()
	assert_that(int(d.get("pending_state", -1))).is_equal(PopUnit.State.MILITIA)
	var u2: PopUnit = PopUnit.deserialize(d)
	assert_that(u2.pending_state).is_equal(PopUnit.State.MILITIA)
	assert_that(u2.state).is_equal(PopUnit.State.FOLLOWER)
	u2.apply_pending()
	assert_that(u2.state).is_equal(PopUnit.State.MILITIA)

func test_popunit_defaults() -> void:
	var u2: PopUnit = PopUnit.deserialize({})
	assert_that(u2.uid).is_equal(0)
	assert_that(u2.state).is_equal(PopUnit.State.FOLLOWER)
	assert_that(u2.tile).is_equal(Vector2i(-1, -1))
	assert_that(u2.character_uid).is_equal(-1)

func test_building_defs_by_id() -> void:
	assert_that(BuildingDefs.def_by_id(&"great_temple")).is_not_null()
	assert_that(BuildingDefs.def_by_id(&"market")).is_not_null()
	assert_that(BuildingDefs.def_by_id(&"barracks")).is_not_null()
	assert_that(BuildingDefs.def_by_id(&"ancient_vault")).is_not_null()
	assert_that(BuildingDefs.def_by_id(&"nope")).is_null()

func test_building_roundtrip() -> void:
	var b := UniqueBuilding.new()
	b.def = BuildingDefs.market()
	b.cell = Vector2i(8, 9)
	b.level = 2
	b.uid = 4
	b.assigned_followers = 3
	b.zone_type = 1
	b.zone_multiplier = 1.1
	b.upkeep[&"food"] = 2.0
	var chain := ProductionChain.new()
	chain.id = &"test_chain"
	chain.inputs[&"wood"] = 2.0
	chain.outputs[&"planks"] = 1.5
	chain.required_workers = 3
	b.production_chain = chain

	var d := b.serialize()
	var b2: UniqueBuilding = UniqueBuilding.deserialize(d, BuildingDefs.def_by_id(&"market"))
	assert_that(b2.def).is_not_null()
	assert_that(b2.def.id).is_equal(&"market")
	assert_that(b2.cell).is_equal(Vector2i(8, 9))
	assert_that(b2.level).is_equal(2)
	assert_that(b2.uid).is_equal(4)
	assert_that(b2.assigned_followers).is_equal(3)
	assert_that(b2.zone_type).is_equal(1)
	assert_bool(absf(b2.zone_multiplier - 1.1) < 1e-9).is_true()
	assert_bool(absf(float(b2.upkeep.get(&"food", 0.0)) - 2.0) < 1e-9).is_true()
	assert_that(b2.production_chain).is_not_null()
	assert_that(b2.production_chain.id).is_equal(&"test_chain")
	assert_that(b2.production_chain.required_workers).is_equal(3)
	assert_bool(absf(float(b2.production_chain.inputs.get(&"wood", 0.0)) - 2.0) < 1e-9).is_true()

func test_building_roundtrip_no_chain() -> void:
	var b := UniqueBuilding.new()
	b.def = BuildingDefs.barracks()
	b.cell = Vector2i(1, 1)
	b.level = 1
	b.uid = 2
	var b2: UniqueBuilding = UniqueBuilding.deserialize(b.serialize(), BuildingDefs.def_by_id(&"barracks"))
	assert_that(b2.production_chain).is_null()
	assert_bool(b2.upkeep.is_empty()).is_true()

func _rich_city() -> City:
	var city := TestFactories.make_city(0)
	city.is_capital = true
	city.stronghold_level = 2
	city.faction = City.Faction.NECROPHAGE
	city.food_stockpile = 123.5
	city.starving = true
	city.scale_tier = 1
	city.auto_resource_mult = 1.1
	city.upkeep_mult = 0.9
	city.storage[&"industry"] = 55.0
	city.storage[&"gold"] = 10.0
	city.special_sites[Vector2i(6, 5)] = &"shrine"
	city.add_road(Vector2i(5, 4))
	city.add_road(Vector2i(4, 5))
	city.ensure_resource_ctx()
	city.resource_ctx.add(&"wood", 42.0)
	city.resource_ctx.add(&"stone", 7.0)
	city.add_followers(4)
	city.pop[0].state = PopUnit.State.WORKER
	city.pop[0].tile = Vector2i(5, 4)
	city.pop[1].state = PopUnit.State.MILITIA
	city.pop[1].patrol = true
	city.pop[2].assigned_to = 10
	city.pop[0].character_uid = 100
	city.pop[1].character_uid = 101
	var bh := Borough.new()
	bh.cell = Vector2i(6, 5)
	bh.level = 2
	bh.uid = city._uid_seq
	city._uid_seq += 1
	city.boroughs.append(bh)
	var market := UniqueBuilding.new()
	market.def = BuildingDefs.market()
	market.cell = Vector2i(5, 3)
	market.level = 2
	market.uid = city._uid_seq
	city._uid_seq += 1
	market.zone_type = 1
	market.zone_multiplier = 1.15
	var chain := ProductionChain.new()
	chain.id = &"sawmill"
	chain.inputs[&"wood"] = 3.0
	chain.outputs[&"planks"] = 2.0
	chain.required_workers = 2
	market.production_chain = chain
	city.pop[2].assigned_to = market.uid
	city.buildings.append(market)
	var temple := UniqueBuilding.new()
	temple.def = BuildingDefs.great_temple()
	temple.cell = Vector2i(6, 5)
	temple.level = 1
	temple.uid = city._uid_seq
	city._uid_seq += 1
	city.buildings.append(temple)
	return city

func test_city_roundtrip_full() -> void:
	var city := _rich_city()
	var d := city.serialize()

	var city2 := City.new()
	city2.deserialize(d)

	assert_that(city2.uid).is_equal(0)
	assert_that(city2.center).is_equal(Vector2i(5, 5))
	assert_that(city2.stronghold_level).is_equal(2)
	assert_that(city2.faction).is_equal(City.Faction.NECROPHAGE)
	assert_bool(city2.is_capital).is_true()
	assert_bool(absf(city2.food_stockpile - 123.5) < 1e-9).is_true()
	assert_bool(city2.starving).is_true()
	assert_that(city2.scale_tier).is_equal(1)
	assert_bool(absf(city2.auto_resource_mult - 1.1) < 1e-9).is_true()
	assert_bool(absf(city2.upkeep_mult - 0.9) < 1e-9).is_true()
	assert_bool(absf(float(city2.storage.get(&"industry", 0.0)) - 55.0) < 1e-9).is_true()
	assert_bool(absf(float(city2.storage.get(&"gold", 0.0)) - 10.0) < 1e-9).is_true()
	assert_that(city2.special_sites.get(Vector2i(6, 5), &"")).is_equal(&"shrine")
	assert_bool(city2.has_road(Vector2i(5, 4))).is_true()
	assert_bool(city2.has_road(Vector2i(4, 5))).is_true()
	assert_bool(city2.has_road(Vector2i(9, 9))).is_false()
	assert_that(city2.resource_ctx).is_not_null()
	assert_bool(absf(city2.resource_ctx.amount(&"wood") - 42.0) < 1e-9).is_true()
	assert_bool(absf(city2.resource_ctx.amount(&"stone") - 7.0) < 1e-9).is_true()
	assert_that(city2.pop.size()).is_equal(4)
	assert_that(city2.pop[0].state).is_equal(PopUnit.State.WORKER)
	assert_that(city2.pop[0].tile).is_equal(Vector2i(5, 4))
	assert_that(city2.pop[1].state).is_equal(PopUnit.State.MILITIA)
	assert_bool(city2.pop[1].patrol).is_true()
	assert_that(city2.pop[2].assigned_to).is_equal(int(city2.buildings[0].uid))
	assert_that(city2.pop[0].character_uid).is_equal(100)
	assert_that(city2.pop[1].character_uid).is_equal(101)
	assert_that(city2.boroughs.size()).is_equal(1)
	assert_that(city2.boroughs[0].cell).is_equal(Vector2i(6, 5))
	assert_that(city2.boroughs[0].level).is_equal(2)
	assert_that(city2.buildings.size()).is_equal(2)
	assert_that(city2.buildings[0].def.id).is_equal(&"market")
	assert_that(city2.buildings[0].level).is_equal(2)
	assert_that(city2.buildings[0].production_chain).is_not_null()
	assert_that(city2.buildings[0].production_chain.id).is_equal(&"sawmill")
	assert_that(city2.buildings[1].def.id).is_equal(&"great_temple")
	assert_bool(absf(city2.buildings[0].zone_multiplier - 1.15) < 1e-9).is_true()
	assert_that(city2.get_great_temple_level()).is_equal(1)

func test_city_uid_seq_continuity() -> void:
	var city := _rich_city()
	var d := city.serialize()
	var city2 := City.new()
	city2.deserialize(d)
	var max_restored := -1
	for u in city2.pop:
		max_restored = maxi(max_restored, u.uid)
	for building in city2.buildings:
		max_restored = maxi(max_restored, building.uid)
	city2.add_followers(2)
	var fresh := city2.pop[city2.pop.size() - 1]
	assert_bool(fresh.uid > max_restored).is_true()

func test_city_json_safe() -> void:
	var city := _rich_city()
	var s := JSON.stringify(city.serialize())
	assert_bool(s.length() > 0).is_true()
	var parsed: Variant = JSON.parse_string(s)
	assert_bool(parsed is Dictionary).is_true()

func test_city_unknown_building_skipped() -> void:
	var city := _rich_city()
	var d := city.serialize()
	(d["buildings"] as Array)[1] = {"def_id": "mystery_tower", "cell": {"x": 9, "y": 9}, "level": 1, "uid": 77}
	var city2 := City.new()
	city2.deserialize(d)
	assert_that(city2.buildings.size()).is_equal(1)
	assert_that(city2.buildings[0].def.id).is_equal(&"market")
	var fresh := city2._add_pop(PopUnit.State.FOLLOWER, 1)
	assert_bool(fresh.uid != 77).is_true()

func test_city_empty_deserialize() -> void:
	var city := City.new()
	city.deserialize({})
	assert_that(city.center).is_equal(Vector2i(-1, -1))
	assert_that(city.pop.size()).is_equal(0)
	assert_that(city.buildings.size()).is_equal(0)
	assert_bool(city.storage.is_empty()).is_true()

func test_registry_roundtrip() -> void:
	var reg := CharacterRegistry.new()
	var city := TestFactories.make_city(0)
	city.add_followers(3)
	var rng := TestFactories.seeded(9222)
	rng.seed = 1234
	var ch0: Character = reg.create(0, city.pop[0], rng)
	var ch1: Character = reg.create(0, city.pop[1], rng)
	ch0.name = "Торм"
	var dead := Character.new()
	dead.uid = reg._uid_seq
	reg._uid_seq += 1
	dead.name = "Ульда"
	dead.alive = false
	dead.city_uid = 0
	dead.pop_uid = 99
	reg._characters[dead.uid] = dead

	var data: Array = reg.serialize()
	assert_that(data.size()).is_equal(3)

	var reg2 := CharacterRegistry.new()
	reg2.deserialize(data)
	var c0: Character = reg2.get_by_uid(ch0.uid)
	assert_that(c0).is_not_null()
	assert_that(c0.name).is_equal("Торм")
	assert_bool(c0.alive).is_true()
	assert_that(c0.pop_uid).is_equal(city.pop[0].uid)
	assert_that(reg2.get_by_pop(city.pop[0].uid)).is_not_null()
	var c1: Character = reg2.get_by_uid(ch1.uid)
	assert_that(c1).is_not_null()
	assert_that(reg2.get_by_pop(city.pop[1].uid)).is_not_null()
	var d: Character = reg2.get_by_uid(dead.uid)
	assert_that(d).is_not_null()
	assert_bool(d.alive).is_false()
	assert_that(reg2.get_by_pop(99)).is_null()
	var t_count := 0
	for t in c0.traits:
		t_count += 1
	assert_that(t_count).is_equal(ch0.traits.size())
	var pop3 := PopUnit.new()
	pop3.uid = 555
	var ch2: Character = reg2.create(0, pop3, rng)
	assert_bool(ch2.uid > dead.uid).is_true()

func test_find_city_by_uid() -> void:
	var p := WorldPersistence.new(null)
	var a := TestFactories.make_city(0)
	var b := TestFactories.make_city(1)
	var all: Array = [a, b]
	assert_that(p._find_city(all, 1, 2, null)).is_equal(b)
	assert_that(p._find_city(all, 5, 2, null)).is_null()
	var only: Array = [a]
	assert_that(p._find_city(only, 99, 1, null)).is_equal(a)
	assert_that(p._find_city(only, 99, 2, null)).is_null()

func test_find_city_empty() -> void:
	var p := WorldPersistence.new(null)
	assert_that(p._find_city([], 0, 1, null)).is_null()
