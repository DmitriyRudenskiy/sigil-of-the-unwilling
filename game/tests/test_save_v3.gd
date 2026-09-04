extends "res://tests/gut_base.gd"
## Save v3 (Каскад Сложности): города и персонажи в сохранении.
## Сериализация City/PopUnit/UniqueBuilding/BuildingDefs, миграция v2->v3,
## JSON-совместимость, WorldPersistence._find_city.


func _make_city(uid: int = 0) -> City:
	var city := City.new()
	city.uid = uid
	city.display_name = "TestTown %d" % uid
	city.center = Vector2i(5, 5)
	return city


# ==================== SaveData v3 ====================

func test_version_is_current() -> void:
	# v6: legend-chronicle добавил chronicle (см. SaveData). Версия растёт,
	# пикируем минимум — точный пин ломается на каждом bump.
	assert_true(SaveData.CURRENT_VERSION >= 6, "CURRENT_VERSION >= 6 (v6 = chronicle)")


func test_v2_migration_adds_empty_cities() -> void:
	## v2-сейв (без cities/characters) -> пустые списки, версия 3, валиден.
	var v2 := {
		"version": 2,
		"run_seed": 42,
		"date": {"month": 3, "week": 2, "day": 5},
		"hero": {"cell": {"x": 1, "y": 2}, "time_mp_spent": 3.0},
		"world": {"captured_villages": []},
	}
	var sd := SaveData.new()
	sd.from_dict(v2)
	assert_eq(sd.version, SaveData.CURRENT_VERSION, "migrated to current version")
	assert_true(sd.cities is Array, "cities is Array")
	assert_eq((sd.cities as Array).size(), 0, "cities empty")
	assert_eq((sd.characters as Array).size(), 0, "characters empty")
	assert_true(sd.is_valid(), "v2 save still valid")
	assert_eq(sd.run_seed, 42, "seed preserved")


func test_v3_roundtrip_json() -> void:
	## to_dict -> JSON.stringify/parse -> from_dict: JSON-совместимость.
	var sd := SaveData.new()
	sd.run_seed = 7
	sd.date = {"month": 1, "week": 1, "day": 1}
	sd.hero = {"cell": {"x": 0, "y": 0}}
	var city := _make_city(0)
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
	assert_true(parsed is Dictionary, "json parses")

	var sd2 := SaveData.new()
	sd2.from_dict(parsed)
	assert_eq(sd2.version, SaveData.CURRENT_VERSION, "version")
	assert_eq(sd2.run_seed, 7, "seed")
	assert_eq(sd2.cities.size(), 1, "one city")
	assert_eq(sd2.characters.size(), 1, "one character")
	var cd: Dictionary = sd2.cities[0]
	assert_eq(int(cd.get("uid", -1)), 0, "city uid")
	assert_eq((cd.get("pop", []) as Array).size(), 3, "city pop preserved")


func test_from_dict_garbage_collections() -> void:
	var sd := SaveData.new()
	sd.from_dict({"version": 3, "cities": "oops", "characters": 5, "hero": {"cell": {"x": 0, "y": 0}}, "run_seed": 1})
	assert_eq(sd.cities.size(), 0, "non-array cities -> []")
	assert_eq(sd.characters.size(), 0, "non-array characters -> []")


# ==================== PopUnit ====================

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
	assert_eq(u2.uid, 7, "uid")
	assert_eq(u2.state, PopUnit.State.WORKER, "state")
	assert_eq(u2.tile, Vector2i(3, 4), "tile")
	assert_eq(u2.assigned_to, 12, "assigned_to")
	assert_eq(u2.born_turn, 9, "born_turn")
	assert_eq(u2.character_uid, 33, "character_uid")


