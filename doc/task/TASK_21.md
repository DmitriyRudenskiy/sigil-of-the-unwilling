Спрайт с героем лежит тут /Users/user/Downloads/1789146336378-01a0916d-cbed-7ca8-b59e-828b6e3ea5fc.png перемести в нужное место

Принято. Жёлтая точка — это фолбэк `PlaceholderTexture.circle(...)`, который срабатывал, потому что старый билдер анимации не совпадал с этим листом: он резал лист на клетки **128×128 и 4 колонки** (реальный лист — **8×5, клетка 75×103**), а кадр `"away"` вообще добавлялся **один раз вне цикла** (переменная `c` после цикла = 4 → регион за границами). Плюс лист с белым фоном и кадры в клетках стоят не по центру — без нормализации по alpha-bbox анимация бы «дрожала».

Ниже — готовая замена: новый утилитарный билдер + полный `HeroVisuals.gd`.

---

## 1. Новый файл: `res://scripts/core/KnightFramesBuilder.gd`

Нарезает лист 8×5, вырезает белый фон (с мягким краем), нормализует каждый кадр по alpha-bbox (центрирование по горизонтали + общая линия земли), собирает `SpriteFrames`.

```gdscript
// FILE: res://scripts/core/KnightFramesBuilder.gd
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

## Пороги отреза белого фона: расстояние до цвета угла листа.
const BG_EPS_HARD := 0.035
const BG_EPS_SOFT := 0.140

class Frame:
	var img: Image
	var w: int
	var h: int

static func build_from_file(path: String) -> SpriteFrames:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return build_from_image(img)

static func build_from_image(src: Image) -> SpriteFrames:
	var sheet := src.duplicate()
	if sheet.get_format() != Image.FORMAT_RGBA8:
		sheet.convert(Image.FORMAT_RGBA8)
	_strip_background(sheet)

	var cell_w := sheet.get_width() / GRID_COLS
	var cell_h := sheet.get_height() / GRID_ROWS
	if cell_w <= 0 or cell_h <= 0:
		return null

	# Проход 1: alpha-bbox каждой клетки + общая линия земли (мин. нижний отступ).
	var frames := {}  # row -> Array[GRID_COLS] of (Frame | null)
	var ground_pad := cell_h
	for row in GRID_ROWS:
		var row_frames: Array = []
		row_frames.resize(GRID_COLS)
		for col in GRID_COLS:
			var cell := sheet.get_region(Rect2i(col * cell_w, row * cell_h, cell_w, cell_h))
			var used := cell.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				row_frames[col] = null
				continue
			var f := Frame.new()
			f.img = cell.get_region(used)
			f.w = used.size.x
			f.h = used.size.y
			row_frames[col] = f
			ground_pad = mini(ground_pad, cell_h - (used.position.y + used.size.y))
		frames[row] = row_frames
	if ground_pad == cell_h:
		ground_pad = 0

	# Проход 2: нормализация в канвас размера клетки (ре-центрование).
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
			var f: Frame = row_frames[col]
			if f == null:
				continue
			var canvas := Image.create(cell_w, cell_h, false, Image.FORMAT_RGBA8)
			var dx := int(roundf((cell_w - f.w) * 0.5))
			var dy := cell_h - ground_pad - f.h
			canvas.blit_rect(f.img, Rect2i(0, 0, f.w, f.h), Vector2i(dx, dy))
			sf.add_frame(an, ImageTexture.create_from_image(canvas))

	for an in sf.get_animation_names():
		if sf.get_frame_count(an) == 0:
			sf.remove_animation(an)
	return sf

## Убирает однородный светлый фон: цвет берётся из угла (0,0).
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
```

---

## 2. Замена: `res://scenes/entities/HeroVisuals.gd`

Полный файл. Жёлтая точка остаётся **только** как фолбэк при отсутствии листа.

