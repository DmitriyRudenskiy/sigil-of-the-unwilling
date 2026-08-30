@tool
extends EditorScript
## Stage 0: Hex Asset Normalizer
## Run: File > Run Script (Ctrl+Shift+X)

const SOURCE_DIR := "res://assets/raw/"
const OUTPUT_DIR := "res://tilesets/processed/"

const FILE_MAP := {
    "a_измени_бином_на_пуст-2.jpeg": "sand_base",
    "a_измени_бином_на_пуст — копия.jpeg": "sand_dunes",
    "a_измени_бином_на_пуст.png": "sand_pebbles",
    "b_измени_бином_на_пуст.png": "sand_grass",
    "b_измени_бином_на_пуст — копия.png": "sand_cactus",
    "b_измени_бином_на_пуст — копия 2.png": "sand_palm",
}

const PARTIAL_MATCHES := [
    {"match": "942b9d421", "name": "grass_base"},
    {"match": "d42345121", "name": "grass_dry"},
    {"match": "b9d42345.png", "name": "forest_shrub"},
    {"match": "b9d423451", "name": "forest_1tree"},
    {"match": "9d4234512", "name": "forest_2trees"},
    {"match": "42b9d422", "name": "mountain_1"},
    {"match": "2b9d4234", "name": "mountain_3a"},
    {"match": "42b9d423", "name": "mountain_3b"},
    {"match": "spritesheet-7", "name": "water_corner"},
    {"match": "spritesheet-8", "name": "river_curve_a"},
    {"match": "spritesheet-6", "name": "river_curve_b"},
    {"match": "spritesheet-5", "name": "river_diag_a"},
    {"match": "spritesheet-3", "name": "river_diag_b"},
    {"match": "spritesheet-4", "name": "river_straight"},
]

const RESOURCE_NAMES := ["res_wood", "res_mercury", "res_ore", "res_sulfur", "res_crystal", "res_gems", "res_gold"]


func _run() -> void:
    print("=== Stage 0: Hex Asset Normalizer ===")
    var dir := DirAccess.open("res://")
    if not dir.dir_exists(OUTPUT_DIR):
        dir.make_dir_recursive(OUTPUT_DIR)
    if not dir.dir_exists(SOURCE_DIR):
        printerr("ERROR: Source dir not found: ", SOURCE_DIR)
        return

    var source := DirAccess.open(SOURCE_DIR)
    if source == null:
        printerr("ERROR: Cannot open: ", SOURCE_DIR)
        return

    var files: Array[String] = []
    source.list_dir_begin()
    var file_name := source.get_next()
    while file_name != "":
        if not source.current_is_dir():
            var ext := file_name.get_extension().to_lower()
            if ext in ["png", "jpeg", "jpg"]:
                files.append(file_name)
        file_name = source.get_next()
    source.list_dir_end()
    print("Found %d image files." % files.size())

    # Determine target size
    var sizes: Dictionary = {}
    for f in files:
        var img := Image.load_from_file(SOURCE_DIR + f)
        if img:
            var w := img.get_width()
            sizes[w] = sizes.get(w, 0) + 1
    var target_size := 128
    if sizes.size() > 0:
        var max_count := 0
        for w in sizes:
            if sizes[w] > max_count:
                max_count = sizes[w]
                target_size = w
    print("Target size: %dx%d" % [target_size, target_size])

    var processed_count := 0
    for f in files:
        var out_name := _resolve_name(f)
        if out_name.is_empty():
            print("SKIP: ", f)
            continue
        var img := Image.load_from_file(SOURCE_DIR + f)
        if img == null:
            printerr("ERROR loading: ", f)
            continue
        if img.is_compressed():
            img.decompress()
        if img.get_format() != Image.FORMAT_RGBA8:
            img.convert(Image.FORMAT_RGBA8)
        _remove_black_background(img)
        _apply_hex_mask(img, true)  # true=pointy-top
        if img.get_width() != target_size or img.get_height() != target_size:
            img.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
        var out_path := OUTPUT_DIR + out_name + ".png"
        img.save_png(out_path)
        processed_count += 1
        print("  OK: %s -> %s" % [f, out_name])

    print("Done: %d tiles -> %s" % [processed_count, OUTPUT_DIR])


func _resolve_name(filename: String) -> String:
    if FILE_MAP.has(filename):
        return FILE_MAP[filename]
    var lower := filename.to_lower()
    if lower.begins_with("resour"):
        for i in range(RESOURCE_NAMES.size()):
            if str(i) in filename:
                return RESOURCE_NAMES[i]
        return "res_unknown"
    for pm in PARTIAL_MATCHES:
        if pm["match"] in filename:
            return pm["name"]
    return ""


func _remove_black_background(img: Image) -> void:
    var threshold := 30
    var w := img.get_width()
    var h := img.get_height()
    for y in range(h):
        for x in range(w):
            var pixel := img.get_pixel(x, y)
            if int(pixel.r * 255) < threshold and int(pixel.g * 255) < threshold and int(pixel.b * 255) < threshold:
                img.set_pixel(x, y, Color(0, 0, 0, 0))


func _apply_hex_mask(img: Image, pointy_top: bool) -> void:
    var w := img.get_width()
    var h := img.get_height()
    var cx := float(w) / 2.0
    var cy := float(h) / 2.0
    var radius := minf(cx, cy) * 0.98
    for y in range(h):
        for x in range(w):
            var px := float(x) - cx + 0.5
            var py := float(y) - cy + 0.5
            var inside := _point_in_hex_pointy(px, py, radius) if pointy_top else _point_in_hex_flat(px, py, radius)
            if not inside:
                img.set_pixel(x, y, Color(0, 0, 0, 0))


func _point_in_hex_pointy(px: float, py: float, r: float) -> bool:
    var q := (sqrt(3.0) / 3.0 * px - 1.0 / 3.0 * py) / r
    var s := (2.0 / 3.0 * py) / r
    return maxf(absf(q), maxf(absf(s), absf(-q - s))) <= 1.0


func _point_in_hex_flat(px: float, py: float, r: float) -> bool:
    var q := (2.0 / 3.0 * px) / r
    var s := (-1.0 / 3.0 * px + sqrt(3.0) / 3.0 * py) / r
    return maxf(absf(q), maxf(absf(s), absf(-q - s))) <= 1.0
