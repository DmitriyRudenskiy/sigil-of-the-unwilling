extends GdUnitTestSuite

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
		assert_bool(_StatusEffects.is_debuff(d)).is_true()
	for status in buffs:
		assert_bool(_StatusEffects.is_debuff(status)).is_false()

func test_stun_classification() -> void:
	assert_bool(_StatusEffects.is_stun(_StatusEffects.Effect.PETRIFIED)).is_true()
	assert_bool(_StatusEffects.is_stun(_StatusEffects.Effect.BLIND)).is_true()
	assert_bool(_StatusEffects.is_stun(_StatusEffects.Effect.SLOW)).is_false()

func test_add_status() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	assert_that(unit.statuses[_StatusEffects.Effect.HASTE]).is_equal(3)

func test_clear_debuffs() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.HASTE, 3)
	unit.add_status(_StatusEffects.Effect.CURSE, 2)
	unit.add_status(_StatusEffects.Effect.BLESS, 1)
	unit.clear_debuffs()
	assert_bool(unit.statuses.has(_StatusEffects.Effect.CURSE)).is_false()
	assert_bool(unit.statuses.has(_StatusEffects.Effect.HASTE)).is_true()
	assert_bool(unit.statuses.has(_StatusEffects.Effect.BLESS)).is_true()

func test_is_stunned() -> void:
	var unit := _make_unit()
	assert_bool(unit.is_stunned()).is_false()
	unit.add_status(_StatusEffects.Effect.PETRIFIED, 1)
	assert_bool(unit.is_stunned()).is_true()

func test_status_duration_tick() -> void:
	var unit := _make_unit()
	unit.add_status(_StatusEffects.Effect.SLOW, 3)
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	assert_that(unit.statuses[_StatusEffects.Effect.SLOW]).is_equal(2)
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	unit.statuses[_StatusEffects.Effect.SLOW] -= 1
	var to_remove: Array = []
	for eff in unit.statuses.keys():
		if unit.statuses[eff] <= 0:
			to_remove.append(eff)
	for eff in to_remove:
		unit.statuses.erase(eff)
	assert_bool(unit.statuses.has(_StatusEffects.Effect.SLOW)).is_false()

func test_name_lookup() -> void:
	const SE := preload("res://scripts/data/StatusEffects.gd")
	var name := SE.get_name(SE.Effect.SLOW)
	assert_bool(name is String and name != "").is_true()

func _make_unit() -> BattleState.BattleUnit:
	var stack := Units.make_fixed_stack("swordsmen", 10)
	var unit := BattleState.BattleUnit.new(stack)
	return unit
