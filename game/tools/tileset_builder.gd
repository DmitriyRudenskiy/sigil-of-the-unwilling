extends SceneTree
## TileSet Builder v4 — разделение фон/объекты через подпапки.
##
## Структура:
##   res://tilesets/processed/{biome}/base/*.png    → фоновые тайлы
##   res://tilesets/processed/{biome}/objects/*.png → объекты (декор)
##
## Результат:
##   - Источник 0: фоновые тайлы (основной слой)
##   - Источник 1: объектные тайлы (декор-слой)
##
## Запуск:
##   godot --path . --headless -s tools/tileset_builder.gd

const PROCESSED_DIR := "res://tilesets/processed/"
const ATLAS_PATH := "res://tilesets/hex_atlas_base.png"
const ATLAS_OBJ_PATH := "res://tilesets/hex_atlas_objects.png"
const OUTPUT_PATH := "res://tilesets/hex_tileset.tres"
const MAP_SCRIPT_PATH := "res://world/TerrainAtlasMap.gd"
const TILE := 82

const TERRAINS := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]
const TERRAIN_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.2, 0.45, 0.4), Color(0.85, 0.75, 0.45),
    Color(0.35, 0.6, 0.3), Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35),
    Color(0.9, 0.93, 0.98),
]

const DOC_TO_CELL := [0, 14, 10, 8, 6, 2]
const EDGE_DIRS := [
    Vector2(1, 0), Vector2(0.5, -0.866), Vector2(-0.5, -0.866),
    Vector2(-1, 0), Vector2(-0.5, 0.866), Vector2(0.5, 0.866),
]
const HOME_COMPAT := {
    0: [0], 1: [1, 0, 3], 2: [2], 3: [3], 4: [4, 3], 5: [5, 3], 6: [6, 3],
}
const MARGIN_SQ := 0.015

var ref_colors: Array[Color] = []
var synth_log: Array[String] = []

# Данные сканирования
var base_tiles: Dictionary = {}   # biome_name → Array[Image]
var obj_tiles: Dictionary = {}    # biome_name → Array[Image]
var tile_terrain: Dictionary = {} # tile_name → terrain_id

# ===================== ENTRY =====================
func _init() -> void:
    print("=== TileSet Builder v4 (base + objects) ===")

    # 1. Сканируем папки
    _scan_biome_folders()
    if base_tiles.is_empty():
        printerr("❌ No base textures found. Check structure: processed/{biome}/base/")
        quit(1)
        return

    # 2. Синтезируем недостающие фоны
    _synthesize_missing_backgrounds()

    # 3. Вычисляем референсные цвета
    _compute_refs()

    # 4. Строим атлас фонов
    var base_ordered := _build_ordered_base()
    var base_atlas := _build_atlas(base_ordered)
    base_atlas.save_png(ATLAS_PATH)
    print("🖼️  Base atlas: %s (%d tiles)" % [ATLAS_PATH, base_ordered.size()])

    # 5. Строим атлас объектов
    var obj_ordered := _build_ordered_objects()
    var obj_atlas := _build_atlas(obj_ordered)
    obj_atlas.save_png(ATLAS_OBJ_PATH)
    print("🖼️  Objects atlas: %s (%d tiles)" % [ATLAS_OBJ_PATH, obj_ordered.size()])

    # 6. Создаём TileSet с двумя источниками
    var base_coords := _build_tileset(base_atlas, base_ordered, obj_atlas, obj_ordered)

    # 7. Генерируем TerrainAtlasMap
    _write_map_script(base_coords, obj_ordered)

    # 8. Отчёт
    _write_report(base_ordered, obj_ordered)

    print("=== DONE: %d base + %d object tiles ===" % [base_ordered.size(), obj_ordered.size()])
    quit(0)

