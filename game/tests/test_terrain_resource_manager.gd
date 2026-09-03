extends "res://tests/test_base.gd"
## terrain-resources: unit-тесты TerrainResourceManager (контактный сбор с лесу/
## гор, истощение точек, сигналы, персистентность).

const _TRM = preload("res://scripts/data/TerrainResourceManager.gd")


## карта_данных: ровно контракт, который consume() generate() WorldBootstrap —
## terrain = {cell -> id}, width, height, seed.
func _make_map(seed: int = 7) -> Dictionary:
	var terrain := {}
	terrain[Vector2i(0, 0)] = 4   # FOREST -> wood
	terrain[Vector2i(4, 4)] = 5   # MOUNTAIN -> stone
	terrain[Vector2i(2, 2)] = 4   # FOREST -> wood
	return {"terrain": terrain, "width": 5, "height": 5, "seed": seed}


# ==================== GENERATE ====================

func test_generate_places_points_on_forest_and_mountains() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map())
	assert_true(trm.cells.has(Vector2i(0, 0)), "forest -> точка")
	assert_true(trm.cells.has(Vector2i(4, 4)), "mountain -> точка")
	assert_true(trm.cells.has(Vector2i(2, 2)), "forest center -> точка")
	assert_eq(trm.res_id_at(Vector2i(0, 0)), &"wood", "forest -> wood")
	assert_eq(trm.res_id_at(Vector2i(4, 4)), &"stone", "mountain -> stone")
	assert_false(trm.is_exhausted(Vector2i(0, 0)), "точка не истощена")
	trm.free()


func test_generate_skips_plain() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map())
	# равнина отсутствует в terrain -> не точка.
	assert_false(trm.cells.has(Vector2i(1, 1)), "равнина не точка")
	trm.free()


func test_generate_density_controls_count() -> void:
	var trm_low := _TRM.new()
	trm_low.generate(_make_map(), 0.0)
	assert_eq(trm_low.cells.size(), 0, "density 0 -> 0 точек")
	trm_low.free()

	var trm_full := _TRM.new()
	trm_full.generate(_make_map(), 1.0)
	assert_eq(trm_full.cells.size(), 3, "density 1 -> все точки")
	trm_full.free()


# ==================== HARVEST ====================

# ponytail: Godot 4.7 — connect lambda-сигнала не срабатывает (именный слот да).
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
	assert_eq(harvested.get("res_id"), &"wood", "harvest res_id")
	assert_eq(harvested.get("amount"), 2, "harvest amount = HARVEST_AMOUNT")
	assert_eq(_sig_res, &"wood", "signal res_id")
	assert_eq(_sig_amount, 2, "signal amount")
	assert_true(trm.is_exhausted(cell), "после сбора — истощена")
	trm.free()


func test_harvest_exhausted_returns_zero() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	var cell := Vector2i(0, 0)
	trm.harvest(cell)
	var harvested := trm.harvest(cell)
	assert_eq(harvested.get("amount"), 0, "второй сбор = 0")
	assert_false(trm.is_harvestable(cell), "истощённая не harvestable")
	trm.free()


func test_harvest_unknown_cell_returns_zero() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	var harvested := trm.harvest(Vector2i(1, 1))
	assert_eq(harvested.get("amount"), 0, "равнина = 0")
	trm.free()


func test_is_harvestable() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	assert_true(trm.is_harvestable(Vector2i(0, 0)), "forest harvestable")
	assert_false(trm.is_harvestable(Vector2i(1, 1)), "plain not")
	trm.free()


# ==================== PERSISTENCE ====================

func test_persistence_roundtrip() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	trm.harvest(Vector2i(0, 0))  # истощим одну точку

	var data: Dictionary = trm.to_dict()
	assert_true(data.has(str(Vector2i(0, 0))), "истощённая в словаре")

	var restored := _TRM.new()
	restored.generate(_make_map(), 1.0)  # restore работает только по существующим клеткам
	restored.restore_from_dict(data)
	assert_true(restored.is_exhausted(Vector2i(0, 0)),
			"восстановлено истощение (0,0)")
	assert_false(restored.is_exhausted(Vector2i(4, 4)),
			"гора не истощена")
	trm.free()
	restored.free()


func test_mark_exhausted() -> void:
	var trm := _TRM.new()
	trm.generate(_make_map(), 1.0)
	trm.mark_exhausted([Vector2i(4, 4)])
	assert_true(trm.is_exhausted(Vector2i(4, 4)), "mark_exhausted")
	trm.free()
