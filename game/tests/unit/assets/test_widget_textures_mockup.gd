extends BaseTest

# Шаг 4 (ui-mockup-parity): виджет-графика темы обязана быть рисунком, а не
# плашкой, и носитеlem — 9-slice, а не растянутой картинкой.
#
# Классы болезней, которые здесь держатся:
#   К-8 — маржа 9-slice больше/равна размеру текстуры → нулевое ядро, центр
#         рисуется растянутым пикселем (проверка 2);
#   К-8b — texture_margin не задан вовсе (= 0) → 9-slice выключен, рамка тянется
#         целиком и фаска плывёт на любом размере контрола (проверка 2). Именно
#         так жили кнопочные стили темы до шага 4 — ни один тест этого не видел;
#   «плоская заливка» — плейсхолдеры widgets/ были одноцветными (109…198 байт),
#   спека требует ненулевого разброса яркости (проверка 1);
#   копии-состояния — hover/pressed/disabled как копия normal (проверка 3).
#
# Пороги — свойство генератора scripts/ui_kit/build_ui_kit.py, а не макета:
# зерно поля он кладёт заведомо больше порога, плоская плашка под него не проходит.

const THEME_PATH := "res://assets/theme/game_theme.tres"
const KIT_DIR := "res://assets/ui/widgets"
const MANIFEST_PATH := "res://assets/ui/widgets/MANIFEST.json"

const TONES_MIN := 8        # оттенков меньше — это грань, а не материал
const SPREAD_MIN := 0.15    # разброс яркости (0…1): у одноцветной плашки 0.0
const TEXTURES_MIN := 12    # тема обязана кормиться китом, а не StyleBoxFlat

const STATES: Array[String] = ["normal", "hover", "pressed", "disabled"]


## Род носителя по манифесту кита: "9-slice", "full-bleed" или "" (не описан).
static func _kit_kind(path: String) -> String:
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (man is Dictionary):
		return ""
	var files: Variant = (man as Dictionary).get("files", {})
	if not (files is Dictionary):
		return ""
	var entry: Variant = (files as Dictionary).get(path.trim_prefix(KIT_DIR + "/"), {})
	if not (entry is Dictionary):
		return ""
	return String((entry as Dictionary).get("kind", ""))


# --- утилиты -----------------------------------------------------------------

static func _image_of(path: String) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func _stats(img: Image) -> Dictionary:
	var tones := {}
	var lo := 1.0
	var hi := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			tones[c.to_html(false)] = true
			var l := _lum(c)
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return {"tones": tones.size(), "spread": hi - lo}


static func _theme() -> Theme:
	return load(THEME_PATH)


## Всё, чем тема кормит контролы как текстурой: {ключ: Resource}.
static func _theme_textures() -> Dictionary:
	var out := {}
	var theme := _theme()
	for type in theme.get_stylebox_type_list():
		for style in theme.get_stylebox_list(type):
			var sb := theme.get_stylebox(style, type)
			if sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null:
				out["%s/%s" % [type, style]] = sb
	for type in theme.get_icon_type_list():
		for style in theme.get_icon_list(type):
			var tex := theme.get_icon(style, type)
			if tex != null:
				out["%s/%s" % [type, style]] = tex
	return out


