extends "res://tests/test_base.gd"
## Regression tests for round 5 executor + spell flow (РФ5-1, РФ5-3, РФ5-4).

const _Executor = preload("res://scripts/systems/BattleTurnExecutor.gd")
const _Input = preload("res://scripts/systems/BattleInput.gd")
const _ActionResolver = preload("res://scripts/systems/BattleActionResolver.gd")
const _HeroMagic = preload("res://scripts/entities/HeroMagic.gd")
const _BAI = preload("res://scripts/systems/BattleAI.gd")

var _units: Node

func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")

# РФ5-1: PendingAction.SPELL exists in enum
func test_pending_action_spell_exists() -> void:
	var exec = _Executor.new()
	var val = exec.PendingAction.SPELL
	assert_eq(val, 3, "SPELL action should be enum value 3")
	exec.free()

# РФ5-1: on_spell_target_selected emits spell_cast_executed on success
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
	assert_true(state_holder[0], "spell_cast_executed should fire on successful cast")
	assert_eq(state_holder[1].get("result"), "success", "result is success")
	exec.free()

# РФ5-1: on_spell_target_selected emits spell_cast_failed on failure
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
	assert_true(failed_holder[0], "spell_cast_failed should fire on invalid spell")
	exec.free()

# РФ4-2: request_sacrifice emits execute_sacrifice + transitions to animating.
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
	assert_true(holder[0], "execute_sacrifice should fire on successful sacrifice")
	assert_eq(holder[1].get("result"), "success", "result is success")
	assert_eq(exec._state, _Executor.State.PLAYER_ANIMATING, "transitions to animating")
	assert_false(def.is_alive(), "target finished off")
	assert_eq(int(storage.get(&"gold", 0)), 60, "resource deducted")
	exec.free()

# РФ4-2: request_sacrifice is a no-op when not waiting for input.
func test_request_sacrifice_guard_when_idle() -> void:
	var state := _make_battle_state()
	var exec := _Executor.new()
	exec.name = "ExecSacrificeIdle"
	exec.setup(state, _BAI.new(), {})
	var atk: BattleState.BattleUnit = state.attacker_units[0]
	var def: BattleState.BattleUnit = state.defender_units[0]
	# _state == IDLE, active_unit not set → should not fire.
	var fired := false
	exec.execute_sacrifice.connect(func(_a, _t, _c, _r):
		fired = true
	)
	var storage := {&"gold": 100}
	var sacrifice := {"type": &"resource", "resource": &"gold", "amount": 40}
	exec.request_sacrifice(atk, sacrifice, def, storage)
	assert_false(fired, "no signal when not WAITING_INPUT")
	assert_true(def.is_alive(), "target untouched when guard blocks")
	exec.free()

func _make_battle_state() -> BattleState:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	return state

# РФ5-3: refund_mana on HeroMagic
func test_hero_magic_refund() -> void:
	var magic = _HeroMagic.new()
	magic.init_defaults()
	magic.spend_mana(10)
	assert_eq(magic.mana_current, 10, "Mana should be 10 after spending 10")
	magic.refund_mana(5)
	assert_eq(magic.mana_current, 15, "Mana should be 15 after refunding 5")
	magic.refund_mana(10)
	assert_eq(magic.mana_current, 20, "Mana should cap at max after over-refund")

# РФ5-4: _clear_highlights resets _pending_spell_id
func test_clear_highlights_resets_pending_spell() -> void:
	var input = _Input.new()
	input._pending_spell_id = "fireball"
	input.highlight_move["a"] = 1
	input.highlight_attack["b"] = 1
	input._clear_highlights()
	assert_eq(input._pending_spell_id, "", "pending_spell_id should be cleared")
	assert_eq(input.highlight_move.size(), 0, "move highlights should be cleared")
	assert_eq(input.highlight_attack.size(), 0, "attack highlights should be cleared")
	input.free()

# РФ5-6: HeroMagic.spend_mana returns false on insufficient mana
func test_spend_mana_insufficient() -> void:
	var magic = _HeroMagic.new()
	magic.init_defaults()
	var result = magic.spend_mana(999)
	assert_false(result, "spend_mana should fail with insufficient mana")
	assert_eq(magic.mana_current, 20, "Mana should be unchanged on failed spend")

# РФ5-1: resume_battle handles SPELL pending action (без active state — no-op)
func test_resume_battle_pending_spell() -> void:
	var exec := _Executor.new()
	exec.name = "ExecResumeSpell"
	exec._pending_completion = _Executor.PendingAction.SPELL
	exec.resume_battle()
	assert_eq(exec._pending_completion, _Executor.PendingAction.NONE, "pending should reset after resume")
	assert_false(exec.is_paused(), "executor unpaused after resume")
	exec.free()

# РФ5-1: _paused guard in on_spell_anim_completed
func test_spell_anim_paused_guard() -> void:
	var exec := _Executor.new()
	exec.name = "ExecSpellPaused"
	exec._paused = true
	exec.on_spell_anim_completed()
	assert_eq(exec._pending_completion, _Executor.PendingAction.SPELL, "SPELL should be pending after paused guard")
	assert_eq(exec._state, _Executor.State.IDLE, "state unchanged while paused")
	exec.free()
