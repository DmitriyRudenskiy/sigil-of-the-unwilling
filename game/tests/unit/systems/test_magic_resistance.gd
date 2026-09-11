extends BaseTest




var _rng := TestFactories.seeded(9348)

func before_test() -> void:
	_rng.seed = 42

func test_undead_immunity_to_bless() -> void:
	var unit := TestFactories.make_battle_unit("zombie")
	var result := SpellCaster.cast(&"bless", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_undead_immunity_to_cure() -> void:
	var unit := TestFactories.make_battle_unit("zombie")
	var result := SpellCaster.cast(&"cure", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_undead_immunity_to_curse() -> void:
	var unit := TestFactories.make_battle_unit("zombie")
	var result := SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_undead_immunity_to_slow() -> void:
	var unit := TestFactories.make_battle_unit("zombie")
	var result := SpellCaster.cast(&"slow", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_dragon_low_level_immunity() -> void:
	var unit := TestFactories.make_battle_unit("red_dragon")
	var result := SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_dragon_high_level_spell() -> void:
	var unit := TestFactories.make_battle_unit("red_dragon")
	var result := SpellCaster.cast(&"armageddon", unit, {"spell_power": 10}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")

func test_golem_mind_immunity() -> void:
	var unit := TestFactories.make_battle_unit("stone_golem")
	var result := SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")

func test_dwarf_resistance_calc() -> void:
	var unit := TestFactories.make_battle_unit("dwarf")
	var caster_bonus := {"spell_power": 5}
	var target_bonus := {"knowledge": 5}
	var resist := SpellCaster._calc_resistance(unit, target_bonus)
	assert_bool(resist >= 0.5).is_true()

func test_normal_damage_spell() -> void:
	var unit := TestFactories.make_battle_unit("skeleton")
	var result := SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 10}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")
	assert_bool(int(result.get("damage", 0)) > 0).is_true()

func test_resistance_reduction() -> void:
	var unit := TestFactories.make_battle_unit("skeleton")
	var result := SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 100}, {"knowledge": 10}, _rng)
	assert_that(result.get("result")).is_equal("success")

func test_spell_not_found() -> void:
	var result := SpellCaster.cast(&"nonexistent_spell", null, {}, {}, _rng)
	assert_that(result.get("result")).is_equal("not_found")

func test_status_application() -> void:
	var unit := TestFactories.make_battle_unit("skeleton")
	if unit == null:
		return
	var result := SpellCaster.cast(&"haste", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")
	assert_that(unit.statuses.get(StatusEffects.Effect.HASTE, 0)).is_equal(3)

