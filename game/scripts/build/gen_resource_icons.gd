extends SceneTree

const SIZE_SMALL := 32
const SIZE_LARGE := 64

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dir_small := "res://assets/ui/icons/resources"
    var dir_large := "res://assets/ui/icons/resources"
    
    if not DirAccess.dir_exists_absolute(dir_small):
        DirAccess.make_dir_recursive_absolute(dir_small)
    
    # Ресурсы из ThemeConfig
    var resources := [
        {"id": "wood", "color": Color(0.62, 0.44, 0.24), "name": "Дерево"},
        {"id": "mercury", "color": Color(0.64, 0.67, 0.74), "name": "Ртуть"},
        {"id": "ore", "color": Color(0.50, 0.40, 0.34), "name": "Руда"},
        {"id": "sulfur", "color": Color(0.87, 0.80, 0.30), "name": "Сера"},
        {"id": "crystal", "color": Color(0.40, 0.63, 0.88), "name": "Кристаллы"},
        {"id": "gems", "color": Color(0.52, 0.80, 0.62), "name": "Самоцветы"},
        {"id": "gold", "color": Color(0.92, 0.77, 0.28), "name": "Золото"},
        {"id": "silver", "color": Color(0.85, 0.85, 0.9), "name": "Серебро"},
        {"id": "quartz", "color": Color(0.95, 0.95, 0.95), "name": "Кварц"},
        {"id": "coal", "color": Color(0.2, 0.2, 0.2), "name": "Уголь"},
    ]
    
    for res in resources:
        var img_small := _build_icon(res, SIZE_SMALL)
        var img_large := _build_icon(res, SIZE_LARGE)
        img_small.save_png("%s/%s.png" % [dir_small, res.id])
        # Для больших можно сохранить с суффиксом или в отдельную папку
        print("[ResourceIconGenerator] Generated icon for %s" % res.name)
    
    print("[ResourceIconGenerator] Generated %d resource icons in %s" % [resources.size(), dir_small])
    quit(0)

func _build_icon(res: Dictionary, size: int) -> Image:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var base_color := res.color as Color
    var hi := base_color.lightened(0.3)
    var sh := base_color.darkened(0.4)
    var outline := Color(0.15, 0.12, 0.08, 1.0)
    
    match res.id:
        &"wood":
            _draw_tree(img, base_color, hi, sh, outline, size)
        &"mercury":
            _draw_flask(img, base_color, hi, sh, outline, size)
        &"ore":
            _draw_rock(img, base_color, hi, sh, outline, size)
        &"sulfur":
            _draw_crystals(img, base_color, hi, sh, outline, size)
        &"crystal":
            _draw_gem_octahedron(img, base_color, hi, sh, outline, size)
        &"gems":
            _draw_cut_gem(img, base_color, hi, sh, outline, size)
        &"gold":
            _draw_coins(img, base_color, hi, sh, outline, size)
        &"silver":
            _draw_ingot(img, base_color, hi, sh, outline, size)
        &"quartz":
            _draw_quartz_cluster(img, base_color, hi, sh, outline, size)
        &"coal":
            _draw_coal_lump(img, base_color, hi, sh, outline, size)
        _:
            _draw_placeholder(img, base_color, size)
    
    return img

func _sp(img: Image, x: int, y: int, c: Color) -> void:
    if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
        img.set_pixel(x, y, c)

func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            var dx := float(x - cx) / float(rx) if rx > 0 else 0
            var dy := float(y - cy) / float(ry) if ry > 0 else 0
            if dx * dx + dy * dy <= 1.0:
                _sp(img, x, y, c)

