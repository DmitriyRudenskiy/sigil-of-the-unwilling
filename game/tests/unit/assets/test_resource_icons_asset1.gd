extends BaseTest

# ASSET-1 — собственные иконки ресурсов вместо чужого атласа HoMM III
# (тикет «чужой пиксель в репо: resources.png», docs/mvp/TICKETS.md; формула
# иконки — [[13-art-bible]] §7.1, палитра — §4.6). Генератор —
# game/tools/gen_resource_icons.py; воспроизводимость проверяет он же:
# `python3 game/tools/gen_resource_icons.py --check` (вне headless-гейта).
#
# Здесь: A-1 канвас/вес/имя · A-2 поле содержимого · A-4 проработка светом
# (полоса оттенков есть; направление 45° и ΔL* +8…+20 — глазами, группа B:
# по пикселям полоса не отличима от светлой массы, см. ниже) · A-5 обводка ·
# A-6 палитра (в т.ч. «ни одного R=G=B») · A-8 комплект · A-9 анти-рекол
# (dHash против ячеек удалённого атласа) · A-11 удаление носителя ·
# A-12 строка провенанса на файл · сверка контраста на носителе (§4.3, номера
# критерия нет) · потребители (AC-поток, номера критерия нет) ·
# заполнение поля (смысл A-3 машиной не проверяется: dHash в 16 px и
# 60%-десатуре вырожден — все пары красные, минимум 0; §12.1).
#
# Числовые пороги живут только здесь и в генераторе; [[13-art-bible]] §12.1
# ссылается на них по имени (PAIR_MIN, DHASH_MIN, BORDER_MIN, …), а не дублирует.

const IDS: Array[String] = [
	"bog_iron", "cinnabar", "coal", "coal_swamp", "crystal", "food", "gems",
	"gold", "gold_ore", "iron", "limonite", "mercury", "oak", "ore", "quartz",
	"saltpeter", "silver", "stone", "sulfur", "turquoise", "wood",
]

# Мера различимости — одна реализация на гейт, на снятие констант A-9 и на
# печать матрицы (tools/dhash_report.gd). Python-зеркало удалено из репо.
const Measure := preload("res://tools/dhash_measure.gd")

const ICON_DIR := "res://assets/ui/icons/resources/"
const FOREIGN_SHEET := "res://assets/textures/resources.png"
const PROVENANCE_REGISTRY := "res://assets/PROVENANCE.md"
const FIELD := Measure.FIELD            # §7.1 шаг 2: поле = канвас − 8 px
const SIZE_LIMIT := 6144    # §8.2
const CARRIER := Measure.CARRIER        # §4.1 тёмное дерево поля карты
const SOOT := Color8(0x16, 0x10, 0x0A)      # §7.1 шаг 5: цвет обводки
const L_MIN := 0.20         # §4.3: яркость массы (без обводки) на носителе
const L_DELTA_MIN := 0.08   # §4.3: и контраст против дерева поля
const SOOT_E := 12.0        # A-5: «это сажа» — допуск ΔE76 против #16100a
const BORDER_MIN := 0.60    # A-5: ≥ 60 % границы силуэта должно быть обводкой
const DHASH_MIN := 12        # §12.1: A-9 в оправке поля — подсовывание ячейки 0, шум наших 14
const PAIR_MIN := 12         # красная любая пара форм по полю содержимого
const DHASH_MIN_CANVAS := 8  # A-9 в оправке канваса — подсовывание 0, шум наших 11

