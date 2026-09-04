extends "res://tests/gut_base.gd"
## M2: Черты — TraitDef и TraitRegistry (реестр, выкатка по редкости,
## сериализация, пользовательские черты).

const _TraitDef = preload("res://scripts/demographics/TraitDef.gd")
const _TraitRegistry = preload("res://scripts/demographics/TraitRegistry.gd")

var reg: Variant


func before_each() -> void:
	reg = _TraitRegistry.new()


# ==================== РЕЕСТР ====================

func test_defaults_loaded() -> void:
	assert_eq(reg.all().size(), 15, "15 default traits")
	assert_true(reg.has(&"sleepy"), "has sleepy")
	var t: TraitDef = reg.get_trait(&"sleepy")
	assert_eq(t.effect_type, &"rest", "sleepy affects rest")
	assert_eq(t.effect_value, -0.08, "sleepy -0.08")


func test_get_unknown() -> void:
	assert_null(reg.get_trait(&"no_such_trait"), "null for unknown")


func test_by_tag() -> void:
	var body: Array = reg.by_tag(&"body")
	assert_true(body.size() >= 4, "body tag has traits (got %d)" % body.size())
	assert_eq(reg.by_tag(&"nonexistent_tag_xyz").size(), 0, "no such tag")


func test_by_rarity_distribution() -> void:
	## 5/3/3/4: commons — самая частая группа (15 черт всего).
	assert_eq(reg.by_rarity(TraitDef.Rarity.COMMON).size(), 5, "common has 5")
	assert_eq(reg.by_rarity(TraitDef.Rarity.UNCOMMON).size(), 3, "uncommon has 3")
	assert_eq(reg.by_rarity(TraitDef.Rarity.RARE).size(), 3, "rare has 3")
	assert_eq(reg.by_rarity(TraitDef.Rarity.LEGENDARY).size(), 4, "legendary has 4")


# ==================== ВЫКАТКА ====================

func test_roll_deterministic_with_seed() -> void:
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var a: Array = reg.roll_traits(r1)
	var b: Array = reg.roll_traits(r2)
	assert_eq(a.size(), b.size(), "same count")
	for i in a.size():
		assert_eq((a[i] as TraitDef).id, (b[i] as TraitDef).id, "same trait %d" % i)


func test_roll_range_and_no_dups() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var seen := {}
	for i in 200:
		var ts: Array = reg.roll_traits(r)
		assert_true(ts.size() <= 3, "count <= 3 (got %d)" % ts.size())
		var ids: Array = []
		for t in ts:
			assert_true(not ids.has(t.id), "no dup %s" % t.id)
			ids.append(t.id)
			seen[t.id] = true
	assert_true(seen.size() >= 8, "variety: >= 8 distinct traits in 200 rolls (got %d)" % seen.size())


func test_roll_max_count() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	for i in 50:
		var ts: Array = reg.roll_traits(r, 1)
		assert_true(ts.size() <= 1, "max 1 trait")


func test_roll_zero_possible() -> void:
	## 15% выкаток дают 0 черт — за 300 роллов должно встретиться.
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var zeros := 0
	for i in 300:
		if reg.roll_traits(r).is_empty():
			zeros += 1
	assert_true(zeros >= 1, "at least one zero roll in 300 (got %d)" % zeros)


# ==================== Кастомные черты ====================

func test_custom_trait_add() -> void:
	var t := _TraitDef.new()
	t.id = &"custom"
	t.display_name = "Кастом"
	t.rarity = _TraitDef.Rarity.RARE
	t.effect_type = &"inspiration"
	t.effect_value = -0.5
	reg.add(t)
	assert_true(reg.has(&"custom"), "added")
	var g: TraitDef = reg.get_trait(&"custom")
	assert_eq(g.effect_value, -0.5, "value kept")
	assert_eq(g.rarity, _TraitDef.Rarity.RARE, "rarity kept")


func test_custom_trait_replaces_default() -> void:
	var t := _TraitDef.new()
	t.id = &"sleepy"
	t.effect_type = &"rest"
	t.effect_value = 0.5
	reg.add(t)
	assert_eq(reg.all().size(), 15, "no growth on replace")
	var g: TraitDef = reg.get_trait(&"sleepy")
	assert_eq(g.effect_value, 0.5, "replaced value")


# ==================== СЕРИАЛИЗАЦИЯ ====================

func test_trait_serialize_roundtrip_single() -> void:
	var t: TraitDef = reg.get_trait(&"sleepy")
	var d := t.to_dict()
	var t2 := _TraitDef.from_dict(d)
	assert_eq(t2.id, t.id, "id")
	assert_eq(t2.display_name, t.display_name, "name")
	assert_eq(t2.effect_type, t.effect_type, "effect type")
	assert_eq(t2.effect_value, t.effect_value, "effect value")
	assert_eq(t2.rarity, t.rarity, "rarity")
	assert_eq(t2.tags, t.tags, "tags")
	assert_eq(t2.modifier_for(t.effect_type), t.effect_value, "modifier")


func test_trait_serialize_roundtrip_multi_effect() -> void:
	var t: TraitDef = reg.get_trait(&"restless")
	var d := t.to_dict()
	var t2 := _TraitDef.from_dict(d)
	assert_eq(t2.modifier_for(&"rest"), -0.05, "rest effect")
	assert_eq(t2.modifier_for(&"social"), 0.10, "social effect")
	assert_eq(t2.modifier_for(&"inspiration"), 0.0, "inspiration unaffected")
