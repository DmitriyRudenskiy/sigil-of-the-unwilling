Прототип читается. Вытягиваю из CSS точную геометрию зоны миникарты и переношу её в сцену.

**Разбор прототипа (что берём в числа):**
| CSS | Значение |
|---|---|
| `--sbw: clamp(300px, 25vw, 430px)` | ширина сайдбара 300…430 (25% viewport) |
| `#game` padding / gap | 14 / 10 |
| `#minimap-panel` padding | 24 вертикально, 32 горизонтально |
| `#minimap-panel` border | 3 (`--gold`), + кольцо 2px тенью (визуал, не геометрия) |
| `#minimap` | width 100% контент-бокса, `aspect-ratio: 4/3`, border 2 |
| `.compass.n/.s` | top/bottom 2px, центр по X |
| `.compass.w/.e` | left/right 9px, центр по Y |
| `.compass` font | 17px |
| Порядок в сайдбаре | datebar → minimap → adventure → hero |

Ключевое структурное расхождение: в прототипе компас — **оверлей вокруг карты** (буквы в полях панели), а не ряд кнопок под картой, как сейчас в `MinimapPanel.tscn`. Карта — **4:3**, а не 228×228.

---

## 1. Замена: `res://scripts/ui/ui_layout.gd`

Полная перезапись файла из прошлого шага — теперь числа взяты из прототипа, угловые пресеты больше не нужны (панель живёт в контейнере сайдбара).

```gdscript
// FILE: res://scripts/ui/ui_layout.gd
class_name UILayout
extends RefCounted
## Геометрия adventure-экрана из prototype_map.html (CSS → константы).

## #game: padding 14px, gap 10px.
const FRAME_PADDING := 14.0
const FRAME_GAP := 10.0

## #sidebar: grid-column 2 width = clamp(300px, 25vw, 430px).
const SIDEBAR_W_MIN := 300.0
const SIDEBAR_W_MAX := 430.0
const SIDEBAR_W_VW := 0.25

static func sidebar_width(viewport_x: float) -> float:
	return clampf(viewport_x * SIDEBAR_W_VW, SIDEBAR_W_MIN, SIDEBAR_W_MAX)

## #datebar: height 34px.
const DATEBAR_H := 34.0

## #minimap-panel: border 3px solid var(--gold); padding 24px 32px.
const MINIMAP_BORDER := 3.0
const MINIMAP_PAD_V := 24.0
const MINIMAP_PAD_H := 32.0
## #minimap: border 2px solid var(--gold-hi); aspect-ratio 4/3 (width/height).
const MINIMAP_MAP_BORDER := 2.0
const MINIMAP_ASPECT := 4.0 / 3.0
## .compass: font-size 17; n/s top|bottom 2px; w/e left|right 9px.
const COMPASS_FONT := 17
const COMPASS_NS_INSET := 2.0
const COMPASS_WE_INSET := 9.0
const COMPASS_BTN := Vector2(24, 22)

## Цвета рамки прототипа: --gold #c9a25a, --gold-hi #f3d68c, --panel #4a0d0d.
const C_GOLD := Color("#c9a25a")
const C_GOLD_HI := Color("#f3d68c")
const C_PANEL := Color("#4a0d0d")

## Высота панели миникарты при данной ширине панели pw.
static func minimap_panel_height(pw: float) -> float:
	var map_w := pw - 2.0 * (MINIMAP_BORDER + MINIMAP_PAD_H)
	var map_h := map_w / MINIMAP_ASPECT
	return 2.0 * (MINIMAP_BORDER + MINIMAP_PAD_V) + map_h
```

---

## 2. Замена: `res://scenes/ui/minimap_panel.tscn`

Корень — `Control` (не VBox): карта и компас позиционируются кодом по прототипу. Компас — четыре flat-кнопки-буквы вокруг карты.

