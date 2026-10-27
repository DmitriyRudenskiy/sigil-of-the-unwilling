class_name CampaignMapField
extends Control

## Поле карты кампании (T-194, D-281): гексы регион-графа в игровом пути.
##
## До этого шага `MapScreenModel` (view model карты: карточка региона, опции
## движения, причины недоступности) не вызывался из прод-кода никем — карта
## жила в тестах и в сейве, а игрок видел пустой фон. Поле — тот прод-вызывающий:
## оно читает биомы и туман из `RegionMap`, карточку и причины — из
## `MapScreenModel`, рисунок гексов — из листа `TileAtlas`. Своего состояния у
## поля нет, кроме выбранного региона: ни в модели экрана, ни в `RegionMap`
## поля выбора нет, и заводить его там нечем (D-281).
##
## Геометрия — гексы (D-281: изометрия макета 10 — отдельное будущее
## предложение, не этот шаг). Координат у регион-графа нет, поэтому раскладка
## выводится из рёбер: старт в центре, соседи — по свободным направлениям в
## фиксированном порядке (I1: никакой энтропии), кадр заполняется масштабированием.
## Камеры нет: поле целиком лежит в кадре, а не скроллится.

## Выбор игрока: карточка региона + причины из модели экрана. Слушатель — HUD.
signal region_selected(card: Dictionary)

const SHEET := "res://assets/tiles/world_map_atlas.webp"
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
## Биом региона (имена из `movement.json`) → биом листа тайлов. Молчаливого
## фолбэка на траву нет: гора, окрашенная как луг, — это ложь на кадре, а не
## недорисованный пиксель. Неизвестный биом рисуется серым и виден в кадре.
const REGION_BIOME_TO_ATLAS := {
	"plains": TileAtlas.Biome.GRASS,
	"forest": TileAtlas.Biome.GRASS,
	"sacred_grove": TileAtlas.Biome.GRASS,
	"mountains": TileAtlas.Biome.ROCK,
	"ruins": TileAtlas.Biome.ROCK,
	"swamp": TileAtlas.Biome.SWAMP,
	"scorched": TileAtlas.Biome.MUD,
	"river": TileAtlas.Biome.WATER,
	"ford": TileAtlas.Biome.WATER,
}
const COLOR_UNKNOWN := Color(0.32, 0.3, 0.28)
const COLOR_FOG := Color(0.06, 0.06, 0.07)
const COLOR_EDGE := Color(0.76, 0.6, 0.47, 0.55)
const COLOR_SELECTED := Color(0.85, 0.68, 0.42)
const COLOR_HERO := Color(0.9, 0.86, 0.78)
const MARGIN := 0.06

var _map: RegionMap = null
var _selected: String = ""
var _sheet: Texture2D = null
var _centers: Dictionary = {}  # region -> Vector2, пиксели внутри `size`
var _radius := 0.0


func _ready() -> void:
	# Поле глотает клики (иначе наведение проходит сквозь карту), но стоит оно
	# под слоем HUD, поэтому кнопки поверх поля доходят до себя первыми.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Раскладка считается по кадру, а на момент `bind_map` кадр ещё нулевой:
	# без этого сигнала карта осталась бы точкой в левом верхнем углу.
	resized.connect(_on_resized)


func _on_resized() -> void:
	_layout()
	queue_redraw()


func bind_map(map: RegionMap) -> void:
	_map = map
	_selected = ""
	_layout()
	queue_redraw()


## Обновление после хода: туман и позиция героя меняются без пересоздания поля.
func refresh() -> void:
	queue_redraw()


func selected_region() -> String:
	return _selected


## Регион отряда (маркер на поле). Читает миникарта, чтобы не заводить второго
## носителя позиции (D-281).
func hero_region() -> String:
	return "" if _map == null else _map.hero_region


## Регионы, которые поле показывает открытыми — порядок и состав обязан
## совпадать с носителем (тест сверяет с `RegionMap.open_regions`).
func visible_regions() -> Array:
	if _map == null:
		return []
	return _map.open_regions.duplicate()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var region := region_at((event as InputEventMouseButton).position)
	if region == "" or not _map.open_regions.has(region):
		return
	accept_event()
	select_region(region)


