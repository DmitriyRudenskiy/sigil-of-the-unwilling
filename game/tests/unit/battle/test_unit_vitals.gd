extends BaseTest

## battle-unit-vitals: мана персонажа из Intelligence, уровень персонажа и то,
## из какого пула оплачивается заклинание. Правило владельца (2026-10-18): мана
## есть у того, у есть Intelligence — то есть у юнита с DnDCombatantProfile;
## обычный стек маны не имеет вовсе (ни пула, ни полосы в интерфейсе).

const INT_SCORE_16 := 16
const INT_SCORE_10 := 10
const INT_SCORE_8 := 8
const INT_SCORE_3 := 3


## Профиль с одним заданным Intelligence (остальные — значения по умолчанию).
func _profile(int_score: int) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new("vitals", "Vitals Test")
	p.abilities.set_score(DNDAbilityScores.Ability.INT, int_score)
	return p


## Персонаж: стек + профиль (мана есть).
func _character(int_score: int = INT_SCORE_10) -> BattleState.BattleUnit:
	var stack := UnitStack.new(UnitStats.new("vitals_hero", "Vitals Hero", 1, 1, 10, 5, 0, []), 1)
	var unit := BattleState.BattleUnit.new(stack)
	unit.dnd_profile = _profile(int_score)
	return unit


## Чистый стек без профиля (маны нет).
func _stack_unit() -> BattleState.BattleUnit:
	return BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new("vitals_gob", "Vitals Goblin", 1, 1, 1, 4, 0, []), 5)
	)


## Заклинание нужной школы/уровня/цены (реестр для этих тестов не нужен).
func _spell(school: String = "air", level: int = 1, cost: int = 5) -> SpellRegistry.SpellDef:
	var s := SpellRegistry.SpellDef.new()
	s.school = school
	s.level = level
	s.base_mana = cost
	return s


## Герой с манами по умолчанию: 20/20, школа воздуха уровня 1.
func _magic() -> HeroMagic:
	var m := HeroMagic.new()
	m.init_defaults()
	return m


func test_mana_pool_scales_with_intelligence() -> void:
	assert_int(_profile(INT_SCORE_16).get_mana_max()).is_equal(25)
	assert_int(_profile(INT_SCORE_10).get_mana_max()).is_equal(10)


func test_mana_pool_never_below_one_spell() -> void:
	assert_int(_profile(INT_SCORE_8).get_mana_max()).is_equal(5)
	assert_int(_profile(INT_SCORE_3).get_mana_max()).is_equal(5)


func test_plain_stack_has_no_mana_at_all() -> void:
	var unit := _stack_unit()
	assert_bool(unit.has_mana()).is_false()
	assert_int(unit.get_mana()).is_equal(0)
	assert_int(unit.get_mana_max()).is_equal(0)
	assert_bool(unit.spend_mana(1)).is_false()


func test_character_pool_spend_and_refund() -> void:
	var unit := _character(INT_SCORE_10)
	assert_int(unit.get_mana_max()).is_equal(10)
	assert_bool(unit.spend_mana(5)).is_true()
	assert_int(unit.get_mana()).is_equal(5)
	assert_bool(unit.spend_mana(6)).is_false()
	assert_int(unit.get_mana()).is_equal(5)
	unit.refund_mana(5)
	assert_int(unit.get_mana()).is_equal(10)
	unit.refund_mana(100)
	assert_int(unit.get_mana()).is_equal(10)


func test_spell_is_charged_to_the_character_pool_not_the_hero() -> void:
	var magic := _magic()
	var unit := _character(INT_SCORE_10)
	var charged: int = BattleActionResolver.pay_spell_mana(unit, magic, _spell())
	assert_int(charged).is_equal(5)
	assert_int(unit.get_mana()).is_equal(5)
	assert_int(magic.mana_current).is_equal(20)


func test_stack_spell_is_charged_to_hero_mana() -> void:
	var magic := _magic()
	var unit := _stack_unit()
	var charged: int = BattleActionResolver.pay_spell_mana(unit, magic, _spell())
	assert_int(charged).is_equal(5)
	assert_int(magic.mana_current).is_equal(15)
	assert_int(unit.get_mana()).is_equal(0)


func test_character_cast_of_unknown_school_is_denied() -> void:
	var magic := _magic()
	var unit := _character(INT_SCORE_16)
	var charged: int = BattleActionResolver.pay_spell_mana(unit, magic, _spell("fire"))
	assert_int(charged).is_equal(-1)
	assert_int(unit.get_mana()).is_equal(25)
	assert_int(magic.mana_current).is_equal(20)


func test_cast_is_denied_when_the_pool_is_empty() -> void:
	var magic := _magic()
	var unit := _character(INT_SCORE_8)
	assert_bool(unit.spend_mana(5)).is_true()
	var charged: int = BattleActionResolver.pay_spell_mana(unit, magic, _spell())
	assert_int(charged).is_equal(-1)
	assert_int(unit.get_mana()).is_equal(0)
	assert_int(magic.mana_current).is_equal(20)


func test_refund_goes_back_to_the_pool_that_paid() -> void:
	var unit := _character(INT_SCORE_10)
	BattleActionResolver.pay_spell_mana(unit, _magic(), _spell())
	assert_int(unit.get_mana()).is_equal(5)
	unit.refund_mana(5)
	assert_int(unit.get_mana()).is_equal(10)


func test_level_comes_from_the_definition() -> void:
	var def := DnDBattleFactory.DnDCharacterDef.new("lvl", "Levelled")
	def.level = 7
	assert_int(DnDBattleFactory.build_profile(def).level).is_equal(7)


func test_level_defaults_to_one() -> void:
	var def := DnDBattleFactory.DnDCharacterDef.new("lvl", "Levelled")
	assert_int(DnDBattleFactory.build_profile(def).level).is_equal(1)


func test_level_survives_serialization() -> void:
	var p := _profile(INT_SCORE_10)
	p.level = 12
	var restored := DnDCombatantProfile.from_dict(p.to_dict())
	assert_int(restored.level).is_equal(12)


func test_mana_current_survives_serialization() -> void:
	var p := _profile(INT_SCORE_16)
	p.spend_mana(5)
	var restored := DnDCombatantProfile.from_dict(p.to_dict())
	assert_int(restored.get_mana()).is_equal(20)


func test_saved_profile_without_mana_draws_it_from_intelligence() -> void:
	var data := _profile(INT_SCORE_16).to_dict()
	data.erase("mana_current")
	assert_int(DnDCombatantProfile.from_dict(data).get_mana()).is_equal(25)


func test_level_never_touches_combat_numbers() -> void:
	var plain := _profile(INT_SCORE_16)
	var levelled := _profile(INT_SCORE_16)
	levelled.level = 20
	assert_int(levelled.get_total_ac()).is_equal(plain.get_total_ac())
	assert_int(levelled.get_attack_bonus()).is_equal(plain.get_attack_bonus())
	assert_int(levelled.get_damage_bonus()).is_equal(plain.get_damage_bonus())
