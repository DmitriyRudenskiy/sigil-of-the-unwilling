extends Node
class_name WorldUIManager
## Manages all world-level UI elements and overlays.

signal toggle_inventory_requested
signal inventory_closed_requested

var _hero: HeroController
var _map_gen: MapGenerator
var _camera: Camera2D

var ui: AdventureUI
var ui_layer: CanvasLayer
var inventory_screen: ArtifactInventoryScreen
var chest_dialog: ArtifactChestDialog
var grid_overlay: HexGridOverlay
var marker_layer: MarkerLayer

func setup(hero: HeroController, map_gen: MapGenerator, camera: Camera2D) -> void:
	_hero = hero
	_map_gen = map_gen
	_camera = camera
	
	_create_ui_layer()
	_create_ui()
	_create_inventory_screen()
	_create_chest_dialog()
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
	inventory_screen = ArtifactInventoryScreen.new()
	inventory_screen.name = "ArtifactInventoryScreen"
	inventory_screen.visible = false
	inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(inventory_screen)

func _create_chest_dialog() -> void:
	chest_dialog = ArtifactChestDialog.new()
	chest_dialog.name = "ArtifactChestDialog"
	chest_dialog.visible = false
	chest_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(chest_dialog)

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
		inventory_screen.setup(_hero.inventory)
		inventory_screen.show()

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
