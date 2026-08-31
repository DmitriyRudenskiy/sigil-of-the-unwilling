extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Тест: MapGenerator сохраняет seed_value до generate().

# Предзагрузка зависимостей, чтобы class_name резолвились в headless-режиме
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _MapRenderer = preload("res://scripts/world/MapRenderer.gd")
const _MapSpawner = preload("res://scripts/world/MapSpawner.gd")
const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")

func _init() -> void:
	var failed := 0

	# new() без добавления в дерево — _ready() не вызывается
	var mg = _MapGenerator.new()
	mg.seed_value = 777

	if mg.seed_value != 777:
		printerr("MapGenerator must store seed_value before generate()")
		failed += 1
	else:
		print("MapGenerator seed persistence passed")

	# Дополнительно: проверка map_width / map_height до generate()
	mg.map_width = 80
	mg.map_height = 40

	if mg.map_width != 80:
		printerr("MapGenerator must store map_width before generate()")
		failed += 1
	else:
		print("MapGenerator map_width persistence passed")

	if mg.map_height != 40:
		printerr("MapGenerator must store map_height before generate()")
		failed += 1
	else:
		print("MapGenerator map_height persistence passed")

	_failed = failed
	_passed = 3 - failed

	mg.free()  # Node2D: освобождаем, чтобы не утекал в ObjectDB
	await process_frame
	quit(1 if failed > 0 else 0)
