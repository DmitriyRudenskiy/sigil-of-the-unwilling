extends Node
class_name WorldUIManager
## Manages all world-level UI elements and overlays.

signal toggle_inventory_requested
signal inventory_closed_requested

var _hero: HeroController
var _map_gen: MapGenerator
var _camera: Camera2D
# city-in-world: сид мира (детерминированный найм последователей в CityScreen).
var _rng: RandomNumberGenerator

var ui: AdventureUI
var ui_layer: CanvasLayer
var inventory_screen: ArtifactInventoryScreen
var chest_dialog: ArtifactChestDialog
var grid_overlay: HexGridOverlay
var marker_layer: MarkerLayer
# city-in-world: экран управления городом (свой слой, выше UI мира).
var city_screen: CityScreen
var city_layer: CanvasLayer

func setup(hero: HeroController, map_gen: MapGenerator, camera: Camera2D,
		rng: RandomNumberGenerator = null, cities_mgr: Node = null) -> void:
	_hero = hero
	_map_gen = map_gen
	_camera = camera
	_rng = rng
	
	_create_ui_layer()
	_create_ui()
	# legend-chronicle: видимый прогресс славы в правой колонке.
	if ui != null:
		ui.set_cities(cities_mgr)
	_create_inventory_screen()
	_create_chest_dialog()
	_create_city_screen()
	_create_marker_layer()

func _create_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "WorldUILayer"
	ui_layer.layer = 30
	add_child(ui_layer)

func _create_ui() -> void:
	ui = AdventureUI.new()
	add_child(ui)
	ui.setup(_hero, _camera)

func _create_inventory_screen() -> void:
	# Скелет окна — в res://scenes/ui/ArtifactInventoryScreen.tscn (static structural
	# children); скрипт применяет тему и наполняет динамическим содержимом.
	var scene := load("res://scenes/ui/ArtifactInventoryScreen.tscn") as PackedScene
	inventory_screen = scene.instantiate() as Control
	inventory_screen.name = "ArtifactInventoryScreen"
	inventory_screen.visible = false
	inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_screen.closed.connect(_on_inventory_closed)
	ui_layer.add_child(inventory_screen)

func _create_chest_dialog() -> void:
	chest_dialog = load("res://scenes/ui/ArtifactChestDialog.tscn").instantiate() as ArtifactChestDialog
	chest_dialog.name = "ArtifactChestDialog"
	chest_dialog.visible = false
	chest_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(chest_dialog)

func _create_city_screen() -> void:
	# city-in-world: слой 40 — выше WorldUI (30), ниже battle-слоёв.
	city_layer = CanvasLayer.new()
	city_layer.name = "CityScreenLayer"
	city_layer.layer = 40
	add_child(city_layer)
	city_screen = CityScreen.new()
	city_screen.name = "CityScreen"
	city_screen.visible = false
	city_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	city_screen.close_requested.connect(_on_city_screen_close_requested)
	city_layer.add_child(city_screen)

func _create_marker_layer() -> void:
	marker_layer = MarkerLayer.new()
	marker_layer.name = "MarkerLayer"
	marker_layer.setup(_map_gen)
	add_child(marker_layer)

func set_hex_borders(on: bool) -> void:
	if on and grid_overlay == null:
		grid_overlay = HexGridOverlay.new()
		grid_overlay.map_ref = _map_gen
		grid_overlay.cam_ref = _camera
		add_child(grid_overlay)
	if grid_overlay != null:
		grid_overlay.enabled = on

func toggle_inventory() -> void:
	if inventory_screen == null:
		return
	if inventory_screen.visible:
		inventory_screen.hide()
	else:
		inventory_screen.set_hero(_hero)
		inventory_screen.show()

func _on_inventory_closed() -> void:
	inventory_closed_requested.emit()

func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if marker_layer:
		marker_layer.show_markers(hero_cell, mp, dist)

func hide_reach_markers() -> void:
	if marker_layer:
		marker_layer.hide_markers()

func set_ui_visible(visible: bool) -> void:
	if ui:
		ui.visible = visible

func refresh_ui() -> void:
	if ui:
		ui.refresh_all()


# ==================== city-in-world: city screen ====================

## Открыть экран управления городом. Идемпотентно: при смене города —
## пере-привязка (setup), при том же городе — только повторное открытие.
func open_city_screen(city: City, hero_cell: Vector2i) -> void:
	if city == null or city_screen == null:
		return
	var bounds := Vector2i(0, 0)
	if _map_gen != null:
		bounds = Vector2i(_map_gen.map_width, _map_gen.map_height)
	if city_screen.city != city:
		city_screen.setup(city, _hero, hero_cell, _rng, bounds)
	else:
		city_screen.hero_cell = hero_cell
	city_screen.open()

func close_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.close()

## Guard для WorldShortcuts/WorldInput: оверлей открыт.
func city_overlay_open() -> bool:
	return city_screen != null and city_screen.is_open()

## Перерисовать открытый экран из состояния города (после внешних мутаций).
func refresh_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.refresh()

func _on_city_screen_close_requested() -> void:
	close_city_screen()

## city-in-world: сокет-действия через РЕАЛЬНЫЙ экран (CITY_BUILD/CITY_LEVEL/
## CITY_HIRE): открыть экран для города → выполнить то же действие, что
## выполняет кнопка → вернуть результат.
func city_screen_action(action: String, city: City, hero_cell: Vector2i,
		building_id: String = "farm") -> Dictionary:
	if city == null:
		return {"ok": false, "reason": "no city"}
	open_city_screen(city, hero_cell)
	match action:
		"build":
			return city_screen.build_pressed(StringName(building_id))
		"level":
			return city_screen.level_up_pressed()
		"hire":
			return city_screen.hire_pressed()
	return {"ok": false, "reason": "unknown action: " + action}

## Статусная строка в InfoPanel (WorldBootstrap показывает тут сообщения).
func set_status(text: String) -> void:
	if ui:
		ui.set_status(text)

func set_date(month: int, week: int, day: int) -> void:
	if ui:
		ui.set_date(month, week, day)

func _exit_tree() -> void:
	# Cleanup any signal connections if added in the future
	pass
