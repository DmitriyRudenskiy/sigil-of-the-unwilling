extends BaseTest



func test_debuff_classification() -> void:
	var debuffs := [StatusEffects.Effect.SLOW, StatusEffects.Effect.CURSE,
		StatusEffects.Effect.WEAKNESS, StatusEffects.Effect.MISFORTUNE,
		StatusEffects.Effect.PETRIFIED, StatusEffects.Effect.BLIND]
	var buffs := [StatusEffects.Effect.HASTE, StatusEffects.Effect.BLESS,
		StatusEffects.Effect.SHIELD, StatusEffects.Effect.STONESKIN,
		StatusEffects.Effect.BLOODLUST, StatusEffects.Effect.PRECISION,
		StatusEffects.Effect.WIND_WALL]

	for d in debuffs:
		assert_bool(StatusEffects.is_debuff(d)).is_true()
	for status in buffs:
		assert_bool(StatusEffects.is_debuff(status)).is_false()

func test_stun_classification() -> void:
	assert_bool(StatusEffects.is_stun(StatusEffects.Effect.PETRIFIED)).is_true()
	assert_bool(StatusEffects.is_stun(StatusEffects.Effect.BLIND)).is_true()
	assert_bool(StatusEffects.is_stun(StatusEffects.Effect.SLOW)).is_false()

func test_add_status() -> void:
	var unit := TestFactories.make_battle_unit()
	unit.add_status(StatusEffects.Effect.HASTE, 3)
	assert_that(unit.statuses[StatusEffects.Effect.HASTE]).is_equal(3)

func test_clear_debuffs() -> void:
	var unit := TestFactories.make_battle_unit()
	unit.add_status(StatusEffects.Effect.HASTE, 3)
	unit.add_status(StatusEffects.Effect.CURSE, 2)
	unit.add_status(StatusEffects.Effect.BLESS, 1)
	unit.clear_debuffs()
	assert_bool(unit.statuses.has(StatusEffects.Effect.CURSE)).is_false()
	assert_bool(unit.statuses.has(StatusEffects.Effect.HASTE)).is_true()
	assert_bool(unit.statuses.has(StatusEffects.Effect.BLESS)).is_true()

func test_is_stunned() -> void:
	var unit := TestFactories.make_battle_unit()
	assert_bool(unit.is_stunned()).is_false()
	unit.add_status(StatusEffects.Effect.PETRIFIED, 1)
	assert_bool(unit.is_stunned()).is_true()

func test_status_duration_tick() -> void:
	var unit := TestFactories.make_battle_unit()
	unit.add_status(StatusEffects.Effect.SLOW, 3)
	unit.statuses[StatusEffects.Effect.SLOW] -= 1
	assert_that(unit.statuses[StatusEffects.Effect.SLOW]).is_equal(2)
	unit.statuses[StatusEffects.Effect.SLOW] -= 1
	unit.statuses[StatusEffects.Effect.SLOW] -= 1
	var to_remove: Array = []
	for eff in unit.statuses.keys():
		if unit.statuses[eff] <= 0:
			to_remove.append(eff)
	for eff in to_remove:
		unit.statuses.erase(eff)
	assert_bool(unit.statuses.has(StatusEffects.Effect.SLOW)).is_false()

func test_name_lookup() -> void:

	# get_name() is shadowed by native GDScript.get_name() in static-via-class calls.
	var name := StatusEffects.new().get_name(StatusEffects.Effect.SLOW)
	assert_bool(name is String and name != "").is_true()

