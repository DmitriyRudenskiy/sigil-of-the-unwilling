extends SceneTree

## Снимок экрана карты для машинных мер (world-map-art-variety, гейт «Замер на живом
## рендере»). Рендерится настоящий `MapGenerator` с настоящим атласом в offscreen
## SubViewport: кадр — пиксели того же рендера, что видит игрок, а не монтаж из файлов.
##
## Рядом с PNG пишется геометрия (`<кадр>.cells.json`): центр каждой клетки в пикселях
## кадра и размер тайла. Модель (какой тайл где нарисован) НЕ вывозится — меры «не
## паттерн» считаются по пикселям, геометрия нужна только чтобы знать, где клетка.
##
## Запуск НЕ headless (нужен рендер, см. tools/ux_shots.gd):
##   Godot --path game -s tools/map_shot.gd -- --seed=4242 --size=40 --out=/tmp/map.png
##   --fog=1 — оставить туман войны (по умолчанию снят: меряется террейн, а не видимость)

const DEFAULT_SEED := 4242
const DEFAULT_SIZE := 40
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var out := _arg("--out", "/tmp/map-shot/map.png")
	var seed_value := int(_arg("--seed", str(DEFAULT_SEED)))
	var side := int(_arg("--size", str(DEFAULT_SIZE)))
	var with_fog := _arg("--fog", "0") == "1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var atlas = load("res://scripts/world/tile_atlas.gd")
	var renderer = load("res://scripts/world/map_renderer.gd")
	var biome_names: PackedStringArray = atlas.Biome.keys()
	var to_biome: Dictionary = renderer.TERRAIN_TO_BIOME

	var scene := Node2D.new()
	viewport.add_child(scene)
	var mg = load("res://scenes/world/map_generator.tscn").instantiate()
	mg.map_width = side
	mg.map_height = side
	mg.seed_value = seed_value
	scene.add_child(mg)
	# generate() живёт в _ready(), а он пройдёт не раньше ближайшего кадра
	await _frames(5)

	# Кадр задаём сдвигом узла карты: камера в offscreen-вьюпорте не гарантирована,
	# а сдвиг — тот же, из которого считается геометрия кадра.
	var center: Vector2 = mg.map_to_local(Vector2i(side / 2, side / 2))
	scene.position = Vector2(float(VIEWPORT_SIZE.x), float(VIEWPORT_SIZE.y)) / 2.0 - center

	if not with_fog and mg.visibility != null:
		for cell in mg.model.terrain_grid:
			mg.visibility.explored[cell] = true
			mg.visibility.visible[cell] = true
		mg.apply_fog(mg.visibility)

	await _frames(20)

	var img := viewport.get_texture().get_image()
	if img == null:
		push_error("map_shot: рендер вернул пустую текстуру (нет дисплея?)")
		quit(2)
		return
	var global_out := ProjectSettings.globalize_path(out)
	if img.save_png(global_out) != OK:
		push_error("map_shot: не удалось записать %s" % global_out)
		quit(3)
		return
	_dump_geometry(mg, scene, global_out, img.get_size(), to_biome, biome_names)
	print("SHOT %s %dx%d seed=%d cells=%d" % [global_out, img.get_width(), img.get_height(),
		seed_value, mg.model.terrain_grid.size()])
	quit(0)


## Геометрия кадра: центр клетки в пикселях снимка (локация клетки + сдвиг узла).
func _dump_geometry(mg, scene: Node2D, shot_path: String, size: Vector2i,
		to_biome: Dictionary, biome_names: PackedStringArray) -> void:
	var cells := {}
	for cell in mg.model.terrain_grid:
		var p: Vector2 = mg.map_to_local(cell) + scene.position
		if p.x < 0.0 or p.y < 0.0 or p.x > size.x or p.y > size.y:
			continue
		# Подпись биома — только для группировки клеток при замере; само различие
		# считается по пикселям кадра (иначе гейт сверял бы модель с моделью).
		var biome: int = int(to_biome.get(int(mg.model.terrain_grid[cell]), -1))
		if biome < 0:
			continue
		cells["%d,%d" % [cell.x, cell.y]] = [int(round(p.x)), int(round(p.y)),
			biome_names[biome].to_lower()]
	var payload := {
		"tile": [int(mg.get_tile_size().x), int(mg.get_tile_size().y)],
		"size": [size.x, size.y],
		"seed": mg.seed_value,
		"cells": cells,
	}
	var f := FileAccess.open(shot_path + ".cells.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload))
		f.close()


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.get_slice("=", 1)
	return def


func _frames(n: int) -> void:
	for i in n:
		await process_frame
