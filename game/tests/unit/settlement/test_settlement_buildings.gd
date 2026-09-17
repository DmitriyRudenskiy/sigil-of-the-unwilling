extends BaseTest

# Фаза 3 settlement-system: здания, стройка, hearth, производство, переселение

const Settlement = preload("res://scripts/settlement/Settlement.gd")
const Buildings = preload("res://scripts/settlement/SettlementBuildings.gd")
const B = preload("res://scripts/data/settlement_buildings.gd")

func _settle_with(res: Dictionary) -> Variant:
	var s: Variant = Settlement.new()
	for k in res:
		s.add_resource(k, res[k])
	return s

func test_starting_buildings_present() -> void:
	var c: Variant = Settlement.form_caravan({"human": 1})
	assert_that(c.buildings_of("hearth").size()).is_equal(1)
	assert_that(c.buildings_of("warehouse").size()).is_equal(1)

func test_build_requires_materials() -> void:
	var s: Variant = _settle_with({"wood": 1})
	assert_bool(not Buildings.can_build(s, "shelter")).override_failure_message("стройка без материалов")
	s.add_resource("wood", 5)
	assert_bool(Buildings.can_build(s, "shelter"))

func test_build_takes_cycles() -> void:
	var s: Variant = _settle_with({"wood": 10})
	assert_bool(Buildings.start_build(s, "shelter", Vector2i(2, 0)))
	var shelter: Array = s.buildings_of("shelter")
	assert_that(int(shelter[0]["data"]["build_left"])).is_equal(Buildings.BUILD_CYCLES)
	Buildings.on_day_passed(s, _rng(1))
	assert_that(int(shelter[0]["data"]["build_left"])).is_equal(1)
	Buildings.on_day_passed(s, _rng(1))
	assert_that(int(shelter[0]["data"].get("build_left", 0))).is_equal(0)

func test_cell_occupied_blocks_second_build() -> void:
	var s: Variant = _settle_with({"wood": 20})
	assert_bool(Buildings.start_build(s, "shelter", Vector2i(2, 0)))
	assert_bool(not Buildings.start_build(s, "shelter", Vector2i(2, 0)))

func test_lumber_mill_recipe() -> void:
	var s: Variant = _settle_with({"wood": 10})
	var mill: Dictionary = s.add_building("lumber_mill", Vector2i(3, 0))
	mill["data"]["recipe"] = "planks"
	Buildings.on_day_passed(s, _rng(1))
	assert_that(float(s.state["resources"].get("planks", 0.0))).is_equal(2.0)
	assert_that(float(s.state["resources"].get("wood", 0.0))).is_equal(8.0)

func test_recipe_without_input_stops() -> void:
	var s: Variant = _settle_with({})
	var mill: Dictionary = s.add_building("lumber_mill", Vector2i(3, 0))
	mill["data"]["recipe"] = "planks"
	Buildings.on_day_passed(s, _rng(1))
	assert_that(float(s.state["resources"].get("planks", 0.0))).is_equal(0.0)

func test_hearth_level_by_houses() -> void:
	var s: Variant = _settle_with({"wood": 40})
	s.add_building("hearth", Vector2i.ZERO)
	Buildings.start_build(s, "shelter", Vector2i(1, 0))
	assert_that(Buildings.hearth_level(s)).is_equal(1)
	Buildings.start_build(s, "shelter", Vector2i(2, 0))
	assert_that(Buildings.hearth_level(s)).is_equal(2)
	Buildings.start_build(s, "shelter", Vector2i(3, 0))
	Buildings.start_build(s, "shelter", Vector2i(0, 1))
	assert_that(Buildings.hearth_level(s)).is_equal(3)

func test_auto_rehome_prefers_species_house() -> void:
	var s: Variant = _settle_with({"wood": 20, "planks": 8})
	var human: Dictionary = s.add_settler("human")
	var shelter: Dictionary = s.add_building("shelter", Vector2i(1, 0))
	var house: Dictionary = s.add_building("human_house", Vector2i(2, 0))
	Buildings.on_day_passed(s, _rng(1))  # триггерит _auto_rehome
	assert_that(human["home"]).is_equal(house["id"])

func test_frog_not_rehomed_to_shelter() -> void:
	var s: Variant = _settle_with({})
	var frog: Dictionary = s.add_settler("frog")
	s.add_building("shelter", Vector2i(1, 0))
	Buildings.on_day_passed(s, _rng(1))
	assert_that(frog["home"]).is_equal("")

func test_small_camp_small_node_flag() -> void:
	var b: Dictionary = B.by_id("small_foragers_camp")
	assert_bool(bool(b.get("small", false)))
	var w: Dictionary = B.by_id("woodcutters_camp")
	assert_bool(not bool(w.get("small", false)))

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
