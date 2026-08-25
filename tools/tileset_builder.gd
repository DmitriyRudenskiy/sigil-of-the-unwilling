@tool
extends EditorScript
## Stage 1 (v2): TileSet builder with AUTOMATIC terrain + peering bit assignment.
## Алгоритм: для каждого тайла семплируем цвет у 6 рёбер гекса, сравниваем с
## эталонными цветами биомов; если на ребре "чужой" биом -> peering bit = -1,
## иначе = id своего террейна. Run: File > Run Script (Ctrl+Shift+X).

const PROCESSED_DIR := "res://tilesets/processed/"
const ATLAS_PATH := "res://tilesets/hex_atlas.png"
const OUTPUT_PATH := "res://tilesets/hex_tileset.tres"
const MAP_SCRIPT_PATH := "res://scripts/TerrainAtlasMap.gd"
const TILE := 82
const FLAT_TOP := false  # если Stage 0 показал flat-top -> true и пересобрать

const TERRAINS := ["water", "sand", "grass", "forest", "mountain", "snow"]
const TERRAIN_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.85, 0.75, 0.45), Color(0.35, 0.6, 0.3),
    Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35), Color(0.9, 0.93, 0.98),
]
const BASE_FILES := ["water_base", "sand_base", "grass_base", "forest_1tree", "mountain_1", "snow_base"]

const FILE_TO_TERRAIN := {
    "water_base": 0, "water_corner": 0,
    "sand_base": 1, "sand_dunes": 1, "sand_pebbles": 1, "sand_grass": 1,
    "grass_base": 2, "grass_dry": 2, "forest_shrub": 2,
    "forest_1tree": 3, "forest_2trees": 3,
    "mountain_1": 4, "mountain_3a": 4, "mountain_3b": 4,
    "snow_base": 5,
}
const DECOR := ["sand_palm", "sand_cactus"]
const RIVERS := ["river_straight", "river_curve_a", "river_curve_b", "river_diag_a", "river_diag_b"]

## doc bits [E,NE,NW,W,SW,SE] -> TileSet.CellNeighbor (pointy-top)
const DOC_TO_CELL := [
    0,   # CELL_NEIGHBOR_RIGHT_SIDE        (E)
    14,  # CELL_NEIGHBOR_TOP_RIGHT_SIDE    (NE)
    10,  # CELL_NEIGHBOR_TOP_LEFT_SIDE     (NW)
    8,   # CELL_NEIGHBOR_LEFT_SIDE         (W)
    6,   # CELL_NEIGHBOR_BOTTOM_LEFT_SIDE  (SW)
    2,   # CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE (SE)
]
const EDGE_DIRS := [
    Vector2(1, 0), Vector2(0.5, -0.866), Vector2(-0.5, -0.866),
    Vector2(-1, 0), Vector2(-0.5, 0.866), Vector2(0.5, 0.866),
]
## Какие цвета рёбер считаем "своими" для каждого террейна
## (лес растёт на траве, пики гор стоят на траве и т.д.)
const HOME_COMPAT := {0: [0], 1: [1], 2: [2], 3: [3, 2], 4: [4, 2], 5: [5, 2]}
const MARGIN_SQ := 0.015  # порог уверенности различия цветов (0..1)

var ref_colors: Array[Color] = []
var synth_list: Array[String] = []


