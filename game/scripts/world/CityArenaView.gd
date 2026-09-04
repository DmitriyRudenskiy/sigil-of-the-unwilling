class_name CityArenaView
extends Node2D
## Арена строительства (M3): интерактивная песочница на CityArenaModel.
##
## Игрок строит здания/районы по клеткам (клик после выбора в палитре),
## крутит ходы (кнопка или авто), наблюдает за едой, доходом, уровнем
## и итоговым score. Тонирование колец — CityArenaModel.ring_color().
##
## UI строится кодом (без ассетов): Polygon2D-гексы + Area2D-кликеры
## (Polygon2D не принимает ввод — ввод идёт через CollisionObject2D)
## + CanvasLayer.


const HEX_SIZE := 26.0
const SQRT3: float = 1.7320508

## Порядок палитры: [id, эмодзи, подпись].
const PALETTE: Array = [
	[&"farm", "🌾", "Ферма"],
	[&"mill", "🌀", "Мельница"],
	[&"bakery", "🍞", "Пекарня"],
	[&"mine", "⛏", "Рудник"],
	[&"smithy", "⚒", "Кузница"],
	[&"tavern", "🍺", "Таверна"],
	[&"school", "📚", "Училище"],
	[&"trade_post", "⚖", "Торговый пост"],
	[&"market", "🏪", "Рынок"],
	[&"shack", "🛖", "Хижина"],
	[&"walls", "🧱", "Стены"],
	[&"district", "🏘", "Район"],
]


var _city: City = null
var _turn := 0
var _starve_days := 0
var _selected: StringName = &""
var _auto := false


var _hex_layer: Node2D = null
var _camera: Camera2D = null
var _ui: CanvasLayer = null
var _top_hud: Label = null
var _score_hud: Label = null
var _log_hud: Label = null
var _tooltip: Label = null
var _auto_btn: Button = null
var _timer: Timer = null
## Живые узлы клеток: cell -> {"poly", "mark", "ylab"}.
## Создаются один раз, при refresh только обновляются свойства
## (иначе в авто-режиме каждый тик аллоцируются ~550 узлов).
var _cell_nodes: Dictionary = {}


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)

	_hex_layer = Node2D.new()
	_hex_layer.name = "HexLayer"
	add_child(_hex_layer)

	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	_build_ui()

	get_viewport().size_changed.connect(_fit_camera)
	_new_game()
	_fit_camera()


func _new_game() -> void:
	_city = CityArenaModel.make_city()
	_turn = 0
	_starve_days = 0
	_selected = &""
	_stop_auto()
	_log("Город основан. Выберите здание в палитре и кликните по клетке.")
	_build_cells()
	_refresh()


## ==================== ГЕОМЕТРИЯ ====================

func _hex_to_pixel(cell: Vector2i) -> Vector2:
	## Pointy-top, odd-row shift (как HexUtils).
	var x: float = HEX_SIZE * SQRT3 * (float(cell.x) + 0.5 * (cell.y & 1))
	var y: float = HEX_SIZE * 1.5 * float(cell.y)
	return Vector2(x, y)


static func _hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var ang: float = PI / 180.0 * (60.0 * float(i) - 30.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * size)
	return pts


func _ring_color(ring: int) -> Color:
	return CityArenaModel.ring_color(ring)


func _building_emoji(id: StringName) -> String:
	match id:
		&"farm": return "🌾"
		&"mill": return "🌀"
		&"bakery": return "🍞"
		&"mine": return "⛏"
		&"smithy": return "⚒"
		&"tavern": return "🍺"
		&"school": return "📚"
		&"trade_post": return "⚖"
		&"market": return "🏪"
		&"shack": return "🛖"
		&"walls": return "🧱"
		&"district": return "🏘"
		_: return "❓"


func _ring_yield_short(ring: int) -> String:
	var y: Dictionary = ArenaBalance.ring_yield(ring)
	var food: float = float(y.get(&"food", 0.0))
	var ind: float = float(y.get(&"industry", 0.0))
	var parts: Array[String] = []
	if food > 0.0:
		parts.append("🌾" + ("%.1f" % food))
	if ind > 0.0:
		parts.append("🏭" + ("%.1f" % ind))
	return ", ".join(parts)


## Район на клетке (City не хранит карту районов — ищем по списку).
func _borough_at(cv: Vector2i) -> Borough:
	if _city == null:
		return null
	for b in _city.boroughs:
		if b.cell == cv:
			return b
	return null


