extends BaseTest

const CampaignBuildingPlacement = preload("res://scripts/city/campaign_building_placement.gd")
const CampaignBuildingCatalog = preload("res://scripts/data/campaign_building_catalog.gd")
const HexUtils = preload("res://scripts/core/hex_utils.gd")
const ArenaRingSystem = preload("res://scripts/city/arena_ring_system.gd")

func _building(id: String, roles: Array, cell: Vector2i, adjacency: Array = [], footprint: Array = [[0, 0]]) -> Dictionary:
	return {"id": id, "roles": roles, "cell": cell, "footprint": footprint, "adjacency": adjacency}

func test_city_layout_is_52_cells_and_placement_respects_terrain_and_occupancy() -> void:
	var cells := CampaignBuildingPlacement.city_cells()
	assert_that(cells.size()).is_equal(52)
	var anchor := ArenaRingSystem.center()
	var building := {
		"footprint": [[0, 0]],
		"placement": {"terrain_tags": ["grass"], "requires_special_site": false},
	}
	var legal := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "grass"}, {})
	assert_bool(legal.ok).is_true()
	assert_that(legal.cells).is_equal([anchor])
	var wrong_terrain := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "sand"}, {})
	assert_bool(wrong_terrain.ok).is_false()
	assert_that(wrong_terrain.issues.size()).is_equal(1)
	var occupied := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "grass"}, {anchor: "farm"})
	assert_bool(occupied.ok).is_false()
	assert_that(occupied.issues[0]).contains("occupied")

func test_campaign_city_geometry_uses_explicit_center_not_arena_origin() -> void:
	var center := Vector2i(20, 17)
	var cells := CampaignBuildingPlacement.city_cells(center)
	assert_that(cells.size()).is_equal(52)
	assert_bool(cells.has(center)).is_true()
	var building := {
		"footprint": [[0, 0]],
		"placement": {"terrain_tags": [], "requires_special_site": false},
	}
	var edge := HexUtils.cells_in_core_ring(center, 3)[0]
	assert_bool(CampaignBuildingPlacement.explain_placement(
		building, edge, {}, {}, {}, center).ok).is_true()
	var outside := CampaignBuildingPlacement.explain_placement(
		building, center + Vector2i(10, 10), {}, {}, {}, center)
	assert_bool(outside.ok).is_false()
	assert_bool(_has_issue(outside.issues, "outside the 52-cell city")).is_true()

func test_multicell_footprint_and_special_site_constraints() -> void:
	var anchor := ArenaRingSystem.center()
	var building := {
		"footprint": [[0, 0], [1, 0]],
		"placement": {"terrain_tags": [], "requires_special_site": true},
	}
	var cells := CampaignBuildingPlacement.footprint_cells(anchor, building.footprint)
	assert_that(cells.size()).is_equal(2)
	var sites := {cells[0]: "spring", cells[1]: "spring"}
	var legal := CampaignBuildingPlacement.explain_placement(building, anchor, {}, {}, sites)
	assert_bool(legal.ok).is_true()
	var blocked := CampaignBuildingPlacement.explain_placement(building, anchor, {}, {}, {cells[1]: "spring"})
	assert_bool(blocked.ok).is_false()
	assert_that(blocked.issues[0]).contains("anchor")

func test_footprint_cannot_extend_outside_the_52_cell_city() -> void:
	var cells := CampaignBuildingPlacement.city_cells()
	var city_set := {}
	for cell in cells:
		city_set[cell] = true
	var anchor := cells[0]
	var invalid_footprint: Array = [[0, 0]]
	for q in range(-4, 5):
		for r in range(-4, 5):
			var candidate := [[0, 0], [q, r]]
			var placement := CampaignBuildingPlacement.footprint_cells(anchor, candidate)
			if placement.size() == 2 and not city_set.has(placement[1]):
				invalid_footprint = candidate
				break
		if invalid_footprint.size() == 2:
			break
	var result := CampaignBuildingPlacement.explain_placement({
		"footprint": invalid_footprint,
		"placement": {"terrain_tags": [], "requires_special_site": false},
	}, anchor, {}, {})
	assert_bool(result.ok).is_false()
	assert_bool(_has_issue(result.issues, "outside the 52-cell city")).is_true()

func test_adjacency_uses_hex_radius_and_exposes_causes() -> void:
	var center := ArenaRingSystem.center()
	var near := HexUtils.get_neighbor(center, 0, true)
	var far := HexUtils.get_neighbor(near, 0, true)
	var workshop := _building("workshop", ["crafting"], center)
	var adjacency := [{"id": "crafting_near_farm", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 500}]
	var farm := _building("farm", ["agriculture"], near, adjacency)
	var nearby := CampaignBuildingPlacement.explain_adjacency(workshop, center, [farm])
	assert_that(float(nearby.effects.output_bp)).is_equal(500.0)
	assert_that(nearby.causes.size()).is_equal(1)
	assert_that(nearby.causes[0].source_id).is_equal("farm")
	var distant_farm := _building("farm", ["agriculture"], far, adjacency)
	var distant := CampaignBuildingPlacement.explain_adjacency(workshop, center, [distant_farm])
	assert_bool(distant.effects.is_empty()).is_true()

