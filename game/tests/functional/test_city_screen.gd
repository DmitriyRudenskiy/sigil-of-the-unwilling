extends BaseTest



var screen: CityScreen = null
var city: RefCounted = null
var hero: Node2D = null

func _main_root() -> Node:
	return Engine.get_main_loop().root

func before_test() -> void:
	screen = load("res://scenes/ui/city_screen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	city = City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	city.storage[&"industry"] = 30.0
	hero = HeroController.new()
	hero.name = "Hero"
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))

func after_test() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	if hero != null and is_instance_valid(hero):
		hero.queue_free()
	await get_tree().process_frame
	screen = null
	hero = null
	city = null

func test_setup_binds_city_and_hero() -> void:
	assert_that(screen.city).is_equal(city)
	assert_that(screen.hero).is_equal(hero)
	assert_bool(screen.is_open()).is_false()
	screen.open()
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.visible).is_true()
	screen.close()
	assert_bool(screen.is_open()).is_false()
	assert_bool(screen.visible).is_false()

func test_close_button_emits_close_requested() -> void:
	var emitted: Array = [false]
	screen.close_requested.connect(func(): emitted[0] = true)
	var btn := screen.get_node("ScreenMargin/ScreenLayout/ScreenHeader/HeaderRow/Close") as Button
	assert_that(btn).is_not_null()
	btn.emit_signal("pressed")
	assert_bool(emitted[0]).is_true()

func test_escape_closes_open_legacy_panel_before_requesting_screen_close() -> void:
	var close_requested := [false]
	screen.close_requested.connect(func(): close_requested[0] = true)
	screen._toggle_legacy_actions()
	assert_bool(screen._legacy_panel.visible).is_true()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._unhandled_key_input(escape)
	assert_bool(screen._legacy_panel.visible).is_false()
	assert_bool(close_requested[0]).is_false()
	screen._unhandled_key_input(escape)
	assert_bool(close_requested[0]).is_true()

func test_sidebar_collapses_at_compact_width_and_respects_manual_override() -> void:
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 720)
	await get_tree().process_frame
	assert_bool(screen._sidebar_collapsed).is_true()
	assert_bool(screen._catalog_scroll.visible).is_false()
	screen._toggle_sidebar()
	assert_bool(screen._sidebar_collapsed).is_false()
	screen.size = Vector2(1920, 1080)
	await get_tree().process_frame
	assert_bool(screen._sidebar_collapsed).is_false()
	screen._sidebar_override = false
	var window := screen.get_window()
	var original_window_size := window.size
	window.size = Vector2i(1280, 720)
	await get_tree().process_frame
	assert_bool(screen._sidebar_collapsed).is_true()
	window.size = Vector2i(1920, 1080)
	await get_tree().process_frame
	assert_bool(screen._sidebar_collapsed).is_false()
	window.size = original_window_size

func test_campaign_hud_uses_registered_resources_live_ledger_and_persisted_group_state() -> void:
	var defs := Resources.get_campaign_resource_defs(true)
	var resources: ResourceContext = city.ensure_resource_ctx(defs)
	resources.setup(defs, true)
	resources.deserialize({"food": 10.0, "wood": 5.0, "iron": 0.0})
	assert_bool(resources.transact({"wood": 2.0}, {"food": 3.0}, "test:production").ok).is_true()
	var worker: PopUnit = city.add_migrant(PopUnit.State.WORKER, 0)
	worker.ancestry_id = "halflings"
	city.campaign_group_state["farmers_brewers"] = {"satisfaction": 42, "unmet_turns": 1}
	screen.refresh()
	var food_button: Button = screen._resource_buttons[&"food"]
	var wood_button: Button = screen._resource_buttons[&"wood"]
	var iron_button: Button = screen._resource_buttons[&"iron"]
	assert_bool(food_button.text.contains("Еда  13.0  Δ+3.0")).is_true()
	assert_bool(wood_button.text.contains("Дерево  3.0  Δ-2.0")).is_true()
	assert_bool(iron_button.text.contains("Железо  0.0  Δ+0.0")).is_true()
	for metric in [food_button, wood_button, iron_button]:
		assert_that(metric.icon).is_not_null()
		var metric_style := metric.get_theme_stylebox("normal") as StyleBoxFlat
		assert_that(metric_style.bg_color).is_equal(Color("#30291d"))
		assert_that(metric_style.border_color).is_equal(Color("#9a804d"))
	assert_bool(screen._population_metric.text.begins_with("Жители 1 / ")).is_true()
	assert_that(screen._housing_metric.text).is_equal("Жильё 0")
	assert_bool(screen._inspector_text.text.contains("Земледельцы & Пивовары · удовлетворённость 42%")).is_true()
	assert_bool(screen._inspector_text.text.contains("городская удовлетворённость")).is_false()
	screen._on_resource_pressed(&"food")
	assert_bool(screen._inspector_text.text.contains("test:production  +3.0")).is_true()
	var header_text := _visible_text(screen.get_node("ScreenMargin/ScreenLayout/ScreenHeader"))
	for forbidden in ["Gold", "Stone", "Золото", "Камень", "score"]:
		assert_bool(header_text.contains(forbidden)).override_failure_message(
			"unsupported campaign HUD value displayed: %s" % forbidden).is_false()