func test_popunit_pending_roundtrip() -> void:
	var u := PopUnit.new()
	u.uid = 1
	u.state = PopUnit.State.FOLLOWER
	u.request_switch(PopUnit.State.MILITIA)
	var d := u.serialize()
	assert_eq(int(d.get("pending_state", -1)), PopUnit.State.MILITIA, "pending serialized")
	var u2: PopUnit = PopUnit.deserialize(d)
	assert_eq(u2.pending_state, PopUnit.State.MILITIA, "pending restored")
	assert_eq(u2.state, PopUnit.State.FOLLOWER, "current state unchanged")
	u2.apply_pending()
	assert_eq(u2.state, PopUnit.State.MILITIA, "pending applies after load")


func test_popunit_defaults() -> void:
	var u2: PopUnit = PopUnit.deserialize({})
	assert_eq(u2.uid, 0, "uid default")
	assert_eq(u2.state, PopUnit.State.FOLLOWER, "state default")
	assert_eq(u2.tile, Vector2i(-1, -1), "tile default")
	assert_eq(u2.character_uid, -1, "char default")


# ==================== BuildingDefs / UniqueBuilding ====================

func test_building_defs_by_id() -> void:
	assert_not_null(BuildingDefs.def_by_id(&"great_temple"), "temple")
	assert_not_null(BuildingDefs.def_by_id(&"market"), "market")
	assert_not_null(BuildingDefs.def_by_id(&"barracks"), "barracks")
	assert_not_null(BuildingDefs.def_by_id(&"ancient_vault"), "vault")
	assert_null(BuildingDefs.def_by_id(&"nope"), "unknown -> null")


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
	assert_not_null(b2.def, "def relinked")
	assert_eq(b2.def.id, &"market", "def id")
	assert_eq(b2.cell, Vector2i(8, 9), "cell")
	assert_eq(b2.level, 2, "level")
	assert_eq(b2.uid, 4, "uid")
	assert_eq(b2.assigned_followers, 3, "followers")
	assert_eq(b2.zone_type, 1, "zone_type")
	assert_true(absf(b2.zone_multiplier - 1.1) < 1e-9, "zone_multiplier")
	assert_true(absf(float(b2.upkeep.get(&"food", 0.0)) - 2.0) < 1e-9, "upkeep")
	assert_not_null(b2.production_chain, "chain")
	assert_eq(b2.production_chain.id, &"test_chain", "chain id")
	assert_eq(b2.production_chain.required_workers, 3, "chain workers")
	assert_true(absf(float(b2.production_chain.inputs.get(&"wood", 0.0)) - 2.0) < 1e-9, "chain input")


func test_building_roundtrip_no_chain() -> void:
	var b := UniqueBuilding.new()
	b.def = BuildingDefs.barracks()
	b.cell = Vector2i(1, 1)
	b.level = 1
	b.uid = 2
	var b2: UniqueBuilding = UniqueBuilding.deserialize(b.serialize(), BuildingDefs.def_by_id(&"barracks"))
	assert_null(b2.production_chain, "no chain")
	assert_true(b2.upkeep.is_empty(), "no upkeep")


# ==================== City ====================

