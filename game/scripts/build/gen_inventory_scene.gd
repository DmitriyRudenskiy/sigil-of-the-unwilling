extends SceneTree

var OUT := "res://scenes/ui/artifact_inventory_screen.tscn"

var _ext: Array = []
var _node_lines: Array = []

# Геометрия сетки снаряжения живёт в скрипте экрана; генератор берёт её оттуда же,
# чтобы раскладка сцены и `_refresh_grid()` не разъезжались.
const _Screen = preload("res://scripts/ui/artifact_inventory_screen.gd")

const _DOLL_X := [258, 318, 180, 6, 68, 318, 180, 318, 6, 22, 318, 46, 258, 6, 68, 318]
const _DOLL_Y := [6, 6, 66, 58, 58, 68, 146, 130, 160, 230, 218, 300, 298, 370, 370, 392]

func _ext_resource(res_type: String, path: String, uid: int) -> void:
	var rec := {"type": res_type, "path": path, "id": uid}
	_ext.append(rec)

func _add_node(name: String, typ: String, parent_path: String, extra: String = "", uid: int = 0) -> void:
	var line := "[node name=\"" + name + "\" type=\"" + typ + "\""
	if uid > 0:
		line += " unique_id=" + str(uid)
	if parent_path != "":
		line += " parent=\"" + parent_path + "\""
	line += "]"
	if extra != "":
		line += "\n" + extra
	line += "\n\n"
	_node_lines.append(line)