func _run() -> void:
    print("=== Stage 1 v2: auto TileSet builder ===")
    var files := _list_processed()
    if files.is_empty():
        printerr("ERROR: processed/ is empty. Run Stage 0 first.")
        return

    _synthesize_missing(files)
    files = _list_processed()
    _compute_refs()

    # Порядок тайлов в атласе: по террейнам, затем реки, декор, остатки
    var ordered: Array[String] = []
    for t in 6:
        for f in files:
            var ft: int = FILE_TO_TERRAIN.get(f, -9)
            if ft == t:
                ordered.append(f)
    for f in RIVERS:
        if files.has(f): ordered.append(f)
    for f in DECOR:
        if files.has(f): ordered.append(f)
    for f in files:
        if not ordered.has(f): ordered.append(f)

    # Сборка атласа
    var atlas_img := Image.create(TILE * ordered.size(), TILE, false, Image.FORMAT_RGBA8)
    var coords: Dictionary = {}
    for i in ordered.size():
        var timg := _load_tile(ordered[i])
        if timg == null:
            continue
        atlas_img.blit_rect(timg, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
        coords[ordered[i]] = Vector2i(i, 0)
    atlas_img.save_png(ATLAS_PATH)
    var tex := ImageTexture.create_from_image(atlas_img)
    print("Atlas saved: %s (%d tiles)" % [ATLAS_PATH, coords.size()])

    # TileSet + terrain set
    var ts := TileSet.new()
    ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
    ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
    ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
    ts.tile_size = Vector2i(TILE, TILE)
    ts.add_terrain_set(0)
    ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
    for t in 6:
        ts.add_terrain(0, t)
        ts.set_terrain_name(0, t, TERRAINS[t])
        ts.set_terrain_color(0, t, TERRAIN_COLORS[t])

    var src := TileSetAtlasSource.new()
    src.texture = tex
    src.texture_region_size = Vector2i(TILE, TILE)
    ts.add_source(src, 0)
    for name in coords:
        var c: Vector2i = coords[name]
        src.create_tile(c)

    # АВТОНАЗНАЧЕНИЕ terrain + peering bits
    var report_rows: Array[String] = []
    for name in coords:
        var c: Vector2i = coords[name]
        var td: TileData = src.get_tile_data(c, 0)
        if td == null:
            continue
        if not FILE_TO_TERRAIN.has(name):
            continue  # реки/декор - без террейна
        var home: int = FILE_TO_TERRAIN[name]
        td.terrain_set = 0
        td.terrain = home
        var timg := _load_tile(name)
        var bits := _analyze(timg, home)
        var mask := ""
        for b in 6:
            var cn: int = DOC_TO_CELL[b]
            if td.is_valid_terrain_peering_bit(cn):
                td.set_terrain_peering_bit(cn, bits[b])
            else:
                print("WARN: invalid peering bit %d for %s (orientation mismatch? set FLAT_TOP)" % [cn, name])
            mask += "1" if bits[b] == -1 else "0"
        report_rows.append("| %s | (%d,0) | %s | 0b%s |" % [name, c.x, TERRAINS[home], mask])
        print("  %-16s terrain=%s mask=0b%s" % [name, TERRAINS[home], mask])

    ResourceSaver.save(ts, OUTPUT_PATH)
    print("TileSet saved: ", OUTPUT_PATH)

    _write_map_script(coords)
    _write_report(report_rows)
    print("=== DONE. Next: run scenes/TestTerrain.tscn to verify transitions ===")


# ================= ANALYSIS =================
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
            var t: float = tf
            for of in [-0.18, -0.09, 0.0, 0.09, 0.18]:
                var o: float = of
                var p := Vector2(cx, cy) + d * (a * t) + perp * (a * o)
                var xi := int(p.x)
                var yi := int(p.y)
                if xi < 0 or yi < 0 or xi >= img.get_width() or yi >= img.get_height():
                    continue
                var px := img.get_pixel(xi, yi)
                if px.a > 0.5:
                    sum += px
                    n += 1
        if n < 4:
            res.append(home)  # прозрачное ребро -> считаем своим
            continue
        var avg := Color(sum.r / float(n), sum.g / float(n), sum.b / float(n))
        var dists: Array[float] = []
        var nearest := 0
        var bd := 1e9
        for i in 6:
            var r: Color = ref_colors[i]
            var ds := (r.r-avg.r)*(r.r-avg.r) + (r.g-avg.g)*(r.g-avg.g) + (r.b-avg.b)*(r.b-avg.b)
            dists.append(ds)
            if ds < bd:
                bd = ds
                nearest = i
        var d_compat := 1e9
        for ci in compat:
            var cv: int = ci
            d_compat = minf(d_compat, dists[cv])
        var foreign := (not compat.has(nearest)) and (d_compat - bd > MARGIN_SQ)
        res.append(-1 if foreign else home)
    return res


func _compute_refs() -> void:
    ref_colors.clear()
    for t in 6:
        var base: String = BASE_FILES[t]
        var img := _load_tile(base)
        if img == null:
            ref_colors.append(TERRAIN_COLORS[t])
            continue
        # средний цвет непрозрачных пикселей в центре
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
        if n > 0:
            ref_colors.append(Color(sum.r / float(n), sum.g / float(n), sum.b / float(n)))
        else:
            ref_colors.append(TERRAIN_COLORS[t])


# ================= SYNTHESIS =================
func _synthesize_missing(files: Array[String]) -> void:
    if not files.has("water_base"):
        var src_img := _load_tile("river_straight")
        var col: Color = TERRAIN_COLORS[0]
        if src_img != null:
            col = _avg_opaque(src_img)
        _save_hex_solid("water_base", col)
        synth_list.append("water_base (заливка из палитры river_straight)")
    if not files.has("snow_base"):
        var g := _load_tile("grass_base")
        if g != null:
            for y in range(g.get_height()):
                for x in range(g.get_width()):
                    var px := g.get_pixel(x, y)
                    if px.a > 0.5:
                        g.set_pixel(x, y, px.lerp(Color(0.92, 0.95, 1.0), 0.75))
            g.save_png(PROCESSED_DIR + "snow_base.png")
            synth_list.append("snow_base (модуляция grass_base в бело-синий)")
        else:
            _save_hex_solid("snow_base", TERRAIN_COLORS[5])
            synth_list.append("snow_base (заливка)")


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


# ================= IO =================
func _list_processed() -> Array[String]:
    var res: Array[String] = []
    var dir := DirAccess.open(PROCESSED_DIR)
    if dir == null:
        return res
    dir.list_dir_begin()
    var f := dir.get_next()
    while f != "":
        if f.ends_with(".png"):
            res.append(f.get_basename())
        f = dir.get_next()
    dir.list_dir_end()
    return res


func _load_tile(name: String) -> Image:
    var path := PROCESSED_DIR + name + ".png"
    if not FileAccess.file_exists(path):
        return null
    var img := Image.load_from_file(path)
    if img == null:
        return null
    if img.get_format() != Image.FORMAT_RGBA8:
        img.convert(Image.FORMAT_RGBA8)
    if img.get_width() != TILE or img.get_height() != TILE:
        img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
    return img


func _avg_opaque(img: Image) -> Color:
    var sum := Color(0, 0, 0, 0)
    var n := 0
    for y in range(0, img.get_height(), 2):
        for x in range(0, img.get_width(), 2):
            var px := img.get_pixel(x, y)
            if px.a > 0.5:
                sum += px
                n += 1
    if n == 0:
        return TERRAIN_COLORS[0]
    return Color(sum.r / float(n), sum.g / float(n), sum.b / float(n))


func _write_map_script(coords: Dictionary) -> void:
    var txt := "class_name TerrainAtlasMap\n"
    txt += "## AUTOGENERATED by tileset_builder.gd - do not edit\n"
    txt += "const SOURCE_ID := 0\n"
    txt += "const CENTER_COORDS := {\n"
    for t in 6:
        for name in coords:
            var ft: int = FILE_TO_TERRAIN.get(name, -9)
            if ft == t and name in BASE_FILES:
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
    var fa := FileAccess.open(MAP_SCRIPT_PATH, FileAccess.WRITE)
    if fa:
        fa.store_string(txt)
    print("Generated: ", MAP_SCRIPT_PATH)


func _write_report(rows: Array[String]) -> void:
    var txt := "\n## Приложение A: Stage 1 (автоназначение, tileset_builder v2)\n\n"
    txt += "Ориентация: %s-top. Peering bits (CellNeighbor): E=0, SE=2, SW=6, W=8, NW=10, NE=14.\n" % ["flat" if FLAT_TOP else "pointy"]
    txt += "Маска 0b###### в порядке doc-битов [E,NE,NW,W,SW,SE]; 1 = на ребре чужой биом (peering=-1).\n\n"
    txt += "| Тайл | Atlas | Террейн | Маска |\n|---|---|---|---|\n"
    for r in rows:
        txt += r + "\n"
    txt += "\nСинтезированные временные тайлы:\n"
    if synth_list.is_empty():
        txt += "- нет\n"
    else:
        for s in synth_list:
            txt += "- %s\n" % s
    txt += "\nВариативность: тайлы с одинаковой маской (sand_base/dunes/pebbles, forest_1tree/2trees, mountain_*) движок выбирает случайно по probability.\n"
    var fa := FileAccess.open("res://REPORT.md", FileAccess.READ_WRITE)
    if fa:
        fa.seek_end()
        fa.store_string(txt)
    else:
        printerr("Cannot append REPORT.md")
