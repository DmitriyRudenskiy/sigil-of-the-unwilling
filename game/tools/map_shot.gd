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
##   --fog=1 — включить туман войны (по умолчанию снят: машинные меры меряют террейн).
##   --zoom=0.5 — масштаб кадра (тот же Camera2D.zoom, что ZOOM_LEVELS в игре: 0.5…2.25,
##            дефолт 1.0). Нужен глазному ревью «видно на масштабе, на котором играют»;
##            геометрия кадра и размер тайла пишутся в тех же единицах, что нарисованы.
##
## Про --fog (T-137): раньше флаг только «не мешал» и молчал: туман рисует
## map_renderer по VisibilityMap, а её в этом харнессе никто не создавал (в игре её
## создаёт world_controller), значит `mg.visibility` был null при обоих значениях и
## кадр от флага не менялся ни на байт. Теперь флаг включает туман тем же состоянием,
## что живой рантайм на старте (`world_bootstrap`: VisibilityMap + recompute до первого
## кадра), и падает с кодом 4, если туман не включился. Кадр с туманом — предмет
## глазного ревью (п. 8 чек-листа), а не машинных мер: в `check_map_art` он не подаётся,
## тумана нет ни в 17 мерах, ни в мутациях `--self-test` (гейт печатает свой охват).

const DEFAULT_SEED := 4242
const DEFAULT_SIZE := 40
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var out := _arg("--out", "/tmp/map-shot/map.png")
	var seed_value := int(_arg("--seed", str(DEFAULT_SEED)))
	var side := int(_arg("--size", str(DEFAULT_SIZE)))
	var zoom := float(_arg("--zoom", "1"))
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
	# --center=x,y — снять вокруг конкретной клетки: окрестность деревни по умолчанию
	# это луг и дороги, а глазное ревью леса/скал требует своего биома.
	var center_cell := Vector2i(side / 2, side / 2)
	if _arg("--center", "") != "":
		center_cell = Vector2i(int(_arg("--center", "0,0").get_slice(",", 0)),
				int(_arg("--center", "0,0").get_slice(",", 1)))
	var center: Vector2 = mg.map_to_local(center_cell)
	# Зум — масштаб узла карты (в игре это Camera2D.zoom). Сдвиг вычитается уже после
	# масштаба, а геометрия умножается на тот же коэффициент: иначе клетки.json разойдутся
	# с пикселями и меры начнут мерить не там, где нарисовано.
	scene.scale = Vector2(zoom, zoom)
	scene.position = Vector2(float(VIEWPORT_SIZE.x), float(VIEWPORT_SIZE.y)) / 2.0 - center * zoom

	# По умолчанию тумана нет: карту красит map_generator в _ready(), VisibilityMap не
	# создаётся. Ветка «снять туман» отсюда удалена как мёртвая — при null visibility
	# она не выполнялась никогда, только выглядела как действие.
	var fog_cells := 0
	if with_fog:
		var vis = load("res://scripts/core/visibility_map.gd").new()
		vis.set_map_size(side, side)
		# То же состояние, что мир на старте: обзор героя в центре карты, своих городов нет.
		vis.recompute(Vector2i(side / 2, side / 2), [], GameNumbers.FOG_HERO_SIGHT,
				GameNumbers.FOG_CITY_SIGHT, mg.hex_shift_right)
		mg.visibility = vis
		mg.apply_fog(vis)
		for cell in mg.model.terrain_grid:
			if not vis.is_explored(cell) or not vis.is_visible(cell):
				fog_cells += 1
		if fog_cells == 0:
			# Флаг не имеет права снова значить «ничего»: просили туман — требуй туман.
			push_error("map_shot: --fog=1 запрошен, туман не включился (вне видимости 0 клеток)")
			quit(4)
			return

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
	_dump_geometry(mg, scene, global_out, img.get_size(), to_biome, biome_names, zoom)
	var fog_flag := "on" if with_fog else "off"
	print("SHOT %s %dx%d seed=%d cells=%d fog=%s fog_cells=%d zoom=%.2f" % [
		global_out, img.get_width(), img.get_height(), seed_value,
		mg.model.terrain_grid.size(), fog_flag, fog_cells, zoom,
	])
	quit(0)


## Геометрия кадра: центр клетки в пикселях снимка (локация клетки + сдвиг узла).
func _dump_geometry(mg, scene: Node2D, shot_path: String, size: Vector2i,
		to_biome: Dictionary, biome_names: PackedStringArray, zoom: float = 1.0) -> void:
	var cells := {}
	for cell in mg.model.terrain_grid:
		var p: Vector2 = mg.map_to_local(cell) * zoom + scene.position
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
		"tile": [int(round(mg.get_tile_size().x * zoom)), int(round(mg.get_tile_size().y * zoom))],
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