# §4.6 полоса (замер живых артефактов) — те же токены, что у генератора.
const PALETTE := {
	"a1": "#111112", "a2": "#1d201f", "a3": "#2b2723", "a4": "#412c22",
	"a5": "#604e3a", "a6": "#767160", "a7": "#bdae93", "a8": "#3b4444",
	"c1": "#18100f", "c2": "#403929", "c3": "#58644b", "c4": "#7d734b",
	"c5": "#8c947c", "c6": "#beb28f", "c7": "#5a3e29", "c8": "#29261d",
	"d1": "#321c12", "d2": "#413828", "d3": "#6e331d", "d4": "#7d4c2f",
	"d5": "#a86d41", "d6": "#ac8e5b", "d7": "#d4c09d",
	"b1": "#bf9926", "b2": "#f1d167", "b3": "#4072bc", "b4": "#5e472c",
	"b5": "#889ea6", "b6": "#d6be6e", "b7": "#7b7259",
	"soot": "#16100a", "wood": "#281c0f", "gold": "#8a6a3a",
	"gold_bright": "#9e7738", "parchment": "#e8d5a8", "crimson": "#7a100c",
	"ok": "#7aa85a",
}

# A-9 — 16 ячеек удалённого атласа HoMM III (assets/textures/resources.png,
# md5 b34a11b6f199645a5a91509c16b08e0f, 410×410, сетка 4×4 по 102 px). Атласа в
# репо больше нет (A-11), а эталон «на что не должно быть похоже» остаётся
# данными теста — снятыми МЕРОЙ ГЕЙТА (DhashMeasure), той же, которой режется
# сравнение:
#   git show 21ff6d2c^:game/assets/textures/resources.png > /tmp/homm_atlas.png
#   godot --headless --path game -s tools/dhash_report.gd -- --atlas=/tmp/homm_atlas.png
# Прежние константы были сняты PIL-зеркалом, которого в репо нет и которое их не
# воспроизводит (ни одна из 16 не совпала ни с одним вариантом раскроя); при
# кросс-реализационном шуме PIL↔Godot 2–12 бит на пару порог 12 давал ложный
# PASS там, где проверить было нельзя.
#
# Оправки две, потому что векторы подсовывания разные (замер 2026-10-15,
# tools/dhash_report.gd, худшее из 16 ячеек, 0 = точно та же форма): подсована
# целиком в 32×32 → канвас 0 / поле 31; подсована в поле §7.1 → канвас 19 /
# поле 0. Пороги калиброваны по измеренному шуму наших иконок (канвас шумит
# сильнее — он с 8 px прозрачных полей), а не по §12.1.
const HOMM_DHASH_CANVAS: Array[String] = [
	"3052fa8c5c686800", "00e6a4b2b4646000", "78d4deeab4242000", "1ae4debaea380c00",
	"04eacd62f65c0800", "00e8aaaad8300000", "904966a4d8322000", "74caaa94ca697000",
	"00ca96b4687a0000", "00e586ae49340000", "1ce38d92a4486810", "0038baa6d9786000",
	"00d434d6ec5c3000", "00a9e668b4f47000", "3064aad5a8787800", "00e2b5ada9552200",
]

const HOMM_DHASH_FIELD: Array[String] = [
	"305afabc5c796000", "08d6d4a6b4752000", "d9f49aecb4a42010", "36b2b6bada790800",
	"04a8ccb4be551900", "10e0a69add300000", "34d5d446dc4b3000", "24aaacface596010",
	"20dad4b468680000", "0064ceacd9340000", "5aa98cb6e4786820", "0030faaad8706000",
	"20c8f896e44d3008", "50a5d4ccb4647000", "40a1c8d6da696808", "60c6968c9a752300",
]


# --- утилиты -----------------------------------------------------------------

static func _icon_path(id: String) -> String:
	return ICON_DIR + "icon_resource_" + id + ".png"


static func _load_image(id: String) -> Image:
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(_icon_path(id)))
	return img if err == OK else null


# Lab (D65) — нужно ровно для ΔE76 в A-5: «пограничный пиксель — сажа».
static func _lab(c: Color) -> Vector3:
	var gamma := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = gamma.call(c.r)
	var g: float = gamma.call(c.g)
	var b: float = gamma.call(c.b)
	var x: float = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y: float = 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z: float = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var cube := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = cube.call(x)
	var fy: float = cube.call(y)
	var fz: float = cube.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


# --- A-1, A-8: комплект, имена, вес ------------------------------------------

