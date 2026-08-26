class_name SlicerCore
extends RefCounted

const HEX_SIZE := 82
const SQRT3 := 1.7320508

static func extract_hexes_from_screenshot(img: Image, hex_size: int, orientation: String) -> Array[Image]:
    var hexes: Array[Image] = []
    var w := img.get_width()
    var h := img.get_height()
    
    # Pointy-top geometry
    var hex_w := int(hex_size * SQRT3 / 2.0)
    var hex_h := hex_size
    var step_x := hex_w
    var step_y := int(hex_h * 0.75)
    
    var row := 0
    var y := hex_h / 2
    while y < h - hex_h / 2:
        var offset_x := hex_w / 2 if (row % 2 != 0) else 0
        var x := offset_x + hex_w / 2
        while x < w - hex_w / 2:
            var rect := Rect2i(x - hex_w / 2, y - hex_h / 2, hex_w, hex_h)
            var sub_img := Image.create(hex_w, hex_h, false, Image.FORMAT_RGBA8)
            sub_img.blit_rect(img, rect, Vector2i.ZERO)
            apply_hex_mask(sub_img, hex_size)
            hexes.append(sub_img)
            x += step_x
        y += step_y
        row += 1
    return hexes

static func apply_hex_mask(img: Image, size: int) -> void:
    var cx := float(img.get_width()) / 2.0
    var cy := float(img.get_height()) / 2.0
    var r := minf(cx, cy) * 0.98
    for y in img.get_height():
        for x in img.get_width():
            var px := float(x) - cx + 0.5
            var py := float(y) - cy + 0.5
            # Pointy top hex math
            var q := (SQRT3 / 3.0 * px - 1.0 / 3.0 * py) / r
            var s := (2.0 / 3.0 * py) / r
            if maxf(absf(q), maxf(absf(s), absf(-q - s))) > 1.0:
                img.set_pixel(x, y, Color(0, 0, 0, 0))

static func compute_dhash(img: Image) -> int:
    var small := Image.create(9, 8, false, Image.FORMAT_RGBA8)
    small.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
    small.resize(9, 8, Image.INTERPOLATE_LANCZOS)
    
    var hash_val := 0
    for y in 8:
        for x in 8:
            var c1 := small.get_pixel(x, y).get_luminance()
            var c2 := small.get_pixel(x + 1, y).get_luminance()
            hash_val <<= 1
            if c1 > c2:
                hash_val |= 1
    return hash_val

static func hamming_distance(h1: int, h2: int) -> int:
    var x := h1 ^ h2
    var count := 0
    while x != 0:
        count += x & 1
        x >>= 1
    return count
