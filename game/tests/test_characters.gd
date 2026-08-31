extends "res://tests/test_base.gd"
## M2: Персонажи — Character (потребности, черты, сериализация) и
## CharacterRegistry (связь с PopUnit, uid, сериализация).

const _Character = preload("res://scripts/demographics/Character.gd")
const _CharacterRegistry = preload("res://scripts/demographics/CharacterRegistry.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _TraitDef = preload("res://scripts/demographics/TraitDef.gd")


func _mk_pop(uid: int) -> PopUnit:
	var p := _PopUnit.new()
	p.uid = uid
	p.born_turn = 0
	return p


# ==================== CHARACTER ====================

func test_new_character_defaults() -> void:
	var ch := _Character.new()
	assert_true(ch.alive, "alive by default")
	for k in _Character.NEED_KEYS:
		assert_eq(ch.needs[k], 0.8, "need %s = 0.8" % k)
		assert_eq(ch.need_zero_streak[k], 0, "zero streak 0")
		assert_false(ch.was_critical[k], "not critical")


func test_modify_need_clamps() -> void:
	var ch := _Character.new()
	ch.modify_need(&"hunger", 5.0)
	assert_eq(ch.needs[&"hunger"], 1.0, "clamped to 1")
	ch.modify_need(&"hunger", -5.0)
	assert_eq(ch.needs[&"hunger"], 0.0, "clamped to 0")


func test_is_need_critical() -> void:
	var ch := _Character.new()
	ch.modify_need(&"hunger", -0.7)
	assert_true(ch.is_need_critical(&"hunger"), "0.1 < 0.2")
	assert_false(ch.is_need_critical(&"belief"), "0.8 not critical")
	ch.modify_need(&"hunger", 0.05)
	assert_true(ch.is_need_critical(&"hunger"), "0.15 still critical")


func test_trait_modifier_sums() -> void:
	var ch := _Character.new()
	var t1 := _TraitDef.new()
	t1.effect_type = &"hunger"
	t1.effect_value = 0.1
	var t2 := _TraitDef.new()
	t2.effect_type = &"hunger"
	t2.effect_value = -0.05
	ch.traits = [t1, t2]
	assert_eq(ch.trait_modifier(&"hunger"), 0.05, "sum of modifiers")
	assert_eq(ch.trait_modifier(&"belief"), 0.0, "unaffected need")


func test_age_in_days() -> void:
	var ch := _Character.new()
	ch.birth_turn = 5
	assert_eq(ch.age_in_days(10), 5, "age 5 days")
	assert_eq(ch.age_in_days(3), 0, "clamped to 0")


func test_serialize_roundtrip() -> void:
	var ch := _Character.new()
	ch.uid = 7
	ch.name = "Тест"
	ch.icon = "🧙"
	ch.birth_turn = 3
	ch.city_uid = 1
	ch.pop_uid = 9
	ch.modify_need(&"hunger", -0.3)
	var t := _TraitDef.new()
	t.id = &"hardy"
	t.effect_type = &"hunger"
	t.effect_value = 0.1
	ch.traits = [t]
	ch.alive = false
	var d := ch.serialize()
	var ch2 := _Character.deserialize(d)
	assert_eq(ch2.uid, 7, "uid")
	assert_eq(ch2.name, "Тест", "name")
	assert_eq(ch2.icon, "🧙", "icon")
	assert_eq(ch2.birth_turn, 3, "birth turn")
	assert_eq(ch2.city_uid, 1, "city uid")
	assert_eq(ch2.pop_uid, 9, "pop uid")
	assert_eq(ch2.needs[&"hunger"], 0.5, "need value")
	assert_eq(ch2.needs[&"rest"], 0.8, "untouched need")
	assert_false(ch2.alive, "alive state")
	assert_eq(ch2.traits.size(), 1, "trait count")
	assert_eq(ch2.traits[0].id, &"hardy", "trait id")


# ==================== REGISTRY ====================

func test_registry_create_and_link() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch: Character = reg.create(5, p)
	assert_true(ch.uid >= 0, "uid assigned")
	assert_eq(p.character_uid, ch.uid, "pop linked")
	assert_eq(reg.get_by_pop(1).uid, ch.uid, "get_by_pop")
	assert_eq(reg.get_by_uid(ch.uid).uid, ch.uid, "get by uid")
	assert_eq(reg.all().size(), 1, "one character")
	assert_true(_CharacterRegistry._NAMES.has(ch.name), "name from pool: %s" % ch.name)


func test_registry_create_idempotent() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch1: Character = reg.create(5, p)
	var ch2: Character = reg.create(5, p)
	assert_eq(ch1.uid, ch2.uid, "same character returned")
	assert_eq(reg.all().size(), 1, "one character total")


func test_registry_uids_unique() -> void:
	var reg := _CharacterRegistry.new()
	var p1 := _mk_pop(1)
	var p2 := _mk_pop(2)
	var c1: Character = reg.create(0, p1)
	var c2: Character = reg.create(0, p2)
	assert_true(c1.uid != c2.uid, "unique uids")


func test_registry_create_reuses_rng_for_traits() -> void:
	var reg := _CharacterRegistry.new()
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var c1: Character = reg.create(0, _mk_pop(1), r1)
	## Сбрасываем реестр, чтобы сравнить вторую выкатку traits.
	reg = _CharacterRegistry.new()
	var c2: Character = reg.create(0, _mk_pop(1), r2)
	var ids1 := _trait_ids(c1.traits)
	var ids2 := _trait_ids(c2.traits)
	assert_eq(ids1, ids2, "traits deterministic by rng")


func _trait_ids(traits: Array) -> Array:
	var ids: Array = []
	for t in traits:
		ids.append(t.id)
	return ids


func test_registry_on_pop_removed() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch: Character = reg.create(0, p)
	var dead: Character = reg.on_pop_removed(1)
	assert_eq(dead.uid, ch.uid, "returned character")
	assert_null(reg.get_by_pop(1), "link removed")
	assert_eq(reg.get_by_uid(ch.uid).uid, ch.uid, "record kept (for chronicles)")
	assert_null(reg.on_pop_removed(999), "unknown pop -> null")


func test_registry_remove() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch: Character = reg.create(0, p)
	reg.remove(ch.uid)
	assert_null(reg.get_by_uid(ch.uid), "removed")
	assert_eq(reg.all().size(), 0, "registry empty")


func test_alive_in_city_filter() -> void:
	var reg := _CharacterRegistry.new()
	var p1 := _mk_pop(1)
	var p2 := _mk_pop(2)
	var c1: Character = reg.create(7, p1)
	reg.create(9, p2)
	assert_eq(reg.alive_in_city(7).size(), 1, "only city 7")
	assert_eq(reg.alive_in_city(9).size(), 1, "only city 9")
	c1.alive = false
	assert_eq(reg.alive_in_city(7).size(), 0, "dead filtered out")


func test_registry_serialize_roundtrip() -> void:
	var reg := _CharacterRegistry.new()
	reg.create(1, _mk_pop(1))
	reg.create(1, _mk_pop(2))
	var data: Array = reg.serialize()
	assert_eq(data.size(), 2, "2 serialized")
	var reg2 := _CharacterRegistry.new()
	reg2.deserialize(data)
	assert_eq(reg2.all().size(), 2, "restored count")
	var found: Character = reg2.get_by_pop(1)
	assert_not_null(found, "by_pop restored")
	assert_eq(found.city_uid, 1, "city uid restored")
	# uid не переиспользуются после восстановления
	var c3: Character = reg2.create(1, _mk_pop(3))
	var old_max := 0
	for d in data:
		old_max = maxi(old_max, int(d["uid"]))
	assert_true(c3.uid > old_max, "new uid > restored max")


func test_registry_deserialize_dead_char_no_link() -> void:
	var reg := _CharacterRegistry.new()
	var ch: Character = reg.create(1, _mk_pop(1))
	ch.alive = false
	var reg2 := _CharacterRegistry.new()
	reg2.deserialize(reg.serialize())
	var restored: Character = reg2.get_by_uid(ch.uid)
	assert_not_null(restored, "dead char kept")
	assert_false(restored.alive, "alive=false restored")
	assert_null(reg2.get_by_pop(1), "dead char not linked to pop")
