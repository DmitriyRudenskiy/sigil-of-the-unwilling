Принято. Разбор прототипа боя:

| Элемент прототипа | Значение |
|---|---|
| Сетка | ROWS=11, COLS = max(19, …по аспекту экрана) — поле от края до края |
| Панель | height 60, padding 6/10, gap 6 |
| Кнопки групп | 44×44, font 20, рамка 2 `#e0b862`, radius 5 |
| Левая группа (4) | ⚙ настройки, ⚑ знамя, 🏃 отступить, ⚔ авто-бой |
| Центр | лог-строка 44px (фон `#241605`, рамка 2, font 15) + колонка стрелок ▲▼ 22×21 (font 10) — прокрутка/разворот истории |
| Правая группа (3) | 🛡 строй, ⏳ ждать, 📖 книга заклинаний |

Расхождение с твоим текстом: в прототипе группа из **4 кнопок слева**, из **3 — справа**. Делаю по прототипу; если нужно зеркально — в готовой `.tscn` меняются местами двумя строками (`left_group`/`right_group`), геометрия не меняется.

Текущие расхождения: логическая доска 17×11 (прототип ≥19 колонок); нижняя панель — плоский ряд из 7 кнопок без лог-строки и истории; нет строки «текущий ход» по центру; поле не фитится в экран.

---

## 1. `res://scripts/constants/game_numbers_battle.gd` — заменить строку

```gdscript
// FILE: res://scripts/constants/game_numbers_battle.gd
# Было: const BATTLE_BOARD_W := 17
# Прототип: COLS = max(19, …) — поле от края до края, минимум 19 колонок.
const BATTLE_BOARD_W := 19
const BATTLE_BOARD_H := 11
```
(остальные константы блока не менять).

---

## 2. Замена: `res://scenes/ui/battle_ui.tscn`

```tscn
// FILE: res://scenes/ui/battle_ui.tscn
[gd_scene load_steps=4 format=3 uid="uid://battleui01"]

[ext_resource type="Script" path="res://scripts/ui/battle_ui.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/battle_spellbook_panel.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/settings_screen.tscn" id="3"]

[node name="BattleUI" type="CanvasLayer"]
script = ExtResource("1")

[node name="bottom_bar" type="PanelContainer" parent="."]
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -60.0

[node name="bar_box" type="HBoxContainer" parent="bottom_bar"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="left_group" type="HBoxContainer" parent="bottom_bar/bar_box"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="settings_btn" type="Button" parent="bottom_bar/bar_box/left_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "⚙"

[node name="surrender_btn" type="Button" parent="bottom_bar/bar_box/left_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "⚑"

[node name="retreat_btn" type="Button" parent="bottom_bar/bar_box/left_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "🏃"

[node name="auto_btn" type="Button" parent="bottom_bar/bar_box/left_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "⚔"

[node name="log_wrap" type="HBoxContainer" parent="bottom_bar/bar_box"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 4

[node name="log_panel" type="PanelContainer" parent="bottom_bar/bar_box/log_wrap"]
custom_minimum_size = Vector2(0, 44)
layout_mode = 2
size_flags_horizontal = 3

[node name="status_log" type="Label" parent="bottom_bar/bar_box/log_wrap/log_panel"]
layout_mode = 2
mouse_filter = 2
text = "Выберите существо…"
clip_text = true

[node name="log_arrows" type="VBoxContainer" parent="bottom_bar/bar_box/log_wrap"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="log_up" type="Button" parent="bottom_bar/bar_box/log_wrap/log_arrows"]
custom_minimum_size = Vector2(22, 21)
layout_mode = 2
text = "▲"

[node name="log_down" type="Button" parent="bottom_bar/bar_box/log_wrap/log_arrows"]
custom_minimum_size = Vector2(22, 21)
layout_mode = 2
text = "▼"

[node name="right_group" type="HBoxContainer" parent="bottom_bar/bar_box"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="formation_btn" type="Button" parent="bottom_bar/bar_box/right_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "🛡"

[node name="wait_btn" type="Button" parent="bottom_bar/bar_box/right_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "⏳"

[node name="spellbook_btn" type="Button" parent="bottom_bar/bar_box/right_group"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
text = "📖"

[node name="history_panel" type="PanelContainer" parent="."]
visible = false
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = -386.0
offset_right = -10.0
offset_bottom = -66.0

[node name="Scroll" type="ScrollContainer" parent="history_panel"]
layout_mode = 2

[node name="history_list" type="VBoxContainer" parent="history_panel/Scroll"]
layout_mode = 2
size_flags_horizontal = 3

[node name="initiative_panel" type="PanelContainer" parent="."]
anchor_left = 1.0
anchor_right = 1.0
anchor_top = 0.0
anchor_bottom = 1.0
offset_left = -190.0
offset_top = 100.0
offset_bottom = -80.0

[node name="initiative_list" type="ItemList" parent="initiative_panel"]
layout_mode = 2
theme_override_constants/v_separation = 4

[node name="collapse_btn" type="Button" parent="."]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -190.0
offset_top = 74.0
offset_right = -10.0
offset_bottom = 100.0
text = "▾"

[node name="BattleSpellbookPanel" parent="." instance=ExtResource("2")]
visible = false

[node name="SettingsScreen" parent="." instance=ExtResource("3")]
visible = false
```

---

## 3. Замена: `res://scripts/ui/battle_ui.gd`

Полный файл. Публичный API контроллера сохранён (`set_status`, `update_active_unit`, `set_attack_enabled`, `update_initiative`, `_connect_skeleton`), добавлены: строка хода, история с прокруткой ▲▼ и разворотом полной истории кликом по строке.

