extends Control
class_name MainMenu
## Главное меню по референсу тронного зала:
## фон — тронный зал; справа колонка: серая панель с 🔒 + три синие глянцевые кнопки

func _ready() -> void:
	_build_background()
	_build_right_column()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex := _find_bg()
	if tex != null:
		bg.texture = tex
	else:
		bg.texture = _placeholder()
		print("[MainMenu] TODO: положить арт тронного зала в res://assets/ui/main_menu_bg.png")
	add_child(bg)


func _find_bg() -> Texture2D:
	for c in ["res://assets/ui/main_menu_bg.png", "res://assets/ui/throne.png"]:
		if ResourceLoader.exists(c):
			return load(c)
	# автопоиск в raw по имени
	var dir := DirAccess.open("res://assets/raw")
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			var low := f.to_lower()
			if low.find("throne") != -1 or low.find("menu") != -1 or low.find("tron") != -1:
				if FileAccess.file_exists("res://assets/raw/" + f):
					return load("res://assets/raw/" + f)
			f = dir.get_next()
	return null


func _placeholder() -> ImageTexture:
	var img := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	for y in 1080:
		var t := float(y) / 1080.0
		for x in 1920:
			img.set_pixel(x, y, Color(lerpf(0.08, 0.02, t), lerpf(0.06, 0.01, t), lerpf(0.15, 0.05, t)))
	return ImageTexture.create_from_image(img)


func _build_right_column() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -380
	col.offset_right = -60
	col.offset_top = 120
	col.offset_bottom = -120
	col.add_theme_constant_override("separation", 20)
	add_child(col)

	# Серая панель с 🔒 (как на референсе)
	var lock := PanelContainer.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.35, 0.35, 0.38, 0.85)
	ls.set_corner_radius_all(8)
	ls.set_border_width_all(2)
	ls.border_color = Color(0.5, 0.5, 0.55)
	lock.add_theme_stylebox_override("panel", ls)
	lock.custom_minimum_size = Vector2(300, 180)
	col.add_child(lock)

	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.add_child(lv)
	var li := Label.new()
	li.name = "LockIcon"
	li.text = "🔒"
	li.add_theme_font_size_override("font_size", 64)
	li.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(li)
	var lt := Label.new()
	lt.text = "Кампания недоступна"
	lt.add_theme_font_size_override("font_size", 16)
	lt.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(lt)

	# Три синие глянцевые кнопки
	for bd in [["Новая игра", "_on_new_game"], ["Загрузить", "_on_load_game"], ["Выход", "_on_exit"]]:
		var btn := Button.new()
		btn.text = bd[0]
		btn.custom_minimum_size = Vector2(300, 70)
		btn.add_theme_font_size_override("font_size", 24)
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.15, 0.35, 0.75)
		sn.set_corner_radius_all(10)
		sn.set_border_width_all(2)
		sn.border_color = Color(0.3, 0.5, 0.9)
		sn.shadow_color = Color(0.1, 0.2, 0.5, 0.5)
		sn.shadow_size = 4
		btn.add_theme_stylebox_override("normal", sn)
		var sh := sn.duplicate()
		sh.bg_color = Color(0.2, 0.45, 0.9)
		btn.add_theme_stylebox_override("hover", sh)
		var sp := sn.duplicate()
		sp.bg_color = Color(0.1, 0.25, 0.6)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		btn.pressed.connect(Callable(self, bd[1]))
		col.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var ver := Label.new()
	ver.text = "HoMM3 Clone v0.1 — Godot 4.7"
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")


func _on_load_game() -> void:
	var lock := get_node_or_null("VBoxContainer/PanelContainer")
	if lock != null:
		var tw := create_tween()
		tw.tween_property(lock, "modulate", Color(1, 0.5, 0.5), 0.15)
		tw.tween_property(lock, "modulate", Color.WHITE, 0.15)
	print("[MainMenu] Load: не реализовано в прототипе")


func _on_exit() -> void:
	get_tree().quit()
