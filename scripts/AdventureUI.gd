extends CanvasLayer
class_name AdventureUI
## Координатор UI: миникарта, армия, ресурсы, инфо-панель.

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

const RIGHT_W := 252
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)

var _minimap: MinimapPanel
var _army: ArmyPanel
var _resources: ResourceBar
var _info: InfoPanel

var _hero_controller: HeroController
var _options_popup: PopupPanel
var _border_check: CheckBox


func _ready() -> void:
	layer = 10
	_build_right_column()


func _build_right_column() -> void:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.set_border_width_all(2)
	s.border_color = C_BORDER
	p.add_theme_stylebox_override("panel", s)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.offset_left = -RIGHT_W
	add_child(p)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)

	_minimap = MinimapPanel.new()
	vb.add_child(_minimap)

	_info = InfoPanel.new()
	vb.add_child(_info)

	_army = ArmyPanel.new()
	vb.add_child(_army)

	_resources = ResourceBar.new()
	vb.add_child(_resources)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)


func setup(hero: HeroController) -> void:
	_hero_controller = hero
	hero.movement_points_changed.connect(func(c, m): _info.set_status("👣 %d/%d" % [c, m]))
	hero.resources_changed.connect(func(_r): _resources.update_resources(hero.resources))
	hero.path_previewed.connect(func(t): _info.set_status(t))

	var world := get_parent()
	var camera: Camera2D = null
	if world and world.has_method("get_camera"):
		camera = world.get_camera()

	_minimap.setup(hero.get_map_gen(), hero, camera)
	_minimap.minimap_clicked.connect(_on_minimap_clicked)
	_minimap.camera_jump_requested.connect(_on_camera_jump)

	_info.end_turn_pressed.connect(_on_end_turn)
	_info.options_requested.connect(_on_options)
	_info.fill_hero_slot(0, hero)

	refresh_all()


func refresh_all() -> void:
	if _hero_controller == null:
		return
	_army.update_army(_hero_controller.army)
	_resources.update_resources(_hero_controller.resources)


func add_city(city_name: String) -> void:
	_info.add_city(city_name)


func advance_day() -> void:
	_info.advance_day()
	date_changed.emit(_info.month, _info.week, _info.day)


func _on_minimap_clicked(cell: Vector2i) -> void:
	var world := get_parent()
	if world and world.has_method("center_camera_on"):
		world.center_camera_on(cell)


func _on_camera_jump(direction: String) -> void:
	var world := get_parent()
	if world and world.has_method("jump_camera"):
		world.jump_camera(direction)


func _on_end_turn() -> void:
	advance_day()
	end_turn_pressed.emit()


func _on_options() -> void:
	if _options_popup == null:
		_options_popup = PopupPanel.new()
		var vb := VBoxContainer.new()
		_options_popup.add_child(vb)
		_border_check = CheckBox.new()
		_border_check.text = "Рамка гексов"
		_border_check.toggled.connect(_on_border_toggled)
		vb.add_child(_border_check)
		add_child(_options_popup)
	_options_popup.popup_centered(Vector2i(260, 80))


func _on_border_toggled(on: bool) -> void:
	var world := get_parent()
	if world and world.has_method("set_hex_borders"):
		world.set_hex_borders(on)
