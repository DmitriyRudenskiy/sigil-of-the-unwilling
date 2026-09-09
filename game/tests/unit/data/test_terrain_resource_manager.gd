extends GdUnitTestSuite

const _TRM = preload("res://scripts/data/TerrainResourceManager.gd")


func _make_map(seed: int = 7) -> Dictionary:
	var terrain := {}
	terrain[Vector2i(0, 0)] = 4   
	terrain[Vector2i(4, 4)] = 5   
	terrain[Vector2i(2, 2)] = 4   
	return {"terrain": terrain, "width": 5, "height": 5, "seed": seed}



func test_generate_places_points_on_forest_and_mountains() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map())
	assert_bool(trm.cells.has(Vector2i(0, 0))).is_true()
	assert_bool(trm.cells.has(Vector2i(4, 4))).is_true()
	assert_bool(trm.cells.has(Vector2i(2, 2))).is_true()
	assert_that(trm.res_id_at(Vector2i(0, 0))).is_equal(&"wood")
	assert_that(trm.res_id_at(Vector2i(4, 4))).is_equal(&"stone")
	assert_bool(trm.is_exhausted(Vector2i(0, 0))).is_false()
	trm.free()


func test_generate_skips_plain() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map())
	assert_bool(trm.cells.has(Vector2i(1, 1))).is_false()
	trm.free()


func test_generate_density_controls_count() -> void:
	var trm_low := _TRM.new()
	trm_low.generate(_make_map(), 0.0)
	assert_that(trm_low.cells.size()).is_equal(0)
	trm_low.free()

	var trm_full := _TRM.new()
	trm_full.generate(_make_map(), 1.0)
	assert_that(trm_full.cells.size()).is_equal(3)
	trm_full.free()



var _sig_res: Variant = null
var _sig_amount: int = -1
func _on_test_harvested(cell: Variant, rid: Variant, amt: Variant) -> void:
	_sig_res = rid
	_sig_amount = amt

func test_harvest_returns_res_and_amount() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	_sig_res = null
	_sig_amount = -1
	trm.terrain_harvested.connect(_on_test_harvested)
	var cell := Vector2i(0, 0)
	var harvested := trm.harvest(cell)
	assert_that(harvested.get("res_id")).is_equal(&"wood")
	assert_that(harvested.get("amount")).is_equal(2)
	assert_that(_sig_res).is_equal(&"wood")
	assert_that(_sig_amount).is_equal(2)
	assert_bool(trm.is_exhausted(cell)).is_true()
	trm.free()


func test_harvest_exhausted_returns_zero() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	var cell := Vector2i(0, 0)
	trm.harvest(cell)
	var harvested := trm.harvest(cell)
	assert_that(harvested.get("amount")).is_equal(0)
	assert_bool(trm.is_harvestable(cell)).is_false()
	trm.free()


func test_harvest_unknown_cell_returns_zero() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	var harvested := trm.harvest(Vector2i(1, 1))
	assert_that(harvested.get("amount")).is_equal(0)
	trm.free()


func test_is_harvestable() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	assert_bool(trm.is_harvestable(Vector2i(0, 0))).is_true()
	assert_bool(trm.is_harvestable(Vector2i(1, 1))).is_false()
	trm.free()



func test_persistence_roundtrip() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	trm.harvest(Vector2i(0, 0))  

	var data: Dictionary = trm.to_dict()
	assert_bool(data.has(str(Vector2i(0, 0)))).is_true()

	var restored := _TRM.new()
	restored.generate(_make_map(), 1.0)  
	restored.restore_from_dict(data)
	assert_bool(restored.is_exhausted(Vector2i(0, 0))).is_true()
	assert_bool(restored.is_exhausted(Vector2i(4, 4))).is_false()
	trm.free()
	restored.free()


func test_mark_exhausted() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	trm.mark_exhausted([Vector2i(4, 4)])
	assert_bool(trm.is_exhausted(Vector2i(4, 4))).is_true()
	trm.free()
