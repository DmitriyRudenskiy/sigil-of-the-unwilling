extends SceneTree

var _passed: int = 0
var _failed: int = 0

const Clusterer = preload("res://tools/texture_slicer/BiomeClusterer.gd")

func _init() -> void:
    print("Running Test Biome Clustering...")
    var hexes: Array[Image] = []
    
    # Create colors for biomes
    var colors = {
        "water": Color.BLUE,
        "grass": Color.GREEN,
        "snow": Color.WHITE
    }
    
    for biome in colors.keys():
        for i in range(10):
            var img = Image.create(82, 82, false, Image.FORMAT_RGBA8)
            img.fill(colors[biome])
            hexes.append(img)
            
    var biomes = Clusterer.cluster_by_color(hexes)
    
    var success = true
    for b in ["water", "grass", "snow"]:
        if biomes[b].size() != 10:
            print("  FAILURE: Biome %s has %d tiles, expected 10" % [b, biomes[b].size()])
            success = false
            
    if success:
        print("  SUCCESS: All biomes clustered correctly")
    else:
        print("  FAILURE: Clustering failed")
        
    _failed = 0 if success else 1
    _passed = 1 if success else 0
    quit(0)
