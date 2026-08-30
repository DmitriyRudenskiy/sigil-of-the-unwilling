class_name CityPanel
extends Control
## Панель города: фигурки населения, еда, районы, здания.
## Пассивна: читает City, изменения приходят через сигналы города.

signal building_upgrade_requested(building: UniqueBuilding)
signal closed

const W := 340.0
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)

var _city: City = null
var _title: Label
var _summary: Label
var _pops: ItemList
var _buildings: ItemList
var _btn_worker: Button
var _btn_militia: Button
var _btn_patrol: Button
var _view_uids: Array[int] = []
var _view_buildings: Array[UniqueBuilding] = []


func _ready() -> void:
	visible = false
	_build_ui()


func open(city: City) -> void:
	_bind(city)
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -W - 12.0
	offset_right = -12.0
	offset_top = 40.0
	offset_bottom = -40.0

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.set_border_width_all(2)
	s.border_color = C_BORDER
	panel.add_theme_stylebox_override("panel", s)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_summary)

	_pops = ItemList.new()
	_pops.custom_minimum_size = Vector2(0, 150)
	_pops.item_selected.connect(func(_i): _update_buttons())
	vb.add_child(_pops)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	_btn_worker = _mk_btn(row, "⚙ Рабочий", _on_worker)
	_btn_militia = _mk_btn(row, "🛡 Ополченец", _on_militia)
	var btn_res := _mk_btn(row, "👤 Резерв", _on_follower)
	_btn_patrol = _mk_btn(row, "🐎 Патруль", _on_patrol)
	btn_res.size_flags_horizontal = _btn_worker.size_flags_horizontal  # выравнивание

	_buildings = ItemList.new()
	_buildings.custom_minimum_size = Vector2(0, 90)
	_buildings.item_activated.connect(_on_building_activated)
	vb.add_child(_buildings)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


func _mk_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _bind(city: City) -> void:
	if _city == city:
		return
	if _city != null:
		_city.population_changed.disconnect(_refresh)
		_city.boroughs_changed.disconnect(_refresh)
		_city.buildings_changed.disconnect(_refresh)
		_city.storage_changed.disconnect(_refresh)
	_city = city
	if _city != null:
		_city.population_changed.connect(_refresh)
		_city.boroughs_changed.connect(_refresh)
		_city.buildings_changed.connect(_refresh)
		_city.storage_changed.connect(_refresh)


func _refresh() -> void:
	if _city == null or not visible:
		return
	var c := _city
	_title.text = "%s%s" % [c.display_name, " (столица)" if c.is_capital else ""]

	var over := ""
	if c.over_limit() > 0:
		over = "  ⚠ ПЕРЕЛИМИТ %d" % c.over_limit()
	_summary.text = "Население: %d/%d%s\nРабочие %d · Свободных последователей %d · Ополченцы %d (патруль %d)\nЕда: %.0f/%.0f (нетто %+.1f/ход)%s\nОдобрение: %+d · Безопасность: %d\nРайоны: %d/%d · Промышленность: %.0f" % [
		c.pop_capped(), c.pop_cap(), over,
		c.count_state(PopUnit.State.WORKER), c.free_followers(),
		c.count_state(PopUnit.State.MILITIA), c.patrol_count(),
		c.food_stockpile, c.growth_threshold(), c.net_food(),
		"  🍂 ГОЛОД" if c.starving else "",
		c.approval(), c.safety(),
		c.boroughs.size(), BoroughRules.max_boroughs(c),
		float(c.storage.get(&"industry", 0.0)),
	]

	_pops.clear()
	_view_uids.clear()
	for u in c.pop:
		var tag := "👤"
		var extra := ""
		match u.state:
			PopUnit.State.WORKER:
				tag = "⚙"
				extra = " %s" % u.tile
			PopUnit.State.MILITIA:
				tag = "🛡"
				extra = " патруль" if u.patrol else ""
		if u.assigned_to != -1:
			extra += " [в здании]"
		if u.pending_state != -1:
			extra += " ⏳"
		_pops.add_item("%s #%d%s" % [tag, u.uid, extra])
		_view_uids.append(u.uid)

	_buildings.clear()
	_view_buildings.clear()
	for b in c.buildings:
		var up := c.can_upgrade_building(b)
		_buildings.add_item("%s ур.%d/3%s" % [
			b.def.display_name, b.level, "  [можно улучшить]" if up.ok else "",
		])
		_view_buildings.append(b)

	_update_buttons()


func _selected_uid() -> int:
	var idx := _pops.get_selected_items()
	if idx.is_empty():
		return -1
	return _view_uids[idx[0]]


func _selected_unit() -> PopUnit:
	var uid := _selected_uid()
	return _city.find_pop(uid) if uid >= 0 else null


func _update_buttons() -> void:
	var u := _selected_unit()
	var has := u != null and u.is_available()
	_btn_worker.disabled = not has or _city.first_free_worker_tile().x < 0
	_btn_militia.disabled = not has
	_btn_patrol.disabled = u == null or u.state != PopUnit.State.MILITIA
	_btn_patrol.text = "🐎 Патруль: ВЫКЛ" if _btn_patrol.disabled \
		else ("🐎 Патруль: ВЫКЛ" if not u.patrol else "🐎 Патруль: ВКЛ")


func _on_worker() -> void:
	var u := _selected_unit()
	if u != null:
		_city.request_switch(u.uid, PopUnit.State.WORKER, _city.first_free_worker_tile())


func _on_follower() -> void:
	var u := _selected_unit()
	if u != null:
		_city.request_switch(u.uid, PopUnit.State.FOLLOWER)


func _on_militia() -> void:
	var u := _selected_unit()
	if u != null:
		_city.request_switch(u.uid, PopUnit.State.MILITIA)


func _on_patrol() -> void:
	var u := _selected_unit()
	if u != null:
		_city.set_patrol(u.uid, not u.patrol)


func _on_building_activated(idx: int) -> void:
	if idx >= 0 and idx < _view_buildings.size():
		building_upgrade_requested.emit(_view_buildings[idx])