```gdscript
// FILE: res://scripts/ui/battle_ui.gd
class_name BattleUI
extends CanvasLayer
## Нижняя панель боя 1:1 с прототипом: 4 кнопки слева, лог-строка хода
## с историей (▲▼ + клик = разворот полной истории) по центру, 3 кнопки справа.

signal wait_requested
signal auto_battle_requested
signal retreat_requested
signal surrender_requested
signal formation_requested
signal spellbook_toggle_requested

const C_BAR_BG := Color("#96703a")
const C_BAR_BORDER := Color("#2e1f0d")
const C_BTN_BG := Color("#6f4f24")
const C_BTN_BORDER := Color("#e0b862")
const C_BTN_TEXT := Color("#ffe9a8")
const C_LOG_BG := Color("#241605")
const C_LOG_TEXT := Color("#ffd98a")

@onready var _bottom_bar: PanelContainer = $bottom_bar
@onready var _status_log: Label = $bottom_bar/bar_box/log_wrap/log_panel/status_log
@onready var _log_panel: PanelContainer = $bottom_bar/bar_box/log_wrap/log_panel
@onready var _history_panel: PanelContainer = $history_panel
@onready var _history_list: VBoxContainer = $history_panel/Scroll/history_list
@onready var _initiative_panel: PanelContainer = $initiative_panel
@onready var _initiative_list: ItemList = $initiative_panel/initiative_list
@onready var _collapse_btn: Button = $collapse_btn
@onready var _spellbook: Control = $BattleSpellbookPanel
@onready var _settings_screen: Control = $SettingsScreen

var _history: Array[String] = []
var _history_idx := -1          # -1 / последний индекс = «живой» режим
var _turn := 0
var _status_text := ""
var _active_text := ""
var _preview_text := ""
var _attack_enabled := false

func _ready() -> void:
	_connect_skeleton()

## Сборка стилей и подключений (вызывается из _ready; имя сохранено для тестов).
func _connect_skeleton() -> void:
	_apply_styles()
	var bar := $bottom_bar/bar_box
	var left: HBoxContainer = bar.get_node("left_group")
	var right: HBoxContainer = bar.get_node("right_group")
	left.get_node("settings_btn").pressed.connect(func(): _settings_screen.visible = not _settings_screen.visible)
	left.get_node("surrender_btn").pressed.connect(func(): surrender_requested.emit())
	left.get_node("retreat_btn").pressed.connect(func(): retreat_requested.emit())
	left.get_node("auto_btn").pressed.connect(func(): auto_battle_requested.emit())
	right.get_node("formation_btn").pressed.connect(func(): formation_requested.emit())
	right.get_node("wait_btn").pressed.connect(func(): wait_requested.emit())
	right.get_node("spellbook_btn").pressed.connect(func():
		_spellbook.visible = not _spellbook.visible
		spellbook_toggle_requested.emit())
	bar.get_node("log_wrap/log_arrows/log_up").pressed.connect(func(): _scroll_history(-1))
	bar.get_node("log_wrap/log_arrows/log_down").pressed.connect(func(): _scroll_history(1))
	_log_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_history())
	_collapse_btn.pressed.connect(func():
		_initiative_panel.visible = not _initiative_panel.visible
		_collapse_btn.text = "▾" if _initiative_panel.visible else "▴")

func _apply_styles() -> void:
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = C_BAR_BG
	bar_sb.border_width_top = 3
	bar_sb.border_color = C_BAR_BORDER
	bar_sb.content_margin_left = 10.0
	bar_sb.content_margin_right = 10.0
	bar_sb.content_margin_top = 6.0
	bar_sb.content_margin_bottom = 6.0
	_bottom_bar.add_theme_stylebox_override("panel", bar_sb)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = C_BTN_BG
	btn_sb.set_border_width_all(2)
	btn_sb.border_color = C_BTN_BORDER
	btn_sb.set_corner_radius_all(5)
	var log_sb := StyleBoxFlat.new()
	log_sb.bg_color = C_LOG_BG
	log_sb.set_border_width_all(2)
	log_sb.border_color = C_BTN_BORDER
	log_sb.set_corner_radius_all(5)
	log_sb.content_margin_left = 10.0
	log_sb.content_margin_right = 10.0
	var hist_sb := StyleBoxFlat.new()
	hist_sb.bg_color = Color(0.09, 0.05, 0.01, 0.95)
	hist_sb.set_border_width_all(2)
	hist_sb.border_color = C_BTN_BORDER
	hist_sb.set_corner_radius_all(5)
	_history_panel.add_theme_stylebox_override("panel", hist_sb)

	for btn_path in [
		"bottom_bar/bar_box/left_group/settings_btn", "bottom_bar/bar_box/left_group/surrender_btn",
		"bottom_bar/bar_box/left_group/retreat_btn", "bottom_bar/bar_box/left_group/auto_btn",
		"bottom_bar/bar_box/right_group/formation_btn", "bottom_bar/bar_box/right_group/wait_btn",
		"bottom_bar/bar_box/right_group/spellbook_btn",
	]:
		var b: Button = get_node(btn_path)
		b.add_theme_stylebox_override("normal", btn_sb)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", C_BTN_TEXT)
	for small in ["log_up", "log_down"]:
		var b: Button = $bottom_bar/bar_box/log_wrap/log_arrows.get_node(small)
		b.add_theme_stylebox_override("normal", btn_sb)
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", C_BTN_TEXT)
	_log_panel.add_theme_stylebox_override("panel", log_sb)
	_status_log.add_theme_font_size_override("font_size", 15)
	_status_log.add_theme_color_override("font_color", C_LOG_TEXT)

# ═══════════════ ПУБЛИЧНЫЙ API (контроллер/вью) ═══════════════

func set_turn(turn: int) -> void:
	_turn = turn
	_compose()

## Сообщение статуса = новая запись истории боя.
func set_status(text: String) -> void:
	_status_text = text
	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)
		_history_idx = _history.size() - 1
		if _history_panel.visible:
			_rebuild_history_panel()
	_compose()

func update_active_unit(u) -> void:
	if u == null:
		_active_text = ""
	else:
		_active_text = "%s ×%d · скорость %d" % [u.get_display_name(), u.count, u.speed]
	_compose()

func set_preview(text: String) -> void:
	_preview_text = text
	_compose()

func set_attack_enabled(enabled: bool) -> void:
	_attack_enabled = enabled
	_compose()

func update_initiative(entries: Array) -> void:
	_initiative_list.clear()
	for e in entries:
		_initiative_list.add_item(str(e))
	_compose()

# ═══════════════ ИСТОРИЯ ═══════════════

func _scroll_history(step: int) -> void:
	if _history.is_empty():
		return
	var last := _history.size() - 1
	if _history_idx < 0:
		_history_idx = last
	_history_idx = clampi(_history_idx + step, 0, last)
	_compose()

func _toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible
	if _history_panel.visible:
		_rebuild_history_panel()

func _rebuild_history_panel() -> void:
	for c in _history_list.get_children():
		c.queue_free()
	for i in _history.size():
		var l := Label.new()
		l.text = "%d. %s" % [i + 1, _history[i]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history_list.add_child(l)

func _compose() -> void:
	var live := _history_idx < 0 or _history_idx >= _history.size() - 1
	var body: String
	if live:
		var parts: Array[String] = []
		if _active_text != "":
			parts.append(_active_text)
		if _status_text != "":
			parts.append(_status_text)
		if _preview_text != "":
			parts.append(_preview_text)
		if _attack_enabled:
			parts.append("⚔ атака доступна")
		body = " · ".join(parts) if parts.size() > 0 else "Выберите существо…"
	else:
		body = "‹%d/%d› %s" % [_history_idx + 1, _history.size(), _history[_history_idx]]
	var prefix := ("Ход %d · " % _turn) if _turn > 0 else ""
	_status_log.text = prefix + body
```

---

## 4. Патч `res://scripts/systems/battle_controller.gd`

Старые connect'ы кнопок нижней панели больше не существуют. Замени блок подключения UI к кнопкам на:

```gdscript
// FILE: res://scripts/systems/battle_controller.gd
# ... в месте, где сейчас подключаются кнопки BattleUI (grep: `.pressed.connect` по файлу), заменить на: ...
func _connect_ui_buttons() -> void:
	if not _ui.wait_requested.is_connected(_on_wait):
		_ui.wait_requested.connect(_on_wait)
	if not _ui.auto_battle_requested.is_connected(_on_auto_battle):
		_ui.auto_battle_requested.connect(_on_auto_battle)
	if not _ui.retreat_requested.is_connected(_on_retreat):
		_ui.retreat_requested.connect(_on_retreat)
	if not _ui.surrender_requested.is_connected(_on_surrender):
		_ui.surrender_requested.connect(_on_surrender)
	if not _ui.formation_requested.is_connected(_on_formation_toggle):
		_ui.formation_requested.connect(_on_formation_toggle)
```
Имена хендлеров — фактические из контроллера (grep `func _on_wait`, `func _on_auto`, `func _on_retreat`…); если хендлера нет (например, `_on_formation_toggle`) — создать заглушку-событие `GameLogger.battle(...)` нельзя: подключи существующий обработчик строя или оставь сигнал неподключённым, убрав строку. Вызовы `_ui.update_active_unit / set_status / set_attack_enabled / update_initiative` не меняются; добавь `_ui.set_turn(bs.turn_number)` рядом с `update_initiative`.

---

## 5. Патч `res://scripts/systems/battle_view.gd` — поле от края до края

```gdscript
// FILE: res://scripts/systems/battle_view.gd
# ... добавить метод и два вызова ...

## Прототип: сетка заполняет экран. Фитим доску 19x11 в viewport без полей.
func fit_camera_to_board() -> void:
	var r := GameNumbersBattle.BATTLE_HEX_OUTLINE_RADIUS
	var board_w := (BattleState.BW + 1.0) * sqrt(3.0) * r
	var board_h := 1.5 * r * (BattleState.BH - 1) + 2.0 * r
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return
	var z := minf(vp.x / board_w, vp.y / board_h)
	_camera.zoom = Vector2(z, z)
	_camera.position = _tile_map.map_to_local(Vector2i(BattleState.BW / 2, BattleState.BH / 2))

# в setup() после paint_field():
	fit_camera_to_board()
	get_viewport().size_changed.connect(fit_camera_to_board)
```

---

## 6. Замена теста: `res://tests/unit/ui/test_battle_ui_onready.gd`

```gdscript
// FILE: res://tests/unit/ui/test_battle_ui_onready.gd
extends BaseTest
const _BattleUIScene := preload("res://scenes/ui/battle_ui.tscn")
var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
		_ui = null

func test_battle_ui_skeleton_matches_prototype() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	var bar: HBoxContainer = ui.get_node("bottom_bar/bar_box")
	assert_int(bar.get_node("left_group").get_child_count()).is_equal(4)
	assert_int(bar.get_node("right_group").get_child_count()).is_equal(3)
	assert_vector2(bar.get_node("left_group/settings_btn").custom_minimum_size).is_equal(Vector2(44, 44))
	assert_vector2(bar.get_node("log_wrap/log_arrows/log_up").custom_minimum_size).is_equal(Vector2(22, 21))
	assert_float(ui.get_node("bottom_bar").offset_top).is_equal(-60.0)

func test_battle_log_history_and_turn() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	ui.set_turn(3)
	ui.set_status("Ход мечника")
	ui.set_status("Атака: 12 урона")
	ui.set_status("Ход лучника")
	var log: Label = ui.get_node("bottom_bar/bar_box/log_wrap/log_panel/status_log")
	assert_str(log.text).contains("Ход 3")
	assert_str(log.text).contains("Ход лучника")
	# ▲▼ листают историю
	ui.get_node("bottom_bar/bar_box/log_wrap/log_arrows/log_up").pressed.emit()
	assert_str(log.text).contains("‹3/3›")
	ui.get_node("bottom_bar/bar_box/log_wrap/log_arrows/log_up").pressed.emit()
	assert_str(log.text).contains("Атака: 12 урона")
	# клик по строке разворачивает полную историю
	var panel: Control = ui.get_node("history_panel")
	assert_bool(panel.visible).is_false()
	ui._toggle_history()
	assert_bool(panel.visible).is_true()
	assert_int(ui.get_node("history_panel/Scroll/history_list").get_child_count()).is_equal(3)

func test_battle_board_is_19_wide() -> void:
	assert_int(GameNumbersBattle.BATTLE_BOARD_W).is_equal(19)
	assert_int(GameNumbersBattle.BATTLE_BOARD_H).is_equal(11)
```

