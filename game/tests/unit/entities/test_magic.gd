extends GdUnitTestSuite

const _HeroMagic = preload("res://scripts/entities/HeroMagic.gd")

func test_init_defaults() -> void:

	var m := _HeroMagic.new()
	m.init_defaults()
	assert_that(m.mana_max).is_equal(20)
	assert_that(m.mana_current).is_equal(20)
	assert_that(m.schools.get(SchoolType.ID.AIR, 0)).is_equal(1)
	assert_bool(m.knows("magic_arrow")).is_true()
	assert_bool(m.knows("haste")).is_true()

func test_learn_forget() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	assert_bool(m.learn("healing_bolt")).is_true()
	assert_bool(m.knows("healing_bolt")).is_true()
	assert_bool(m.learn("healing_bolt")).is_false()
	assert_bool(m.forget("healing_bolt")).is_true()
	assert_bool(m.knows("healing_bolt")).is_false()

func test_mana_cost_normal() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 5, "tags": []}
	assert_that(m.get_mana_cost(spell)).is_equal(5)

func test_mana_cost_anti_magic() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 5, "tags": ["anti_magic"]}
	assert_that(m.get_mana_cost(spell)).is_equal(7)

func test_can_cast_success() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "air", "level": 1, "tags": []}
	assert_bool(m.can_cast(spell)).is_true()

func test_can_cast_no_mana() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 2
	var spell := {"base_mana": 5, "school": "air", "level": 1, "tags": []}
	assert_bool(m.can_cast(spell)).is_false()

func test_can_cast_no_school() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	var spell := {"base_mana": 3, "school": "fire", "level": 2, "tags": []}
	assert_bool(m.can_cast(spell)).is_false()

func test_spend_refund() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	assert_bool(m.spend_mana(8)).is_true()
	assert_that(m.mana_current).is_equal(12)
	m.refund_mana(4)
	assert_that(m.mana_current).is_equal(16)

func test_restore_full() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 5
	m.restore_full()
	assert_that(m.mana_current).is_equal(20)

func test_tick_restore() -> void:
	var m := _HeroMagic.new()
	m.init_defaults()
	m.mana_current = 18
	m.tick_restore(5)
	assert_that(m.mana_current).is_equal(20)
