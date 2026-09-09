class_name TestFactories
extends RefCounted

const City := preload("res://scripts/world/City.gd")
const HeroController := preload("res://scripts/entities/HeroController.gd")
const Follower := preload("res://scripts/entities/Follower.gd")

static func make_city(uid: int = 1, stronghold: int = 2) -> City:
	var city := City.new()
	city.uid = uid
	city.display_name = "TestTown %d" % uid
	city.center = Vector2i(5, 5)
	city.stronghold_level = stronghold
	city.storage[&"industry"] = 500.0
	return city

static func make_hero(path := &"archivist") -> HeroController:
	var h := HeroController.new()
	h.hero_name = "Darkstorn"
	h.path_id = path
	return h

static func seeded(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

static func make_follower(uid: int, path := &"archivist") -> Follower:
	var f := Follower.new()
	f.uid = uid
	f.path = path
	return f

static func make_battle_state(
	atk_key: String = "swordsmen",
	def_key: String = "goblins",
	atk_count: int = 20,
	def_count: int = 5,
	units: Node = null
) -> BattleState:

	if units == null:
		units = Services.resolve(&"units")
	if units == null:
		units = load("res://scripts/autoload/UnitRegistry.gd").new()
	var atk: Array[UnitStack] = [units.make_fixed_stack(atk_key, atk_count)]
	var def: Array[UnitStack] = [units.make_fixed_stack(def_key, def_count)]
	var bs := BattleState.new()
	bs.place_army(atk, def)
	return bs

static func make_city_with_temple(uid: int = 1, stronghold: int = 2, temple_level: int = 2) -> City:
	var city := make_city(uid, stronghold)
	var ub := UniqueBuilding.new()
	ub.def = UniqueBuilding.Def.new()
	ub.def.id = &"great_temple"
	ub.level = temple_level
	city.buildings.append(ub)
	return city
