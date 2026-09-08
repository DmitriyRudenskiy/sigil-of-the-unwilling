extends Node
class_name WorldUIManager

signal toggle_inventory_requested
signal inventory_closed_requested

var _hero: HeroController
var _map_gen: MapGenerator
var _camera: Camera2D
var _rng: RandomNumberGenerator

@onready var ui: AdventureUI = $WorldUILayer/AdventureUI
@onready var ui_layer: CanvasLayer = $WorldUILayer
@onready var inventory_screen: ArtifactInventoryScreen = $WorldUILayer/ArtifactInventoryScreen
@onready var chest_dialog: ArtifactChestDialog = $WorldUILayer/ArtifactChestDialog
@onready var grid_overlay: HexGridOverlay = $HexGridOverlay
@onready var marker_layer: MarkerLayer = $MarkerLayer
@onready var city_screen: CityScreen = $CityScreenLayer/CityScreen
@onready var city_layer: CanvasLayer = $CityScreenLayer
@onready var death_sequence: DeathSequence = $DeathSequence
@onready var chronicle_screen: ChronicleScreen = $ChronicleScreen
@onready var game_over_screen: GameOverScreen = $GameOverScreen

func setup(hero: HeroController, map_gen: MapGenerator, camera: Camera2D,
		rng: RandomNumberGenerator = null, cities_mgr: Node = null) -> void:
	_hero = hero
	_map_gen = map_gen
	_camera = camera
	_rng = rng
	grid_overlay.map_ref = _map_gen
	grid_overlay.cam_ref = _camera
	marker_layer.setup(_map_gen)
	if ui != null:
		ui.set_cities(cities_mgr)
		ui.setup(_hero, _camera)
	if inventory_screen != null and not inventory_screen.closed.is_connected(_on_inventory_closed):
		inventory_screen.closed.connect(_on_inventory_closed)
	if city_screen != null and not city_screen.close_requested.is_connected(_on_city_screen_close_requested):
		city_screen.close_requested.connect(_on_city_screen_close_requested)

func set_hex_borders(on: bool) -> void:
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

func city_overlay_open() -> bool:
	return city_screen != null and city_screen.is_open()

func refresh_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.refresh()

func _on_city_screen_close_requested() -> void:
	close_city_screen()

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

func set_status(text: String) -> void:
	if ui:
		ui.set_status(text)

func set_date(month: int, week: int, day: int) -> void:
	if ui:
		ui.set_date(month, week, day)

func _exit_tree() -> void:
	pass
