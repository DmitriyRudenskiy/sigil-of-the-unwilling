extends "res://tests/gut_base.gd"
## Тест: MapGenerator сохраняет seed_value до generate().

# Предзагрузка зависимостей, чтобы class_name резолвились в headless-режиме
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _MapRenderer = preload("res://scripts/world/MapRenderer.gd")
const _MapSpawner = preload("res://scripts/world/MapSpawner.gd")
const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")

var _mg: Node = null


func after_each() -> void:
	if _mg != null:
		_mg.free()
		_mg = null


func test_seed_persistence_before_generate() -> void:
	# new() без добавления в дерево — _ready() не вызывается
	_mg = _MapGenerator.new()
	_mg.seed_value = 777
	assert_eq(_mg.seed_value, 777, "MapGenerator хранит seed_value до generate()")


func test_size_persistence_before_generate() -> void:
	_mg = _MapGenerator.new()
	_mg.map_width = 80
	_mg.map_height = 40
	assert_eq(_mg.map_width, 80, "MapGenerator хранит map_width до generate()")
	assert_eq(_mg.map_height, 40, "MapGenerator хранит map_height до generate()")
