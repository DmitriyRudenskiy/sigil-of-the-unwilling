class_name ResourceContext
extends RefCounted

signal resource_changed(id: StringName, old_val: float, new_val: float)
signal capacity_reached(id: StringName)
signal transaction_committed(flow: Dictionary)

var _resources: Dictionary = {}
var _capacities: Dictionary = {}
var _registered: Dictionary = {}
var _strict_registry := false
var _ledger: Array[Dictionary] = []

func setup(defs: Array, strict_registry: bool = false) -> void:
	_strict_registry = _strict_registry or strict_registry
	for def in defs:
		if def == null:
			continue
		_registered[def.id] = true
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

func add(id: StringName, add_amount: float, source: String = "") -> float:
	if add_amount <= 0.0 or (_strict_registry and not _registered.has(id)):
		return 0.0
	if not _capacities.has(id):
		_capacities[id] = INF
	var old: float = amount(id)
	var cap: float = _capacities[id]
	var new_val: float = minf(old + add_amount, cap)
	var actual: float = maxf(new_val - old, 0.0)
	_resources[id] = new_val
	if actual > 0.0:
		resource_changed.emit(id, old, new_val)
		if not source.is_empty():
			_record_flow(source, {}, {id: actual})
	if new_val >= cap and actual < add_amount:
		capacity_reached.emit(id)
	return actual

func remove(id: StringName, remove_amount: float, source: String = "") -> float:
	if remove_amount <= 0.0 or (_strict_registry and not _registered.has(id)):
		return 0.0
	var old: float = amount(id)
	var actual: float = minf(remove_amount, old)
	_resources[id] = old - actual
	if actual > 0.0:
		resource_changed.emit(id, old, old - actual)
		if not source.is_empty():
			_record_flow(source, {id: actual}, {})
	return actual

func get_capacity(id: StringName) -> float:
	if _strict_registry and not _registered.has(id):
		return 0.0
	return float(_capacities.get(id, INF))

func set_capacity(id: StringName, cap: float) -> void:
	if _strict_registry and not _registered.has(id):
		return
	_capacities[id] = cap
	var cur: float = amount(id)
	if cur > cap:
		_resources[id] = cap
		resource_changed.emit(id, cur, cap)

func can_afford(costs: Dictionary) -> bool:
	for id in costs:
		if (_strict_registry and not _registered.has(id)) or amount(id) < float(costs[id]):
			return false
	return true

## Apply both sides or neither; successful entries are the auditable resource ledger.
func transact(inputs: Dictionary, outputs: Dictionary, source: String) -> Dictionary:
	if inputs.is_empty() and outputs.is_empty():
		return {"ok": false, "reason": "empty_transaction", "source": source}
	var ids := {}
	for id in inputs:
		ids[id] = true
	for id in outputs:
		ids[id] = true
	var missing := {}
	var capacity_shortage := {}
	var invalid := []
	var final_amounts := {}
	for id in ids:
		if _strict_registry and not _registered.has(id):
			invalid.append(String(id))
			continue
		var cost := float(inputs.get(id, 0.0))
		var product := float(outputs.get(id, 0.0))
		if not is_finite(cost) or not is_finite(product) or cost < 0.0 or product < 0.0:
			return {"ok": false, "reason": "invalid_amount", "resource": String(id), "source": source}
		if amount(id) < cost:
			missing[String(id)] = cost - amount(id)
			continue
		var after := amount(id) - cost + product
		if after > get_capacity(id):
			capacity_shortage[String(id)] = after - get_capacity(id)
		else:
			final_amounts[id] = after
	if not invalid.is_empty():
		return {"ok": false, "reason": "unregistered_resource", "resources": invalid, "source": source}
	if not missing.is_empty():
		return {"ok": false, "reason": "insufficient_stock", "missing": missing, "source": source}
	if not capacity_shortage.is_empty():
		return {"ok": false, "reason": "insufficient_capacity", "capacity_shortage": capacity_shortage, "source": source}
	for id in final_amounts:
		var old := amount(id)
		var new_val: float = final_amounts[id]
		_resources[id] = new_val
		if not is_equal_approx(old, new_val):
			resource_changed.emit(id, old, new_val)
	var flow := _record_flow(source, inputs, outputs)
	return {"ok": true, "flow": flow}

func _record_flow(source: String, inputs: Dictionary, outputs: Dictionary) -> Dictionary:
	var flow := {
		"source": source,
		"inputs": _string_key_copy(inputs),
		"outputs": _string_key_copy(outputs),
	}
	_ledger.append(flow)
	transaction_committed.emit(flow.duplicate(true))
	return flow

func spend(costs: Dictionary, source: String = "spend") -> bool:
	if costs.is_empty():
		return true
	return bool(transact(costs, {}, source).get("ok", false))

func get_ledger() -> Array[Dictionary]:
	return _ledger.duplicate(true)

func clear_ledger() -> void:
	_ledger.clear()

func serialize() -> Dictionary:
	var out := {}
	for id in _resources:
		out[String(id)] = amount(id)
	return out

func deserialize(data: Dictionary) -> void:
	_resources.clear()
	for id in data:
		if _strict_registry and not _registered.has(StringName(id)):
			continue
		_resources[StringName(id)] = float(data[id])

static func _string_key_copy(values: Dictionary) -> Dictionary:
	var copy := {}
	for id in values:
		copy[String(id)] = float(values[id])
	return copy
