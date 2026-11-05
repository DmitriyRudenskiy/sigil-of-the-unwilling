extends Node2D
## ============================================================================
## HexMapGenerator — генератор гексагональной карты для Godot 4.7 (TileMapLayer)
##
## Закрывает типовые ошибки генераторов карт, из-за которых «карта кривая»:
##   1. Дыры в форме карты      -> осевой (axial) регион, а не квадратный цикл;
##   2. Швы/нахлёст рядов       -> позиции считает TileMapLayer по TileSet,
##                                 вручную ничего умножать на 0.75 не нужно;
##   3. Прозрачные щели         -> TileSet строится как TILE_SHAPE_HEXAGON
##                                 с правильным tile_offset_axis;
##   4. Пустые клетки           -> atlas_coords валидируются по размеру атласа;
##   5. Одинаковые карты        -> новый случайный сид на каждый запуск
##                                 (или фиксированный через seed_override);
##   6. Призраки тайлов         -> clear() перед каждой генерацией.
##
## Как пользоваться:
##   • повесьте скрипт на любой Node2D в сцене и запустите проект;
##   • F5 в запущенной игре — перегенерировать карту;
##   • свой kit-sheet: назначьте atlas_texture и поправьте biome_tiles
##     (биом -> колонка/строка тайла в атласе);
##   • правильные (неслюснутые) пропорции гекса: POINTY_TOP — 64x74,
##     FLAT_TOP — 74x64; для демо-атласа они подставляются автоматически.
## ============================================================================

signal map_generated(cell_count: int, used_seed: int)

## Биомы карты (набор как на kit-sheet: трава/снег/скалы/вода/грязь).
enum Biome { GRASS, GRASS_FLOWERS, FOREST, SNOW, ICE, WATER, ROCK, MUD }

## Ориентация гексагонов.
## POINTY_TOP  -> TileSet.TILE_OFFSET_AXIS_HORIZONTAL (острый угол сверху);
## FLAT_TOP    -> TileSet.TILE_OFFSET_AXIS_VERTICAL   (плоская грань сверху).
enum HexOrientation { POINTY_TOP, FLAT_TOP }

const ATLAS_COLS := 4
const ATLAS_ROWS := 2

## Палитра демо-атласа (индекс = Biome).
const _DEMO_COLORS := {
        Biome.GRASS: Color(0.42, 0.70, 0.24),
        Biome.GRASS_FLOWERS: Color(0.45, 0.72, 0.26),
        Biome.FOREST: Color(0.40, 0.66, 0.23),
        Biome.SNOW: Color(0.93, 0.95, 0.98),
        Biome.ICE: Color(0.70, 0.84, 0.94),
        Biome.WATER: Color(0.24, 0.49, 0.78),
        Biome.ROCK: Color(0.56, 0.56, 0.53),
        Biome.MUD: Color(0.55, 0.44, 0.30),
}
## Точки цветов/камешков (доли размера тайла).
const _FLOWER_SPOTS: Array[Vector2] = [
        Vector2(0.30, 0.38), Vector2(0.62, 0.30), Vector2(0.50, 0.62),
        Vector2(0.32, 0.66), Vector2(0.68, 0.58),
]
const _MUD_SPOTS: Array[Vector2] = [Vector2(0.35, 0.40), Vector2(0.60, 0.55), Vector2(0.45, 0.70)]
const _CANOPY_CIRCLES: Array[Vector2] = [Vector2(0, -12), Vector2(-9, -5), Vector2(9, -5)]

@export_group("Карта")
## Ориентация гексов. Должна совпадать с формой тайлов вашего атласа!
@export var orientation: HexOrientation = HexOrientation.POINTY_TOP
## Радиус карты в гексах (24 -> 1801 клетка: 3R^2 + 3R + 1).
@export_range(1, 128) var map_radius: int = 24
## Генерировать карту автоматически в _ready().
@export var generate_on_ready: bool = true
## -1 = случайный сид при каждом запуске; иначе карта воспроизводима.
@export var seed_override: int = -1
## Создать Camera2D и навести её на карту при генерации.
@export var auto_fit_camera: bool = true

@export_group("Биомы и их вес (0 = биом не используется)")
@export_range(0.0, 100.0) var weight_grass: float = 34.0
@export_range(0.0, 100.0) var weight_flowers: float = 8.0
@export_range(0.0, 100.0) var weight_forest: float = 10.0
@export_range(0.0, 100.0) var weight_snow: float = 16.0
@export_range(0.0, 100.0) var weight_ice: float = 6.0
@export_range(0.0, 100.0) var weight_water: float = 12.0
@export_range(0.0, 100.0) var weight_rock: float = 9.0
@export_range(0.0, 100.0) var weight_mud: float = 5.0

