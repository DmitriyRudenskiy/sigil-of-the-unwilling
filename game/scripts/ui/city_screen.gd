class_name CityScreen
extends Control

const DeceptionCheck = preload("res://scripts/systems/deception_check.gd")
const ReputationSystem = preload("res://scripts/city/reputation_system.gd")
const WeaponTechService = preload("res://scripts/systems/weapon_tech_service.gd")
const LeadershipCheck = preload("res://scripts/systems/leadership_check.gd")
const ArchetypeResolver = preload("res://scripts/demographics/archetype_resolver.gd")
const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")
const CampaignCityProgression := preload("res://scripts/city/campaign_city_progression.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignDefenseResolver := preload("res://scripts/city/campaign_defense_resolver.gd")

const PALETTE := {
	"background": Color("#11120f"),
	"panel": Color("#211e18"),
	"board": Color("#171915"),
	"text_primary": Color("#f1e6cf"),
	"text_muted": Color("#c6b78f"),
	"accent_gold": Color("#e0bd67"),
	"accent_teal": Color("#77e4da"),
	"text_warning": Color("#e8a17c"),
	"text_success": Color("#91c992"),
	"text_body": Color("#d5cdbb"),
	"text_metric": Color("#e7d5aa"),
}

const CATALOG_CATEGORIES := [
	{"title": "Все", "roles": []},
	{"title": "Производство", "roles": [
		"food_production", "agriculture", "wood_production", "woodworking",
		"iron_production", "metalworking",
	]},
	{"title": "Службы", "roles": [
		"administration", "community_service", "education", "education_service",
		"health_service", "herbal_service", "religious_service", "water_service",
	]},
	{"title": "Жильё", "roles": ["housing"]},
	{"title": "Оборона", "roles": ["military_training", "static_defense"]},
]

signal close_requested
signal state_changed

var city: City = null
var hero: HeroController = null
var hero_cell: Vector2i = Vector2i(-1, -1)
var rng: RandomNumberGenerator = null
var map_bounds: Vector2i = Vector2i.ZERO

var _stats_label: Label
var _buildings_label: Label
var _title_label: Label
var _message_label: Label
var _sidebar: PanelContainer
var _sidebar_title: Label
var _category_tabs: HBoxContainer
var _category_buttons: Array[Button] = []
var _selected_category_index := 0
var _catalog_scroll: ScrollContainer
var _catalog_placeholder: Label
var _confirm_build_button: Button
var _cancel_build_button: Button
var _board_placeholder: Label
var _board: CampaignCityBoard
var _selected_cell := Vector2i(-1, -1)
var _close_button: Button
var _resource_buttons: Dictionary = {}
var _population_metric: Label
var _housing_metric: Label
var _city_level_button: Button
var _inspector_panel: PanelContainer
var _inspector_title: Label
var _inspector_text: Label
var _legacy_panel: PanelContainer
var _legacy_actions: HBoxContainer
var _legacy_toggle: Button
var _sidebar_button: Button
var _sidebar_collapsed := false
var _sidebar_override := false
var _opened := false
var terrain_provider: Callable = Callable()
var _mvp_catalog: Dictionary = {}
var _campaign_catalog: Dictionary = {}
var _visible_catalog_categories: Array[Dictionary] = []
var _catalog_error := ""
var _selected_building_id := ""
var _catalog_rendered := false
var _placement_active := false
var _preview_anchor := Vector2i(-1, -1)
var _preview_result: Dictionary = {}

func _ready() -> void:
	_mvp_catalog = ArchetypeResolver.load_catalog()
	_build_shell()
	_initialize_campaign_catalog()
	var buttons := _legacy_actions
	var build_farm := buttons.get_node("BuildFarm") as Button
	build_farm.pressed.connect(_on_build_farm_pressed)
	build_farm.text = GameText.city_build_farm()
	var build_mine := buttons.get_node("BuildMine") as Button
	build_mine.pressed.connect(_on_build_mine_pressed)
	build_mine.text = GameText.city_build_mine()
	var level_up := buttons.get_node("LevelUp") as Button
	level_up.pressed.connect(_on_level_up_pressed)
	level_up.text = GameText.city_level_up()
	var hire := buttons.get_node("Hire") as Button
	hire.pressed.connect(_on_hire_pressed)
	hire.text = GameText.city_hire()
	var unload := buttons.get_node("Unload") as Button
	unload.pressed.connect(_on_unload_pressed)
	unload.text = GameText.city_unload()
	var cart := buttons.get_node("Cart") as Button
	cart.pressed.connect(_on_cart_pressed)
	cart.text = GameText.city_cart()
	var recruit := buttons.get_node("Recruit") as Button
	recruit.pressed.connect(_on_recruit_pressed)
	recruit.text = GameText.city_recruit()
	var close_btn := _close_button
	close_btn.pressed.connect(_on_close_pressed)
	close_btn.text = GameText.city_close()
	_apply_keyboard_focus(close_btn)
	_sidebar_button.pressed.connect(_toggle_sidebar)
	_apply_keyboard_focus(_sidebar_button)
	_legacy_toggle.pressed.connect(_toggle_legacy_actions)
	_apply_keyboard_focus(_legacy_toggle)
	resized.connect(_on_screen_resized)
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_on_screen_resized):
		window.size_changed.connect(_on_screen_resized)
	_on_screen_resized()

static func contrast_ratio(foreground: Color, background: Color) -> float:
	var foreground_luminance := _relative_luminance(foreground)
	var background_luminance := _relative_luminance(background)
	var brighter := maxf(foreground_luminance, background_luminance)
	var darker := minf(foreground_luminance, background_luminance)
	return (brighter + 0.05) / (darker + 0.05)

static func _relative_luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	var weights := [0.2126, 0.7152, 0.0722]
	var luminance := 0.0
	for index in range(3):
		var channel: float = channels[index]
		var linear := channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)
		luminance += linear * weights[index]
	return luminance

func _resource_icon(resource_id: StringName) -> Texture2D:
	match resource_id:
		&"food": return BuildingDefs.get_icon(&"farm")
		&"wood": return ThemeConfig.icon_texture(ThemeConfig.ICON_DIR_RESOURCES + "wood.png")
		&"iron": return ThemeConfig.icon_texture(ThemeConfig.ICON_DIR_RESOURCES + "ore.png")
	return null

func _resource_metric_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style

func _apply_keyboard_focus(control: Control) -> void:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = PALETTE.accent_teal
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	control.add_theme_stylebox_override("focus", focus)