func test_adjacency_stacking_is_bounded_and_recomputed_deterministically() -> void:
	var center := ArenaRingSystem.center()
	var target := _building("workshop", ["crafting"], center)
	var rule := [{"id": "farm_bonus", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 7000}]
	var farms := [
		_building("farm_b", ["agriculture"], HexUtils.get_neighbor(center, 0, true), rule),
		_building("farm_a", ["agriculture"], HexUtils.get_neighbor(center, 1, true), rule),
	]
	var initial := CampaignBuildingPlacement.recompute_adjacency([target] + farms)
	var target_result: Dictionary = _find_building_result(initial, "workshop")
	assert_that(float(target_result.breakdown.effects.output_bp)).is_equal(10000.0)
	assert_that(target_result.breakdown.causes.size()).is_equal(2)
	var repeated := CampaignBuildingPlacement.recompute_adjacency(farms + [target])
	assert_that(repeated).is_equal(initial)
	var without_one := CampaignBuildingPlacement.recompute_adjacency([target, farms[0]])
	assert_that(float(_find_building_result(without_one, "workshop").breakdown.effects.output_bp)).is_equal(7000.0)

func test_inactive_or_ruined_buildings_do_not_supply_adjacency_effects() -> void:
	var center := ArenaRingSystem.center()
	var target := _building("workshop", ["crafting"], center)
	var rule := [{"id": "farm_bonus", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 1500}]
	var source := _building("farm", ["agriculture"], HexUtils.get_neighbor(center, 0, true), rule)
	source["state"] = "inactive"
	var no_active_source := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_active_source.effects.is_empty()).is_true()
	source["state"] = "active"
	source["construction_turns_remaining"] = 1
	var no_in_progress_source := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_in_progress_source.effects.is_empty()).is_true()
	source["construction_turns_remaining"] = 0
	target["construction_turns_remaining"] = 1
	var no_in_progress_target := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_in_progress_target.effects.is_empty()).is_true()
	target["construction_turns_remaining"] = 0
	target["state"] = "ruined"
	var no_active_target := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_active_target.effects.is_empty()).is_true()

func _find_building_result(results: Array[Dictionary], id: String) -> Dictionary:
	for result in results:
		if result.building_id == id:
			return result
	return {}

func _has_issue(issues: Array, fragment: String) -> bool:
	for issue in issues:
		if String(issue).contains(fragment):
			return true
	return false


## city-construction-districts 4.1: «1 клетка = 1 здание» — инвариант данных
## MVP-каталога: каждый building footprint [[0,0]] (одна клетка).
## city-construction-districts 2.4/4.3: правило соседства в MVP — одно на каталог.
## Канон — «ферма у леса +15%» (02-mechanics §3.5, 02g §3). Носитель MVP — лесопилка
## рядом с фермой (rule id `forest_edge_farm`): самого леса как размещаемого объекта
## на городской сетке нет, роль леса играет соседнее лесозаготовительное здание.
## Числа не хардкод теста: проверяется ровно то, что объявлено в каталоге, и то,
## что из этого следует по сетке.
func _catalog_buildings() -> Array:
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_that(catalog.is_empty()).is_false()
	var buildings: Array = catalog.get("buildings", [])
	assert_that(buildings.size()).is_greater(0)
	return buildings


func _catalog_instance(definition_id: String, cell: Vector2i) -> Dictionary:
	for definition in _catalog_buildings():
		if definition is Dictionary and String(definition.get("id", "")) == definition_id:
			var instance: Dictionary = definition.duplicate(true)
			instance["cell"] = cell
			# WORKING по носителю: active + пустая очередь стройки
			# (city-construction-districts 2.3, маппинг SM на construction-queue).
			instance["state"] = "active"
			instance["construction_turns_remaining"] = 0
			return instance
	fail("здание %s отсутствует в кампанийном каталоге" % definition_id)
	return {}


func _farm_bonus(sawmill: Dictionary, farm: Dictionary) -> float:
	var results := CampaignBuildingPlacement.recompute_adjacency([sawmill, farm])
	var breakdown: Dictionary = _find_building_result(results, "campaign_farm").get("breakdown", {})
	return float(breakdown.get("effects", {}).get("output_bp", 0.0))