@export_group("Пятна биомов (опционально)")
## Вместо независимого рандома на каждый гекс — случайные области-пятна
## (Voronoi по гекс-расстоянию от случайных центров). Полный рандом = false.
@export var use_biome_blobs: bool = false
## Сколько случайных центров-пятен бросить на карту.
@export_range(2, 512) var blob_count: int = 18

@export_group("TileSet")
## Текстура вашего kit-sheet. Если пусто — рисуется демо-атлас гексов (4x2).
@export var atlas_texture: Texture2D
## Размер ОДНОЙ клетки атласа (полный bounding box гексагона), в пикселях.
@export var tile_size: Vector2i = Vector2i(64, 64)
## Строить корректный гексагональный TileSet из скрипта.
## Отключите, если TileSet настроен вручную в редакторе.
@export var build_tileset_automatically: bool = true
## Строгий режим: для биома нет тайла в атласе -> push_error и клетка
## остаётся пустой («отсутствие = провал приёмки», как в прод-конвейере),
## а не подмена на (0, 0) с push_warning. По умолчанию false — демка
## всегда рисует полную картинку.
@export var strict_missing_tiles: bool = false
## Путь к готовому TileMapLayer. Пусто -> берётся/создаётся ребёнок "TileMapLayer".
@export var tilemap_path: NodePath
## Биом -> координаты тайла в атласе (колонка, строка).
## По умолчанию — раскладка демо-атласа. Под свой kit-sheet поправьте здесь!
@export var biome_tiles: Dictionary = {
        Biome.GRASS: Vector2i(0, 0),
        Biome.GRASS_FLOWERS: Vector2i(1, 0),
        Biome.FOREST: Vector2i(2, 0),
        Biome.SNOW: Vector2i(3, 0),
        Biome.ICE: Vector2i(0, 1),
        Biome.WATER: Vector2i(1, 1),
        Biome.ROCK: Vector2i(2, 1),
        Biome.MUD: Vector2i(3, 1),
}

## ГПСЧ генератора (rng.seed = last_seed, можно повторить карту).
var rng := RandomNumberGenerator.new()
## Сид последней генерации (для воспроизведения вставьте в seed_override).
var last_seed: int = -1

var _tile_map: TileMapLayer
var _source_id: int = -1
var _atlas_grid: Vector2i = Vector2i.ZERO
var _warned_biomes: Dictionary = {}
## Фактический размер тайла (для демо-атласа — правильные пропорции гекса).
var _tile_size_eff: Vector2i = Vector2i(64, 64)


func _ready() -> void:
        if generate_on_ready:
                generate()


## Полная генерация карты. Можно вызывать повторно (в т.ч. по F5).
func generate() -> void:
        map_radius = maxi(1, map_radius)
        # Ошибка «карта одинаковая при каждом запуске»: без случайного сида.
        # Глобальный ГПСЧ в Godot 4 уже рандомизирован, randi() достаточно.
        last_seed = seed_override if seed_override >= 0 else randi()
        rng.seed = last_seed

        _setup_tilemap()
        var cells := _build_cell_list()
        var biomes := _pick_biomes(cells)
        _paint(cells, biomes)
        if auto_fit_camera:
                _fit_camera()

        var counts := {}
        for b in biomes:
                counts[b] = counts.get(b, 0) + 1
        print("HexMapGenerator: сид %d, клеток %d, биомы %s" % [last_seed, cells.size(), counts])
        map_generated.emit(cells.size(), last_seed)


func clear_map() -> void:
        if _tile_map != null:
                _tile_map.clear()


## ----------------------------------------------------------------------------
## Координаты. Бог генераторов без дыр — осевые координаты (q, r) + конверсия
## в клеточные координаты TileMapLayer (offset-схема "odd-r"/"odd-q"),
## в точности повторяющая TileSet::map_to_local из исходников Godot:
##   OFFSET_AXIS_HORIZONTAL: pos = (x + 0.5*[posmod(y,2)==1], y), шаг Y = 0.75*h
##   OFFSET_AXIS_VERTICAL:   pos = (x, y + 0.5*[posmod(x,2)==1]), шаг X = 0.75*w
## ----------------------------------------------------------------------------

