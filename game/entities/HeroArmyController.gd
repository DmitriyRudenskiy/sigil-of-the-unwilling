extends Node
class_name HeroArmyController
## Hero army: init, battle serialization, results application.
## UnitRegistry инжектируется через setup(); fallback → ServiceContainer → autoload.

const ServiceContainer = preload("res://core/ServiceContainer.gd")
const ServiceLocator = preload("res://core/ServiceLocator.gd")

var army: Array[UnitStack] = []
var _units_registry: Node = null  # UnitRegistry


func setup(units_registry: Node = null) -> void:
	_units_registry = ServiceLocator.resolve(units_registry, &"units")
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
		# РФ-герой: герой не может командовать более чем MAX_HERO_ARMY_SIZE юнитами.
		if alive.size() >= GameSettings.MAX_HERO_ARMY_SIZE:
			GameLogger.hero(
				"Армия героя достигла лимита юнитов (%d), остальные не участвуют в бою."
				% GameSettings.MAX_HERO_ARMY_SIZE)
			break
		alive.append(stack.duplicate_stack())
	return alive


func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	var new_army: Array[UnitStack] = []
	for stack in surviving_army:
		if stack != null and stack.is_alive():
			# РФ6-1: пересборка из реестра — статы каноничные, только численность сохраняется
			var clean = _units_registry.make_fixed_stack(stack.get_key(), stack.count)
			if clean != null:
				new_army.append(clean)
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
