extends Node
class_name HeroArmyController
## Hero army: init, battle serialization, results application.

var army: Array[UnitStack] = []


func _init() -> void:
	_init_default_army()


func _init_default_army() -> void:
	army = [
		Units.make_fixed_stack("swordsmen", 103),
		Units.make_fixed_stack("archers", 36),
		Units.make_fixed_stack("cavalry", 34),
		Units.make_fixed_stack("mages", 10),
		Units.make_fixed_stack("guardians", 20),
		Units.make_fixed_stack("archmages", 12),
		Units.make_fixed_stack("champions", 6),
		Units.make_fixed_stack("knights", 12),
	]


func get_army_for_battle() -> Array[UnitStack]:
	var alive: Array[UnitStack] = []
	for stack in army:
		if stack != null and stack.is_alive():
			alive.append(stack.duplicate_stack())
	return alive


func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	var new_army: Array[UnitStack] = []
	for stack in surviving_army:
		if stack != null and stack.is_alive():
			new_army.append(stack)
	army = new_army


func serialize() -> Array:
	var result: Array = []
	for stack in army:
		if stack != null and stack.is_alive():
			result.append({"key": stack.get_key(), "count": stack.count})
	return result


func deserialize(data: Array) -> void:
	army.clear()
	for item in data:
		var key: String = str(item.get("key", ""))
		var count: int = int(item.get("count", 0))
		var stack := Units.make_fixed_stack(key, count)
		if stack != null and stack.is_alive():
			army.append(stack)