## Шестиугольный регион радиуса R без единой дырки:
## q из [-R..R], r из [max(-R, -q-R) .. min(R, -q+R)].
func _build_cell_list() -> Array[Vector2i]:
        var cells: Array[Vector2i] = []
        for q in range(-map_radius, map_radius + 1):
                var r_min := maxi(-map_radius, -q - map_radius)
                var r_max := mini(map_radius, -q + map_radius)
                for r in range(r_min, r_max + 1):
                        cells.append(_axial_to_cell(q, r))
        return cells


## Осевые (axial) -> клеточные координаты TileMapLayer.
func _axial_to_cell(q: int, r: int) -> Vector2i:
        if orientation == HexOrientation.POINTY_TOP:
                # odd-r: нечётные ряды сдвинуты вправо на полтайла.
                @warning_ignore("integer_division")
                return Vector2i(q + (r - (r & 1)) / 2, r)
        # odd-q: нечётные столбцы сдвинуты вниз на полтайла.
        @warning_ignore("integer_division")
        return Vector2i(q, r + (q - (q & 1)) / 2)


## Обратная конверсия (нужна для гекс-расстояний в режиме пятен).
func _cell_to_axial(c: Vector2i) -> Vector2i:
        if orientation == HexOrientation.POINTY_TOP:
                @warning_ignore("integer_division")
                return Vector2i(c.x - (c.y - (c.y & 1)) / 2, c.y)
        @warning_ignore("integer_division")
        return Vector2i(c.x, c.y - (c.x - (c.x & 1)) / 2)


## Расстояние между гексами в осевых координатах (кубическая формула).
func _axial_distance(a: Vector2i, b: Vector2i) -> int:
        var dq := a.x - b.x
        var dr := a.y - b.y
        @warning_ignore("integer_division")
        return (absi(dq) + absi(dq + dr) + absi(dr)) / 2


## ----------------------------------------------------------------------------
## Биомы: полный рандом по весам (+ опциональные пятна).
## ----------------------------------------------------------------------------

func _pick_biomes(cells: Array[Vector2i]) -> PackedInt32Array:
        var options: Array = [
                [Biome.GRASS, weight_grass],
                [Biome.GRASS_FLOWERS, weight_flowers],
                [Biome.FOREST, weight_forest],
                [Biome.SNOW, weight_snow],
                [Biome.ICE, weight_ice],
                [Biome.WATER, weight_water],
                [Biome.ROCK, weight_rock],
                [Biome.MUD, weight_mud],
        ]
        options = options.filter(func(o: Array) -> bool: return o[1] > 0.0)
        if options.is_empty():
                options = [[Biome.GRASS, 1.0]]
        var total := 0.0
        for o in options:
                total += o[1]

        var result := PackedInt32Array()
        result.resize(cells.size())

        if use_biome_blobs:
                # Случайные пятна: каждый гекс берёт биом ближайшего случайного центра.
                var centers: Array = []
                for i in blob_count:
                        var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
                        centers.append([cell, _weighted_biome(options, total)])
                for i in cells.size():
                        var best := 0
                        var best_d := 2147483647
                        var ax := _cell_to_axial(cells[i])
                        for k in centers.size():
                                var d := _axial_distance(ax, _cell_to_axial(centers[k][0]))
                                if d < best_d:
                                        best_d = d
                                        best = k
                        result[i] = centers[best][1]
        else:
                # Полный рандом: независимый взвешенный выбор на каждый гекс.
                for i in cells.size():
                        result[i] = _weighted_biome(options, total)
        return result


func _weighted_biome(options: Array, total: float) -> int:
        var roll := rng.randf() * total
        var acc := 0.0
        for o in options:
                acc += o[1]
                if roll <= acc:
                        return o[0]
        return options[options.size() - 1][0]


## ----------------------------------------------------------------------------
## TileMapLayer + TileSet.
## ----------------------------------------------------------------------------

func _setup_tilemap() -> void:
        if _tile_map == null and not tilemap_path.is_empty():
                _tile_map = get_node_or_null(tilemap_path) as TileMapLayer
        if _tile_map == null:
                _tile_map = get_node_or_null(^"TileMapLayer") as TileMapLayer
        if _tile_map == null:
                _tile_map = TileMapLayer.new()
                _tile_map.name = "TileMapLayer"
                add_child(_tile_map)
        # Для демо-атласа берём правильные пропорции гекса (ревью T-341: квадратный
        # bbox 64x64 даёт сплюснутый гекс): островерхий h = w * 2/sqrt(3),
        # плосковерхий w = h * 2/sqrt(3). Для своего атласа действует ваш tile_size.
        _tile_size_eff = tile_size
        if atlas_texture == null:
                var s := 2.0 / sqrt(3.0)
                if orientation == HexOrientation.POINTY_TOP:
                        _tile_size_eff = Vector2i(tile_size.x, int(round(tile_size.x * s)))
                else:
                        _tile_size_eff = Vector2i(int(round(tile_size.y * s)), tile_size.y)
        if build_tileset_automatically or _tile_map.tile_set == null:
                _tile_map.tile_set = _build_tileset()


