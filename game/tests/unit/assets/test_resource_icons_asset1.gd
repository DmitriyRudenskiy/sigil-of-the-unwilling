extends BaseTest

# ASSET-1 — собственные иконки ресурсов вместо чужого атласа HoMM III
# (тикет «чужой пиксель в репо: resources.png», docs/mvp/TICKETS.md; формула
# иконки — [[13-art-bible]] §7.1, палитра — §4.6). Генератор —
# game/tools/gen_resource_icons.py; воспроизводимость проверяет он же:
# `python3 game/tools/gen_resource_icons.py --check` (вне headless-гейта).
#
# Здесь: A-1 канвас/вес/имя · A-2 поле содержимого · A-3 заполнение ·
# A-4 проработка светом (направление 45° — глазами, группа B приёмки) ·
# A-5 обводка · A-6 палитра · A-8 комплект · A-9 анти-рекол (dHash против ячеек
# удалённого атласа) · A-11 удаление носителя · A-12 провенанс · A-13 потребители ·
# A-14 контраст на носителе.

const IDS: Array[String] = [
	"bog_iron", "cinnabar", "coal", "coal_swamp", "crystal", "food", "gems",
	"gold", "gold_ore", "limonite", "mercury", "oak", "ore", "quartz",
	"saltpeter", "silver", "stone", "sulfur", "turquoise", "wood",
]

const ICON_DIR := "res://assets/ui/icons/resources/"
const FOREIGN_SHEET := "res://assets/textures/resources.png"
const PROVENANCE_REGISTRY := "res://assets/PROVENANCE.md"
const FIELD := 8            # §7.1 шаг 2: поле = канвас − 8 px с каждой стороны
const SIZE_LIMIT := 6144    # §8.2
const CARRIER := Color8(0x28, 0x1C, 0x0F)  # §4.1 тёмное дерево поля карты
const SOOT := Color8(0x16, 0x10, 0x0A)      # §7.1 шаг 5: цвет обводки
const L_MIN := 0.20         # A-14: яркость массы
const L_DELTA_MIN := 0.08   # A-14: и контраст против носителя
const DHASH_MIN := 12       # §12.1: медиана несвязанной пары 18, подозрительная ≤ 10
const PAIR_MIN := 12         # красная любая пара форм по полю содержимого (минимум 15)
const _HEX_DIGITS := "0123456789abcdef"

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

# A-9 — dHash 8×8 шестнадцати ячеек атласа HoMM III. Сняты 2026-10-14 с
# assets/textures/resources.png (md5 b34a11b6f199645a5a91509c16b08e0f) до его
# удаления: атласа в репо больше нет, а эталон «на что не должно быть похоже»
# остаётся данными теста.
const HOMM_DHASH: Array[String] = [
	"70dafaccdc786004", "50cce4b2b4e4e00c", "d0f4b4ecf0e464a0", "70f696b2d8f83044",
	"79e8ccb2f2dc5808", "20e8a29ad0f10260", "c8cc76e4ccf07024", "c8e8acf4d8e8e060",
	"e0c896b4ec69826c", "28e4aeacd0718448", "c0a8ae96e4f8e060", "8278f2aacc706264",
	"89d0b896d4ccb0b2", "e0e4e4a8b6f47072", "e0e0cad6bcf8797a", "84ca8aac98f06460",
]


# --- утилиты -----------------------------------------------------------------

static func _icon_path(id: String) -> String:
	return ICON_DIR + "icon_resource_" + id + ".png"


static func _load_image(id: String) -> Image:
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(_icon_path(id)))
	return img if err == OK else null


# Яркость как её видит глаз на носителе: альфа — смешивание с деревом поля.
static func _lum(c: Color) -> float:
	var a := c.a
	return 0.2126 * (c.r * a + CARRIER.r * (1.0 - a)) \
		+ 0.7152 * (c.g * a + CARRIER.g * (1.0 - a)) \
		+ 0.0722 * (c.b * a + CARRIER.b * (1.0 - a))