func test_mvp_catalog_has_exactly_one_adjacency_rule() -> void:
	var rules := 0
	var owner_id := ""
	var rule := {}
	for definition in _catalog_buildings():
		if not (definition is Dictionary):
			continue
		for entry in definition.get("adjacency", []):
			rules += 1
			owner_id = String(definition.get("id", ""))
			rule = entry
	assert_that(rules).is_equal(1) \
		.override_failure_message("MVP: ровно одно правило соседства на каталог")
	assert_that(owner_id).is_equal("campaign_sawmill")
	assert_that(String(rule.get("id", ""))).is_equal("forest_edge_farm")
	assert_that(String(rule.get("target_role", ""))).is_equal("food_production")
	assert_that(int(rule.get("radius", 0))).is_equal(1)
	assert_that(String(rule.get("effect", ""))).is_equal("output_bp")
	# 1500 б.п. = +15% канонического правила
	assert_that(float(rule.get("value", 0.0))).is_equal(1500.0)


func test_shipped_forest_edge_rule_gives_the_farm_fifteen_percent() -> void:
	var center := ArenaRingSystem.center()
	var farm := _catalog_instance("campaign_farm", HexUtils.get_neighbor(center, 0, true))
	var sawmill := _catalog_instance("campaign_sawmill", center)
	assert_that(_farm_bonus(sawmill, farm)).is_equal(1500.0)
	var results := CampaignBuildingPlacement.recompute_adjacency([sawmill, farm])
	var causes: Array = _find_building_result(results, "campaign_farm").get("breakdown", {}).get("causes", [])
	assert_that(causes.size()).is_equal(1)
	assert_that(String(causes[0].get("source_id", ""))).is_equal("campaign_sawmill")
	assert_that(String(causes[0].get("rule_id", ""))).is_equal("forest_edge_farm")
	# Правило односторонее: лесопилка рядом с фермой ничего не получает.
	var sawmill_effects: Dictionary = _find_building_result(results, "campaign_sawmill") \
		.get("breakdown", {}).get("effects", {})
	assert_bool(sawmill_effects.is_empty()).is_true()


func test_shipped_forest_edge_rule_needs_working_source_at_radius_one() -> void:
	var center := ArenaRingSystem.center()
	var farm := _catalog_instance("campaign_farm", center)
	var sawmill := _catalog_instance("campaign_sawmill", HexUtils.get_neighbor(center, 0, true))
	assert_that(_farm_bonus(sawmill, farm)).is_equal(1500.0)
	# Радиус 1: отодвинули лесопилку — леса (т.е. её) рядом уже нет.
	var far_cell := HexUtils.get_neighbor(HexUtils.get_neighbor(center, 0, true), 0, true)
	assert_that(HexUtils.hex_distance(center, far_cell, true)).is_equal(2)
	var far_sawmill := _catalog_instance("campaign_sawmill", far_cell)
	assert_that(_farm_bonus(far_sawmill, farm)).is_equal(0.0)
	# BUILDING (state inactive) — аура не действует.
	sawmill["state"] = "inactive"
	assert_that(_farm_bonus(sawmill, farm)).is_equal(0.0)
	# BUILDING в очереди стройки (state active, но remaining > 0) — тоже нет.
	sawmill["state"] = "active"
	sawmill["construction_turns_remaining"] = 2
	assert_that(_farm_bonus(sawmill, farm)).is_equal(0.0)
	# RUINED — нет.
	sawmill["construction_turns_remaining"] = 0
	sawmill["state"] = "ruined"
	assert_that(_farm_bonus(sawmill, farm)).is_equal(0.0)
	# WORKING — бонус возвращается: эффект производный от состояний, не кэш.
	sawmill["state"] = "active"
	assert_that(_farm_bonus(sawmill, farm)).is_equal(1500.0)
	# Стройка на самой ферме (BUILDING-цель) — бонус не применяется к тому, кто
	# ещё не работает.
	farm["construction_turns_remaining"] = 1
	assert_that(_farm_bonus(sawmill, farm)).is_equal(0.0)


func test_mvp_catalog_one_cell_per_building() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var buildings: Array = catalog.get("buildings", [])
	assert_that(buildings.size()).is_greater(0)
	for b in buildings:
		if not (b is Dictionary):
			continue
		var id := String(b.get("id", ""))
		# JSON-парсинг даёт float-координаты — сравниваем в клеточном пространстве
		# (footprint_cells нормализует int-ово).
		var cells := CampaignBuildingPlacement.footprint_cells(Vector2i.ZERO, b.get("footprint", []))
		assert_that(cells.size()).is_equal(1) \
			.override_failure_message("MVP: 1 клетка = 1 здание (footprint = ровно 1 клетка): %s" % id)
		assert_that(cells[0]).is_equal(Vector2i.ZERO) \
			.override_failure_message("MVP: footprint = одна клетка-якорь [0,0]: %s" % id)