func _cell_mark(cv: Vector2i) -> String:
	var b: UniqueBuilding = _city.get_building_at(cv)
	if b != null and b.def != null:
		var mark: String = _building_emoji(b.def.id)
		if b.level > 1:
			mark += str(b.level)
		return mark
	var bo: Borough = _borough_at(cv)
	if bo != null:
		var mark: String = "🏘"
		if bo.level > 1:
			mark += str(bo.level)
		return mark
	return ""


## ==================== ОТРИСОВКА ====================

## Создаёт узлы всех клеток арены (один раз на игру).
func _build_cells() -> void:
	for c in _hex_layer.get_children():
		c.queue_free()
	_cell_nodes.clear()
	var cells: Array = CityArenaModel.cells_in_arena()
	for cell in cells:
		var cv: Vector2i = cell
		var ring: int = CityArenaModel.ring_of(cv)
		var pos: Vector2 = _hex_to_pixel(cv)

		# Группа клетки (координаты относительно её центра).
		var group := Node2D.new()
		group.position = pos
		_hex_layer.add_child(group)

		# Визуальный гекс.
		var poly := Polygon2D.new()
		poly.polygon = _hex_corners(Vector2.ZERO, HEX_SIZE - 1.0)
		poly.color = _ring_color(ring)
		poly.z_index = 1
		group.add_child(poly)

		# Кликер: Polygon2D не принимает ввод, поэтому отдельная Area2D
		# с тем же полигоном (input_event / mouse_entered / mouse_exited).
		var area := Area2D.new()
		var cp := CollisionPolygon2D.new()
		cp.polygon = _hex_corners(Vector2.ZERO, HEX_SIZE - 1.0)
		area.add_child(cp)
		area.input_pickable = true
		area.input_event.connect(_on_cell_input.bind(cv))
		area.mouse_entered.connect(_on_cell_entered.bind(cv))
		area.mouse_exited.connect(_on_cell_exited)
		group.add_child(area)

		# Подпись клетки (эмодзи здания / 🏰 центр).
		var label := Label.new()
		label.position = Vector2(-HEX_SIZE, -HEX_SIZE * 0.72)
		label.size = Vector2(HEX_SIZE * 2.0, HEX_SIZE * 1.4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 2
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		if ring == 0:
			label.text = "🏰"
			label.add_theme_font_size_override("font_size", 18)
		else:
			label.text = ""
			label.add_theme_font_size_override("font_size", 13)
		group.add_child(label)

		# Выходы кольца мелким текстом (нет у центра).
		var ylab: Label = null
		if ring > 0:
			ylab = Label.new()
			ylab.position = Vector2(-HEX_SIZE, HEX_SIZE * 0.18)
			ylab.size = Vector2(HEX_SIZE * 2.0, 14)
			ylab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ylab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ylab.z_index = 2
			ylab.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
			ylab.add_theme_font_size_override("font_size", 8)
			ylab.text = _ring_yield_short(ring)
			group.add_child(ylab)

		# Глиф особенности клетки (карьер/родник/река/руины, кольца 2..4).
		var feat: Label = null
		var feat_id: StringName = CityArenaModel.cell_feature(_city, cv)
		if feat_id != &"":
			feat = Label.new()
			feat.position = Vector2(-HEX_SIZE, -HEX_SIZE * 1.14)
			feat.size = Vector2(HEX_SIZE * 2.0, 12)
			feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			feat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			feat.z_index = 2
			feat.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
			feat.add_theme_font_size_override("font_size", 9)
			feat.text = CityArenaModel.feature_glyph(feat_id)
			group.add_child(feat)

		# Бейдж кластера (первая клетка связки ≥4 зданий одного типа).
		var badge := Label.new()
		badge.position = Vector2(HEX_SIZE * 0.15, -HEX_SIZE * 1.10)
		badge.size = Vector2(HEX_SIZE * 0.85, 12)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.z_index = 2
		badge.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
		badge.add_theme_font_size_override("font_size", 9)
		badge.text = ""
		group.add_child(badge)

		_cell_nodes[cv] = {"poly": poly, "mark": label, "ylab": ylab,
			"feat": feat, "badge": badge}


## Обновляет цвета/подписи живых узлов (вызывается на каждый refresh).
## Клетки кластера подсвечиваются ярче, на первой клетке — бейдж ⚡×N.
func _draw_arena() -> void:
	if _city == null:
		return
	var clu: Dictionary = CityArenaModel.cluster_uids(_city)
	var firsts: Dictionary = {}
	for cl in CityArenaModel.clusters(_city):
		var cells: Array = (cl as Dictionary)["cells"]
		firsts[cells[0]] = "⚡×%d" % cells.size()
	for cv in _cell_nodes:
		var n: Dictionary = _cell_nodes[cv]
		var ring: int = CityArenaModel.ring_of(cv)
		var poly: Polygon2D = n["poly"]
		var b: UniqueBuilding = _city.get_building_at(cv)
		var in_cluster: bool = b != null and clu.has(b.uid)
		if _city.cell_is_built(cv):
			poly.color = _ring_color(ring).darkened(0.22 if in_cluster else 0.45)
		else:
			poly.color = _ring_color(ring)
		var mark: Label = n["mark"]
		if ring > 0:
			mark.text = _cell_mark(cv)
		var ylab: Label = n["ylab"]
		if ylab != null:
			ylab.text = _ring_yield_short(ring)
		var badge: Label = n["badge"]
		if badge != null:
			badge.text = str(firsts.get(cv, ""))


## Сигнал Area2D.input_event(viewport, event, shape_idx, pos, normal) —
## порядок аргументов Godot 4. `cv` подставляется через .bind() (последний аргумент).
func _on_cell_input(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2, normal: Vector2,
		cv: Vector2i) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_cell_click(cv)


func _on_cell_entered(cv: Vector2i) -> void:
	_show_tooltip(cv)


func _on_cell_exited() -> void:
	if _tooltip != null:
		_tooltip.visible = false


## ==================== UI ====================

func _build_ui() -> void:
	# Верхний HUD.
	var top := HBoxContainer.new()
	top.position = Vector2(16, 10)
	_ui.add_child(top)
	_top_hud = Label.new()
	_top_hud.add_theme_font_size_override("font_size", 15)
	_top_hud.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	top.add_child(_top_hud)
	_score_hud = Label.new()
	_score_hud.add_theme_font_size_override("font_size", 15)
	_score_hud.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_score_hud.position = Vector2(620, 0)
	_ui.add_child(_score_hud)

	# Палитра слева.
	var palette := VBoxContainer.new()
	palette.position = Vector2(10, 60)
	palette.add_theme_constant_override("separation", 4)
	_ui.add_child(palette)
	var title := Label.new()
	title.text = "Палитра (клик — выбор, повторный клик — снять)"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title.custom_minimum_size = Vector2(190, 0)
	palette.add_child(title)
	for row in PALETTE:
		var id: StringName = row[0]
		var emoji: String = row[1]
		var name: String = row[2]
		var cost: String = _cost_label(id)
		var btn := Button.new()
		btn.text = "%s %s %s" % [emoji, name, cost]
		btn.custom_minimum_size = Vector2(190, 30)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_palette_pressed.bind(id))
		palette.add_child(btn)

	# Кнопки действий внизу.
	var bar := HBoxContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -54.0
	bar.offset_left = 0.0
	bar.add_theme_constant_override("separation", 8)
	_ui.add_child(bar)
	bar.add_child(_make_action_btn("⏭ Ход", _on_turn_pressed))
	_auto_btn = _make_action_btn("▶ Авто", _on_auto_pressed)
	bar.add_child(_auto_btn)
	bar.add_child(_make_action_btn("🧑‍🌾 Нанять", _on_hire_pressed))
	bar.add_child(_make_action_btn("🏛 Уровень", _on_level_pressed))
	bar.add_child(_make_action_btn("↺ Заново", _on_reset_pressed))
	bar.add_child(_make_action_btn("⌂ Меню", _on_menu_pressed))

	# Журнал.
	_log_hud = Label.new()
	_log_hud.anchor_top = 1.0
	_log_hud.anchor_bottom = 1.0
	_log_hud.offset_top = -100.0
	_log_hud.offset_left = 16.0
	_log_hud.add_theme_font_size_override("font_size", 13)
	_log_hud.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_ui.add_child(_log_hud)

	# Тултип.
	_tooltip = Label.new()
	_tooltip.anchor_top = 1.0
	_tooltip.anchor_bottom = 1.0
	_tooltip.anchor_left = 0.5
	_tooltip.anchor_right = 0.5
	_tooltip.offset_top = -12.0
	_tooltip.offset_left = -400.0
	_tooltip.offset_right = 400.0
	_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip.add_theme_font_size_override("font_size", 12)
	_tooltip.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	_tooltip.visible = false
	_ui.add_child(_tooltip)

	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.timeout.connect(_on_auto_tick)
	add_child(_timer)


