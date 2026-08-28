extends Node

const PROCESSED_DIR := "res://tilesets/processed/"
const OUTPUT_PATH := "res://tilesets/hex_tileset.tres"
const TILE_SIZE := Vector2i(82, 82)

const TERRAIN_DEFS := [
    {"id": 0, "name": "water", "color": Color(0.2, 0.4, 0.8)},
    {"id": 1, "name": "sand", "color": Color(0.9, 0.8, 0.4)},
    {"id": 2, "name": "grass", "color": Color(0.3, 0.7, 0.3)},
    {"id": 3, "name": "forest", "color": Color(0.1, 0.5, 0.1)},
    {"id": 4, "name": "mountain", "color": Color(0.5, 0.4, 0.3)},
    {"id": 5, "name": "snow", "color": Color(0.9, 0.95, 1.0)},
]

const FILE_TO_TERRAIN := {
    "water_base": 0,
    "water_corner": 0,
    "sand_base": 1,
    "sand_dunes": 1,
    "sand_pebbles": 1,
    "sand_grass": 1,
    "grass_base": 2,
    "grass_dry": 2,
    "forest_1tree": 3,
    "forest_2trees": 3,
    "forest_shrub": 3,
    "mountain_1": 4,
    "mountain_3a": 4,
    "mountain_3b": 4,
    "snow_base": 5,
    "river_straight": -1,
    "river_curve_a": -1,
    "river_curve_b": -1,
    "river_diag_a": -1,
    "river_diag_b": -1,
}

const DECOR_FILES := ["sand_palm", "sand_cactus"]

const BIT_MAPPING := {
    "doc_bit_0_E": "godot_peering_0_Right",
    "doc_bit_1_NE": "godot_peering_5_TopRight",
    "doc_bit_2_NW": "godot_peering_4_TopLeft",
    "doc_bit_3_W": "godot_peering_3_Left",
    "doc_bit_4_SW": "godot_peering_2_BottomLeft",
    "doc_bit_5_SE": "godot_peering_1_BottomRight",
}

func _ready() -> void:
    print("=== Running TileSet Builder (CLI) ===")
    run_builder()
    get_tree().quit()

func run_builder() -> void:
    var dir := DirAccess.open(PROCESSED_DIR)
    if dir == null:
        printerr("ERROR: Processed directory not found: ", PROCESSED_DIR)
        return
    
    var available_tiles: Array[String] = []
    dir.list_dir_begin()
    var fname := dir.get_next()
    while fname != "":
        if fname.ends_with(".png"):
            available_tiles.append(fname.get_basename())
        fname = dir.get_next()
    dir.list_dir_end()
    
    var tileset := TileSet.new()
    tileset.resource_name = "hex_tileset"
    tileset.tile_shape = TileSet.TILE_SHAPE_HEXAGON
    tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
    tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
    tileset.tile_size = TILE_SIZE
    
    var atlas := TileSetAtlasSource.new()
    atlas.texture_region_size = TILE_SIZE
    
    var atlas_img := Image.create(TILE_SIZE.x * available_tiles.size(), TILE_SIZE.y, false, Image.FORMAT_RGBA8)
    var x_offset := 0
    var tile_coords: Array[Vector2i] = []
    for tile_name in available_tiles:
        var img := Image.load_from_file(PROCESSED_DIR + tile_name + ".png")
        if img == null: continue
        atlas_img.blit_rect(img, Rect2i(0, 0, TILE_SIZE.x, TILE_SIZE.y), Vector2i(x_offset, 0))
        tile_coords.append(Vector2i(x_offset / TILE_SIZE.x, 0))
        x_offset += TILE_SIZE.x
    
    var atlas_tex := ImageTexture.create_from_image(atlas_img)
    atlas.texture = atlas_tex
    atlas.texture_region_size = TILE_SIZE
    
    for i in tile_coords.size():
        atlas.create_tile(tile_coords[i])
    
    tileset.add_source(atlas, 0)
    
    # Godot 4.7: плоский terrain-API на TileSet (TileSetTerrainSet/TileSetTerrain удалены)
    tileset.add_terrain_set(0)
    var terrain_set_idx: int = tileset.get_terrain_sets_count() - 1
    tileset.set_terrain_set_mode(terrain_set_idx, TileSet.TerrainMode.TERRAIN_MODE_MATCH_SIDES)
    for i in TERRAIN_DEFS.size():
        var tdef: Dictionary = TERRAIN_DEFS[i]
        tileset.add_terrain(terrain_set_idx, -1)
        var terrain_idx: int = tileset.get_terrains_count(terrain_set_idx) - 1
        tileset.set_terrain_name(terrain_set_idx, terrain_idx, str(tdef["name"]))
        tileset.set_terrain_color(terrain_set_idx, terrain_idx, tdef["color"])
    
    ResourceSaver.save(tileset, OUTPUT_PATH)
    _generate_report(available_tiles, tile_coords)
    print("TileSet saved to: ", OUTPUT_PATH)

func _generate_report(available_tiles: Array[String], tile_coords: Array[Vector2i]) -> void:
    var report := "\n\n## Таблица маппинга тайлов (сгенерировано tileset_builder.gd)\n\n"
    report += "| Тайл | Индекс в атласе | Террейн | Тип |\n"
    report += "|------|-----------------|---------|-----|\n"
    for i in available_tiles.size():
        var tile_name := available_tiles[i]
        var coord := tile_coords[i]
        var terrain_id: int = FILE_TO_TERRAIN.get(tile_name, -1)
        var terrain_name: String = str(TERRAIN_DEFS[terrain_id]["name"]) if terrain_id >= 0 else "N/A"
        var tile_type := "декор" if tile_name in DECOR_FILES else ("террейн" if terrain_id >= 0 else "река")
        report += "| %s | (%d, 0) | %s | %s |\n" % [tile_name, coord.x, terrain_name, tile_type]
    
    report += "\n## Peering Bits Mapping (pointy-top hex)\n\n"
    report += "| Документация | Godot 4.7 | Направление |\n"
    report += "|--------------|-----------|-------------|\n"
    for doc_bit in BIT_MAPPING:
        report += "| %s | %s | %s |\n" % [doc_bit, BIT_MAPPING[doc_bit], doc_bit.substr(8)]
    
    var report_file := FileAccess.open("res://REPORT.md", FileAccess.READ)
    var report_content := ""
    if report_file:
        report_content = report_file.get_as_text()
        report_file.close()
    
    var insert_pos := report_content.find("## Известные баги")
    if insert_pos == -1: insert_pos = report_content.length()
    report_content = report_content.insert(insert_pos, report)
    
    var report_write := FileAccess.open("res://REPORT.md", FileAccess.WRITE)
    if report_write:
        report_write.store_string(report_content)
        report_write.close()
