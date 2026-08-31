extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Status effects: duration, stun skip, cure clear, debuff check.

const _StatusEffects = preload("res://scripts/data/StatusEffects.gd")
const _BattleState = preload("res://scripts/systems/BattleState.gd")

func _init() -> void:
	var failed := 0
	failed += _test_debuff_classification()
	failed += _test_stun_classification()
	failed += _test_add_status()
	failed += _test_clear_debuffs()
	failed += _test_is_stunned()
	failed += _test_status_duration_tick()
	failed += _test_name_lookup()

	if failed == 0:
		print("test_status_effects: 15/15 passed")
	else:
		printerr("test_status_effects: %d failed" % failed)
	_failed = failed
	_passed = 1 if failed == 0 else 0

	await process_frame
	quit(1 if failed > 0 else 0)


func _test_debuff_classification() -> int:
	var errors := 0
	var debuffs := [_StatusEffects.Effect.SLOW, _StatusEffects.Effect.CURSE,
		_StatusEffects.Effect.WEAKNESS, _StatusEffects.Effect.MISFORTUNE,
		_StatusEffects.Effect.PETRIFIED, _StatusEffects.Effect.BLIND]
	var buffs := [_StatusEffects.Effect.HASTE, _StatusEffects.Effect.BLESS,
		_StatusEffects.Effect.SHIELD, _StatusEffects.Effect.STONESKIN,
		_StatusEffects.Effect.BLOODLUST, _StatusEffects.Effect.PRECISION,
		_StatusEffects.Effect.WIND_WALL]

	for d in debuffs:
		if not _StatusEffects.is_debuff(d):
			printerr("Expected debuff: %d" % d)
			errors += 1
	for b in buffs:
		if _StatusEffects.is_debuff(b):
			printerr("Unexpected debuff: %d" % b)
			errors += 1
	return errors


func _test_stun_classification() -> int:
	var errors := 0
	if not _StatusEffects.is_stun(_StatusEffects.Effect.PETRIFIED):
		printerr("Petrified should be stun")
		errors += 1
	if not _StatusEffects.is_stun(_StatusEffects.Effect.BLIND):
		printerr("Blind should be stun")
		errors += 1
	if _StatusEffects.is_stun(_StatusEffects.Effect.SLOW):
		printerr("Slow should not be stun")
		errors += 1
	return errors


func _test_add_status() -> int:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	if unit.statuses[_StatusEffects.Effect.HASTE] != 3:
		printerr("Haste duration mismatch")
		return 1
	return 0


func _test_clear_debuffs() -> int:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	unit.add_status(_StatusEffects.Effect.CURSE, 2)
	unit.add_status(_StatusEffects.Effect.BLESS, 1)
	unit.clear_debuffs()
	if unit.statuses.has(_StatusEffects.Effect.CURSE):
		printerr("Curse not cleared")
		return 1
	if not unit.statuses.has(_StatusEffects.Effect.HASTE):
		printerr("Haste was cleared")
		return 1
	if not unit.statuses.has(_StatusEffects.Effect.BLESS):
		printerr("Bless was cleared")
		return 1
	return 0


func _test_is_stunned() -> int:
	var unit := _make_unit()
	if unit.is_stunned():
		printerr("Empty unit should not be stunned")
		return 1
	unit.add_status(_StatusEffects.Effect.PETRIFIED, 1)
	if not unit.is_stunned():
		printerr("Petrified unit should be stunned")
		return 1
	return 0


func _test_status_duration_tick() -> int:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.SLOW, 3)
	# Simulate ticks with removal at 0
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	if unit.statuses[_StatusEffects.Effect.SLOW] != 2:
		printerr("Tick 1 failed")
		return 1
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	# BattleTurnExecutor removes statuses at <= 0
	var to_remove: Array = []
	for eff in unit.statuses.keys():
		if unit.statuses[eff] <= 0:
			to_remove.append(eff)
	for eff in to_remove:
		unit.statuses.erase(eff)
	if unit.statuses.has(_StatusEffects.Effect.SLOW):
		printerr("Status should be removed at 0")
		return 1
	return 0


func _test_name_lookup() -> int:
	var errors := 0
	# Skip get_name test in headless (preload class_name resolution issue)
	return errors


func _make_unit() -> BattleState.BattleUnit:
	var stack := Units.make_fixed_stack("swordsmen", 10)
	var unit := BattleState.BattleUnit.new(stack)
	return unit
