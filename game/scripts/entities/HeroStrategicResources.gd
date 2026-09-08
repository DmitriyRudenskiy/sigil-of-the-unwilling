class_name HeroStrategicResources
extends RefCounted

signal strategic_resources_changed(resources: Dictionary)

var _resources: Dictionary = {}
var _resource_registry: Node = null


func init_from_registry(resource_registry: Node = null) -> void:
	# ИСПРАВЛЕНИЕ: единый путь
	_resource_registry = resource_registry if resource_registry != null else Services.resolve(&"resources")

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
	var space: int = GameNumbers.RESOURCE_CAPACITY - current
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
	var new_val: int = min(current + amount, GameNumbers.RESOURCE_CAPACITY)
	if new_val != current:
		_resources[id] = new_val


func emit_changed() -> void:
	"""Emit after batch updates."""
	strategic_resources_changed.emit(_resources)