---

## Runbook

1. Перезаписать: `BattleUI.tscn`, `BattleUI.gd`, `test_battle_ui_onready.gd`; правка константы в `GameNumbersBattle.gd`; патчи `BattleController.gd` и `BattleView.gd`.
2. Grep-чеклист старых имён (всё должно исчезнуть или быть осознанно переключено):
```bash
grep -rn "bottom_bar/" game/scripts game/tests | grep -v "bar_box"
grep -rn "top_panel\|_active_info\|_preview\b" game/scripts
grep -rn "BATTLE_BOARD_W\|\b17\b" game/tests/unit/systems | grep -i battle
```
Тесты, хардкодящие правую колонку деплоя (`x = 16`), перевести на `BattleState.BW - 1`.
3. Прогон:
```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ui/test_battle_ui_onready.gd
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/systems
pytest game/tests/mcp/test_battle_controller.py game/tests/mcp/test_battle_full_e2e.py
```
4. Критерии приёмки (1920×1080): доска 19×11 видна целиком по ширине без боковых полей; панель 60px: слева 4 кнопки 44×44, справа 3; по центру строка 44px с «Ход N · …»; ▲▼ листают записи (префикс `‹i/n›`), клик по строке открывает панель полной истории (3+ записи после трёх событий); ⏳/⚔/🏃///📖 вызывают свои сигналы (проверить логами контроллера); MCP-`screenshot`, наложенный на прототип, совпадает по контурам панели и групп кнопок ±1px.


## `res://scenes/battle_view.tscn` — текущее содержимое

Файл не требует правок в контексте прошлой работы по приведению интерфейса боя к прототипу (размер доски 19×11 и фит камеры `fit_camera_to_board()` живут в `BattleView.gd` и `GameNumbersBattle`, а не в сцене).

```tscn
// FILE: res://scenes/battle_view.tscn
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/systems/battle_view.gd" id="1"]
[ext_resource type="Script" path="res://scripts/ui/highlight_overlay.gd" id="2"]
[ext_resource type="Script" path="res://scripts/ui/cursor_overlay.gd" id="3"]

[node name="BattleView" type="Node2D"]
script = ExtResource("1")

[node name="Terrain" type="TileMapLayer" parent="."]

[node name="Highlight" type="Node2D" parent="."]
script = ExtResource("2")

[node name="Cursor" type="Node2D" parent="."]
script = ExtResource("3")

[node name="Camera" type="Camera2D" parent="."]
```

---

### Ключевые точки связки с `BattleView.gd`

| Узел в `.tscn` | Переменная в коде | Что делает |
|---|---|---|
| `Terrain` (TileMapLayer) | `_terrain` / `_tile_map` | В `_ready()` переименовывается в `BattleTerrain`, получает `TileAtlas.build_hex_tileset()`, калибруется через `HexGrid.calibrate()` |
| `Highlight` (Node2D + `HighlightOverlay`) | `_overlay` | Рендер подсветок move/attack/unreachable, `z_index = 5`, `tm = _tile_map` |
| `Cursor` (Node2D + `CursorOverlay`) | `_cursor` | Имя переопределяется в `BattleCursor`, `z_index = 30`, стартует невидимым |
| `Camera` (Camera2D) | `_camera` | `make_current()` в `_ready()`, зум и позиция пересчитываются в `fit_camera_to_board()` |

### Что добавилось в `BattleView.gd` в прошлом шаге (не в сцене)

```gdscript
// FILE: res://scripts/systems/battle_view.gd
# ... в setup() после paint_field() и в конце класса: ...

## Прототип: сетка заполняет экран. Фитим доску 19x11 в viewport без полей.
func fit_camera_to_board() -> void:
	var r := GameNumbersBattle.BATTLE_HEX_OUTLINE_RADIUS
	var board_w := (BattleState.BW + 1.0) * sqrt(3.0) * r
	var board_h := 1.5 * r * (BattleState.BH - 1) + 2.0 * r
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return
	var z := minf(vp.x / board_w, vp.y / board_h)
	_camera.zoom = Vector2(z, z)
	_camera.position = _tile_map.map_to_local(Vector2i(BattleState.BW / 2, BattleState.BH / 2))
```

И в `setup()` (или в `_ready()` после `paint_field()`) вызов:
```gdscript
	fit_camera_to_board()
	get_viewport().size_changed.connect(fit_camera_to_board)
```

---

### Проверка консистентности

Если при запуске боя в консоли появляются `Null` ошибки на `@onready` переменных — значит сцена была переопределена/пересохранена из редактора и потеряла узлы. В этом случае:
1. Открой `BattleView.tscn` в редакторе Godot.
2. Проверь, что в корне ровно 4 ребёнка: `Terrain`, `Highlight`, `Cursor`, `Camera` — именно в таком порядке и с такими именами.
3. `BattleView` — корневой `Node2D`, а не `Node3D` (код использует `map_to_local` и `_tile_map.set_cell` — это 2D API).


## `res://scripts/systems/battle_view.gd` — полный файл

Все существующие методы сохранены, `fit_camera()` заменён на `fit_camera_to_board()` с подпиской на `size_changed` (поле 19×11 фитуется в экран от края до края, как в прототипе).

