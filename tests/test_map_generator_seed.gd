extends SceneTree
## Тест: MapGenerator сохраняет seed_value до generate().

# Предзагрузка зависимостей, чтобы class_name резолвились в headless-режиме
const _MapModel = preload("res://scripts/map/MapModel.gd")
const _MapRenderer = preload("res://scripts/map/MapRenderer.gd")
const _MapSpawner = preload("res://scripts/map/MapSpawner.gd")
const _MapGenerator = preload("res://scripts/MapGenerator.gd")

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

	await process_frame
	quit(1 if failed > 0 else 0)
