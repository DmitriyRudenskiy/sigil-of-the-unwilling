class_name BattleFlow
extends Node

signal battle_started
signal battle_completed(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

const _BATTLE_SCENE := preload("res://scenes/battle.tscn")

var _active_battle: Node = null
## Узел сцены боя под root, пока он жив. После `_on_battle_finished` `_active_battle`
## уже `null`, а сцена остаётся до оверлея «Продолжить» — именно она и оставалась
## сиротой под root, когда мир снимали с дерева: следующий автопрогон в том же
## процессе находил её в `_handle_battle()`, видел `battle_over` и зависал на ней,
## не доходя до хода (T-204: druid→fighter, `turn` стоит на 0, `battles_fought` +1
## за кадр).
var _battle_node: Node = null

func start_battle(
	attacker_army: Array[UnitStack],
	defender_army: Array[UnitStack],
	attacker_bonus: Dictionary = {},
	defender_bonus: Dictionary = {},
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {},
	obstacle_seed: int = -1,
	hero_magic: Variant = null,
	enemy_terrain: String = "grass"
) -> void:
	# T17/D2: без ГСЧ — отсутствие seed означает пустое поле препятствий.
	if obstacle_seed < 0:
		obstacle_seed = 0
	if _active_battle != null and is_instance_valid(_active_battle):
		return
	SoundManager.play_music_cue(&"music_battle")
	battle_started.emit()

	_active_battle = _BATTLE_SCENE.instantiate()
	_active_battle.name = "Battle"
	_battle_node = _active_battle

	get_tree().root.add_child(_active_battle)

	_active_battle.battle_finished.connect(_on_battle_finished.bind(_active_battle))
	_active_battle.call_deferred(
		"start_battle",
		attacker_army,
		defender_army,
		attacker_bonus,
		defender_bonus,
		attacker_artifact_mods,
		defender_artifact_mods,
		obstacle_seed,
		hero_magic,
		enemy_terrain
	)

func _on_battle_finished(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack], battle: Node) -> void:
	_active_battle = null
	# UI-3 F: сцена держится до подтверждения финального оверлея (единственный выход)
	if is_instance_valid(battle) and battle.has_method("show_result_overlay"):
		battle.show_result_overlay(winner, surviving_atk, surviving_def)
		battle.result_accepted.connect(
			_finish_battle.bind(winner, surviving_atk, surviving_def, battle), CONNECT_ONE_SHOT)
		return
	_finish_battle(winner, surviving_atk, surviving_def, battle)

func _finish_battle(
	winner: BattleState.Side,
	surviving_atk: Array[UnitStack],
	surviving_def: Array[UnitStack],
	battle: Node
) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
	if _battle_node == battle:
		_battle_node = null
	RenderingServer.set_default_clear_color(ThemeConfig.C_BATTLE_BG_FLOW)
	if winner == BattleState.Side.ATTACKER:
		SoundManager.play_sfx_cue(&"battle_victory")
	else:
		SoundManager.play_sfx_cue(&"battle_defeat")
	SoundManager.play_music_cue(&"music_world")
	battle_completed.emit(winner, surviving_atk, surviving_def)

## Владелец сцены боя — flow. Снимают flow (вместе с миром) — снимается и сцена:
## оставшись под root, она превращалась в вечный «бой завершён» для любого
## следующего автопрогона того же процесса (T-204).
func _exit_tree() -> void:
	if is_instance_valid(_battle_node):
		_battle_node.queue_free()
	_battle_node = null
	_active_battle = null
