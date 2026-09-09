extends GdUnitTestSuite

const _Character = preload("res://scripts/demographics/Character.gd")
const _CharacterRegistry = preload("res://scripts/demographics/CharacterRegistry.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _TraitDef = preload("res://scripts/demographics/TraitDef.gd")


func _mk_pop(uid: int) -> PopUnit:
	var p := _PopUnit.new()
	p.uid = uid
	p.born_turn = 0
	return p



func test_new_character_defaults() -> void:
	var ch := _Character.new()
	assert_bool(ch.alive).is_true()
	for k in _Character.NEED_KEYS:
		assert_that(ch.needs[k]).is_equal(0.8)
		assert_that(ch.need_zero_streak[k]).is_equal(0)
		assert_bool(ch.was_critical[k]).is_false()


func test_modify_need_clamps() -> void:
	var ch := _Character.new()
	ch.modify_need(NeedType.ID.REST, 5.0)
	assert_that(ch.needs[NeedType.ID.REST]).is_equal(1.0)
	ch.modify_need(NeedType.ID.REST, -5.0)
	assert_that(ch.needs[NeedType.ID.REST]).is_equal(0.0)


func test_is_need_critical() -> void:
	var ch := _Character.new()
	ch.modify_need(NeedType.ID.REST, -0.7)
	assert_bool(ch.is_need_critical(NeedType.ID.REST)).is_true()
	assert_bool(ch.is_need_critical(NeedType.ID.INSPIRATION)).is_false()
	ch.modify_need(NeedType.ID.REST, 0.05)
	assert_bool(ch.is_need_critical(NeedType.ID.REST)).is_true()


func test_trait_modifier_sums() -> void:
	var ch := _Character.new()
	var t1 := _TraitDef.new()
	t1.effect_type = &"rest"
	t1.effect_value = 0.1
	var t2 := _TraitDef.new()
	t2.effect_type = &"rest"
	t2.effect_value = -0.05
	ch.traits = [t1, t2]
	assert_that(ch.trait_modifier(&"rest")).is_equal(0.05)
	assert_that(ch.trait_modifier(&"inspiration")).is_equal(0.0)


func test_age_in_days() -> void:
	var ch := _Character.new()
	ch.birth_turn = 5
	assert_that(ch.age_in_days(10)).is_equal(5)
	assert_that(ch.age_in_days(3)).is_equal(0)


func test_serialize_roundtrip() -> void:
	var ch := _Character.new()
	ch.uid = 7
	ch.name = "Тест"
	ch.icon = "🧙"
	ch.birth_turn = 3
	ch.city_uid = 1
	ch.pop_uid = 9
	ch.modify_need(NeedType.ID.SOCIAL, -0.3)
	var t := _TraitDef.new()
	t.id = &"sleepy"
	t.effect_type = &"rest"
	t.effect_value = 0.05
	ch.traits = [t]
	ch.alive = false
	var d := ch.serialize()
	var ch2 := _Character.deserialize(d)
	assert_that(ch2.uid).is_equal(7)
	assert_that(ch2.name).is_equal("Тест")
	assert_that(ch2.icon).is_equal("🧙")
	assert_that(ch2.birth_turn).is_equal(3)
	assert_that(ch2.city_uid).is_equal(1)
	assert_that(ch2.pop_uid).is_equal(9)
	assert_that(ch2.needs[NeedType.ID.SOCIAL]).is_equal(0.5)
	assert_that(ch2.needs[NeedType.ID.REST]).is_equal(0.8)
	assert_bool(ch2.alive).is_false()
	assert_that(ch2.traits.size()).is_equal(1)
	assert_that(ch2.traits[0].id).is_equal(&"sleepy")


func test_deserialize_migrates_belief_to_inspiration() -> void:
	var old_save := {
		"uid": 42,
		"name": "Старый",
		"icon": "🙂",
		"birth_turn": 0,
		"city_uid": -1,
		"pop_uid": -1,
		"alive": true,
		"needs": {"hunger": "0.8", "rest": "0.8", "social": "0.8", "belief": "0.4"},
		"traits": [],
	}
	var ch := _Character.deserialize(old_save)
	assert_bool(ch.needs.has(NeedType.ID.INSPIRATION)).is_true()
	assert_that(ch.needs[NeedType.ID.INSPIRATION]).is_equal(0.4)
	assert_that(ch.needs.size()).is_equal(3) # belief/hunger отброшены
	var mixed_save := {
		"uid": 43, "name": "Микс", "icon": "🙂", "birth_turn": 0,
		"city_uid": -1, "pop_uid": -1, "alive": true,
		"needs": {"belief": "0.4", "inspiration": "0.6"}, "traits": [],
	}
	var ch2 := _Character.deserialize(mixed_save)
	assert_that(ch2.needs[NeedType.ID.INSPIRATION]).is_equal(0.6)
	assert_that(ch2.needs.size()).is_equal(3)



func test_registry_create_and_link() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch: Character = reg.create(5, p)
	assert_bool(ch.uid >= 0).is_true()
	assert_that(p.character_uid).is_equal(ch.uid)
	assert_that(reg.get_by_pop(1).uid).is_equal(ch.uid)
	assert_that(reg.get_by_uid(ch.uid).uid).is_equal(ch.uid)
	assert_that(reg.all().size()).is_equal(1)
	assert_bool(_CharacterRegistry._NAMES.has(ch.name)).is_true()


func test_registry_create_idempotent() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch1: Character = reg.create(5, p)
	var ch2: Character = reg.create(5, p)
	assert_that(ch1.uid).is_equal(ch2.uid)
	assert_that(reg.all().size()).is_equal(1)


func test_registry_uids_unique() -> void:
	var reg := _CharacterRegistry.new()
	var p1 := _mk_pop(1)
	var p2 := _mk_pop(2)
	var c1: Character = reg.create(0, p1)
	var c2: Character = reg.create(0, p2)
	assert_bool(c1.uid != c2.uid).is_true()


func test_registry_create_reuses_rng_for_traits() -> void:
	var reg := _CharacterRegistry.new()
	var r1 := TestFactories.seeded(9584)
	r1.seed = 99
	var r2 := TestFactories.seeded(9584)
	r2.seed = 99
	var c1: Character = reg.create(0, _mk_pop(1), r1)
	reg = _CharacterRegistry.new()
	var c2: Character = reg.create(0, _mk_pop(1), r2)
	var ids1 := _trait_ids(c1.traits)
	var ids2 := _trait_ids(c2.traits)
	assert_that(ids1).is_equal(ids2)


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
	assert_that(dead.uid).is_equal(ch.uid)
	assert_that(reg.get_by_pop(1)).is_null()
	assert_that(reg.get_by_uid(ch.uid).uid).is_equal(ch.uid)
	assert_that(reg.on_pop_removed(999)).is_null()


func test_registry_remove() -> void:
	var reg := _CharacterRegistry.new()
	var p := _mk_pop(1)
	var ch: Character = reg.create(0, p)
	reg.remove(ch.uid)
	assert_that(reg.get_by_uid(ch.uid)).is_null()
	assert_that(reg.all().size()).is_equal(0)


func test_alive_in_city_filter() -> void:
	var reg := _CharacterRegistry.new()
	var p1 := _mk_pop(1)
	var p2 := _mk_pop(2)
	var c1: Character = reg.create(7, p1)
	reg.create(9, p2)
	assert_that(reg.alive_in_city(7).size()).is_equal(1)
	assert_that(reg.alive_in_city(9).size()).is_equal(1)
	c1.alive = false
	assert_that(reg.alive_in_city(7).size()).is_equal(0)


func test_registry_serialize_roundtrip() -> void:
	var reg := _CharacterRegistry.new()
	reg.create(1, _mk_pop(1))
	reg.create(1, _mk_pop(2))
	var data: Array = reg.serialize()
	assert_that(data.size()).is_equal(2)
	var reg2 := _CharacterRegistry.new()
	reg2.deserialize(data)
	assert_that(reg2.all().size()).is_equal(2)
	var found: Character = reg2.get_by_pop(1)
	assert_that(found).is_not_null()
	assert_that(found.city_uid).is_equal(1)
	var c3: Character = reg2.create(1, _mk_pop(3))
	var old_max := 0
	for d in data:
		old_max = maxi(old_max, int(d["uid"]))
	assert_bool(c3.uid > old_max).is_true()


func test_registry_deserialize_dead_char_no_link() -> void:
	var reg := _CharacterRegistry.new()
	var ch: Character = reg.create(1, _mk_pop(1))
	ch.alive = false
	var reg2 := _CharacterRegistry.new()
	reg2.deserialize(reg.serialize())
	var restored: Character = reg2.get_by_uid(ch.uid)
	assert_that(restored).is_not_null()
	assert_bool(restored.alive).is_false()
	assert_that(reg2.get_by_pop(1)).is_null()
