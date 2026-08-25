extends SceneTree
## Check tileset integrity: existence, resources, and TerrainAtlasMap.
## Run: godot --headless -s tools/check_tileset.gd

const TerrainAtlasMapScript = preload("res://scripts/TerrainAtlasMap.gd")

var failed := 0
var passed := 0

func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		printerr("  FAIL  ", name, " — ", detail)


func _init() -> void:
	print("=== Tileset check ===")

	# 1. File exists
	var tileset_path := "res://tilesets/hex_tileset.tres"
	check("tileset file exists", FileAccess.file_exists(tileset_path))

	# 2. Resource loads
	var ts := load(tileset_path)
	check("tileset loads", ts != null, "%s" % ts)
	check("tileset is TileSet", ts is TileSet, "%s" % ts.get_class())

	# 3. Has source 0
	var has_source: bool = ts.has_source(0) if ts is TileSet else false
	check("has source 0", has_source)

	# 4. TerrainAtlasMap has 7 biomes
	var coords := TerrainAtlasMapScript.CENTER_COORDS
	for t in 7:
		check("biome %d in CENTER_COORDS" % t, coords.has(t))

	# 5. All coords are valid Vector2i
	for t in 7:
		if coords.has(t):
			var c = coords[t]
			check("biome %d is Vector2i" % t, c is Vector2i, "%s" % str(c))

	# 6. Swamp specifically
	check("swamp (id=1) present", coords.has(1), "missing swamp!")

	print("\n=== %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