func test_set_names_and_weight() -> void:
	var dir := DirAccess.open(ICON_DIR)
	assert_bool(dir != null).is_true()
	if dir == null:
		return
	var pngs: Array[String] = []
	for f in dir.get_files():
		if f.get_extension().to_lower() == "png":
			pngs.append(f)
	var expected: Array[String] = []
	for id in IDS:
		expected.append("icon_resource_%s.png" % id)
	pngs.sort()
	expected.sort()
	assert_bool(pngs == expected).override_failure_message(
		"в %s должен лежать ровно комплект ASSET-1: %s, найдено %s"
		% [ICON_DIR, expected, pngs]
	).is_true()
	for id in IDS:
		var path := _icon_path(id)
		assert_bool(FileAccess.file_exists(path)).is_true()
		assert_int(FileAccess.get_file_as_bytes(path).size()).is_less_equal(SIZE_LIMIT)
		var img := _load_image(id)
		assert_bool(img != null).override_failure_message("не читается png: %s" % id).is_true()
		if img == null:
			continue
		assert_int(img.get_width()).is_equal(32)
		assert_int(img.get_height()).is_equal(32)


# --- A-2: поле содержимого (канвас − 8 px) -----------------------------------

func test_content_stays_in_field() -> void:
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		for y in range(32):
			for x in range(32):
				if img.get_pixel(x, y).a > 0.0:
					var inside := x >= FIELD and x < 32 - FIELD and y >= FIELD and y < 32 - FIELD
					assert_bool(inside).override_failure_message(
						"%s: пиксель вне поля содержимого §7.1 (%d,%d)" % [id, x, y]
					).is_true()


# --- заполнение поля (не пустое, не заливка) ---------------------------------
# Это НЕ A-3: критерий A-3 («силуэт опознаётся в 16 px и 60%-десатуре, dHash
# пар ≥ 12») машиной не проверяется — на таком входе хэш вырожден целиком
# (замер 2026-10-15: минимум 0, красных — все пары). A-3 — группа B, глаза.
# Здесь — только разумная полоса заполнения, чтобы иконка не была точкой или
# плашкой.

func test_silhouette_fill_ratio() -> void:
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		var opaque := 0
		for y in range(32):
			for x in range(32):
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_int(opaque).override_failure_message("силуэт %s вне полосы заполнения" % id) \
			.is_greater_equal(40)
		assert_int(opaque).is_less_equal(220)


# --- A-6: палитра §4.6 + «ни одного R=G=B» -----------------------------------
# Член «не более одного акцентного семейства, ≤ 8 % площади» здесь не проверяется:
# роль пикселя из PNG не восстанавливается, акцент неотличим от светлой массы.
# Держит генератор (ACCENT_MAX), глаз — группа B.

func test_body_uses_documented_palette() -> void:
	var allowed := {}
	for hex: String in PALETTE.values():
		allowed[hex.to_lower()] = true
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		for y in range(1, 31):
			for x in range(1, 31):
				var c := img.get_pixel(x, y)
				if c.a < 1.0:
					continue
				# A-6 «чистого серого нет» (§4.3) — по всем видимым пикселям,
				# не только по «телу»: край AA смешивается с носителем и тоже
				# может свернуться в серый.
				assert_bool(c.r8 != c.g8 or c.g8 != c.b8).override_failure_message(
					"%s: чистый серый R=G=B=%d в (%d,%d) — §4.3" % [id, c.r8, x, y]
				).is_true()
				var surrounded := true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if img.get_pixelv(Vector2i(x, y) + d).a < 1.0:
						surrounded = false
				if not surrounded:
					continue
				var hex := "#" + c.to_html(false)
				assert_bool(allowed.has(hex)).override_failure_message(
					"%s: цвет #%s вне палитры §4.6 в (%d,%d)" % [id, hex, x, y]
				).is_true()


# --- A-4/A-5: проработка светом и обводка ------------------------------------

