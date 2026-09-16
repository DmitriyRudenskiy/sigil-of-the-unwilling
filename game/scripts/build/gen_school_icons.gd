extends SceneTree

const SIZE_SMALL := 32
const SIZE_LARGE := 64

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dir_path := "res://assets/ui/icons/schools"
    
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    
    # Школы магии
    var schools := [
        {"id": "air", "color": Color(0.7, 0.85, 0.95), "name": "Воздух"},
        {"id": "fire", "color": Color(0.95, 0.4, 0.3), "name": "Огонь"},
        {"id": "water", "color": Color(0.3, 0.6, 0.9), "name": "Вода"},
        {"id": "earth", "color": Color(0.5, 0.65, 0.4), "name": "Земля"},
    ]
    
    for school in schools:
        var img_small := _build_icon(school, SIZE_SMALL)
        img_small.save_png("%s/%s.png" % [dir_path, school.id])
        print("[SchoolIconGenerator] Generated icon for %s" % school.name)
    
    print("[SchoolIconGenerator] Generated %d school icons in %s" % [schools.size(), dir_path])
    quit(0)

func _build_icon(school: Dictionary, size: int) -> Image:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var base_color := school.color as Color
    var hi := base_color.lightened(0.25)
    var sh := base_color.darkened(0.35)
    var outline := Color(0.15, 0.12, 0.08, 1.0)
    
    match school.id:
        &"air":
            _draw_air(img, base_color, hi, sh, outline, size)
        &"fire":
            _draw_fire(img, base_color, hi, sh, outline, size)
        &"water":
            _draw_water(img, base_color, hi, sh, outline, size)
        &"earth":
            _draw_earth(img, base_color, hi, sh, outline, size)
        _:
            _draw_placeholder(img, base_color, size)
    
    return img

func _sp(img: Image, x: int, y: int, c: Color) -> void:
    if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
        img.set_pixel(x, y, c)

func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            var dx: float = float(x - cx) / float(rx) if rx > 0 else 0.0
            var dy: float = float(y - cy) / float(ry) if ry > 0 else 0.0
            if dx * dx + dy * dy <= 1.0:
                _sp(img, x, y, c)

