class_name WorldSpawner
extends Node2D
## Спавн и удаление объектов мира: деревни, ресурсы, враги.

var map: MapGenerator = null


func spawn_all() -> void:
	if map == null or not map.has_valid_tilemap():
		return
	_spawn_villages()
	_spawn_resources()
	_spawn_enemies()


func remove_resource_at(cell: Vector2i) -> bool:
	for child in get_children():
		if child.has_meta("cell") and child.get_meta("cell") == cell and child.has_meta("res_type"):
			child.queue_free()
			return true
	return false


func remove_enemy_at(cell: Vector2i) -> bool:
	for child in get_children():
		if child.has_meta("enemy_cell") and child.get_meta("enemy_cell") == cell:
			child.queue_free()
			return true
	return false


func capture_village(cell: Vector2i) -> bool:
	for child in get_children():
		if child.has_meta("cell") and child.get_meta("cell") == cell:
			var flag := child.get_node_or_null("Flag")
			if flag != null:
				flag.text = "🏳️"
				return true
	return false


func _spawn_villages() -> void:
	for cell in map.village_cells:
		var v := Node2D.new()
		v.set_meta("cell", cell)
		var sp := Sprite2D.new()
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				if y < 20 and abs(x - 24) < (24 - y) * 0.8:
					img.set_pixel(x, y, Color(0.7, 0.2, 0.1))
				elif y >= 20 and y < 42 and x >= 10 and x <= 38:
					img.set_pixel(x, y, Color(0.6, 0.5, 0.3))
		sp.texture = ImageTexture.create_from_image(img)
		sp.z_index = 5
		v.add_child(sp)
		var flag := Label.new()
		flag.name = "Flag"
		flag.text = "🚩"
		flag.add_theme_font_size_override("font_size", 16)
		flag.position = Vector2(18, -20)
		v.add_child(flag)
		v.position = map.map_to_local(cell)
		add_child(v)


func _spawn_resources() -> void:
	var icons := ["🪵", "🧪", "🪨", "🟡", "🔷", "💎", "🪙"]
	for cell in map.resource_cells:
		var res_type: int = map.resource_cells[cell]
		var r := Node2D.new()
		r.set_meta("cell", cell)
		r.set_meta("res_type", res_type)
		var lbl := Label.new()
		lbl.text = icons[res_type] if res_type < icons.size() else "?"
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.position = Vector2(-12, -12)
		r.add_child(lbl)
		r.position = map.map_to_local(cell)
		r.z_index = 6
		add_child(r)


func _spawn_enemies() -> void:
	for cell in map.enemy_stacks:
		var army: Array = map.enemy_stacks[cell]
		var e := Node2D.new()
		e.set_meta("enemy_cell", cell)
		var sp := Sprite2D.new()

		var first_unit = army[0]
		var key: String = first_unit.get_key()
		var portrait_path := UnitSprites.find_portrait_small(key)
		if portrait_path != "":
			sp.texture = load(portrait_path)
		else:
			var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
			var c := Vector2(24, 24)
			for y in 48:
				for x in 48:
					var d := Vector2(x, y).distance_to(c)
					if d <= 20:
						img.set_pixel(x, y, Color(0.7, 0.15, 0.1))
					elif d <= 22:
						img.set_pixel(x, y, Color(0.2, 0.05, 0.05))
			sp.texture = ImageTexture.create_from_image(img)
		sp.z_index = 6
		e.add_child(sp)
		e.position = map.map_to_local(cell)
		add_child(e)