```gdscript
// FILE: res://scripts/systems/battle_view.gd
class_name BattleView
extends Node2D
## Визуальный слой боя: гексагональная сетка, спрайты юнитов, подсветки,
## курсор, препятствия, анимации движения/атаки. Геометрия поля 1:1 с прототипом:
## 19×11 клеток, фитуется в viewport без полей по бокам.

const _UnitSprite := preload("res://scenes/entities/BattleUnitSprite.tscn")
const _HeroFigure := preload("res://scenes/entities/HeroFigure.tscn")
const UnitSprites := preload("res://scripts/data/UnitSprites.gd")
const TileAtlas := preload("res://scripts/data/TileAtlas.gd")
const HexGrid := preload("res://scripts/core/HexGrid.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")

const RING := 3
const HEX_OUTLINE_RADIUS: float = GameNumbersBattle.BATTLE_HEX_OUTLINE_RADIUS

enum CursorMode { DEFAULT, ATTACK, RANGED, SPELL, MOVE }

@onready var _terrain: TileMapLayer = $Terrain
@onready var _overlay: Node2D = $Highlight
@onready var _cursor: Node2D = $Cursor
@onready var _camera: Camera2D = $Camera

var _tile_map: TileMapLayer = null
var _sprites_by_uid: Dictionary = {}
var _active_tweens: Dictionary = {}

# ═══════════════ ИНИЦИАЛИЗАЦИЯ ═══════════════

func setup() -> void:
	_tile_map = _terrain
	_tile_map.name = "BattleTerrain"
	_tile_map.tile_set = TileAtlas.build_hex_tileset()
	RenderingServer.set_default_clear_color(ThemeConfig.C_BATTLE_BG_VIEW)
	HexGrid.calibrate(_tile_map)
	_overlay.tm = _tile_map
	_overlay.z_index = 5
	_camera.make_current()
	_cursor.name = "BattleCursor"
	_cursor.z_index = 30
	_cursor.visible = false

func paint_field() -> void:
	var grass: Vector2i = TileAtlas.BASE_COORDS[TileAtlas.Biome.GRASS][0]
	for y in range(-RING, BattleState.BH + RING):
		for x in range(-RING, BattleState.BW + RING):
			_tile_map.set_cell(Vector2i(x, y), TileAtlas.SOURCE_ID, grass)

## Прототип: сетка заполняет экран. Фитим доску 19×11 в viewport без полей.
func fit_camera_to_board() -> void:
	var r := GameNumbersBattle.BATTLE_HEX_OUTLINE_RADIUS
	var board_w := (BattleState.BW + 1.0) * sqrt(3.0) * r
	var board_h := 1.5 * r * (BattleState.BH - 1) + 2.0 * r
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return
	var z := minf(vp.x / board_w, vp.y / board_h)
	_camera.zoom = Vector2(z, z)
	_camera.position = _tile_map.map_to_local(Vector2i(BattleState.BW / 2, BattleState.BH / 2))

# ═══════════════ СПРАЙТЫ ЮНИТОВ ═══════════════

func create_unit_sprite(unit: BattleState.BattleUnit) -> void:
	var n: Node2D = _UnitSprite.instantiate()
	var key := unit.get_key()
	var ppath := UnitSprites.find_portrait(key)
	var sp: Sprite2D = n.get_node("Figure")
	if ppath != "":
		sp.texture = load(ppath)
	else:
		var col := ThemeConfig.C_SIDE_ATTACKER if unit.side == BattleState.Side.ATTACKER else ThemeConfig.C_SIDE_DEFENDER
		sp.texture = PlaceholderTexture.circle(22, col, Color(0.1, 0.1, 0.1))
	sp.flip_h = (unit.side == BattleState.Side.ATTACKER)
	var display_name := unit.get_display_name()
	var il: Label = n.get_node("Initial")
	il.text = display_name.left(1) if display_name != "" else "?"
	var cl: Label = n.get_node("CountLabel")
	cl.text = str(unit.get_count())
	n.position = _tile_map.map_to_local(unit.cell)
	n.z_index = 6
	n.set_meta("uid", unit.uid)
	_sprites_by_uid[unit.uid] = n
	add_child(n)

func update_unit_count(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var cl := node.get_node_or_null("CountLabel")
	if cl != null:
		cl.text = str(unit.get_count())

func flash_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate", ThemeConfig.C_HIT_FLASH, GameNumbers.HIT_FLASH_SEC)
	tw.tween_property(node, "modulate", Color.WHITE, GameNumbers.HIT_FLASH_RECOVER_SEC)

func remove_unit(unit: BattleState.BattleUnit) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	_kill_unit_tweens(unit.uid)
	_sprites_by_uid.erase(unit.uid)
	node.queue_free()

func spawn_hero_figure() -> void:
	var path := UnitSprites.find_portrait("knight")
	if path == "":
		return
	var hero: Sprite2D = _HeroFigure.instantiate()
	hero.texture = load(path)
	hero.scale = Vector2(1.0, 1.0)
	hero.position = _tile_map.map_to_local(Vector2i(1, 1))
	add_child(hero)

# ═══════════════ АНИМАЦИИ ═══════════════

func animate_move(unit: BattleState.BattleUnit, path: Array) -> Tween:
	var node := _find_node(unit)
	if node == null or path.is_empty():
		return null
	_kill_unit_tweens(unit.uid)
	var tw := create_tween()
	_active_tweens[unit.uid] = tw
	var duration: float = path.size() * GameNumbers.BATTLE_MOVE_STEP_SEC
	for i in path.size():
		var cell: Vector2i = path[i]
		var target_pos := _tile_map.map_to_local(cell)
		tw.tween_property(node, "position", target_pos, GameNumbers.BATTLE_MOVE_STEP_SEC)
	tw.finished.connect(func():
		_active_tweens.erase(unit.uid))
	return tw

func animate_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	var atk_node := _find_node(atk)
	var def_node := _find_node(def)
	if atk_node == null or def_node == null:
		return
	var original_pos := atk_node.position
	var target_pos := def_node.position + Vector2(20, 0) * (-1.0 if atk.side == BattleState.Side.DEFENDER else 1.0)
	var tw := create_tween()
	tw.tween_property(atk_node, "position", target_pos, GameNumbers.BATTLE_ATTACK_ANIM_SEC * 0.5)
	tw.tween_property(atk_node, "position", original_pos, GameNumbers.BATTLE_ATTACK_ANIM_SEC * 0.5)

func show_retaliation_arrow(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	var atk_node := _find_node(atk)
	var def_node := _find_node(def)
	if atk_node == null or def_node == null:
		return
	var arrow := Line2D.new()
	arrow.add_point(atk_node.position)
	arrow.add_point(def_node.position)
	arrow.width = 3.0
	arrow.default_color = Color(1, 0.8, 0.2, 0.95)
	arrow.z_index = 19
	add_child(arrow)
	var tw := create_tween()
	tw.tween_property(arrow, "modulate:a", 0.0, 0.8)
	tw.finished.connect(func(): arrow.queue_free())

# ═══════════════ ПОДСВЕТКИ И КУРСОР ═══════════════

func set_highlights(move: Dictionary, attack: Dictionary) -> void:
	if _overlay == null:
		return
	_overlay.move_cells = move
	_overlay.atk_cells = attack
	_overlay.queue_redraw()

func clear_highlights() -> void:
	if _overlay == null:
		return
	_overlay.move_cells.clear()
	_overlay.atk_cells.clear()
	_overlay.queue_redraw()

func set_unreachable_highlights(cells: Dictionary) -> void:
	if _overlay == null:
		return
	_overlay.unreachable_cells = cells
	_overlay.queue_redraw()

func set_cursor_mode(mode: int) -> void:
	if _cursor == null:
		return
	_cursor.set_mode(mode)

func set_cursor_visible(visible: bool) -> void:
	if _cursor == null:
		return
	_cursor.visible_flag = visible
	_cursor.queue_redraw()

# ═══════════════ ПРЕПЯТСТВИЯ ═══════════════

func add_obstacle(cell: Vector2i, emoji: String) -> void:
	var label := Label.new()
	label.text = emoji
	label.position = _tile_map.map_to_local(cell) + Vector2(-20, -30)
	label.add_theme_font_size_override("font_size", 32)
	label.z_index = 7
	add_child(label)

# ═══════════════ ТЕКСТ И УРОН ═══════════════

func show_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = _tile_map.map_to_local(cell) + Vector2(-30, -40)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.finished.connect(func(): label.queue_free())

func show_damage_number(unit: BattleState.BattleUnit, amount: int) -> void:
	var node := _find_node(unit)
	if node == null:
		return
	show_floating_text(unit.cell, str(amount), ThemeConfig.C_TEXT_DAMAGE)

# ═══════════════ КООРДИНАТЫ ═══════════════

func map_to_local(cell: Vector2i) -> Vector2:
	return _tile_map.map_to_local(cell)

func global_to_map(global_pos: Vector2) -> Vector2i:
	var local_pos := _tile_map.to_local(global_pos)
	return _tile_map.local_to_map(local_pos)

func to_local(global_pos: Vector2) -> Vector2:
	return _tile_map.to_local(global_pos)

# ═══════════════ ВНУТРЕННИЕ МЕТОДЫ ═══════════════

func _kill_unit_tweens(uid: int) -> void:
	if _active_tweens.has(uid):
		var tw = _active_tweens[uid]
		if tw is Tween and tw.is_valid():
			tw.kill()
		_active_tweens.erase(uid)

func _find_node(unit: BattleState.BattleUnit) -> Node2D:
	if unit == null:
		return null
	var node: Node2D = _sprites_by_uid.get(unit.uid, null)
	if node != null and not is_instance_valid(node):
		_sprites_by_uid.erase(unit.uid)
		return null
	return node
```

---

## Интеграция в `BattleController.gd`

В `_ready()` замени `_view.fit_camera()` на:

```gdscript
func _ready() -> void:
	_init_state()
	_init_executor()
	_init_input()
	_init_fx()
	_wire_signals()
	_wire_ui_signals()
	_view.setup()
	_view.paint_field()
	await get_tree().process_frame
	_view.fit_camera_to_board()  # Было: _view.fit_camera()
	get_viewport().size_changed.connect(_view.fit_camera_to_board)
```

---

## Проверка консистентности

После замены файла запусти:

```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/systems/test_battle_view.gd
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/systems/test_battle_controller.gd
```

**Критерии приёмки:**
1. Поле 19×11 видно целиком по ширине без боковых полей (зум = `minf(vp.x / board_w, vp.y / board_h)`).
2. При изменении размера окна (например, с 1920×1080 на 1280×720) поле автоматически пересчитывается (подписка на `size_changed`).
3. Все существующие тесты `test_battle_view.gd` проходят (методы `create_unit_sprite`, `remove_unit`, `set_highlights`, `animate_move` сохранены).

Принято. Разбор прототипа со скриншота:

| Параметр | Значение |
|---|---|
| Порядок кнопок сверху | Продолжить, Новая игра, Загрузить, Настройки, Выход |
| Колонка | справа, вертикально ~ниже центра, ширина ≈340px, отступ справа ≈55px |
| Шаг | ≈64px между центрами (кнопка 40px + зазор 24px) |
|Normal-стиль | плоская кнопка: без рамки/фона, серый текст ≈16px, центрирован |
|Hover/focus | сплошная планка приглушённого золота (~72% alpha) во всю ширину колонки, текст тёмный |
|Лишние кнопки | Арена, Модель воина, Модель мага, Хроника → уходят в настройки |

---

## 1. Фон (Runbook-шаг 0)

```bash
mkdir -p game/assets/ui
cp "/Users/user/Downloads/1788626748853-01a07274-c0c3-7af7-9d09-ae79c571f40c.png" \
   game/assets/ui/main_menu_bg.png
```
`MainMenu._find_bg()` уже ищет `res://assets/ui/main_menu_bg.png` первым кандидатом, `stretch_mode = 6` (cover) в `.tscn` уже стоит — код не меняем.

---

## 2. Замена: `res://scenes/main_menu.tscn`

