extends "res://tests/test_base.gd"
## SlicerCore deduplication: dhash + hamming distance.
##
## Note: dhash is a *luminance gradient* hash — two solid fills (even of
## different colors) always hash to 0. "Different" images must differ in
## luminance pattern, not in flat color.

const Slicer = preload("res://tools/texture_slicer/SlicerCore.gd")


func _solid(color: Color) -> Image:
    var img := Image.create(82, 82, false, Image.FORMAT_RGBA8)
    img.fill(color)
    return img


func _gradient() -> Image:
    # White -> black horizontal gradient: distinct luminance pattern.
    var img := Image.create(82, 82, false, Image.FORMAT_RGBA8)
    for x in 82:
        var c := Color(1.0 - x / 81.0, 1.0 - x / 81.0, 1.0 - x / 81.0)
        for y in 82:
            img.set_pixel(x, y, c)
    return img


func test_identical_images_distance_zero() -> void:
    var h1 = Slicer.compute_dhash(_solid(Color.RED))
    var h2 = Slicer.compute_dhash(_solid(Color.RED))
    assert_eq(Slicer.hamming_distance(h1, h2), 0, "identical images distance 0")


func test_different_patterns_distance_positive() -> void:
    var h1 = Slicer.compute_dhash(_solid(Color.WHITE))
    var h3 = Slicer.compute_dhash(_gradient())
    assert_true(Slicer.hamming_distance(h1, h3) > 0, "solid vs gradient distance > 0")