```gdscript
// FILE: res://scenes/entities/HeroVisuals.gd
class_name HeroVisuals
extends Node2D
## Визуал героя: анимация рыцаря из листа 8x5, маркер цели, превью пути,
## орб состояния. Жёлтая точка-заглушка — только если лист не найден.

const DestMarkerScene := preload("res://scenes/entities/DestMarker.tscn")
const StatusOrbScene := preload("res://scenes/entities/StatusOrb.tscn")

const HERO_SHEET_CANDIDATES := [
	"res://assets/raw/hero_knight.png",
	"res://assets/raw/knight.png",
	"res://assets/raw/hero.png",
]

## Ряд 0 листа смотрит ВПРАВО — управляет знаком flip_h.
const SIDE_FACES_RIGHT := true

@onready var _anim: AnimatedSprite2D = $Anim
@onready var _fallback: Sprite2D = $Fallback

## MapGenerator для cell -> world (превью пути). Выставляется извне.
var map: Node = null

var _marker: DestMarker = null
var _status_orb: StatusOrb = null
var _path_line: Line2D = null
var _avatar_tex: Texture2D = null
var _sheet_path_cache := ""

func _ready() -> void:
	_build_animation()

func avatar_texture() -> Texture2D:
	return _avatar_tex

# ═══════════════ АНИМАЦИЯ ═══════════════

func _build_animation() -> void:
	var sf := KnightFramesBuilder.build_from_file(_find_sheet())
	if sf == null or sf.get_animation_names().is_empty():
		_use_fallback()
		return
	_anim.sprite_frames = sf
	_anim.scale = Vector2(0.62, 0.62)
	_anim.centered = true
	_anim.visible = true
	_fallback.visible = false
	_anim.animation = &"side"
	_anim.stop()
	_anim.frame = 0
	_avatar_tex = sf.get_frame_texture(&"side", 0)
	GameLogger.hero("Knight animation built from %s" % _sheet_path_cache)

func _use_fallback() -> void:
	_fallback.texture = PlaceholderTexture.circle(20, Color(0.9, 0.7, 0.1), Color(0.3, 0.2, 0.0))
	_fallback.visible = true
	_anim.visible = false
	GameLogger.warn("HeroVisuals: sheet not found or empty, using placeholder dot")

func _find_sheet() -> String:
	if _sheet_path_cache != "":
		return _sheet_path_cache
	for c in HERO_SHEET_CANDIDATES:
		if FileAccess.file_exists(c):
			_sheet_path_cache = c
			return c
	return ""

func set_facing(delta: Vector2i) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if delta.x != 0:
		_anim.animation = &"side"
		_anim.flip_h = (delta.x < 0) if SIDE_FACES_RIGHT else (delta.x > 0)
	else:
		_anim.animation = &"away"
		_anim.flip_h = delta.y >= 0
	_anim.play()

## Галоп вместо шага (опционально, если есть ряд 2).
func set_running(enabled: bool) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if not _anim.sprite_frames.has_animation(&"run"):
		return
	if _anim.animation == &"side" or _anim.animation == &"run":
		_anim.animation = &"run" if enabled else &"side"

func idle_animation() -> void:
	if _anim == null:
		return
	_anim.stop()
	_anim.frame = 0

# ═══════════════ ПУТЬ / МАРКЕР / ОРБ ═══════════════

func setup_path_visual() -> void:
	if _marker == null:
		_marker = DestMarkerScene.instantiate()
		_marker.name = "DestMarker"
		add_child(_marker)
		_marker.visible = false
	if _path_line == null:
		_path_line = Line2D.new()
		_path_line.name = "PathLine"
		_path_line.width = 3.0
		_path_line.default_color = Color(0.9, 0.8, 0.4, 0.6)
		add_child(_path_line)
		_path_line.visible = false
	if _status_orb == null:
		_status_orb = StatusOrbScene.instantiate()
		add_child(_status_orb)

func draw_path(pts: Array[Vector2i]) -> void:
	if pts.is_empty():
		clear_path_visual()
		return
	setup_path_visual()
	_path_line.clear_points()
	for p in pts:
		_path_line.add_point(_cell_to_local(p))
	_path_line.visible = true
	_marker.position = _cell_to_local(pts[pts.size() - 1])
	_marker.visible = true

func clear_path_visual() -> void:
	if _path_line != null:
		_path_line.clear_points()
		_path_line.visible = false
	if _marker != null:
		_marker.visible = false

func show_marker(pos: Vector2) -> void:
	setup_path_visual()
	_marker.position = pos
	_marker.visible = true

func update_status_orb(mp_ratio: float) -> void:
	setup_path_visual()
	_status_orb.set_ratio(mp_ratio)
	_status_orb.visible = mp_ratio < 0.999

func _cell_to_local(cell: Vector2i) -> Vector2:
	if map != null and map.has_method("map_to_local"):
		return map.map_to_local(cell) - global_position
	return Vector2(cell) * 82.0 - global_position
```