static func _hex64(hex: String) -> int:
	var v := 0
	for i in range(hex.length()):
		v = (v << 4) | _HEX_DIGITS.find(hex[i])
	return v


static func _hash9x8(src: Image) -> int:
	var small := src.duplicate()
	small.resize(9, 8)
	var h := 0
	for y in range(8):
		for x in range(8):
			if _lum(small.get_pixel(x, y)) > _lum(small.get_pixel(x + 1, y)):
				h |= 1 << (y * 8 + x)
	return h


# Анти-рекол: весь канвас — ячейки референса заполняют его целиком.
static func _dhash(img: Image) -> int:
	return _hash9x8(img)


# Различие форм: только поле содержимого. На всём канвасе мера вырождена —
# 8 px прозрачных полей дают длинные прогоны равных яркостей, биты гаснут,
# и расстояние между любыми двумя иконками жмётся к нулю (замер 2026-10-14:
# по всему канвасу медиана пар 10, максимум 20, красных при пороге 12 — 121/190;
# по полю — медиана 25, диапазон 12–42).
static func _dhash_field(img: Image) -> int:
	return _hash9x8(img.get_region(Rect2i(FIELD, FIELD, 32 - 2 * FIELD, 32 - 2 * FIELD)))


static func _hamming(a: int, b: int) -> int:
	var d := a ^ b
	var n := 0
	for i in range(64):
		n += (d >> i) & 1
	return n


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


# --- A-3: заполнение поля (не пустое, не заливка) ----------------------------

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


# --- A-6: палитра §4.6 (тело иконки; края — анти-алиасинг) -------------------

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
		var soot := 0
		var lo := 1.0
		var hi := 0.0
		var tones := {}
		for y in range(32):
			for x in range(32):
				var c := img.get_pixel(x, y)
				if c.a <= 0.5:
					continue
				opaque += 1
				var l := _lum(c)
				lo = minf(lo, l)
				hi = maxf(hi, l)
				tones[c.to_html(false)] = true
				if c.to_html(false) == SOOT.to_html(false):
					soot += 1
		assert_int(tones.size()).override_failure_message(
			"%s: плоская заливка без света — оттенков %d" % [id, tones.size()]
		).is_greater_equal(3)
		assert_float(hi - lo).override_failure_message(
			"%s: разброс яркости %.2f — проработки нет" % [id, hi - lo]
		).is_greater(0.25)
		assert_int(soot).override_failure_message(
			"%s: обводки §7.1 шагом 5 (#16100a) нет" % id
		).is_greater_equal(1)
		assert_int(soot).is_less_equal(int(opaque * 0.45))


# --- A-14: силуэт читается на носителе ---------------------------------------

func test_contrast_against_carrier() -> void:
	var carrier_l := _lum(CARRIER)
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		var sum := 0.0
		var n := 0
		for y in range(32):
			for x in range(32):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					sum += _lum(c)
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
	for id in IDS:
		var img := _load_image(id)
		if img == null:
			continue
		forms[id] = _dhash_field(img)
		var h := _dhash(img)
		var best := 64
		for cell in HOMM_DHASH:
			best = mini(best, _hamming(h, _hex64(cell)))
		assert_int(best).override_failure_message(
			("%s: dHash ближе (%d) к ячейке удалённого атласа HoMM III, чем порог %d — "
				+ "это перекрас, а не рисунок") % [id, best, DHASH_MIN]
		).is_greater_equal(DHASH_MIN)
	# формы различаются между собой (гард против вырожденного хэша и близнецов)
	var ids := forms.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var d := _hamming(forms[ids[i]], forms[ids[j]])
			assert_int(d).override_failure_message(
				"формы %s и %s неразличимы в 8×8 (dHash %d)" % [ids[i], ids[j], d]
			).is_greater_equal(PAIR_MIN)


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


# --- A-13: потребители отдают иконку -----------------------------------------

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
	# food и oak пришли в UI вместе с ASSET-1 (у удалённого атласа их не было)
	assert_bool(ResourceAtlas.texture_for_id(&"food") != null).is_true()
	assert_bool(ResourceAtlas.texture_for_id(&"oak") != null).is_true()
