extends CanvasLayer
class_name AdventureUI
## Координатор UI: миникарта, армия, ресурсы, инфо-панель.

const _SettingsScreen = preload("res://scripts/ui/SettingsScreen.gd")

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)
signal minimap_cell_activated(cell: Vector2i)
signal camera_jump_requested_dir(dir: String)
signal settings_applied
signal hex_borders_toggled(on: bool)

const RIGHT_W := 252
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)

var _minimap: MinimapPanel
var _army: ArmyPanel
var _resources: ResourceBar
var _info: InfoPanel

# Addendum 10: Resource chain panels
var _strat_resources: ResourcesPanel
var _skills_panel: SkillsPanel
var _tools_panel: ToolsPanel
var _hero_status: HeroStatusPanel

## legend-chronicle: видимый прогресс славы (цель — ENDGAME_GLORY_VICTORY).
var _cities_mgr: Node = null

## resource-collection-popup: «Собрано ресурс» на любом событии сбора.
var _collect_popup: ResourceCollectPopup
var _glory_label: Label
var _glory_bar: ProgressBar

var _hero_controller: HeroController
var _options_popup: PopupPanel
var _border_check: CheckBox


func _ready() -> void:
	layer = 10
	_build_right_column()
	# resource-collection-popup: один попап на событие сбора (оба пути —
	# богатые жилы и простой сбор шлют GameEventBus.resource_extracted).
	# Связь живёт столько, сколько нод (GameEventBus — процессный autoload,
	# коннект отваливается вместе с освобождением AdventureUI).
	if not GameEventBus.resource_extracted.is_connected(_on_resource_extracted):
		GameEventBus.resource_extracted.connect(_on_resource_extracted)


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

	_info = load("res://scenes/ui/InfoPanel.tscn").instantiate() as InfoPanel
	vb.add_child(_info)

	_army = ArmyPanel.new()
	vb.add_child(_army)

	_resources = ResourceBar.new()
	vb.add_child(_resources)

	# Addendum 10: Resource chain panels
	_strat_resources = ResourcesPanel.new()
	vb.add_child(_strat_resources)

	_skills_panel = SkillsPanel.new()
	vb.add_child(_skills_panel)

	_tools_panel = ToolsPanel.new()
	vb.add_child(_tools_panel)

	# legend-chronicle: состояние героя (кондиция/статы/последователи).
	_hero_status = HeroStatusPanel.new()
	vb.add_child(_hero_status)

	# legend-chronicle: прогресс славы (когда до победы).
	var glory_box := VBoxContainer.new()
	glory_box.name = "GloryBox"
	glory_box.add_theme_constant_override("separation", 2)
	vb.add_child(glory_box)
	_glory_label = Label.new()
	_glory_label.add_theme_font_size_override("font_size", 12)
	glory_box.add_child(_glory_label)
	_glory_bar = ProgressBar.new()
	_glory_bar.show_percentage = false
	_glory_bar.custom_minimum_size = Vector2(0, 12)
	glory_box.add_child(_glory_bar)
	refresh_glory()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)


func setup(hero: HeroController, camera: Camera2D = null) -> void:
	_hero_controller = hero
	hero.movement_points_changed.connect(func(c, m): _update_mp_display(c, m))
	hero.resources_changed.connect(func(res): _resources.update_resources(res))
	hero.path_previewed.connect(func(t): _info.set_status(t))
	# Addendum 10: Resource chain signals
	hero.strategic_resources_changed.connect(_strat_resources.update_resources)
	hero.skills_changed.connect(func(): _skills_panel.update_skills(hero.skills.get_all()))
	hero.tools_changed.connect(func(): _tools_panel.update_tools(hero.tools.get_all()))
	hero.time_changed.connect(_info.set_time)
	_hero_status.set_hero(hero)

	var map_gen := hero.get_map_gen()
	_minimap.setup(map_gen, hero, camera)
	_minimap.minimap_clicked.connect(_on_minimap_clicked)
	# fog-of-war: обновлять мини-карту при перерисе видимости.
	if map_gen != null and map_gen.renderer != null:
		map_gen.renderer.fog_refreshed.connect(_minimap.refresh)
	_minimap.camera_jump_requested.connect(_on_camera_jump)
	set_cities(_cities_mgr)

	_info.end_turn_pressed.connect(_on_end_turn)
	_info.options_requested.connect(_on_options)
	_info.fill_hero_slot(0, hero)

	refresh_all()


## endgame/succession: сменить героя НЕ через setup() — setup ре-коннектит
## сигналы долговечных нод (info.end_turn_pressed и т.п.) и задвоит их.
## Тут только hero-специфичная часть: новые сигналы героя + реф миникарты.
func reattach_hero(hero: HeroController, camera: Camera2D = null) -> void:
	_hero_controller = hero
	hero.movement_points_changed.connect(func(c, m): _update_mp_display(c, m))
	hero.resources_changed.connect(func(res): _resources.update_resources(res))
	hero.path_previewed.connect(func(t): _info.set_status(t))
	hero.strategic_resources_changed.connect(_strat_resources.update_resources)
	hero.skills_changed.connect(func(): _skills_panel.update_skills(hero.skills.get_all()))
	hero.tools_changed.connect(func(): _tools_panel.update_tools(hero.tools.get_all()))
	hero.time_changed.connect(_info.set_time)
	_hero_status.set_hero(hero)
	var map_gen := hero.get_map_gen()
	_minimap.setup(map_gen, hero, camera)
	_info.fill_hero_slot(0, hero)
	set_cities(_cities_mgr)
	refresh_all()


