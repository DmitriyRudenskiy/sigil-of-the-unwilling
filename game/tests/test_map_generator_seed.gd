extends GdUnitTestSuite

const _MapModel = preload("res://scripts/world/MapModel.gd")
const _MapRenderer = preload("res://scripts/world/MapRenderer.gd")
const _MapSpawner = preload("res://scripts/world/MapSpawner.gd")
const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")

var _mg: Node = null


func after_test() -> void:
	if _mg != null:
		_mg.free()
		_mg = null


func test_seed_persistence_before_generate() -> void:
	_mg = _MapGenerator.new()
	_mg.seed_value = 777
	assert_that(_mg.seed_value).is_equal(777)


func test_size_persistence_before_generate() -> void:
	_mg = _MapGenerator.new()
	_mg.map_width = 80
	_mg.map_height = 40
	assert_that(_mg.map_width).is_equal(80)
	assert_that(_mg.map_height).is_equal(40)