Колонка из 5 кнопок в порядке прототипа; лишние кнопки и `Spacer` удалены; `VersionLabel` уведён в угол; `LockPanel` вынесен из колонки на корень.

```tscn
// FILE: res://scenes/main_menu.tscn
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/chronicle_screen.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/settings_screen.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/artifact_inventory_screen.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/ui/save_load_screen.tscn" id="5"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
expand_mode = 1
stretch_mode = 6

[node name="RightColumn" type="VBoxContainer" parent="."]
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_left = -395.0
offset_top = 28.0
offset_right = -55.0
offset_bottom = 348.0
theme_override_constants/separation = 24

[node name="ContinueButton" type="Button" parent="RightColumn"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2

[node name="NewGameButton" type="Button" parent="RightColumn"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2

[node name="LoadGameButton" type="Button" parent="RightColumn"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2

[node name="SettingsButton" type="Button" parent="RightColumn"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2

[node name="ExitButton" type="Button" parent="RightColumn"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2

[node name="VersionLabel" type="Label" parent="."]
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -220.0
offset_top = -28.0
offset_right = -8.0
offset_bottom = -6.0
horizontal_alignment = 2
theme_override_font_sizes/font_size = 12
modulate = Color(1, 1, 1, 0.5)

[node name="LockPanel" type="PanelContainer" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="ChronicleScreen" parent="." instance=ExtResource("2")]
visible = false

[node name="SettingsScreen" parent="." instance=ExtResource("3")]
visible = false

[node name="ArtifactInventoryScreen" parent="." instance=ExtResource("4")]
visible = false

[node name="SaveLoadScreen" parent="." instance=ExtResource("5")]
visible = false
```

---

## 3. Блоки замены в `res://scripts/ui/main_menu.gd`

**3a. Заменить блок `@onready`-ссылок на кнопки:**

```gdscript
// FILE: res://scripts/ui/main_menu.gd
@onready var _background: TextureRect = $Background
@onready var _continue_btn: Button = $RightColumn/ContinueButton
@onready var _new_game_btn: Button = $RightColumn/NewGameButton
@onready var _load_game_btn: Button = $RightColumn/LoadGameButton
@onready var _settings_btn: Button = $RightColumn/SettingsButton
@onready var _exit_btn: Button = $RightColumn/ExitButton
@onready var _version_label: Label = $VersionLabel
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _save_load_screen: SaveLoadScreen = $SaveLoadScreen
```
(ссылки `_arena_btn`, `_model_warrior_btn`, `_model_mage_btn`, `_chronicle_btn` удалить).

**3b. В `_ready()` после `_create_save_load_screen()` добавить:**

```gdscript
	_refresh_continue()
```

**3c. Заменить `_style_buttons()` целиком** (стиль прототипа: плоско + золотая планка на hover/focus):

```gdscript
func _style_buttons() -> void:
	var buttons: Array[Button] = [_continue_btn, _new_game_btn, _load_game_btn, _settings_btn, _exit_btn]
	var empty := StyleBoxEmpty.new()
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0.72, 0.54, 0.20, 0.92)
	bar.set_corner_radius_all(2)
	var bar_pressed := bar.duplicate() as StyleBoxFlat
	bar_pressed.bg_color = Color(0.58, 0.42, 0.14, 0.95)
	for btn in buttons:
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", bar)
		btn.add_theme_stylebox_override("pressed", bar_pressed)
		btn.add_theme_stylebox_override("focus", bar)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
		btn.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.03))
		btn.add_theme_color_override("font_pressed_color", Color(0.16, 0.10, 0.03))
		btn.add_theme_color_override("font_focus_color", Color(0.16, 0.10, 0.03))
		btn.mouse_entered.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_hover"))
		btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
		_UIAnimator.setup_button(btn)
```

**3d. Заменить `_localize()` и `_connect_buttons()`:**

```gdscript
func _localize() -> void:
	_continue_btn.text = _loc("Продолжить", "Continue")
	_new_game_btn.text = GameText.menu_new_game()
	_load_game_btn.text = GameText.menu_load_game()
	_settings_btn.text = GameText.menu_settings()
	_exit_btn.text = GameText.menu_exit()
	_version_label.text = GameText.menu_version()

func _connect_buttons() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_new_game_btn.pressed.connect(_on_new_game)
	_load_game_btn.pressed.connect(_on_load_game)
	_settings_btn.pressed.connect(_on_settings)
	_exit_btn.pressed.connect(_on_exit)
	# Лишние кнопки переехали в настройки — хендлеры те же, источник теперь там.
	_settings_screen.arena_requested.connect(_on_arena)
	_settings_screen.model_warrior_requested.connect(_on_model_warrior)
	_settings_screen.model_mage_requested.connect(_on_model_mage)
	_settings_screen.chronicle_requested.connect(_on_chronicle)
```

**3e. Новые методы (добавить рядом с хендлерами):**

```gdscript
func _loc(ru: String, en: String) -> String:
	return ru if TranslationServer.get_locale().begins_with("ru") else en

## «Продолжить»: самый свежий сейв через проверенный путь SaveLoadScreen.
func _on_continue() -> void:
	var slot := _newest_slot()
	if slot < 0:
		return
	_save_load_screen.perform_load(slot)

func _newest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for i in range(1, SaveManager.SLOT_COUNT + 1):
		if not SaveManager.has_save_in_slot(i):
			continue
		var t := 0.0
		if SaveManager.has_method("slot_path"):
			var p: String = SaveManager.slot_path(i)
			if FileAccess.file_exists(p):
				t = FileAccess.get_modified_time(p)
		if best < 0 or t >= best_time:
			best = i
			best_time = t
	return best

func _refresh_continue() -> void:
	var has := _newest_slot() >= 0
	_continue_btn.disabled = not has
	_continue_btn.modulate.a = 0.45 if not has else 1.0
```

---

## 4. Настройки: раздел «Дополнительно»

**4a. Добить `res://scenes/ui/settings_screen.tscn`** — вставить узлы после `AutoSaveToggle`, перед `ButtonRow`:

```tscn
[node name="ExtrasHeader" type="Label" parent="Panel/Box"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.4, 1)
theme_override_font_sizes/font_size = 16

[node name="ExtrasRow" type="HBoxContainer" parent="Panel/Box"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="ArenaButton" type="Button" parent="Panel/Box/ExtrasRow"]
custom_minimum_size = Vector2(120, 36)
layout_mode = 2

[node name="ModelWarriorButton" type="Button" parent="Panel/Box/ExtrasRow"]
custom_minimum_size = Vector2(120, 36)
layout_mode = 2

[node name="ModelMageButton" type="Button" parent="Panel/Box/ExtrasRow"]
custom_minimum_size = Vector2(120, 36)
layout_mode = 2

[node name="ChronicleButton" type="Button" parent="Panel/Box/ExtrasRow"]
custom_minimum_size = Vector2(120, 36)
layout_mode = 2
```

**4b. Блоки в `res://scripts/ui/settings_screen.gd`:**

```gdscript
// FILE: res://scripts/ui/settings_screen.gd
# ... после `signal applied`: ...
signal arena_requested
signal model_warrior_requested
signal model_mage_requested
signal chronicle_requested

# ... новый метод; вызвать последней строкой _init_content() до блока анимации: ...
func _setup_extras() -> void:
	var row := get_node("Panel/Box/ExtrasRow") as HBoxContainer
	(row.get_node("ArenaButton") as Button).pressed.connect(func(): arena_requested.emit())
	(row.get_node("ModelWarriorButton") as Button).pressed.connect(func(): model_warrior_requested.emit())
	(row.get_node("ModelMageButton") as Button).pressed.connect(func(): model_mage_requested.emit())
	(row.get_node("ChronicleButton") as Button).pressed.connect(func(): chronicle_requested.emit())

# ... в конец _localize() добавить: ...
	var _ru := TranslationServer.get_locale().begins_with("ru")
	(get_node("Panel/Box/ExtrasHeader") as Label).text = "Дополнительно" if _ru else "Extras"
	var _row := get_node("Panel/Box/ExtrasRow") as HBoxContainer
	(_row.get_node("ArenaButton") as Button).text = GameText.menu_arena()
	(_row.get_node("ModelWarriorButton") as Button).text = GameText.menu_model_warrior()
	(_row.get_node("ModelMageButton") as Button).text = GameText.menu_model_mage()
	(_row.get_node("ChronicleButton") as Button).text = GameText.menu_chronicle()
```

---

## 5. Тест: `res://tests/unit/ui/test_main_menu_layout.gd`

