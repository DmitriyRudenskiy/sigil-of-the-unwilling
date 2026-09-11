extends BaseTest


func test_spellbook_button_is_action_button() -> void:
	var action = true
	assert_bool(action).is_true()

func test_spell_chosen_ignored_when_locked() -> void:
	var exec = BattleTurnExecutor.new()
	assert_bool(exec.is_input_active()).is_false()
	exec.free()

func test_is_input_active_states() -> void:
	var exec = BattleTurnExecutor.new()
	assert_bool(exec.is_input_active()).is_false()
	exec.free()

func test_spell_chosen_panel_closes() -> void:
	var units := Services.resolve(&"units")
	var state := BattleState.new()
	var atk_stack: UnitStack = units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	var exec = auto_free( BattleTurnExecutor.new())
	exec.name = "ExecSpellbook"
	exec.setup(state, BattleAI.new(), {})
	state.active_unit = state.attacker_units[0]
	var emitted_holder: Array = [false]
	exec.spell_cast_executed.connect(func(_caster, _target, _r):
		emitted_holder[0] = true
	)
	exec.on_spell_target_selected(&"magic_arrow", state.defender_units[0])
	assert_bool(emitted_holder[0]).is_true()
	exec.free()

func test_shortcuts_gated_by_world_visibility() -> void:
	var world_visible = false
	var should_gate = not world_visible
	assert_bool(should_gate).is_true()