func test_shading_and_outline_present() -> void:
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		var opaque := 0
		var edge := 0
		var edge_soot := 0
		var lo := 1.0
		var hi := 0.0
		var tones := {}
		var lab_soot := _lab(SOOT)
		for y in range(32):
			for x in range(32):
				var c := img.get_pixel(x, y)
				if c.a <= 0.5:
					continue
				opaque += 1
				var l := Measure.lum(c)
				lo = minf(lo, l)
				hi = maxf(hi, l)
				tones[c.to_html(false)] = true
				var on_edge := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var p := Vector2i(x + d.x, y + d.y)
					if p.x < 0 or p.y < 0 or p.x > 31 or p.y > 31 or img.get_pixelv(p).a <= 0.5:
						on_edge = true
				if on_edge:
					edge += 1
					if _lab(c).distance_to(lab_soot) <= SOOT_E:
						edge_soot += 1
		assert_int(tones.size()).override_failure_message(
			"%s: плоская заливка без света — оттенков %d" % [id, tones.size()]
		).is_greater_equal(3)
		assert_float(hi - lo).override_failure_message(
			"%s: разброс яркости %.2f — проработки нет" % [id, hi - lo]
		).is_greater(0.25)
		# A-5: обводка §7.1 шагом 5 обязана одевать силуэт, а не торчать пятнами.
		# Направление света (шаг 4) и ΔL* +8…+20 отсюда не проверяемы: светлый
		# тон полосы — тот же палитровый токен, что и светлая масса, а «самый
		# светлый цвет иконки» часто акцент (замер: turquoise — 0 % светлого тона
		# на верхних гранях при корректной нормали). Группа B приёмки — глазами.
		assert_float(float(edge_soot) / edge).override_failure_message(
			"%s: границы обведено сажей %.0f %% < %.0f %% (A-5)"
			% [id, 100.0 * float(edge_soot) / edge, 100.0 * BORDER_MIN]
		).is_greater_equal(BORDER_MIN)


# --- сверка контраста на носителе (§4.3; номера критерия нет) ----------------

func test_contrast_against_carrier() -> void:
	var carrier_l := Measure.lum(CARRIER)
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		var sum := 0.0
		var n := 0
		for y in range(32):
			for x in range(32):
				var c := img.get_pixel(x, y)
				# сажа исключается: обводка по определению темнее носителя (§7.1
				# шаг 5), считать её в «яркости массы» — столкнуть A-14 с A-5
				if c.a > 0.5 and c.to_html(false) != SOOT.to_html(false):
					sum += Measure.lum(c)
					n += 1
		if n == 0:
			continue
		var mean := sum / n
		assert_float(mean).override_failure_message(
			"%s: масса тонет в носителе (яркость %.3f < %.2f)" % [id, mean, L_MIN]
		).is_greater_equal(L_MIN)
		assert_float(mean - carrier_l).override_failure_message(
			"%s: контраст против дерева поля %.3f < %.2f" % [id, mean - carrier_l, L_DELTA_MIN]
		).is_greater_equal(L_DELTA_MIN)


# --- A-9: это не перекрас чужого атласа --------------------------------------

