extends "res://tests/gut_base.gd"
## city-in-world: назначение расы/класса/архетипа и модификаторов
## в Follower и FollowerSystem.recruit.

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


## Хелпер-герой с объявленным свойством followers (recruit делает hero.followers.append(f)).
class _HeroStub extends RefCounted:
	var followers: Array = []


func _make_hero() -> _HeroStub:
	return _HeroStub.new()


# ==================== НАЗНАЧЕНИЕ РАСЫ/КЛАССА ====================

func test_recruit_assigns_race_and_class() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_not_null(f, "recruit returned a follower")
	assert_true(_VALID_RACES.has(String(f.race).to_lower()), "valid race: %s" % f.race)
	assert_true(_VALID_CLASSES.has(String(f.path).to_lower()), "valid class: %s" % f.path)
	assert_eq(hero.followers.size(), 1, "recruit added follower to hero")

func test_recruit_removes_pop() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_FollowerSystem.recruit(city, hero, rng)
	assert_eq(city.pop.size(), 0, "pop decreased after recruit")

func test_recruit_null_when_no_follower() -> void:
	var city := _City.new()  # без юнитов
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_null(f, "recruit returns null when no free follower")

func test_recruit_null_when_no_hero() -> void:
	var city := _make_city()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var f: _Follower = _FollowerSystem.recruit(city, null, rng)
	assert_null(f, "recruit returns null when hero is null")


# ==================== МОДИФИКАТОРЫ ====================

func test_elf_stat_modifiers() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_not_null(f, "recruit returned a follower")
	# Если выпала эльфийка — проверяем её характерные модификаторы.
	if String(f.race).to_lower() == "elf":
		assert_eq(f.stat_modifiers.get(&"DEX", 0), 2, "elf +2 DEX")
		assert_eq(f.stat_modifiers.get(&"INT", 0), 2, "elf +2 INT")
		assert_eq(f.stat_modifiers.get(&"CON", 0), -2, "elf -2 CON")
		return
	# Для любой расы модификаторы должны совпадать с матрицей рас-классов
	# (у human они пустые — это корректные данные Pathfinder).
	var rc := _RaceClassRegistry.new()
	var race_def: Variant = rc.get_race(StringName(f.race))
	rc = null
	assert_not_null(race_def, "picked race found in registry")
	assert_eq(f.stat_modifiers, race_def.ability_adjustments.duplicate(), "stat_modifiers match race matrix")
	for k in f.stat_modifiers:
		assert_true(f.stat_modifiers[k] is int, "modifier is int: %s=%s" % [k, f.stat_modifiers[k]])


# ==================== СПЕЦИФИКАЦИЯ КЛАССА ====================

func test_abilities_include_class_features() -> void:
	var rc := _RaceClassRegistry.new()
	var alch: Variant = rc.get_class_def(&"alchemist")
	rc = null
	assert_not_null(alch, "alchemist found")
	var abilities: Array = _FollowerSystem._collectabilities(alch, null)
	var has_mutagen := false
	for a in abilities:
		if String(a).to_lower().contains("mutagen"):
			has_mutagen = true
	assert_true(has_mutagen, "alchemist abilities include Mutagen")

func test_collectabilities_race_traits() -> void:
	var rc := _RaceClassRegistry.new()
	var elf: Variant = rc.get_race(&"elf")
	rc = null
	assert_not_null(elf, "elf found")
	var abilities: Array = _FollowerSystem._collectabilities(null, elf)
	assert_true(not abilities.is_empty(), "elf traits collected: %s" % str(abilities))


# ==================== АРХЕТИП ====================

func test_recruit_archetype_assigned() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_not_null(f, "recruit returned a follower")
	# архетип либо пустой (базовый класс), либо непустой StringName.
	assert_true(f.archetype.is_empty() or (f.archetype is StringName), "archetype well-typed")


# ==================== ОПИСАНИЕ / СЕРИАЛИЗАЦИЯ ====================

func test_describe_includes_race_class() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_not_null(f, "recruit returned a follower")
	var desc := f.describe()
	assert_true(desc.contains(String(f.race)), "describe includes race: %s" % desc)
	assert_true(desc.contains(String(f.path)), "describe includes class: %s" % desc)

func test_serialize_roundtrip() -> void:
	var city := _make_city()
	var hero := _make_hero()
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var f: _Follower = _FollowerSystem.recruit(city, hero, rng)
	assert_not_null(f, "recruit returned a follower")
	var data := f.serialize()
	var f2: Variant = _Follower.new()
	f2.deserialize(data)
	assert_eq(f2.race, f.race, "roundtrip race preserved")
	assert_eq(f2.path, f.path, "roundtrip path preserved")
	assert_eq(f2.stat_modifiers, f.stat_modifiers, "roundtrip stat_modifiers preserved")
	assert_eq(f2.abilities, f.abilities, "roundtrip abilities preserved")


# ==================== ДЕТЕРМИНАН ====================

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

	assert_eq(f1.race, f2.race, "race deterministic")
	assert_eq(f1.path, f2.path, "class deterministic")
	assert_eq(f1.archetype, f2.archetype, "archetype deterministic")
	assert_eq(f1.stat_modifiers, f2.stat_modifiers, "stat_modifiers deterministic")