func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.name = "ScreenShade"
	shade.color = Color(PALETTE.background, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	move_child(shade, 0)

	var margin := MarginContainer.new()
	margin.name = "ScreenMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "ScreenLayout"
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := PanelContainer.new()
	header.name = "ScreenHeader"
	header.custom_minimum_size.y = 72
	header.add_theme_stylebox_override("panel", _panel_style(Color("#211e18"), Color("#92743b")))
	layout.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.add_theme_constant_override("separation", 18)
	header.add_child(header_row)
	_title_label = Label.new()
	_title_label.name = "CityTitle"
	_title_label.text = "Город"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color("#f1e6cf"))
	header_row.add_child(_title_label)
	var subtitle := Label.new()
	subtitle.name = "CitySubtitle"
	subtitle.text = "КАМПАНИЙНЫЙ ГОРОД · 52 КЛЕТКИ"
	subtitle.add_theme_color_override("font_color", Color("#c6b78f"))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(subtitle)
	var metrics := HBoxContainer.new()
	metrics.name = "ResourceHud"
	metrics.add_theme_constant_override("separation", 6)
	header_row.add_child(metrics)
	for id in [&"food", &"wood", &"iron"]:
		var metric := Button.new()
		metric.name = String(id).capitalize() + "Metric"
		metric.text = "%s  —" % _resource_label(id)
		metric.tooltip_text = "Текущий баланс и потоки из общего журнала"
		metric.focus_mode = Control.FOCUS_ALL
		metric.icon = _resource_icon(id)
		metric.add_theme_constant_override("h_separation", 8)
		metric.alignment = HORIZONTAL_ALIGNMENT_LEFT
		metric.add_theme_stylebox_override("normal", _resource_metric_style(Color("#30291d"), Color("#9a804d")))
		metric.add_theme_stylebox_override("hover", _resource_metric_style(Color("#3b3120"), PALETTE.accent_gold))
		metric.add_theme_stylebox_override("pressed", _resource_metric_style(Color("#45391f"), PALETTE.accent_gold))
		metric.add_theme_stylebox_override("disabled", _resource_metric_style(Color("#211e18"), Color("#665638")))
		_apply_keyboard_focus(metric)
		metric.add_theme_color_override("font_color", PALETTE.text_metric)
		metric.pressed.connect(_on_resource_pressed.bind(id))
		_resource_buttons[id] = metric
		metrics.add_child(metric)
	_population_metric = Label.new()
	_population_metric.name = "PopulationMetric"
	_population_metric.text = "Жители —"
	_population_metric.tooltip_text = "Население города"
	_population_metric.focus_mode = Control.FOCUS_ALL
	_apply_keyboard_focus(_population_metric)
	_population_metric.add_theme_color_override("font_color", Color("#e7d5aa"))
	header_row.add_child(_population_metric)
	_housing_metric = Label.new()
	_housing_metric.name = "HousingMetric"
	_housing_metric.text = "Жильё —"
	_housing_metric.tooltip_text = "Жильё и лимит из запросов города"
	_housing_metric.focus_mode = Control.FOCUS_ALL
	_apply_keyboard_focus(_housing_metric)
	_housing_metric.add_theme_color_override("font_color", Color("#e7d5aa"))
	header_row.add_child(_housing_metric)
	_city_level_button = Button.new()
	_city_level_button.name = "CityLevelProgression"
	_city_level_button.focus_mode = Control.FOCUS_ALL
	_city_level_button.tooltip_text = "Уровень и занятые клетки города"
	_apply_keyboard_focus(_city_level_button)
	_city_level_button.pressed.connect(level_up_pressed)
	header_row.add_child(_city_level_button)
	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.custom_minimum_size.x = 115
	header_row.add_child(_close_button)

	var workspace := HSplitContainer.new()
	workspace.name = "CityWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.split_offset = 350
	layout.add_child(workspace)

	_sidebar = PanelContainer.new()
	_sidebar.name = "BuildSidebar"
	_sidebar.custom_minimum_size = Vector2(330, 0)
	_sidebar.add_theme_stylebox_override("panel", _panel_style(Color("#1b1915"), Color("#665638")))
	workspace.add_child(_sidebar)
	var sidebar_box := VBoxContainer.new()
	sidebar_box.add_theme_constant_override("separation", 8)
	_sidebar.add_child(sidebar_box)
	var sidebar_header := HBoxContainer.new()
	sidebar_box.add_child(sidebar_header)
	_sidebar_title = Label.new()
	_sidebar_title.text = "СТРОИТЕЛЬСТВО"
	_sidebar_title.add_theme_font_size_override("font_size", 18)
	_sidebar_title.add_theme_color_override("font_color", Color("#e0bd67"))
	_sidebar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_header.add_child(_sidebar_title)
	_sidebar_button = Button.new()
	_sidebar_button.name = "SidebarToggle"
	_sidebar_button.text = "Свернуть"
	_sidebar_button.tooltip_text = "Свернуть или развернуть каталог зданий"
	_sidebar_button.focus_mode = Control.FOCUS_ALL
	sidebar_header.add_child(_sidebar_button)
	_category_tabs = HBoxContainer.new()
	_category_tabs.name = "CategoryTabs"
	_category_tabs.custom_minimum_size.y = 34
	_category_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_tabs.add_theme_constant_override("separation", 4)
	sidebar_box.add_child(_category_tabs)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.name = "CatalogScroll"
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_box.add_child(_catalog_scroll)
	var catalog_box := VBoxContainer.new()
	catalog_box.name = "CatalogCards"
	catalog_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_scroll.add_child(catalog_box)
	_catalog_placeholder = Label.new()
	_catalog_placeholder.text = "Каталог зданий"
	_catalog_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catalog_box.add_child(_catalog_placeholder)
	var placement_actions := HBoxContainer.new()
	placement_actions.name = "PlacementActions"
	sidebar_box.add_child(placement_actions)
	_cancel_build_button = Button.new()
	_cancel_build_button.name = "CancelPlacement"
	_cancel_build_button.text = "Отмена"
	_cancel_build_button.visible = false
	_cancel_build_button.focus_mode = Control.FOCUS_ALL
	_apply_keyboard_focus(_cancel_build_button)
	_cancel_build_button.pressed.connect(cancel_placement)
	placement_actions.add_child(_cancel_build_button)
	_confirm_build_button = Button.new()
	_confirm_build_button.name = "ConfirmPlacement"
	_confirm_build_button.text = "Построить"
	_confirm_build_button.tooltip_text = "Списать стоимость и поставить здание в очередь строительства"
	_confirm_build_button.visible = false
	_confirm_build_button.disabled = true
	_confirm_build_button.focus_mode = Control.FOCUS_ALL
	_apply_keyboard_focus(_confirm_build_button)
	_confirm_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_build_button.pressed.connect(_confirm_campaign_building)
	placement_actions.add_child(_confirm_build_button)

	var board_panel := PanelContainer.new()
	board_panel.name = "CityBoardPanel"
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.custom_minimum_size = Vector2(400, 360)
	var board_style := _panel_style(Color("#171915", 0.45), Color("#665638"))
	board_panel.add_theme_stylebox_override("panel", board_style)
	workspace.add_child(board_panel)
	var board_area := Control.new()
	board_area.name = "BoardArea"
	board_panel.add_child(board_area)
	_board_placeholder = Label.new()
	_board_placeholder.name = "BoardPlaceholder"
	_board_placeholder.text = "План города"
	_board_placeholder.add_theme_font_size_override("font_size", 28)
	_board_placeholder.add_theme_color_override("font_color", Color("#a99c7e"))
	_board_placeholder.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	board_area.add_child(_board_placeholder)
	_board = CampaignCityBoard.new()
	_board.name = "CampaignCityBoard"
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_area.add_child(_board)
	_board.cell_selected.connect(_on_board_cell_selected)
	_board.cell_hovered.connect(_on_board_cell_hovered)
	_inspector_panel = PanelContainer.new()
	_inspector_panel.name = "CityInspector"
	_inspector_panel.anchor_left = 0.0
	_inspector_panel.anchor_top = 1.0
	_inspector_panel.anchor_right = 0.0
	_inspector_panel.anchor_bottom = 1.0
	_inspector_panel.offset_left = 16.0
	_inspector_panel.offset_top = -190.0
	_inspector_panel.offset_right = 360.0
	_inspector_panel.offset_bottom = -16.0
	_inspector_panel.add_theme_stylebox_override("panel", _panel_style(Color("#211e18"), Color("#92743b")))
	board_area.add_child(_inspector_panel)
	var inspector_box := VBoxContainer.new()
	inspector_box.add_theme_constant_override("separation", 6)
	_inspector_panel.add_child(inspector_box)
	_inspector_title = Label.new()
	_inspector_title.name = "InspectorTitle"
	_inspector_title.add_theme_color_override("font_color", Color("#e0bd67"))
	inspector_box.add_child(_inspector_title)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_box.add_child(inspector_scroll)
	_inspector_text = Label.new()
	_inspector_text.name = "InspectorText"
	_inspector_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(_inspector_text)
	var legend := PanelContainer.new()
	legend.name = "TerrainLegend"
	legend.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	legend.position = Vector2(-205, -150)
	legend.custom_minimum_size = Vector2(190, 132)
	legend.add_theme_stylebox_override("panel", _panel_style(Color("#211e18"), Color("#92743b")))
	board_area.add_child(legend)
	var legend_box := VBoxContainer.new()
	legend_box.add_theme_constant_override("separation", 3)
	legend.add_child(legend_box)
	var legend_title := Label.new()
	legend_title.text = "РЕЛЬЕФ И КОЛЬЦА"
	legend_title.add_theme_color_override("font_color", Color("#e0bd67"))
	legend_box.add_child(legend_title)
	for row in ["Ядро", "Кольцо I", "Кольцо II", "Кольцо III"]:
		var legend_row := Label.new()
		legend_row.text = "◆  " + row
		legend_row.add_theme_color_override("font_color", Color("#e4ddce"))
		legend_box.add_child(legend_row)

	_legacy_panel = PanelContainer.new()
	_legacy_panel.name = "LegacyActionsPanel"
	_legacy_panel.visible = false
	_legacy_panel.add_theme_stylebox_override("panel", _panel_style(Color("#1b1915"), Color("#665638")))
	layout.add_child(_legacy_panel)
	var legacy_box := VBoxContainer.new()
	_legacy_panel.add_child(legacy_box)
	_stats_label = Label.new()
	_stats_label.name = "LegacyStats"
	_stats_label.visible = false
	legacy_box.add_child(_stats_label)
	_buildings_label = Label.new()
	_buildings_label.name = "LegacyBuildings"
	_buildings_label.visible = false
	legacy_box.add_child(_buildings_label)
	var legacy_scroll := ScrollContainer.new()
	legacy_scroll.custom_minimum_size.y = 54
	legacy_box.add_child(legacy_scroll)
	var legacy_buttons := HBoxContainer.new()
	legacy_buttons.name = "LegacyActions"
	legacy_buttons.add_theme_constant_override("separation", 6)
	_legacy_actions = legacy_buttons
	legacy_scroll.add_child(legacy_buttons)
	for action_name in ["BuildFarm", "BuildMine", "LevelUp", "Hire", "Unload", "Cart", "Recruit"]:
		var action := Button.new()
		action.name = action_name
		action.focus_mode = Control.FOCUS_ALL
		_apply_keyboard_focus(action)
		legacy_buttons.add_child(action)

	var footer := HBoxContainer.new()
	footer.name = "ScreenFooter"
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	_legacy_toggle = Button.new()
	_legacy_toggle.name = "LegacyToggle"
	_legacy_toggle.text = "Классические действия города ▾"
	_legacy_toggle.focus_mode = Control.FOCUS_ALL
	footer.add_child(_legacy_toggle)
	_message_label = Label.new()
	_message_label.name = "CityMessage"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.add_theme_color_override("font_color", Color("#d5cdbb"))
	footer.add_child(_message_label)