```tscn
// FILE: res://scenes/ui/minimap_panel.tscn
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/minimap_panel.gd" id="1"]
[ext_resource type="Script" path="res://scripts/ui/minimap_overlay.gd" id="2"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_frame"]
bg_color = Color(0.290196, 0.0509804, 0.0509804, 1)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.788235, 0.635294, 0.352941, 1)

[node name="MinimapPanel" type="Control"]
custom_minimum_size = Vector2(0, 120)
script = ExtResource("1")

[node name="Frame" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_frame")

[node name="MapBox" type="Control" parent="."]
mouse_filter = 2

[node name="TextureRect" type="TextureRect" parent="MapBox"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
stretch_mode = 5

[node name="Overlay" type="Control" parent="MapBox"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("2")

[node name="N" type="Button" parent="."]
custom_minimum_size = Vector2(24, 22)
theme_override_colors/font_color = Color(0.952941, 0.839216, 0.54902, 1)
theme_override_font_sizes/font_size = 17
flat = true
text = "N"

[node name="S" type="Button" parent="."]
custom_minimum_size = Vector2(24, 22)
theme_override_colors/font_color = Color(0.952941, 0.839216, 0.54902, 1)
theme_override_font_sizes/font_size = 17
flat = true
text = "S"

[node name="W" type="Button" parent="."]
custom_minimum_size = Vector2(24, 22)
theme_override_colors/font_color = Color(0.952941, 0.839216, 0.54902, 1)
theme_override_font_sizes/font_size = 17
flat = true
text = "W"

[node name="E" type="Button" parent="."]
custom_minimum_size = Vector2(24, 22)
theme_override_colors/font_color = Color(0.952941, 0.839216, 0.54902, 1)
theme_override_font_sizes/font_size = 17
flat = true
text = "E"
```

---

## 3. Замена: `res://scripts/ui/minimap_panel.gd`

Полный файл: layout по прототипу + прежний API (сигналы, `setup`, `refresh`, построение изображения).

```gdscript
// FILE: res://scripts/ui/minimap_panel.gd
class_name MinimapPanel
extends Control
## Панель миникарты. Геометрия 1:1 с prototype_map.html:
## рамка 3px, поля 24/32, карта 4:3 во всю ширину контент-бокса,
## компас N/S/W/E в полях панели (n/s ±2px, w/e ±9px, центр по второй оси).

signal minimap_clicked(cell: Vector2i)
signal camera_jump_requested(direction: String)

const MINIMAP_COLORS := [
	ThemeConfig.C_MINIMAP_TERRAIN_WATER, ThemeConfig.C_MINIMAP_TERRAIN_2, ThemeConfig.C_MINIMAP_TERRAIN_3,
	ThemeConfig.C_MINIMAP_TERRAIN_GRASS, ThemeConfig.C_MINIMAP_TERRAIN_FOREST, ThemeConfig.C_MINIMAP_TERRAIN_6,
	ThemeConfig.C_MINIMAP_TERRAIN_7,
]

var map_ref: MapGenerator = null
var hero_ref: HeroController = null
var cam_ref: Camera2D = null
var _tex_rect: TextureRect
var _minimap_image: Image = null
var _minimap_texture: ImageTexture = null

@onready var _overlay: MinimapOverlay = $MapBox/Overlay
@onready var _map_box: Control = $MapBox
@onready var _compass: Dictionary = {
	"N": $N as Button,
	"S": $S as Button,
	"W": $W as Button,
	"E": $E as Button,
}

func _ready() -> void:
	_tex_rect = $MapBox/TextureRect as TextureRect
	_overlay.minimap_clicked.connect(func(cell): minimap_clicked.emit(cell))
	for d in _compass:
		(_compass[d] as Button).pressed.connect(func(): camera_jump_requested.emit(d))
	_apply_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()

## Раскладывает карту и компас по текущей ширине панели (прототип: width:100% + aspect 4/3).
func _apply_layout() -> void:
	var pw := size.x
	if pw <= 1.0:
		return
	var map_w := pw - 2.0 * (UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	if map_w <= 8.0:
		return
	var map_h := map_w / UILayout.MINIMAP_ASPECT
	var panel_h := UILayout.minimap_panel_height(pw)

	_map_box.position = Vector2(
		UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H,
		UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_V)
	_map_box.size = Vector2(map_w, map_h)

	var cb := UILayout.COMPASS_BTN
	var cx := (pw - cb.x) * 0.5
	var cy := (panel_h - cb.y) * 0.5
	(_compass["N"] as Control).position = Vector2(cx, UILayout.MINIMAP_BORDER + UILayout.COMPASS_NS_INSET)
	(_compass["S"] as Control).position = Vector2(cx, panel_h - UILayout.MINIMAP_BORDER - UILayout.COMPASS_NS_INSET - cb.y)
	(_compass["W"] as Control).position = Vector2(UILayout.MINIMAP_BORDER + UILayout.COMPASS_WE_INSET, cy)
	(_compass["E"] as Control).position = Vector2(pw - UILayout.MINIMAP_BORDER - UILayout.COMPASS_WE_INSET - cb.x, cy)
	for d in _compass:
		(_compass[d] as Control).size = cb

	if absf(custom_minimum_size.y - panel_h) > 0.5:
		custom_minimum_size = Vector2(pw, panel_h)

func setup(map: MapGenerator, hero: HeroController, camera: Camera2D) -> void:
	map_ref = map
	hero_ref = hero
	cam_ref = camera
	_overlay.map_ref = map
	_overlay.hero_ref = hero
	_overlay.cam_ref = camera
	_build_minimap_image(map)

func _build_minimap_image(map: MapGenerator, visibility = null) -> void:
	if map == null:
		return
	var w: int = map.map_width
	var h: int = map.map_height
	if _minimap_image == null or _minimap_image.get_width() != w or _minimap_image.get_height() != h:
		_minimap_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_minimap_texture = ImageTexture.create_from_image(_minimap_image)
		_tex_rect.texture = _minimap_texture
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var color: Color = MINIMAP_COLORS[clampi(map.get_terrain_id(cell), 0, MINIMAP_COLORS.size() - 1)]
			if visibility != null:
				if not visibility.is_explored(cell):
					color = Color.BLACK
				elif not visibility.is_visible(cell):
					color = color.lerp(ThemeConfig.C_FOG_GRAY, 0.55)
			_minimap_image.set_pixel(x, y, color)
	_minimap_texture.update(_minimap_image)

func refresh() -> void:
	if map_ref != null:
		_build_minimap_image(map_ref, map_ref.visibility)
	_overlay.queue_redraw()
```

