extends SceneTree
## Tool: generates 64x64 procedural icons for all artifacts.

const SIZE := 64
const OUTLINE := Color(0.1, 0.08, 0.06, 1.0)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    # В standalone `-s`-режиме autoload-синглтон (Artifacts) не создаётся,
    # поэтому инстанцируем реестр напрямую — get_all() сам собирает определения.
    var artifacts := preload("res://scripts/autoload/ArtifactRegistry.gd").new()
    var dir_path := "res://assets/artifacts"
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    for art in artifacts.get_all():
        var img := _build_icon(art)
        img.save_png("%s/%s.png" % [dir_path, art.id])
    print("[ArtifactIconGenerator] Generated %d icons in %s" % [artifacts.get_all().size(), dir_path])
    quit(0)


func _build_icon(art: Artifact) -> Image:
    var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
    var base_color := Color.DARK_SLATE_GRAY
    match art.rarity:
        Artifact.Rarity.MINOR: base_color = Color(0.45, 0.42, 0.35)
        Artifact.Rarity.MAJOR: base_color = Color(0.25, 0.45, 0.75)
        Artifact.Rarity.RELIC: base_color = Color(0.75, 0.6, 0.15)
    var hi := base_color.lightened(0.4)
    var sh := base_color.darkened(0.4)
    match art.slot:
        Artifact.Slot.HEAD: _draw_crown(img, base_color, hi, sh)
        Artifact.Slot.NECK: _draw_necklace(img, base_color, hi, sh)
        Artifact.Slot.TORSO: _draw_armor(img, base_color, hi, sh)
        Artifact.Slot.WEAPON: _draw_sword(img, base_color, hi, sh, art.is_two_handed)
        Artifact.Slot.SHIELD: _draw_shield(img, base_color, hi, sh)
        Artifact.Slot.LEGS: _draw_legs(img, base_color, hi, sh)
        Artifact.Slot.BOOTS: _draw_boots(img, base_color, hi, sh)
        Artifact.Slot.RING_L, Artifact.Slot.RING_R: _draw_ring(img, base_color, hi, sh)
        Artifact.Slot.MISC_A, Artifact.Slot.MISC_B: _draw_misc(img, base_color, hi, sh, art)
        Artifact.Slot.SPELLBOOK: _draw_book(img, base_color, hi, sh)
    var border_col := Color(0.3, 0.3, 0.3)
    match art.rarity:
        Artifact.Rarity.MINOR: border_col = Color(0.6, 0.6, 0.5)
        Artifact.Rarity.MAJOR: border_col = Color(0.4, 0.6, 0.9)
        Artifact.Rarity.RELIC: border_col = Color(0.95, 0.8, 0.3)
    _draw_border(img, border_col)
    return img


func _sp(img: Image, x: int, y: int, c: Color) -> void:
    if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
        img.set_pixel(x, y, c)


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            var dx := float(x - cx) / float(rx)
            var dy := float(y - cy) / float(ry)
            if dx * dx + dy * dy <= 1.0: _sp(img, x, y, c)


