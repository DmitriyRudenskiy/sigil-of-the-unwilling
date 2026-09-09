extends GdUnitTestSuite

const _City = preload("res://scripts/world/City.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _FollowerSystem = preload("res://scripts/entities/FollowerSystem.gd")

func _make_city(followers: int, workers: int = 0) -> RefCounted:
	var c := _City.new()
	c.display_name = "Город"
	c.center = Vector2i(10, 10)
	for i in workers:
		c.add_migrant(PopUnit.State.WORKER, -1)
	for i in followers:
		c.add_migrant(PopUnit.State.FOLLOWER, -1)
	return c

func test_roundtrip_all_fields() -> void:
	var f := _Follower.new()
	f.uid = 3
	f.name = "Марк"
	f.race = &"elf"
	f.path = &"wizard"
	f.archetype = &"arcane_tradition"
	f.trait_ids.append(&"brave")
	f.trait_ids.append(&"curious")
	f.stat_modifiers[&"INT"] = 3
	f.abilities.append(&"fireball")
	var f2 := _Follower.new()
	f2.deserialize(f.serialize())
	assert_that(f2.uid).is_equal(3)
	assert_that(f2.name).is_equal("Марк")
	assert_that(f2.race).is_equal(&"elf")
	assert_that(f2.path).is_equal(&"wizard")
	assert_that(f2.archetype).is_equal(&"arcane_tradition")
	assert_that(f2.trait_ids).is_equal([&"brave", &"curious"])
	assert_that(int(f2.stat_modifiers.get(&"INT", 0))).is_equal(3)
	assert_that(f2.abilities).is_equal([&"fireball"])

func test_roundtrip_defaults() -> void:
	var f := _Follower.new()
	var f2 := _Follower.new()
	f2.deserialize(f.serialize())
	assert_that(f2.race).is_equal(f.race)
	assert_bool((f2.trait_ids as Array).is_empty()).is_true()
	assert_bool((f2.abilities as Array).is_empty()).is_true()

func test_to_dict_json_compatible() -> void:
	var f := _Follower.new()
	f.name = "Вера"
	f.race = &"dwarf"
	f.path = &"cleric"
	f.trait_ids.append(&"honest")
	f.stat_modifiers[&"CON"] = 2
	var d: Dictionary = f.to_dict()
	assert_that(d.get("name")).is_equal("Вера")
	assert_that(d.get("race")).is_equal("dwarf")
	assert_that(d.get("path")).is_equal("cleric")
	assert_bool(d.get("traits") is Array).is_true()
	assert_that(String((d.get("traits") as Array)[0])).is_equal("honest")
	var json := JSON.stringify(d)
	assert_str(json).is_not_empty()
	var back: Variant = JSON.parse_string(json)
	assert_bool(back is Dictionary).is_true()

func test_recruit_moves_follower_from_city_to_hero() -> void:
	var city := _make_city(2)
	var hero := HeroController.new()
	var before: int = city.pop.size()
	var f := _FollowerSystem.recruit(city, hero, TestFactories.seeded(42))
	assert_that(f).is_not_null()
	assert_that(city.pop.size()).is_equal(before - 1)
	assert_that(hero.followers.size()).is_equal(1)
	assert_bool(hero.followers[0] == f).is_true()
	assert_str(f.name).is_not_empty()
	hero.free()

func test_recruit_null_without_free_followers() -> void:
	var city := _make_city(0, 3)
	var hero := HeroController.new()
	assert_that(_FollowerSystem.recruit(city, hero, TestFactories.seeded(1))).is_null()
	assert_that(hero.followers.size()).is_equal(0)
	hero.free()

func test_recruit_deterministic_with_same_seed() -> void:
	var c1 := _make_city(1)
	var c2 := _make_city(1)
	var h1 := HeroController.new()
	var h2 := HeroController.new()
	var f1 := _FollowerSystem.recruit(c1, h1, TestFactories.seeded(7))
	var f2 := _FollowerSystem.recruit(c2, h2, TestFactories.seeded(7))
	assert_that(f1.name).is_equal(f2.name)
	assert_that(f1.race).is_equal(f2.race)
	assert_that(f1.path).is_equal(f2.path)
	assert_that(f1.trait_ids).is_equal(f2.trait_ids)
	h1.free()
	h2.free()

func test_recruit_uid_increments() -> void:
	var city := _make_city(3)
	var hero := HeroController.new()
	var f1 := _FollowerSystem.recruit(city, hero, TestFactories.seeded(1))
	var f2 := _FollowerSystem.recruit(city, hero, TestFactories.seeded(2))
	assert_that(f1.uid).is_equal(1)
	assert_that(f2.uid).is_equal(2)
	hero.free()