# ===================== 1. СКАНИРОВАНИЕ =====================
func _scan_biome_folders() -> void:
    var dir := DirAccess.open(PROCESSED_DIR)
    if dir == null:
        printerr("Cannot open: %s" % PROCESSED_DIR)
        return

    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        if dir.current_is_dir():
            var biome_name := entry.to_lower()
            if TERRAINS.has(biome_name):
                # Сканируем подпапку base/
                var base_path := PROCESSED_DIR + entry + "/base/"
                var base_imgs := _load_all_images(base_path)
                if base_imgs.size() > 0:
                    base_tiles[biome_name] = base_imgs
                    print("  📁 %s/base: %d textures" % [biome_name, base_imgs.size()])

                # Сканируем подпапку objects/
                var obj_path := PROCESSED_DIR + entry + "/objects/"
                var obj_imgs := _load_all_images(obj_path)
                if obj_imgs.size() > 0:
                    obj_tiles[biome_name] = obj_imgs
                    print("  📁 %s/objects: %d textures" % [biome_name, obj_imgs.size()])
                else:
                    print("  📁 %s/objects: empty (no decor)" % biome_name)
            else:
                print("  ⏭️  Skipping unknown folder: %s" % entry)
        entry = dir.get_next()
    dir.list_dir_end()

    # Подсчёт
    var total_base := 0
    var total_obj := 0
    for b in base_tiles:
        total_base += base_tiles[b].size()
    for b in obj_tiles:
        total_obj += obj_tiles[b].size()
    print("📂 Total: %d base, %d objects across %d biomes" % [total_base, total_obj, base_tiles.size()])

func _load_all_images(path: String) -> Array[Image]:
    var images: Array[Image] = []
    var dir := DirAccess.open(path)
    if dir == null:
        return images

    dir.list_dir_begin()
    var f := dir.get_next()
    while f != "":
        if not dir.current_is_dir():
            var ext := f.get_extension().to_lower()
            if ext in ["png", "jpg", "jpeg", "webp"]:
                var img := Image.load_from_file(path + f)
                if img != null:
                    if img.get_format() != Image.FORMAT_RGBA8:
                        img.convert(Image.FORMAT_RGBA8)
                    if img.get_width() != TILE or img.get_height() != TILE:
                        img.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
                    _apply_hex_mask(img)
                    images.append(img)
        f = dir.get_next()
    dir.list_dir_end()
    return images

# ===================== 2. СИНТЕЗ НЕДОСТАЮЩИХ =====================
func _synthesize_missing_backgrounds() -> void:
    for t in TERRAINS.size():
        var biome_name: String = TERRAINS[t]
        if not base_tiles.has(biome_name):
            var solid := _make_solid_hex(TERRAIN_COLORS[t])
            base_tiles[biome_name] = [solid] as Array[Image]
            synth_log.append("%s_base (solid color fill)" % biome_name)
            print("  🎨 Synthesized background: %s" % biome_name)

# ===================== 3. РЕФЕРЕНСНЫЕ ЦВЕТА =====================
func _compute_refs() -> void:
    ref_colors.clear()
    for t in TERRAINS.size():
        var biome_name: String = TERRAINS[t]
        if not base_tiles.has(biome_name) or base_tiles[biome_name].is_empty():
            ref_colors.append(TERRAIN_COLORS[t])
            continue
        var img: Image = base_tiles[biome_name][0]
        var sum := Color(0, 0, 0, 0)
        var n := 0
        var cx := float(TILE) / 2.0
        for y in TILE:
            for x in TILE:
                if Vector2(x - cx, y - cx).length() < cx * 0.5:
                    var px := img.get_pixel(x, y)
                    if px.a > 0.5:
                        sum += px
                        n += 1
        if n > 0:
            ref_colors.append(Color(sum.r / n, sum.g / n, sum.b / n))
        else:
            ref_colors.append(TERRAIN_COLORS[t])

# ===================== 4. ПОРЯДОК АТЛАСОВ =====================
func _build_ordered_base() -> Array[String]:
    var ordered: Array[String] = []
    for t in TERRAINS.size():
        var biome_name: String = TERRAINS[t]
        if not base_tiles.has(biome_name):
            continue
        var imgs = base_tiles[biome_name]
        # Сортируем по сложности — самый простой = base
        var scored := [] as Array[Dictionary]
        for i in imgs.size():
            scored.append({"img": imgs[i], "score": _complexity_score(imgs[i]), "idx": i})
        scored.sort_custom(func(a, b): return a["score"] < b["score"])

        # Первый = base
        var base_name := "%s_base" % biome_name
        var ordered_imgs := [] as Array
        for item in scored:
            var name := "%s_base" % biome_name if item["idx"] == scored[0]["idx"] else "%s_v%02d" % [biome_name, item["idx"]]
            ordered.append(name)
            tile_terrain[name] = t
            ordered_imgs.append(item["img"])
        base_tiles[biome_name + "_ordered"] = ordered_imgs
    return ordered

