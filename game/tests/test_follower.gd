extends "res://tests/test_base.gd"
## city-in-world: последователи.
##  - Follower round-trip (serialize/deserialize: имя, раса, путь, архетип,
##    черты, модификаторы, способности);
##  - to_dict — JSON-совместимо (сокет CITY_HIRE / GET_STATE);
##  - FollowerSystem.recruit: город отдаёт свободного FOLLOWER-юнита (pop падает),
##    герой получает Follower; детерминировано по rng;
##  - recruit → null, когда свободных FOLLOWER не осталось.

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
	assert_eq(f2.uid, 3, "uid")
	assert_eq(f2.name, "Марк", "имя")
	assert_eq(f2.race, &"elf", "раса")
	assert_eq(f2.path, &"wizard", "путь")
	assert_eq(f2.archetype, &"arcane_tradition", "архетип")
	assert_eq(f2.trait_ids, [&"brave", &"curious"], "черты")
	assert_eq(int(f2.stat_modifiers.get(&"INT", 0)), 3, "модификатор")
	assert_eq(f2.abilities, [&"fireball"], "способности")


func test_roundtrip_defaults() -> void:
	# Пустые/по-умолчанию поля не ломают deserialize.
	var f := _Follower.new()
	var f2 := _Follower.new()
	f2.deserialize(f.serialize())
	assert_eq(f2.race, f.race, "раса по умолчанию")
	assert_true((f2.trait_ids as Array).is_empty(), "черты пусты")
	assert_true((f2.abilities as Array).is_empty(), "способности пусты")


func test_to_dict_json_compatible() -> void:
	var f := _Follower.new()
	f.name = "Вера"
	f.race = &"dwarf"
	f.path = &"cleric"
	f.trait_ids.append(&"honest")
	f.stat_modifiers[&"CON"] = 2
	var d: Dictionary = f.to_dict()
	assert_eq(d.get("name"), "Вера", "имя в dict")
	assert_eq(d.get("race"), "dwarf", "раса строкой (не StringName)")
	assert_eq(d.get("path"), "cleric", "путь строкой")
	assert_true(d.get("traits") is Array, "traits — массив")
	assert_eq(String((d.get("traits") as Array)[0]), "honest", "trait id строкой")
	var json := JSON.stringify(d)
	assert_not_empty(json, "JSON сериализуется")
	var back: Variant = JSON.parse_string(json)
	assert_true(back is Dictionary, "JSON парсится обратно")


func test_recruit_moves_follower_from_city_to_hero() -> void:
	# Hero без дерева: recruit трогает только hero.followers.
	var city := _make_city(2)
	var hero := HeroController.new()
	var before: int = city.pop.size()
	var f := _FollowerSystem.recruit(city, hero, _seeded(42))
	assert_not_null(f, "найден последователь")
	assert_eq(city.pop.size(), before - 1, "pop города −1")
	assert_eq(hero.followers.size(), 1, "у героя 1 последователь")
	assert_true(hero.followers[0] == f, "тот же объект")
	assert_not_empty(f.name, "имя назначено")
	hero.free()


func test_recruit_null_without_free_followers() -> void:
	var city := _make_city(0, 3)  # только рабочие
	var hero := HeroController.new()
	assert_null(_FollowerSystem.recruit(city, hero, _seeded(1)), "без FOLLOWER — null")
	assert_eq(hero.followers.size(), 0, "герой пуст")
	hero.free()


func test_recruit_deterministic_with_same_seed() -> void:
	var c1 := _make_city(1)
	var c2 := _make_city(1)
	var h1 := HeroController.new()
	var h2 := HeroController.new()
	var f1 := _FollowerSystem.recruit(c1, h1, _seeded(7))
	var f2 := _FollowerSystem.recruit(c2, h2, _seeded(7))
	assert_eq(f1.name, f2.name, "имя детерминировано")
	assert_eq(f1.race, f2.race, "раса детерминирована")
	assert_eq(f1.path, f2.path, "путь детерминирован")
	assert_eq(f1.trait_ids, f2.trait_ids, "черты детерминированы")
	h1.free()
	h2.free()


func test_recruit_uid_increments() -> void:
	var city := _make_city(3)
	var hero := HeroController.new()
	var f1 := _FollowerSystem.recruit(city, hero, _seeded(1))
	var f2 := _FollowerSystem.recruit(city, hero, _seeded(2))
	assert_eq(f1.uid, 1, "первый uid 1")
	assert_eq(f2.uid, 2, "второй uid 2")
	hero.free()


func _seeded(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