static func _walk_png(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				_walk_png(full, out)
			elif f.get_extension().to_lower() == "png":
				out.append(full)
		f = d.get_next()
	d.list_dir_end()


# --- 1. носитель: это нарисовано, а не залито --------------------------------

func test_theme_textures_are_drawn_not_flat() -> void:
	var items := _theme_textures()
	assert_int(items.size()).override_failure_message(
		"тема обязана кормиться текстурным китом (найдено %d)" % items.size()
	).is_greater_equal(TEXTURES_MIN)
	for key in items:
		var res: Resource = null
		if items[key] is StyleBoxTexture:
			res = (items[key] as StyleBoxTexture).texture
		else:
			res = items[key] as Resource
		var path: String = res.resource_path
		assert_bool(path != "" and FileAccess.file_exists(path)).override_failure_message(
			"%s: текстура темы без файла-носителя (%s)" % [key, path]
		).is_true()
		var img := _image_of(path)
		assert_bool(img != null).override_failure_message(
			"%s: носитель не читается как png: %s" % [key, path]
		).is_true()
		if img == null:
			continue
		var s := _stats(img)
		assert_int(s["tones"]).override_failure_message(
			"%s: оттенков %d — это плашка, а не материал (%s)" % [key, s["tones"], path]
		).is_greater_equal(TONES_MIN)
		assert_float(s["spread"]).override_failure_message(
			"%s: разброс яркости %.3f — проработки светом нет (%s)"
			% [key, s["spread"], path]
		).is_greater_equal(SPREAD_MIN)


# --- 2. фаска — это срезанный угол, а не чёрный треугольник -------------------

func test_chamfer_is_cut_not_painted_black() -> void:
	# Плита макета — с фаской. Если носитель без альфы, угол становится чёрным
	# треугольником поверх фона (так и было на первом снимке стартового экрана):
	# на 9-slice это выглядит как «рамка с обкусанными углами».
	var pngs: Array = []
	_walk_png(KIT_DIR, pngs)
	for path in pngs:
		var img := _image_of(path)
		if img == null:
			continue
		# Носитель без альфы даёт a == 1.0 на любом пикселе, так что проверки ниже
		# ловят и «нет альфы», и «угол залит».
		assert_float(img.get_pixel(0, 0).a).override_failure_message(
			"%s: угол непрозрачен (a=%.2f) — фаска залита вместо среза или у PNG нет альфы"
			% [path, img.get_pixel(0, 0).a]
		).is_less(0.5)
		assert_float(img.get_pixel(img.get_width() - 1, img.get_height() - 1).a).is_less(0.5)


# --- 3. 9-slice включён и не вырожден (К-8, К-8b) ----------------------------

func test_nine_slice_margins_present_and_non_degenerate() -> void:
	var theme := _theme()
	var checked := 0
	var full_bleed := 0
	for type in theme.get_stylebox_type_list():
		for style in theme.get_stylebox_list(type):
			var sb := theme.get_stylebox(style, type)
			if not (sb is StyleBoxTexture) or (sb as StyleBoxTexture).texture == null:
				continue
			var t := sb as StyleBoxTexture
			var w := float((t.texture as Texture2D).get_width())
			var h := float((t.texture as Texture2D).get_height())
			var key := "%s/%s" % [type, style]
			# Полноцветный носитель (круглый медальон макета 11) обязан быть
			# заявлен в манифесте: у круга нет фаски, которую можно размазать, и
			# 9-slice к нему не применяется. Исключение действует, только пока
			# носитель квадратный, — неквадратный без маржи растянется.
			if _kit_kind(t.texture.resource_path) == "full-bleed":
				full_bleed += 1
				assert_float(w).override_failure_message(
					"%s: full-bleed носитель %s не квадратный (%d×%d) — его растянёт"
					% [key, t.texture.resource_path, int(w), int(h)]
				).is_equal(h)
				continue
			checked += 1
			# К-8b: маржа 0 = 9-slice выключен, текстура тянется целиком.
			assert_float(t.texture_margin_left).override_failure_message(
				"%s: texture_margin_left = 0 на %s — рамка растянется целиком (К-8b)"
				% [key, t.texture.resource_path]
			).is_greater(0.0)
			assert_float(t.texture_margin_right).is_greater(0.0)
			assert_float(t.texture_margin_top).is_greater(0.0)
			assert_float(t.texture_margin_bottom).is_greater(0.0)
			# К-8: ядро обязано остаться ненулевым.
			assert_float(t.texture_margin_left + t.texture_margin_right).override_failure_message(
				"%s: маржа %d+%d ≥ ширины текстуры %d — нулевое ядро (К-8)"
				% [key, t.texture_margin_left, t.texture_margin_right, int(w)]
			).is_less(w)
			assert_float(t.texture_margin_top + t.texture_margin_bottom).override_failure_message(
				"%s: маржа %d+%d ≥ высоты текстуры %d — нулевое ядро (К-8)"
				% [key, t.texture_margin_top, t.texture_margin_bottom, int(h)]
			).is_less(h)
	assert_int(checked).is_greater_equal(8)
	# Обратная сторона исключения: круглые медальоны нижней панели боя обязаны
	# быть в теме (четыре состояния), а не «молча» ездить на плите.
	assert_int(full_bleed).override_failure_message(
		"в теме не осталось full-bleed носителей — круглые медальоны съехали с RoundIconButton"
	).is_greater_equal(4)


# --- 4. состояния не копии ---------------------------------------------------

func test_button_states_are_not_copies() -> void:
	for family in ["button", "button_menu", "button_round"]:
		var bytes := {}
		for st in STATES:
			var path := "%s/buttons/%s_%s.png" % [KIT_DIR, family, st]
			assert_bool(FileAccess.file_exists(path)).override_failure_message(
				"нет состояния носителя: %s" % path
			).is_true()
			bytes[st] = FileAccess.get_file_as_bytes(path)
		for i in range(STATES.size()):
			for j in range(i + 1, STATES.size()):
				assert_bool(bytes[STATES[i]] != bytes[STATES[j]]).override_failure_message(
					"%s: состояния %s и %s — побайтовые копии (состояния не выводены)"
					% [family, STATES[i], STATES[j]]
				).is_true()


# --- 5. провенанс: каждый файл кита описан в манифесте ----------------------

func test_kit_manifest_covers_every_file() -> void:
	assert_bool(FileAccess.file_exists(MANIFEST_PATH)).is_true()
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_bool(man is Dictionary).is_true()
	if not (man is Dictionary):
		return
	var files: Dictionary = man["files"]
	var pngs: Array = []
	_walk_png(KIT_DIR, pngs)
	assert_int(pngs.size()).is_greater_equal(12)
	for path in pngs:
		var rel: String = path.trim_prefix(KIT_DIR + "/")
		assert_bool(files.has(rel)).override_failure_message(
			"%s нет в MANIFEST.json — файл кита без провенанса" % rel
		).is_true()
	# обратная сторона: манифест не обещает файлов, которых нет
	for rel in files:
		assert_bool(FileAccess.file_exists(KIT_DIR + "/" + String(rel))).override_failure_message(
			"MANIFEST.json обещает %s, файла нет" % rel
		).is_true()


# --- 6. MenuPlate: плита макета 09 привязана к стартовому экрану -------------

func test_menu_plate_variation_wired() -> void:
	var theme := _theme()
	for st in STATES:
		var sb := theme.get_stylebox(st, "MenuPlate")
		assert_bool(sb is StyleBoxTexture).override_failure_message(
			"MenuPlate/styles/%s не StyleBoxTexture (тема провалилась на базовый Button)" % st
		).is_true()
		if sb is StyleBoxTexture:
			assert_bool(String((sb as StyleBoxTexture).texture.resource_path)
				.contains("button_menu_")).override_failure_message(
				"MenuPlate/%s ссылается не на плиту макета: %s"
				% [st, (sb as StyleBoxTexture).texture.resource_path]
			).is_true()
	var ui: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(ui)
	var col := ui.get_node_or_null("RightColumn")
	assert_object(col).is_not_null()
	if col == null:
		return
	for btn in col.get_children():
		assert_bool(btn.get_theme_type_variation() == &"MenuPlate").override_failure_message(
			"%s стартового экрана не в варианте MenuPlate — на нём не видно плиту макета"
			% btn.name
		).is_true()


# --- 7. провенанс не расходится с темой --------------------------------------

func test_manifest_margins_match_theme() -> void:
	# MANIFEST.json — единственная запись о том, как кит нарезается. Если тема
	# отступит в сторону, провенанс соврёт, а следующий шаг сделает отступы
	# «по манифесту» и получит растянутую фаску.
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_bool(man is Dictionary).is_true()
	if not (man is Dictionary):
		return
	var files: Dictionary = (man as Dictionary)["files"]
	var texs: Dictionary = _theme_textures()
	var checked := 0
	for key in texs:
		var sb: StyleBoxTexture = texs[key] as StyleBoxTexture
		if sb == null:
			continue
		var rel: String = String(sb.texture.resource_path).trim_prefix(KIT_DIR + "/")
		if not files.has(rel):
			continue
		if _kit_kind(String(sb.texture.resource_path)) == "full-bleed":
			continue  # у полноцветного носителя нарезки нет по построению
		var want: Array = []
		for v in files[rel]["texture_margin"]:  # JSON отдаёт числа float'ом
			want.append(int(v))
		var got: Array = [
			int(sb.texture_margin_left), int(sb.texture_margin_top),
			int(sb.texture_margin_right), int(sb.texture_margin_bottom),
		]
		assert_array(got).override_failure_message(
			"%s: тема режет %s как %s, а манифест обещает %s"
			% [key, rel, str(got), str(want)]
		).is_equal(want)
		checked += 1
	assert_int(checked).override_failure_message(
		"тема почти не ссылается на кит — сверять отступы не с чем").is_greater_equal(8)
