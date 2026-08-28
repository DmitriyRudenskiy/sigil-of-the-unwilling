extends Node
## Тестовый фейк: HeroController для WorldBattleCoordinator.
## Минимальный набор свойств/методов, к которым координатор обращается
## через мягкие зависимости (get / has_method).

var movement: Node = null   # FakeMovement
var army: Node = null       # Опционально: HeroArmyController (fallback-стек)
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
