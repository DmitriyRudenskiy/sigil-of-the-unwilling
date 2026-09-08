extends Node

var movement: Node = null   
var army: Node = null       
var apply_calls := 0
var force_stop_calls := 0


func force_stop() -> void:
	force_stop_calls += 1


func get_battle_bonus() -> Dictionary:
	return {}


func get_army_for_battle() -> Array:
	return []


func apply_battle_results(_survivors: Array) -> void:
	apply_calls += 1
