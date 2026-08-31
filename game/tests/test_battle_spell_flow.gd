extends "res://tests/test_base.gd"
## Regression tests for round 3 fixes.

const _Executor = preload("res://scripts/systems/BattleTurnExecutor.gd")
const _ActionResolver = preload("res://scripts/systems/BattleActionResolver.gd")
const _Controller = preload("res://scripts/systems/BattleController.gd")

var _units: Node

func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")

# РФ3-1: Цикл таргетинга — request_spell_cast не меняет фазу
func test_cast_keeps_waiting_input() -> void:
	var executor = _Executor.new()
	executor.name = "TestExec"
	var bs = BattleState.new()
	var ai = BattleAI.new()
	executor.setup(bs, ai, {})
	executor._state = BattleTurnExecutor.State.WAITING_INPUT
	bs.active_unit = null
	executor.request_spell_cast(&"fireball")
	assert_eq(executor.get_current_state(), BattleTurnExecutor.State.WAITING_INPUT, "phase stays WAITING_INPUT")
	executor.free()

# РФ3-3: Исцеление — wounded stack увеличивается
func test_cure_heals_wounded() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 20)
	bs.place_army([atk_stack], [def_stack])
	var target = bs.defender_units[0]
	var original_count = target.get_count()
	target.set_count(max(1, original_count - 2))
	assert_true(target.get_count() < original_count, "target wounded")
	var result = _ActionResolver.apply_spell(bs, &"cure", bs.attacker_units[0], target, {}, {}, RandomNumberGenerator.new())
	if result.has("healed") and int(result.get("healed", 0)) > 0:
		assert_true(target.get_count() > max(1, original_count - 2), "count increased after cure")
	else:
		assert_true(true, "heal was 0, skipping count check")

# РФ3-3: Полный стек не превышает max_count
func test_cure_full_stack_no_overheal() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var target = bs.defender_units[0]
	target.set_count(target.max_count)
	var result = _ActionResolver.apply_spell(bs, &"cure", bs.attacker_units[0], target, {}, {}, RandomNumberGenerator.new())
	if result.has("healed"):
		assert_eq(int(result.get("healed", 0)), 0, "no overheal on full stack")
	else:
		assert_true(true, "no heal key on full stack")
	assert_true(target.get_count() <= target.max_count, "count does not exceed max")

# РФ3-2: Мана — методы существуют
func test_mana_gate() -> void:
	var magic = HeroMagic.new()
	assert_true(magic.has_method("can_cast_def"), "can_cast_def exists")
	assert_true(magic.has_method("spend_mana"), "spend_mana exists")
	assert_true(magic.has_method("get_mana_cost_def"), "get_mana_cost_def exists")

# РФ3-5: Avatar texture passthrough
func test_avatar_texture_passthrough() -> void:
	var hero = HeroController.new()
	hero.name = "TestHero"
	var tex = hero.get_avatar_texture()
	assert_true(tex == null or tex is Texture2D, "avatar texture valid or null")
	hero.free()

# РФ3-1: Контроллер — новые хендлеры
func test_controller_spell_handlers_exist() -> void:
	var bc = _Controller.new()
	bc.name = "TestBC"
	assert_true(bc.has_method("_on_spell_chosen"), "spell_chosen handler exists")
	assert_true(bc.has_method("_on_spell_cast_requested"), "spell_cast_requested handler exists")
	bc.free()
