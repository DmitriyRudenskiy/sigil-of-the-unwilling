class_name FollowerSystem
extends RefCounted

const FOLLOWER_NAMES: Array = [
	"Аркадий", "Борис", "Вера", "Глеб", "Дарья", "Елизар", "Жанна", "Захар",
	"Ирина", "Кирилл", "Люба", "Марк", "Настасья", "Олег", "Пелагея", "Родион",
	"Светлана", "Тимур", "Устинья", "Фёдор",
]

const _Follower = preload("res://scripts/entities/Follower.gd")
const _RaceClass = preload("res://scripts/data/RaceClassRegistry.gd")
const _RaceDef = preload("res://scripts/data/RaceDef.gd")
const _ClassDef = preload("res://scripts/data/ClassDef.gd")
const _Trait = preload("res://scripts/demographics/TraitRegistry.gd")
const _City = preload("res://scripts/world/City.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")

static var _default_registry: _Trait = null
static var _default_raceclass: _RaceClass = null


static func registry() -> _Trait:
	if _default_registry == null:
		_default_registry = _Trait.new()
	return _default_registry


static func raceclass_registry() -> _RaceClass:
	if _default_raceclass == null:
		_default_raceclass = _RaceClass.new()
	return _default_raceclass


static func make_follower(uid: int, name: String, trait_ids: Array = []) -> _Follower:
	var f := _Follower.new()
	f.uid = uid
	f.name = name
	for id in trait_ids:
		f.trait_ids.append(StringName(id))
	return f


static func recruit(
	city: _City, hero, rng: RandomNumberGenerator,
	registry: _Trait = null
) -> _Follower:
	if city == null or hero == null:
		return null
	var unit: _PopUnit = _find_free_follower(city)
	if unit == null:
		return null
	city.remove_pop(unit.uid)

	var r: RandomNumberGenerator
	if rng != null:
		r = rng
	else:
		r = RandomNumberGenerator.new()
	var reg: _Trait = registry if registry != null else registry()

	var traits: Array = reg.roll_traits(r, 2)
	var ids: Array = []
	for t in traits:
		ids.append(t.id)

	var rc: _RaceClass = raceclass_registry()
	var rc_race: _RaceDef = rc.pick_race(r)
	var rc_class: _ClassDef = rc.pick_class(r)
	var rc_arch: Dictionary = rc.pick_archetype(rc_class, r)

	var f: _Follower = make_follower(
		_next_uid(hero), FOLLOWER_NAMES[r.randi_range(0, FOLLOWER_NAMES.size() - 1)], ids)
	f.race = rc_race.id if rc_race != null else f.race
	f.path = rc_class.id if rc_class != null else f.path
	f.archetype = StringName(String(rc_arch.get("id", ""))) if rc_arch != null else &""
	f.stat_modifiers = rc_race.ability_adjustments.duplicate() if rc_race != null else {}
	f.abilities = _collectabilities(rc_class, rc_race)

	hero.followers.append(f)
	return f


static func _collectabilities(class_def: _ClassDef, race_def: _RaceDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if class_def != null:
		for feat in class_def.features:
			out.append(StringName(feat))
	if race_def != null:
		for tr in race_def.traits:
			out.append(StringName(tr))
	return out


static func _find_free_follower(city: _City) -> _PopUnit:
	for u in city.pop:
		if u != null and u.is_free_follower():
			return u
	return null


static func _next_uid(hero) -> int:
	var max_uid := 0
	for f in hero.followers:
		max_uid = maxi(max_uid, int(f.uid))
	return max_uid + 1
