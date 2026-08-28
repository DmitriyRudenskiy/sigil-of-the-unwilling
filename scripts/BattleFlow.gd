class_name BattleFlow
extends Node
## Поток боя: создание, ожидание, возврат результата.
## Не прячет мир и не меняет героя — это остаётся в WorldController.

signal battle_started
signal battle_completed(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

const _BATTLE_SCENE := preload("res://scenes/Battle.tscn")

var _active := false

func start_battle(
	attacker_army: Array[UnitStack],
	defender_army: Array[UnitStack],
	attacker_bonus: Dictionary = {},
	defender_bonus: Dictionary = {},
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {},
	obstacle_seed: int = -1,
	hero_magic: Node = null
) -> void:
	if obstacle_seed < 0:
		obstacle_seed = randi()
	if _active:
		return
	_active = true
	battle_started.emit()

	var battle := _BATTLE_SCENE.instantiate()
	battle.name = "Battle"

	get_tree().root.add_child(battle)

	battle.battle_finished.connect(_on_battle_finished.bind(battle))
	battle.call_deferred(
		"start_battle",
		attacker_army,
		defender_army,
		attacker_bonus,
		defender_bonus,
		attacker_artifact_mods,
		defender_artifact_mods,
		obstacle_seed,
		hero_magic
	)


func _on_battle_finished(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack], battle: Node) -> void:
	_active = false
	battle.queue_free()
	RenderingServer.set_default_clear_color(Color(0.10, 0.10, 0.12))
	battle_completed.emit(winner, surviving_atk, surviving_def)
