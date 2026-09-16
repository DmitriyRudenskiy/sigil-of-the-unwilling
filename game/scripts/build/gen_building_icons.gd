extends SceneTree

const SIZE_SMALL := 32
const SIZE_LARGE := 64

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dir_path := "res://assets/ui/icons/buildings"
    
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    
    # Здания города
    var buildings := [
        {"id": "farm", "color": Color(0.8, 0.7, 0.4), "name": "Ферма"},
        {"id": "mill", "color": Color(0.7, 0.6, 0.5), "name": "Мельница"},
        {"id": "bakery", "color": Color(0.9, 0.8, 0.6), "name": "Пекарня"},
        {"id": "mine", "color": Color(0.4, 0.35, 0.3), "name": "Шахта"},
        {"id": "smithy", "color": Color(0.5, 0.4, 0.35), "name": "Кузница"},
        {"id": "tavern", "color": Color(0.6, 0.4, 0.3), "name": "Таверна"},
        {"id": "school", "color": Color(0.4, 0.5, 0.7), "name": "Школа магии"},
        {"id": "trade_post", "color": Color(0.7, 0.6, 0.5), "name": "Торговый пост"},
        {"id": "market", "color": Color(0.8, 0.7, 0.5), "name": "Рынок"},
        {"id": "shack", "color": Color(0.5, 0.45, 0.4), "name": "Лачуга"},
        {"id": "walls", "color": Color(0.6, 0.55, 0.5), "name": "Стены"},
        {"id": "barracks", "color": Color(0.5, 0.45, 0.5), "name": "Казармы"},
    ]
    
    for bld in buildings:
        var img_small := _build_icon(bld, SIZE_SMALL)
        img_small.save_png("%s/%s.png" % [dir_path, bld.id])
        print("[BuildingIconGenerator] Generated icon for %s" % bld.name)
    
    print("[BuildingIconGenerator] Generated %d building icons in %s" % [buildings.size(), dir_path])
    quit(0)

func _build_icon(bld: Dictionary, size: int) -> Image:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var base_color := bld.color as Color
    var hi := base_color.lightened(0.25)
    var sh := base_color.darkened(0.35)
    var outline := Color(0.15, 0.12, 0.08, 1.0)
    
    match bld.id:
        &"farm":
            _draw_farm(img, base_color, hi, sh, outline, size)
        &"mill":
            _draw_mill(img, base_color, hi, sh, outline, size)
        &"bakery":
            _draw_bakery(img, base_color, hi, sh, outline, size)
        &"mine":
            _draw_mine(img, base_color, hi, sh, outline, size)
        &"smithy":
            _draw_smithy(img, base_color, hi, sh, outline, size)
        &"tavern":
            _draw_tavern(img, base_color, hi, sh, outline, size)
        &"school":
            _draw_school(img, base_color, hi, sh, outline, size)
        &"trade_post":
            _draw_trade_post(img, base_color, hi, sh, outline, size)
        &"market":
            _draw_market(img, base_color, hi, sh, outline, size)
        &"shack":
            _draw_shack(img, base_color, hi, sh, outline, size)
        &"walls":
            _draw_walls(img, base_color, hi, sh, outline, size)
        &"barracks":
            _draw_barracks(img, base_color, hi, sh, outline, size)
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