func test_campaign_hud_marks_missing_resource_context_unavailable() -> void:
	var food_button: Button = screen._resource_buttons[&"food"]
	assert_bool(food_button.text.contains("Еда  —  Δ —")).is_true()
	assert_bool(food_button.text.contains("Еда  0")).is_false()

func test_campaign_city_level_hud_reports_capacity_and_advances_only_when_filled() -> void:
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	city.campaign_buildings.append({"id": "starter", "cell": cells[4], "footprint": [[0, 0]]})
	screen.refresh()
	assert_that(screen._city_level_button.text).is_equal("Город 1 · 2/4")
	assert_bool(screen._city_level_button.visible).is_true()
	assert_bool(screen._city_level_button.disabled).is_false()
	var blocked: CityCheck = screen.level_up_pressed()
	assert_bool(blocked.ok).is_false()
	assert_bool(blocked.reason.contains("ещё 2 клетки")).is_true()
	assert_that(city.level).is_equal(1)
	city.campaign_buildings.append_array([
		{"id": "starter_b", "cell": cells[5], "footprint": [[0, 0]]},
		{"id": "starter_c", "cell": cells[6], "footprint": [[0, 0]]},
	])
	screen.refresh()
	assert_that(screen._city_level_button.text).is_equal("Город 1 · 4/4")
	assert_bool(screen._city_level_button.disabled).is_false()
	screen._city_level_button.pressed.emit()
	assert_that(city.level).is_equal(2)
	assert_that(screen._city_level_button.text).is_equal("Город 2 · 4/9")