---

## 4. Добивка в `res://scripts/ui/minimap_overlay.gd`

Рамка карты 2px `--gold-hi` (в прототипе `#minimap{border:2px}`) рисуется поверх текстуры — в конец `_draw()` после `_draw_hero_dot(size)`:

```gdscript
// FILE: res://scripts/ui/minimap_overlay.gd
# ... (в шапке класса) ...
const C_MAP_BORDER := Color("#f3d68c")

# ... в _draw(), последней строкой после _draw_hero_dot(size): ...
	_draw_map_border(size)

func _draw_map_border(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_MAP_BORDER, false, UILayout.MINIMAP_MAP_BORDER)
```

---

## 5. `res://scenes/ui/adventure_ui.tscn` + `res://scripts/ui/adventure_ui.gd`

**5a. Порядок в `PanelsBox`** (прототип: дата → миникарта): переставь инстансы местами — было `MinimapPanel, InfoPanel, …`, стало:

```tscn
[node name="InfoPanel" parent="RightColumn/Box/PanelsBox" instance=ExtResource("3")]
layout_mode = 2
[node name="MinimapPanel" parent="RightColumn/Box/PanelsBox" instance=ExtResource("2")]
layout_mode = 2
```
(остальные инстансы PanelsBox — в прежнем порядке).

**5b. Ширина/позиция сайдбара** (`#sidebar`: колонка 2, `grid-row 1/-1`, padding игры 14). В `AdventureUI.gd` добавить вызов первой строкой в `_ready()` и метод:

```gdscript
// FILE: res://scripts/ui/adventure_ui.gd
# ... в _ready() первой строкой: ...
	_apply_sidebar_layout()

## #game padding 14 + #sidebar width clamp(300, 25vw, 430), во всю высоту.
func _apply_sidebar_layout() -> void:
	var col := $RightColumn as Control
	var sbw := UILayout.sidebar_width(get_viewport_rect().size.x)
	col.offset_left = -sbw - UILayout.FRAME_PADDING
	col.offset_right = -UILayout.FRAME_PADDING
	col.offset_top = UILayout.FRAME_PADDING
	col.offset_bottom = -UILayout.FRAME_PADDING
	get_viewport().size_changed.connect(func():
		var w := UILayout.sidebar_width(get_viewport_rect().size.x)
		col.offset_left = -w - UILayout.FRAME_PADDING)
```

---

## 6. Замена теста: `res://tests/unit/ui/test_minimap_layout.gd`