```gdscript
// FILE: res://tests/unit/ui/test_main_menu_layout.gd
extends BaseTest
const _MenuScene := preload("res://scenes/main_menu.tscn")
var _menu: Node = null

func after_test() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
		_menu = null

func test_menu_column_matches_prototype() -> void:
	_menu = _MenuScene.instantiate()
	get_tree().root.add_child(_menu)
	var col: VBoxContainer = _menu.get_node("RightColumn")
	var names: Array[String] = []
	for c in col.get_children():
		names.append(c.name)
	assert_int(names.size()).is_equal(5)
	assert_str(names[0]).is_equal("ContinueButton")
	assert_str(names[1]).is_equal("NewGameButton")
	assert_str(names[2]).is_equal("LoadGameButton")
	assert_str(names[3]).is_equal("SettingsButton")
	assert_str(names[4]).is_equal("ExitButton")
	# Лишних кнопок в колонке больше нет.
	for gone in ["ArenaButton", "ModelWarriorButton", "ModelMageButton", "ChronicleButton"]:
		assert_that(col.get_node_or_null(gone)).is_null()

func test_extras_moved_to_settings() -> void:
	_menu = _MenuScene.instantiate()
	get_tree().root.add_child(_menu)
	var ss: SettingsScreen = _menu.get_node("SettingsScreen")
	var row: HBoxContainer = ss.get_node("Panel/Box/ExtrasRow")
	assert_int(row.get_child_count()).is_equal(4)
	assert_bool(ss.has_signal("arena_requested")).is_true()
	assert_bool(ss.has_signal("chronicle_requested")).is_true()

func test_continue_disabled_without_saves() -> void:
	_menu = _MenuScene.instantiate()
	get_tree().root.add_child(_menu)
	var btn: Button = _menu.get_node("RightColumn/ContinueButton")
	var expected := _menu._newest_slot() < 0
	assert_bool(btn.disabled).is_equal(expected)
```

---

## Runbook

1. Скопировать фон (шаг 0), перезаписать `MainMenu.tscn`, применить блоки 3a–3e в `MainMenu.gd`, добить `SettingsScreen.tscn`/`.gd` (4a–4b), создать тест.
2. Grep-чеклист старых ссылок (должно стать пусто):
```bash
grep -rn "_arena_btn\|_model_warrior_btn\|_model_mage_btn\|_chronicle_btn" game/scripts/ui/main_menu.gd
grep -rn "ArenaButton\|ModelWarriorButton\|ChronicleButton" game/scenes/main_menu.tscn
```
3. Прогон:
```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ui/test_main_menu_layout.gd
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/test_settings_persist.gd
```
4. Критерии приёмки:
- Меню = скриншот-прототип: арт-фон во весь экран, справа колонка из 5 плоских кнопок в порядке Продолжить → Новая игра → Загрузить → Настройки → Выход; hover/focus — золотая планка с тёмным текстом во всю ширину колонки.
- «Продолжить» серая и некликабельная без сейвов; при наличии сейва грузит самый свежий через `SaveLoadScreen.perform_load`.
- В настройках новый раздел «Дополнительно»: Арена / Модель воина / Модель мага / Хроника — каждое нажатие открывает соответствующий экран прежними хендлерами меню.
- `test_scene_boot.gd` и MCP `test_settings_menu.py` остаются зелёными (путь SettingsButton не изменился).

Проанализировал прототип. Структура окна инвентаря:
- **Левая панель (412px)**: портрет, имя, статы, ряды навыков, сетка 2×3
- **Правая панель (~450px)**: кукла 240×360 + 16 слотов экипировки с абсолютным позиционированием, инвентарь 6 слотов со стрелками ◀▶, 3 кнопки действий
- **Боковая колонка (80px)**: баннер, мини-портрет, 7 слотов, OK
- **Нижняя панель**: 7 слотов армии + 4 кнопки построения

Ниже полные файлы для замены.

## 1. Полная замена: `res://scenes/ui/artifact_inventory_screen.tscn`

