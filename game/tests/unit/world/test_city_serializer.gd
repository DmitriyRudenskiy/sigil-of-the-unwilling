extends BaseTest

var city: City

func before_test() -> void:
	city = City.new()
	city.uid = 7
	city.center = Vector2i(10, 5)
	city.owner = &"player"
	city.storage[&"industry"] = 100.0

func test_roundtrip_basic_fields() -> void:
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)

	assert_that(c2.center).is_equal(Vector2i(10, 5))
	assert_that(String(c2.owner)).is_equal("player")

func test_roundtrip_storage() -> void:
	city.storage[&"industry"] = 42.5
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_float(c2.storage[&"industry"]).is_equal_approx(42.5, 0.0001)

func test_roundtrip_pop() -> void:
	city.add_followers(3)
	city.pop[0].ancestry_id = "humans"
	city.pop[0].archetype_id = "engineers_builders"
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.pop.size()).is_equal(3)
	assert_that(c2.pop[0].ancestry_id).is_equal("humans")
	assert_that(c2.pop[0].archetype_id).is_equal("engineers_builders")

func test_roundtrip_boroughs() -> void:
	var b := Borough.new()
	b.cell = Vector2i(11, 5)
	b.level = 2
	b.uid = 1
	city.boroughs.append(b)
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.boroughs.size()).is_equal(1)
	assert_that(c2.boroughs[0].cell).is_equal(Vector2i(11, 5))
	assert_that(c2.boroughs[0].level).is_equal(2)

func test_roundtrip_buildings() -> void:
	city.storage[&"industry"] = 100.0
	var def := BuildingDefs.market()
	var bld := city.build_building(def, Vector2i(11, 5))
	assert_that(bld).is_not_null()
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.buildings.size()).is_equal(1)
	assert_that(c2.buildings[0].def.id).is_equal(def.id)

func test_roundtrip_campaign_buildings() -> void:
	city.campaign_buildings = [{
		"uid": 12, "id": "watchtower", "roles": ["static_defense"],
		"cell": Vector2i(11, 5), "state": "inactive",
		"defense": {"active": 5, "inactive": 0, "ruined": 0},
	}]
	var serialized := CitySerializer.serialize(city)
	var restored := City.new()
	CitySerializer.deserialize(restored, serialized)
	assert_that(restored.campaign_buildings.size()).is_equal(1)
	assert_that(restored.campaign_buildings[0].id).is_equal("watchtower")
	assert_that(restored.campaign_buildings[0].cell).is_equal(Vector2i(11, 5))
	assert_that(restored.campaign_buildings[0].state).is_equal("inactive")
	assert_that(restored.add_migrant(PopUnit.State.FOLLOWER, 0).uid).is_equal(13)

func test_roundtrip_campaign_group_state_and_food_ledger() -> void:
	city.food_stockpile = 12.5
	city.campaign_group_state = {"engineers_builders": {"satisfaction": 42, "unmet_turns": 2}}
	var saved := CitySerializer.serialize(city)
	assert_bool(saved.has("food_stockpile")).is_false()
	assert_float(float(saved.resource_ctx.food)).is_equal_approx(12.5, 0.0001)
	var restored := City.new()
	CitySerializer.deserialize(restored, saved)
	assert_float(restored.food_stockpile).is_equal_approx(12.5, 0.0001)
	assert_that(restored.campaign_group_state.engineers_builders.satisfaction).is_equal(42)
	assert_that(restored.campaign_group_state.engineers_builders.unmet_turns).is_equal(2)