func _build() -> void:
	_ext_resource("Script", "res://scripts/ui/artifact_inventory_screen.gd", 1)

	var uid := 1000

	_add_node("ArtifactInventoryScreen", "Control", "", "script = ExtResource(\"1\")", uid)
	uid += 1

	# Центр окна — обычный Control, а не CenterContainer (T-154, дефект «а»):
	# контейнер разворачивал Window (обычный Control без min-size) в 0×0, весь
	# контент разбегался от центра, а рамка Outline не рисовалась вовсе.
	_add_node(
		"Center", "Control", ".",
		"offset_left = 10.0\noffset_top = 10.0\noffset_right = 1410.0\noffset_bottom = 690.0\n", uid)
	uid += 1

	_add_node(
		"Window", "Control", "Center",
		"offset_left = 10.0\noffset_top = 10.0\noffset_right = 1390.0\noffset_bottom = 670.0\n", uid)
	uid += 1

	# Рамка — на весь Window: без якорей PanelContainer свёрнут в 0×0 и рамку не рисует.
	_add_node(
		"Outline", "PanelContainer", "Center/Window",
		"anchor_right = 1.0\nanchor_bottom = 1.0\ntheme_type_variation = &\"ArtifactOutline\"\n", uid)
	uid += 1

	# Left/Side/Right — не прямоугольники-колонки, а нулевые точки: их дети
	# расписаны в координатах окна (историческая разметка сцены). См. комментарий
	# у _box ниже: смещение родителя сложилось бы с offset ребёнка дважды.
	_add_node("Left", "Control", "Center/Window", _box(0, 0, 0, 0), uid)
	uid += 1

	_add_node(
		"Portrait", "TextureRect", "Center/Window/Left",
		"offset_left = 11.0\noffset_top = 11.0\noffset_right = 91.0\noffset_bottom = 91.0\nstretch_mode = 5\n", uid)
	uid += 1

	_add_node(
		"Name", "Label", "Center/Window/Left",
		"offset_left = 100.0\noffset_top = 31.0\noffset_right = 300.0\noffset_bottom = 60.0\n", uid)
	uid += 1

	for i in 4:
		_add_node(
			"StatIcon_" + str(i), "TextureRect", "Center/Window/Left",
			"offset_left = " + str(20 + i * 101) + ".0\noffset_top = 95.0\noffset_right = " + str(66 + i * 101) + ".0\noffset_bottom = 141.0\n", uid)
		uid += 1

	for i in 4:
		_add_node(
			"StatName_" + str(i), "Label", "Center/Window/Left",
			"offset_left = " + str(20 + i * 101) + ".0\noffset_top = 143.0\noffset_right = " + str(121 + i * 101) + ".0\noffset_bottom = 161.0\n", uid)
		uid += 1

	for i in 4:
		_add_node(
			"StatValue_" + str(i), "Label", "Center/Window/Left",
			"offset_left = " + str(12 + i * 101) + ".0\noffset_top = 168.0\noffset_right = " + str(109 + i * 101) + ".0\noffset_bottom = 189.0\n", uid)
		uid += 1

	_add_node(
		"Mana_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 191.0\noffset_right = 162.0\noffset_bottom = 211.0\n", uid)
	uid += 1
	_add_node(
		"Mana_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 191.0\noffset_right = 300.0\noffset_bottom = 211.0\n", uid)
	uid += 1
	_add_node(
		"Exp_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 240.0\noffset_right = 162.0\noffset_bottom = 260.0\n", uid)
	uid += 1
	_add_node(
		"Exp_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 240.0\noffset_right = 300.0\noffset_bottom = 260.0\n", uid)
	uid += 1
	_add_node(
		"School_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 289.0\noffset_right = 162.0\noffset_bottom = 309.0\n", uid)
	uid += 1
	_add_node(
		"School_val", "Label", "Center/Window/Left",
		"offset_left = 204.0\noffset_top = 289.0\noffset_right = 300.0\noffset_bottom = 309.0\n", uid)
	uid += 1

	_add_node(
		"Skills_lbl", "Label", "Center/Window/Left",
		"offset_left = 12.0\noffset_top = 320.0\noffset_right = 132.0\noffset_bottom = 340.0\n", uid)
	uid += 1

	for i in 6:
		_add_node(
			"Skill_" + str(i), "Button", "Center/Window/Left",
			"offset_left = " + str(22 + (i % 2) * 190) + ".0\noffset_top = " + str(352 + (i / 2) * 82) + ".0\noffset_right = " + str(142 + (i % 2) * 190) + ".0\noffset_bottom = " + str(422 + (i / 2) * 82) + ".0\n", uid)
		uid += 1
		_add_node(
			"SkillIcon", "TextureRect", "Center/Window/Left/Skill_" + str(i),
			"mouse_filter = 2\n" + _box(8, 15, 48, 55), uid)
		uid += 1
		_add_node(
			"SkillLevel", "Label", "Center/Window/Left/Skill_" + str(i),
			"visible = false\nmouse_filter = 2\nhorizontal_alignment = 1\n" + _gold(20) + "\n" + _box(52, 24, 112, 46), uid)
		uid += 1

	_add_node("Right", "Control", "Center/Window", _box(0, 0, 0, 0), uid)
	uid += 1

	_add_node(
		"Figure", "TextureRect", "Center/Window/Right",
		"offset_left = 607.0\noffset_top = 13.0\noffset_right = 847.0\noffset_bottom = 373.0\nstretch_mode = 5\n", uid)
	uid += 1

	for i in 16:
		_add_node(
			"DollSlot_" + str(i), "TextureRect", "Center/Window/Right",
			"offset_left = " + str(510 + _DOLL_X[i]) + ".0\noffset_top = " + str(10 + _DOLL_Y[i]) + ".0\noffset_right = " + str(566 + _DOLL_X[i]) + ".0\noffset_bottom = " + str(66 + _DOLL_Y[i]) + ".0\n", uid)
		uid += 1
		_add_node(
			"EquipIcon", "TextureRect", "Center/Window/Right/DollSlot_" + str(i),
			"visible = false\nmouse_filter = 2\n" + _box(0, 0, 56, 56), uid)
		uid += 1

	# Сетка снаряжения (grid-inventory-and-merchant 4.1): 6×4 клетки по 56 px
	# с шагом 60 вместо шести BackpackSlot_* и постраничной прокрутки. Координаты
	# берёт один источник — константы экрана, иначе генератор и `_refresh_grid()`
	# разъедутся на первом же изменении размера клетки.
	var g: Vector2i = _Screen.GRID_ORIGIN
	var pitch: int = _Screen.CELL_PITCH
	var cell: int = _Screen.CELL_SIZE
	_add_node(
		"Grid", "Control", "Center/Window/Right",
		_box(g.x, g.y, g.x + pitch * 6, g.y + pitch * 4), uid)
	uid += 1
	for row in 4:
		for col in 6:
			# Координаты — внутри Grid'а (сам Grid стоит в сетке окна), иначе
			# смещение родителя сложится с offset клетки дважды.
			var x0: int = col * pitch
			var y0: int = row * pitch
			_add_node(
				"GridCell_%d_%d" % [col, row], "ColorRect", "Center/Window/Right/Grid",
				"mouse_filter = 2\n" + _box(x0, y0, x0 + cell, y0 + cell)
				+ "color = " + _color(_Screen.CELL_EMPTY), uid)
			uid += 1
	_add_node(
		"Items", "Control", "Center/Window/Right/Grid",
		"mouse_filter = 2\n" + _box(0, 0, pitch * 6, pitch * 4), uid)
	uid += 1

	_add_node(
		# Подпись — по левому краю колонки: полоса перевеса растёт вправо от
		# x=900, и центрированная подпись уезжала бы от своих предметов (кадр
		# 2026-10-27: «Перевес» на 260 px правее первой иконки).
		"Overflow_lbl", "Label", "Center/Window/Right",
		_box(900, 286, 1390, 310), uid)
	uid += 1
	_add_node(
		"Overflow", "Control", "Center/Window/Right",
		"mouse_filter = 2\n" + _box(900, 310, 1390, 370), uid)
	uid += 1
	_add_node(
		"Desc_lbl", "Label", "Center/Window/Right",
		_box(900, 386, 1390, 410), uid)
	uid += 1
	_add_node(
		# Ни цвета, ни размера: цвет наследуется от корня экрана (золото), а
		# размер — от темы. Свои override'ы сюда просить нельзя: font_color
		# считается мёртвым (T-189), а размер ниже 16 — нечитаемым (T-190).
		"Desc", "Label", "Center/Window/Right",
		"autowrap_mode = 3\nvertical_alignment = 1\n" + _box(900, 410, 1390, 460), uid)
	uid += 1

	# Кнопки действий — справа от сетки: раньше они стояли на y 531..577, то есть
	# поверх панели армии (Bottom 470..650).
	for pair in [["Equip", 26], ["Remove", 90], ["Dispose", 154]]:
		_add_node(
			String(pair[0]), "Button", "Center/Window/Right",
			_box(1280, int(pair[1]), 1390, int(pair[1]) + 56), uid)
		uid += 1

	_add_node("Side", "Control", "Center/Window", _box(0, 0, 0, 0), uid)
	uid += 1

	_add_node(
		"Banner", "TextureRect", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 19.0\noffset_right = 391.0\noffset_bottom = 81.0\nstretch_mode = 5\n", uid)
	uid += 1
	_add_node(
		"Mini", "TextureRect", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 89.0\noffset_right = 391.0\noffset_bottom = 135.0\nstretch_mode = 5\n", uid)
	uid += 1
	for i in 6:
		_add_node(
			"SideSlot_" + str(i), "TextureRect", "Center/Window/Side",
			"offset_left = 329.0\noffset_top = " + str(132 + i * 50) + ".0\noffset_right = 391.0\noffset_bottom = " + str(174 + i * 50) + ".0\n", uid)
		uid += 1
	_add_node(
		"Ok", "Button", "Center/Window/Side",
		"offset_left = 329.0\noffset_top = 542.0\noffset_right = 391.0\noffset_bottom = 588.0\n", uid)
	uid += 1

	_add_node(
		"Bottom", "PanelContainer", "Center/Window",
		"theme_type_variation = &\"ArtifactBottom\"\n" + _box(10, 470, 1390, 650), uid)
	uid += 1

	for i in 7:
		_add_node(
			"ArmySlot_" + str(i), "TextureRect", "Center/Window/Bottom",
			"offset_left = " + str(10 + i * 82) + ".0\noffset_top = 10.0\noffset_right = " + str(86 + i * 82) + ".0\noffset_bottom = 86.0\n", uid)
		uid += 1
		_add_node(
			"ArmyIcon", "TextureRect", "Center/Window/Bottom/ArmySlot_" + str(i),
			"visible = false\nmouse_filter = 2\n" + _box(6, 6, 70, 70), uid)
		uid += 1
		_add_node(
			"ArmyCount", "Label", "Center/Window/Bottom/ArmySlot_" + str(i),
			"visible = false\nmouse_filter = 2\nhorizontal_alignment = 2\n"
			+ "theme_type_variation = &\"LabelNumber\"\n" + _box(6, 50, 74, 76), uid)
		uid += 1

	_add_node(
		"Formations", "Control", "Center/Window/Bottom",
		_box(1224, 11, 1357, 84), uid)
	uid += 1
	for i in 4:
		_add_node(
			"Form_" + str(i), "Button", "Center/Window/Bottom/Formations",
			"offset_left = " + str(6 + (i % 2) * 66) + ".0\noffset_top = " + str(6 + (i / 2) * 36) + ".0\noffset_right = " + str(66 + (i % 2) * 66) + ".0\noffset_bottom = " + str(38 + (i / 2) * 36) + ".0\n", uid)
		uid += 1

## Координаты узла. Родители детей Left/Side/Right — нулевые точки, поэтому
## числа здесь читаются как координаты окна, а не как смещение внутри колонки.
func _box(l: int, t: int, r: int, b: int) -> String:
	return "offset_left = " + str(l) + ".0\noffset_top = " + str(t) + ".0\noffset_right = " + str(r) + ".0\noffset_bottom = " + str(b) + ".0\n"

## Литерал цвета для .tscn: `str(Color)` отдаёт кортеж `(r, g, b, a)`, а редактор
## пишет `Color(r, g, b, a)`; без обёртки каждый прогон генератора переписывал
## бы цвет в файле (дрейф 107 строк, найден 2026-10-27).
func _color(c: Color) -> String:
	return "Color" + str(c) + "\n"

func _gold(sz: int) -> String:
	return "theme_override_colors/font_color = " + _color(ThemeConfig.C_TEXT_GOLD_SOFT) + "theme_override_font_sizes/font_size = " + str(sz)

func _white(sz: int) -> String:
	return "theme_override_colors/font_color = " + _color(ThemeConfig.C_TEXT_WHITE) + "theme_override_font_sizes/font_size = " + str(sz)

func _emit() -> void:
	var out := ""
	out += "[gd_scene load_steps=" + str(_ext.size() + 1) + " format=3]\n"
	for e in _ext:
		out += '[ext_resource type="' + e.type + '" path="' + e.path + '" id="' + str(e.id) + '"]\n'
	for l in _node_lines:
		out += l + "\n"
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		print("GEN ERROR: cannot open " + OUT)
		return
	f.store_string(out)
	f.close()
	print("WROTE " + str(_node_lines.size()) + " nodes, " + str(_ext.size()) + " ext_resources -> " + OUT)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_build()
	_emit()
	quit(0)