## Корректный гексагональный TileSet. Именно здесь лечатся «прозрачные щели»
## и «плавающие ряды»: TILE_SHAPE_HEXAGON + STACKED + правильный offset axis.
func _build_tileset() -> TileSet:
        var ts := TileSet.new()
        ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
        ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
        ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL \
                        if orientation == HexOrientation.POINTY_TOP \
                        else TileSet.TILE_OFFSET_AXIS_VERTICAL
        ts.tile_size = _tile_size_eff

        var src := TileSetAtlasSource.new()
        src.texture = atlas_texture if atlas_texture != null else _build_demo_atlas()
        src.texture_region_size = Vector2i(_tile_size_eff)

        var grid := src.get_atlas_grid_size()
        if grid.x < 1 or grid.y < 1:
                push_warning("HexMapGenerator: атлас меньше одного тайла %s — включаю демо-атлас."
                        % str(grid))
                src.texture = _build_demo_atlas()
                grid = src.get_atlas_grid_size()

        # Ошибка «пустые клетки после set_cell»: тайл атласа надо создать явно.
        for y in grid.y:
                for x in grid.x:
                        src.create_tile(Vector2i(x, y))

        _atlas_grid = grid
        _source_id = ts.add_source(src)
        return ts


## ----------------------------------------------------------------------------
## Отрисовка.
## ----------------------------------------------------------------------------

func _paint(cells: Array[Vector2i], biomes: PackedInt32Array) -> void:
        # Ошибка «призраки тайлов при повторной генерации»: сначала clear().
        _tile_map.clear()
        for i in cells.size():
                var t := _resolve_tile(biomes[i])
                if t.x < 0:
                        # Строгий режим: клетка остаётся пустой — провал виден сразу.
                        _tile_map.erase_cell(cells[i])
                else:
                        _tile_map.set_cell(cells[i], _source_id, t)


## Валидация atlas_coords: выход за сетку атласа = пустая клетка в Godot.
func _resolve_tile(biome: int) -> Vector2i:
        var coords: Vector2i = biome_tiles.get(biome, Vector2i(-1, -1))
        var valid := coords.x >= 0 and coords.y >= 0 \
                        and coords.x < _atlas_grid.x and coords.y < _atlas_grid.y
        if valid:
                return coords
        if not _warned_biomes.has(biome):
                _warned_biomes[biome] = true
                _report_missing_tile(biome, coords)
        if strict_missing_tiles:
                return Vector2i(-1, -1)
        return Vector2i.ZERO


## Репорт отсутствующего тайла: строгий режим — push_error, демо — push_warning.
func _report_missing_tile(biome: int, coords: Vector2i) -> void:
        var info := "биом %d, задано %s, сетка атласа %s" % [biome, str(coords), str(_atlas_grid)]
        if strict_missing_tiles:
                # Семантика прод-конвейера: отсутствие тайла = провал, а не
                # «нарисуем соседний биом» (класс невидимых багов «дорога -> трава»).
                push_error("HexMapGenerator: в атласе нет тайла (%s)." % info)
        else:
                push_warning("HexMapGenerator: тайл вне сетки (%s) — использую (0, 0)." % info)
        return


func _fit_camera() -> void:
        var cam := get_node_or_null(^"MapCamera") as Camera2D
        if cam == null:
                cam = Camera2D.new()
                cam.name = "MapCamera"
                add_child(cam)
        var used := _tile_map.get_used_rect()
        if used.size == Vector2i.ZERO:
                return
        var a := _tile_map.map_to_local(used.position)
        var b := _tile_map.map_to_local(used.position + used.size - Vector2i(1, 1))
        var rect := Rect2(a, Vector2.ZERO).expand(b).grow(float(_tile_size_eff.x))
        cam.position = rect.get_center()
        var vp := get_viewport_rect().size
        var z := minf(vp.x / maxf(rect.size.x, 1.0), vp.y / maxf(rect.size.y, 1.0))
        cam.zoom = Vector2.ONE * z
        cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
                generate()


## ----------------------------------------------------------------------------
## Демо-атлас: рисуется в рантайме, если kit-sheet не назначен.
## Гексагон занимает ВЕСЬ bounding box tile_size (углы прозрачны) — иначе у
## Godot появляются наложения/щели, т.к. шаг рядов = 0.75 высоты тайла.
## ----------------------------------------------------------------------------

