class_name BiomeClusterer
extends RefCounted

static func cluster_by_color(hexes: Array[Image]) -> Dictionary:
    # Упрощенная кластеризация по доминирующему цвету (K-Means / Thresholding)
    var biomes := {
        "water": [], "swamp": [], "sand": [], "grass": [], 
        "forest": [], "mountain": [], "snow": []
    }
    
    for img in hexes:
        var avg := get_average_color(img)
        var biome := classify_biome(avg)
        biomes[biome].append(img)
        
    return biomes

static func get_average_color(img: Image) -> Color:
    var sum := Color(0,0,0,0)
    var count := 0
    # Sample center pixels to avoid transparent edges
    var cx := img.get_width() / 2
    var cy := img.get_height() / 2
    for y in range(cy - 10, cy + 10):
        for x in range(cx - 10, cx + 10):
            if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
                var c := img.get_pixel(x, y)
                if c.a > 0.5:
                    sum += c
                    count += 1
    if count == 0: return Color.BLACK
    return Color(sum.r / count, sum.g / count, sum.b / count, 1.0)

static func classify_biome(c: Color) -> String:
    var lum := c.get_luminance()
    if lum > 0.85: return "snow"
    if c.b > 0.6 and c.r < 0.4: return "water"
    if c.r > 0.6 and c.g > 0.5 and c.b < 0.4: return "sand"
    if c.g > 0.4 and c.r < 0.4 and c.b < 0.4:
        if lum < 0.3: return "forest"
        return "grass"
    if c.r < 0.4 and c.g < 0.4 and c.b < 0.4: return "mountain"
    if c.g > 0.3 and c.b > 0.3 and lum < 0.4: return "swamp"
    return "grass"
