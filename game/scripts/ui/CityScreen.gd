class_name CityScreen
extends Control
## city-in-world: экран управления городом мира (списочный формат).
##
## Полный-рект Control (mouse_filter = STOP) — глотает клики по карте.
## Хост — WorldUIManager (CanvasLayer.layer = 40, выше WorldUI 30);
## камера мира не трогается, оверлей рисуется поверх на своём слое.
## Headless-safe: создаётся всегда (сокет-сценарии управляют городом
## без дисплея).
##
## Кнопки: построить ферму, построить шахту, улучшить (уровень города),
## нанять последователя, закрыть. Все действия мутируют РЕАЛЬНЫЙ City
## (persist через City.serialize — без дублирования состояния в UI).

signal close_requested
signal state_changed

var city: City = null
var hero: HeroController = null
var hero_cell: Vector2i = Vector2i(-1, -1)
var rng: RandomNumberGenerator = null
## Границы карты для подбора клетки постройки (City.first_free_build_cell):
## (0, 0) — без ограничений.
var map_bounds: Vector2i = Vector2i.ZERO

var _bg: Panel
var _stats_label: Label
var _buildings_label: Label
var _title_label: Label
var _message_label: Label
var _opened := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg = Panel.new()
	_bg.name = "CityScreenBackground"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var center := CenterContainer.new()
	center.name = "CityScreenCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_bg.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "CityScreenPanel"
	panel.custom_minimum_size = Vector2(560.0, 420.0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "CityScreenBox"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.name = "CityScreenTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.name = "CityScreenStats"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats_label)

	_buildings_label = Label.new()
	_buildings_label.name = "CityScreenBuildings"
	_buildings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buildings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_buildings_label)

	var buttons := HBoxContainer.new()
	buttons.name = "CityScreenButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)

	buttons.add_child(_make_button("BuildFarm", "🌾 Построить ферму", _on_build_farm_pressed))
	buttons.add_child(_make_button("BuildMine", "⛏️ Построить шахту", _on_build_mine_pressed))
	buttons.add_child(_make_button("LevelUp", "⬆️ Улучшить", _on_level_up_pressed))
	buttons.add_child(_make_button("Hire", "👤 Нанять", _on_hire_pressed))
	buttons.add_child(_make_button("Close", "✕ Выход из города", _on_close_pressed))

	_message_label = Label.new()
	_message_label.name = "CityScreenMessage"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message_label)