## Выбор региона — только через модель экрана: карточка и причины недоступности
## приходят из неё, поле ничего о правилах движения не знает.
func select_region(region: String) -> void:
	if _map == null or not _map.open_regions.has(region):
		return
	_selected = region
	var card := _card_for(region)
	queue_redraw()
	region_selected.emit(card)


## Сброс выбора (четвёртый тайл левой колонки, D-281 задача 3.7): «пустого
## региона» в носителе нет, поэтому сброс — отдельное действие, а не
## `select_region("")`, который обязан отвергнуть несуществующий id.
func clear_selection() -> void:
	if _selected == "":
		return
	_selected = ""
	queue_redraw()
	region_selected.emit({})


## Карточка региона из модели экрана + причины движения до него. Отдельная
## функция, потому что её читают двое: сигнал выбора и подпись на кадре.
func _card_for(region: String) -> Dictionary:
	var card: Dictionary = MapScreenModel.region_card(_map, region)
	for opt in MapScreenModel.travel_options(_map):
		if String(opt.get("region", "")) == region:
			card["days"] = int(opt.get("days", 0))
			card["food_cost"] = float(opt.get("food_cost", 0.0))
			card["reachable"] = bool(opt.get("available", false))
			card["reason"] = String(opt.get("reason", ""))
			break
	return card


## Регион под точкой — по попаданию в гекс, а не по ближнему центру: соседние
## гексы касаются рёбрами, и «ближний» на границе выбирает не то, что под курсором.
func region_at(point: Vector2) -> String:
	for region in _centers:
		if Geometry2D.is_point_in_polygon(point, hex_points(region)):
			return String(region)
	return ""


## Центр гекса региона в пикселях поля — нужен съёмке кадра и тесту ввода.
func center_of(region: String) -> Vector2:
	return _centers.get(region, Vector2.ZERO)


func hex_points(region: String) -> PackedVector2Array:
	return HexDraw.points_at(_centers.get(region, Vector2.ZERO) as Vector2, _radius)


## Раскладка из рёбер: BFS от стартового региона, соседи — по первым свободным
## направлениям. Позиция региона не зависит от порядка `regions` и от того,
## сколько регионов открыто, — кадр не «прыгает» между ходами.
func _layout() -> void:
	_centers = {}
	if _map == null or _map.regions.is_empty():
		return
	var axial: Dictionary = {}
	var origin := _map.start_region if _map.regions.has(_map.start_region) else _map.regions[0]
	axial[origin] = Vector2i.ZERO
	var queue: Array[String] = [String(origin)]
	var taken: Dictionary = {Vector2i.ZERO: true}
	while not queue.is_empty():
		var region := String(queue.pop_front())
		var here: Vector2i = axial[region]
		for neighbor in _map.neighbors(region):
			var key := String(neighbor)
			if axial.has(key):
				continue
			var spot := Vector2i.ZERO
			for direction in HEX_DIRECTIONS:
				spot = here + direction
				if not taken.has(spot):
					break
			while taken.has(spot):
				# Все шесть направлений заняты (в графе есть цикл): встаём в
				# следующее свободное, иначе регион пропадёт с кадра.
				for direction in HEX_DIRECTIONS:
					spot = spot + direction
					if not taken.has(spot):
						break
			axial[key] = spot
			taken[spot] = true
			queue.append(key)
	# Осевые → пиксели (pointy-top, та же геометрия вершин, что `HexDraw.points`).
	var boxes := PackedVector2Array()
	var pixels: Dictionary = {}
	for region in axial:
		var a: Vector2i = axial[region]
		var p := Vector2(sqrt(3.0) * (a.x + a.y / 2.0), 1.5 * a.y)
		pixels[region] = p
		boxes.append(p)
	var bounds := Rect2()
	for p in boxes:
		bounds = bounds.expand(p)
	if bounds.size == Vector2.ZERO:
		bounds = Rect2(Vector2.ZERO, Vector2.ONE)
	# Масштаб так, чтобы гексы с радиусом вписались в кадр целиком (половина
	# гекса за краем — это не «карта ушла за кадр», а обрезанный кадр); радиус —
	# половина шага решётки по горизонтали.
	var k := sqrt(3.0) / 2.0 * 0.92
	var avail := size * (Vector2.ONE - Vector2(2.0 * MARGIN, 2.0 * MARGIN))
	var scale_min := minf(
		avail.x / (bounds.size.x + sqrt(3.0) * k),
		avail.y / (bounds.size.y + 2.0 * k))
	_radius = k * scale_min
	var offset := (size - bounds.size * scale_min) / 2.0 - bounds.position * scale_min
	for region in pixels:
		_centers[region] = (pixels[region] as Vector2) * scale_min + offset


