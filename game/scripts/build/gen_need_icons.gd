extends SceneTree

const SIZE_SMALL := 32
const SIZE_LARGE := 64

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dir_path := "res://assets/ui/icons/needs"
    
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    
    # Потребности героя
    var needs := [
        {"id": "rest", "color": Color(0.3, 0.5, 0.8), "name": "Отдых"},
        {"id": "social", "color": Color(0.3, 0.7, 0.4), "name": "Общение"},
        {"id": "inspiration", "color": Color(0.9, 0.8, 0.3), "name": "Вдохновение"},
    ]
    
    for need in needs:
        var img_small := _build_icon(need, SIZE_SMALL)
        img_small.save_png("%s/%s.png" % [dir_path, need.id])
        print("[NeedIconGenerator] Generated icon for %s" % need.name)
    
    print("[NeedIconGenerator] Generated %d need icons in %s" % [needs.size(), dir_path])
    quit(0)

func _build_icon(need: Dictionary, size: int) -> Image:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var base_color := need.color as Color
    var hi := base_color.lightened(0.25)
    var sh := base_color.darkened(0.35)
    var outline := Color(0.15, 0.12, 0.08, 1.0)
    
    match need.id:
        &"rest":
            _draw_rest(img, base_color, hi, sh, outline, size)
        &"social":
            _draw_social(img, base_color, hi, sh, outline, size)
        &"inspiration":
            _draw_inspiration(img, base_color, hi, sh, outline, size)
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

func _draw_outline(img: Image, color: Color, thickness: int) -> void:
    var w := img.get_width()
    var h := img.get_height()
    for x in range(w):
        _sp(img, x, 0, color)
        _sp(img, x, h - 1, color)
    for y in range(h):
        _sp(img, 0, y, color)
        _sp(img, w - 1, y, color)

func _draw_placeholder(img: Image, base: Color, size: int) -> void:
    var center := size / 2
    var radius := int(size * 0.3)
    _ellipse(img, center, center, radius, radius, base)
    _draw_outline(img, Color.DARK_GRAY, 1)

# Отдых: луна + звёзды
func _draw_rest(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    
    # Луна (полумесяц)
    var moon_r := int(size * 0.25)
    _ellipse(img, center, center, moon_r, moon_r, base)
    _ellipse(img, center + 4, center - 2, moon_r - 2, moon_r - 2, Color(0.1, 0.15, 0.25))
    
    # Звёзды вокруг
    var star_positions := [
        Vector2(center - 10, center - 8),
        Vector2(center + 8, center - 10),
        Vector2(center - 6, center + 8),
    ]
    
    for pos in star_positions:
        # Маленькая звезда (4 луча)
        _sp(img, int(pos.x), int(pos.y), hi)
        _sp(img, int(pos.x) - 1, int(pos.y), hi.lightened(0.2))
        _sp(img, int(pos.x) + 1, int(pos.y), hi.lightened(0.2))
        _sp(img, int(pos.x), int(pos.y) - 1, hi.lightened(0.2))
        _sp(img, int(pos.x), int(pos.y) + 1, hi.lightened(0.2))
    
    _draw_outline(img, outline, 1)

# Общение: два силуэта/пузыря речи
func _draw_social(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    
    # Два пузыря речи
    # Левый пузырь
    _ellipse(img, center - 6, center - 2, 8, 7, base)
    _line(img, center - 10, center + 5, center - 4, center + 5, base)
    _line(img, center - 4, center + 5, center - 2, center + 8, base)
    
    # Правый пузырь
    _ellipse(img, center + 6, center + 2, 8, 7, base.lightened(0.15))
    _line(img, center + 10, center - 5, center + 4, center - 5, base.lightened(0.15))
    _line(img, center + 4, center - 5, center + 2, center - 8, base.lightened(0.15))
    
    # Точки внутри (символ диалога)
    for i in 3:
        var dot_x := center - 8 + i * 3
        _ellipse(img, dot_x, center - 2, 1, 1, hi)
        _ellipse(img, dot_x + 4, center + 2, 1, 1, hi)
    
    _draw_outline(img, outline, 1)

# Вдохновение: лампочка/свет
func _draw_inspiration(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    
    # Лампочка (овал снизу + цоколь)
    var bulb_r := int(size * 0.2)
    _ellipse(img, center, center - 4, bulb_r, bulb_r + 2, base)
    _ellipse(img, center, center - 4, bulb_r - 3, bulb_r - 1, hi)
    
    # Цоколь лампы
    _rect(img, center - 4, center + 6, center + 4, center + 10, Color(0.6, 0.55, 0.5))
    
    # Лучи света
    var rays := 8
    for i in rays:
        var angle := float(i) * 2 * PI / float(rays)
        var ray_start := 12
        var ray_end := 18
        
        var sx := center + cos(angle) * ray_start
        var sy := (center - 4) + sin(angle) * ray_start
        var ex := center + cos(angle) * ray_end
        var ey := (center - 4) + sin(angle) * ray_end
        
        # Рисуем луч только если он направлен вверх и в стороны
        if sin(angle) < 0 or abs(cos(angle)) > 0.5:
            _line(img, int(sx), int(sy), int(ex), int(ey), hi.lightened(0.3))
    
    # Блеск на лампочке
    _sp(img, center - 3, center - 6, Color.WHITE)
    _sp(img, center - 2, center - 5, Color.WHITE)
    
    _draw_outline(img, outline, 1)
