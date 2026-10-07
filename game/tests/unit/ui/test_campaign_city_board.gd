extends BaseTest

var board: CampaignCityBoard
var city: City

func before_test() -> void:
	board = CampaignCityBoard.new()
	board.size = Vector2(1000, 700)
	Engine.get_main_loop().root.add_child(board)
	city = City.new()
	city.center = Vector2i(18, 20)
	var legacy := UniqueBuilding.new()
	legacy.def = BuildingDefs.def_by_id(&"farm")
	legacy.cell = city.center
	city.buildings.append(legacy)
	city.campaign_buildings.append({
		"uid": 9, "id": "campaign_farm", "cell": city.center + Vector2i(2, 1),
		"footprint": [[0, 0]], "state": "inactive", "construction_turns_remaining": 2,
	})
	board.bind_city(city, {}, func(cell: Vector2i) -> int:
		return HexUtils.Terrain.FOREST if cell == city.center else HexUtils.Terrain.GRASS
	)

func after_test() -> void:
	if is_instance_valid(board):
		board.free()

func test_board_uses_exact_52_cell_city_geometry_and_canonical_occupants() -> void:
	await get_tree().process_frame
	assert_that(board._atlas.resource_path).is_equal("res://assets/textures/hex_sheet_0.png")
	assert_that(CampaignCityBoard.building_art_path("campaign_farm")).ends_with("building_farmhouse.webp")
	assert_that(CampaignCityBoard.building_art_path("campaign_sawmill")).ends_with("building_sawmill.webp")
	assert_that(CampaignCityBoard.building_art_path("campaign_iron_mine")).is_empty()
	var cells := board.get_rendered_cells()
	assert_that(cells.size()).is_equal(52)
	var unique := {}
	var rings := {}
	for cell in cells:
		unique[cell] = true
		rings[board.get_cell_visual(cell).ring] = true
		assert_bool(board.get_cell_center(cell) != Vector2(-1, -1)).is_true()
	assert_that(unique.size()).is_equal(52)
	assert_that(rings.size()).is_equal(4)
	var core := board.get_cell_visual(city.center)
	assert_that(core.legacy_building_id).is_equal("farm")
	assert_that(core.terrain_name).is_equal("forest")
	assert_that(core.ring).is_zero()
	var site := board.get_cell_visual(city.center + Vector2i(2, 1))
	assert_that(site.campaign_building_id).is_equal("campaign_farm")
	assert_that(site.campaign_state).is_equal("inactive")
	assert_that(site.construction_turns_remaining).is_equal(2)
	assert_bool(site.occupied).is_true()

func test_arrow_keys_move_focused_board_selection_between_existing_cells() -> void:
	await get_tree().process_frame
	board.set_selection(city.center)
	var selected: Array[Vector2i] = []
	board.cell_selected.connect(func(cell: Vector2i): selected.append(cell))
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	board._gui_input(right)
	assert_that(selected.size()).is_equal(1)
	assert_that(selected[0]).is_not_equal(city.center)
	assert_bool(board.get_rendered_cells().has(selected[0])).is_true()
	assert_that(board.focus_mode).is_equal(Control.FOCUS_ALL)

func test_board_does_not_guess_missing_terrain() -> void:
	board.bind_city(city, {})
	var visual := board.get_cell_visual(city.center)
	assert_that(visual.terrain_id).is_equal(-1)
	assert_that(visual.terrain_name).is_empty()
