extends "res://tests/test_base.gd"

const _HeroMagic = preload("res://scripts/hero/HeroMagic.gd")

func test_init_defaults() -> void:
	
	var m := _HeroMagic.new()
	m.init_defaults()
	assert_eq(m.mana_max, 20, "mana_max")
	assert_eq(m.mana_current, 20, "mana_current")
	assert_eq(m.schools.get("air", 0), 1, "air school")
	assert_true(m.knows("magic_arrow"), "knows magic_arrow")
	assert_true(m.knows("haste"), "knows haste")

func test_learn_forget() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	assert_true(m.learn("healing_bolt"), "learn")
	assert_true(m.knows("healing_bolt"), "knows after learn")
	assert_false(m.learn("healing_bolt"), "no dup")
	assert_true(m.forget("healing_bolt"), "forget")
	assert_false(m.knows("healing_bolt"), "forgotten")

func test_mana_cost_normal() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 5, "tags": []}
	assert_eq(m.get_mana_cost(spell), 5, "normal cost")

func test_mana_cost_anti_magic() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 5, "tags": ["anti_magic"]}
	assert_eq(m.get_mana_cost(spell), 7, "anti_magic +2")

func test_can_cast_success() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "air", "level": 1, "tags": []}
	assert_true(m.can_cast(spell), "can cast")

func test_can_cast_no_mana() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 2
	var spell := {"base_mana": 5, "school": "air", "level": 1, "tags": []}
	assert_false(m.can_cast(spell), "no mana")

func test_can_cast_no_school() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "fire", "level": 2, "tags": []}
	assert_false(m.can_cast(spell), "no school")

func test_spend_refund() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	assert_true(m.spend_mana(8), "spend")
	assert_eq(m.mana_current, 12, "after spend")
	m.refund_mana(4)
	assert_eq(m.mana_current, 16, "after refund")

func test_restore_full() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 5
	m.restore_full()
	assert_eq(m.mana_current, 20, "restored")

func test_tick_restore() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 18
	m.tick_restore(5)
	assert_eq(m.mana_current, 20, "capped")
