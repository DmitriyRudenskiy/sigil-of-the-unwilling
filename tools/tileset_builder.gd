extends SceneTree
## Stage 1 (v2.1): TileSet builder with AUTOMATIC terrain + peering bit assignment.
## Now supports 7 terrains (including Swamp) and dynamic variants.
## Run via CLI: godot --headless -s tools/tileset_builder.gd

const PROCESSED_DIR := "res://tilesets/processed/"
const ATLAS_PATH := "res://tilesets/hex_atlas.png"
const OUTPUT_PATH := "res://tilesets/hex_tileset.tres"
const MAP_SCRIPT_PATH := "res://scripts/TerrainAtlasMap.gd"
const TILE := 82
const FLAT_TOP := false

const TERRAINS := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]
const TERRAIN_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.2, 0.45, 0.4), Color(0.85, 0.75, 0.45),
    Color(0.35, 0.6, 0.3), Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35),
    Color(0.9, 0.93, 0.98),
]
const BASE_FILES := ["water_base", "swamp_base", "sand_base", "grass_base", "forest_1tree", "mountain_1", "snow_base"]
const OVERRIDES := {"forest_shrub": 3}
const DECOR := ["sand_palm", "sand_cactus"]
const RIVERS := ["river_straight", "river_curve_a", "river_curve_b", "river_diag_a", "river_diag_b"]

func terrain_of_file(name: String) -> int:
    if OVERRIDES.has(name):
        return OVERRIDES[name]
    if name in DECOR or name in RIVERS:
        return -1
    for i in TERRAINS.size():
        if name.begins_with(TERRAINS[i]):
            return i
    return -1

const HOME_COMPAT := {0: [0], 1: [1, 0, 3], 2: [2], 3: [3], 4: [4, 3], 5: [5, 3], 6: [6, 3]}
const MARGIN_SQ := 0.015

const DOC_TO_CELL := [0, 14, 10, 8, 6, 2]
const EDGE_DIRS := [
    Vector2(1, 0), Vector2(0.5, -0.866), Vector2(-0.5, -0.866),
    Vector2(-1, 0), Vector2(-0.5, 0.866), Vector2(0.5, 0.866),
]

var ref_colors: Array[Color] = []
var synth_list: Array[String] = []