func _build_demo_atlas() -> ImageTexture:
        var w := _tile_size_eff.x * ATLAS_COLS
        var h := _tile_size_eff.y * ATLAS_ROWS
        var data := PackedByteArray()
        data.resize(w * h * 4)
        var idx := 0
        for y in h:
                @warning_ignore("integer_division")
                var ty := y / _tile_size_eff.y
                var ly := y % _tile_size_eff.y
                for x in w:
                        @warning_ignore("integer_division")
                        var tx := x / _tile_size_eff.x
                        var lx := x % _tile_size_eff.x
                        var tile := ty * ATLAS_COLS + tx
                        var c := _demo_tile_pixel(tile, lx, ly, _tile_size_eff.x, _tile_size_eff.y)
                        data[idx] = int(clampf(c.r * 255.0, 0.0, 255.0))
                        data[idx + 1] = int(clampf(c.g * 255.0, 0.0, 255.0))
                        data[idx + 2] = int(clampf(c.b * 255.0, 0.0, 255.0))
                        data[idx + 3] = int(clampf(c.a * 255.0, 0.0, 255.0))
                        idx += 4
        # Image.create() устарел (4.3+): используем статический create_from_data.
        var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
        return ImageTexture.create_from_image(img)


func _demo_tile_pixel(tile: int, x: int, y: int, w: int, h: int) -> Color:
        var cx := (w - 1) * 0.5
        var cy := (h - 1) * 0.5
        var dx := absf(x - cx)
        var dy := absf(y - cy)

        # Гексагон с вершинами на 1/4 и 3/4 размера — стыкуется без щелей.
        var inside := false
        var edge := 0.0
        if orientation == HexOrientation.POINTY_TOP:
                var hw: float = w * 0.5 if dy <= h * 0.25 \
                                else w * 0.5 * (h * 0.5 - dy) / (h * 0.25)
                inside = dx <= hw
                edge = hw - dx
        else:
                var hh: float = h * 0.5 if dx <= w * 0.25 \
                                else h * 0.5 * (w * 0.5 - dx) / (w * 0.25)
                inside = dy <= hh
                edge = hh - dy
        if not inside:
                return Color(0, 0, 0, 0)

        var col: Color = _DEMO_COLORS[tile]
        # Детерминированный шум, чтобы тайлы не выглядели плоскими.
        var n := absf(fmod(sin((x + tile * 97) * 12.9898 + y * 78.233) * 43758.5453, 1.0))
        col = _shade(col, 0.93 + n * 0.12)

        match tile:
                Biome.GRASS:
                        if n > 0.90:
                                col = _shade(col, 0.86)
                Biome.GRASS_FLOWERS:
                        for s in _FLOWER_SPOTS:
                                var fdx := x - s.x * w
                                var fdy := y - s.y * h
                                if fdx * fdx + fdy * fdy <= 3.2:
                                        col = Color(0.99, 0.99, 0.90)
                Biome.FOREST:
                        var hit := false
                        for cc in _CANOPY_CIRCLES:
                                var ddx := x - (cx + cc.x)
                                var ddy := y - (cy + cc.y)
                                if ddx * ddx + ddy * ddy <= 130.0:
                                        hit = true
                                        break
                        if hit:
                                col = _shade(Color(0.15, 0.35, 0.13), 0.85 + n * 0.30)
                        elif absf(x - cx) <= 2.5 and dy >= 2.0 and dy <= 22.0:
                                col = _shade(Color(0.44, 0.30, 0.16), 0.90 + n * 0.20)
                Biome.SNOW:
                        if n > 0.96:
                                col = Color(1, 1, 1)
                Biome.ICE:
                        if (x + y) % 13 < 2:
                                col = _shade(col, 1.18)
                Biome.WATER:
                        if y % 15 == 6 or y % 15 == 7:
                                col = _shade(col, 1.22)
                Biome.ROCK:
                        var facet := (x - int(cx)) > (y - int(cy))
                        col = _shade(col, 1.10 if facet else 0.92)
                Biome.MUD:
                        for s in _MUD_SPOTS:
                                var mdx := x - s.x * w
                                var mdy := y - s.y * h
                                if mdx * mdx + mdy * mdy <= 4.8:
                                        col = _shade(col, 0.68)

        if edge < 1.5:
                col = _shade(col, 0.72)
        return col


func _shade(c: Color, f: float) -> Color:
        return Color(c.r * f, c.g * f, c.b * f, c.a)