func test_catalog_cards_filter_and_explain_selected_city_affordability_prerequisites_and_duration() -> void:
	assert_that(screen._campaign_catalog.get("buildings", []).size()).is_equal(98)
	assert_that(screen._catalog_error).is_empty()
	var card_list := screen._catalog_scroll.get_child(0) as VBoxContainer
	assert_that(card_list.get_child_count()).is_equal(99)
	assert_that(screen._category_buttons.size()).is_equal(CityScreen.CATALOG_CATEGORIES.size())
	assert_that(screen._category_buttons[1].text).is_equal("Производство")
	assert_that(screen._catalog_scroll).is_not_null()
	var farm_card := card_list.get_node("BuildingCard_campaign_farm")
	var farm_icon := _find_named(farm_card, "BuildingIcon") as TextureRect
	var availability := _find_named(farm_card, "BuildingAvailability") as Label
	var cost_panel := _find_named(farm_card, "BuildingCostPanel") as PanelContainer
	assert_that(farm_icon.texture).is_not_null()
	assert_that(farm_icon.texture.resource_path).is_equal(
		"res://assets/textures/objects/building_farmhouse.webp")
	var select_button := _find_named(farm_card, "SelectBuilding") as Button
	assert_bool(select_button.flat).is_true()
	assert_bool(select_button.tooltip_text.contains("Дерево 4")).is_true()
	assert_bool(select_button.tooltip_text.contains("Эффекты:")).is_true()
	assert_bool(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.0)) > 0.0).is_true()
	assert_bool(select_button.focus_mode == Control.FOCUS_ALL).is_true()
	assert_that(cost_panel).is_not_null()
	assert_that((_find_named(cost_panel, "CostCaption") as Label).text).is_equal("СТОИМОСТЬ")
	assert_that((_find_named(cost_panel, "CostAmount_wood") as Label).text).is_equal("4")
	assert_that((cost_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color).is_equal(Color("#392f1d"))
	assert_bool(availability.text.contains("Не хватает: Дерево 4.0")).is_true()
	assert_bool(availability.text.contains("Строительство: 1 ход(а)")).is_true()

	var definitions: Array = screen._campaign_catalog.buildings
	var farm_index := -1
	for index in range(definitions.size()):
		if String(definitions[index].id) == "campaign_farm":
			farm_index = index
			break
	var farm_definition: Dictionary = definitions[farm_index].duplicate(true)
	farm_definition.prerequisites.buildings = ["campaign_sawmill"]
	definitions[farm_index] = farm_definition
	var resources: ResourceContext = city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true))
	resources.setup(Resources.get_campaign_resource_defs(true), true)
	resources.deserialize({"food": 0.0, "wood": 10.0, "iron": 2.0})
	screen._render_catalog_cards()
	farm_card = card_list.get_node("BuildingCard_campaign_farm")
	availability = _find_named(farm_card, "BuildingAvailability") as Label
	assert_bool(availability.text.contains("не выполнено: здание campaign_sawmill")).is_true()
	city.campaign_buildings.append({"uid": 0, "id": "campaign_sawmill", "state": "active",
		"construction_turns_remaining": 0, "cell": city.center, "footprint": [[0, 0]]})
	screen._render_catalog_cards()
	farm_card = card_list.get_node("BuildingCard_campaign_farm")
	availability = _find_named(farm_card, "BuildingAvailability") as Label
	assert_bool(availability.text.contains("Требования выполнены")).is_true()
	(_find_named(farm_card, "SelectBuilding") as Button).pressed.emit()
	assert_that(screen._selected_building_id).is_equal("campaign_farm")

	var production_tab := 1
	screen._on_category_tab_pressed(production_tab)
	await get_tree().process_frame
	var expected_production_cards := 0
	var production_roles: Array = CityScreen.CATALOG_CATEGORIES[production_tab].roles
	for definition in definitions:
		for role in definition.roles:
			if production_roles.has(role):
				expected_production_cards += 1
				break
	assert_that(card_list.get_child_count()).is_equal(expected_production_cards + 1)
	assert_that(card_list.get_node_or_null("BuildingCard_campaign_farm")).is_not_null()
	await get_tree().process_frame

func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_named(child, target_name)
		if found != null:
			return found
	return null

func _visible_text(node: Node) -> String:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return ""
	var text := ""
	if node is Label:
		text += (node as Label).text + " "
	elif node is Button:
		text += (node as Button).text + " "
	for child in node.get_children():
		text += _visible_text(child)
	return text