```tscn
// FILE: res://scenes/ui/artifact_inventory_screen.tscn
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/artifact_inventory_screen.gd" id="1"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_window"]
bg_color = Color(0.29, 0.204, 0.137, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.086, 0.063, 0.039, 1)

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_panel"]
bg_color = Color(0.29, 0.208, 0.141, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.141, 0.086, 0.031, 1)

[node name="ArtifactInventoryScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Dim" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color(0, 0, 0, 0.7)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Window" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(942, 640)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_window")

[node name="MainBox" type="VBoxContainer" parent="Center/Window"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Top" type="HBoxContainer" parent="Center/Window/MainBox"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Left" type="VBoxContainer" parent="Center/Window/MainBox/Top"]
custom_minimum_size = Vector2(412, 0)
layout_mode = 2
theme_override_constants/separation = 0

[node name="LeftPanel" type="PanelContainer" parent="Center/Window/MainBox/Top/Left"]
layout_mode = 2
size_flags_vertical = 3
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="LeftBox" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="HeroHead" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="Portrait" type="TextureRect" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/HeroHead"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="HeroName" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/HeroHead"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Name" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/HeroHead/HeroName"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 16
theme_override_colors/font_color = Color(0.94, 0.86, 0.68, 1)

[node name="Level" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/HeroHead/HeroName"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 12

[node name="Stats" type="GridContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox"]
layout_mode = 2
columns = 4
theme_override_constants/h_separation = 6

[node name="Attack" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="Label" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Attack"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 11

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Attack"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2
size_flags_horizontal = 4

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Attack/Icon"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 22
text = "⚔️"

[node name="Defense" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="Label" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Defense"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 11

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Defense"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2
size_flags_horizontal = 4

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Defense/Icon"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 22
text = "🛡️"

[node name="SpellPower" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="Label" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/SpellPower"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 11

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/SpellPower"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2
size_flags_horizontal = 4

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/SpellPower/Icon"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 22
text = "📖"

[node name="Knowledge" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="Label" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Knowledge"]
layout_mode = 2
horizontal_alignment = 1
theme_override_font_sizes/font_size = 11

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Knowledge"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2
size_flags_horizontal = 4

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Stats/Knowledge/Icon"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 22
text = "📚"

[node name="StatValues" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox"]
layout_mode = 2
theme_override_constants/separation = 0

[node name="Attack" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/StatValues"]
layout_mode = 2
size_flags_horizontal = 3
horizontal_alignment = 1
theme_override_font_sizes/font_size = 13

[node name="Defense" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/StatValues"]
layout_mode = 2
size_flags_horizontal = 3
horizontal_alignment = 1
theme_override_font_sizes/font_size = 13

[node name="SpellPower" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/StatValues"]
layout_mode = 2
size_flags_horizontal = 3
horizontal_alignment = 1
theme_override_font_sizes/font_size = 13

[node name="Knowledge" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/StatValues"]
layout_mode = 2
size_flags_horizontal = 3
horizontal_alignment = 1
theme_override_font_sizes/font_size = 13

[node name="Rows" type="VBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Row1" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon1" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1/Icon1"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "👁️"

[node name="Label1" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 12

[node name="Icon2" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1/Icon2"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "🦅"

[node name="Icon3" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row1/Icon3"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "☠️"

[node name="Row2" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon1" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2/Icon1"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "🎖️"

[node name="Label1" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 12

[node name="Icon2" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2/Icon2"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "📜"

[node name="Label2" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row2"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 12

[node name="Row3" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon1" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3/Icon1"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "🎺"

[node name="Label1" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 12

[node name="Icon2" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3"]
custom_minimum_size = Vector2(42, 42)
layout_mode = 2

[node name="IconLabel" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3/Icon2"]
layout_mode = 2
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
theme_override_font_sizes/font_size = 18
text = "🛡️"

[node name="Label2" type="Label" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Rows/Row3"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 12

[node name="Skills" type="GridContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox"]
layout_mode = 2
size_flags_vertical = 3
columns = 2
theme_override_constants/h_separation = 6
theme_override_constants/v_separation = 6

[node name="Skill0" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill0"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill0"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Skill1" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill1"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill1"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Skill2" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill2"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill2"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Skill3" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill3"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill3"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Skill4" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill4"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill4"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Skill5" type="HBoxContainer" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Icon" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill5"]
custom_minimum_size = Vector2(46, 46)
layout_mode = 2

[node name="Name" type="Panel" parent="Center/Window/MainBox/Top/Left/LeftPanel/LeftBox/Skills/Skill5"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Right" type="VBoxContainer" parent="Center/Window/MainBox/Top"]
layout_mode = 2
size_flags_horizontal = 3

[node name="RightPanel" type="PanelContainer" parent="Center/Window/MainBox/Top/Right"]
layout_mode = 2
size_flags_vertical = 3
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="RightBox" type="VBoxContainer" parent="Center/Window/MainBox/Top/Right/RightPanel"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="Doll" type="Control" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="Figure" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(240, 360)
layout_mode = 0
offset_left = 96.0
offset_top = 2.0
offset_right = 336.0
offset_bottom = 362.0
expand_mode = 1
stretch_mode = 5

[node name="Slot0" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 258.0
offset_top = 6.0
offset_right = 314.0
offset_bottom = 62.0
expand_mode = 1
stretch_mode = 5

[node name="Slot1" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 318.0
offset_top = 6.0
offset_right = 374.0
offset_bottom = 62.0
expand_mode = 1
stretch_mode = 5

[node name="Slot2" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 180.0
offset_top = 66.0
offset_right = 236.0
offset_bottom = 122.0
expand_mode = 1
stretch_mode = 5

[node name="Slot3" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 6.0
offset_top = 58.0
offset_right = 62.0
offset_bottom = 114.0
expand_mode = 1
stretch_mode = 5

[node name="Slot4" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 68.0
offset_top = 58.0
offset_right = 124.0
offset_bottom = 114.0
expand_mode = 1
stretch_mode = 5

[node name="Slot5" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 318.0
offset_top = 68.0
offset_right = 374.0
offset_bottom = 124.0
expand_mode = 1
stretch_mode = 5

[node name="Slot6" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 180.0
offset_top = 146.0
offset_right = 236.0
offset_bottom = 202.0
expand_mode = 1
stretch_mode = 5

[node name="Slot7" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 318.0
offset_top = 130.0
offset_right = 374.0
offset_bottom = 186.0
expand_mode = 1
stretch_mode = 5

[node name="Slot8" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 6.0
offset_top = 160.0
offset_right = 62.0
offset_bottom = 216.0
expand_mode = 1
stretch_mode = 5

[node name="Slot9" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 22.0
offset_top = 230.0
offset_right = 78.0
offset_bottom = 286.0
expand_mode = 1
stretch_mode = 5

[node name="Slot10" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 318.0
offset_top = 218.0
offset_right = 374.0
offset_bottom = 274.0
expand_mode = 1
stretch_mode = 5

[node name="Slot11" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 46.0
offset_top = 300.0
offset_right = 102.0
offset_bottom = 356.0
expand_mode = 1
stretch_mode = 5

[node name="Slot12" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 258.0
offset_top = 298.0
offset_right = 314.0
offset_bottom = 354.0
expand_mode = 1
stretch_mode = 5

[node name="Slot13" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 6.0
offset_top = 370.0
offset_right = 62.0
offset_bottom = 426.0
expand_mode = 1
stretch_mode = 5

[node name="Slot14" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 68.0
offset_top = 370.0
offset_right = 124.0
offset_bottom = 426.0
expand_mode = 1
stretch_mode = 5

[node name="Slot15" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 0
offset_left = 318.0
offset_top = 392.0
offset_right = 374.0
offset_bottom = 448.0
expand_mode = 1
stretch_mode = 5

[node name="Inventory" type="HBoxContainer" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 5

[node name="PrevButton" type="Button" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(22, 56)
layout_mode = 2
text = "◀"

[node name="InvSlot0" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="InvSlot1" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="InvSlot2" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="InvSlot3" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="InvSlot4" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="InvSlot5" type="TextureRect" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="NextButton" type="Button" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory"]
custom_minimum_size = Vector2(22, 56)
layout_mode = 2
text = "▶"

[node name="Actions" type="HBoxContainer" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10

[node name="SpellbookButton" type="Button" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Actions"]
custom_minimum_size = Vector2(58, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "📜"

[node name="ToolboxButton" type="Button" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Actions"]
custom_minimum_size = Vector2(58, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "🧰"

[node name="DisposeButton" type="Button" parent="Center/Window/MainBox/Top/Right/RightPanel/RightBox/Actions"]
custom_minimum_size = Vector2(58, 46)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "⊘"

[node name="Side" type="VBoxContainer" parent="Center/Window/MainBox/Top"]
custom_minimum_size = Vector2(80, 0)
layout_mode = 2
theme_override_constants/separation = 8

[node name="Banner" type="TextureRect" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 62)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="Mini" type="TextureRect" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 46)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="SideSlot0" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot1" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot2" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot3" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot4" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot5" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="SideSlot6" type="Panel" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 42)
layout_mode = 2

[node name="OkButton" type="Button" parent="Center/Window/MainBox/Top/Side"]
custom_minimum_size = Vector2(62, 46)
layout_mode = 2
size_flags_vertical = 10
theme_override_font_sizes/font_size = 26
text = "✓"

[node name="Bottom" type="HBoxContainer" parent="Center/Window/MainBox"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="ArmySlot0" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot1" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot2" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot3" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot4" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot5" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="ArmySlot6" type="TextureRect" parent="Center/Window/MainBox/Bottom"]
custom_minimum_size = Vector2(76, 76)
layout_mode = 2
expand_mode = 1
stretch_mode = 5

[node name="Formations" type="GridContainer" parent="Center/Window/MainBox/Bottom"]
layout_mode = 2
size_flags_horizontal = 10
columns = 2
theme_override_constants/h_separation = 5
theme_override_constants/v_separation = 5

[node name="Form0" type="Button" parent="Center/Window/MainBox/Bottom/Formations"]
custom_minimum_size = Vector2(64, 34)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "⚏"

[node name="Form1" type="Button" parent="Center/Window/MainBox/Bottom/Formations"]
custom_minimum_size = Vector2(64, 34)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "⚐"

[node name="Form2" type="Button" parent="Center/Window/MainBox/Bottom/Formations"]
custom_minimum_size = Vector2(64, 34)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "⚍"

[node name="Form3" type="Button" parent="Center/Window/MainBox/Bottom/Formations"]
custom_minimum_size = Vector2(64, 34)
layout_mode = 2
theme_override_font_sizes/font_size = 14
text = "⇄"
```

---

## 2. Полная замена: `res://scripts/ui/artifact_inventory_screen.gd`