func _make_action_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(cb)
	return btn


func _cost_label(id: StringName) -> String:
	if id == &"district":
		return "(район)"
	var def: UniqueBuilding.Def = BuildingDefs.def_by_id(id)
	if def == null or def.levels.is_empty():
		return ""
	var req: UniqueBuilding.LevelReq = def.levels[0]
	return "(%d)" % int(req.industry)


## ==================== ВЗАИМОДЕЙСТВИЕ ====================

func _on_palette_pressed(id: StringName) -> void:
	_selected = &"" if _selected == id else id
	_log("Выбрано: " + _selection_name())
	_draw_arena()


func _selection_name() -> String:
	if _selected == &"":
		return "ничего (клик по зданию — апгрейд)"
	for row in PALETTE:
		if row[0] == _selected:
			return "%s %s" % [row[1], row[2]]
	return str(_selected)


func _handle_cell_click(cv: Vector2i) -> void:
	if _city == null:
		return
	if CityArenaModel.ring_of(cv) == 0:
		_log("Это центр города.")
		return
	if _city.cell_is_built(cv):
		_try_upgrade(cv)
		return
	if _selected == &"":
		_log("Сначала выберите здание в палитре (или кликните по построенному — апгрейд).")
		return
	if _selected == &"district":
		var can: Dictionary = _city.can_build_borough(cv)
		if bool(can.get("ok", false)):
			var ok: bool = _city.build_borough(cv)
			_log("Район: " + ("построен" if ok else "не построен"))
		else:
			_log("Район: %s" % str(can.get("reason", "")))
		_refresh()
		return
	var def: UniqueBuilding.Def = BuildingDefs.def_by_id(_selected)
	if def == null:
		return
	var res: Dictionary = CityArenaModel.place_building(_city, def, cv)
	if bool(res.get("ok", false)):
		var ruins: String = ""
		if res.has("ruins_gold"):
			ruins = " (руины: +%.0f 🪙)" % float(res.get("ruins_gold", 0.0))
		_log("Построено: %s (−%d промышленности)%s" % [
			def.display_name, int(res.get("cost", 0.0)), ruins])
	else:
		_log("Не построено: %s" % str(res.get("reason", "")))
	_refresh()


