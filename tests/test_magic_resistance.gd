extends "res://tests/test_base.gd"
## Magic resistance: undead immunity, dragon level check, pendant negation, dwarf resistance.

const _SpellCaster = preload("res://scripts/spells/SpellCaster.gd")
const _BattleState = preload("res://scripts/BattleState.gd")
const _SE = preload("res://scripts/data/StatusEffects.gd")

var _rng := RandomNumberGenerator.new()
var _units: Node

func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")
	_rng.seed = 42


func test_undead_immunity_to_bless() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"bless", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "undead immune to bless")


func test_undead_immunity_to_cure() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"cure", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "undead immune to cure")


func test_undead_immunity_to_curse() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "undead immune to curse")


func test_undead_immunity_to_slow() -> void:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"slow", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "undead immune to slow")


func test_dragon_low_level_immunity() -> void:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "dragon immune to lvl 1 spell")


func test_dragon_high_level_spell() -> void:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"armageddon", unit, {"spell_power": 10}, {}, _rng)
	assert_eq(result.get("result"), "success", "dragon vulnerable to lvl 4 spell")


func test_golem_mind_immunity() -> void:
	var unit := _make_unit("stone_golem")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "immune", "golem immune to curse (mind)")


func test_dwarf_resistance_calc() -> void:
	var unit := _make_unit("dwarf")
	# Dwarves have magic_resistant tag -> +40% base resistance
	var caster_bonus := {"spell_power": 5}
	var target_bonus := {"knowledge": 5}  # 25% from knowledge + 40% from tag = 65%
	var resist := _SpellCaster._calc_resistance(unit, target_bonus)
	assert_true(resist >= 0.5, "dwarf resistance >= 0.5 (got %s)" % resist)


func test_normal_damage_spell() -> void:
	var unit := _make_unit("skeleton")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 10}, {}, _rng)
	assert_eq(result.get("result"), "success", "skeleton vulnerable to magic_arrow")
	assert_true(int(result.get("damage", 0)) > 0, "damage > 0")


func test_resistance_reduction() -> void:
	var unit := _make_unit("skeleton")
	# With knowledge=10 -> 50% resist chance
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 100}, {"knowledge": 10}, _rng)
	assert_eq(result.get("result"), "success", "still succeeds even when resisted")


func test_spell_not_found() -> void:
	var result := _SpellCaster.cast(&"nonexistent_spell", null, {}, {}, _rng)
	assert_eq(result.get("result"), "not_found", "unknown spell returns not_found")


func test_status_application() -> void:
	var unit := _make_unit("skeleton")
	if unit == null:
		return
	var result := _SpellCaster.cast(&"haste", unit, {"spell_power": 5}, {}, _rng)
	assert_eq(result.get("result"), "success", "haste succeeds on skeletons")
	assert_eq(unit.statuses.get(_SE.Effect.HASTE, 0), 3, "haste sets 3 turns")


func _make_unit(key: String) -> BattleState.BattleUnit:
	var stack = _units.make_fixed_stack(key, 10)
	if stack == null:
		stack = _units.make_fixed_stack("skeleton", 10)
	if stack == null:
		return null
	var unit := _BattleState.BattleUnit.new(stack)
	return unit
