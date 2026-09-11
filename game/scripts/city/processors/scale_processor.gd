class_name ScaleProcessor
extends CitySubProcessor
## Scale/tier shift, storage capacity scaling, per-tier multipliers.

signal city_scale_changed(city_uid: int, new_scale: int)

var _base_caps: Dictionary = {}


func get_id() -> StringName:
	return &"scale"


func process(city: City, _turn: int, report: Dictionary) -> void:
	var new_tier: int = ScaleShiftManager.tier_for(city.pop_capped())
	if new_tier != city.scale_tier:
		city.scale_tier = new_tier
		report["scale_changed"] = 1
		city_scale_changed.emit(city.uid, new_tier)
	report["tier"] = new_tier

	var res := city.ensure_resource_ctx()
	var storage_mult: float = ScaleShiftManager.storage_multiplier(new_tier)
	if storage_mult != 1.0:
		var base: Dictionary = _base_caps.get(city.uid, {})
		for rid in _known_resource_ids(res):
			var cur_cap: float = res.get_capacity(rid)
			if cur_cap >= GameSettings.INF / 2.0:
				continue
			if not base.has(rid):
				base[rid] = cur_cap
			res.set_capacity(rid, float(base[rid]) * storage_mult)
		_base_caps[city.uid] = base
	elif _base_caps.has(city.uid):
		var base: Dictionary = _base_caps[city.uid]
		for rid in base:
			res.set_capacity(rid, float(base[rid]))

	city.auto_resource_mult = ScaleShiftManager.auto_resource_multiplier(new_tier)
	city.upkeep_mult = ScaleShiftManager.upkeep_multiplier(new_tier)


func _known_resource_ids(res: ResourceContext) -> Array:
	var ids: Array = []
	for id in res.get_all():
		ids.append(id)
	return ids
