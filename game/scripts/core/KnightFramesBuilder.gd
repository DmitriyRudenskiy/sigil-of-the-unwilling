class_name KnightFramesBuilder
extends RefCounted
## Строит SpriteFrames героя из листа рыцаря 8x5.
## Лист: ряды 0/2/4 = side(шаг вправо)/run(галоп вправо)/away(вид со спины);
## ряды 1/3 — зеркальные дубли (не используются, игра зеркалит flip_h).
## ВАЖНО: кадры в клетках листа стоят НЕ по центру — каждый кадр
## нормализуется по своему alpha-bbox (центр по X + общая линия земли по Y),
## иначе анимация дрожит.

const GRID_COLS := 8
const GRID_ROWS := 5

const ROW_ANIMS := {0: &"side", 2: &"run", 4: &"away"}
const ROW_FPS := {&"side": 8.0, &"run": 12.0, &"away": 8.0}

## Пороги отреза фона (если он непрозрачный): расстояние до цвета угла листа.
const BG_EPS_HARD := 0.035
const BG_EPS_SOFT := 0.140

static func build_from_file(path: String) -> SpriteFrames:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return build_from_image(img)

static func build_from_image(src: Image) -> SpriteFrames:
	# duplicate() наследуется от Resource и возвращает Variant — поэтому без каста,
	# работаем in-place на переданном изображении (вызывающие стороны передают
	# свежесчитанный Image, как legacy-путь в HeroVisualController).
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var sheet: Image = src
	_strip_background(sheet)

	var w := sheet.get_width()
	var h := sheet.get_height()
	# Канвас — единый размер клетки (вверх по округлению): 574x574 -> 72x115,
	# чтобы все кадры одного аним-цикла были пиксель-в-пиксель одного размера.
	var cw := (w + GRID_COLS - 1) / GRID_COLS
	var ch := (h + GRID_ROWS - 1) / GRID_ROWS
	if cw <= 0 or ch <= 0:
		return null

	# Проход 1: alpha-bbox каждой клетки + общая линия земли (мин. нижний отступ).
	# Границы клеток пропорциональные (int(col * w / COLS)) — при 574x574 целочисленное
	# деление дало бы дрейф до 5 px на последней колонке.
	var frames := {}  # row -> Array[GRID_COLS] of {"img": Image, "w": int, "h": int} | null
	var ground_pad := ch
	for row in GRID_ROWS:
		var y0 := int(row * h / GRID_ROWS)
		var y1 := int((row + 1) * h / GRID_ROWS)
		var row_ch: int = y1 - y0
		var row_frames: Array = []
		row_frames.resize(GRID_COLS)
		for col in GRID_COLS:
			var x0 := int(col * w / GRID_COLS)
			var x1 := int((col + 1) * w / GRID_COLS)
			var cell := sheet.get_region(Rect2i(x0, y0, x1 - x0, row_ch))
			var used := cell.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				row_frames[col] = null
				continue
			row_frames[col] = {"img": cell.get_region(used), "w": used.size.x, "h": used.size.y}
			ground_pad = mini(ground_pad, row_ch - (used.position.y + used.size.y))
		frames[row] = row_frames
	if ground_pad == ch:
		ground_pad = 0

	# Проход 2: нормализация в канвас cw x ch (ре-центрование по X, общая линия земли по Y).
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	for row in ROW_ANIMS:
		var an: StringName = ROW_ANIMS[row]
		sf.add_animation(an)
		sf.set_animation_loop(an, true)
		sf.set_animation_speed(an, ROW_FPS.get(an, 8.0))
		var row_frames: Array = frames.get(row, [])
		for col in GRID_COLS:
			var f: Dictionary = row_frames[col] as Dictionary
			if f == null:
				continue
			var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
			var dx := int(roundf((cw - int(f["w"])) * 0.5))
			var dy := ch - ground_pad - int(f["h"])
			canvas.blit_rect(f["img"], Rect2i(0, 0, int(f["w"]), int(f["h"])), Vector2i(dx, dy))
			sf.add_frame(an, ImageTexture.create_from_image(canvas))

	for an in sf.get_animation_names():
		if sf.get_frame_count(an) == 0:
			sf.remove_animation(an)
	return sf

## Убирает однородный светлый фон, если он непрозрачный: цвет берётся из угла (0,0).
## Лист с альфа-каналом (прозрачные углы) пропускается без изменений.
## Жёсткий порог — полностью прозрачно, мягкий — частичная alpha для
## сглаженных краёв (антиалиасинг не оставляет белого ореола).
static func _strip_background(img: Image) -> void:
	var bg := img.get_pixel(0, 0)
	if bg.a <= 0.0:
		return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var dr := c.r - bg.r
			var dg := c.g - bg.g
			var db := c.b - bg.b
			var d := sqrt(dr * dr + dg * dg + db * db)
			if d <= BG_EPS_HARD:
				c.a = 0.0
				img.set_pixel(x, y, c)
			elif d < BG_EPS_SOFT:
				c.a *= (d - BG_EPS_HARD) / (BG_EPS_SOFT - BG_EPS_HARD)
				img.set_pixel(x, y, c)
