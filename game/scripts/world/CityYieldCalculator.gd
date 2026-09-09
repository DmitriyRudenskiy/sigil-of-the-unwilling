class_name CityYieldCalculator
extends RefCounted

const _YIELD_KEYS := [&"food", &"industry", &"dust", &"science", &"influence"]

var _exploited_cache: Dictionary = {}
var _exploited_dirty: bool = true
var _yield_cache: Dictionary = {}
var _yield_cache_dirty: bool = true

func invalidate() -> void:
	_exploited_dirty = true
	_yield_cache_dirty = true

func calculate(city: City) -> Dictionary:
	if not _yield_cache_dirty:
		return _yield_cache.duplicate()
	_ensure_exploited(city)
	var total := {}
	for k in _YIELD_KEYS:
		total[k] = 0.0
	for cell in _exploited_cache.keys():
		var y: Dictionary = city.tile_yield_fn.call(cell)
		for k in _YIELD_KEYS:
			total[k] = float(total[k]) + float(y.get(k, 0.0))
	total[&"food"] = float(total[&"food"]) * SpecializationSystem.food_yield_multiplier(city)
	_yield_cache = total
	_yield_cache_dirty = false
	return total.duplicate()

func _ensure_exploited(city: City) -> void:
	if not _exploited_dirty:
		return
	_exploited_cache.clear()
	for borough in city.boroughs:
		for nb in HexUtils.get_all_neighbors(borough.cell):
			if not city.cell_is_built(nb):
				_exploited_cache[nb] = true
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.tile.x >= 0 and not city.cell_is_built(u.tile):
			_exploited_cache[u.tile] = true
	_exploited_dirty = false
