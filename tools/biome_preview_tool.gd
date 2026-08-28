extends Node2D
## Biome Preview Tool — чистый рендер тайлсета без игровых элементов.
##
## Запуск:
##   /Applications/Godot.app/Contents/MacOS/Godot --path "$(pwd)" \
##     --windowed --resolution 1920x1080 \
##     res://scenes/BiomePreview.tscn \
##     --mode duo --biomes water,grass --seed 42 \
##     --out res://previews/
##
## Режимы: solo | duo | trio | matrix | all
## --all генерирует сразу 1 solo на каждый биом + все пары duo + 2 trio + matrix.

const TerrainAtlasMap = preload("res://world/TerrainAtlasMap.gd")
const HexUtilsClass = preload("res://core/HexUtils.gd")

const GRID_W := 28
const GRID_H := 20
const BIOME_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]

# ===================== ENTRY =====================
func _ready() -> void:
    print("=== Biome Preview Tool ===")

    var args := OS.get_cmdline_args()
    var mode := "matrix"
    var biomes_arg := ""
    var seed_val := 42
    var out_dir := "res://previews/"
    var open_after := true
    var retina := false

    for i in args.size():
        if args[i] == "--mode" and i + 1 < args.size():
            mode = args[i + 1]
        elif args[i] == "--biomes" and i + 1 < args.size():
            biomes_arg = args[i + 1]
        elif args[i] == "--seed" and i + 1 < args.size():
            seed_val = int(args[i + 1])
        elif args[i] == "--out" and i + 1 < args.size():
            out_dir = args[i + 1]
        elif args[i] == "--no-open":
            open_after = false
        elif args[i] == "--retina":
            retina = true

    if not DirAccess.dir_exists_absolute(out_dir):
        DirAccess.make_dir_recursive_absolute(out_dir)

    # Retina: удваиваем физический фреймбуфер
    if retina:
        var vp := get_viewport()
        vp.size = Vector2i(3840, 2160)
        vp.content_scale_size = Vector2i(1920, 1080)

    match mode:
        "all":
            await _generate_all(out_dir, seed_val, open_after)
        "solo":
            var biomes := _parse_biomes(biomes_arg, ["grass"])
            for b in biomes:
                await _render_and_save("solo_%s" % b, out_dir, seed_val, open_after,
                                       func(tm: TileMapLayer): _fill_solo(tm, b, seed_val))
        "duo":
            var biomes := _parse_biomes(biomes_arg, ["water", "grass"])
            if biomes.size() < 2:
                printerr("--mode duo requires 2 biomes, e.g. --biomes water,grass")
                get_tree().quit()
                return
            await _render_and_save("duo_%s_%s" % [biomes[0], biomes[1]], out_dir, seed_val, open_after,
                                   func(tm: TileMapLayer): _fill_duo(tm, biomes[0], biomes[1], seed_val))
        "trio":
            var biomes := _parse_biomes(biomes_arg, ["water", "grass", "mountain"])
            if biomes.size() < 3:
                printerr("--mode trio requires 3 biomes, e.g. --biomes water,grass,mountain")
                get_tree().quit()
                return
            await _render_and_save("trio_%s_%s_%s" % [biomes[0], biomes[1], biomes[2]], out_dir, seed_val, open_after,
                                   func(tm: TileMapLayer): _fill_trio(tm, biomes[0], biomes[1], biomes[2], seed_val))
        "matrix":
            await _render_and_save("matrix_all", out_dir, seed_val, open_after,
                                   func(tm: TileMapLayer): _fill_matrix(tm, seed_val))
        _:
            printerr("Unknown mode: %s" % mode)
            get_tree().quit()

    get_tree().quit()

# ===================== HELPERS =====================
func _parse_biomes(arg: String, fallback: Array[String]) -> Array[String]:
    if arg.is_empty():
        return fallback
    var parts := arg.split(",")
    var result: Array[String] = []
    for p in parts:
        var name := p.strip_edges()
        if BIOME_NAMES.has(name):
            result.append(name)
        else:
            printerr("⚠️  Unknown biome '%s', skipping. Valid: %s" % [name, ", ".join(BIOME_NAMES)])
    return result if not result.is_empty() else fallback

func _biome_id(name: String) -> int:
    return BIOME_NAMES.find(name)

# ===================== SCENE SETUP =====================
func _create_scene() -> Dictionary:
    var tile_map := TileMapLayer.new()
    tile_map.name = "Terrain"
    tile_map.tile_set = load("res://tilesets/hex_tileset.tres")
    add_child(tile_map)
    if tile_map.tile_set == null:
        printerr("❌ hex_tileset.tres not found. Run tileset_builder.gd first.")
        get_tree().quit()
        return {}

    var camera := Camera2D.new()
    camera.name = "Camera"
    camera.zoom = Vector2(1.4, 1.4)
    add_child(camera)

    # Калибровка чётности строк под реальный layout
    HexUtilsClass.calibrate(tile_map)

    # Тёмный фон за пределами карты (не белый!)
    RenderingServer.set_default_clear_color(Color(0.08, 0.06, 0.04))

    return {"tm": tile_map, "cam": camera}

