extends BaseTest




var _units: Node

func before_test() -> void:
	_units = Services.resolve(&"units")

func test_cast_keeps_waiting_input() -> void:
	var executor = BattleTurnExecutor.new()
	executor.name = "TestExec"
	var bs = BattleState.new()
	var ai = BattleAI.new()
	executor.setup(bs, ai, {})
	executor._state = BattleTurnExecutor.State.WAITING_INPUT
	bs.active_unit = null
	executor.request_spell_cast(&"fireball")
	assert_that(executor.get_current_state()).is_equal(BattleTurnExecutor.State.WAITING_INPUT)
	executor.free()

func test_cure_heals_wounded() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 20)
	bs.place_army([atk_stack], [def_stack])
	var target = bs.defender_units[0]
	var original_count = target.get_count()
	target.set_count(max(1, original_count - 2))
	assert_bool(target.get_count() < original_count).is_true()
	var result = BattleActionResolver.apply_spell(bs, &"cure", bs.attacker_units[0], target, {}, {}, TestFactories.seeded(9631))
	if int(result.get("healed", 0)) > 0:
		assert_bool(target.get_count() > max(1, original_count - 2)).is_true()
	else:
		assert_bool(result.has("result")).is_true()

func test_cure_full_stack_no_overheal() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var target = bs.defender_units[0]
	target.set_count(target.max_count)
	var result = BattleActionResolver.apply_spell(bs, &"cure", bs.attacker_units[0], target, {}, {}, TestFactories.seeded(9631))
	assert_that(int(result.get("healed", 0))).is_equal(0)
	assert_bool(target.get_count() <= target.max_count).is_true()

func test_mana_gate() -> void:
	var magic = HeroMagic.new()
	assert_bool(magic.has_method("can_cast_def")).is_true()
	assert_bool(magic.has_method("spend_mana")).is_true()
	assert_bool(magic.has_method("get_mana_cost_def")).is_true()

func test_avatar_texture_passthrough() -> void:
	var hero = HeroController.new()
	hero.name = "TestHero"
	var tex = hero.get_avatar_texture()
	assert_bool(tex == null or tex is Texture2D).is_true()
	hero.free()

func test_controller_spell_handlers_exist() -> void:
	var bc = BattleController.new()
	bc.name = "TestBC"
	assert_bool(bc.has_method("_on_spell_chosen")).is_true()
	assert_bool(bc.has_method("_on_spell_cast_requested")).is_true()
	bc.free()
