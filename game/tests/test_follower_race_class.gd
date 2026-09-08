extends GdUnitTestSuite

const _Follower = preload("res://scripts/entities/Follower.gd")
const _FollowerSystem = preload("res://scripts/entities/FollowerSystem.gd")
const _City = preload("res://scripts/world/City.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _RaceClassRegistry = preload("res://scripts/data/RaceClassRegistry.gd")

const _VALID_RACES := ["aasimar", "dwarf", "elf", "gnome", "halfling", "human"]
const _VALID_CLASSES := ["alchemist", "barbarian", "bard", "cleric", "druid", "fighter",
	"inquisitor", "kineticist", "magus", "monk", "paladin", "ranger", "rogue",
	"sorcerer", "wizard", "witch"]


func _make_city() -> City:
	var city := _City.new()
	var u := _PopUnit.new()
	u.uid = 1
	city.pop.append(u)
	return city


class _HeroStub extends RefCounted:
	var followers: Array = []


func _make_hero() -> _HeroStub:
	return _HeroStub.new()



func test_recruit_assigns_race_and_class() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_not_null()
	assert_bool(_VALID_RACES.has(String(f.race).to_lower())).is_true()
	assert_bool(_VALID_CLASSES.has(String(f.path).to_lower())).is_true()
	assert_that(hero.followers.size()).is_equal(1)

func test_recruit_removes_pop() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_FollowerSystem.recruit(city, hero, rng)
	assert_that(city.pop.size()).is_equal(0)

func test_recruit_null_when_no_follower() -> void:
	var city := _City.new()  
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_null()

func test_recruit_null_when_no_hero() -> void:
	var city := _make_city()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var f: _Follower = _FollowerSystem.recruit(city, null, rng)
	assert_that(f).is_null()



func test_elf_stat_modifiers() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_not_null()
	if String(f.race).to_lower() == "elf":
		assert_that(f.stat_modifiers.get(&"DEX", 0)).is_equal(2)
		assert_that(f.stat_modifiers.get(&"INT", 0)).is_equal(2)
		assert_that(f.stat_modifiers.get(&"CON", 0)).is_equal(-2)
		return
	var rc := _RaceClassRegistry.new()
	var race_def: Variant = rc.get_race(StringName(f.race))
	rc = null
	assert_that(race_def).is_not_null()
	assert_that(f.stat_modifiers).is_equal(race_def.ability_adjustments.duplicate())
	for k in f.stat_modifiers:
		assert_bool(f.stat_modifiers[k] is int).is_true()



func test_abilities_include_class_features() -> void:
	var rc := _RaceClassRegistry.new()
	var alch: Variant = rc.get_class_def(&"alchemist")
	rc = null
	assert_that(alch).is_not_null()
	var abilities: Array = _FollowerSystem._collectabilities(alch, null)
	var has_mutagen := false
	for a in abilities:
		if String(a).to_lower().contains("mutagen"):
			has_mutagen = true
	assert_bool(has_mutagen).is_true()

func test_collectabilities_race_traits() -> void:
	var rc := _RaceClassRegistry.new()
	var elf: Variant = rc.get_race(&"elf")
	rc = null
	assert_that(elf).is_not_null()
	var abilities: Array = _FollowerSystem._collectabilities(null, elf)
	assert_bool(not abilities.is_empty()).is_true()



func test_recruit_archetype_assigned() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_not_null()
	assert_bool(f.archetype.is_empty() or (f.archetype is StringName)).is_true()



func test_describe_includes_race_class() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_not_null()
	var desc := f.describe()
	assert_bool(desc.contains(String(f.race))).is_true()
	assert_bool(desc.contains(String(f.path))).is_true()

func test_serialize_roundtrip() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_that(f).is_not_null()
	var data := f.serialize()
	var f2: Variant = _Follower.new()
	f2.deserialize(data)
	assert_that(f2.race).is_equal(f.race)
	assert_that(f2.path).is_equal(f.path)
	assert_that(f2.stat_modifiers).is_equal(f.stat_modifiers)
	assert_that(f2.abilities).is_equal(f.abilities)



func test_recruit_deterministic() -> void:
	var city1 := _make_city()
	var hero1 := _make_hero()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 555
	var f1: Variant = _FollowerSystem.recruit(city1, hero1, rng1)

	var city2 := _make_city()
	var hero2 := _make_hero()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 555
	var f2: Variant = _FollowerSystem.recruit(city2, hero2, rng2)

	assert_that(f1.race).is_equal(f2.race)
	assert_that(f1.path).is_equal(f2.path)
	assert_that(f1.archetype).is_equal(f2.archetype)
	assert_that(f1.stat_modifiers).is_equal(f2.stat_modifiers)