func refresh_all() -> void:
	if _hero_controller == null:
		return
	_army.update_army(_hero_controller.army.army)
	_resources.update_resources(_hero_controller.resources.resources)
	_strat_resources.update_resources(_hero_controller.strategic_resources.get_all())
	_skills_panel.update_skills(_hero_controller.skills.get_all())
	_tools_panel.update_tools(_hero_controller.tools.get_all())
	_hero_status.refresh()
	refresh_glory()


## legend-chronicle: слава (CityManager) — метка + прогресс-бар к цели.
func set_cities(cities_mgr: Node) -> void:
	if _cities_mgr == cities_mgr:
		return
	_cities_mgr = cities_mgr
	if _cities_mgr != null and _cities_mgr.has_signal("glory_changed") \
			and not _cities_mgr.glory_changed.is_connected(_on_glory_changed):
		_cities_mgr.glory_changed.connect(_on_glory_changed)
	refresh_glory()


func _on_glory_changed(_window_total: float) -> void:
	refresh_glory()


## resource-collection-popup: «Собрано ресурс» — один попап на событие.
## Оба пути сбора шлют единый GameEventBus.resource_extracted: богатые жилы —
## из ResourceNodeManager.try_extract, простой — из
## WorldInteractionController.collect_resource_at.
func _on_resource_extracted(_cell: Vector2i, resource_id: StringName, amount: int) -> void:
	if _collect_popup == null:
		_collect_popup = ResourceCollectPopup.new()
		_collect_popup.name = "ResourceCollectPopup"
		add_child(_collect_popup)
	_collect_popup.show_resource(resource_id, amount)


func refresh_glory() -> void:
	var total := 0.0
	if _cities_mgr != null and _cities_mgr.glory != null:
		total = _cities_mgr.glory.total
	var target := float(GameSettings.ENDGAME_GLORY_VICTORY)
	if _glory_label != null:
		_glory_label.text = "👑 Слава: %d / %d" % [int(total), int(target)]
	if _glory_bar != null:
		_glory_bar.max_value = target
		_glory_bar.value = clampf(total, 0.0, target)


## Статусная строка (путь, сообщения системы).
func set_status(text: String) -> void:
	_info.set_status(text)


func add_city(city_name: String) -> void:
	_info.add_city(city_name)


func advance_day() -> void:
	_info.advance_day()
	date_changed.emit(_info.month, _info.week, _info.day)


func set_date(month: int, week: int, day: int) -> void:
	_info.set_date(month, week, day)


func _on_minimap_clicked(cell: Vector2i) -> void:
	minimap_cell_activated.emit(cell)


func _on_camera_jump(direction: String) -> void:
	camera_jump_requested_dir.emit(direction)


func _on_end_turn() -> void:
	SoundManager.play_sfx_cue(&"ui_click")
	advance_day()
	end_turn_pressed.emit()


func _on_options() -> void:
	# Show merged options: hex borders + settings button
	if _options_popup == null:
		_options_popup = PopupPanel.new()
		var vb := VBoxContainer.new()
		_options_popup.add_child(vb)
		_border_check = CheckBox.new()
		_border_check.text = "Рамка гексов"
		_border_check.toggled.connect(_on_border_toggled)
		vb.add_child(_border_check)

		var settings_btn := Button.new()
		settings_btn.text = "⚙️ Настройки"
		settings_btn.pressed.connect(_on_open_settings)
		settings_btn.pressed.connect(func() -> void: SoundManager.play_sfx_cue(&"ui_click"))
		vb.add_child(settings_btn)

		add_child(_options_popup)
	_options_popup.popup_centered(Vector2i(260, 110))


func _on_open_settings() -> void:
	if _options_popup != null:
		_options_popup.hide()
	var screen: Control = _SettingsScreen.new()
	screen.setup(get_node_or_null("/root/Settings"))
	screen.applied.connect(_on_settings_applied)
	add_child(screen)


func _on_settings_applied() -> void:
	settings_applied.emit()


func _on_border_toggled(on: bool) -> void:
	hex_borders_toggled.emit(on)


func _update_mp_display(current: float, max_val: float) -> void:
	var text := "🚶 %.1f / %.0f" % [current, max_val]
	var ratio: float = current / max_val if max_val > 0 else 0.0
	var color: Color
	if ratio >= 0.4:
		color = Color.GREEN
	elif ratio >= 0.1:
		color = Color.YELLOW
	else:
		color = Color.RED
	_info.set_status_colored(text, color)