# Ферма: колосья пшеницы
func _draw_farm(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Три колоса
    for i in 3:
        var cx := center - 8 + i * 8
        var stem_h := 16 + (i % 2) * 4
        
        # Стебель
        _line(img, cx, bottom_y, cx, bottom_y - stem_h, base.darkened(0.3))
        
        # Колос (овалы вдоль стебля)
        for j in 3:
            var grain_y := bottom_y - stem_h + j * 4 + 2
            _ellipse(img, cx, grain_y, 3, 2, base.lerp(hi, float(j) / 3))
    
    # Земля внизу
    _rect(img, 4, bottom_y, size - 4, bottom_y + 4, Color(0.4, 0.3, 0.2))
    
    _draw_outline(img, outline, 1)

# Мельница: здание с крыльями
func _draw_mill(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Здание (трапеция)
    var top_w := int(size * 0.2)
    var bottom_w := int(size * 0.3)
    var height := int(size * 0.4)
    var top_y := bottom_y - height
    
    for y in range(top_y, bottom_y):
        var progress := float(y - top_y) / float(height)
        var w := int(top_w + (bottom_w - top_w) * progress)
        _rect(img, center - w, y, center + w, y, base)
    
    # Крыша
    _rect(img, center - top_w - 2, top_y - 6, center + top_w + 2, top_y, sh)
    
    # Крылья мельницы (крест)
    _rect(img, center - 2, top_y - 12, center + 2, top_y + 8, base.darkened(0.2))
    _rect(img, center - 10, top_y - 4, center + 10, top_y + 4, base.darkened(0.2))
    
    _draw_outline(img, outline, 1)

# Пекарня: хлеб/буханка
func _draw_bakery(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Буханка хлеба (овал)
    _ellipse(img, center, bottom_y - 10, 12, 8, base)
    _ellipse(img, center, bottom_y - 10, 8, 5, hi)
    
    # Нарезка (линии на хлебе)
    for i in 4:
        var x := center - 6 + i * 4
        _line(img, x, bottom_y - 14, x + 2, bottom_y - 8, sh)
    
    # Стол/прилавок
    _rect(img, 6, bottom_y, size - 6, bottom_y + 4, Color(0.5, 0.35, 0.25))
    
    _draw_outline(img, outline, 1)

# Шахта: кирка + вход в шахту
func _draw_mine(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Вход в шахту (арка)
    _rect(img, center - 10, bottom_y - 14, center + 10, bottom_y, base.darkened(0.3))
    _ellipse(img, center, bottom_y - 14, 10, 6, base.darkened(0.2))
    
    # Кирка (крестом)
    var pick_x := center + 8
    var pick_y := bottom_y - 20
    
    # Рукоять
    _line(img, pick_x - 6, pick_y + 6, pick_x + 6, pick_y - 6, Color(0.5, 0.35, 0.2))
    
    # Лезвия
    _line(img, pick_x - 8, pick_y - 4, pick_x + 4, pick_y + 4, base)
    _line(img, pick_x - 4, pick_y - 8, pick_x + 8, pick_y, base)
    
    _draw_outline(img, outline, 1)

# Кузница: молот + наковальня
func _draw_smithy(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Наковальня
    _rect(img, center - 10, bottom_y - 8, center + 10, bottom_y, base.darkened(0.2))
    _rect(img, center - 6, bottom_y - 12, center + 6, bottom_y - 8, base)
    
    # Молот над наковальней
    var hammer_y := bottom_y - 20
    _rect(img, center + 4, hammer_y, center + 8, hammer_y + 10, Color(0.4, 0.3, 0.2))  # рукоять
    _rect(img, center, hammer_y - 4, center + 12, hammer_y + 2, base.darkened(0.4))  # головка
    
    # Искры
    _sp(img, center - 4, hammer_y - 6, Color.YELLOW)
    _sp(img, center - 8, hammer_y - 4, Color.ORANGE)
    
    _draw_outline(img, outline, 1)

# Таверна: кружка пива
func _draw_tavern(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Кружка (цилиндр)
    var mug_w := 10
    var mug_h := 16
    var mug_top := bottom_y - mug_h
    
    _rect(img, center - mug_w, mug_top, center + mug_w, bottom_y, base)
    _rect(img, center - mug_w, mug_top, center + mug_w, mug_top + 4, hi)  # пенка сверху
    
    # Ручка кружки
    _line(img, center + mug_w, mug_top + 4, center + mug_w + 6, mug_top + 4, base.darkened(0.2))
    _line(img, center + mug_w + 6, mug_top + 4, center + mug_w + 6, mug_top + 10, base.darkened(0.2))
    _line(img, center + mug_w + 6, mug_top + 10, center + mug_w, mug_top + 10, base.darkened(0.2))
    
    # Пена
    _rect(img, center - mug_w + 2, mug_top + 2, center + mug_w - 2, mug_top + 6, Color(0.95, 0.9, 0.7))
    
    _draw_outline(img, outline, 1)

# Школа магии: книга со звездой
func _draw_school(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Книга (раскрытая)
    _rect(img, center - 12, bottom_y - 14, center - 2, bottom_y, base)
    _rect(img, center + 2, bottom_y - 14, center + 12, bottom_y, base.lightened(0.1))
    
    # Корешок книги
    _rect(img, center - 2, bottom_y - 14, center + 2, bottom_y, sh)
    
    # Магическая звезда над книгой
    var star_y := bottom_y - 22
    for i in 5:
        var angle := -PI/2 + float(i) * 2 * PI / 5
        var sx := center + cos(angle) * 8
        var sy := star_y + sin(angle) * 8
        _sp(img, int(sx), int(sy), hi)
        _line(img, center, star_y, int(sx), int(sy), base)
    
    _draw_outline(img, outline, 1)

# Торговый пост: весы
func _draw_trade_post(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Стойка весов
    _rect(img, center - 2, bottom_y - 16, center + 2, bottom_y, base.darkened(0.3))
    
    # Балка весов
    _rect(img, center - 12, bottom_y - 16, center + 12, bottom_y - 14, base)
    
    # Чашки весов
    _ellipse(img, center - 10, bottom_y - 8, 6, 4, base)
    _ellipse(img, center + 10, bottom_y - 8, 6, 4, base)
    
    # Верёвки
    _line(img, center - 12, bottom_y - 16, center - 10, bottom_y - 12, sh)
    _line(img, center + 12, bottom_y - 16, center + 10, bottom_y - 12, sh)
    
    _draw_outline(img, outline, 1)

# Рынок: прилавок с товарами
func _draw_market(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Прилавок
    _rect(img, center - 12, bottom_y - 10, center + 12, bottom_y, base)
    
    # Тент над прилавком
    _rect(img, center - 14, bottom_y - 18, center + 14, bottom_y - 14, Color(0.8, 0.4, 0.3))
    
    # Товары на прилавке (круги)
    for i in 5:
        var x := center - 10 + i * 5
        var item_color: Color = [Color.RED, Color.GREEN, Color.YELLOW, Color.ORANGE, Color.PURPLE][i]
        _ellipse(img, x, bottom_y - 12, 3, 3, item_color)
    
    _draw_outline(img, outline, 1)

# Лачуга: простой домик
func _draw_shack(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Стены
    _rect(img, center - 10, bottom_y - 14, center + 10, bottom_y, base)
    
    # Крыша (треугольник)
    for y in range(bottom_y - 20, bottom_y - 14):
        var progress := float(bottom_y - 14 - y) / 6
        var w := int(10 + progress * 4)
        _rect(img, center - w, y, center + w, y, sh)
    
    # Дверь
    _rect(img, center - 4, bottom_y - 10, center + 4, bottom_y, base.darkened(0.4))
    
    # Окно
    _rect(img, center - 8, bottom_y - 12, center - 5, bottom_y - 8, Color(0.6, 0.7, 0.8))
    
    _draw_outline(img, outline, 1)

# Стены: зубчатая стена
func _draw_walls(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var bottom_y := size - 6
    
    # Основная стена
    _rect(img, 6, bottom_y - 12, size - 6, bottom_y, base)
    
    # Зубцы
    for x in range(8, size - 8, 8):
        _rect(img, x, bottom_y - 18, x + 4, bottom_y - 12, base)
    
    # Ворота
    _rect(img, size/2 - 6, bottom_y - 10, size/2 + 6, bottom_y, base.darkened(0.3))
    
    _draw_outline(img, outline, 1)

# Казармы: шлем + мечи крестом
func _draw_barracks(img: Image, base: Color, hi: Color, sh: Color, outline: Color, size: int) -> void:
    var center := size / 2
    var bottom_y := size - 6
    
    # Здание казарм
    _rect(img, center - 12, bottom_y - 12, center + 12, bottom_y, base)
    
    # Крыша
    _rect(img, center - 14, bottom_y - 16, center + 14, bottom_y - 12, sh)
    
    # Шлем спереди
    _ellipse(img, center, bottom_y - 18, 6, 5, base.darkened(0.2))
    _rect(img, center - 4, bottom_y - 16, center + 4, bottom_y - 14, hi)
    
    # Мечи крестом за шлемом
    _line(img, center - 8, bottom_y - 22, center + 8, bottom_y - 14, Color(0.7, 0.7, 0.75))
    _line(img, center + 8, bottom_y - 22, center - 8, bottom_y - 14, Color(0.7, 0.7, 0.75))
    
    _draw_outline(img, outline, 1)
