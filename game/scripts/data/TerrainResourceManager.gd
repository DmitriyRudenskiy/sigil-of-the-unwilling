extends Node
class_name TerrainResourceManager
## terrain-resources: лес и горы на карте — точки добычи (лес → wood, гора →
## stone). Добыча по контакту (герой встал на клетку), истощение точек,
## персистентность истощения, конфигурируемая плотность, визуальная
## маркировка (см. MarkerLayer.set_terrain_resource_markers).
##
## Аддитивно к существующим hidden-жилам ResourceNodeManager — не трогает
## систему `resource_cells` (требование: отсутствие регрессии).

const HexUtils = preload("res://scripts/core/HexUtils.gd")
const GameLogger = preload("res://scripts/core/GameLogger.gd")

## лес → wood, гора → stone (требование: карта «террейн → ресурс»).
const TERRAIN_RESOURCE_MAP: Dictionary = {
	HexUtils.Terrain.FOREST: &"wood",
	HexUtils.Terrain.MOUNTAIN: &"stone",
}

## добыча по контакту: сколько даётся с одной точки за раз.
const HARVEST_AMOUNT := 2

signal terrain_harvested(cell: Vector2i, res_id: StringName, amount: int)
signal terrain_exhausted(cell: Vector2i, res_id: StringName)

## terrain_resource_cells: cell -> {"res": res_id, "exhausted": bool}.
var cells: Dictionary = {}
## конфигурируемая плотность: доля forest/mountain клеток, ставших точками
## (0..1; 1.0 = все клетки лесов и гор — точки добычи).
var density: float = 1.0

## персистентность: дельта мира, куда записывается истощение (WorldStateDelta).
var _world_delta: Variant = null

## персистентность: связать с дельтой мира (запись истощения в момент добычи).
func attach_delta(delta: Variant) -> void:
	_world_delta = delta

func _ready() -> void:
	# автозагрузка не нужна — менеджер живёт в результате бутстрапа.
	pass

## генерация точек добычи на клетках лесов/гор во время генерации карты.
## density — конфигурируемая плотность (переопределяет self.density).
func generate(map_data: Dictionary, density: float = -1.0) -> void:
	cells.clear()
	# ponytail: density < 0 = « не задана» → брать self.density; 0 = «ноль точек».
	if density < 0.0:
		density = self.density
	elif density >= 0.0:
		self.density = density
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(map_data.get("seed", 0))
	var terrain_map: Dictionary = map_data.get("terrain", {})
	var width: int = map_data.get("width", 0)
	var height: int = map_data.get("height", 0)
	if width == 0 or height == 0:
		return
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				continue
			var terrain_id: int = int(terrain_map[cell])
			var res_id: Variant = TERRAIN_RESOURCE_MAP.get(terrain_id)
			if res_id == null:
				continue
			# ponytail: плотность — вероятностная выборка клеток (рандом по seed).
			if rng.randf() <= density:
				cells[cell] = {"res": res_id, "exhausted": false}

## доступен ли клетке ресурс к добыче (требование: «террейн → ресурс» +
## «доступный к добыче ресурс»).
func is_harvestable(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and not c.get("exhausted", false)

## id ресурса на клетке (или null, если клетки нет в карте точек).
func res_id_at(cell: Vector2i) -> Variant:
	var c: Variant = cells.get(cell, null)
	return c.get("res", null) if c != null else null

## добыча по контакту: герой встал на клетку точки добычи → начислить ресурс,
## истощить точку. Возвращает {"res_id":..., "amount":...} (amount 0 — если не
## доступно).
func harvest(cell: Vector2i) -> Dictionary:
	var c = cells.get(cell, null)
	if c == null or c.get("exhausted", false):
		return {"res_id": null, "amount": 0}
	var res_id: StringName = c["res"] as StringName
	c["exhausted"] = true
	if _world_delta != null and _world_delta.has_method("add_terrain_exhausted"):
		_world_delta.add_terrain_exhausted(cell)
	terrain_harvested.emit(cell, res_id, HARVEST_AMOUNT)
	terrain_exhausted.emit(cell, res_id)
	GameLogger.world("Terrain resource harvested at %s: %s" % [cell, res_id])
	return {"res_id": res_id, "amount": HARVEST_AMOUNT}

## персистентность истощения: отметить клетки истощёнными (из сейва).
func mark_exhausted(cells_list: Array) -> void:
	for cell in cells_list:
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

## персистентность: только истощённые точки (нетронутые восстанавливаются
## генерацией). cell_str -> res_id.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for cell in cells:
		var c: Dictionary = cells[cell]
		if c.get("exhausted", false):
			out[str(cell)] = c["res"]
	return out

## персистентность: восстановить истощённые точки из to_dict().
func restore_from_dict(data: Dictionary) -> void:
	for key in data:
		var cell := _parse_cell(str(key))
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

func _parse_cell(s: String) -> Vector2i:
	# (x,y) -> Vector2i
	var inner := s.trim_prefix("(").trim_suffix(")")
	var parts: Array = inner.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

## персистентность: визуал — истощена ли клетка точки добычи.
func is_exhausted(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and c.get("exhausted", false)
