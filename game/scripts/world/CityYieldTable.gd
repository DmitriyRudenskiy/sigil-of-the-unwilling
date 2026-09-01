class_name CityYieldTable
extends RefCounted
## city-in-world: FIDSI-выходы клетки по реальному terrain (HexUtils.Terrain).
## Одна точка тюнинга; ключи — всегда FIDSI (неизвестный terrain → нули).

const KEYS: Array = [&"food", &"industry", &"dust", &"science", &"influence"]

## terrain_id (HexUtils.Terrain) -> {food, industry, dust, science, influence}.
static func yield_for_terrain(terrain_id: int) -> Dictionary:
	var out := _zero()
	match terrain_id:
		# HexUtils.Terrain.WATER (0) — строить/ставить рабочих нельзя, нули.
		HexUtils.Terrain.SWAMP:
			out[&"food"] = 1.0
			out[&"industry"] = 1.0
		HexUtils.Terrain.SAND:
			out[&"industry"] = 1.0
		HexUtils.Terrain.GRASS:
			out[&"food"] = 3.0
			out[&"industry"] = 2.0
		HexUtils.Terrain.FOREST:
			out[&"food"] = 1.0
			out[&"industry"] = 2.0
		HexUtils.Terrain.MOUNTAIN:
			out[&"industry"] = 3.0
			out[&"dust"] = 1.0
		HexUtils.Terrain.SNOW:
			out[&"food"] = 1.0
	return out


static func _zero() -> Dictionary:
	var out := {}
	for k in KEYS:
		out[k] = 0.0
	return out
