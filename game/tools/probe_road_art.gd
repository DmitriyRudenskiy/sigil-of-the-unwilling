extends SceneTree

# Зонд T-3xx: почему декали дорог на кадре читаются прямоугольниками.
# Печатает геометрию тайлсетов (база/дороги/объекты) и альфу листов. Headless.
#   Godot --path game --headless --script tools/probe_road_art.gd

func _initialize() -> void:
	var ts := HexCellArt.build_hex()
	_dump("база (HexCellArt)", ts)
	var rts := MapRoads.build_tileset()
	_dump("дороги (MapRoads)", rts)
	var ots := MapObjects.build_tileset()
	_dump("объекты (MapObjects)", ots)
	_alpha("лист дорог", MapRoads.SHEET_PATH)
	_alpha("лист дорог (туман)", MapRoads.FOG_SHEET_PATH)
	quit(0)


func _dump(label: String, ts: TileSet) -> void:
	if ts == null:
		print("%-22s тайлсет НЕ построен" % label)
		return
	print("%-22s tile_size=%s shape=%d" % [label, ts.tile_size, ts.tile_shape])
	for i in ts.get_source_count():
		var id: int = ts.get_source_id(i)
		var src: TileSetAtlasSource = ts.get_source(id) as TileSetAtlasSource
		if src == null:
			print("   источник %d: не AtlasSource" % id)
			continue
		var tex: Texture2D = src.texture
		var n := src.get_tiles_count()
		print("   источник %d: region=%s тайлов=%d текстура=%s формат=%d" % [
			id, src.texture_region_size, n,
			tex.get_size() if tex != null else "null",
			tex.get_image().get_format() if tex != null else -1])
		# Квадратный регион при неквадратной клетке = срез листа не по клетке.
		if src.texture_region_size != ts.tile_size:
			print("   !! region %s != tile_size %s" % [src.texture_region_size, ts.tile_size])


func _alpha(label: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		print("%-22s файла нет" % label)
		return
	var img: Image = (load(path) as Texture2D).get_image()
	var transparent := 0
	var opaque := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			if img.get_pixel(x, y).a < 0.01:
				transparent += 1
			else:
				opaque += 1
	print("%-22s %s формат=%d  прозрачных %d  непрозрачных %d" % [
		label, img.get_size(), img.get_format(), transparent, opaque])
