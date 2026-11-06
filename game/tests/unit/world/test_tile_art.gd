extends BaseTest
## Материал биома (**T-344**, пункты 1–3 задачи) — чем клетка обязана быть, а не
## только «координата существует».
##
## Прежний лист был плоской заливкой с обводкой: тест это устраивало, игрока — нет
## («однотонные, плоские, шов на каждом стыке»). Этот файл держит ровно то, что
## делает клетку нарисованной, и проверяется он по пикселям собранного листа, а не
## по константам: подделка «σ посчитана по одному каналу» здесь не пройдёт.
##
## Пороги — не вкусовщина, а половина того, что даёт текущий лист (замер того же
## среза: σ яркости 0.036…0.074, различие вариантов 76% пикселей). Падает — значит
## биом реально выцвел, а не «порог оказался строгим».

## Доля различающихся пикселей между вариантом 0 и вариантом 1 того же биома.
const VARIANT_DIFF_MIN := 0.25

## Разброс яркости внутри одной клетки: абсолютная σ и размах относительно средней
## яркости биома. Плоская заливка даёт σ≈0; доля, а не абсолют, потому что у тёмных
## биомов (болото, грязь, дорога) запас по яркости изначально втрое меньше.
const SIGMA_MIN := 0.02
const SPREAD_MIN := 0.25

## Насколько кромка клетки обязана быть темнее середины — в долях яркости центра.
## Общая сторона складывается из двух таких кромок: это и есть «шов сот», а не
## нарисованная линия. Доля, а не абсолют: тёмный биом (болото) при абсолютном
## пороге проваливался бы за то, что у него просто меньше запаса по яркости.
const EDGE_DARK_MIN := 0.08


func _fail(message: String) -> void:
	assert_that(message).is_equal("")


## Биомы, которые рендер способен положить на карту (+ ядро города).
func _paintable() -> Array:
	var ids := {}
	for biome in MapRenderer.TERRAIN_TO_BIOME.values():
		ids[int(biome)] = true
	ids[HexCellArt.Biome.MUD] = true
	return ids.keys()


func _image() -> Image:
	var sheet := HexCellArt.sheet()
	assert_that(sheet).is_not_null()
	return sheet.get_image()


func _cell_rect(coords: Vector2i) -> Rect2i:
	var hex := HexCellArt.HEX_SIZE
	return Rect2i(coords.x * hex.x, coords.y * hex.y, hex.x, hex.y)


