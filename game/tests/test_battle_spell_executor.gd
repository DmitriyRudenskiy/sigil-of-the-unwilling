extends GdUnitTestSuite

const _Executor = preload("res://scripts/systems/BattleTurnExecutor.gd")
const _Input = preload("res://scripts/systems/BattleInput.gd")
const _ActionResolver = preload("res://scripts/systems/BattleActionResolver.gd")
const _HeroMagic = preload("res://scripts/entities/HeroMagic.gd")
const _BAI = preload("res://scripts/systems/BattleAI.gd")

var _units: Node

func before_test() -> void:
	_units = Services.resolve(&"units")

func test_pending_action_spell_exists() -> void:
	var exec = _Executor.new()
	var val = exec.PendingAction.SPELL
	assert_that(val).is_equal(3)
	exec.free()

func test_cast_emits_spell_cast_executed() -> void:
	var state := _make_battle_state()
	var exec := _Executor.new()
	exec.name = "ExecCastOK"
	exec.setup(state, _BAI.new(), {})
	var caster: BattleState.BattleUnit = state.attacker_units[0]
	var target: BattleState.BattleUnit = state.defender_units[0]
	state.active_unit = caster

	var state_holder: Array = [false, {}]
	exec.spell_cast_executed.connect(func(_c, _t, r):
		state_holder[0] = true
		state_holder[1] = r
	)
	exec.on_spell_target_selected(&"magic_arrow", target)
	assert_bool(state_holder[0]).is_true()
	assert_that(state_holder[1].get("result")).is_equal("success")
	exec.free()

func test_cast_emits_spell_cast_failed() -> void:
	var state := _make_battle_state()
	var exec := _Executor.new()
	exec.name = "ExecCastFail"
	exec.setup(state, _BAI.new(), {})
	var caster: BattleState.BattleUnit = state.attacker_units[0]
	state.active_unit = caster

	var failed_holder: Array = [false]
	exec.spell_cast_failed.connect(func(_r):
		failed_holder[0] = true
	)
	exec.on_spell_target_selected(&"nonexistent_spell", caster)
	assert_bool(failed_holder[0]).is_true()
	exec.free()

func test_request_sacrifice_emits_and_finishes() -> void:
	var state := _make_battle_state()
	var exec := _Executor.new()
	exec.name = "ExecSacrifice"
	exec.setup(state, _BAI.new(), {})
	var atk: BattleState.BattleUnit = state.attacker_units[0]
	var def: BattleState.BattleUnit = state.defender_units[0]
	exec._state = _Executor.State.WAITING_INPUT
	state.active_unit = atk

	var holder: Array = [false, {}]
	exec.execute_sacrifice.connect(func(_a, _t, _c, r):
		holder[0] = true
		holder[1] = r
	)
	var storage := {&"gold": 100}
	var sacrifice := {"type": &"resource", "resource": &"gold", "amount": 40}
	exec.request_sacrifice(atk, sacrifice, def, storage)
	assert_bool(holder[0]).is_true()
	assert_that(holder[1].get("result")).is_equal("success")
	assert_that(exec._state).is_equal(_Executor.State.PLAYER_ANIMATING)
	assert_bool(def.is_alive()).is_false()
	assert_that(int(storage.get(&"gold", 0))).is_equal(60)
	exec.free()

func test_request_sacrifice_guard_when_idle() -> void:
	var state := _make_battle_state()
	var exec := _Executor.new()
	exec.name = "ExecSacrificeIdle"
	exec.setup(state, _BAI.new(), {})
	var atk: BattleState.BattleUnit = state.attacker_units[0]
	var def: BattleState.BattleUnit = state.defender_units[0]
	var fired := false
	exec.execute_sacrifice.connect(func(_a, _t, _c, _r):
		fired = true
	)
	var storage := {&"gold": 100}
	var sacrifice := {"type": &"resource", "resource": &"gold", "amount": 40}
	exec.request_sacrifice(atk, sacrifice, def, storage)
	assert_bool(fired).is_false()
	assert_bool(def.is_alive()).is_true()
	exec.free()

func _make_battle_state() -> BattleState:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	return state

func test_hero_magic_refund() -> void:
	var magic = _HeroMagic.new()
	magic.init_defaults()
	magic.spend_mana(10)
	assert_that(magic.mana_current).is_equal(10)
	magic.refund_mana(5)
	assert_that(magic.mana_current).is_equal(15)
	magic.refund_mana(10)
	assert_that(magic.mana_current).is_equal(20)

func test_clear_highlights_resets_pending_spell() -> void:
	var input = _Input.new()
	input._pending_spell_id = "fireball"
	input.highlight_move["a"] = 1
	input.highlight_attack["b"] = 1
	input._clear_highlights()
	assert_that(input._pending_spell_id).is_equal("")
	assert_that(input.highlight_move.size()).is_equal(0)
	assert_that(input.highlight_attack.size()).is_equal(0)
	input.free()

func test_spend_mana_insufficient() -> void:
	var magic = _HeroMagic.new()
	magic.init_defaults()
	var result = magic.spend_mana(999)
	assert_bool(result).is_false()
	assert_that(magic.mana_current).is_equal(20)

func test_resume_battle_pending_spell() -> void:
	var exec := _Executor.new()
	exec.name = "ExecResumeSpell"
	exec._pending_completion = _Executor.PendingAction.SPELL
	exec.resume_battle()
	assert_that(exec._pending_completion).is_equal(_Executor.PendingAction.NONE)
	assert_bool(exec.is_paused()).is_false()
	exec.free()

func test_spell_anim_paused_guard() -> void:
	var exec := _Executor.new()
	exec.name = "ExecSpellPaused"
	exec._paused = true
	exec.on_spell_anim_completed()
	assert_that(exec._pending_completion).is_equal(_Executor.PendingAction.SPELL)
	assert_that(exec._state).is_equal(_Executor.State.IDLE)
	exec.free()
