extends Node2D
## Демонстрационный полигон сот (**T-344**, пункт 5 задачи). Собирает большое поле
## из *нашего* процедурного листа тем же путём, каким его красит игра: модель
## рельефа → `MapRenderer.paint()` → база + шесть подслоёв переходов. Ничего
## своего про полигоны здесь нет — если соты на этом кадре не смыкаются, дефект в
## листе или в рендерере, а не в демо.
##
## Зачем демо, а не игровой экран: игровой кадр карты показывает три биома и семь
## клеток, на нём нельзя ни разобрать материал каждого биома, ни увидеть все шесть
## сторон перехода. Поле ниже намеренно набито соседствами: снег у воды, лес у
## скалы, болото у луга.
##
## Кадр: `Godot --path game -s tools/shot_scene.gd -- --scene=res://tools/map_art_demo.tscn --out=tmp/shots/x.png`
## Фон — почти чёрный: щель между сотами на таком фоне видна как тёмная волосина,
## а на сером она бы пряталась.

const W := 27
const H := 15
const SEED := 20261106

## Модель только те поля, что читает `MapRenderer`: рельеф, размеры, сид. Всё
## остальное (города, дороги, видимость) демо не касается — оно не участвует в
## вопросе «стыкуются ли соты и читается ли биом».
class _DemoModel:
	var terrain_grid: Dictionary = {}
	var map_width := 0
	var map_height := 0
	var seed_value := 0

var _model: _DemoModel


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.05))
	_model = _make_model()
	_model.terrain_grid = _terrain_grid()
	_model.map_width = W
	_model.map_height = H
	_model.seed_value = SEED
	var renderer: RefCounted = load("res://scripts/world/map_renderer.gd").new(_model)

	var tileset := TileAtlas.build_hex_tileset()
	var base := TileMapLayer.new()
	base.name = "TileMapTerrain"
	base.tile_set = tileset
	add_child(base)

	var root := Node2D.new()
	root.name = "TileMapTransitions"
	add_child(root)
	var layers: Array = []
	for side: String in TileAtlas.SIDES:
		var layer := TileMapLayer.new()
		layer.name = "TileMapTransition_" + side
		layer.tile_set = tileset
		root.add_child(layer)
		layers.append(layer)
	renderer.transition_layers = layers
	renderer.paint(base)

	var camera := Camera2D.new()
	add_child(camera)
	camera.position = base.map_to_local(Vector2i(W / 2, H / 2)) + Vector2(0, 24)
	camera.make_current()


func _make_model() -> _DemoModel:
	return _DemoModel.new()


func _terrain_grid() -> Dictionary:
	var grid: Dictionary = {}
	for y in H:
		for x in W:
			grid[Vector2i(x, y)] = _terrain_at(x, y)
	_features(grid)
	return grid


## Две рукописные полосы поверх шума: шум сам скал и дороги не даёт, а без них
## пункт 2 («скальные плиты», «дорога совместима со слоем дорог») на кадре не
## проверяется. Дорога — тем же биомом базы (Terrain.ROAD → Biome.ROAD); отдельный
## лист дорожного покрытия (`map_roads.gd`) здесь не поднят, это проверка базы.
func _features(grid: Dictionary) -> void:
	for x in W:
		var ry := int(float(H) * 0.52 + 3.0 * sin(float(x) * 0.55))
		for d in 2:
			if ry + d < H:
				grid[Vector2i(x, ry + d)] = HexUtils.Terrain.MOUNTAIN
	for y in H:
		var rx := int(float(W) * 0.58 + 3.2 * cos(float(y) * 0.75))
		grid[Vector2i(rx, y)] = HexUtils.Terrain.ROAD


func _terrain_at(x: int, y: int) -> int:
	# Рельеф — два октавы значения плюс две широтные полосы: середина поля обязана
	# дать извилистые границы, полосы — гарантированные границы снега и воды.
	var h := _noise(x, y, 7.0, 0.62) * 0.65 + _noise(x, y, 3.0, 0.9) * 0.35
	if y < 2:
		return HexUtils.Terrain.SNOW
	if y > H - 3:
		return HexUtils.Terrain.WATER
	if h < 0.30:
		return HexUtils.Terrain.WATER
	if h < 0.37:
		return HexUtils.Terrain.SWAMP
	if h < 0.45:
		return HexUtils.Terrain.SAND
	if h < 0.60:
		return HexUtils.Terrain.GRASS
	if h < 0.74:
		return HexUtils.Terrain.FOREST
	if h < 0.86:
		return HexUtils.Terrain.MOUNTAIN
	return HexUtils.Terrain.SNOW


## Значение в узле решётки с билинейной выборкой — детерминированный шум поля.
func _noise(x: int, y: int, period: float, bias: float) -> float:
	var fx := float(x) / period
	var fy := float(y) / (period * 0.75)
	var ix := int(floorf(fx))
	var iy := int(floorf(fy))
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	var a := _cell_hash(ix, iy)
	var b := _cell_hash(ix + 1, iy)
	var c := _cell_hash(ix, iy + 1)
	var d := _cell_hash(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty) * bias + 0.5 * (1.0 - bias)


func _cell_hash(x: int, y: int) -> float:
	var h := x * 0x9E3779B1 + y * 0x85EBCA77 + SEED * 0xC2B2AE3D
	h = ((h ^ (h >> 15)) * 0x27D4EB2F) & 0xFFFFFFFF
	return float((h ^ (h >> 13)) & 0xFFFF) / 65535.0