func test_icons_are_not_recolored_homm_cells() -> void:
	var forms := {}
	var worst := {"канвас": 64, "поле": 64}
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		forms[id] = Measure.hash_field(img)
		var hashes := {
			"канвас": [Measure.hash_canvas(img), HOMM_DHASH_CANVAS, DHASH_MIN_CANVAS],
			"поле": [Measure.hash_field(img), HOMM_DHASH_FIELD, DHASH_MIN],
		}
		for framing in hashes:
			var h: int = hashes[framing][0]
			var refs: Array[String] = hashes[framing][1]
			var minimum: int = hashes[framing][2]
			var best := 64
			for cell in refs:
				best = mini(best, Measure.hamming(h, Measure.hex64(cell)))
			worst[framing] = mini(int(worst[framing]), best)
			assert_int(best).override_failure_message(
				("%s: в оправке «%s» ближе (%d) к ячейке удалённого атласа HoMM III, чем "
					+ "порог %d — это перекрас, а не рисунок") % [id, framing, best, minimum]
			).is_greater_equal(minimum)
	# формы различаются между собой (гард против вырожденного хэша и близнецов)
	var ids := forms.keys()
	var pairs: Array = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var d := Measure.hamming(forms[ids[i]], forms[ids[j]])
			pairs.append([d, ids[i], ids[j]])
			assert_int(d).override_failure_message(
				"формы %s и %s неразличимы в 8×8 (dHash %d)" % [ids[i], ids[j], d]
			).is_greater_equal(PAIR_MIN)
	# DHASH_MATRIX=1 — матрица той же мерой, которой её режет гейт. Python-зеркало
	# здесь неавторитетно: PIL-ресайз 16×16→9×8 расходится с Godot на 2–12 бит
	# на пару (ore↔silver: Godot 11, PIL 13/16/23 для BOX/HAMMING/LANCZOS).
	if OS.get_environment("DHASH_MATRIX") != "":
		pairs.sort_custom(func(a, b):
			return a[0] < b[0] if a[0] != b[0] else str(a[1]) < str(b[1]))
		var red := 0
		var dist: Array[int] = []
		for p in pairs:
			dist.append(p[0])
			if p[0] < PAIR_MIN:
				red += 1
		dist.sort()
		print("DHASH MATRIX (мера гейта DhashMeasure, порог %d): пар %d, красных %d" % [
			PAIR_MIN, pairs.size(), red])
		print("мин %d · медиана %d · max %d · маржа к порогу %+d" % [
			dist[0], dist[int(dist.size() / 2.0)], dist[dist.size() - 1], dist[0] - PAIR_MIN])
		print("худшие 12: ", pairs.slice(0, 12))


# --- A-11: чужой носитель удалён ---------------------------------------------

func test_foreign_atlas_and_placeholders_gone() -> void:
	assert_bool(not ResourceLoader.exists(FOREIGN_SHEET)).override_failure_message(
		"атлас HoMM III всё ещё в репо: %s" % FOREIGN_SHEET
	).is_true()
	for id in IDS:
		var legacy := ICON_DIR + id + ".png"
		assert_bool(not ResourceLoader.exists(legacy)).override_failure_message(
			"старый плейсхолдер %s лежит рядом с новой иконкой" % legacy
		).is_true()


# --- A-12: строка провенанса на каждый файл ----------------------------------

func test_provenance_row_per_icon() -> void:
	assert_bool(FileAccess.file_exists(PROVENANCE_REGISTRY)).is_true()
	var text := FileAccess.get_file_as_string(PROVENANCE_REGISTRY)
	for id in IDS:
		assert_bool(text.contains("icon_resource_%s.png" % id)).override_failure_message(
			"в assets/PROVENANCE.md нет строки провенанса для icon_resource_%s.png" % id
		).is_true()


# --- потребители отдают иконку (AC-поток; номера критерия нет) --------------

func test_consumers_resolve_icons() -> void:
	for id in IDS:
		var tex: Texture2D = ResourceAtlas.texture_for_id(StringName(id))
		assert_bool(tex != null).override_failure_message(
			"ResourceAtlas.texture_for_id(\"%s\") — null" % id
		).is_true()
		assert_bool(IconRegistry.resource_texture(id) is Texture2D).is_true()
	for type in range(ResourceType.CLASSIC_COUNT):
		assert_bool(ResourceAtlas.texture_for_type(type) != null).override_failure_message(
			"ResourceAtlas.texture_for_type(%d) — null" % type
		).is_true()
	assert_bool(ResourceAtlas.texture_for_type(ResourceType.CLASSIC_COUNT) == null).is_true()
	assert_bool(ResourceAtlas.texture_for_id(&"") == null).is_true()
	assert_bool(ResourceAtlas.texture_for_id(&"no_such_resource") == null).is_true()
	# food и oak пришли в UI вместе с ASSET-1 (у удалённого атласа их не было);
	# iron — шапка города, где до этого рисовался чужой по смыслу рудой.
	assert_bool(ResourceAtlas.texture_for_id(&"food") != null).is_true()
	assert_bool(ResourceAtlas.texture_for_id(&"oak") != null).is_true()
	assert_bool(ResourceAtlas.texture_for_id(&"iron") != null).is_true()