func _rect(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            _sp(img, x, y, c)


func _draw_border(img: Image, c: Color) -> void:
    for i in SIZE:
        _sp(img, i, 0, c); _sp(img, i, SIZE-1, c); _sp(img, 0, i, c); _sp(img, SIZE-1, i, c)


func _draw_crown(img: Image, b: Color, hi: Color, _s: Color) -> void:
    _rect(img, 12, 30, 52, 48, b); _rect(img, 12, 30, 52, 34, hi); _rect(img, 12, 44, 52, 48, b.darkened(0.4))
    for sx in [16, 24, 32, 40, 48]:
        for y in range(20, 32):
            var hw := 2 - (y - 20) / 3
            _rect(img, sx - hw, y, sx + hw, y, b); _sp(img, sx, y, hi)
        _sp(img, sx, 20, Color.RED)


func _draw_necklace(img: Image, b: Color, hi: Color, sh: Color) -> void:
    for i in 40:
        var a := PI + (float(i) / 40.0) * PI
        var x := int(32 + cos(a) * 18); var y := int(20 + sin(a) * 14)
        _sp(img, x, y, b); _sp(img, x, y+1, sh)
    _ellipse(img, 32, 42, 6, 8, b); _ellipse(img, 31, 41, 3, 4, hi)


func _draw_armor(img: Image, b: Color, hi: Color, sh: Color) -> void:
    _rect(img, 16, 14, 48, 52, b); _rect(img, 16, 14, 48, 18, hi); _rect(img, 16, 48, 48, 52, sh)
    _ellipse(img, 16, 18, 6, 6, b); _ellipse(img, 48, 18, 6, 6, b); _rect(img, 31, 20, 33, 48, sh)


func _draw_sword(img: Image, _b: Color, hi: Color, _s: Color, two: bool) -> void:
    var bt := 8; var bb := 40 if two else 44
    for y in range(bt, bb):
        var hw := 2 + (y - bt) / 10
        _rect(img, 32-hw, y, 32+hw, y, hi); _sp(img, 32, y, Color.WHITE)
    _rect(img, 24, bb, 40, bb+4, Color(0.8, 0.7, 0.2))
    var hb := 56 if two else 50
    _rect(img, 30, bb+4, 34, hb, Color(0.4, 0.25, 0.15))
    _ellipse(img, 32, hb+2, 3, 3, Color(0.8, 0.7, 0.2))


func _draw_shield(img: Image, b: Color, hi: Color, sh: Color) -> void:
    for y in range(12, 54):
        var t := float(y-12) / 42.0; var hw := int(20 - t*t*8)
        _rect(img, 32-hw, y, 32+hw, y, b)
    _rect(img, 12, 12, 52, 16, hi); _rect(img, 20, 48, 44, 52, sh); _ellipse(img, 32, 32, 5, 5, hi)


func _draw_legs(img: Image, b: Color, hi: Color, sh: Color) -> void:
    _rect(img, 16, 14, 30, 50, b); _rect(img, 34, 14, 48, 50, b)
    _rect(img, 16, 14, 30, 18, hi); _rect(img, 34, 14, 48, 18, hi)
    _rect(img, 16, 46, 30, 50, sh); _rect(img, 34, 46, 48, 50, sh); _rect(img, 31, 14, 33, 50, OUTLINE)


func _draw_boots(img: Image, b: Color, hi: Color, sh: Color) -> void:
    _rect(img, 12, 20, 28, 44, b); _rect(img, 12, 44, 32, 52, b)
    _rect(img, 12, 20, 28, 24, hi); _rect(img, 12, 48, 32, 52, sh)
    _rect(img, 36, 20, 52, 44, b); _rect(img, 32, 44, 52, 52, b)
    _rect(img, 36, 20, 52, 24, hi); _rect(img, 32, 48, 52, 52, sh)


func _draw_ring(img: Image, _b: Color, hi: Color, sh: Color) -> void:
    for y in range(12, 52):
        for x in range(12, 52):
            var d := Vector2(x-32, y-32).length()
            if d >= 14 and d <= 20:
                var t := (d-14) / 6.0; _sp(img, x, y, hi.lerp(sh, t))
    _ellipse(img, 32, 18, 4, 4, Color.RED); _sp(img, 31, 17, Color(1.0, 0.7, 0.7))


func _draw_misc(img: Image, b: Color, hi: Color, sh: Color, art: Artifact) -> void:
    match art.id:
        &"lucky_clover":
            for dx in [-10, 10]:
                for dy in [-10, 10]:
                    _ellipse(img, 32+dx, 32+dy, 7, 9, Color(0.2, 0.6, 0.3))
            _rect(img, 31, 32, 33, 52, Color(0.3, 0.5, 0.2))
        &"cloak_undead":
            for y in range(10, 54):
                var hw := int(12 + (y-10)*0.4); _rect(img, 32-hw, y, 32+hw, y, b)
            _rect(img, 10, 10, 54, 14, hi); _ellipse(img, 32, 22, 5, 5, Color(0.5, 0.1, 0.1))
        &"spellbinders_hat":
            for y in range(8, 40):
                var hw := int(4+(y-8)*0.35); _rect(img, 32-hw, y, 32+hw, y, b)
            _rect(img, 8, 40, 56, 46, sh); _rect(img, 8, 40, 56, 42, hi)
            for dx in [-1, 0, 1]:
                for dy in [-1, 0, 1]:
                    _sp(img, 32+dx, 20+dy, Color.YELLOW)
        &"statue_legion":
            _rect(img, 22, 12, 42, 52, b); _rect(img, 22, 12, 42, 18, hi)
            _rect(img, 16, 20, 22, 28, b); _rect(img, 42, 20, 48, 28, b)
            _ellipse(img, 32, 12, 4, 4, hi)
        _:
            _rect(img, 18, 16, 46, 48, Color(0.9, 0.85, 0.7))
            _ellipse(img, 18, 32, 4, 16, Color(0.7, 0.6, 0.4))
            _ellipse(img, 46, 32, 4, 16, Color(0.7, 0.6, 0.4))
            for y in range(22, 42, 4):
                _rect(img, 24, y, 40, y+1, OUTLINE)


func _draw_book(img: Image, _b: Color, hi: Color, sh: Color) -> void:
    _rect(img, 14, 14, 50, 50, Color(0.4, 0.15, 0.15))
    _rect(img, 16, 16, 48, 48, Color(0.95, 0.9, 0.8))
    _rect(img, 31, 14, 33, 50, Color(0.4, 0.15, 0.15))
    _sp(img, 32, 32, Color(0.9, 0.7, 0.2))
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            _sp(img, 32+dx*2, 32+dy*2, Color(0.9, 0.7, 0.2))
