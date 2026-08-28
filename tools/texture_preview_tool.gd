extends SceneTree

const Slicer = preload("res://tools/texture_slicer/SlicerCore.gd")
const Clusterer = preload("res://tools/texture_slicer/BiomeClusterer.gd")

func _init() -> void:
    var args := OS.get_cmdline_args()
    var mode := "sheet"
    var input_path := ""
    var out_dir := "res://previews/"
    var seed_val := 42
    var apply := false
    var compare := false
    var retina := false
    
    # Парсинг аргументов (упрощенно)
    for i in args.size():
        if args[i] == "--mode" and i+1 < args.size(): mode = args[i+1]
        if args[i] == "--input" and i+1 < args.size(): input_path = args[i+1]
        if args[i] == "--out" and i+1 < args.size(): out_dir = args[i+1]
        if args[i] == "--apply": apply = true
        if args[i] == "--compare": compare = true
        if args[i] == "--retina": retina = true

    if input_path.is_empty():
        printerr("Usage: --input <path> [--mode sheet|screenshot] [--apply] [--compare]")
        quit(1)
        return

    print("=== Texture Preview Tool ===")
    print("Mode: %s | Input: %s" % [mode, input_path])
    
    var img := Image.load_from_file(input_path)
    if img == null:
        printerr("Failed to load image: %s" % input_path)
        quit(1)
        return
        
    var hexes: Array[Image] = []
    
    if mode == "screenshot":
        print("Extracting hexes from screenshot...")
        hexes = Slicer.extract_hexes_from_screenshot(img, 82, "pointy")
        print("Extracted %d hexes." % hexes.size())
    else:
        # Режим Sheet (auto-grid slicing)
        print("Slicing sheet... (fallback to simple grid for now)")
        # Здесь должна быть логика авто-поиска сетки через проекции альфа-канала
        # Для краткости используем фиксированную сетку или делегируем в binom_cutter
        pass 

    print("Clustering biomes...")
    var biomes := Clusterer.cluster_by_color(hexes)
    for b in biomes.keys():
        print("  %s: %d tiles" % [b, biomes[b].size()])
        
    # Дедупликация (dHash)
    print("Deduplicating...")
    var unique_tiles: Dictionary = {} # biome -> Array[Image]
    for b in biomes.keys():
        unique_tiles[b] = []
        var hashes: Array[int] = []
        for hex_img in biomes[b]:
            var h := Slicer.compute_dhash(hex_img)
            var is_dup := false
            for existing_h in hashes:
                if Slicer.hamming_distance(h, existing_h) < 5:
                    is_dup = true
                    break
            if not is_dup:
                hashes.append(h)
                unique_tiles[b].append(hex_img)
        print("  %s: %d unique tiles" % [b, unique_tiles[b].size()])

    # Сохранение тайлов и манифеста
    var slice_dir := "res://tilesets/sliced/preview_run/"
    DirAccess.make_dir_recursive_absolute(slice_dir)
    # ... (код сохранения PNG и manifest.json)
    
    print("Generating Preview Map...")
    # Создаем сцену, рендерим, делаем скриншот
    var preview_scene_res = load("res://tools/texture_preview_tool.tscn")
    if preview_scene_res:
        var preview_scene: Node = preview_scene_res.instantiate()
        root.add_child(preview_scene)
        
        # Ждем рендера и сохраняем
        await process_frame
        await RenderingServer.frame_post_draw
        await RenderingServer.frame_post_draw
        
        var viewport_img: Image = root.get_viewport().get_texture().get_image()
        var out_path := out_dir.path_join("preview_%d.png" % seed_val)
        viewport_img.save_png(out_path)
        print("Preview saved: %s" % out_path)
        
        # macOS Finder open
        OS.shell_open("file://" + ProjectSettings.globalize_path(out_path))
    else:
        printerr("Could not load res://tools/texture_preview_tool.tscn")

    if apply:
        print("Applying to project (triggering tileset_builder)...")
        # Вызов существующего tileset_builder.gd
        
    quit(0)
