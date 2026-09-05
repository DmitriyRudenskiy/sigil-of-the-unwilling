class_name HeroStrategicResources
extends RefCounted
## Strategic resource management (wood, stone, etc.) for the hero.
## ResourceRegistry инжектируется через init_from_registry().

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")

signal strategic_resources_changed(resources: Dictionary)

var _resources: Dictionary = {}
var _resource_registry: Node = null  # ResourceRegistry


func init_from_registry(resource_registry: Node = null) -> void:
	_resource_registry = ServiceLocator.resolve(resource_registry, &"resources")

	var all: Array = _resource_registry.get_all()
	for def in all:
		_resources[def.id] = 0


func get_all() -> Dictionary:
	return _resources.duplicate()


func set_all(data: Dictionary) -> void:
	_resources = data.duplicate()
	strategic_resources_changed.emit(_resources)


func add(id: StringName, amount: int) -> int:
	"""Add strategic resource. Returns amount actually added (may be capped)."""
	if amount <= 0:
		return 0
	if not _resources.has(id):
		_resources[id] = 0
	var current: int = _resources[id]
	var space: int = MapConfig.RESOURCE_CAPACITY - current
	var actual: int = min(amount, max(0, space))
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
	var new_val: int = min(current + amount, MapConfig.RESOURCE_CAPACITY)
	if new_val != current:
		_resources[id] = new_val


func emit_changed() -> void:
	"""Emit after batch updates."""
	strategic_resources_changed.emit(_resources)
