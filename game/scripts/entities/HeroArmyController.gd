extends Node
class_name HeroArmyController

var army: Array[UnitStack] = []
var _units_registry: Node = null

func setup(units_registry: Node = null) -> void:

	_units_registry = units_registry if units_registry != null else Services.resolve(&"units")
	_init_default_army()

func _init_default_army() -> void:
	army = [
		_units_registry.make_fixed_stack("swordsmen", 103),
		_units_registry.make_fixed_stack("archers", 36),
		_units_registry.make_fixed_stack("cavalry", 34),
		_units_registry.make_fixed_stack("mages", 10),
		_units_registry.make_fixed_stack("guardians", 20),
		_units_registry.make_fixed_stack("archmages", 12),
		_units_registry.make_fixed_stack("champions", 6),
		_units_registry.make_fixed_stack("knights", 12),
	]

func get_army_for_battle() -> Array[UnitStack]:
	var alive: Array[UnitStack] = []
	for stack in army:
		if stack == null or not stack.is_alive():
			continue
		if alive.size() >= GameNumbers.MAX_HERO_ARMY_SIZE:
			GameLogger.hero(
				"Армия героя достигла лимита юнитов (%d), остальные не участвуют в бою."
				% GameNumbers.MAX_HERO_ARMY_SIZE)
			break
		alive.append(stack.duplicate_stack())
	return alive

func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	var new_army: Array[UnitStack] = []
	for stack in surviving_army:
		if stack != null and stack.is_alive():
			if _units_registry != null:
				var clean = _units_registry.make_fixed_stack(stack.get_key(), stack.count)
				if clean != null:
					new_army.append(clean)
				continue
			new_army.append(stack.duplicate_stack())
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
		var stack: UnitStack = _units_registry.make_fixed_stack(key, count)
		if stack != null and stack.is_alive():
			army.append(stack)