func _rect(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            _sp(img, x, y, c)

func _line(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
    var dx := abs(x2 - x1)
    var dy := abs(y2 - y1)
    var sx := 1 if x1 < x2 else -1
    var sy := 1 if y1 < y2 else -1
    var err := dx - dy
    while true:
        _sp(img, x1, y1, c)
        if x1 == x2 and y1 == y2:
            break
        var e2 := 2 * err
        if e2 > -dy:
            err -= dy
            x1 += sx
        if e2 < dx:
            err += dx
            y1 += sy

func _draw_tree(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var scale := float(size) / 64.0
    
    # Ствол
    var trunk_w := int(6 * scale)
    var trunk_h := int(16 * scale)
    _rect(img, center - trunk_w, size - trunk_h - 4, center + trunk_w, size - 4, base.darkened(0.3))
    
    # Крона (треугольник)
    var base_y := size - trunk_h - 4
    for level in 3:
        var level_y := base_y - level * int(10 * scale)
        var width := int((16 - level * 4) * scale)
        for y in range(level_y, level_y + int(10 * scale)):
            var progress := float(y - level_y) / float(10 * scale)
            var w := int(width * (1 - progress * 0.5))
            _rect(img, center - w, y, center + w, y, base.lerp(hi, float(level) / 3))
    
    # Контур
    _draw_outline(img, outline, 1)

func _draw_flask(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 8
    var top_y := 8
    var neck_y := int(size * 0.35)
    
    # Колба (овал снизу)
    _ellipse(img, center, bottom_y - 10, int(size * 0.25), int(size * 0.25), base)
    _ellipse(img, center, bottom_y - 10, int(size * 0.2) - 2, int(size * 0.2) - 2, hi)
    
    # Горлышко
    var neck_w := int(size * 0.08)
    _rect(img, center - neck_w, top_y, center + neck_w, neck_y, base)
    
    # Жидкость внутри
    var liquid_y := bottom_y - 12
    _ellipse(img, center, liquid_y, int(size * 0.18), int(size * 0.15), base.lightened(0.2))
    
    _draw_outline(img, outline, 1)

func _draw_rock(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var points := [
        Vector2(center - 12, size - 10),
        Vector2(center - 14, size - 20),
        Vector2(center - 8, size - 28),
        Vector2(center + 4, size - 30),
        Vector2(center + 14, size - 24),
        Vector2(center + 12, size - 12),
        Vector2(center + 6, size - 6),
        Vector2(center - 6, size - 6),
    ]
    
    # Заполнение многоугольника
    for y in range(size):
        var intersections := []
        for i in range(points.size()):
            var p1 := points[i]
            var p2 := points[(i + 1) % points.size()]
            if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
                var t := float(y - p1.y) / float(p2.y - p1.y)
                var x := p1.x + t * (p2.x - p1.x)
                intersections.append(x)
        
        intersections.sort()
        for i in range(0, intersections.size() - 1, 2):
            _rect(img, int(intersections[i]), y, int(intersections[i + 1]), y, base)
    
    # Блик
    _ellipse(img, center - 4, size - 16, 4, 4, hi)
    _draw_outline(img, outline, 1)

func _draw_crystals(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    # Три кристалла
    for i in 3:
        var cx := center - 8 + i * 8
        var cy := size - 8
        var height := 12 + i * 4
        # Ромб
        _line(img, cx, cy - height, cx - 4, cy, base)
        _line(img, cx, cy - height, cx + 4, cy, base)
        _line(img, cx - 4, cy, cx, cy + 4, sh)
        _line(img, cx + 4, cy, cx, cy + 4, sh)
        _rect(img, cx - 4, cy, 8, 4, base.darkened(0.2))
    _draw_outline(img, outline, 1)

func _draw_gem_octahedron(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var radius := int(size * 0.25)
    
    # Верхняя пирамида
    for y in range(center - radius, center):
        var progress := float(y - (center - radius)) / float(radius)
        var w := int(radius * progress)
        _rect(img, center - w, y, center + w, y, base.lerp(hi, progress))
    
    # Нижняя пирамида
    for y in range(center, center + radius):
        var progress := float(y - center) / float(radius)
        var w := int(radius * (1 - progress))
        _rect(img, center - w, y, center + w, y, base.lerp(sh, progress))
    
    _draw_outline(img, outline, 1)

func _draw_cut_gem(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var outer := int(size * 0.28)
    var inner := int(size * 0.15)
    
    # Внешний восьмиугольник (упрощённо - квадрат с обрезанными углами)
    _rect(img, center - outer, center - inner, center + outer, center + inner, base)
    _rect(img, center - inner, center - outer, center + inner, center + outer, base)
    
    # Грани
    _rect(img, center - 2, center - inner, center + 2, center + inner, hi)
    _rect(img, center - inner, center - 2, center + inner, center + 2, hi)
    
    _draw_outline(img, outline, 1)

func _draw_coins(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    # Три монеты стопкой
    for i in 3:
        var offset := i * 3 - 3
        _ellipse(img, center + offset, size - 14 + i * 2, 8, 8, base.lerp(hi, float(i) / 3))
        # Детали монеты
        _sp(img, center + offset, size - 14 + i * 2, hi)
    _draw_outline(img, outline, 1)

func _draw_ingot(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    # Слиток трапециевидной формы
    var top_w := int(size * 0.15)
    var bottom_w := int(size * 0.25)
    var height := int(size * 0.3)
    var top_y := int(size * 0.3)
    var bottom_y := top_y + height
    
    for y in range(top_y, bottom_y):
        var progress := float(y - top_y) / float(height)
        var w := int(top_w + (bottom_w - top_w) * progress)
        _rect(img, center - w, y, center + w, y, base.lerp(sh, progress))
    
    _rect(img, center - top_w, top_y, center + top_w, top_y + 4, hi)
    _draw_outline(img, outline, 1)

func _draw_quartz_cluster(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    # Пять кристаллов кварца веером
    for i in 5:
        var angle := -PI/4 + float(i) * (PI/2) / 4
        var cx := center + cos(angle) * 8
        var cy := size - 10 + sin(angle) * 4
        var height := 14 - abs(i - 2) * 2
        # Кристалл
        _line(img, int(cx), int(cy), int(cx + sin(angle) * 4), int(cy - height), base)
        _line(img, int(cx), int(cy), int(cx - sin(angle) * 4), int(cy - height), base)
        _sp(img, int(cx), int(cy - height), hi)
    _draw_outline(img, outline, 1)

func _draw_coal_lump(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    # Неправильная форма угля
    var points := [
        Vector2(center - 10, size - 12),
        Vector2(center - 12, size - 22),
        Vector2(center - 6, size - 28),
        Vector2(center + 6, size - 26),
        Vector2(center + 12, size - 18),
        Vector2(center + 8, size - 8),
        Vector2(center - 4, size - 6),
    ]
    
    for y in range(size):
        var intersections := []
        for i in range(points.size()):
            var p1 := points[i]
            var p2 := points[(i + 1) % points.size()]
            if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
                var t := float(y - p1.y) / float(p2.y - p1.y)
                var x := p1.x + t * (p2.x - p1.x)
                intersections.append(x)
        
        intersections.sort()
        for i in range(0, intersections.size() - 1, 2):
            _rect(img, int(intersections[i]), y, int(intersections[i + 1]), y, base)
    
    # Блеск
    _sp(img, center - 4, size - 18, hi)
    _sp(img, center + 2, size - 14, hi.lightened(0.2))
    _draw_outline(img, outline, 1)

func _draw_placeholder(img: Image, base: Color, size: int) -> void:
    var center := size / 2
    var radius := int(size * 0.3)
    _ellipse(img, center, center, radius, radius, base)
    _draw_outline(img, Color.DARK_GRAY, 1)

func _draw_outline(img: Image, color: Color, thickness: int) -> void:
    var w := img.get_width()
    var h := img.get_height()
    for x in range(w):
        _sp(img, x, 0, color)
        _sp(img, x, h - 1, color)
    for y in range(h):
        _sp(img, 0, y, color)
        _sp(img, w - 1, y, color)
