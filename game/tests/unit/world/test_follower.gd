extends BaseTest




func _make_city(followers: int, workers: int = 0) -> RefCounted:
	var c := City.new()
	c.display_name = "Город"
	c.center = Vector2i(10, 10)
	for i in workers:
		c.add_migrant(PopUnit.State.WORKER, -1)
	for i in followers:
		c.add_migrant(PopUnit.State.FOLLOWER, -1)
	return c

func test_roundtrip_all_fields() -> void:
	var f := Follower.new()
	f.uid = 3
	f.name = "Марк"
	f.race = &"elf"
	f.path = &"wizard"
	f.archetype = &"arcane_tradition"
	f.trait_ids.append(&"brave")
	f.trait_ids.append(&"curious")
	f.stat_modifiers[&"INT"] = 3
	f.abilities.append(&"fireball")
	f.gender = &"female"
	var f2 := Follower.new()
	f2.deserialize(f.serialize())
	assert_that(f2.uid).is_equal(3)
	assert_that(f2.name).is_equal("Марк")
	assert_that(f2.race).is_equal(&"elf")
	assert_that(f2.path).is_equal(&"wizard")
	assert_that(f2.archetype).is_equal(&"arcane_tradition")
	assert_that(f2.trait_ids).is_equal([&"brave", &"curious"])
	assert_that(int(f2.stat_modifiers.get(&"INT", 0))).is_equal(3)
	assert_that(f2.abilities).is_equal([&"fireball"])
	assert_that(f2.gender).is_equal(&"female")

func test_gender_default_and_old_save_compat() -> void:
	# team-romance-roleplay: дефолт male, старый сейв без поля → male
	var f := Follower.new()
	assert_that(f.gender).is_equal(&"male")
	var old_save := {"uid": 1, "name": "Глеб", "race": "human", "path": "fighter",
		"archetype": "", "traits": [], "stat_modifiers": [], "abilities": []}
	var f2 := Follower.new()
	f2.deserialize(old_save)
	assert_that(f2.gender).is_equal(&"male")

func test_roundtrip_defaults() -> void:
	var f := Follower.new()
	var f2 := Follower.new()
	f2.deserialize(f.serialize())
	assert_that(f2.race).is_equal(f.race)
	assert_bool((f2.trait_ids as Array).is_empty()).is_true()
	assert_bool((f2.abilities as Array).is_empty()).is_true()

func test_to_dict_json_compatible() -> void:
	var f := Follower.new()
	f.name = "Вера"
	f.race = &"dwarf"
	f.path = &"cleric"
	f.trait_ids.append(&"honest")
	f.stat_modifiers[&"CON"] = 2
	f.gender = &"female"
	var d: Dictionary = f.to_dict()
	assert_that(d.get("name")).is_equal("Вера")
	assert_that(d.get("race")).is_equal("dwarf")
	assert_that(d.get("path")).is_equal("cleric")
	assert_that(d.get("gender")).is_equal("female")
	assert_bool(d.get("traits") is Array).is_true()
	assert_that(String((d.get("traits") as Array)[0])).is_equal("honest")
	var json := JSON.stringify(d)
	assert_str(json).is_not_empty()
	var back: Variant = JSON.parse_string(json)
	assert_bool(back is Dictionary).is_true()

func test_recruit_moves_follower_from_city_to_hero() -> void:
	var city := _make_city(2)
	var hero = auto_free( HeroController.new())
	var before: int = city.pop.size()
	var f := FollowerSystem.recruit(city, hero, TestFactories.seeded(42))
	assert_that(f).is_not_null()
	assert_that(city.pop.size()).is_equal(before - 1)
	assert_that(hero.followers.size()).is_equal(1)
	assert_bool(hero.followers[0] == f).is_true()
	assert_str(f.name).is_not_empty()
	hero.free()

func test_recruit_null_without_free_followers() -> void:
	var city := _make_city(0, 3)
	var hero = auto_free( HeroController.new())
	assert_that(FollowerSystem.recruit(city, hero, TestFactories.seeded(1))).is_null()
	assert_that(hero.followers.size()).is_equal(0)
	hero.free()

func test_recruit_deterministic_with_same_seed() -> void:
	var c1 := _make_city(1)
	var c2 := _make_city(1)
	var h1 = auto_free( HeroController.new())
	var h2 = auto_free( HeroController.new())
	var f1 := FollowerSystem.recruit(c1, h1, TestFactories.seeded(7))
	var f2 := FollowerSystem.recruit(c2, h2, TestFactories.seeded(7))
	assert_that(f1.name).is_equal(f2.name)
	assert_that(f1.race).is_equal(f2.race)
	assert_that(f1.path).is_equal(f2.path)
	assert_that(f1.trait_ids).is_equal(f2.trait_ids)
	assert_that(f1.orientation).is_equal(f2.orientation)
	h1.free()
	h2.free()

func test_orientation_roll_values_and_determinism() -> void:
	# team-romance-roleplay: hetero/homo/bi, детерминизм по seed
	var valid := [&"hetero", &"homo", &"bi"]
	var seen: Dictionary = {}
	for seed in range(1, 51):
		var o := FollowerSystem.roll_orientation(TestFactories.seeded(seed))
		assert_bool(valid.has(o)).is_true()
		seen[String(o)] = int(seen.get(String(o), 0)) + 1
	assert_bool(seen.has(&"hetero")).is_true()
	# один seed — один результат
	assert_that(FollowerSystem.roll_orientation(TestFactories.seeded(5))).is_equal(
		FollowerSystem.roll_orientation(TestFactories.seeded(5)))

func test_orientation_roundtrip_and_old_save() -> void:
	var f := Follower.new()
	f.orientation = &"bi"
	var f2 := Follower.new()
	f2.deserialize(f.serialize())
	assert_that(f2.orientation).is_equal(&"bi")
	# старый сейв без orientation → hetero
	var f3 := Follower.new()
	f3.deserialize({"uid": 1, "name": "X"})
	assert_that(f3.orientation).is_equal(&"hetero")

func test_recruit_gender_from_name() -> void:
	# team-romance-roleplay 6.1: пол выводится из имени (детерминированно)
	var city := _make_city(5)
	var hero = auto_free( HeroController.new())
	var seen_female := false
	var seen_male := false
	for seed in range(1, 21):
		var f := FollowerSystem.recruit(city, hero, TestFactories.seeded(seed))
		if f == null:
			break
		var expected := &"female" if FollowerSystem.FEMALE_NAMES.has(f.name) else &"male"
		assert_that(f.gender).is_equal(expected)
		if f.gender == &"female":
			seen_female = true
		else:
			seen_male = true
	assert_bool(seen_male).is_true()
	assert_bool(seen_female).is_true()
	hero.free()

func test_recruit_uid_increments() -> void:
	var city := _make_city(3)
	var hero = auto_free( HeroController.new())
	var f1 := FollowerSystem.recruit(city, hero, TestFactories.seeded(1))
	var f2 := FollowerSystem.recruit(city, hero, TestFactories.seeded(2))
	assert_that(f1.uid).is_equal(1)
	assert_that(f2.uid).is_equal(2)
	hero.free()
