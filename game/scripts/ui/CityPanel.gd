class_name CityPanel
extends Control

signal building_upgrade_requested(building: UniqueBuilding)
signal closed

const C_BG := ThemeConfig.C_PANEL_BG
const C_BORDER := ThemeConfig.C_PANEL_BORDER

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
	var box := get_node("Panel/Box")
	_title = box.get_node("Title") as Label
	_summary = box.get_node("Summary") as Label
	_pops = box.get_node("Pops") as ItemList
	_buildings = box.get_node("Buildings") as ItemList
	_btn_worker = box.get_node("Row/WorkerButton") as Button
	_btn_worker.text = GameText.cityjob_name(&"worker")
	_btn_militia = box.get_node("Row/MilitiaButton") as Button
	_btn_militia.text = GameText.cityjob_name(&"militia")
	_btn_patrol = box.get_node("Row/PatrolButton") as Button
	_btn_patrol.text = GameText.cityjob_name(&"patrol")
	var reserve_btn := box.get_node("Row/ReserveButton") as Button
	reserve_btn.text = GameText.cityjob_name(&"reserve")
	reserve_btn.connect("pressed", _on_follower)
	var close_btn := box.get_node("CloseButton") as Button
	close_btn.text = GameText.ui_close()
	close_btn.connect("pressed", close)

	_pops.item_selected.connect(func(_i): _update_buttons())
	_btn_worker.pressed.connect(_on_worker)
	_btn_militia.pressed.connect(_on_militia)
	_btn_patrol.pressed.connect(_on_patrol)
	_buildings.item_activated.connect(_on_building_activated)

	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.set_border_width_all(2)
	s.border_color = C_BORDER
	(get_node("Panel") as PanelContainer).add_theme_stylebox_override("panel", s)


func open(city: City) -> void:
	_bind(city)
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()



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
	_title.text = "%s%s" % [c.display_name, GameText.citypanel_capital() if c.is_capital else ""]

	var over := ""
	if c.over_limit() > 0:
		over = GameText.citypanel_over_limit(c.over_limit())
	_summary.text = GameText.citypanel_summary(
		c.pop_capped(), c.pop_cap(), over,
		c.count_state(PopUnit.State.WORKER), c.free_followers(),
		c.count_state(PopUnit.State.MILITIA), c.patrol_count(),
		"%.0f" % c.food_stockpile, "%.0f" % c.growth_threshold(), "%+.1f" % c.net_food(),
		GameText.citypanel_starving() if c.starving else "",
		"%+d" % c.approval(), c.safety(),
		c.boroughs.size(), BoroughRules.max_boroughs(c),
		"%.0f" % float(c.storage.get(&"industry", 0.0)),
	)

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
				extra = GameText.citypanel_patrol_tag() if u.patrol else ""
		if u.assigned_to != -1:
			extra += GameText.citypanel_in_building()
		if u.pending_state != -1:
			extra += " ⏳"
		_pops.add_item("%s #%d%s" % [tag, u.uid, extra])
		_view_uids.append(u.uid)

	_buildings.clear()
	_view_buildings.clear()
	for b in c.buildings:
		var up := c.can_upgrade_building(b)
		_buildings.add_item(GameText.citypanel_building_line(
			b.def.display_name, b.level, GameText.citypanel_can_upgrade() if up.ok else ""))
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
	_btn_patrol.text = GameText.citypanel_patrol_off() if _btn_patrol.disabled \
		else (GameText.citypanel_patrol_off() if not u.patrol else GameText.citypanel_patrol_on())


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
