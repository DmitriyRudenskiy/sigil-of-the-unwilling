extends GdUnitTestSuite

const _TraitDef = preload("res://scripts/demographics/TraitDef.gd")
const _TraitRegistry = preload("res://scripts/demographics/TraitRegistry.gd")

var reg: Variant


func before_test() -> void:
	reg = _TraitRegistry.new()



func test_defaults_loaded() -> void:
	assert_that(reg.all().size()).is_equal(15)
	assert_bool(reg.has(&"sleepy")).is_true()
	var t: TraitDef = reg.get_trait(&"sleepy")
	assert_that(t.effect_type).is_equal(&"rest")
	assert_that(t.effect_value).is_equal(-0.08)


func test_get_unknown() -> void:
	assert_that(reg.get_trait(&"no_such_trait")).is_null()


func test_by_tag() -> void:
	var body: Array = reg.by_tag(&"body")
	assert_bool(body.size() >= 4).is_true()
	assert_that(reg.by_tag(&"nonexistent_tag_xyz").size()).is_equal(0)


func test_by_rarity_distribution() -> void:
	assert_that(reg.by_rarity(TraitDef.Rarity.COMMON).size()).is_equal(5)
	assert_that(reg.by_rarity(TraitDef.Rarity.UNCOMMON).size()).is_equal(3)
	assert_that(reg.by_rarity(TraitDef.Rarity.RARE).size()).is_equal(3)
	assert_that(reg.by_rarity(TraitDef.Rarity.LEGENDARY).size()).is_equal(4)



func test_roll_deterministic_with_seed() -> void:
	var r1 := TestFactories.seeded(4035)
	r1.seed = 42
	var r2 := TestFactories.seeded(4035)
	r2.seed = 42
	var a: Array = reg.roll_traits(r1)
	var b: Array = reg.roll_traits(r2)
	assert_that(a.size()).is_equal(b.size())
	for i in a.size():
		assert_that((a[i] as TraitDef).id).is_equal((b[i] as TraitDef).id)


func test_roll_range_and_no_dups() -> void:
	var r := TestFactories.seeded(4035)
	r.seed = 7
	var seen := {}
	for i in 200:
		var ts: Array = reg.roll_traits(r)
		assert_bool(ts.size() <= 3).is_true()
		var ids: Array = []
		for t in ts:
			assert_bool(not ids.has(t.id)).is_true()
			ids.append(t.id)
			seen[t.id] = true
	assert_bool(seen.size() >= 8).is_true()


func test_roll_max_count() -> void:
	var r := TestFactories.seeded(4035)
	r.seed = 1
	for i in 50:
		var ts: Array = reg.roll_traits(r, 1)
		assert_bool(ts.size() <= 1).is_true()


func test_roll_zero_possible() -> void:
	var r := TestFactories.seeded(4035)
	r.seed = 3
	var zeros := 0
	for i in 300:
		if reg.roll_traits(r).is_empty():
			zeros += 1
	assert_bool(zeros >= 1).is_true()



func test_custom_trait_add() -> void:
	var t := _TraitDef.new()
	t.id = &"custom"
	t.display_name = "Кастом"
	t.rarity = _TraitDef.Rarity.RARE
	t.effect_type = &"inspiration"
	t.effect_value = -0.5
	reg.add(t)
	assert_bool(reg.has(&"custom")).is_true()
	var g: TraitDef = reg.get_trait(&"custom")
	assert_that(g.effect_value).is_equal(-0.5)
	assert_that(g.rarity).is_equal(_TraitDef.Rarity.RARE)


func test_custom_trait_replaces_default() -> void:
	var t := _TraitDef.new()
	t.id = &"sleepy"
	t.effect_type = &"rest"
	t.effect_value = 0.5
	reg.add(t)
	assert_that(reg.all().size()).is_equal(15)
	var g: TraitDef = reg.get_trait(&"sleepy")
	assert_that(g.effect_value).is_equal(0.5)



func test_trait_serialize_roundtrip_single() -> void:
	var t: TraitDef = reg.get_trait(&"sleepy")
	var d := t.to_dict()
	var t2 := _TraitDef.from_dict(d)
	assert_that(t2.id).is_equal(t.id)
	assert_that(t2.display_name).is_equal(t.display_name)
	assert_that(t2.effect_type).is_equal(t.effect_type)
	assert_that(t2.effect_value).is_equal(t.effect_value)
	assert_that(t2.rarity).is_equal(t.rarity)
	assert_that(t2.tags).is_equal(t.tags)
	assert_that(t2.modifier_for(t.effect_type)).is_equal(t.effect_value)


func test_trait_serialize_roundtrip_multi_effect() -> void:
	var t: TraitDef = reg.get_trait(&"restless")
	var d := t.to_dict()
	var t2 := _TraitDef.from_dict(d)
	assert_that(t2.modifier_for(&"rest")).is_equal(-0.05)
	assert_that(t2.modifier_for(&"social")).is_equal(0.10)
	assert_that(t2.modifier_for(&"inspiration")).is_equal(0.0)