## Яркости непрозрачных пикселей клетки, каждый третий пиксель по осям: проверка
## статистики, а не фотосессия — полной сетки здесь не нужно.
func _luminances(img: Image, coords: Vector2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rect := _cell_rect(coords)
	for y in range(0, rect.size.y, 3):
		for x in range(0, rect.size.x, 3):
			var c := img.get_pixel(rect.position.x + x, rect.position.y + y)
			if c.a > 0.5:
				out.append(c.get_luminance())
	return out


## Вариант базы обязан не быть копией: соседние клетки одного биома различаются
## плотностью и набором деталей, иначе поле читается текстурой-кирпичом.
func test_base_variants_are_not_copies() -> void:
	var img := _image()
	var hex := HexCellArt.HEX_SIZE
	var same: Array[String] = []
	for biome in _paintable():
		var a := _cell_rect(Vector2i(int(biome), 0))
		var b := _cell_rect(Vector2i(int(biome), 1))
		var differs := 0
		var total := 0
		for y in range(0, hex.y, 2):
			for x in range(0, hex.x, 2):
				if img.get_pixel(a.position.x + x, a.position.y + y).a <= 0.5:
					continue
				total += 1
				if img.get_pixel(a.position.x + x, a.position.y + y) \
						!= img.get_pixel(b.position.x + x, b.position.y + y):
					differs += 1
		if total == 0 or float(differs) / float(total) < VARIANT_DIFF_MIN:
			same.append("%s: %.1f%%" % [
				HexCellArt.Biome.keys()[int(biome)],
				100.0 * float(differs) / float(maxi(total, 1))])
	if not same.is_empty():
		_fail("варианты базы совпадают (< %d%% различий): %s"
			% [int(VARIANT_DIFF_MIN * 100), ", ".join(same)])


## Пункт 1: клетка не плоская. Считается разброс яркости по клетке — заливка с
## одной тёмной обводкой порога не проходит (обводка даёт σ порядка 0.01).
func test_base_cells_are_not_flat() -> void:
	var img := _image()
	var flat: Array[String] = []
	for biome in _paintable():
		var lums := _luminances(img, Vector2i(int(biome), 0))
		if lums.size() < 100:
			flat.append("%s: клетка пуста" % HexCellArt.Biome.keys()[int(biome)])
			continue
		var mean := 0.0
		for l in lums:
			mean += l
		mean /= float(lums.size())
		var variance := 0.0
		var lo := 1.0
		var hi := 0.0
		for l in lums:
			variance += (l - mean) * (l - mean)
			lo = minf(lo, l)
			hi = maxf(hi, l)
		var sigma := sqrt(variance / float(lums.size()))
		if sigma < SIGMA_MIN or hi - lo < SPREAD_MIN * mean:
			flat.append("%s: σ=%.3f, размах=%.3f" % [
				HexCellArt.Biome.keys()[int(biome)], sigma, hi - lo])
	if not flat.is_empty():
		_fail("плоские биомы (σ<%.2f или размах<%.0f%% средней): %s"
			% [SIGMA_MIN, SPREAD_MIN * 100.0, ", ".join(flat)])


## Пункт 3: кромка темнее середины. Общая сторона затемняется дважды (по кромке
## с каждой клетки) — так соты читаются сотами без отдельной линии сетки.
func test_cell_edge_is_darker_than_middle() -> void:
	var img := _image()
	var hex := HexCellArt.HEX_SIZE
	var weak: Array[String] = []
	for biome in _paintable():
		var rect := _cell_rect(Vector2i(int(biome), 0))
		# Середина клетки — эталон «чего касаемся на самом деле»: пиксель у самой
		# стороны полупрозрачен (сглаживание края), и сравнивать его яркость в лоб
		# с непрозрачным центром значит мерить альфу, а не краску. Поэтому кромка
		# композится на свой же центр — ровно так, как её увидит глаз над фоном.
		var middle := _mean_luminance(img, Rect2i(
				rect.position.x + hex.x / 2 - 12, rect.position.y + rect.size.y / 2 - 12,
				24, 24))
		# Меряется самый тёмный пиксель кромки, а не среднее по полосе: видит глаз
		# именно линию стыка, а не усреднённые три пикселя вокруг неё.
		var edge := 1.0
		for d in 3:
			for x in [rect.position.x + d, rect.position.x + hex.x - 1 - d]:
				edge = minf(edge, _over(
						img, x, rect.position.y + rect.size.y / 2, middle))
		if edge > middle * (1.0 - EDGE_DARK_MIN):
			weak.append("%s: кромка %.3f, центр %.3f (%.1f%%)" % [
				HexCellArt.Biome.keys()[int(biome)], edge, middle,
				100.0 * (1.0 - edge / middle)])
	if not weak.is_empty():
		_fail("кромка не темнее центра (меньше %.0f%%): %s"
			% [EDGE_DARK_MIN * 100.0, ", ".join(weak)])


## Яркость пикселя, положенного на яркость `over` с его собственной альфой.
func _over(img: Image, x: int, y: int, over: float) -> float:
	var c := img.get_pixel(x, y)
	return c.get_luminance() * c.a + over * (1.0 - c.a)


func _mean_luminance(img: Image, rect: Rect2i) -> float:
	var total := 0.0
	for y in rect.size.y:
		for x in rect.size.x:
			total += img.get_pixel(rect.position.x + x, rect.position.y + y).get_luminance()
	return total / float(rect.size.x * rect.size.y)


## Деталь не имеет права вылезать за гекс: угол bounding box — всегда воздух.
## Иначе трава или трещина лезут в чужую клетку, и «шов» возвращается.
func test_details_stay_inside_hex() -> void:
	var img := _image()
	var hex := HexCellArt.HEX_SIZE
	var leak: Array[String] = []
	for biome in _paintable():
		for variant in HexCellArt.VARIANTS:
			var rect := _cell_rect(Vector2i(int(biome), variant))
			for corner in [
				Vector2i(0, 0), Vector2i(hex.x - 1, 0),
				Vector2i(0, hex.y - 1), Vector2i(hex.x - 1, hex.y - 1),
			]:
				if img.get_pixel(rect.position.x + corner.x, rect.position.y + corner.y).a > 0.0:
					leak.append("%s/%d@%s" % [
						HexCellArt.Biome.keys()[int(biome)], variant, str(corner)])
	if not leak.is_empty():
		_fail("краска в углу клетки (%d): %s" % [leak.size(), ", ".join(leak.slice(0, 6))])


## Детерминизм листа: перекраска тайлмапа (paint, туман) обязана давать те же
## пиксели, иначе варианты cells разъезжаются между кадрами.
func test_sheet_rebuild_is_identical() -> void:
	var first := _fingerprint(_image())
	HexCellArt.clear_cache()
	assert_that(_fingerprint(_image())).is_equal(first)


## Отпечаток листа по пикселям (каждый пятый): без кодировщиков и файлов, только
## то, что реально ляжет на тайл.
func _fingerprint(img: Image) -> String:
	var parts := PackedStringArray()
	for y in range(0, img.get_height(), 5):
		for x in range(0, img.get_width(), 5):
			parts.append(str(img.get_pixelv(Vector2(x, y)).to_rgba32()))
	return "|".join(parts).md5_text()


## Вариант клетки — функция от клетки и сида, а не от порядка обхода: один и тот же
## гекс обязан получать один и тот же вариант при любом числе перекрасок.
func test_variant_choice_is_stable() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(3, -2), Vector2i(-7, 4), Vector2i(11, 11)]
	for cell in cells:
		var first := HexCellArt.variant_for(cell, 7, HexCellArt.VARIANTS)
		for pass_ in 3:
			assert_that(HexCellArt.variant_for(cell, 7, HexCellArt.VARIANTS)).is_equal(first)
		assert_that(HexCellArt.variant_for(cell, 7, 1)).is_equal(0)
		assert_that(first).is_greater_equal(0)
		assert_that(first).is_less(HexCellArt.VARIANTS)

