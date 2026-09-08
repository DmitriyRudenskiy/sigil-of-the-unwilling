class_name ProductionChain
extends RefCounted

var id: StringName = &""
var inputs: Dictionary = {}  
var outputs: Dictionary = {}  
var required_workers: int = 1
var building_eff: float = 1.0


func calculate_output(workers: int, logistics: float = 1.0) -> Dictionary:
	if required_workers <= 0 or workers <= 0:
		return {}
	var ratio: float = float(workers) / float(required_workers)
	var eff: float = minf(ratio, 1.0) * building_eff * logistics
	var result := {}
	for out_id in outputs:
		result[out_id] = float(outputs[out_id]) * eff
	return result


func can_produce(ctx: ResourceContext, workers: int) -> bool:
	if workers <= 0:
		return false
	return ctx.can_afford(inputs)


func execute(ctx: ResourceContext, workers: int, logistics: float = 1.0) -> Dictionary:
	if not can_produce(ctx, workers):
		return {}
	for in_id in inputs:
		ctx.remove(in_id, float(inputs[in_id]))
	return calculate_output(workers, logistics)


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"inputs": _sn_dict_to_str(inputs),
		"outputs": _sn_dict_to_str(outputs),
		"required_workers": required_workers,
		"building_eff": building_eff,
	}


static func from_dict(data: Dictionary) -> ProductionChain:
	var chain := ProductionChain.new()
	chain.id = StringName(data.get("id", ""))
	chain.inputs = _str_dict_to_sn(data.get("inputs", {}))
	chain.outputs = _str_dict_to_sn(data.get("outputs", {}))
	chain.required_workers = int(data.get("required_workers", 1))
	chain.building_eff = float(data.get("building_eff", 1.0))
	return chain


static func _sn_dict_to_str(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[String(k)] = src[k]
	return out


static func _str_dict_to_sn(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[StringName(k)] = src[k]
	return out