func _build_ordered_objects() -> Array[String]:
    var ordered: Array[String] = []
    for t in TERRAINS.size():
        var biome_name: String = TERRAINS[t]
        if not obj_tiles.has(biome_name):
            continue
        var imgs: Array[Image] = obj_tiles[biome_name]
        for i in imgs.size():
            var name := "%s_obj_%02d" % [biome_name, i]
            ordered.append(name)
            tile_terrain[name] = t
    return ordered

# ===================== 5. АТЛАСЫ =====================
func _build_atlas(ordered: Array[String]) -> Image:
    if ordered.is_empty():
        return Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
    var atlas := Image.create(TILE * ordered.size(), TILE, false, Image.FORMAT_RGBA8)
    for i in ordered.size():
        var img := _get_tile_image(ordered[i])
        if img != null:
            atlas.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
    return atlas

func _get_tile_image(name: String) -> Image:
    # Ищем в сохранённых данных
    for t in TERRAINS.size():
        var biome_name: String = TERRAINS[t]
        # Проверяем упорядоченные базы
        var ordered_key := biome_name + "_ordered"
        if base_tiles.has(ordered_key):
            var arr: Array = base_tiles[ordered_key]
            # Ищем индекс по имени
            var base_name := "%s_base" % biome_name
            if name == base_name and arr.size() > 0:
                return arr[0]
            var prefix := biome_name + "_v"
            if name.begins_with(prefix):
                var idx_str := name.substr(prefix.length())
                var idx := int(idx_str)
                if idx < arr.size():
                    return arr[idx]
        # Проверяем объекты
        if obj_tiles.has(biome_name):
            var obj_prefix := "%s_obj_" % biome_name
            if name.begins_with(obj_prefix):
                var idx_str := name.substr(obj_prefix.length())
                var idx := int(idx_str)
                var imgs: Array[Image] = obj_tiles[biome_name]
                if idx < imgs.size():
                    return imgs[idx]
    return null

# ===================== 6. TILESET =====================
func _build_tileset(base_atlas: Image, base_ordered: Array[String], obj_atlas: Image, obj_ordered: Array[String]) -> Dictionary:
    var ts := TileSet.new()
    ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
    ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
    ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
    ts.tile_size = Vector2i(TILE, TILE)

    # Террейны
    ts.add_terrain_set(0)
    ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
    for t in TERRAINS.size():
        ts.add_terrain(0, t)
        ts.set_terrain_name(0, t, TERRAINS[t])
        ts.set_terrain_color(0, t, TERRAIN_COLORS[t])

    # === Источник 0: ФОН ===
    var base_tex := ImageTexture.create_from_image(base_atlas)
    var src_base := TileSetAtlasSource.new()
    src_base.texture = base_tex
    src_base.texture_region_size = Vector2i(TILE, TILE)
    ts.add_source(src_base, 0)

    var coords: Dictionary = {}
    for i in base_ordered.size():
        var c := Vector2i(i, 0)
        src_base.create_tile(c)
        coords[base_ordered[i]] = c

        # Назначаем terrain + peering
        var name: String = base_ordered[i]
        var home: int = tile_terrain.get(name, -1)
        if home >= 0:
            var td: TileData = src_base.get_tile_data(c, 0)
            if td != null:
                td.terrain_set = 0
                td.terrain = home
                var img := _get_tile_image(name)
                var bits := _analyze_edges(img, home)
                for b in 6:
                    var cn: int = DOC_TO_CELL[b]
                    if td.is_valid_terrain_peering_bit(cn):
                        td.set_terrain_peering_bit(cn, bits[b])

    # === Источник 1: ОБЪЕКТЫ (декор) ===
    if obj_ordered.size() > 0:
        var obj_tex := ImageTexture.create_from_image(obj_atlas)
        var src_obj := TileSetAtlasSource.new()
        src_obj.texture = obj_tex
        src_obj.texture_region_size = Vector2i(TILE, TILE)
        ts.add_source(src_obj, 1)  # ID = 1

        for i in obj_ordered.size():
            var c := Vector2i(i, 0)
            src_obj.create_tile(c)

    ResourceSaver.save(ts, OUTPUT_PATH)
    print("💾 TileSet saved: %s (source 0: base, source 1: objects)" % OUTPUT_PATH)
    return coords

