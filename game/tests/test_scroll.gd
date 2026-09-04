extends "res://tests/gut_base.gd"

const _HeroMagic = preload("res://scripts/entities/HeroMagic.gd")
const _ScrollRules = preload("res://scripts/data/ScrollRules.gd")

func test_pickup_learn() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var before = m.spellbook.size()
	_ScrollRules.apply_pickup(m, "fireball")
	assert_true(m.knows("fireball"), "learned on pickup")
	assert_eq(m.spellbook.size(), before + 1, "spellbook grew")

func test_pickup_no_dup() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var before = m.spellbook.size()
	_ScrollRules.apply_pickup(m, "magic_arrow")
	assert_eq(m.spellbook.size(), before, "no dup on known")

func test_can_cast_scroll() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "air", "level": 1, "tags": []}
	assert_true(_ScrollRules.can_cast_in_battle(m, spell, 1), "can cast with scroll")
	assert_false(_ScrollRules.can_cast_in_battle(m, spell, 0), "no scroll left")
