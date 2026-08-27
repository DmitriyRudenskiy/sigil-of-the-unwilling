class_name HeroStrategicResources
extends RefCounted
## Strategic resource management (wood, stone, etc.) for the hero.
## Extracted from HeroController to reduce its size and improve testability.

signal strategic_resources_changed(resources: Dictionary)

var _resources: Dictionary = {}

func init_from_registry() -> void:
	var all: Array = ResourceRegistry.get_all()
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
	var space: int = GameSettings.RESOURCE_CAPACITY - current
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
	var new_val: int = min(current + amount, GameSettings.RESOURCE_CAPACITY)
	if new_val != current:
		_resources[id] = new_val


func emit_changed() -> void:
	"""Emit after batch updates."""
	strategic_resources_changed.emit(_resources)
