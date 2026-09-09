extends CanvasLayer
class_name AdventureUI

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)
signal minimap_cell_activated(cell: Vector2i)
signal camera_jump_requested_dir(dir: String)
signal settings_applied
signal hex_borders_toggled(on: bool)

const RIGHT_W := 252
const C_BG := ThemeConfig.C_PANEL_BG
const C_BORDER := ThemeConfig.C_PANEL_BORDER

@onready var _minimap: MinimapPanel = $RightColumn/Box/PanelsBox/MinimapPanel
@onready var _army: ArmyPanel = $RightColumn/Box/PanelsBox/ArmyPanel
@onready var _resources: ResourceBar = $RightColumn/Box/PanelsBox/ResourceBar
@onready var _info: InfoPanel = $RightColumn/Box/PanelsBox/InfoPanel
@onready var _strat_resources: ResourcesPanel = $RightColumn/Box/PanelsBox/ResourcesPanel
@onready var _skills_panel: SkillsPanel = $RightColumn/Box/PanelsBox/SkillsPanel
@onready var _tools_panel: ToolsPanel = $RightColumn/Box/PanelsBox/ToolsPanel
@onready var _hero_status: HeroStatusPanel = $RightColumn/Box/PanelsBox/HeroStatusPanel
@onready var _collect_popup: ResourceCollectPopup = $ResourceCollectPopup
@onready var _settings_screen: SettingsScreen = $SettingsScreen

var _cities_mgr: Node = null
var _glory_label: Label
var _glory_bar: ProgressBar

var _hero_controller: HeroController
@onready var _options_popup: Control = $OptionsPopup
var popup_open: bool = false
var _border_check: CheckBox

func _ready() -> void:
	layer = 10
	var p := get_node("RightColumn") as PanelContainer
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.set_border_width_all(2)
	s.border_color = C_BORDER
	p.add_theme_stylebox_override("panel", s)

	_options_popup.get_node("OptionsTitle").text = GameText.adventure_options()
	_options_popup.get_node("ShowMarkersButton").text = GameText.adventure_show_markers()
	_border_check = _options_popup.get_node("BorderCheck/BorderCheckBox") as CheckBox
	_border_check.text = GameText.adventure_hex_grid()
	if not _border_check.is_connected("toggled", _on_border_toggled):
		_border_check.toggled.connect(_on_border_toggled)
	var settings_btn := _options_popup.get_node("BorderCheck/SettingsButton") as Button
	settings_btn.text = GameText.settings_title()
	if not settings_btn.is_connected("pressed", _on_open_settings):
		settings_btn.pressed.connect(_on_open_settings)
	_options_popup.get_node("CloseOptionsButton").text = GameText.ui_close()

	var glory_box := get_node("RightColumn/Box/GloryBox") as VBoxContainer
	_glory_label = glory_box.get_node("GloryLabel") as Label
	_glory_bar = glory_box.get_node("GloryBar") as ProgressBar
	refresh_glory()

	if not GameEventBus.resource_extracted.is_connected(_on_resource_extracted):
		GameEventBus.resource_extracted.connect(_on_resource_extracted)

func setup(hero: HeroController, camera: Camera2D = null) -> void:
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
	_minimap.minimap_clicked.connect(_on_minimap_clicked)
	if map_gen != null and map_gen.renderer != null:
		map_gen.renderer.fog_refreshed.connect(_minimap.refresh)
	_minimap.camera_jump_requested.connect(_on_camera_jump)
	set_cities(_cities_mgr)

	_info.end_turn_pressed.connect(_on_end_turn)
	_info.options_requested.connect(_on_options)
	_info.fill_hero_slot(0, hero)

	refresh_all()

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

func _on_resource_extracted(_cell: Vector2i, resource_id: StringName, amount: int) -> void:
	if _collect_popup != null:
		_collect_popup.show_resource(resource_id, amount)

func refresh_glory() -> void:
	var total := 0.0
	if _cities_mgr != null and _cities_mgr.glory != null:
		total = _cities_mgr.glory.total
	var target := float(GameNumbers.GLORY_VICTORY_THRESHOLD)
	if _glory_label != null:
		_glory_label.text = GameText.adventure_glory(int(total), int(target))
	if _glory_bar != null:
		_glory_bar.max_value = target
		_glory_bar.value = clampf(total, 0.0, target)

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
	popup_open = not popup_open
	if popup_open:
		_options_popup.show()
	else:
		_options_popup.hide()

func _on_open_settings() -> void:
	if _options_popup != null:
		_options_popup.hide()
	if not _settings_screen.applied.is_connected(_on_settings_applied):
		_settings_screen.applied.connect(_on_settings_applied)
	var settings_node: Object = Services.resolve(&"settings")
	_settings_screen.setup(settings_node)
	_settings_screen.show()

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