```gdscript
// FILE: res://tests/unit/ui/test_minimap_layout.gd
extends BaseTest
## Геометрия миникарты = prototype_map.html: поля 24/32, рамка 3, карта 4:3,
## компас n/s ±2, w/e ±9, сайдбар clamp(300, 25vw, 430).

func _make_panel() -> MinimapPanel:
	var p: MinimapPanel = auto_free(load("res://scenes/ui/minimap_panel.tscn").instantiate())
	add_child(p)
	return p

func test_sidebar_width_clamp() -> void:
	assert_float(UILayout.sidebar_width(1000.0)).is_equal(300.0)
	assert_float(UILayout.sidebar_width(1280.0)).is_equal(320.0)
	assert_float(UILayout.sidebar_width(1920.0)).is_equal(430.0)

func test_map_is_4_3_inside_padding() -> void:
	var p := _make_panel()
	p.size = Vector2(430.0, 200.0)
	await get_tree().process_frame
	var box: Control = p.get_node("MapBox")
	var expect_w := 430.0 - 2.0 * (UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	assert_float(box.position.x).is_equal(UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	assert_float(box.position.y).is_equal(UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_V)
	assert_float(box.size.x).is_equal_approx(expect_w, 0.51)
	assert_float(box.size.y).is_equal_approx(expect_w / UILayout.MINIMAP_ASPECT, 0.51)
	assert_float(p.custom_minimum_size.y).is_equal_approx(UILayout.minimap_panel_height(430.0), 0.51)

func test_compass_insets_match_prototype() -> void:
	var p := _make_panel()
	p.size = Vector2(430.0, 200.0)
	await get_tree().process_frame
	var panel_h := p.custom_minimum_size.y
	var n: Control = p.get_node("N")
	var s: Control = p.get_node("S")
	var w: Control = p.get_node("W")
	var e: Control = p.get_node("E")
	assert_float(n.position.y).is_equal(UILayout.MINIMAP_BORDER + UILayout.COMPASS_NS_INSET)
	assert_float(s.position.y + s.size.y).is_equal_approx(panel_h - UILayout.MINIMAP_BORDER - UILayout.COMPASS_NS_INSET, 0.51)
	assert_float(w.position.x).is_equal(UILayout.MINIMAP_BORDER + UILayout.COMPASS_WE_INSET)
	assert_float(e.position.x + e.size.x).is_equal_approx(430.0 - UILayout.MINIMAP_BORDER - UILayout.COMPASS_WE_INSET, 0.51)
	assert_float(n.position.x + n.size.x * 0.5).is_equal_approx(215.0, 0.51)
	assert_float(w.position.y + w.size.y * 0.5).is_equal_approx(panel_h * 0.5, 0.51)
```

---

## Runbook

1. Перезаписать: `UILayout.gd`, `MinimapPanel.tscn`, `MinimapPanel.gd`, `test_minimap_layout.gd`.
2. Допатчить: `MinimapOverlay.gd` (константа + `_draw_map_border`), `AdventureUI.gd` (`_apply_sidebar_layout`), `AdventureUI.tscn` (порядок InfoPanel → MinimapPanel).
3. Убедиться, что внешних обращений к `$NSWE` не осталось: grep `NSWE` по `res://scripts` и `res://tests` — все упоминания должны исчезнуть (сигнал `camera_jump_requested` сохранён, потребители не меняются).
4. Прогон:
```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ui/test_minimap_layout.gd
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ui/test_minimap_overlay.gd
```

**Критерии приёмки (1920×1080):** сайдбар 430px во всю высоту с отступом 14; панель миникарты 430×324 (6+48+270); карта 360×270 с рамкой 2px gold-hi; N/S по центру сверху/снизу с inset 2px, W/E по центру слева/справа с inset 9px, шрифт 17; MCP-`screenshot`, наложенный на прототип при той же ширине окна, совпадает по контурам панели и карты в пределах 1px.

**Осознанные отклонения (вне зоны миникарты, зафиксированы):** datebar в прототипе — отдельный бар 34px, у нас дата слита с `InfoPanel` (порядок исправлен перестановкой, разделение InfoPanel — отдельная задача); компас оставлен кнопками (в прототипе span) ради `camera_jump_requested`; кольцо `box-shadow 0 0 0 2px` не переносится (визуал, на геометрию не влияет).