# ===================== 7. TERRAIN ATLAS MAP =====================
func _write_map_script(base_coords: Dictionary, obj_ordered: Array[String]) -> void:
    var txt := "class_name TerrainAtlasMap\n"
    txt += "## AUTOGENERATED by tileset_builder.gd v4 — do not edit\n"
    txt += "const SOURCE_ID := 0\n"
    txt += "const OBJECT_SOURCE_ID := 1\n"

    # CENTER_COORDS (базовые тайлы)
    txt += "const CENTER_COORDS := {\n"
    for t in TERRAINS.size():
        var base_name := "%s_base" % TERRAINS[t]
        if base_coords.has(base_name):
            var c: Vector2i = base_coords[base_name]
            txt += "\t%d: Vector2i(%d, 0),\n" % [t, c.x]
    txt += "}\n"

    # VARIANTS (варианты фона)
    txt += "const VARIANTS := {\n"
    for t in TERRAINS.size():
        var biome: String = TERRAINS[t]
        var variants := ""
        for name in base_coords:
            if tile_terrain.get(name, -1) == t and name != "%s_base" % biome:
                var c: Vector2i = base_coords[name]
                variants += "\t\tVector2i(%d, 0),\n" % c.x
        txt += "\t%d: [\n%s\t],\n" % [t, variants]
    txt += "}\n"

    # DECOR_COORDS (объекты) с вероятностью
    txt += "const DECOR_COORDS := {\n"
    for t in TERRAINS.size():
        var biome: String = TERRAINS[t]
        var entries := ""
        for i in obj_ordered.size():
            if tile_terrain.get(obj_ordered[i], -1) == t:
                entries += "\t\t{\"coords\": Vector2i(%d, 0), \"probability\": 0.15},\n" % i
        txt += "\t%d: [\n%s\t],\n" % [t, entries]
    txt += "}\n"

    # RIVER (пусто)
    txt += "const RIVER_COORDS := []\n"

    var fa := FileAccess.open(MAP_SCRIPT_PATH, FileAccess.WRITE)
    if fa == null:
        push_error("Failed to write TerrainAtlasMap: %s" % error_string(FileAccess.get_open_error()))
        quit(1)
    fa.store_string(txt)
    fa.close()
    print("📝 TerrainAtlasMap updated")

# ===================== 8. ОТЧЁТ =====================
func _write_report(base_ordered: Array[String], obj_ordered: Array[String]) -> void:
    var txt := "\n## TileSet Builder v4 Report (base + objects)\n"
    txt += "| Биом | Фон | Варианты | Объекты |\n|---|---|---|---|\n"

    for t in TERRAINS.size():
        var biome: String = TERRAINS[t]
        var base_count := 0
        var var_count := 0
        var obj_count := 0
        for name in tile_terrain:
            if tile_terrain[name] == t:
                if name.ends_with("_base"):
                    base_count = 1
                elif name.begins_with(biome + "_v"):
                    var_count += 1
                elif name.begins_with(biome + "_obj"):
                    obj_count += 1
        txt += "| %s | %d | %d | %d |\n" % [biome, base_count, var_count, obj_count]

    txt += "\n### Структура папок:\n"
    txt += "```\nprocessed/{biome}/base/    → фоновые (заполнение)\n"
    txt += "processed/{biome}/objects/ → объекты (декор, 15% шанс)\n```\n"

    if synth_log.size() > 0:
        txt += "\n### Synthesized:\n"
        for s in synth_log:
            txt += "- %s\n" % s

    var fa := FileAccess.open("res://docs/REPORT.md", FileAccess.READ_WRITE)
    if fa == null:
        push_error("Failed to open res://docs/REPORT.md: %s" % error_string(FileAccess.get_open_error()))
        return
    fa.seek_end()
    # Гарантируем перевод строки между блоками отчёта
    var content := fa.get_as_text()
    if content.length() > 0 and not content.ends_with("\n"):
        fa.seek_end()
        fa.store_string("\n")
    fa.store_string(txt + "\n")
    fa.close()