func _rich_city() -> City:
	var city := _make_city(0)
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
	# Население: рабочие + последователи + ополченцы.
	city.add_followers(4)
	city.pop[0].state = PopUnit.State.WORKER
	city.pop[0].tile = Vector2i(5, 4)
	city.pop[1].state = PopUnit.State.MILITIA
	city.pop[1].patrol = true
	city.pop[2].assigned_to = 10
	city.pop[0].character_uid = 100
	city.pop[1].character_uid = 101
	# Район.
	var bh := Borough.new()
	bh.cell = Vector2i(6, 5)
	bh.level = 2
	bh.uid = city._uid_seq
	city._uid_seq += 1
	city.boroughs.append(bh)
	# Здания: рынок (с цепочкой) + храм на площадке.
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

	assert_eq(city2.uid, 0, "uid (не перезаписывается)")
	assert_eq(city2.center, Vector2i(5, 5), "center")
	assert_eq(city2.stronghold_level, 2, "stronghold")
	assert_eq(city2.faction, City.Faction.NECROPHAGE, "faction")
	assert_true(city2.is_capital, "capital")
	assert_true(absf(city2.food_stockpile - 123.5) < 1e-9, "food")
	assert_true(city2.starving, "starving")
	assert_eq(city2.scale_tier, 1, "scale_tier")
	assert_true(absf(city2.auto_resource_mult - 1.1) < 1e-9, "auto mult")
	assert_true(absf(city2.upkeep_mult - 0.9) < 1e-9, "upkeep mult")
	assert_true(absf(float(city2.storage.get(&"industry", 0.0)) - 55.0) < 1e-9, "storage industry")
	assert_true(absf(float(city2.storage.get(&"gold", 0.0)) - 10.0) < 1e-9, "storage gold")
	assert_eq(city2.special_sites.get(Vector2i(6, 5), &""), &"shrine", "special site")
	assert_true(city2.has_road(Vector2i(5, 4)), "road 1")
	assert_true(city2.has_road(Vector2i(4, 5)), "road 2")
	assert_false(city2.has_road(Vector2i(9, 9)), "no extra road")
	assert_not_null(city2.resource_ctx, "resource_ctx")
	assert_true(absf(city2.resource_ctx.amount(&"wood") - 42.0) < 1e-9, "wood")
	assert_true(absf(city2.resource_ctx.amount(&"stone") - 7.0) < 1e-9, "stone")
	assert_eq(city2.pop.size(), 4, "pop size")
	assert_eq(city2.pop[0].state, PopUnit.State.WORKER, "worker state")
	assert_eq(city2.pop[0].tile, Vector2i(5, 4), "worker tile")
	assert_eq(city2.pop[1].state, PopUnit.State.MILITIA, "militia state")
	assert_true(city2.pop[1].patrol, "patrol")
	assert_eq(city2.pop[2].assigned_to, int(city2.buildings[0].uid), "assigned to market")
	assert_eq(city2.pop[0].character_uid, 100, "char link 1")
	assert_eq(city2.pop[1].character_uid, 101, "char link 2")
	assert_eq(city2.boroughs.size(), 1, "boroughs")
	assert_eq(city2.boroughs[0].cell, Vector2i(6, 5), "borough cell")
	assert_eq(city2.boroughs[0].level, 2, "borough level")
	assert_eq(city2.buildings.size(), 2, "buildings")
	assert_eq(city2.buildings[0].def.id, &"market", "market def")
	assert_eq(city2.buildings[0].level, 2, "market level")
	assert_not_null(city2.buildings[0].production_chain, "market chain")
	assert_eq(city2.buildings[0].production_chain.id, &"sawmill", "chain id")
	assert_eq(city2.buildings[1].def.id, &"great_temple", "temple def")
	assert_true(absf(city2.buildings[0].zone_multiplier - 1.15) < 1e-9, "zone mult")
	# get_great_temple_level работает после загрузки.
	assert_eq(city2.get_great_temple_level(), 1, "temple level via getter")


func test_city_uid_seq_continuity() -> void:
	## После deserialize новые uid не сталкиваются с восстановленными.
	var city := _rich_city()
	var d := city.serialize()
	var city2 := City.new()
	city2.deserialize(d)
	var max_restored := -1
	for u in city2.pop:
		max_restored = maxi(max_restored, u.uid)
	for b in city2.buildings:
		max_restored = maxi(max_restored, b.uid)
	city2.add_followers(2)
	var fresh := city2.pop[city2.pop.size() - 1]
	assert_true(fresh.uid > max_restored, "new uid above restored (%d > %d)" % [fresh.uid, max_restored])


func test_city_json_safe() -> void:
	## Снимок города JSON-совместим (нет Vector2i/StringName-ключей).
	var city := _rich_city()
	var s := JSON.stringify(city.serialize())
	assert_true(s.length() > 0, "stringified")
	var parsed: Variant = JSON.parse_string(s)
	assert_true(parsed is Dictionary, "parsed")


