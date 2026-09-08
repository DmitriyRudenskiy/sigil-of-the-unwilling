class_name BattleAttackSequence
extends RefCounted
## Секвенция атаки: удары, двойной удар, реприза, моральная доп. инициатива.
## Составляющая BattleTurnExecutor — инстанс владеет исполнителем.


func setup(state: BattleState, rng: RandomNumberGenerator, executor: BattleTurnExecutor) -> void:
	_battle_state = state
	_rng = rng
	_executor = executor


var _executor: BattleTurnExecutor
var _battle_state: BattleState
var _rng: RandomNumberGenerator

var _attack_attacker: BattleState.BattleUnit = null
var _attack_defender: BattleState.BattleUnit = null
var _attack_strikes_left := 0
var _attack_is_melee := false
var _retaliation_phase := false


func has_active() -> bool:
	return _attack_attacker != null


func is_retaliating() -> bool:
	return _retaliation_phase


func strikes_left() -> int:
	return _attack_strikes_left


func attacker() -> BattleState.BattleUnit:
	return _attack_attacker


func defender() -> BattleState.BattleUnit:
	return _attack_defender


func has_adjacent_enemy(unit: BattleState.BattleUnit) -> bool:
	if unit == null:
		return false

	var target_side := BattleState.Side.DEFENDER if unit.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER

	for nb in HexUtils.get_all_neighbors(unit.cell):
		var u := _battle_state.get_unit_at(nb, target_side)
		if u != null and u.is_alive():
			return true

	return false


func start_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if atk == null or def == null or not def.is_alive():
		_executor._on_action_completed()
		return

	if not atk.is_alive():
		_executor._on_action_completed()
		return

	var distance := HexUtils.hex_distance(atk.cell, def.cell)
	var adjacent_enemy := has_adjacent_enemy(atk)

	var is_ranged_shot := atk.is_ranged() and distance > 1 and not adjacent_enemy
	var is_melee_attack := not is_ranged_shot

	_attack_attacker = atk
	_attack_defender = def
	_attack_is_melee = is_melee_attack
	_attack_strikes_left = 2 if atk.is_double_strike() else 1
	_retaliation_phase = false

	var anim_state := BattleTurnExecutor.State.PLAYER_ANIMATING if atk.side == BattleState.Side.ATTACKER else BattleTurnExecutor.State.AI_ANIMATING
	_executor._transition_to(anim_state)

	next_strike()


func next_strike() -> void:
	if _attack_attacker == null or _attack_defender == null:
		finish()
		return

	if not _attack_attacker.is_alive() or not _attack_defender.is_alive():
		finish()
		return

	if _attack_strikes_left <= 0:
		finish()
		return

	_attack_strikes_left -= 1

	var result := _battle_state.apply_attack(
		_attack_attacker,
		_attack_defender,
		_attack_is_melee,
		_rng,
		not _retaliation_phase
	)

	if result.is_empty():
		finish()
		return

	SoundManager.play_sfx_cue(&"battle_hit")
	result["is_retaliation"] = _retaliation_phase

	if result.get("luck", false):
		_executor.floating_text.emit(_attack_defender.cell, GameText.battle_luck(), ThemeConfig.C_BATTLE_LUCK)

	_executor.execute_attack.emit(_attack_attacker, _attack_defender, result)


func finish() -> void:
	_attack_attacker = null
	_attack_defender = null
	_attack_strikes_left = 0
	_retaliation_phase = false

	_executor._morale_allowed = true
	_executor._on_action_completed()


func can_retaliate() -> bool:
	if _attack_attacker == null or _attack_defender == null:
		return false

	if not _attack_is_melee:
		return false

	if not _attack_defender.is_alive():
		return false

	if not _attack_attacker.is_alive():
		return false

	if _attack_defender.has_retaliated:
		return false

	if _attack_attacker.is_no_retaliation():
		return false

	return true


func start_retaliation() -> void:
	var original_attacker := _attack_attacker
	var original_defender := _attack_defender

	_retaliation_phase = true
	_attack_attacker = original_defender
	_attack_defender = original_attacker
	_attack_strikes_left = 1
	_attack_is_melee = true

	original_defender.has_retaliated = true

	var anim_state := BattleTurnExecutor.State.PLAYER_ANIMATING if _attack_attacker.side == BattleState.Side.ATTACKER else BattleTurnExecutor.State.AI_ANIMATING
	_executor._transition_to(anim_state)

	_executor.floating_text.emit(_attack_attacker.cell, GameText.battle_retaliation(), ThemeConfig.C_BATTLE_RETALIATION)

	next_strike()


func try_morale_extra_turn() -> bool:
	var unit := _battle_state.active_unit

	if unit == null or not unit.is_alive():
		return false

	if not BattleRules.can_morale(unit):
		return false

	if _rng.randf() >= GameNumbers.MORALE_CHANCE:
		return false

	_executor.floating_text.emit(unit.cell, GameText.battle_high_morale(), ThemeConfig.C_MORALE)

	unit.has_moved = false

	if _battle_state.is_player_turn:
		_executor._transition_to(BattleTurnExecutor.State.WAITING_INPUT)
	else:
		_executor._run_ai_turn()

	return true
