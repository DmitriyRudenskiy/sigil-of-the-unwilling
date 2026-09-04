extends "res://tests/gut_base.gd"

## Status effects: duration, stun skip, cure clear, debuff check.

const _StatusEffects = preload("res://scripts/data/StatusEffects.gd")
const _BattleState = preload("res://scripts/systems/BattleState.gd")


func test_debuff_classification() -> void:
	var debuffs := [_StatusEffects.Effect.SLOW, _StatusEffects.Effect.CURSE,
		_StatusEffects.Effect.WEAKNESS, _StatusEffects.Effect.MISFORTUNE,
		_StatusEffects.Effect.PETRIFIED, _StatusEffects.Effect.BLIND]
	var buffs := [_StatusEffects.Effect.HASTE, _StatusEffects.Effect.BLESS,
		_StatusEffects.Effect.SHIELD, _StatusEffects.Effect.STONESKIN,
		_StatusEffects.Effect.BLOODLUST, _StatusEffects.Effect.PRECISION,
		_StatusEffects.Effect.WIND_WALL]

	for d in debuffs:
		assert_true(_StatusEffects.is_debuff(d), "expected debuff: %d" % d)
	for b in buffs:
		assert_false(_StatusEffects.is_debuff(b), "unexpected debuff: %d" % b)


func test_stun_classification() -> void:
	assert_true(_StatusEffects.is_stun(_StatusEffects.Effect.PETRIFIED), "Petrified should be stun")
	assert_true(_StatusEffects.is_stun(_StatusEffects.Effect.BLIND), "Blind should be stun")
	assert_false(_StatusEffects.is_stun(_StatusEffects.Effect.SLOW), "Slow should not be stun")


func test_add_status() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	assert_eq(unit.statuses[_StatusEffects.Effect.HASTE], 3, "Haste duration mismatch")


func test_clear_debuffs() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	unit.add_status(_StatusEffects.Effect.CURSE, 2)
	unit.add_status(_StatusEffects.Effect.BLESS, 1)
	unit.clear_debuffs()
	assert_false(unit.statuses.has(_StatusEffects.Effect.CURSE), "Curse not cleared")
	assert_true(unit.statuses.has(_StatusEffects.Effect.HASTE), "Haste was cleared")
	assert_true(unit.statuses.has(_StatusEffects.Effect.BLESS), "Bless was cleared")


func test_is_stunned() -> void:
	var unit := _make_unit()
	assert_false(unit.is_stunned(), "Empty unit should not be stunned")
	unit.add_status(_StatusEffects.Effect.PETRIFIED, 1)
	assert_true(unit.is_stunned(), "Petrified unit should be stunned")


func test_status_duration_tick() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.SLOW, 3)
	# Simulate ticks with removal at 0
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	assert_eq(unit.statuses[_StatusEffects.Effect.SLOW], 2, "Tick 1 failed")
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	# BattleTurnExecutor removes statuses at <= 0
	var to_remove: Array = []
	for eff in unit.statuses.keys():
		if unit.statuses[eff] <= 0:
			to_remove.append(eff)
	for eff in to_remove:
		unit.statuses.erase(eff)
	assert_false(unit.statuses.has(_StatusEffects.Effect.SLOW), "Status should be removed at 0")


func test_name_lookup() -> void:
	# Static через preload в локальном скоупе: file-level const типизуется
	# как base RefCounted, и dispatch уезжает в Object.get_name().
	const SE := preload("res://scripts/data/StatusEffects.gd")
	var name := SE.get_name(SE.Effect.SLOW)
	assert_true(name is String and name != "", "get_name возвращает строку")


func _make_unit() -> BattleState.BattleUnit:
	var stack := Units.make_fixed_stack("swordsmen", 10)
	var unit := BattleState.BattleUnit.new(stack)
	return unit