func test_inspector_shows_only_simulated_active_effects_and_their_causes() -> void:
	var farm_cell: Vector2i = city.center + Vector2i(2, 0)
	var sawmill_cell: Vector2i = city.center + Vector2i(3, 0)
	var farm: Dictionary = screen._find_campaign_building("campaign_farm").duplicate(true)
	farm.merge({"uid": 10, "cell": farm_cell, "state": "active", "construction_turns_remaining": 0,
		"assigned_workers": 2, "services": {"community_mediation": 2}, "upkeep": {"food": 1}}, true)
	var sawmill: Dictionary = screen._find_campaign_building("campaign_sawmill").duplicate(true)
	sawmill.merge({"uid": 11, "cell": sawmill_cell, "state": "active", "construction_turns_remaining": 0}, true)
	var inactive: Dictionary = screen._find_campaign_building("campaign_housing").duplicate(true)
	inactive.merge({"uid": 12, "cell": city.center + Vector2i(0, 2), "state": "inactive",
		"construction_turns_remaining": 0, "services": {"community_mediation": 9}, "upkeep": {"food": 9}}, true)
	var ruined: Dictionary = screen._find_campaign_building("campaign_barracks").duplicate(true)
	ruined.merge({"uid": 13, "cell": city.center + Vector2i(1, 2), "state": "ruined",
		"construction_turns_remaining": 0, "services": {"education": 9}, "upkeep": {"food": 8}}, true)
	var in_progress: Dictionary = screen._find_campaign_building("campaign_farm").duplicate(true)
	in_progress.merge({"uid": 14, "cell": city.center + Vector2i(2, 1), "state": "inactive",
		"construction_turns_remaining": 1, "services": {"community_mediation": 7}, "upkeep": {"food": 7}}, true)
	city.campaign_buildings.assign([farm, sawmill, inactive, ruined, in_progress])
	var resources: ResourceContext = city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true))
	resources.setup(Resources.get_campaign_resource_defs(true), true)
	resources.deserialize({"food": 20.0, "wood": 0.0, "iron": 0.0})
	assert_bool(resources.transact({}, {"food": 2.0},
		"campaign-building:campaign_farm/recipe:farm_food").ok).is_true()
	assert_bool(resources.transact({}, {"food": 9.0},
		"campaign-building:campaign_housing/recipe:stale_inactive").ok).is_true()
	var city_snapshot: Array = city.campaign_buildings.duplicate(true)
	var ledger_snapshot := resources.get_ledger().duplicate(true)
	screen.refresh()
	screen._show_cell_inspector(farm_cell)
	assert_bool(screen._inspector_text.text.contains("Услуга медиация · 2")).is_true()
	assert_bool(screen._inspector_text.text.contains("Содержание: Еда 1 / ход")).is_true()
	assert_bool(screen._inspector_text.text.contains("Эффект соседства: выпуск +15%")).is_true()
	assert_bool(screen._inspector_text.text.contains("Причина: Лесопилка · forest_edge_farm")).is_true()
	assert_bool(screen._inspector_text.text.contains("Производство farm_food: — → Еда 2")).is_true()
	assert_bool(screen._inspector_text.text.contains("stale_inactive")).is_false()
	for cell in [inactive.cell, ruined.cell, in_progress.cell]:
		screen._show_cell_inspector(cell)
		for suppressed in ["Услуга", "Содержание:", "Эффект соседства:", "Производство "]:
			assert_bool(screen._inspector_text.text.contains(suppressed)).override_failure_message(
				"suppressed effect shown on %s cell: %s" % [cell, suppressed]).is_false()
	assert_that(city.campaign_buildings).is_equal(city_snapshot)
	assert_that(resources.get_ledger()).is_equal(ledger_snapshot)

func test_placement_preview_shows_validity_and_exact_reason_then_escape_cancels_read_only() -> void:
	var definitions := Resources.get_campaign_resource_defs(true)
	var resources: ResourceContext = city.ensure_resource_ctx(definitions)
	resources.setup(definitions, true)
	resources.deserialize({"food": 10.0, "wood": 20.0, "iron": 0.0})
	var blocked_cell: Vector2i = city.center + Vector2i(2, 0)
	var free_cell: Vector2i = city.center + Vector2i(2, 1)
	var legacy := UniqueBuilding.new()
	legacy.def = BuildingDefs.def_by_id(&"farm")
	legacy.cell = blocked_cell
	city.buildings.append(legacy)
	screen.refresh()
	var buildings_before: Array = city.campaign_buildings.duplicate(true)
	var amount_before := resources.amount(&"wood")
	var ledger_before: Array = resources.get_ledger().duplicate(true)

	screen._on_building_card_pressed("campaign_farm")
	screen._on_board_cell_hovered(free_cell)
	assert_bool(screen._preview_result.ok).is_true()
	assert_bool(screen._board.preview_valid).is_true()
	assert_that(screen._board.preview_footprint).contains_exactly([free_cell])
	assert_bool(screen._inspector_text.text.contains("Размещение допустимо")).is_true()
	screen._on_board_cell_hovered(blocked_cell)
	assert_bool(screen._preview_result.ok).is_false()
	assert_bool(screen._inspector_text.text.contains("Клетка %s занята" % blocked_cell)).is_true()
	assert_that(city.campaign_buildings).is_equal(buildings_before)
	assert_that(resources.amount(&"wood")).is_equal(amount_before)
	assert_that(resources.get_ledger()).is_equal(ledger_before)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._unhandled_key_input(escape)
	assert_bool(screen._placement_active).is_false()
	assert_that(screen._selected_building_id).is_empty()
	assert_that(screen._board.preview_anchor).is_equal(Vector2i(-1, -1))
	assert_that(city.campaign_buildings).is_equal(buildings_before)
	assert_that(resources.amount(&"wood")).is_equal(amount_before)
	assert_that(resources.get_ledger()).is_equal(ledger_before)