func _update_placement_controls() -> void:
	if not is_instance_valid(_confirm_build_button):
		return
	_confirm_build_button.visible = _placement_active
	_cancel_build_button.visible = _placement_active
	_confirm_build_button.disabled = not _placement_active or _preview_anchor.x < 0 \
		or not bool(_preview_result.get("ok", false))

func _confirm_campaign_building() -> void:
	if not _placement_active or _preview_anchor.x < 0 or _selected_building_id.is_empty():
		return
	var building_id := _selected_building_id
	var result := CampaignBuildingConstructionService.request(
		city, _campaign_catalog, building_id, _preview_anchor, _board.get_terrain_by_cell())
	if not bool(result.get("ok", false)):
		_preview_result = result
		_board.set_placement_preview(_find_campaign_building(building_id), _preview_anchor, false)
		var reasons := _placement_reasons(result)
		_inspector_title.text = "Строительство не принято"
		_inspector_text.text = "\n".join(reasons)
		_message_label.text = reasons[0] if not reasons.is_empty() else "Запрос отклонён"
		_update_placement_controls()
		_refresh_catalog_statuses()
		return
	var instance: Dictionary = result.instance
	_selected_cell = _preview_anchor
	_placement_active = false
	_selected_building_id = ""
	_preview_anchor = Vector2i(-1, -1)
	_preview_result.clear()
	_board.clear_placement_preview()
	refresh()
	var paid_costs: Dictionary = instance.get("paid_costs", {})
	_message_label.text = "Строительство принято: %s · списано %s · осталось %d ход(а)" % [
		String(instance.get("name", building_id)), _resource_map_text(paid_costs),
		int(instance.get("construction_turns_remaining", 0))]
	_update_placement_controls()

func _on_board_cell_selected(cell: Vector2i) -> void:
	_selected_cell = cell
	_board_placeholder.visible = false
	if _placement_active:
		_refresh_placement_preview(cell)
	else:
		_show_cell_inspector(cell)

func _on_board_cell_hovered(cell: Vector2i) -> void:
	if not _placement_active:
		return
	if cell == Vector2i(-1, -1):
		_preview_anchor = Vector2i(-1, -1)
		_preview_result.clear()
		_board.clear_placement_preview()
		_show_cell_inspector(_selected_cell)
		_update_placement_controls()
		return
	_refresh_placement_preview(cell)

func _refresh_placement_preview(anchor: Vector2i) -> void:
	if not _placement_active or city == null or _selected_building_id.is_empty():
		return
	_preview_anchor = anchor
	var definition := _find_campaign_building(_selected_building_id)
	_preview_result = CampaignBuildingConstructionService.explain_request(
		city, _campaign_catalog, _selected_building_id, anchor, _board.get_terrain_by_cell())
	_board.set_placement_preview(definition, anchor, bool(_preview_result.get("ok", false)))
	_inspector_title.text = "%s · предпросмотр" % String(definition.get("name", _selected_building_id))
	if bool(_preview_result.get("ok", false)):
		_inspector_text.text = "Размещение допустимо. Цена будет списана один раз после подтверждения."
		_message_label.text = "Место подходит · выберите клетку и подтвердите строительство"
	else:
		var reasons := _placement_reasons(_preview_result)
		_inspector_text.text = "\n".join(reasons)
		_message_label.text = reasons[0] if not reasons.is_empty() else "Размещение недоступно"
	_update_placement_controls()

