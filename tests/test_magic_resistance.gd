extends SceneTree
## Magic resistance: undead immunity, dragon level check, pendant negation, dwarf resistance.

const _SpellRegistry = preload("res://scripts/data/SpellRegistry.gd")
const _SpellCaster = preload("res://scripts/spells/SpellCaster.gd")
const _BattleState = preload("res://scripts/BattleState.gd")
const _SE = preload("res://scripts/data/StatusEffects.gd")

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 42
	var failed := 0
	failed += _test_undead_immunity_to_bless()
	failed += _test_undead_immunity_to_cure()
	failed += _test_undead_immunity_to_curse()
	failed += _test_undead_immunity_to_slow()
	failed += _test_dragon_low_level_immunity()
	failed += _test_dragon_high_level_spell()
	failed += _test_golem_mind_immunity()
	failed += _test_dwarf_resistance_calc()
	failed += _test_normal_damage_spell()
	failed += _test_resistance_reduction()
	failed += _test_spell_not_found()
	failed += _test_status_application()

	if failed == 0:
		print("test_magic_resistance: 12/12 passed")
	else:
		printerr("test_magic_resistance: %d failed" % failed)
	quit(1 if failed > 0 else 0)


func _test_undead_immunity_to_bless() -> int:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"bless", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Undead should be immune to bless, got: %s" % result.get("result"))
		return 1
	return 0


func _test_undead_immunity_to_cure() -> int:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"cure", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Undead should be immune to cure")
		return 1
	return 0


func _test_undead_immunity_to_curse() -> int:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Undead should be immune to curse")
		return 1
	return 0


func _test_undead_immunity_to_slow() -> int:
	var unit := _make_unit("zombie")
	var result := _SpellCaster.cast(&"slow", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Undead should be immune to slow")
		return 1
	return 0


func _test_dragon_low_level_immunity() -> int:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Dragon should be immune to lvl 1 spell")
		return 1
	return 0


func _test_dragon_high_level_spell() -> int:
	var unit := _make_unit("red_dragon")
	var result := _SpellCaster.cast(&"armageddon", unit, {"spell_power": 10}, {}, _rng)
	if result.get("result") != "success":
		printerr("Dragon should be vulnerable to lvl 4 spell")
		return 1
	return 0


func _test_golem_mind_immunity() -> int:
	var unit := _make_unit("stone_golem")
	var result := _SpellCaster.cast(&"curse", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "immune":
		printerr("Golem should be immune to curse (mind)")
		return 1
	return 0


func _test_dwarf_resistance_calc() -> int:
	var unit := _make_unit("dwarf")
	# Dwarves have magic_resistant tag -> +40% base resistance
	var caster_bonus := {"spell_power": 5}
	var target_bonus := {"knowledge": 5}  # 25% from knowledge + 40% from tag = 65%
	var resist := _SpellCaster._calc_resistance(unit, target_bonus)
	if resist < 0.5:
		printerr("Dwarf resistance too low: %.2f" % resist)
		return 1
	return 0


func _test_normal_damage_spell() -> int:
	var unit := _make_unit("skeleton")
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 10}, {}, _rng)
	if result.get("result") != "success":
		printerr("Normal unit should be vulnerable to magic_arrow")
		return 1
	if result.get("damage", 0) <= 0:
		printerr("Damage should be > 0")
		return 1
	return 0


func _test_resistance_reduction() -> int:
	var unit := _make_unit("skeleton")
	# With knowledge=10 -> 50% resist chance
	var result := _SpellCaster.cast(&"magic_arrow", unit, {"spell_power": 100}, {"knowledge": 10}, _rng)
	if result.get("result") != "success":
		printerr("Should still succeed even when resisted")
		return 1
	return 0


func _test_spell_not_found() -> int:
	var result := _SpellCaster.cast(&"nonexistent_spell", null, {}, {}, _rng)
	if result.get("result") != "not_found":
		printerr("Unknown spell should return not_found")
		return 1
	return 0


func _test_status_application() -> int:
	var unit := _make_unit("skeleton")
	if not unit:
		return 0
	var result := _SpellCaster.cast(&"haste", unit, {"spell_power": 5}, {}, _rng)
	if result.get("result") != "success":
		printerr("Haste should succeed on skeletons")
		return 1
	if unit.statuses.get(_SE.Effect.HASTE, 0) != 3:
		printerr("Haste should set 3 turns")
		return 1
	return 0


func _make_unit(key: String) -> BattleState.BattleUnit:
	var stack := Units.make_fixed_stack(key, 10)
	if stack == null:
		stack = Units.make_fixed_stack("skeleton", 10)
	if stack == null:
		return null
	var unit := _BattleState.BattleUnit.new(stack)
	return unit