---

## 3. Тест: `res://tests/unit/entities/test_knight_frames_builder.gd`

```gdscript
// FILE: res://tests/unit/entities/test_knight_frames_builder.gd
extends BaseTest

const SHEET_PATH := "res://assets/raw/hero_knight.png"

func test_build_creates_expected_animations() -> void:
	var sf := KnightFramesBuilder.build_from_file(SHEET_PATH)
	assert_that(sf).is_not_null()
	assert_bool(sf.has_animation(&"side")).is_true()
	assert_bool(sf.has_animation(&"away")).is_true()
	assert_bool(sf.has_animation(&"run")).is_true()
	assert_int(sf.get_frame_count(&"side")).is_equal(8)
	assert_int(sf.get_frame_count(&"run")).is_equal(8)
	assert_int(sf.get_frame_count(&"away")).is_equal(8)

func test_background_stripped_and_frames_recentered() -> void:
	var sf := KnightFramesBuilder.build_from_file(SHEET_PATH)
	var tex: Texture2D = sf.get_frame_texture(&"side", 0)
	var img: Image = tex.get_image()
	# Белый фон удалён: углы прозрачны.
	assert_float(img.get_pixel(0, 0).a).is_equal(0.0)
	assert_float(img.get_pixel(img.get_width() - 1, 0).a).is_equal(0.0)
	# Кадр отцентрован по X с точностью до 1 px (нормализация bbox).
	var used := img.get_used_rect()
	var center_x := float(used.position.x) + float(used.size.x) * 0.5
	assert_float(center_x).is_equal_approx(float(img.get_width()) * 0.5, 1.0)

func test_missing_sheet_returns_null() -> void:
	assert_that(KnightFramesBuilder.build_from_file("res://nope.png")).is_null()
```

---

## Runbook

**Шаг 1.** Сохрани загруженный лист как `res://assets/raw/hero_knight.png` (импорт не нужен — `Image.load_from_file` читает PNG напрямую).
**Шаг 2.** Создай `res://scripts/core/KnightFramesBuilder.gd` и `res://tests/unit/entities/test_knight_frames_builder.gd`.
**Шаг 3.** Перезапиши `res://scenes/entities/HeroVisuals.gd` (сцена `HeroVisuals.tscn` не меняется: дети `Fallback`/`Anim` на месте).
**Шаг 4.** Проверка:
```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/entities/test_knight_frames_builder.gd
```
**Критерии приёмки:**
1. В мире герой — анимированный рыцарь, жёлтой точки нет; точка возвращается только при удалении листа (фолбэк).
2. Прогони героя вправо/влево/вверх/вниз: цикл шага и вид со спины переключаются, зеркало корректно (если рыцарь «идёт задом» при движении вправо — переключи `SIDE_FACES_RIGHT` на `false`).
3. Дрожания нет: силуэт стоит на одной линии земли при проигрывании цикла (это и есть нормализация «не все кадры по центру»).
4. Если герой визуально сместился по высоте относительно тайла (канвас теперь 75×103 вместо 128×128) — подровняй один раз `_anim.offset` или `position` в `HeroVisuals.tscn`, логика не меняется.