func _placement_reasons(result: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	match String(result.get("reason", "")):
		"placement_blocked":
			for issue in result.get("issues", []):
				reasons.append(_placement_issue_label(String(issue)))
		"insufficient_stock":
			for resource_id in result.get("missing", {}):
				reasons.append("Не хватает %s %s" % [
					_resource_label(StringName(resource_id)), _format_amount(float(result.missing[resource_id]))])
		"city_capacity":
			reasons.append("Занято %d/%d клеток на уровне %d; свободно %d" % [
				int(result.get("used", 0)), int(result.get("limit", 0)),
				int(result.get("level", 1)), int(result.get("remaining", 0))])
		"prerequisite_missing":
			for issue in result.get("missing", []):
				reasons.append("Не выполнено: " + String(issue).replace("building:", "здание "))
		"":
			reasons.append("Размещение недоступно")
		_:
			reasons.append(String(result.get("reason", "Размещение недоступно")))
	return reasons

func _placement_issue_label(issue: String) -> String:
	return issue.replace("footprint cell", "Клетка").replace("is occupied", "занята") \
		.replace("is outside the 52-cell city", "вне 52 клеток города") \
		.replace("has disallowed terrain", "имеет неподходящий рельеф") \
		.replace("requires a special site", "требует особого места")

func cancel_placement() -> void:
	if not _placement_active:
		return
	_placement_active = false
	_selected_building_id = ""
	_preview_anchor = Vector2i(-1, -1)
	_preview_result.clear()
	_board.clear_placement_preview()
	_update_placement_controls()
	_message_label.text = "Размещение отменено"
	var card_list := _catalog_scroll.get_child(0)
	for card in card_list.get_children():
		if card is PanelContainer and String(card.name).begins_with("BuildingCard_"):
			card.add_theme_stylebox_override("panel", _panel_style(Color("#211e18"), Color("#665638")))
	_show_cell_inspector(_selected_cell)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _placement_active:
			cancel_placement()
		elif _legacy_panel.visible:
			_toggle_legacy_actions()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_resource_pressed(resource_id: StringName) -> void:
	_show_resource_ledger(resource_id)

func _update_campaign_hud() -> void:
	for resource_id in ResourceRegistry.CAMPAIGN_MVP_IDS:
		var button: Button = _resource_buttons[resource_id]
		var balance := "—" if city.resource_ctx == null else "%.1f" % city.resource_ctx.amount(resource_id)
		var net := _resource_net(resource_id)
		button.text = "%s  %s  %s" % [_resource_label(resource_id), balance, net]
	_population_metric.text = "Жители %d / %d" % [city.pop_total(), city.pop_cap()]
	_housing_metric.text = "Жильё %d" % city.housing_total()
	_city_level_button.visible = _is_campaign_city()
	if _city_level_button.visible:
		var used := CampaignCityProgression.occupied_cells(city).size()
		var limit := CampaignCityProgression.cell_limit(city.level)
		var progress := CampaignCityProgression.level_up_check(city)
		_city_level_button.text = "Город %d · %d/%d" % [city.level, used, limit]
		_city_level_button.disabled = city.level >= CampaignCityProgression.MAX_LEVEL
		if bool(progress.ok):
			_city_level_button.tooltip_text = "Повысить уровень города до %d" % (city.level + 1)
		elif String(progress.get("reason", "")) == "maximum_level":
			_city_level_button.tooltip_text = "Достигнут максимальный уровень города"
		else:
			_city_level_button.tooltip_text = "До повышения не хватает %d занятых клеток" % int(progress.get("missing", 0))

func _is_campaign_city() -> bool:
	if city == null:
		return false
	if hero != null and hero.city_manager != null and hero.city_manager.is_campaign:
		return true
	return not city.campaign_buildings.is_empty()

func _resource_net(resource_id: StringName) -> String:
	if city.resource_ctx == null:
		return "Δ —"
	var flows := city.resource_ctx.get_ledger()
	if flows.is_empty():
		return "Δ —"
	var net := 0.0
	for flow in flows:
		net += float(flow.get("outputs", {}).get(String(resource_id), 0.0))
		net -= float(flow.get("inputs", {}).get(String(resource_id), 0.0))
	return "Δ%+.1f" % net

func _show_resource_ledger(resource_id: StringName) -> void:
	_inspector_title.text = "%s · журнал" % _resource_label(resource_id)
	if city == null or city.resource_ctx == null:
		_inspector_text.text = "Баланс и журнал недоступны для этого города."
		return
	var lines: Array[String] = []
	for flow in city.resource_ctx.get_ledger():
		var inputs: Dictionary = flow.get("inputs", {})
		var outputs: Dictionary = flow.get("outputs", {})
		var amount_in := float(inputs.get(String(resource_id), 0.0))
		var amount_out := float(outputs.get(String(resource_id), 0.0))
		if amount_in == 0.0 and amount_out == 0.0:
			continue
		lines.append("%s  %s" % [String(flow.get("source", "")), _format_flow(amount_in, amount_out)])
	_inspector_text.text = "\n".join(lines) if not lines.is_empty() else "Нет записей по этому ресурсу в журнале."

func _format_flow(inputs: float, outputs: float) -> String:
	var parts: Array[String] = []
	if inputs > 0.0:
		parts.append("−%.1f" % inputs)
	if outputs > 0.0:
		parts.append("+%.1f" % outputs)
	return " / ".join(parts)

func _show_cell_inspector(cell: Vector2i) -> void:
	if city == null:
		return
	var visual := _board.get_cell_visual(cell)
	_inspector_title.text = "Клетка %d, %d · %s" % [cell.x, cell.y,
		"ядро" if int(visual.get("ring", -1)) == 0 else "кольцо %d" % int(visual.get("ring", -1))]
	var terrain_name := String(visual.get("terrain_name", ""))
	var lines: Array[String] = ["Рельеф: " + (terrain_name if not terrain_name.is_empty() else "недоступен")]
	var campaign_id := String(visual.get("campaign_building_id", ""))
	var legacy_id := String(visual.get("legacy_building_id", ""))
	if not campaign_id.is_empty():
		var instance := _campaign_instance_at(cell)
		var definition := _find_campaign_building(campaign_id)
		lines.append("Кампанийное здание: " + String(definition.get("name", campaign_id)))
		var roles: Array[String] = []
		for role in definition.get("roles", []):
			roles.append(_role_label(String(role)))
		lines.append("Роли: " + " · ".join(roles))
		var paid_costs: Dictionary = instance.get("paid_costs", definition.get("costs", {}))
		lines.append("Стоимость: " + _resource_map_text(paid_costs))
		var upkeep_data: Dictionary = instance.get("upkeep", definition.get("upkeep", {}))
		if not upkeep_data.is_empty():
			var upkeep_label := "Содержание: " if String(instance.get("state", "active")) == "active" \
				and int(instance.get("construction_turns_remaining", 0)) == 0 else "Содержание при работе: "
			lines.append(upkeep_label + _resource_map_text(upkeep_data) + " / ход")
		lines.append("Состояние: " + _building_state_label(String(instance.get("state", "active"))))
		var remaining := int(instance.get("construction_turns_remaining", 0))
		if remaining > 0:
			var total := int(instance.get("construction_turns", definition.get("construction_turns", remaining)))
			lines.append("Строительство: %d/%d ход(а)" % [maxi(0, total - remaining), total])
		else:
			_append_campaign_building_effects(instance, cell, lines)
	elif not legacy_id.is_empty():
		lines.append("Классическое здание: " + legacy_id)
	else:
		lines.append("Свободная клетка" if not bool(visual.get("occupied", false)) else "Занято")
	for group_line in _persisted_group_satisfaction_lines():
		lines.append(group_line)
	_inspector_text.text = "\n".join(lines)

func _building_state_label(state: String) -> String:
	match state:
		"active": return "действует"
		"inactive": return "неактивно"
		"ruined": return "разрушено"
	return state

func _campaign_instance_at(cell: Vector2i) -> Dictionary:
	for instance in city.campaign_buildings:
		if not (instance is Dictionary):
			continue
		var footprint := CampaignBuildingPlacement.footprint_cells(
			instance.get("cell", Vector2i.ZERO), instance.get("footprint", [[0, 0]]))
		if footprint.is_empty():
			footprint = [instance.get("cell", Vector2i.ZERO)]
		if footprint.has(cell):
			return instance
	return {}

func _append_campaign_building_effects(instance: Dictionary, cell: Vector2i, lines: Array[String]) -> void:
	if String(instance.get("state", "active")) != "active":
		return
	for need_id in instance.get("services", {}):
		var amount := float(instance.services[need_id])
		if amount > 0.0:
			lines.append("Услуга %s · %s" % [_service_label(String(need_id)), _format_amount(amount)])
	for training in instance.get("training", []):
		var class_id := str(training.get("class_id", "")) if training is Dictionary else str(training)
		lines.append("Подготовка: " + class_id)
	var adjacency_result := _adjacency_result_for(instance, cell)
	var effects: Dictionary = adjacency_result.get("breakdown", {}).get("effects", {})
	for effect in effects:
		var value := float(effects[effect])
		lines.append("Эффект соседства: %s %s" % [_effect_label(String(effect)), _format_percent(value)])
	for cause in adjacency_result.get("breakdown", {}).get("causes", []):
		var source := _find_campaign_building(String(cause.get("source_id", "")))
		lines.append("Причина: %s · %s · (%d,%d)" % [
			String(source.get("name", cause.get("source_id", ""))),
			String(cause.get("rule_id", "")), cause.source_cell.x, cause.source_cell.y])
	var uid := int(instance.get("uid", -1))
	for contribution in CampaignDefenseResolver.explain(city.campaign_buildings).get("contributions", []):
		if int(contribution.get("building_uid", -2)) == uid:
			lines.append("Оборона: %d" % int(contribution.get("defense", 0)))
	var source_prefix := "campaign-building:%s/recipe:" % String(instance.get("id", ""))
	for flow in city.resource_ctx.get_ledger() if city.resource_ctx != null else []:
		var source := String(flow.get("source", ""))
		if not source.begins_with(source_prefix):
			continue
		var inputs: Dictionary = flow.get("inputs", {})
		var outputs: Dictionary = flow.get("outputs", {})
		lines.append("Производство %s: %s → %s" % [
			source.trim_prefix(source_prefix), _resource_map_text(inputs), _resource_map_text(outputs)])

func _adjacency_result_for(instance: Dictionary, cell: Vector2i) -> Dictionary:
	for result in CampaignBuildingPlacement.recompute_adjacency(city.campaign_buildings):
		if String(result.get("building_id", "")) == String(instance.get("id", "")) \
				and result.get("cell", Vector2i.ZERO) == cell:
			return result
	return {}

func _service_label(id: String) -> String:
	var labels := {"community_mediation": "медиация", "religion": "религия",
		"treatment": "лечение", "education": "обучение", "market_access": "рынок",
		"water": "вода"}
	return String(labels.get(id, id.replace("_", " ")))

func _effect_label(id: String) -> String:
	match id:
		"output_bp": return "выпуск"
	return id.replace("_", " ")

func _format_percent(value_bp: float) -> String:
	return "%+.0f%%" % (value_bp / 100.0)

func _format_amount(amount: float) -> String:
	return "%.1f" % amount if floor(amount) != amount else "%.0f" % amount

func _resource_map_text(resources: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in resources:
		parts.append("%s %s" % [_resource_label(StringName(resource_id)), _format_amount(float(resources[resource_id]))])
	return " · ".join(parts) if not parts.is_empty() else "—"

func _persisted_group_satisfaction_lines() -> Array[String]:
	var lines: Array[String] = []
	if city == null:
		return lines
	var present_groups := {}
	for person in city.pop:
		var group_id := ArchetypeResolver.group_id_for_identity(
			_mvp_catalog, String(person.ancestry_id), String(person.archetype_id))
		if not group_id.is_empty():
			present_groups[group_id] = true
	for group_id in present_groups:
		var state: Variant = city.campaign_group_state.get(group_id, {})
		if not (state is Dictionary) or not state.has("satisfaction"):
			continue
		var group := ArchetypeResolver.get_group(_mvp_catalog, group_id)
		lines.append("%s · удовлетворённость %d%%" % [
			String(group.get("name", group_id)), int(state.satisfaction)])
	return lines

func _initialize_campaign_catalog() -> void:
	_campaign_catalog = CampaignBuildingCatalog.load_catalog()
	var errors := CampaignBuildingCatalog.validate_catalog(_campaign_catalog, _campaign_catalog_references())
	if not errors.is_empty():
		_catalog_error = "; ".join(errors)
		_catalog_placeholder.text = "Каталог кампании недоступен: ошибка проверки"
		_category_tabs.disabled = true
		push_error("Campaign city catalog validation failed: %s" % _catalog_error)
		return
	var roles := {}
	for building in _campaign_catalog.get("buildings", []):
		for role in building.get("roles", []):
			roles[String(role)] = true
	for child in _category_tabs.get_children():
		_category_tabs.remove_child(child)
		child.queue_free()
	_category_buttons.clear()
	_visible_catalog_categories.clear()
	for category in CATALOG_CATEGORIES:
		var has_available_role: bool = category.roles.is_empty()
		for role in category.roles:
			if roles.has(String(role)):
				has_available_role = true
				break
		if not has_available_role:
			continue
		var category_index := _visible_catalog_categories.size()
		_visible_catalog_categories.append(category)
		var tab := Button.new()
		tab.text = String(category.title)
		tab.toggle_mode = true
		tab.button_pressed = category_index == 0
		tab.custom_minimum_size.y = 30
		tab.focus_mode = Control.FOCUS_ALL
		tab.add_theme_font_size_override("font_size", 12)
		tab.add_theme_color_override("font_color", PALETTE.text_muted)
		tab.add_theme_color_override("font_pressed_color", PALETTE.accent_gold)
		tab.add_theme_color_override("font_hover_color", PALETTE.text_primary)
		var idle := StyleBoxFlat.new()
		idle.bg_color = Color("#211e18", 0.45)
		idle.border_color = Color("#665638")
		idle.set_border_width_all(1)
		idle.set_corner_radius_all(4)
		var active := StyleBoxFlat.new()
		active.bg_color = Color("#392f1d")
		active.border_color = PALETTE.accent_gold
		active.set_border_width_all(1)
		active.set_corner_radius_all(4)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			tab.add_theme_stylebox_override(state, active if state in ["pressed", "hover_pressed"] else idle)
		_apply_keyboard_focus(tab)
		tab.pressed.connect(_on_category_tab_pressed.bind(category_index))
		_category_tabs.add_child(tab)
		_category_buttons.append(tab)
	_selected_category_index = 0

func _campaign_catalog_references() -> Dictionary:
	var groups: Array[String] = []
	var needs: Array[String] = ["community_mediation"]
	var classes: Array[String] = []
	for group in _mvp_catalog.get("groups", []):
		groups.append(String(group.get("id", "")))
		var need := String(group.get("signature_need", ""))
		if not need.is_empty() and not needs.has(need):
			needs.append(need)
	for record in _mvp_catalog.get("classes", []):
		if bool(record.get("hireable", false)):
			classes.append(String(record.get("id", "")))
	return {
		"resources": ResourceRegistry.CAMPAIGN_MVP_IDS.map(func(id): return String(id)),
		"groups": groups,
		"needs": needs,
		"trainable_classes": classes,
		"terrain_tags": [],
		"scenario_flags": [],
	}

func _role_label(role: String) -> String:
	var labels := {
		"food_production": "Еда", "agriculture": "Земледелие",
		"wood_production": "Дерево", "woodworking": "Обработка дерева",
		"iron_production": "Железо", "metalworking": "Металл",
		"housing": "Жильё", "administration": "Управление",
		"community_service": "Общественные службы", "education": "Обучение",
		"education_service": "Образование", "health_service": "Здоровье",
		"herbal_service": "Травничество", "military_training": "Военная подготовка",
		"religious_service": "Религия", "static_defense": "Оборона",
		"water_service": "Вода",
	}
	return String(labels.get(role, role.replace("_", " ").capitalize()))

func _on_category_tab_pressed(index: int) -> void:
	_selected_category_index = index
	for tab_index in range(_category_buttons.size()):
		_category_buttons[tab_index].button_pressed = tab_index == index
	call_deferred("_render_catalog_cards")

func _selected_category_roles() -> Array:
	if _visible_catalog_categories.is_empty():
		return []
	var index := clampi(_selected_category_index, 0, _visible_catalog_categories.size() - 1)
	return _visible_catalog_categories[index].roles

func _render_catalog_cards() -> void:
	if _campaign_catalog.is_empty() or city == null:
		return
	var card_list := _catalog_scroll.get_child(0) as VBoxContainer
	for child in card_list.get_children():
		if child != _catalog_placeholder:
			card_list.remove_child(child)
			child.queue_free()
	_catalog_placeholder.visible = false
	var selected_roles := _selected_category_roles()
	for definition in _campaign_catalog.get("buildings", []):
		if not selected_roles.is_empty():
			var matches_category := false
			for role in definition.get("roles", []):
				if selected_roles.has(String(role)):
					matches_category = true
					break
			if not matches_category:
				continue
		card_list.add_child(_make_building_card(definition))
	_catalog_placeholder.visible = card_list.get_child_count() == 1
	_catalog_placeholder.text = "Нет зданий в этой категории" if not _catalog_placeholder.visible else _catalog_placeholder.text
	_catalog_rendered = true

func _make_building_card(definition: Dictionary) -> PanelContainer:
	var building_id := String(definition.get("id", ""))
	var card := PanelContainer.new()
	card.name = "BuildingCard_" + building_id
	card.custom_minimum_size.y = 172.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := building_id == _selected_building_id
	card.add_theme_stylebox_override("panel", _panel_style(
		Color("#29241b") if selected else Color("#211e18"),
		Color("#d3ae5d") if selected else Color("#665638")))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	box.add_child(heading)
	var icon := TextureRect.new()
	icon.name = "BuildingIcon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = CampaignCityBoard.building_art_texture(building_id)
	if icon.texture == null:
		var icon_id := CampaignCityBoard.icon_id_for_building(building_id, _campaign_catalog)
		icon.texture = BuildingDefs.get_icon(StringName(icon_id))
	heading.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	heading.add_child(details)
	var select := Button.new()
	select.name = "SelectBuilding"
	select.text = String(definition.get("name", building_id))
	select.tooltip_text = "%s\n%s\n%s" % [select.text, _building_cost_text(definition), _building_effect_summary(definition)]
	select.focus_mode = Control.FOCUS_ALL
	select.flat = true
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.add_theme_font_size_override("font_size", 17)
	select.add_theme_color_override("font_color", PALETTE.text_primary)
	select.add_theme_color_override("font_hover_color", PALETTE.accent_gold)
	select.add_theme_color_override("font_pressed_color", PALETTE.accent_gold)
	_apply_keyboard_focus(select)
	select.pressed.connect(_on_building_card_pressed.bind(building_id))
	details.add_child(select)
	var roles: Array[String] = []
	for role in definition.get("roles", []):
		roles.append(_role_label(String(role)))
	var role_line := Label.new()
	role_line.text = " · ".join(roles).to_upper()
	role_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_line.add_theme_font_size_override("font_size", 11)
	role_line.add_theme_color_override("font_color", PALETTE.text_muted)
	details.add_child(role_line)

	var cost_panel := PanelContainer.new()
	cost_panel.name = "BuildingCostPanel"
	var cost_style := StyleBoxFlat.new()
	cost_style.bg_color = Color("#392f1d")
	cost_style.border_color = Color("#b28b42")
	cost_style.set_border_width_all(1)
	cost_style.set_corner_radius_all(4)
	cost_style.content_margin_left = 8
	cost_style.content_margin_top = 5
	cost_style.content_margin_right = 8
	cost_style.content_margin_bottom = 5
	cost_panel.add_theme_stylebox_override("panel", cost_style)
	box.add_child(cost_panel)
	var cost_row := HBoxContainer.new()
	cost_row.name = "BuildingCost"
	cost_row.add_theme_constant_override("separation", 8)
	cost_panel.add_child(cost_row)
	var cost_caption := Label.new()
	cost_caption.name = "CostCaption"
	cost_caption.text = "СТОИМОСТЬ"
	cost_caption.add_theme_font_size_override("font_size", 10)
	cost_caption.add_theme_color_override("font_color", PALETTE.text_muted)
	cost_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_child(cost_caption)
	var costs: Dictionary = definition.get("costs", {})
	if costs.is_empty():
		var free_label := Label.new()
		free_label.text = "БЕСПЛАТНО"
		free_label.add_theme_color_override("font_color", PALETTE.accent_gold)
		cost_row.add_child(free_label)
	else:
		for resource_id in costs:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 3)
			var resource_texture := _resource_icon(StringName(resource_id))
			if resource_texture != null:
				var resource_icon := TextureRect.new()
				resource_icon.custom_minimum_size = Vector2(18, 18)
				resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				resource_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				resource_icon.texture = resource_texture
				item.add_child(resource_icon)
			var amount := Label.new()
			amount.name = "CostAmount_" + String(resource_id)
			amount.text = _format_amount(float(costs[resource_id]))
			amount.add_theme_font_size_override("font_size", 16)
			amount.add_theme_color_override("font_color", PALETTE.accent_gold)
			item.add_child(amount)
			cost_row.add_child(item)

	var effect_line := Label.new()
	effect_line.name = "BuildingEffects"
	effect_line.text = _building_effect_summary(definition)
	effect_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_line.add_theme_font_size_override("font_size", 13)
	effect_line.add_theme_color_override("font_color", PALETTE.text_body)
	box.add_child(effect_line)
	var prerequisite_line := Label.new()
	prerequisite_line.name = "BuildingPrerequisites"
	prerequisite_line.text = _building_prerequisite_text(definition)
	prerequisite_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prerequisite_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prerequisite_line.add_theme_font_size_override("font_size", 12)
	prerequisite_line.add_theme_color_override("font_color", PALETTE.text_muted)
	box.add_child(prerequisite_line)
	var status_line := Label.new()
	status_line.name = "BuildingAvailability"
	status_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_line.add_theme_font_size_override("font_size", 12)
	box.add_child(status_line)
	_update_building_availability(status_line, definition)
	return card

func _update_building_availability(status_line: Label, definition: Dictionary) -> void:
	var status := _building_status(definition)
	status_line.text = "%s · %s" % [
		"Строительство: %d ход(а)" % int(definition.get("construction_turns", 0)),
		String(status.reason) if not bool(status.ok) else "Требования выполнены"]
	status_line.add_theme_color_override("font_color",
		Color("#e8a17c") if not bool(status.ok) else Color("#91c992"))

func _refresh_catalog_statuses() -> void:
	if _campaign_catalog.is_empty() or city == null:
		return
	var card_list := _catalog_scroll.get_child(0)
	for card in card_list.get_children():
		if not (card is PanelContainer) or not String(card.name).begins_with("BuildingCard_"):
			continue
		var building_id := String(card.name).trim_prefix("BuildingCard_")
		var status_line := _find_named_node(card, "BuildingAvailability") as Label
		var definition := _find_campaign_building(building_id)
		if status_line != null and not definition.is_empty():
			_update_building_availability(status_line, definition)

func _find_named_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_named_node(child, target_name)
		if found != null:
			return found
	return null

func _building_cost_text(definition: Dictionary) -> String:
	var costs: Dictionary = definition.get("costs", {})
	if costs.is_empty():
		return "Стоимость: нет"
	var parts: Array[String] = []
	for resource_id in costs:
		parts.append("%s %s" % [_resource_label(StringName(resource_id)), costs[resource_id]])
	return "Стоимость: " + " · ".join(parts)

func _building_effect_summary(definition: Dictionary) -> String:
	var effects: Array[String] = []
	for recipe in definition.get("recipes", []):
		if not (recipe is Dictionary):
			continue
		var outputs: Dictionary = recipe.get("outputs", {})
		var inputs: Dictionary = recipe.get("inputs", {})
		var flow := "%s → %s" % [_resource_map_text(inputs), _resource_map_text(outputs)]
		effects.append("Рецепт (%d мест): %s" % [int(recipe.get("workers", 0)), flow])
	for need_id in definition.get("services", {}):
		if float(definition.services[need_id]) > 0.0:
			effects.append("Услуга %s · %s" % [_service_label(String(need_id)), _format_amount(float(definition.services[need_id]))])
	var defense: Dictionary = definition.get("defense", {})
	if int(defense.get("active", 0)) > 0:
		effects.append("Оборона %d" % int(defense.active))
	for class_record in definition.get("training", []):
		var class_id := str(class_record.get("class_id", "")) if class_record is Dictionary else str(class_record)
		effects.append("Подготовка: " + class_id)
	if effects.is_empty():
		return "Эффекты: нет"
	return "Эффекты: " + " · ".join(effects)

func _building_prerequisite_text(definition: Dictionary) -> String:
	var prerequisites: Dictionary = definition.get("prerequisites", {})
	var requirements: Array[String] = []
	for building_id in prerequisites.get("buildings", []):
		var required := _find_campaign_building(String(building_id))
		requirements.append(String(required.get("name", building_id)))
	for flag in prerequisites.get("scenario_flags", []):
		requirements.append("событие " + String(flag))
	var admin_capacity := int(prerequisites.get("admin_capacity", 0))
	if admin_capacity > 0:
		requirements.append("административная ёмкость %d" % admin_capacity)
	return "Требования: " + ("нет" if requirements.is_empty() else " · ".join(requirements))

func _building_status(definition: Dictionary) -> Dictionary:
	var built_ids: Array[String] = []
	for instance in city.campaign_buildings:
		if not (instance is Dictionary):
			continue
		if int(instance.get("construction_turns_remaining", 0)) > 0 \
				or String(instance.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(instance.get("id", "")))
	var prerequisite := CampaignBuildingCatalog.check_prerequisites(
		definition, built_ids, [], 0)
	if not bool(prerequisite.ok):
		var missing: Array[String] = []
		for issue in prerequisite.missing:
			missing.append("не выполнено: " + String(issue).replace("building:", "здание "))
		return {"ok": false, "reason": "; ".join(missing)}
	var missing_costs: Array[String] = []
	for resource_id in definition.get("costs", {}):
		var available := city.resource_ctx.amount(StringName(resource_id)) \
			if city.resource_ctx != null else city.food_stockpile if String(resource_id) == "food" else 0.0
		var shortfall := float(definition.costs[resource_id]) - available
		if shortfall > 0.0001:
			missing_costs.append("%s %s" % [_resource_label(StringName(resource_id)), "%.1f" % shortfall])
	if not missing_costs.is_empty():
		return {"ok": false, "reason": "Не хватает: " + " · ".join(missing_costs)}
	return {"ok": true, "reason": ""}

func _on_building_card_pressed(building_id: String) -> void:
	_selected_building_id = building_id
	_placement_active = true
	var definition := _find_campaign_building(building_id)
	_message_label.text = "Выбрано: %s · строительство %d ход(а)" % [
		String(definition.get("name", building_id)), int(definition.get("construction_turns", 0))]
	var card_list := _catalog_scroll.get_child(0)
	for card in card_list.get_children():
		if card is PanelContainer and String(card.name).begins_with("BuildingCard_"):
			var selected := String(card.name) == "BuildingCard_" + building_id
			card.add_theme_stylebox_override("panel", _panel_style(
				Color("#29241b") if selected else Color("#211e18"),
				Color("#d3ae5d") if selected else Color("#665638")))
	if _selected_cell.x >= 0:
		_refresh_placement_preview(_selected_cell)
	_update_placement_controls()

func _find_campaign_building(building_id: String) -> Dictionary:
	for definition in _campaign_catalog.get("buildings", []):
		if String(definition.get("id", "")) == building_id:
			return definition
	return {}

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _resource_label(id: StringName) -> String:
	match id:
		&"food": return "Еда"
		&"wood": return "Дерево"
		&"iron": return "Железо"
	return String(id)

func _toggle_legacy_actions() -> void:
	_legacy_panel.visible = not _legacy_panel.visible
	_legacy_toggle.text = "Классические действия города %s" % ("▴" if _legacy_panel.visible else "▾")

func _toggle_sidebar() -> void:
	_sidebar_override = true
	_set_sidebar_collapsed(not _sidebar_collapsed)

func _set_sidebar_collapsed(value: bool) -> void:
	_sidebar_collapsed = value
	_sidebar.custom_minimum_size.x = 62.0 if value else 330.0
	_sidebar_title.visible = not value
	_category_tabs.visible = not value
	_catalog_scroll.visible = not value
	_sidebar_button.text = "Каталог" if value else "Свернуть"

func _on_screen_resized() -> void:
	if not _sidebar_override and is_instance_valid(_sidebar):
		var effective_width := size.x
		var window := get_window()
		if window != null:
			effective_width = minf(effective_width, window.size.x)
		_set_sidebar_collapsed(effective_width < 1450.0)

func setup(c: City, h: HeroController, h_cell: Vector2i,
		r: RandomNumberGenerator = null, m_bounds: Vector2i = Vector2i.ZERO,
		terrain_fn: Callable = Callable()) -> void:
	city = c
	hero = h
	hero_cell = h_cell
	rng = r
	map_bounds = m_bounds
	terrain_provider = terrain_fn
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

func refresh() -> void:
	if city == null or not is_instance_valid(city):
		return
	_title_label.text = city.display_name
	var lines: Array[String] = []
	lines.append(GameText.city_population_detail(str(city.pop_capped()), city.free_followers()))
	lines.append(GameText.city_food_netto("%.0f" % city.food_stockpile, "%+.1f" % city.net_food()))
	lines.append(GameText.city_industry_gold("%.0f" % _storage_industry(), "%.0f" % _gold()))
	lines.append(GameText.city_prosperity_reputation("%.0f" % city.prosperity, city.reputation))
	if hero != null and hero.strategic_resources != null:
		var w: float = hero.strategic_resources.current_weight()
		var cap: float = hero.strategic_resources.weight_cap
		lines.append("Рюкзак: %.1f / %.1f" % [w, cap])
	if hero != null:
		var cha: int = int(hero.stats.get("cha", 2))
		var tier: int = WeaponTechService.city_weapon_tier(city, cha)
		var cap: int = mini(LeadershipCheck.max_army_stacks(cha), GameNumbers.HERO_ARMY_MAX_STACKS)
		lines.append("Технологии: тир %d | Отряд: %d/%d" % [tier, hero.get_army().army.size() if hero.get_army() != null else 0, cap])
	_stats_label.text = "\n".join(lines)
	var b_lines: Array[String] = []
	for building in city.buildings:
		if building == null or building.def == null:
			continue
		b_lines.append(GameText.city_building_line(building.def.display_name, building.level, building.cell.x, building.cell.y))
	_buildings_label.text = (GameText.city_buildings() + ":\n" + "\n".join(b_lines)) \
		if not b_lines.is_empty() else GameText.city_buildings_none()
	if _message_label.text == "":
		_message_label.text = GameText.city_intro()
	_sidebar_button.visible = true
	_board.bind_city(city, _campaign_catalog, terrain_provider)
	_board.set_selection(_selected_cell if _selected_cell.x >= 0 else city.center)
	_update_campaign_hud()
	if _catalog_rendered:
		_refresh_catalog_statuses()
	else:
		_render_catalog_cards()
	if _selected_cell.x < 0:
		_selected_cell = city.center
	_show_cell_inspector(_selected_cell)

func _on_build_farm_pressed() -> void:
	build_pressed(&"farm")

func _on_build_mine_pressed() -> void:
	build_pressed(&"mine")

func _on_level_up_pressed() -> void:
	level_up_pressed()

func _on_hire_pressed() -> void:
	hire_pressed()

func build_pressed(def_id: StringName) -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	var def := BuildingDefs.def_by_id(def_id)
	if def == null:
		return _fail(GameText.city_building_not_found(str(def_id)))
	var cell := city.first_free_build_cell(def, map_bounds)
	if cell == Vector2i(-1, -1):
		return _fail(GameText.city_no_cell())
	var check: CityCheck = city.can_build_building(def, cell)
	if not check.ok:
		return _fail(GameText.city_cannot_build(str(check.reason if check.reason != "" else "?")))
	var bld := city.build_building(def, cell)
	if bld == null:
		return _fail(GameText.city_build_failed())
	_set_message(GameText.city_built(def.display_name, cell.x, cell.y, _format_cost(def)))
	refresh()
	return CityCheck.success({"building": String(def_id), "level": bld.level,
		"cell": SerializationUtils.vec2i_to_dict(cell),
		"industry_left": _storage_industry()})

func level_up_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if _is_campaign_city():
		var level_check := CampaignCityProgression.try_level_up(city)
		if not bool(level_check.get("ok", false)):
			var reason := String(level_check.get("reason", ""))
			if reason == "maximum_level":
				return _fail("Достигнут максимальный уровень города")
			return _fail("Для повышения уровня нужно занять ещё %d клетки (%d/%d)" % [
				int(level_check.get("missing", 0)), int(level_check.get("used", 0)),
				int(level_check.get("limit", 0))])
		_set_message("Уровень города повышен до %d · лимит %d клеток" % [
			int(level_check.level), int(level_check.limit)])
		refresh()
		return CityCheck.success({"level": city.level, "occupied_cells": int(level_check.used),
			"cell_limit": int(level_check.limit)})
	if city.level >= GameNumbers.CITY_LEVEL_MAX:
		return _fail(GameText.city_max_level())
	var check: Dictionary = ProsperitySystem.can_level_up(city)
	if not bool(check.get("ok", false)):
		return _fail(GameText.city_cannot_upgrade("; ".join(check.get("reasons", []))))
	var prev_level := city.level
	if not ProsperitySystem.try_level_up(city):
		return _fail(GameText.city_upgrade_failed())
	_set_message(GameText.city_upgraded(prev_level, city.level))
	refresh()
	return CityCheck.success({"level": city.level})

func hire_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null:
		return _fail(GameText.city_hire_no_hero())
	# social-stats-weapon-tech: найм — договорная сделка (обман)
	var dec: Dictionary = _deception("contract")
	if bool(dec.get("deceived", false)) and int(dec.get("severity", 1)) >= 3:
		ReputationSystem.apply(city, -10)
		_set_message(str(dec.get("note", "")))
		refresh()
		return _fail(GameText.city_no_followers())
	var f := FollowerSystem.recruit(city, hero, rng)
	if f == null:
		return _fail(GameText.city_no_followers())
	_set_message(GameText.city_hired(f.describe(FollowerSystem.registry())))
	refresh()
	return CityCheck.success({"follower": f.to_dict()})

func _on_unload_pressed() -> void:
	unload_pressed()

func _on_cart_pressed() -> void:
	buy_cart_pressed()

## Ранняя игра: выгрузка рюкзака в хранилище города (early-game-foundation)
func unload_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null or hero.strategic_resources == null:
		return _fail(GameText.city_hire_no_hero())
	var all: Dictionary = hero.strategic_resources.get_all()
	var moved := 0
	for id in all:
		var amount: int = int(all[id])
		if amount <= 0:
			continue
		var actual: int = hero.remove_strategic_resource(id, amount)
		if actual > 0:
			city.storage[id] = float(city.storage.get(id, 0.0)) + float(actual)
			moved += actual
	if moved == 0:
		return _fail(GameText.city_unload_empty())
	city.storage_changed.emit()
	_set_message(GameText.city_unloaded(moved))
	refresh()
	return CityCheck.success({"moved": moved})

## Ранняя игра: рыночная телега — расширение рюкзака (early-game-foundation)
func buy_cart_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null or hero.strategic_resources == null:
		return _fail(GameText.city_hire_no_hero())
	if not _has_market():
		return _fail(GameText.city_cart_no_market())
	var message := ""
	var cost: float = GameNumbersHero.BACKPACK_CART_COST
	# social-stats-weapon-tech: покупка телеги — важная сделка (обман)
	var dec: Dictionary = _deception("purchase")
	if bool(dec.get("deceived", false)):
		var sev: int = int(dec.get("severity", 1))
		var surcharge: float = float(GameNumbers.DECEPTION_SEVERITIES[sev].get("surcharge", 0.15))
		cost = cost * (1.0 + surcharge)
		if sev >= 3 and city != null:
			ReputationSystem.apply(city, -10)  # кабальный договор
		message += " %s" % str(dec.get("note", ""))
	elif bool(dec.get("revealed", false)):
		message += " %s" % str(dec.get("note", ""))
	else:
		cost = cost * (1.0 - float(dec.get("discount", 0.0)))
	if _storage_industry() < cost:
		return _fail(GameText.city_cart_no_funds(cost))
	city.storage[&"industry"] = _storage_industry() - cost
	city.storage_changed.emit()
	hero.strategic_resources.capacity_bonus += GameNumbersHero.BACKPACK_CART_BONUS
	_set_message((GameText.city_cart_bought(hero.strategic_resources.total_cap()) + message).strip_edges())
	refresh()
	return CityCheck.success({"cap": hero.strategic_resources.total_cap()})

## Ранняя игра: военная рекрутка (early-game-foundation)
func _on_recruit_pressed() -> void:
	recruit_pressed()

func recruit_pressed() -> CityCheck:
	if city == null:
		return _fail(GameText.city_not_bound())
	if hero == null:
		return _fail(GameText.city_hire_no_hero())
	var bld: UniqueBuilding = null
	for b in city.buildings:
		if b != null and b.def != null and not b.def.military_chain.is_empty():
			bld = b
			break
	if bld == null:
		return _fail(GameText.city_recruit_no_building())
	var check: CityCheck = CityService.recruit_military(city, bld, hero)
	if not check.ok:
		return _fail(GameText.city_cannot_recruit(str(check.reason)))
	city.storage_changed.emit()
	_set_message(GameText.city_recruited(String(check.payload.get("unit", "")),
		int(check.payload.get("count", 0)), int(check.payload.get("tier", 1))))
	refresh()
	return check

func _has_market() -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"market":
			return true
	return false


func _on_close_pressed() -> void:
	close_requested.emit()

func _fail(message: String) -> CityCheck:
	_set_message(message)
	return CityCheck.fail(message)

## social-stats-weapon-tech: бросок обмана по статам героя; мелкая торговля не проверяется
func _deception(kind: String) -> Dictionary:
	if hero == null:
		return {"deceived": false, "severity": 0, "note": "", "discount": 0.0, "revealed": false}
	var s: Dictionary = hero.stats
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var base: int = int(GameNumbers.DECEPTION_BASE.get(kind, 10))
	return DeceptionCheck.roll(r,
		int(s.get("int", 2)), int(s.get("wis", 2)),
		int(s.get("cha", 2)), int(s.get("luk", 2)),
		base, 14)

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
		parts.append(GameText.city_cost_industry("%.0f" % req.industry))
	if req.special_amount > 0.0:
		parts.append(GameText.city_cost_special(str(req.special_resource), "%.0f" % req.special_amount))
	if req.followers > 0:
		parts.append(GameText.city_cost_followers(req.followers))
	return ", ".join(parts) if not parts.is_empty() else GameText.city_cost_free()