func _rect(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            _sp(img, x, y, c)

func _line(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
    var dx: int = abs(x2 - x1)
    var dy: int = abs(y2 - y1)
    var sx := 1 if x1 < x2 else -1
    var sy := 1 if y1 < y2 else -1
    var err: int = dx - dy
    while true:
        _sp(img, x1, y1, c)
        if x1 == x2 and y1 == y2:
            break
        var e2: int = 2 * err
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

# Воздух: спираль/ветер
func _draw_air(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    
    # Три изогнутые линии ветра (спираль)
    for spiral in 3:
        var start_angle := float(spiral) * 2 * PI / 3
        var points := []
        
        for i in 20:
            var angle := start_angle + float(i) * 0.3
            var radius := 4 + float(i) * 0.8
            var px := center + cos(angle) * radius
            var py := center + sin(angle) * radius
            points.append(Vector2(int(px), int(py)))
        
        # Рисуем линию спирали
        for i in range(points.size() - 1):
            _line(img, points[i].x, points[i].y, points[i+1].x, points[i+1].y, base.lerp(hi, float(i) / 20))
    
    # Маленькие точки (воздушные частицы)
    var particle_positions := [
        Vector2(center - 10, center - 8),
        Vector2(center + 8, center - 6),
        Vector2(center - 6, center + 10),
        Vector2(center + 10, center + 8),
    ]
    
    for pos in particle_positions:
        _ellipse(img, int(pos.x), int(pos.y), 2, 2, hi)
    
    _draw_outline(img, outline, 1)

# Огонь: пламя
func _draw_fire(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Основная форма пламени (конус с изгибами)
    for y in range(bottom_y, 8, -1):
        var progress := float(bottom_y - y) / float(bottom_y - 8)
        var width := int(14 * (1 - progress) + 4 * sin(progress * PI * 2))
        
        if width > 0:
            _rect(img, center - width, y, center + width, y, base.lerp(hi, progress * 0.5))
    
    # Внутреннее яркое ядро
    for y in range(bottom_y - 4, 14, -1):
        var progress := float(bottom_y - 4 - y) / float(bottom_y - 18)
        var width := int(8 * (1 - progress * 0.7))
        
        if width > 0:
            _rect(img, center - width, y, center + width, y, hi)
    
    # Искры вокруг
    var spark_positions := [
        Vector2(center - 8, 12),
        Vector2(center + 10, 14),
        Vector2(center - 12, 18),
        Vector2(center + 6, 10),
    ]
    
    for pos in spark_positions:
        _sp(img, int(pos.x), int(pos.y), Color.YELLOW)
        _sp(img, int(pos.x), int(pos.y) - 1, Color.ORANGE)
    
    _draw_outline(img, outline, 1)

# Вода: волна/капля
func _draw_water(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    
    # Большая капля в центре
    var drop_top := 10
    var drop_bottom := size - 10
    
    for y in range(drop_top, drop_bottom):
        var progress := float(y - drop_top) / float(drop_bottom - drop_top)
        var width := int(12 * sin(progress * PI) * (1 - progress * 0.3))
        
        if width > 0:
            _rect(img, center - width, y, center + width, y, base.lerp(hi, progress * 0.4))
    
    # Блик на капле
    _ellipse(img, center - 4, drop_top + 6, 3, 4, hi)
    
    # Две волны снизу по бокам
    for side in [-1, 1]:
        var wave_cx: int = center + int(side) * 10
        var wave_y := drop_bottom - 4
        
        for i in 6:
            var wx: int = wave_cx + i * int(side)
            var wy := wave_y + sin(float(i) * 0.8) * 3
            _ellipse(img, int(wx), int(wy), 2, 2, base.lightened(0.2))
    
    # Маленькие капли вокруг
    var droplet_positions := [
        Vector2(center - 12, center - 6),
        Vector2(center + 14, center - 4),
        Vector2(center - 8, center + 12),
    ]
    
    for pos in droplet_positions:
        _ellipse(img, int(pos.x), int(pos.y), 2, 3, base.lightened(0.3))
    
    _draw_outline(img, outline, 1)

# Земля: гора/кристалл
func _draw_earth(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Горный массив (треугольники разной высоты)
    var peaks := [
        {"x": center - 8, "h": 14},
        {"x": center, "h": 20},
        {"x": center + 8, "h": 12},
    ]
    
    for peak in peaks:
        var px := peak.x as int
        var ph := peak.h as int
        var peak_top := bottom_y - ph
        
        # Рисуем треугольник горы
        for y in range(peak_top, bottom_y):
            var progress := float(y - peak_top) / float(ph)
            var width := int((ph - (y - peak_top)) * 0.8)
            
            if width > 0:
                _rect(img, px - width, y, px + width, y, base.lerp(sh, progress * 0.5))
        
        # Снежная шапка на вершине (для центральной горы)
        if px == center:
            for y in range(peak_top, peak_top + 6):
                var progress := float(y - peak_top) / 6
                var width := int((6 - (y - peak_top)) * 0.6)
                if width > 0:
                    _rect(img, px - width, y, px + width, y, Color(0.95, 0.95, 0.95))
    
    # Кристаллы у подножия
    var crystal_positions := [center - 12, center + 12]
    for cx in crystal_positions:
        for i in 3:
            var crystal_h := 6 + i * 2
            var crystal_y := bottom_y - crystal_h
            _line(img, cx, bottom_y, cx - 2, crystal_y, base.lightened(0.3))
            _line(img, cx, bottom_y, cx + 2, crystal_y, base.lightened(0.3))
            _line(img, cx - 2, crystal_y, cx + 2, crystal_y, base.lightened(0.2))
    
    _draw_outline(img, outline, 1)