```gdscript
// FILE: res://scripts/ui/artifact_inventory_screen.gd
extends Control
class_name ArtifactInventoryScreen

const SchoolType = preload("res://scripts/data/school_type.gd")

var _hero: HeroController = null
var _theme: Theme = null
var _tex_cache: Dictionary = {}
var bp_page := 0
var bp_slots: Array = []
var _selected_slot: Artifact.Slot = Artifact.Slot.WEAPON

const TEXT_GOLD := ThemeConfig.C_TEXT_GOLD_SOFT
const TEXT_LIGHT := ThemeConfig.C_TEXT_LIGHT_SOFT

const _STAT_ICON := {
	"attack": "⚔️",
	"defense": "🛡️",
	"spell_power": "📖",
	"knowledge": "📚",
}

const _DOLL_MAP := {
	Artifact.Slot.WEAPON: 0,
	Artifact.Slot.ARMOR: 6,
	Artifact.Slot.HELMET: 1,
	Artifact.Slot.SHIELD: 8,
	Artifact.Slot.BOOTS: 11,
	Artifact.Slot.GLOVES: 9,
	Artifact.Slot.RING: 12,
	Artifact.Slot.AMULET: 2,
	Artifact.Slot.CLOAK: 7,
	Artifact.Slot.BELT: 9,
}

func setup(hero: HeroController) -> void:
	_hero = hero
	_load_theme()
	_build_ui()
	_refresh()

func _load_theme() -> void:
	if _theme == null:
		_theme = load("res://assets/theme/game_theme.tres")

func _tex(path: String, w: int, h: int) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = load(path)
	if tex != null:
		_tex_cache[path] = tex
	return tex

func _artifact_icon(art: Artifact) -> String:
	if art == null:
		return ""
	var id: String = art.id
	var path := "res://assets/ui/artifacts/%s.png" % id
	if FileAccess.file_exists(path):
		return path
	return ""

func _build_ui() -> void:
	var left := get_node_or_null("Center/Window/MainBox/Top/Left/LeftPanel/LeftBox")
	if left == null:
		return
	var portrait := left.get_node_or_null("HeroHead/Portrait")
	if portrait is TextureRect:
		portrait.texture = _tex("res://assets/ui/hero/portrait.png", 80, 80)
	var name := left.get_node_or_null("HeroHead/HeroName/Name")
	if name is Label:
		name.text = _hero.hero_name if _hero else GameText.artifact_default_name()
	var level := left.get_node_or_null("HeroHead/HeroName/Level")
	if level is Label:
		level.text = "Уровень 1 Лорд"
	var stats := left.get_node_or_null("Stats")
	if stats != null:
		for key in _STAT_ICON:
			var label_node := stats.get_node_or_null("%s/Label" % key.capitalize())
			if label_node is Label:
				label_node.text = GameText.stat_label(key)
	var stat_values := left.get_node_or_null("StatValues")
	if stat_values != null:
		for key in ["Attack", "Defense", "SpellPower", "Knowledge"]:
			var val_node := stat_values.get_node_or_null(key)
			if val_node is Label:
				var snake_key := key.to_snake_case()
				val_node.text = str(_hero.stats.get(snake_key, 0) if _hero else 0)
	var rows := left.get_node_or_null("Rows")
	if rows != null:
		var row1_label := rows.get_node_or_null("Row1/Label1")
		if row1_label is Label:
			row1_label.text = "Специальность\nСозерцатели"
		var row2_label1 := rows.get_node_or_null("Row2/Label1")
		if row2_label1 is Label:
			row2_label1.text = "Опыт\n34"
		var row2_label2 := rows.get_node_or_null("Row2/Label2")
		if row2_label2 is Label:
			row2_label2.text = "Мана\n10/10"
		var row3_label1 := rows.get_node_or_null("Row3/Label1")
		if row3_label1 is Label:
			row3_label1.text = "Основной\nЛидерство"
		var row3_label2 := rows.get_node_or_null("Row3/Label2")
		if row3_label2 is Label:
			row3_label2.text = "Основной\nСопротивление"
	_build_right()
	_build_side()
	_build_bottom()

func _build_right() -> void:
	var right := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox")
	if right == null:
		return
	var figure := right.get_node_or_null("Doll/Figure")
	if figure is TextureRect:
		figure.texture = _tex("res://assets/ui/hero/figure.png", 240, 360)
	_rebuild_equipped()
	_refresh_backpack()
	var inv := right.get_node_or_null("Inventory")
	if inv != null:
		var prev_btn := inv.get_node_or_null("PrevButton")
		var next_btn := inv.get_node_or_null("NextButton")
		if prev_btn is Button:
			prev_btn.pressed.connect(func(): bp_page = maxi(0, bp_page - 1); _refresh_backpack())
		if next_btn is Button:
			next_btn.pressed.connect(func(): bp_page += 1; _refresh_backpack())
	var actions := right.get_node_or_null("Actions")
	if actions != null:
		var spellbook_btn := actions.get_node_or_null("SpellbookButton")
		var toolbox_btn := actions.get_node_or_null("ToolboxButton")
		var dispose_btn := actions.get_node_or_null("DisposeButton")
		if spellbook_btn is Button:
			spellbook_btn.pressed.connect(func(): GameLogger.hero("Spellbook opened"))
		if toolbox_btn is Button:
			toolbox_btn.pressed.connect(func(): GameLogger.hero("Toolbox opened"))
		if dispose_btn is Button:
			dispose_btn.pressed.connect(func(): GameLogger.hero("Dispose mode"))

func _build_side() -> void:
	var side := get_node_or_null("Center/Window/MainBox/Top/Side")
	if side == null:
		return
	var banner := side.get_node_or_null("Banner")
	if banner is TextureRect:
		banner.texture = _tex("res://assets/ui/hero/banner.png", 62, 62)
	var mini := side.get_node_or_null("Mini")
	if mini is TextureRect:
		mini.texture = _tex("res://assets/ui/hero/portrait.png", 62, 46)
	var ok_btn := side.get_node_or_null("OkButton")
	if ok_btn is Button:
		ok_btn.pressed.connect(func(): visible = false)

func _build_bottom() -> void:
	var bottom := get_node_or_null("Center/Window/MainBox/Bottom")
	if bottom == null:
		return
	if _hero == null:
		return
	var army: HeroArmyController = _hero.army
	for i in 7:
		var slot := bottom.get_node_or_null("ArmySlot_%d" % i)
		if slot is TextureRect:
			if army != null and i < army.get_stack_count():
				var stack = army.get_stack(i)
				if stack != null:
					slot.texture = _tex("res://assets/ui/units/%s.png" % stack.unit_type, 76, 76)
	var formations := bottom.get_node_or_null("Formations")
	if formations != null:
		for i in 4:
			var btn := formations.get_node_or_null("Form_%d" % i)
			if btn is Button:
				btn.add_theme_color_override("font_color", TEXT_GOLD)
				btn.add_theme_color_override("font_pressed_color", TEXT_LIGHT)

func _refresh() -> void:
	if _hero == null:
		return
	_rebuild_equipped()
	_refresh_backpack()

func _rebuild_equipped() -> void:
	if _hero == null:
		return
	var eq: HeroInventory = _hero.inventory
	var shown := {}
	for slot in eq.equipped.keys():
		var art: Artifact = eq.equipped[slot]
		if art == null:
			continue
		var idx: int = _DOLL_MAP.get(slot, -1)
		if idx < 0 or idx >= 16:
			continue
		var icon_path := _artifact_icon(art)
		if icon_path.is_empty():
			continue
		var ov := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll/Slot_%d" % idx)
		if ov is TextureRect:
			ov.texture = _tex(icon_path, 56, 56)
			ov.visible = true
			shown[idx] = true
	for i in 16:
		if shown.has(i):
			continue
		var ov := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll/Slot_%d" % i)
		if ov is TextureRect:
			ov.visible = false

func _refresh_backpack() -> void:
	if _hero == null:
		return
	var inv: HeroInventory = _hero.inventory
	bp_slots = inv.backpack.duplicate()
	var page_size := 6
	var start := bp_page * page_size
	var end := mini(bp_slots.size(), start + page_size)
	for i in 6:
		var slot_node := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory/InvSlot_%d" % i)
		if slot_node is TextureRect:
			var idx := start + i
			if idx < end:
				var art: Artifact = bp_slots[idx]
				var icon_path := _artifact_icon(art)
				if icon_path.is_empty():
					slot_node.texture = null
				else:
					slot_node.texture = _tex(icon_path, 56, 56)
				slot_node.visible = true
			else:
				slot_node.texture = null
				slot_node.visible = true
	var prev_btn := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory/PrevButton")
	var next_btn := get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory/NextButton")
	if prev_btn is Button:
		prev_btn.disabled = (bp_page == 0)
	if next_btn is Button:
		next_btn.disabled = ((bp_page + 1) * page_size >= bp_slots.size())
```

---

## 3. Тест: `res://tests/unit/ui/test_artifact_inventory_screen.gd`

```gdscript
// FILE: res://tests/unit/ui/test_artifact_inventory_screen.gd
extends BaseTest
const _Scene := preload("res://scenes/ui/artifact_inventory_screen.tscn")
var _screen: Node = null

func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
		_screen = null

func test_artifact_inventory_screen_structure() -> void:
	_screen = _Scene.instantiate()
	get_tree().root.add_child(_screen)
	var left := _screen.get_node_or_null("Center/Window/MainBox/Top/Left/LeftPanel/LeftBox")
	assert_that(left).is_not_null()
	var right := _screen.get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox")
	assert_that(right).is_not_null()
	var side := _screen.get_node_or_null("Center/Window/MainBox/Top/Side")
	assert_that(side).is_not_null()
	var bottom := _screen.get_node_or_null("Center/Window/MainBox/Bottom")
	assert_that(bottom).is_not_null()

func test_artifact_inventory_screen_doll_slots() -> void:
	_screen = _Scene.instantiate()
	get_tree().root.add_child(_screen)
	var doll := _screen.get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Doll")
	assert_that(doll).is_not_null()
	for i in 16:
		var slot := doll.get_node_or_null("Slot_%d" % i)
		assert_that(slot).is_not_null()
		assert_that(slot.custom_minimum_size).is_equal(Vector2(56, 56))

func test_artifact_inventory_screen_inventory_pagination() -> void:
	_screen = _Scene.instantiate()
	get_tree().root.add_child(_screen)
	var inv := _screen.get_node_or_null("Center/Window/MainBox/Top/Right/RightPanel/RightBox/Inventory")
	assert_that(inv).is_not_null()
	var prev := inv.get_node_or_null("PrevButton")
	var next := inv.get_node_or_null("NextButton")
	assert_that(prev).is_not_null()
	assert_that(next).is_not_null()
	for i in 6:
		var slot := inv.get_node_or_null("InvSlot_%d" % i)
		assert_that(slot).is_not_null()
		assert_that(slot.custom_minimum_size).is_equal(Vector2(56, 56))
```

---

## Runbook

1. Заменить `res://scenes/ui/artifact_inventory_screen.tscn` (полная перезапись).
2. Заменить `res://scripts/ui/artifact_inventory_screen.gd` (полная перезапись).
3. Создать `res://tests/unit/ui/test_artifact_inventory_screen.gd`.
4. Прогон тестов:
```bash
godot --headless --path ./game -s res://addons/gdunit4/bin/GdUnitCmdTool.gd --add res://tests/unit/ui/test_artifact_inventory_screen.gd
```
5. Критерии приёмки:
- Окно 942×640, три колонки (левая 412px, правая flex, боковая 80px) + нижняя панель армии.
- 16 слотов экипировки вокруг куклы 240×360 с абсолютным позиционированием по прототипу.
- Инвентарь 6 слотов со стрелками ◀▶ (пагинация работает, кнопки disabled на границах).
- 3 кнопки действий (📜 🧰 ⊘) под инвентарём.
- Боковая колонка: баннер 62×62, мини-портрет 62×46, 7 side-slot 62×42, OK (✓) внизу.
- Армия: 7 слотов 76×76 + 4 кнопки построения 64×34 справа.