func test_v4_migration_unifies_food_stock_and_is_idempotent() -> void:
	var old_save := {
		"version": 4, "center": {"x": 10, "y": 5}, "food_stockpile": 20.0,
		"resource_ctx": {"food": 3.0, "wood": 8.0}, "storage": {"industry": 17.0},
		"campaign_buildings": [{"uid": 4, "id": "watchtower", "state": "active"}],
		"pop": [{"uid": 2, "state": PopUnit.State.WORKER,
			"ancestry_id": "gnomes", "archetype_id": "engineers_builders"}],
	}
	var migrated := CitySerializer._migrate_city_data(old_save, 4)
	var repeated := CitySerializer._migrate_city_data(migrated, 4)
	assert_that(repeated).is_equal(migrated)
	assert_bool(migrated.has("food_stockpile")).is_false()
	assert_float(float(migrated.resource_ctx.food)).is_equal_approx(23.0, 0.0001)
	var restored := City.new()
	CitySerializer.deserialize(restored, old_save)
	assert_float(restored.food_stockpile).is_equal_approx(23.0, 0.0001)
	assert_float(float(restored.resource_ctx.amount(&"wood"))).is_equal_approx(8.0, 0.0001)
	assert_float(float(restored.storage[&"industry"])).is_equal_approx(17.0, 0.0001)
	assert_that(restored.pop[0].ancestry_id).is_equal("gnomes")
	assert_that(restored.pop[0].archetype_id).is_equal("engineers_builders")
	assert_that(restored.campaign_group_state).is_empty()

func test_v2_save_migrates_campaign_buildings_without_touching_legacy_data() -> void:
	var old_save := {
		"version": 2, "center": {"x": 10, "y": 5},
		"buildings": [], "storage": {"industry": 18.0},
	}
	var restored := City.new()
	CitySerializer.deserialize(restored, old_save)
	assert_that(restored.campaign_buildings).is_empty()
	assert_float(restored.storage[&"industry"]).is_equal_approx(18.0, 0.0001)
	assert_that(CitySerializer.serialize(restored).campaign_buildings).is_empty()

func test_v3_save_migrates_population_identity_without_touching_legacy_data() -> void:
	var old_save := {
		"version": 3, "center": {"x": 10, "y": 5},
		"storage": {"industry": 18.0},
		"campaign_buildings": [{"uid": 4, "id": "watchtower", "cell": {"x": 11, "y": 5}}],
		"pop": [{"uid": 2, "state": PopUnit.State.FOLLOWER}],
	}
	var migrated := CitySerializer._migrate_city_data(old_save, 3)
	var repeated := CitySerializer._migrate_city_data(migrated, 3)
	assert_that(repeated).is_equal(migrated)
	var restored := City.new()
	CitySerializer.deserialize(restored, old_save)
	assert_that(restored.pop[0].ancestry_id).is_empty()
	assert_that(restored.pop[0].archetype_id).is_empty()
	assert_that(restored.campaign_buildings.size()).is_equal(1)
	assert_float(restored.storage[&"industry"]).is_equal_approx(18.0, 0.0001)
	assert_that(CitySerializer.serialize(restored).version).is_equal(City.SERIALIZATION_VERSION)

func test_json_safe() -> void:
	city.campaign_buildings = [{"uid": 4, "id": "watchtower", "cell": Vector2i(11, 5)}]
	var parsed: Variant = JSON.parse_string(JSON.stringify(CitySerializer.serialize(city)))
	assert_that(parsed is Dictionary).is_true()
	var restored := City.new()
	CitySerializer.deserialize(restored, parsed)
	assert_that(restored.campaign_buildings[0].cell).is_equal(Vector2i(11, 5))

func test_empty_deserialize() -> void:

	var c2 := City.new()
	CitySerializer.deserialize(c2, {})
	assert_that(c2.pop.size()).is_zero()
	assert_that(c2.boroughs.size()).is_zero()
	assert_that(c2.buildings.size()).is_zero()

func test_uid_continuity() -> void:

	city.add_followers(2)
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	var max_uid := 0
	for u in c2.pop:
		max_uid = maxi(max_uid, u.uid)
	var fresh := c2.add_migrant(PopUnit.State.FOLLOWER, 0)
	assert_that(fresh.uid > max_uid).is_true()

func test_migrate_v1_to_v2() -> void:
	var d: Dictionary = {
		"version": 1,
		"uid": 1,
		"center": {"x": 1, "y": 1},
	}
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.scale_tier).is_equal(0)
	assert_float(c2.auto_resource_mult).is_equal_approx(1.0, 0.0001)
