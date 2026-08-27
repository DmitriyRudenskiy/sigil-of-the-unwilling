extends Node2D
## Приёмочный тест Stage 1: остров каждого биома + update_terrain()

func _ready() -> void:
    var tm := TileMapLayer.new()
    tm.tile_set = load("res://tilesets/hex_tileset.tres")
    add_child(tm)
    var W := 24
    var H := 22
    for y in H:
        for x in W:
            tm.set_cell(Vector2i(x, y), TerrainAtlasMap.SOURCE_ID, TerrainAtlasMap.CENTER_COORDS[3])
    _blob(tm, Vector2i(4, 5), 3, 0)    # вода
    _blob(tm, Vector2i(11, 6), 3, 2)  # песок
    _blob(tm, Vector2i(18, 6), 2, 4)  # лес
    _blob(tm, Vector2i(11, 15), 2, 5) # горы
    _blob(tm, Vector2i(18, 15), 2, 6) # снег
    if tm.has_method("update_terrain"):
        tm.call("update_terrain")
    elif tm.has_method("notify_runtime"):
        tm.call("notify_runtime")
    print("[TestTerrain] ready, check borders")

func _blob(tm: TileMapLayer, center: Vector2i, radius: int, terrain: int) -> void:
    for y in range(center.y - radius - 1, center.y + radius + 2):
        for x in range(center.x - radius - 1, center.x + radius + 2):
            var cell := Vector2i(x, y)
            if HexUtils.hex_distance(center, cell) <= radius:
                tm.set_cell(cell, TerrainAtlasMap.SOURCE_ID, TerrainAtlasMap.CENTER_COORDS[terrain])