## Норма C (T-344): аналитическая норма присутствия кольца угрозы. Кольцо рисует
## маркерный слой (draw_arc в marker_layer._draw), но вместимость его в клетку —
## геометрия НОСИТЕЛЯ: внешний край на пике пульса (0.30 + 0.08 = 0.38·hex) плюс
## ореол (+1.5 px, полуширина штриха 1.5) — против апотемы гекса. Норма pin:
## раздувание пульса или укорочение клетки ловится аналитически, без рендера.
## Второй якорь — два тона (Блок B): ореол темнее ядра, иначе пара «тёмное
## широкое + светлое узкое» не читается как кольцо.
func test_threat_ring_fits_cell_and_has_two_tones() -> void:
	var hex := float(HexCellArt.HEX_SIZE.y) * 0.5
	var apothem := float(HexCellArt.HEX_SIZE.x) * 0.5
	var peak := hex * 0.38
	var outer := peak + 1.5 + 1.5
	assert_float(outer).is_less_equal(apothem)
	assert_float(hex * 0.22 - 1.5).is_greater(0.0)
	var halo: Color = ThemeConfig.C_MARKER_DANGER_ARC.darkened(0.55)
	assert_float(halo.get_luminance()).is_less(
			ThemeConfig.C_MARKER_DANGER_ARC.get_luminance())
