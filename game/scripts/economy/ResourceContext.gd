class_name ResourceContext
extends RefCounted

signal resource_changed(id: StringName, old_val: float, new_val: float)
signal capacity_reached(id: StringName)

var _resources: Dictionary = {}  
var _capacities: Dictionary = {}  


func setup(defs: Array) -> void:
	for def in defs:
		if def == null:
			continue
		var cap: float = float(get_def_capacity(def))
		if not _capacities.has(def.id):
			_capacities[def.id] = cap


static func get_def_capacity(def: ResourceDef) -> float:
	return def.capacity if def.capacity > 0.0 else INF


func amount(id: StringName) -> float:
	return float(_resources.get(id, 0.0))


func get_all() -> Dictionary:
	return _resources.duplicate()


func has(id: StringName) -> bool:
	return _resources.has(id) and amount(id) > 0.0


func is_empty() -> bool:
	for id in _resources:
		if amount(id) > 0.0:
			return false
	return true


func add(id: StringName, add_amount: float) -> float:
	if add_amount <= 0.0:
		return 0.0
	if not _capacities.has(id):
		_capacities[id] = INF
	var old: float = amount(id)
	var cap: float = _capacities[id]
	var new_val: float = minf(old + add_amount, cap)
	var actual: float = maxf(new_val - old, 0.0)
	_resources[id] = new_val
	resource_changed.emit(id, old, new_val)
	if new_val >= cap and actual < add_amount:
		capacity_reached.emit(id)
	return actual


func remove(id: StringName, remove_amount: float) -> float:
	if remove_amount <= 0.0:
		return 0.0
	var old: float = amount(id)
	var actual: float = minf(remove_amount, old)
	_resources[id] = old - actual
	resource_changed.emit(id, old, old - actual)
	return actual


func get_capacity(id: StringName) -> float:
	return float(_capacities.get(id, INF))


func set_capacity(id: StringName, cap: float) -> void:
	_capacities[id] = cap
	var cur: float = amount(id)
	if cur > cap:
		_resources[id] = cap
		resource_changed.emit(id, cur, cap)


func can_afford(costs: Dictionary) -> bool:
	for id in costs:
		if amount(id) < float(costs[id]):
			return false
	return true


func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for id in costs:
		remove(id, float(costs[id]))
	return true


func serialize() -> Dictionary:
	var out := {}
	for id in _resources:
		out[String(id)] = amount(id)
	return out


func deserialize(data: Dictionary) -> void:
	_resources.clear()
	for id in data:
		_resources[StringName(id)] = float(data[id])