func _draw() -> void:
	if _map == null:
		return
	if _sheet == null:
		_sheet = load(SHEET) as Texture2D
	for region in _centers:
		var a := hex_points(region)
		var rect := _atlas_rect(String(region))
		if not _map.open_regions.has(region):
			draw_polygon(a, [COLOR_FOG])
		elif rect == Rect2():
			draw_polygon(a, [COLOR_UNKNOWN])
		else:
			draw_polygon(a, [Color.WHITE], _uvs(a, rect, _centers[region] as Vector2), _sheet)
	for edge in _map.edges:
		var from := _centers.get(String(edge[0]), Vector2.ZERO) as Vector2
		var to := _centers.get(String(edge[1]), Vector2.ZERO) as Vector2
		if _map.open_regions.has(String(edge[0])) and _map.open_regions.has(String(edge[1])):
			draw_line(from, to, COLOR_EDGE, 3.0)
	for region in _centers:
		var pts := hex_points(region)
		var closed := pts
		closed.append(pts[0])
		draw_polyline(closed, COLOR_SELECTED if String(region) == _selected else Color(0, 0, 0, 0.5),
			4.0 if String(region) == _selected else 1.5)
		if not _map.open_regions.has(region):
			# Знак неизвестности: чёрный гекс без него читается как отсутствующая
			# текстура, а не как туман.
			# Шрифт — роль темы, а не `get_theme_default_font`: пиксельная гарнитура
			# назначается ролям (T-147), дефолт движка дал бы системный шрифт.
			var glyph: int = get_theme_font_size("font_size", "LabelCaption")
			draw_string(get_theme_font("font", "LabelCaption"),
				_centers[region] as Vector2 + Vector2(-glyph / 4.0, glyph / 3.0),
				"?", HORIZONTAL_ALIGNMENT_LEFT, -1, glyph, Color(0.6, 0.58, 0.54))
		if String(region) == _map.hero_region:
			draw_circle(_centers[region] as Vector2, _radius * 0.28, COLOR_HERO)
		if String(region) == _selected:
			_draw_caption(region, pts)


## Подпись выбранного региона: имя и, если идти нельзя, причина из модели.
## Литерных строк макета здесь нет — только данные носителя и текст модели.
func _draw_caption(region: String, pts: PackedVector2Array) -> void:
	var font := get_theme_default_font()
	var size_px := get_theme_default_font_size()
	var card := _card_for(region)
	var lines: Array[String] = [region]
	var reason := String(card.get("reason", ""))
	if not bool(card.get("reachable", true)) and reason != "":
		lines.append(reason)
	var base := (_centers[region] as Vector2) + Vector2(-_radius, _radius + size_px)
	for i in lines.size():
		draw_string(font, base + Vector2(0, i * (size_px + 2)), lines[i],
			HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, COLOR_SELECTED)


## Клетка листа для региона: биом → первая клетка базы. Пустой `Rect2` — биома
## нет в листе (или нет листа): гекс рисуется подложкой, а не чужой текстурой,
## иначе «неизвестный биом» выглядел бы лугом.
func _atlas_rect(region: String) -> Rect2:
	var biome: int = REGION_BIOME_TO_ATLAS.get(String(_map.biomes.get(region, "")), -1)
	if _sheet == null or biome == -1:
		return Rect2()
	var cells: Array = TileAtlas.base_coords(int(biome))
	if cells.is_empty():
		return Rect2()
	var cell: Vector2i = cells[0]
	var tile := float(GameNumbers.TILE_SIZE)
	return Rect2(cell.x * tile, cell.y * tile, tile, tile)


## UV гекса: те же вершины полигона, только в координатах клетки листа.
func _uvs(pts: PackedVector2Array, rect: Rect2, center: Vector2) -> PackedVector2Array:
	var sheet_size := _sheet.get_size()
	var uvs := PackedVector2Array()
	for p in pts:
		var local := (p - center + Vector2(_radius, _radius)) * (rect.size.x / (_radius * 2.0))
		uvs.append((rect.position + local) / sheet_size)
	return uvs
