extends BaseTest



func test_pickup_learn() -> void:
	var m := HeroMagic.new()
	m.init_defaults()
	var before = m.spellbook.size()
	ScrollRules.apply_pickup(m, "fireball")
	assert_bool(m.knows("fireball")).is_true()
	assert_that(m.spellbook.size()).is_equal(before + 1)

func test_pickup_no_dup() -> void:
	var m := HeroMagic.new()
	m.init_defaults()
	var before = m.spellbook.size()
	ScrollRules.apply_pickup(m, "magic_arrow")
	assert_that(m.spellbook.size()).is_equal(before)

func test_can_cast_scroll() -> void:
	var m := HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "air", "level": 1, "tags": []}
	assert_bool(ScrollRules.can_cast_in_battle(m, spell, 1)).is_true()
	assert_bool(ScrollRules.can_cast_in_battle(m, spell, 0)).is_false()