func _try_upgrade(cv: Vector2i) -> void:
	var b: UniqueBuilding = _city.get_building_at(cv)
	if b == null:
		var bo: Borough = _borough_at(cv)
		if bo != null:
			_log("Район уровня %d: даёт одобрение и распахивает соседние клетки." % bo.level)
		return
	var can: Dictionary = _city.can_upgrade_building(b)
	if bool(can.get("ok", false)) and _city.perform_upgrade(b):
		_log("Апгрейд: %s → ур. %d" % [b.def.display_name, b.level])
	else:
		_log("Апгрейд не удался: %s" % str(can.get("reason", "не хватает ресурсов")))
	_refresh()


func _show_tooltip(cv: Vector2i) -> void:
	if _tooltip == null or _city == null:
		return
	var ring: int = CityArenaModel.ring_of(cv)
	var lines: Array[String] = ["Клетка (%d, %d), кольцо %d" % [cv.x, cv.y, ring]]
	if ring > 0:
		var y: Dictionary = ArenaBalance.ring_yield(ring)
		var parts: Array[String] = []
		for k in [&"food", &"industry", &"dust", &"science", &"influence"]:
			var v: float = float(y.get(k, 0.0))
			if v > 0.0:
				parts.append(str(k) + " " + ("%.1f" % v))
		lines.append("Выходы кольца: " + (", ".join(parts) if not parts.is_empty() else "—"))
	var f: StringName = CityArenaModel.cell_feature(_city, cv)
	if f != &"":
		lines.append(CityArenaModel.feature_name(f))
	var b: UniqueBuilding = _city.get_building_at(cv)
	if b != null and b.def != null:
		var ring_bonus: float = 1.0 + ArenaBalance.ring_bonus(b.def.id, ring)
		var total: float = CityArenaModel.building_mult(_city, b)
		var in_cluster: bool = CityArenaModel.cluster_uids(_city).has(b.uid)
		var cluster_note: String = " (кластер ×4)" if in_cluster else ""
		lines.append("%s ур.%d — кольцо ×%.2f, суммарно ×%.2f%s, рабочих: %d" % [
			b.def.display_name, b.level, ring_bonus, total, cluster_note,
			b.assigned_workers])
	var bo: Borough = _borough_at(cv)
	if bo != null:
		lines.append("Район ур.%d — одобрение %d, клетки-соседи в обороте" % [
			bo.level, bo.net_approval()])
	_tooltip.text = "   |   ".join(lines)
	_tooltip.visible = true


## ==================== ХОДЫ ====================

func _on_turn_pressed() -> void:
	_advance_turn()