func _render_and_save(label: String, out_dir: String, seed_val: int,
                     open_after: bool, fill_fn: Callable) -> void:
    # Чистим предыдущую сцену
    for c in get_children():
        c.queue_free()
    await get_tree().process_frame

    var scene := _create_scene()
    if scene.is_empty(): return
    var tm: TileMapLayer = scene["tm"]
    var cam: Camera2D = scene["cam"]

    fill_fn.call(tm)

    _fit_camera_to_field(cam, tm)

    # Ждём 2 кадра для завершения отрисовки
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw

    var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_").substr(0, 19)
    var filename := "biome_%s_seed%d_%s.png" % [label, seed_val, timestamp]
    var path := out_dir.path_join(filename)

    var img := get_viewport().get_texture().get_image()
    var err := img.save_png(path)
    if err == OK:
        print("✅ Saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
        if open_after:
            OS.shell_open("file://" + ProjectSettings.globalize_path(path))
    else:
        printerr("❌ Failed to save: %s" % path)

# ===================== CAMERA =====================
func _fit_camera_to_field(cam: Camera2D, tm: TileMapLayer) -> void:
    var used := tm.get_used_rect()
    if used.size.x <= 0 or used.size.y <= 0:
        return
    var p0 := tm.map_to_local(used.position)
    var p1 := tm.map_to_local(used.position + used.size - Vector2i(1, 1))
    var field_sz := Vector2(absf(p1.x - p0.x) + 120.0, absf(p1.y - p0.y) + 120.0)
    var center := (p0 + p1) / 2.0
    var vp_sz := get_viewport().get_visible_rect().size
    var z := maxf(vp_sz.x / field_sz.x, vp_sz.y / field_sz.y)
    cam.zoom = Vector2(z, z)
    cam.position = center

# ===================== CELL HELPERS =====================
func _set_biome_cell(tm: TileMapLayer, cell: Vector2i, biome_name: String, rng: RandomNumberGenerator) -> void:
    var id := _biome_id(biome_name)
    if id < 0:
        return
    if not TerrainAtlasMap.CENTER_COORDS.has(id):
        return
    var coords: Vector2i = TerrainAtlasMap.CENTER_COORDS[id]
    # 30% шанс взять вариант вместо базового (если варианты есть)
    if rng.randf() < 0.30 and TerrainAtlasMap.VARIANTS.has(id):
        var vars: Array = TerrainAtlasMap.VARIANTS[id]
        if vars.size() > 0:
            coords = vars[rng.randi_range(0, vars.size() - 1)]
    tm.set_cell(cell, TerrainAtlasMap.SOURCE_ID, coords)

# ===================== FILL MODES =====================
func _fill_solo(tm: TileMapLayer, biome: String, seed_val: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    for y in GRID_H:
        for x in GRID_W:
            _set_biome_cell(tm, Vector2i(x, y), biome, rng)

func _fill_duo(tm: TileMapLayer, biome_a: String, biome_b: String, seed_val: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    # Вертикальная граница посередине + лёгкая волнистость для естественности
    for y in GRID_H:
        var boundary := GRID_W / 2 + int(sin(float(y) * 0.6) * 2.0)
        for x in GRID_W:
            var b := biome_a if x < boundary else biome_b
            _set_biome_cell(tm, Vector2i(x, y), b, rng)

func _fill_trio(tm: TileMapLayer, a: String, b: String, c: String, seed_val: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    # Три вертикальные полосы с волнистыми границами
    var w3 := GRID_W / 3
    for y in GRID_H:
        var b1 := w3 + int(sin(float(y) * 0.5) * 1.5)
        var b2 := w3 * 2 + int(cos(float(y) * 0.5) * 1.5)
        for x in GRID_W:
            var biome := a if x < b1 else (b if x < b2 else c)
            _set_biome_cell(tm, Vector2i(x, y), biome, rng)

func _fill_matrix(tm: TileMapLayer, seed_val: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    # 7 биомов блоками по 4 колонки с перекрытием (чтобы были стыки между всеми соседями)
    var block_w := 5
    for i in BIOME_NAMES.size():
        var start_x := i * (block_w - 1)
        for y in GRID_H:
            for x_off in block_w:
                var x := start_x + x_off
                if x >= GRID_W:
                    break
                _set_biome_cell(tm, Vector2i(x, y), BIOME_NAMES[i], rng)

# ===================== GENERATE ALL =====================
func _generate_all(out_dir: String, seed_val: int, open_after: bool) -> void:
    print("🎯 Generating full biome test suite...")

    # 1. Solo для каждого биома
    for b in BIOME_NAMES:
        await _render_and_save("solo_%s" % b, out_dir, seed_val, open_after,
                               func(tm: TileMapLayer): _fill_solo(tm, b, seed_val))

    # 2. Все пары duo (C(7,2) = 21 комбинация)
    for i in BIOME_NAMES.size():
        for j in range(i + 1, BIOME_NAMES.size()):
            var a: String = BIOME_NAMES[i]
            var b: String = BIOME_NAMES[j]
            await _render_and_save("duo_%s_%s" % [a, b], out_dir, seed_val, open_after,
                                   func(tm: TileMapLayer): _fill_duo(tm, a, b, seed_val))

    # 3. 3代表性的 trio (water-grass-mountain, swamp-sand-forest, grass-forest-snow)
    var trios := [
        ["water", "grass", "mountain"],
        ["swamp", "sand", "forest"],
        ["grass", "forest", "snow"],
    ]
    for t in trios:
        await _render_and_save("trio_%s_%s_%s" % [t[0], t[1], t[2]], out_dir, seed_val, open_after,
                                   func(tm: TileMapLayer): _fill_trio(tm, t[0], t[1], t[2], seed_val))

    # 4. Matrix — все 7 биомов
    await _render_and_save("matrix_all", out_dir, seed_val, open_after,
                           func(tm: TileMapLayer): _fill_matrix(tm, seed_val))

    print("🎉 Full suite complete: %d files in %s" % [7 + 21 + 3 + 1, out_dir])