# ===================== УТИЛИТЫ =====================
func _complexity_score(img: Image) -> float:
    var cx := float(TILE) / 2.0
    var mn := 1.0
    var mx := 0.0
    for y in range(int(cx * 0.3), int(cx * 1.7)):
        for x in range(int(cx * 0.3), int(cx * 1.7)):
            if x >= 0 and y >= 0 and x < TILE and y < TILE:
                var px := img.get_pixel(x, y)
                if px.a > 0.5:
                    var l := px.get_luminance()
                    mn = minf(mn, l)
                    mx = maxf(mx, l)
    return mx - mn

func _analyze_edges(img: Image, home: int) -> Array[int]:
    var res: Array[int] = []
    if img == null:
        for b in 6:
            res.append(home)
        return res
    var compat: Array = HOME_COMPAT.get(home, [home])
    var cx := float(TILE) / 2.0
    var a := cx * 0.866 * 0.98
    for b in 6:
        var d: Vector2 = EDGE_DIRS[b]
        var perp := Vector2(-d.y, d.x)
        var sum := Color(0, 0, 0, 0)
        var n := 0
        for tf in [0.74, 0.82, 0.90]:
            for of in [-0.18, -0.09, 0.0, 0.09, 0.18]:
                var p: Vector2 = Vector2(cx, cx) + d * (a * tf) + perp * (a * of)
                var xi := int(p.x)
                var yi := int(p.y)
                if xi < 0 or yi < 0 or xi >= TILE or yi >= TILE:
                    continue
                var px := img.get_pixel(xi, yi)
                if px.a > 0.5:
                    sum += px
                    n += 1
        if n < 4:
            res.append(home)
            continue
        var avg := Color(sum.r / n, sum.g / n, sum.b / n)
        var nearest := 0
        var bd := 1e9
        for i in ref_colors.size():
            var r: Color = ref_colors[i]
            var ds := (r.r - avg.r) ** 2 + (r.g - avg.g) ** 2 + (r.b - avg.b) ** 2
            if ds < bd:
                bd = ds
                nearest = i
        var d_compat := 1e9
        for ci in compat:
            if ci < ref_colors.size():
                var r2: Color = ref_colors[ci]
                var ds2 := (r2.r - avg.r) ** 2 + (r2.g - avg.g) ** 2 + (r2.b - avg.b) ** 2
                d_compat = minf(d_compat, ds2)
        var foreign := (not compat.has(nearest)) and (d_compat - bd > MARGIN_SQ)
        res.append(-1 if foreign else home)
    return res

func _apply_hex_mask(img: Image) -> void:
    var cx := float(TILE) / 2.0
    var R := cx * 0.96
    for y in TILE:
        for x in TILE:
            var px := float(x) - cx + 0.5
            var py := float(y) - cx + 0.5
            var q := (sqrt(3.0) / 3.0 * px - 1.0 / 3.0 * py) / R
            var s := (2.0 / 3.0 * py) / R
            if maxf(absf(q), maxf(absf(s), absf(-q - s))) > 1.0:
                img.set_pixel(x, y, Color(0, 0, 0, 0))

func _make_solid_hex(col: Color) -> Image:
    var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
    var cx := float(TILE) / 2.0
    var R := cx * 0.96
    for y in TILE:
        for x in TILE:
            var px := float(x) - cx + 0.5
            var py := float(y) - cx + 0.5
            var q := (sqrt(3.0) / 3.0 * px - 1.0 / 3.0 * py) / R
            var s := (2.0 / 3.0 * py) / R
            if maxf(absf(q), maxf(absf(s), absf(-q - s))) <= 1.0:
                img.set_pixel(x, y, col)
    return img
