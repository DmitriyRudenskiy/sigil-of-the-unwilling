class_name HeroStrategicResources
extends RefCounted

signal strategic_resources_changed(resources: Dictionary)

var _resources: Dictionary = {}
var _resource_registry: Node = null
# Ранняя игра: расширение провозной способности (рыночная телега)
var capacity_bonus: int = 0
# attribute-weight-system: весовой лимит рюкзака (заполняется из defense)
var weight_cap: float = GameNumbersHero.WEIGHT_BASE_CAP + 2.0 * GameNumbersHero.WEIGHT_PER_DEFENSE

func total() -> int:
	var s := 0
	for id in _resources:
		s += int(_resources[id])
	return s

func total_cap() -> int:
	return GameNumbersHero.BACKPACK_TOTAL_CAP + capacity_bonus

func init_from_registry(resource_registry: Node = null) -> void:

	_resource_registry = resource_registry if resource_registry != null else Services.resolve(&"resources")

	var all: Array = _resource_registry.get_all()
	for def in all:
		_resources[def.id] = 0

func set_weight_cap(v: float) -> void:
	weight_cap = v

func current_weight() -> float:
	if _resource_registry == null:
		return 0.0
	return LoadCalculator.resources_weight(_resources, _resource_registry)

func remaining_units(id: StringName) -> int:
	if _resource_registry == null:
		return max(0, total_cap() - total())
	var def: ResourceDef = _resource_registry.get_resource(id)
	if def == null or def.weight_per_unit <= 0.0:
		return max(0, total_cap() - total())
	return LoadCalculator.fit_units(def, current_weight(), weight_cap)

func fit_weight(id: StringName) -> int:
	return remaining_units(id)

func get_all() -> Dictionary:
	return _resources.duplicate()

func set_all(data: Dictionary) -> void:
	_resources = data.duplicate()
	strategic_resources_changed.emit(_resources)

func add(id: StringName, amount: int) -> int:
	"""Add strategic resource. Returns amount actually added (may be capped by count AND weight)."""
	if amount <= 0:
		return 0
	if not _resources.has(id):
		_resources[id] = 0
	var current: int = _resources[id]
	# Ранняя игра: общий лимит рюкзака, а не на тип (early-game-foundation)
	var space: int = total_cap() - total()
	# attribute-weight-system: весовой лимит поверх count-лимита
	var weight_space: int = remaining_units(id)
	var actual: int = min(amount, max(0, space), max(0, weight_space))
	_resources[id] = current + actual
	strategic_resources_changed.emit(_resources)
	return actual

func remove(id: StringName, amount: int) -> int:
	"""Remove strategic resource (for tools/consumables). Returns amount actually removed."""
	if amount <= 0 or not _resources.has(id):
		return 0
	var current: int = _resources[id]
	var actual: int = min(amount, current)
	_resources[id] = current - actual
	strategic_resources_changed.emit(_resources)
	return actual

func _add_internal(id: StringName, amount: int) -> void:
	"""Internal: add without per-call emit (batch updates)."""
	if not _resources.has(id):
		_resources[id] = 0
	var current: int = _resources[id]
	var space: int = max(0, total_cap() - total())
	var weight_space: int = remaining_units(id)
	var new_val: int = min(current + amount, current + space, current + weight_space)
	if new_val != current:
		_resources[id] = new_val

func emit_changed() -> void:
	"""Emit after batch updates."""
	strategic_resources_changed.emit(_resources)