func test_capacity_limit_is_shown_in_preview_and_confirmation_is_blocked_without_writes() -> void:
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	for index in range(4, 7):
		city.campaign_buildings.append({"id": "occupied_%d" % index,
			"cell": cells[index], "footprint": [[0, 0]]})
	var resources: ResourceContext = city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true))
	resources.setup(Resources.get_campaign_resource_defs(true), true)
	resources.deserialize({"food": 0.0, "wood": 20.0, "iron": 0.0})
	var city_before: Array = city.campaign_buildings.duplicate(true)
	var ledger_before: Array = resources.get_ledger().duplicate(true)
	screen._on_building_card_pressed("campaign_farm")
	screen._on_board_cell_selected(cells[7])
	assert_bool(screen._preview_result.ok).is_false()
	assert_that(screen._preview_result.reason).is_equal("city_capacity")
	assert_bool(screen._inspector_text.text.contains("4/4 клеток на уровне 1")).is_true()
	assert_bool(screen._confirm_build_button.disabled).is_true()
	screen._confirm_campaign_building()
	assert_that(city.campaign_buildings).is_equal(city_before)
	assert_float(resources.amount(&"wood")).is_equal_approx(20.0, 0.0001)
	assert_that(resources.get_ledger()).is_equal(ledger_before)

func test_confirmation_routes_through_service_and_charges_exactly_once() -> void:
	var definitions := Resources.get_campaign_resource_defs(true)
	var resources: ResourceContext = city.ensure_resource_ctx(definitions)
	resources.setup(definitions, true)
	resources.deserialize({"food": 5.0, "wood": 8.0, "iron": 0.0})
	var anchor: Vector2i = city.center + Vector2i(2, 1)
	screen._on_building_card_pressed("campaign_farm")
	screen._on_board_cell_selected(anchor)
	assert_bool(screen._preview_result.ok).is_true()
	assert_bool(screen._confirm_build_button.disabled).is_false()
	(_find_named(screen, "ConfirmPlacement") as Button).pressed.emit()
	assert_that(city.campaign_buildings.size()).is_equal(1)
	assert_that(resources.amount(&"wood")).is_equal(4.0)
	var construction_flows := 0
	for flow in resources.get_ledger():
		if String(flow.get("source", "")) == "construction:campaign_farm":
			construction_flows += 1
			assert_that(flow.get("inputs", {}).get("wood", 0.0)).is_equal(4.0)
	assert_that(construction_flows).is_equal(1)
	assert_that(city.campaign_buildings[0].get("state")).is_equal("inactive")
	assert_that(city.campaign_buildings[0].get("construction_turns_remaining")).is_equal(1)
	assert_bool(screen._placement_active).is_false()
	assert_that(screen._message_label.text).contains("осталось 1 ход")
	assert_bool(screen._inspector_text.text.contains("Строительство: 0/1 ход(")).is_true()

