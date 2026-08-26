extends SceneTree

const Slicer = preload("res://tools/texture_slicer/SlicerCore.gd")

func _init() -> void:
    print("Running Test Slicer...")
    var img := Image.create(400, 400, false, Image.FORMAT_RGBA8)
    img.fill(Color.GRAY)
    
    # Draw some mock hexes (just white squares for simplicity of test)
    for x in range(0, 400, 82):
        for y in range(0, 400, 82):
            img.fill_rect(Rect2i(x, y, 82, 82), Color.WHITE)
            
    var hexes = Slicer.extract_hexes_from_screenshot(img, 82, "pointy")
    
    if hexes.size() > 0:
        print("  SUCCESS: Extracted %d hexes" % hexes.size())
        # Check if masking worked (pixel at 0,0 should be transparent)
        if hexes[0].get_pixel(0, 0).a == 0:
            print("  SUCCESS: Hex mask applied")
        else:
            print("  FAILURE: Hex mask not applied")
    else:
        print("  FAILURE: No hexes extracted")
        
    quit(0)