func _init() -> void:
    print("=== Stage 1 v2.1: auto TileSet builder ===")
    var files := _list_processed()
    if files.is_empty():
        printerr("ERROR: processed/ is empty. Run binom_cutter first.")
        return

    _synthesize_missing(files)
    files = _list_processed()
    _compute_refs()

    var ordered: Array[String] = []
    for t in 7:
        for f in files:
            if terrain_of_file(f) == t:
                ordered.append(f)
    for f in RIVERS:
        if files.has(f): ordered.append(f)
    for f in DECOR:
        if files.has(f): ordered.append(f)
    for f in files:
        if not ordered.has(f): ordered.append(f)

    var atlas_img := Image.create(TILE * ordered.size(), TILE, false, Image.FORMAT_RGBA8)
    var coords: Dictionary = {}
    for i in ordered.size():
        var timg := _load_tile(ordered[i])
        if timg == null: continue
        atlas_img.blit_rect(timg, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
        coords[ordered[i]] = Vector2i(i, 0)
    atlas_img.save_png(ATLAS_PATH)
    var tex := ImageTexture.create_from_image(atlas_img)

    var ts := TileSet.new()
    ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
    ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
    ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
    ts.tile_size = Vector2i(TILE, TILE)
    ts.add_terrain_set(0)
    ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
    for t in 7:
        ts.add_terrain(0, t)
        ts.set_terrain_name(0, t, TERRAINS[t])
        ts.set_terrain_color(0, t, TERRAIN_COLORS[t])

    var src := TileSetAtlasSource.new()
    src.texture = tex
    src.texture_region_size = Vector2i(TILE, TILE)
    ts.add_source(src, 0)
    for name in coords:
        src.create_tile(coords[name])

    var report_rows: Array[String] = []
    for name in coords:
        var c: Vector2i = coords[name]
        var td: TileData = src.get_tile_data(c, 0)
        if td == null: continue
        var home: int = terrain_of_file(name)
        if home == -1: continue
        td.terrain_set = 0
        td.terrain = home
        var timg := _load_tile(name)
        var bits := _analyze(timg, home)
        var mask := ""
        for b in 6:
            var cn: int = DOC_TO_CELL[b]
            td.set_terrain_peering_bit(cn, bits[b])
            mask += "1" if bits[b] == -1 else "0"
        report_rows.append("| %s | (%d,0) | %s | 0b%s |" % [name, c.x, TERRAINS[home], mask])

    ResourceSaver.save(ts, OUTPUT_PATH)
    _write_map_script(coords)
    _write_report(report_rows)
    print("=== DONE ===")
    quit()

func _analyze(img: Image, home: int) -> Array[int]:
    var res: Array[int] = []
    if img == null:
        for b in 6: res.append(home)
        return res
    var compat: Array = HOME_COMPAT[home]
    var cx := float(img.get_width()) / 2.0
    var cy := float(img.get_height()) / 2.0
    var a := cx * 0.866 * 0.98
    for b in 6:
        var d: Vector2 = EDGE_DIRS[b]
        var perp := Vector2(-d.y, d.x)
        var sum := Color(0, 0, 0, 0)
        var n := 0
        for tf in [0.74, 0.82, 0.90]:
            for of in [-0.18, -0.09, 0.0, 0.09, 0.18]:
                var p: Vector2 = Vector2(cx, cy) + d * (a * tf) + perp * (a * of)
                var xi := int(p.x); var yi := int(p.y)
                if xi < 0 or yi < 0 or xi >= img.get_width() or yi >= img.get_height(): continue
                var px := img.get_pixel(xi, yi)
                if px.a > 0.5:
                    sum += px
                    n += 1
        if n < 4:
            res.append(home)
            continue
        var avg := Color(sum.r / float(n), sum.g / float(n), sum.b / float(n))
        var dists: Array[float] = []
        var nearest := 0
        var bd := 1e9
        for i in 7:
            var r: Color = ref_colors[i]
            var ds := (r.r-avg.r)*(r.r-avg.r) + (r.g-avg.g)*(r.g-avg.g) + (r.b-avg.b)*(r.b-avg.b)
            dists.append(ds)
            if ds < bd:
                bd = ds
                nearest = i
        var d_compat := 1e9
        for ci in compat:
            d_compat = minf(d_compat, dists[ci])
        var foreign := (not compat.has(nearest)) and (d_compat - bd > MARGIN_SQ)
        res.append(-1 if foreign else home)
    return res

func _compute_refs() -> void:
    ref_colors.clear()
    for t in 7:
        var base: String = BASE_FILES[t]
        var img := _load_tile(base)
        if img == null:
            ref_colors.append(TERRAIN_COLORS[t])
            continue
        var cx := float(img.get_width()) / 2.0
        var cy := float(img.get_height()) / 2.0
        var sum := Color(0, 0, 0, 0)
        var n := 0
        for y in range(img.get_height()):
            for x in range(img.get_width()):
                if Vector2(x - cx, y - cy).length() < cx * 0.5:
                    var px := img.get_pixel(x, y)
                    if px.a > 0.5:
                        sum += px
                        n += 1
        ref_colors.append(Color(sum.r / float(n), sum.g / float(n), sum.b / float(n)) if n > 0 else TERRAIN_COLORS[t])

func _synthesize_missing(files: Array[String]) -> void:
    if not files.has("water_base"):
        _save_hex_solid("water_base", TERRAIN_COLORS[0])
        synth_list.append("water_base (solid)")
    if not files.has("snow_base"):
        _save_hex_solid("snow_base", TERRAIN_COLORS[6])
        synth_list.append("snow_base (solid)")

func _save_hex_solid(name: String, col: Color) -> void:
    var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
    var cx := float(TILE) / 2.0
    for y in range(TILE):
        for x in range(TILE):
            var px := float(x) - cx + 0.5
            var py := float(y) - cx + 0.5
            var q := (sqrt(3.0) / 3.0 * px - 1.0 / 3.0 * py) / (cx * 0.98)
            var s := (2.0 / 3.0 * py) / (cx * 0.98)
            if maxf(absf(q), maxf(absf(s), absf(-q - s))) <= 1.0:
                img.set_pixel(x, y, col)
    img.save_png(PROCESSED_DIR + name + ".png")

func _list_processed() -> Array[String]:
    var res: Array[String] = []
    var dir := DirAccess.open(PROCESSED_DIR)
    if dir == null: return res
    dir.list_dir_begin()
    var f := dir.get_next()
    while f != "":
        if f.ends_with(".png"): res.append(f.get_basename())
        f = dir.get_next()
    dir.list_dir_end()
    return res

func _load_tile(name: String) -> Image:
    var path := PROCESSED_DIR + name + ".png"
    if not FileAccess.file_exists(path): return null
    var img := Image.load_from_file(path)
    if img == null: return null
    if img.get_format() != Image.FORMAT_RGBA8: img.convert(Image.FORMAT_RGBA8)
    if img.get_width() != TILE or img.get_height() != TILE: img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
    return img

func _write_map_script(coords: Dictionary) -> void:
    var txt := "class_name TerrainAtlasMap\n"
    txt += "## AUTOGENERATED by tileset_builder.gd - do not edit\n"
    txt += "const SOURCE_ID := 0\n"
    txt += "const CENTER_COORDS := {\n"
    for t in 7:
        for name in coords:
            if terrain_of_file(name) == t and name in BASE_FILES:
                var c: Vector2i = coords[name]
                txt += "\t%d: Vector2i(%d, %d),\n" % [t, c.x, c.y]
    txt += "}\n"
    txt += "const DECOR_COORDS := {\n"
    for name in DECOR:
        if coords.has(name):
            var c: Vector2i = coords[name]
            txt += "\t\"%s\": Vector2i(%d, %d),\n" % [name, c.x, c.y]
    txt += "}\n"
    txt += "const RIVER_COORDS := [\n"
    for name in RIVERS:
        if coords.has(name):
            var c: Vector2i = coords[name]
            txt += "\tVector2i(%d, %d),\n" % [c.x, c.y]
    txt += "]\n"
    txt += "const VARIANTS := {\n"
    for t in 7:
        var list := ""
        for name in coords:
            if terrain_of_file(name) == t and (name.find("_v") != -1):
                var c: Vector2i = coords[name]
                list += "\t\tVector2i(%d, %d),\n" % [c.x, c.y]
        txt += "\t%d: [\n%s\t],\n" % [t, list]
    txt += "}\n"
    var fa := FileAccess.open(MAP_SCRIPT_PATH, FileAccess.WRITE)
    if fa: fa.store_string(txt)

func _write_report(rows: Array[String]) -> void:
    var txt := "\n## Приложение A: Stage 1 (автоназначение, tileset_builder v2.1)\n\n"
    txt += "Ориентация: %s-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.\n" % ["flat" if FLAT_TOP else "pointy"]
    txt += "Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).\n\n"
    txt += "| Тайл | Atlas | Террейн | Маска |\n|---|---|---|---|\n"
    for r in rows: txt += r + "\n"
    txt += "\nСинтезированные временные тайлы:\n"
    if synth_list.is_empty(): txt += "- нет\n"
    else:
        for s in synth_list: txt += "- %s\n" % s
    var fa := FileAccess.open("res://REPORT.md", FileAccess.READ_WRITE)
    if fa:
        fa.seek_end()
        fa.store_string(txt)
