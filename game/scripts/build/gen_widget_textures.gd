extends SceneTree
## Task 7: текстуры UI-виджетов (кнопки, панели, бары, слайдер, чекбоксы).
## Запуск: Godot --headless --path . -s res://scripts/build/gen_widget_textures.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := "res://assets/ui/widgets"
	_dir(root + "/buttons")
	_dir(root + "/panels")
	_dir(root + "/progress_bars")
	_dir(root + "/sliders")
	_dir(root + "/decorators")

	# Кнопки: 4 состояния (9-slice: рамка + заливка)
	_button(root + "/buttons/button_normal.png", Color(0.15, 0.35, 0.75), Color(0.3, 0.5, 0.9))
	_button(root + "/buttons/button_hover.png", Color(0.2, 0.45, 0.9), Color(0.4, 0.6, 1.0))
	_button(root + "/buttons/button_pressed.png", Color(0.1, 0.25, 0.6), Color(0.25, 0.4, 0.8))
	_button(root + "/buttons/button_disabled.png", Color(0.3, 0.3, 0.32), Color(0.4, 0.4, 0.42))

	# Панели и слоты
	_panel(root + "/panels/panel_bg.png", Color(0.16, 0.11, 0.06, 0.95), Color(0.62, 0.47, 0.22))
	_panel(root + "/panels/slot_bg.png", Color(0.227, 0.141, 0.082, 0.95), Color(0.125, 0.062, 0.023))

	# Прогресс-бары: фон + заполнение (здоровье/мана/опыт)
	_bar(root + "/progress_bars/bar_bg.png", Color(0.08, 0.06, 0.04, 0.9), Color(0.4, 0.3, 0.18))
	_bar(root + "/progress_bars/bar_health_fill.png", Color(0.8, 0.2, 0.15), Color(1.0, 0.4, 0.3))
	_bar(root + "/progress_bars/bar_mana_fill.png", Color(0.2, 0.4, 0.9), Color(0.4, 0.6, 1.0))
	_bar(root + "/progress_bars/bar_xp_fill.png", Color(0.9, 0.75, 0.2), Color(1.0, 0.9, 0.4))

	# Слайдер: дорожка + ползунок
	_bar(root + "/sliders/slider_track.png", Color(0.1, 0.08, 0.05, 0.9), Color(0.4, 0.3, 0.18))
	_slider_handle(root + "/sliders/slider_handle.png")

	# Чекбоксы
	_checkbox(root + "/decorators/checkbox_unchecked.png", false)
	_checkbox(root + "/decorators/checkbox_checked.png", true)

	print("[WidgetTextureGenerator] done")
	quit(0)

func _dir(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		DirAccess.make_dir_recursive_absolute(p)

func _button(path: String, bg: Color, border: Color) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, border if (x < 2 or y < 2 or x >= 30 or y >= 30) else bg)
	img.save_png(path)

func _panel(path: String, bg: Color, border: Color) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, border if (x < 2 or y < 2 or x >= 30 or y >= 30) else bg)
	img.save_png(path)

func _bar(path: String, bg: Color, border: Color) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, border if (x < 1 or y < 1 or x >= 15 or y >= 15) else bg)
	img.save_png(path)

func _slider_handle(path: String) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var inside := x >= 4 and x < 12 and y >= 2 and y < 14
			var border := x >= 3 and x < 13 and y >= 1 and y < 15
			if border:
				img.set_pixel(x, y, Color(0.62, 0.47, 0.22))
			elif inside:
				img.set_pixel(x, y, Color(0.3, 0.2, 0.12))
	img.save_png(path)

func _checkbox(path: String, checked: bool) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var border := x < 1 or y < 1 or x >= 15 or y >= 15
			var mark := checked and x >= 4 and x < 12 and y >= 4 and y < 12
			if border:
				img.set_pixel(x, y, Color(0.62, 0.47, 0.22))
			elif mark:
				img.set_pixel(x, y, Color(0.2, 1.0, 0.4))
			else:
				img.set_pixel(x, y, Color(0.16, 0.11, 0.06, 0.95))
	img.save_png(path)