func _make_button(node_name: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.pressed.connect(cb)
	return b


## Привязка к городу (пере-привязка при смене города).
func setup(c: City, h: HeroController, h_cell: Vector2i,
		r: RandomNumberGenerator = null, m_bounds: Vector2i = Vector2i.ZERO) -> void:
	city = c
	hero = h
	hero_cell = h_cell
	rng = r
	map_bounds = m_bounds
	_message_label.text = ""
	refresh()


func open() -> void:
	if city == null:
		return
	if not _opened:
		_opened = true
		visible = true
	refresh()
	state_changed.emit()


func close() -> void:
	if not _opened:
		return
	_opened = false
	visible = false
	state_changed.emit()


func is_open() -> bool:
	return _opened


## Перерисовать из текущего состояния города (после внешних мутаций).
func refresh() -> void:
	if city == null or not is_instance_valid(city):
		return
	_title_label.text = "%s — уровень %d" % [city.display_name, city.level]

	var lines: Array[String] = []
	lines.append("👥 Население: %d (свободные последователи: %d)" % [city.pop_capped(), city.free_followers()])
	lines.append("🌾 Еда: %.0f (нетто %+.1f в ход)" % [city.food_stockpile, city.net_food()])
	lines.append("🏭 Промышленность: %.0f   🪙 Золото: %.0f" % [_storage_industry(), _gold()])
	lines.append("⭐ Процветание: %.0f   💠 Репутация: %d" % [city.prosperity, city.reputation])
	_stats_label.text = "\n".join(lines)

	var b_lines: Array[String] = []
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		b_lines.append("• %s, ур. %d, клетка (%d, %d)" % [b.def.display_name, b.level, b.cell.x, b.cell.y])
	_buildings_label.text = "Здания:\n" + "\n".join(b_lines) if not b_lines.is_empty() else "Здания: (нет)"
	if _message_label.text == "":
		_message_label.text = "Экран управления городом. Esc — закрыть."


# ==================== ДЕЙСТВИЯ ====================
## Кнопки и сокет-сценарии (CITY_BUILD/CITY_LEVEL/CITY_HIRE) ходят через ОДИН
## и тот же код: публичные методы возвращают результат (Dictionary) и
## обновляют подпись статуса.

func _on_build_farm_pressed() -> void:
	build_pressed(&"farm")


func _on_build_mine_pressed() -> void:
	build_pressed(&"mine")


func _on_level_up_pressed() -> void:
	level_up_pressed()


func _on_hire_pressed() -> void:
	hire_pressed()


## Построить здание (авто-подбор свободной клетки в радиусе города).
func build_pressed(def_id: StringName) -> Dictionary:
	if city == null:
		return _fail("Город не привязан")
	var def := BuildingDefs.def_by_id(def_id)
	if def == null:
		return _fail("Здание не найдено: %s" % str(def_id))
	var cell := city.first_free_build_cell(def, map_bounds)
	if cell == Vector2i(-1, -1):
		return _fail("Нет свободной клетки под постройку")
	var check: Dictionary = city.can_build_building(def, cell)
	if not bool(check.get("ok", false)):
		return _fail("Нельзя построить: %s" % str(check.get("reason", "?")))
	var bld := city.build_building(def, cell)
	if bld == null:
		return _fail("Построить не удалось")
	_set_message("Построено: %s (%d, %d). Расход: %s" % [
		def.display_name, cell.x, cell.y, _format_cost(def)])
	refresh()
	return {"ok": true, "building": String(def_id), "level": bld.level,
		"cell": {"x": cell.x, "y": cell.y},
		"industry_left": _storage_industry()}


## Улучшение города: уровень растёт только при выполнении условий
## (ProsperitySystem.can_level_up — процветание/население/здания).
func level_up_pressed() -> Dictionary:
	if city == null:
		return _fail("Город не привязан")
	if city.level >= ProsperitySystem.CITY_LEVEL_MAX:
		return _fail("Город уже на максимальном уровне")
	var check: Dictionary = ProsperitySystem.can_level_up(city)
	if not bool(check.get("ok", false)):
		return _fail("Нельзя улучшить: " + "; ".join(check.get("reasons", [])))
	var prev_level := city.level
	if not ProsperitySystem.try_level_up(city):
		return _fail("Улучшение не удалось")
	_set_message("Город улучшен: уровень %d → %d" % [prev_level, city.level])
	refresh()
	return {"ok": true, "level": city.level}


## Найм последователя: город отдаёт свободного FOLLOWER-юнита, герой
## получает именованного Follower (FollowerSystem.recruit).
func hire_pressed() -> Dictionary:
	if city == null:
		return _fail("Город не привязан")
	if hero == null:
		return _fail("Наём недоступен: нет героя")
	var f := FollowerSystem.recruit(city, hero, rng)
	if f == null:
		return _fail("Нет свободных последователей для найма")
	_set_message("Нанят: %s" % f.describe(FollowerSystem.registry()))
	refresh()
	return {"ok": true, "follower": f.to_dict()}


func _on_close_pressed() -> void:
	close_requested.emit()


func _fail(message: String) -> Dictionary:
	_set_message(message)
	return {"ok": false, "reason": message}


# ==================== СЛУЖЕБНОЕ ====================

func _set_message(text: String) -> void:
	_message_label.text = text


func _storage_industry() -> float:
	if city == null:
		return 0.0
	return float(city.storage.get(&"industry", 0.0))


func _gold() -> float:
	if city == null or city.resource_ctx == null:
		return 0.0
	return city.resource_ctx.amount(&"gold")


func _format_cost(def: UniqueBuilding.Def) -> String:
	if def == null or def.levels.is_empty():
		return ""
	var req: UniqueBuilding.LevelReq = def.levels[0]
	var parts: Array[String] = []
	if req.industry > 0.0:
		parts.append("промышленность: %.0f" % req.industry)
	if req.special_amount > 0.0:
		parts.append("%s: %.0f" % [str(req.special_resource), req.special_amount])
	if req.followers > 0:
		parts.append("последователи: %d" % req.followers)
	return ", ".join(parts) if not parts.is_empty() else "бесплатно"