func test_city_unknown_building_skipped() -> void:
	var city := _rich_city()
	var d := city.serialize()
	(d["buildings"] as Array)[1] = {"def_id": "mystery_tower", "cell": {"x": 9, "y": 9}, "level": 1, "uid": 77}
	var city2 := City.new()
	city2.deserialize(d)
	assert_eq(city2.buildings.size(), 1, "unknown building skipped")
	assert_eq(city2.buildings[0].def.id, &"market", "known kept")
	# uid_seq пересчитан: новый uid не равен пропущенному 77.
	var fresh := city2._add_pop(PopUnit.State.FOLLOWER, 1)
	assert_true(fresh.uid != 77, "no clash with skipped uid (%d)" % fresh.uid)


func test_city_empty_deserialize() -> void:
	var city := City.new()
	city.deserialize({})
	assert_eq(city.center, Vector2i(-1, -1), "center default")
	assert_eq(city.pop.size(), 0, "no pop")
	assert_eq(city.buildings.size(), 0, "no buildings")
	assert_true(city.storage.is_empty(), "no storage")


# ==================== CharacterRegistry ====================

func test_registry_roundtrip() -> void:
	var reg := CharacterRegistry.new()
	var city := _make_city(0)
	city.add_followers(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ch0: Character = reg.create(0, city.pop[0], rng)
	var ch1: Character = reg.create(0, city.pop[1], rng)
	ch0.name = "Торм"
	# Мёртвый персонаж (хроники).
	var dead := Character.new()
	dead.uid = reg._uid_seq
	reg._uid_seq += 1
	dead.name = "Ульда"
	dead.alive = false
	dead.city_uid = 0
	dead.pop_uid = 99
	reg._characters[dead.uid] = dead

	var data: Array = reg.serialize()
	assert_eq(data.size(), 3, "3 serialized")

	var reg2 := CharacterRegistry.new()
	reg2.deserialize(data)
	var c0: Character = reg2.get_by_uid(ch0.uid)
	assert_not_null(c0, "ch0 restored")
	assert_eq(c0.name, "Торм", "name")
	assert_true(c0.alive, "alive")
	assert_eq(c0.pop_uid, city.pop[0].uid, "pop uid")
	assert_not_null(reg2.get_by_pop(city.pop[0].uid), "by_pop link alive")
	var c1: Character = reg2.get_by_uid(ch1.uid)
	assert_not_null(c1, "ch1 restored")
	assert_not_null(reg2.get_by_pop(city.pop[1].uid), "by_pop link 2")
	var d: Character = reg2.get_by_uid(dead.uid)
	assert_not_null(d, "dead restored")
	assert_false(d.alive, "dead flag")
	assert_null(reg2.get_by_pop(99), "dead not linked to pop")
	# Чёрты восстановлены (количество совпадает).
	var t_count := 0
	for t in c0.traits:
		t_count += 1
	assert_eq(t_count, ch0.traits.size(), "traits count")
	# uid_seq продолжается: новый персонаж получит новый uid.
	var pop3 := PopUnit.new()
	pop3.uid = 555
	var ch2: Character = reg2.create(0, pop3, rng)
	assert_true(ch2.uid > dead.uid, "uid_seq continued")


# ==================== WorldPersistence._find_city ====================

func test_find_city_by_uid() -> void:
	var p := WorldPersistence.new(null)
	var a := _make_city(0)
	var b := _make_city(1)
	var all: Array = [a, b]
	assert_eq(p._find_city(all, 1, 2), b, "found by uid")
	assert_null(p._find_city(all, 5, 2), "not found, no fallback")
	# Fallback: единственный город + единственный в сейве.
	var only: Array = [a]
	assert_eq(p._find_city(only, 99, 1), a, "single-city fallback")
	# Fallback не срабатывает при нескольких сохранённых.
	assert_null(p._find_city(only, 99, 2), "no fallback with multiple saved")


func test_find_city_empty() -> void:
	var p := WorldPersistence.new(null)
	assert_null(p._find_city([], 0, 1), "empty list")
