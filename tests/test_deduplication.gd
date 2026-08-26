extends SceneTree

const Slicer = preload("res://tools/texture_slicer/SlicerCore.gd")

func _init() -> void:
    print("Running Test Deduplication...")
    var img1 = Image.create(82, 82, false, Image.FORMAT_RGBA8)
    img1.fill(Color.RED)
    
    var img2 = Image.create(82, 82, false, Image.FORMAT_RGBA8)
    img2.fill(Color.RED)
    
    var img3 = Image.create(82, 82, false, Image.FORMAT_RGBA8)
    img3.fill(Color.BLUE)
    
    var h1 = Slicer.compute_dhash(img1)
    var h2 = Slicer.compute_dhash(img2)
    var h3 = Slicer.compute_dhash(img3)
    
    if Slicer.hamming_distance(h1, h2) == 0:
        print("  SUCCESS: Identical images have distance 0")
    else:
        print("  FAILURE: Identical images have distance %d" % Slicer.hamming_distance(h1, h2))
        
    if Slicer.hamming_distance(h1, h3) > 0:
        print("  SUCCESS: Different images have distance > 0")
    else:
        print("  FAILURE: Different images have distance 0")
        
    quit(0)
