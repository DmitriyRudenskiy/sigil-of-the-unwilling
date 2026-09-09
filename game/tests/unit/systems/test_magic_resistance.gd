extends GdUnitTestSuite

const _SpellCaster = preload("res://scripts/systems/SpellCaster.gd")
const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _SE = preload("res://scripts/data/StatusEffects.gd")

var _rng := TestFactories.seeded(9348)
var _units: Node

func before_test() -> void:
	_units = Services.resolve(&"units")
	_rng.seed = 42


func test_undead_immunity_to_bless() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"bless", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_undead_immunity_to_cure() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"cure", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_undead_immunity_to_curse() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_undead_immunity_to_slow() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"slow", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_dragon_low_level_immunity() -> void:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_dragon_high_level_spell() -> void:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"armageddon", unit, {"spell_power": 10}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")


func test_golem_mind_immunity() -> void:
	var unit := _make_unit("stone_golem")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("immune")


func test_dwarf_resistance_calc() -> void:
	var unit := _make_unit("dwarf")
	var caster_bonus := {"spell_power": 5}
	var target_bonus := {"knowledge": 5}  
	var resist := _SpellCaster._calc_resistance(unit, target_bonus)
	assert_bool(resist >= 0.5).is_true()


func test_normal_damage_spell() -> void:
	var unit := _make_unit("skeleton")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 10}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")
	assert_bool(int(result.get("damage", 0)) > 0).is_true()


func test_resistance_reduction() -> void:
	var unit := _make_unit("skeleton")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 100}, {"knowledge": 10}, _rng)
	assert_that(result.get("result")).is_equal("success")


func test_spell_not_found() -> void:
	var result := _SpellCaster.cast(&"nonexistent_spell", null, {}, {}, _rng)
	assert_that(result.get("result")).is_equal("not_found")


func test_status_application() -> void:
	var unit := _make_unit("skeleton")
	if unit == null:
		return
	var result := _SpellCaster.cast(&"haste", unit, {"spell_power": 5}, {}, _rng)
	assert_that(result.get("result")).is_equal("success")
	assert_that(unit.statuses.get(_SE.Effect.HASTE, 0)).is_equal(3)


func _make_unit(key: String) -> BattleState.BattleUnit:
	var stack = _units.make_fixed_stack(key, 10)
	if stack == null:
		stack = _units.make_fixed_stack("skeleton", 10)
	if stack == null:
		return null
	var unit := _BattleState.BattleUnit.new(stack)
	return unit