func test_service_rejection_after_valid_preview_changes_neither_city_nor_ledger_again() -> void:
	var definitions := Resources.get_campaign_resource_defs(true)
	var resources: ResourceContext = city.ensure_resource_ctx(definitions)
	resources.setup(definitions, true)
	resources.deserialize({"food": 0.0, "wood": 8.0, "iron": 0.0})
	var anchor: Vector2i = city.center + Vector2i(2, 1)
	screen._on_building_card_pressed("campaign_farm")
	screen._on_board_cell_selected(anchor)
	assert_bool(screen._preview_result.ok).is_true()
	assert_bool(resources.transact({"wood": 8.0}, {}, "test:competing_spend").ok).is_true()
	var before_city: Array = city.campaign_buildings.duplicate(true)
	var before_ledger: Array = resources.get_ledger().duplicate(true)
	screen._confirm_campaign_building()
	assert_that(city.campaign_buildings).is_equal(before_city)
	assert_that(resources.amount(&"wood")).is_equal(0.0)
	assert_that(resources.get_ledger()).is_equal(before_ledger)
	assert_bool(screen._placement_active).is_true()
	assert_bool(screen._confirm_build_button.disabled).is_true()
	assert_bool(screen._inspector_text.text.contains("Не хватает Дерево 4")).is_true()

func test_build_farm_success() -> void:
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_true()
	assert_that(r.payload.get("building")).is_equal("farm")
	assert_that(int(r.payload.get("level", 0))).is_equal(1)
	assert_that(city.buildings.size()).is_equal(1)
	assert_float(float(r.payload.get("industry_left", -1.0))).is_equal_approx(18.0, 0.0001)
	var cell: Dictionary = r.payload.get("cell", {})
	assert_that(HexUtils.hex_distance(Vector2i(int(cell.x), int(cell.y)), city.center)).is_equal(1)

func test_build_mine_cost() -> void:
	# Ранняя игра: рудник доступен с 4-го уровня города (early-game-foundation)
	city.level = 4
	var r: CityCheck = screen.build_pressed(&"mine")
	assert_bool(bool(r.ok)).is_true()
	assert_float(float(r.payload.get("industry_left", -1.0))).is_equal_approx(10.0, 0.0001)

func test_build_fails_without_industry() -> void:
	city.storage[&"industry"] = 5.0
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("Промышленность")).is_true()
	assert_that(city.buildings.size()).is_equal(0)

func test_build_fails_without_free_cell() -> void:
	city.center = Vector2i(0, 0)
	screen.setup(city, hero, Vector2i(0, 0), TestFactories.seeded(42), Vector2i(1, 1))
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("клетки")).is_true()

func test_build_unknown_def_fails() -> void:
	var r: CityCheck = screen.build_pressed(&"nope")
	assert_bool(bool(r.ok)).is_false()

func test_hire_moves_follower_to_hero() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r: CityCheck = screen.hire_pressed()
	assert_bool(bool(r.ok)).is_true()
	var f: Dictionary = r.payload.get("follower", {})
	assert_str(f.get("name", "")).is_not_empty()
	assert_bool(String(f.get("race", "")).length() > 0).is_true()
	assert_that(hero.followers.size()).is_equal(1)
	assert_that(city.count_state(PopUnit.State.FOLLOWER)).is_equal(1)

func test_hire_depletes_then_fails() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r1: CityCheck = screen.hire_pressed()
	assert_bool(bool(r1.ok)).is_true()
	var r2: CityCheck = screen.hire_pressed()
	assert_bool(bool(r2.ok)).is_false()
	assert_bool(str(r2.reason).contains("последователей")).is_true()
	assert_that(hero.followers.size()).is_equal(1)

func test_level_up_fresh_village_fails() -> void:
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).length() > 0).is_true()
	assert_that(city.level).is_equal(1)

func test_level_up_when_conditions_met() -> void:
	city.prosperity = 70.0
	city.storage[&"industry"] = 40.0
	for i in 12:
		city.add_migrant(PopUnit.State.WORKER, -1)
	# Ранняя игра: фермы строятся с 1-го уровня; рудник требует 2-й (early-game-foundation)
	screen.build_pressed(&"farm")
	screen.build_pressed(&"farm")
	assert_that(city.buildings.size()).is_equal(2)
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_true()
	assert_that(int(r.payload.get("level", 0))).is_equal(2)
	assert_that(city.level).is_equal(2)

func test_level_up_max_level_fails() -> void:
	city.level = GameNumbers.CITY_LEVEL_MAX
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("максимальном")).is_true()