func _on_auto_tick() -> void:
	_advance_turn()


func _on_auto_pressed() -> void:
	if _auto:
		_stop_auto()
	else:
		_auto = true
		_auto_btn.text = "⏸ Стоп"
		_timer.start()
		_log("Авто-режим: 1 ход / 0.3 с")


func _stop_auto() -> void:
	_auto = false
	if _timer != null:
		_timer.stop()
	if _auto_btn != null:
		_auto_btn.text = "▶ Авто"


func _advance_turn() -> void:
	if _city == null:
		return
	_turn += 1
	var rep: Dictionary = CityArenaModel.run_turn(_city, _turn)
	if _city.starving:
		_starve_days += 1
	var net: float = float(rep.get("net_food", 0.0))
	var food: float = _city.food_stockpile
	var warn: String = ""
	if bool(rep.get("storm", false)):
		var pm: float = CityArenaModel.storm_production_mult(_city, _turn)
		var sm: String = "  🌪 ШТОРМ: производство ×%.2f, еда −%.1f (стены ур.2 смягчают)" % [
			pm, float(rep.get("storm_food", 0.0))]
		warn = sm + warn
	if _city.starving:
		warn = "  ⚠ ГОЛОД (день %d)" % _starve_days + warn
	var clusters: int = int(rep.get("clusters", 0))
	var cl_note: String = "   ⚡кластеры: %d" % clusters if clusters > 0 else ""
	_log("Ход %d: еда %.0f (нетто %+.1f), процв. %.0f, уровень %d%s%s" % [
		_turn, food, net, _city.prosperity, _city.level, warn, cl_note])
	_refresh()


func _on_hire_pressed() -> void:
	var n: int = CityArenaModel.hire_worker(_city)
	if n > 0:
		_log("Нанят работник (население %d)." % _city.pop_total())
	else:
		_log("Нанять некого: нет рабочих мест или жилья.")
	_refresh()


func _on_level_pressed() -> void:
	var can: Dictionary = ProsperitySystem.can_level_up(_city)
	if bool(can.get("ok", false)):
		if ProsperitySystem.try_level_up(_city):
			_log("Город → уровень %d! Радиус застройки %d." % [
				_city.level, _city.building_max_distance()])
	else:
		var reasons: Array[String] = []
		for r in can.get("reasons", []):
			reasons.append(str(r))
		_log("Уровень: " + ", ".join(reasons))
	_refresh()


func _on_reset_pressed() -> void:
	_new_game()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _log(msg: String) -> void:
	if _log_hud != null:
		_log_hud.text = msg


## ==================== HUD / КАМЕРА ====================

func _refresh() -> void:
	if _city == null:
		return
	_draw_arena()
	var food: float = _city.food_stockpile
	var industry: float = float(_city.storage.get(&"industry", 0.0))
	var gold: float = float(_city.storage.get(&"gold", 0.0))
	var net: float = _city.net_food()
	var storm_mark: String = "   🌪 ШТОРМ" if CityArenaModel.is_storm_turn(_turn) else ""
	var clusters: int = (CityArenaModel.clusters(_city) as Array).size()
	var cluster_mark: String = "   ⚡×4: %d" % clusters if clusters > 0 else ""
	_top_hud.text = "Ход: %d   🌾 %.0f (нетто %+.1f)   🏭 %.0f   🪙 %.0f   👥 %d   ★ %.0f   Уровень %d%s%s" % [
		_turn, food, net, industry, gold, _city.pop_total(),
		_city.prosperity, _city.level, storm_mark, cluster_mark]
	var score: float = CityArenaModel.score(_city, _starve_days)
	_score_hud.text = "Score: %.0f" % score


func _fit_camera() -> void:
	if _camera == null:
		return
	var cells: Array = CityArenaModel.cells_in_arena()
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	for cell in cells:
		var p: Vector2 = _hex_to_pixel(cell as Vector2i)
		minv = minv.min(p)
		maxv = maxv.max(p)
	var world_size: Vector2 = (maxv - minv) + Vector2(HEX_SIZE * 3.0, HEX_SIZE * 3.0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Оставляем место под левую палитру (~210 px) и нижнюю панель.
	var avail: Vector2 = Vector2(maxf(300.0, vp.x - 230.0), maxf(300.0, vp.y - 140.0))
	var zoom: float = minf(avail.x / world_size.x, avail.y / world_size.y)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = Vector2((minv.x + maxv.x) * 0.5 + 115.0 / maxf(zoom, 0.05),
		(minv.y + maxv.y) * 0.5)
