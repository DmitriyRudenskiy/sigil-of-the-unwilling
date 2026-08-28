extends "res://tests/test_base.gd"
## SlicerCore: hex extraction + masking.

const Slicer = preload("res://tools/texture_slicer/SlicerCore.gd")


func _make_screenshot() -> Image:
    var img := Image.create(400, 400, false, Image.FORMAT_RGBA8)
    img.fill(Color.GRAY)

    # Draw some mock hexes (just white squares for simplicity of test)
    for x in range(0, 400, 82):
        for y in range(0, 400, 82):
            img.fill_rect(Rect2i(x, y, 82, 82), Color.WHITE)
    return img


func test_extracts_hexes() -> void:
    var hexes = Slicer.extract_hexes_from_screenshot(_make_screenshot(), 82, "pointy")
    assert_true(hexes.size() > 0, "extracted %d hexes" % hexes.size())


func test_hex_mask_corners_transparent() -> void:
    var hexes = Slicer.extract_hexes_from_screenshot(_make_screenshot(), 82, "pointy")
    if hexes.is_empty():
        return
    var hex: Image = hexes[0]
    assert_eq(hex.get_pixel(0, 0).a, 0.0, "top-left corner masked")
    assert_eq(hex.get_pixel(hex.get_width() - 1, 0).a, 0.0, "top-right corner masked")
    assert_eq(hex.get_pixel(0, hex.get_height() - 1).a, 0.0, "bottom-left corner masked")
    assert_eq(hex.get_pixel(hex.get_width() - 1, hex.get_height() - 1).a, 0.0, "bottom-right corner masked")


func test_hex_mask_center_opaque() -> void:
    var hexes = Slicer.extract_hexes_from_screenshot(_make_screenshot(), 82, "pointy")
    if hexes.is_empty():
        return
    var hex: Image = hexes[0]
    var cx: int = hex.get_width() / 2
    var cy: int = hex.get_height() / 2
    assert_eq(hex.get_pixel(cx, cy).a, 1.0, "center opaque")
