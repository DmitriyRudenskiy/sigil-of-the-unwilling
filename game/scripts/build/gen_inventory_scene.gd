extends SceneTree

## Генератор сцены экрана «Герой» (`scenes/ui/artifact_inventory_screen.tscn`).
##
## Состав и геометрия — не здесь: блоки берутся из `scripts/ui/hero_layout.gd`
## (единственная таблица, docs/20-ux-hero-screen.md §2–§3), ассеты — из
## `assets/ui/hero/MANIFEST.json`. Узлы расставлены якорями-долями, поэтому
## композиция макета держится при любом размере окна (AC «без прокрутки»).

var OUT := "res://scenes/ui/artifact_inventory_screen.tscn"

var _ext: Array = []
var _ids: Dictionary = {}
var _node_lines: Array = []

const _L = preload("res://scripts/ui/hero_layout.gd")

# id'ы ext_resource: 1 — скрипт экрана, дальше — носители кита hero/ и иконки.
const _KIT := {
	"panel_parchment": 10, "panel_stone": 11, "banner_name": 12,
	"frame_portrait": 13, "slot_doll": 14, "cell_grid": 15, "tile_brass": 16,
	"rule_brass": 17, "bar_track": 18, "bar_mana": 19, "bar_hp": 20,
	"figure": 21, "portrait": 22, "frame_card": 23, "frame_row": 24,
}

func _ext_resource(res_type: String, path: String, uid: int) -> void:
	if _ids.has(uid):
		return
	_ids[uid] = true
	_ext.append({"type": res_type, "path": path, "id": uid})

func _kit(name: String) -> String:
	_ext_resource("Texture2D", "res://assets/ui/hero/" + name + ".png", _KIT[name])
	return "ExtResource(\"" + str(_KIT[name]) + "\")"

func _icon(name: String) -> String:
	var id := 100 + _ext.size()
	_ext_resource("Texture2D", "res://assets/ui/icons/" + name + ".png", id)
	return "ExtResource(\"" + str(id) + "\")"

var _u := 1000

func _add_node(name: String, typ: String, parent_path: String, extra: String = "", _uid: int = 0) -> void:
	# В .tscn parent= — путь ОТ КОРНЯ, а не от предыдущего узла: блоки таблицы
	# пишутся как "Sheet/Left", а сцена живёт под Center/Window (без префикса
	# Godot теряет родителя и пересоздаёт узел в корне с именем "Sheet_Left").
	var pp := parent_path
	if pp != "" and pp != "." and not pp.begins_with("Center"):
		pp = "Center/Window/" + pp
	if typ == "TextureRect" and "expand_mode" not in extra:
		# KEEP_SIZE по умолчанию = минимум поперек текстуры: клетка сумки из
		# плитки 96 px не могла сжаться до своих 76 и вылезала за поле (T-255).
		extra += "expand_mode = 1\n"
	var line := "[node name=\"" + name + "\" type=\"" + typ + "\""
	if true:
		line += " unique_id=" + str(_u)
		_u += 1
	if pp != "":
		line += " parent=\"" + pp + "\""
	line += "]"
	if extra != "":
		line += "\n" + extra
	line += "\n\n"
	_node_lines.append(line)

## Якорные доли прямоугольника `r` (координаты канвы) внутри блока `parent`.
## Смещений узел не имеет вовсе: размер задают якоря, а не offset'ы.
func _anch(r: Rect2, parent: String) -> String:
	# Родитель — весь лист (canvas), если это не блок таблицы.
	var p := Rect2(Vector2.ZERO, _L.CANVAS)
	if _L.BLOCKS.has(parent):
		p = _L.BLOCKS[parent]
	return "anchor_left = %s\nanchor_top = %s\nanchor_right = %s\nanchor_bottom = %s\n" % [
		_f(r.position.x / p.size.x), _f(r.position.y / p.size.y),
		_f((r.position.x + r.size.x) / p.size.x),
		_f((r.position.y + r.size.y) / p.size.y)]

## Поля 9-slice паттерна — из реестра `assets/ui/hero/MANIFEST.json` (D-275).
var _margins := {}

func _kit_margin(name: String) -> int:
	if _margins.is_empty():
		var f := FileAccess.open("res://assets/ui/hero/MANIFEST.json", FileAccess.READ)
		if f != null:
			var raw: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if raw is Dictionary:
				var files: Variant = (raw as Dictionary).get("files", {})
				if files is Dictionary:
					# Ключи пути-именованные: files → "hero/panel_parchment.png".
					for k in (files as Dictionary):
						var e: Variant = (files as Dictionary)[k]
						if e is Dictionary and (e as Dictionary).has("margin"):
							_margins[str(k).get_file().get_basename()] = int((e as Dictionary)["margin"])
	return int(_margins.get(name, 40))


func _f(v: float) -> String:
	return "%.6f" % v

## Узел-блок из таблицы: якоря от `parent`, опциональный фон-плитка.
func _block(
		node: String, parent: String, uid: int, bg: String = "", inset: int = 0) -> void:
	# inset — внутренний отступ зоны в px: зона, вставшая впритык к границе
	# камня, читается как наложение на стык колонок (T-257).
	var props := _anch(_L.BLOCKS[node], parent)
	if inset > 0:
		props += "offset_left = %d\noffset_top = %d\noffset_right = %d\noffset_bottom = %d\n" % [
			-inset, -inset, inset, inset]
	_add_node(node, "Control", parent, props, uid)
	uid += 1
	if bg != "":
		# Поля 9-slice — из MANIFEST.json (D-275): у пергамента они 48 px, у камня 40,
		# общий литерал нарезал бы патч не по тому шву. Растяжение — STRETCH (0):
		# лист пергамента в макете один, тайлинг (1) давал бы швы и тёмные полосы.
		var m := _kit_margin(bg)
		_add_node(
			"Bg", "NinePatchRect", parent + "/" + node,
			"texture = " + _kit(bg) + "\n"
			+ "patch_margin_left = %d\npatch_margin_top = %d\n" % [m, m]
			+ "patch_margin_right = %d\npatch_margin_bottom = %d\n" % [m, m]
			+ "axis_stretch_horizontal = 0\naxis_stretch_vertical = 0\n"
			+ "mouse_filter = 2\nanchor_right = 1.0\nanchor_bottom = 1.0\n", uid)
		uid += 1

func _build() -> void:
	_ext_resource("Script", "res://scripts/ui/artifact_inventory_screen.gd", 1)
	var uid := 1000

	# Корень — на полных якорях: у Control, добавленного прямо в Viewport,
	# без якорей размер 0×0, и все доли блоков схлопываются в точку.
	_add_node(
		"ArtifactInventoryScreen", "Control", "",
		"anchor_right = 1.0\nanchor_bottom = 1.0\nscript = ExtResource(\"1\")", uid)
	uid += 1
	# Экран — на всё окно (корень на полных якорях): композиция макета 12
	# живёт долями, прокрутки нет и быть не должно (AC1, T-248).
	for pair in [["Center", "."], ["Window", "Center"], ["Sheet", "Center/Window"]]:
		_add_node(
			pair[0], "Control", pair[1],
			"anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n", uid)
		uid += 1
	_add_node(
		"Outline", "PanelContainer", "Center/Window",
		"anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n"
		+ "theme_type_variation = &\"ArtifactOutline\"\n", uid)
	uid += 1

	# — левая пергаментная колонка ------------------------------------------
	_block("Left", "Sheet", uid, "panel_parchment")
	uid += 1
	var left := "Sheet/Left"
	var L: Rect2 = _L.BLOCKS["Left"]
	var stats: Rect2 = _L.BLOCKS["Stats"]
	var list: Rect2 = _L.BLOCKS["EquipList"]

	_add_node(
		"PortraitFrame", "TextureRect", left,
		_anchor_within("Portrait", L) + "texture = " + _kit("frame_portrait")
		+ "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
	uid += 1
	_add_node(
		"Portrait", "TextureRect", left,
		_anchor_within("Portrait", L) + "texture = " + _kit("portrait")
		+ "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
	uid += 1
	# Плашка имени и «Уровень» — из макета; имени узла `Name` касаются тесты.
	_add_node(
		"NamePlate", "NinePatchRect", left,
		_anchor_within("Name", L) + "texture = " + _kit("banner_name")
		+ "\npatch_margin_left = 28\npatch_margin_top = 20\n"
		+ "patch_margin_right = 28\npatch_margin_bottom = 20\n"
		+ "axis_stretch_horizontal = 1\naxis_stretch_vertical = 1\nmouse_filter = 2\n", uid)
	uid += 1
	_add_node(
		"Name", "Label", left,
		_anchor_within("Name", L)
		+ "horizontal_alignment = 1\nvertical_alignment = 1\n"
		+ "theme_type_variation = &\"LabelTitle\"\n", uid)
	uid += 1
	_add_node(
		"LevelRow", "Label", left,
		_anchor_within("LevelRow", L) + "horizontal_alignment = 1\n", uid)
	uid += 1
	for rule in [["Rule1", "Rule1"], ["Rule2", "Rule2"]]:
		_add_node(
			rule[0], "TextureRect", left,
			_anchor_within(rule[1], L) + "texture = " + _kit("rule_brass")
			+ "\nstretch_mode = 1\nmouse_filter = 2\n", uid)
		uid += 1

	# Характеристики: 2 столбца × 2 строки (макет A6–D7). Имена узлов
	# StatIcon_/StatName_/StatValue_ сохранены — их читают скрипт и тесты.
	var cell := Vector2(stats.size.x / 2.0, stats.size.y / 2.0)
	for i in 4:
		var col: int = i % 2
		var row: int = i / 2
		var base := Rect2(
			stats.position + Vector2(col * cell.x, row * cell.y), cell)
		_add_node(
			"StatIcon_" + str(i), "TextureRect", left,
			_anchor_rect(Rect2(base.position + Vector2(4, 6), Vector2(30, 30)), L), uid)
		uid += 1
		_add_node(
			"StatName_" + str(i), "Label", left,
			_anchor_rect(Rect2(base.position + Vector2(42, 4), Vector2(cell.x - 100, 20)), L), uid)
		uid += 1
		_add_node(
			"StatValue_" + str(i), "Label", left,
			_anchor_rect(Rect2(base.position + Vector2(44, 24), Vector2(cell.x - 52, 24)), L)
			+ "theme_type_variation = &\"LabelNumber\"\n", uid)
		uid += 1

	# Список надетого: 7 строк по frame_row (макет A7–D10).
	for i in 7:
		var y0: float = list.position.y + i * (list.size.y / 7.0)
		var row_r := Rect2(list.position.x, y0, list.size.x, list.size.y / 7.0)
		_add_node(
			"EquipRow_" + str(i), "TextureRect", left,
			_anchor_rect(row_r, L) + "texture = " + _kit("frame_row")
			+ "\nstretch_mode = 1\nmouse_filter = 2\nvisible = false\n", uid)
		uid += 1
		_add_node(
			"EquipIcon_" + str(i), "TextureRect", left + "/EquipRow_" + str(i),
			"anchor_left = 0.02\nanchor_top = 0.08\nanchor_right = 0.09\nanchor_bottom = 0.9\n"
			+ "stretch_mode = 5\nmouse_filter = 2\n", uid)
		uid += 1
		_add_node(
			"EquipName_" + str(i), "Label", left + "/EquipRow_" + str(i),
			"anchor_left = 0.1\nanchor_right = 0.98\nanchor_bottom = 1.0\n"
			+ "vertical_alignment = 1\n", uid)
		uid += 1

	# — каменная плита центра ----------------------------------------------
	_block("Stone", "Sheet", uid, "panel_stone")
	uid += 1
	var S: Rect2 = _L.BLOCKS["Stone"]
	var stone := "Sheet/Stone"
	_add_node(
		"Figure", "TextureRect", stone,
		_anchor_within("Figure", S) + "texture = " + _kit("figure")
		+ "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
	uid += 1

	# Кукла: 16 рамок по анатомии макета; слот (`Artifact.Slot`) у первых 12,
	# остальные — пустой декор (T-242).
	_add_node("Doll", "Control", stone,
		"anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n", uid)
	uid += 1
	for i in _L.DOLL_SLOTS_N:
		# DOLL задан долями кадра (как в карте элементов), Doll живёт в Stone —
		# перевод в локальные пиксели плиты.
		var c: Vector2 = _L.DOLL[i] * _L.CANVAS - S.position
		var r := Rect2(
			c - _L.DOLL_SIZE / 2.0, _L.DOLL_SIZE)
		_add_node(
			"DollSlot_" + str(i), "TextureRect", stone + "/Doll",
			_anchor_rect(r, S) + "texture = " + _kit("slot_doll")
			+ "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
		uid += 1
		_add_node(
			"DollIcon_" + str(i), "TextureRect", stone + "/Doll",
			_anchor_rect(r.grow(-6.0), S)
			+ "mouse_filter = 2\nvisible = false\n", uid)
		uid += 1

	# Сумка 10×5 = 50 ячеек (носитель — GameNumbers.INVENTORY_GRID, D-280).
	_add_node(
		"Bag", "Control", stone, _anch(_L.BLOCKS["Bag"], "Stone") + "mouse_filter = 2\n", uid)
	uid += 1
	var bag: Rect2 = _L.BLOCKS["Bag"]
	var pitch := Vector2(bag.size.x / _L.GRID_COLS, bag.size.y / _L.GRID_ROWS)
	for row in _L.GRID_ROWS:
		for col in _L.GRID_COLS:
			# Доли той же решётки, что у предметов (`origin * шаг`): пиксельные
			# офсеты от размера макета перестают совпадать с полем в любом другом
			# окне, и подсветка врёт о том, какие клетки заняты (T-255).
			# Желоба между клетками — дело рисунка плитки, а не разметки:
			# долевой желоб растёт вместе с окном, а отступ предмета (`ITEM_GAP`)
			# постоянен в px, и на любом размере, кроме макетного, они расходятся.
			_add_node(
				"GridCell_%d_%d" % [col, row], "TextureRect", stone + "/Bag",
				"anchor_left = %s\nanchor_top = %s\nanchor_right = %s\nanchor_bottom = %s\n" % [
					_f(float(col) / _L.GRID_COLS), _f(float(row) / _L.GRID_ROWS),
					_f(float(col + 1) / _L.GRID_COLS),
					_f(float(row + 1) / _L.GRID_ROWS)]
				+ "texture = " + _kit("cell_grid") + "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
			uid += 1
	_add_node(
		"Items", "Control", stone + "/Bag",
		"anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n", uid)
	uid += 1

	# Перевес — вне макета: полоса над сумкой (макет перевеса не рисует).
	for nm in ["Overflow_lbl", "Overflow"]:
		_add_node(
			nm, "Label" if nm.ends_with("_lbl") else "Control", stone,
			_anchor_within("Overflow", S)
			+ ("horizontal_alignment = 0\n" if nm.ends_with("_lbl") else "mouse_filter = 2\n"), uid)
		uid += 1

	# — зона переноса A: мана и школа (камня макета не касаются) -------------
	_block("BandMana", "Sheet", uid, "", 14)
	uid += 1
	var band := "Sheet/BandMana"
	_add_node("Mana_lbl", "Label", band,
		"anchor_left = 0.0\nanchor_top = 0.0\nanchor_right = 1.0\nanchor_bottom = 0.05\n", uid)
	uid += 1
	_add_node("Mana_val", "Label", band,
		"anchor_left = 0.0\nanchor_top = 0.05\nanchor_right = 1.0\nanchor_bottom = 0.11\n"
		+ "theme_type_variation = &\"LabelNumber\"\n", uid)
	uid += 1
	_add_node("ManaTrack", "TextureRect", band,
		"anchor_left = 0.0\nanchor_top = 0.11\nanchor_right = 1.0\nanchor_bottom = 0.145\n"
		+ "texture = " + _kit("bar_track") + "\nstretch_mode = 1\nmouse_filter = 2\n", uid)
	uid += 1
	_add_node("ManaBar", "TextureRect", band,
		"anchor_left = 0.0\nanchor_top = 0.11\nanchor_right = 1.0\nanchor_bottom = 0.145\n"
		+ "texture = " + _kit("bar_mana") + "\nstretch_mode = 0\nmouse_filter = 2\n", uid)
	uid += 1
	_add_node("School_lbl", "Label", band,
		"anchor_left = 0.0\nanchor_top = 0.155\nanchor_right = 1.0\nanchor_bottom = 0.205\n", uid)
	uid += 1
	_add_node("School_val", "Label", band,
		"anchor_left = 0.0\nanchor_top = 0.205\nanchor_right = 1.0\nanchor_bottom = 0.26\n", uid)
	uid += 1

	# — зона переноса C: навыки и построения --------------------------------
	_block("BandSkills", "Sheet", uid, "", 14)
	uid += 1
	var bs := "Sheet/BandSkills"
	_add_node("Skills_lbl", "Label", bs,
		"anchor_left = 0.0\nanchor_top = 0.0\nanchor_right = 1.0\nanchor_bottom = 0.055\n", uid)
	uid += 1
	for i in 6:
		var t0 := 0.06 + i * 0.055
		_add_node("Skill_" + str(i), "Button", bs,
			"anchor_left = 0.0\nanchor_top = %s\nanchor_right = 1.0\nanchor_bottom = %s\n"
			% [_f(t0), _f(t0 + 0.05)] + "text = \"\"\n", uid)
		uid += 1
		# Строка навыка = иконка + уровень: скрипт экрана пишет SkillIcon/SkillLevel,
		# без этих детей перенесённый блок остался бы без значения (AC2).
		_add_node("SkillIcon", "TextureRect", bs + "/Skill_" + str(i),
			"anchor_left = 0.02\nanchor_top = 0.15\nanchor_right = 0.2\nanchor_bottom = 0.85\n"
			+ "stretch_mode = 6\nmouse_filter = 2\n", uid)
		uid += 1
		_add_node("SkillLevel", "Label", bs + "/Skill_" + str(i),
			"anchor_left = 0.7\nanchor_top = 0.15\nanchor_right = 0.98\nanchor_bottom = 0.85\n"
			+ "theme_type_variation = &\"LabelNumber\"\n", uid)
		uid += 1
	_add_node("Formations_lbl", "Label", bs,
		"anchor_left = 0.0\nanchor_top = 0.42\nanchor_right = 1.0\nanchor_bottom = 0.475\n", uid)
	uid += 1
	_add_node("Formations", "Control", bs,
		"anchor_left = 0.0\nanchor_top = 0.48\nanchor_right = 1.0\nanchor_bottom = 0.72\n"
		+ "mouse_filter = 2\n", uid)
	uid += 1
	for i in 4:
		_add_node("Form_" + str(i), "Button", bs + "/Formations",
			"anchor_left = %s\nanchor_top = %s\nanchor_right = %s\nanchor_bottom = %s\n" % [
				_f((i % 2) * 0.5), _f((i / 2) * 0.5),
				_f((i % 2) * 0.5 + 0.5), _f((i / 2) * 0.5 + 0.5)] + "text = \"\"\n", uid)
		uid += 1

	# — колонка армии: карточки, «×», «?» ----------------------------------
	_block("Units", "Sheet", uid)
	uid += 1
	var units := "Sheet/Units"
	# Узел `Bottom` сохранён: на него повязаны тема ArtifactBottom и тесты носителя
	# темы (T-147). PanelContainer не раскидывает карточки — у него один ребёнок
	# `Cards`, а карточки живут внутри него своими долями.
	_add_node("Bottom", "PanelContainer", units,
		_anchor_within("CardScroll", _L.BLOCKS["Units"])
		+ "theme_type_variation = &\"ArtifactBottom\"\nmouse_filter = 2\n", uid)
	uid += 1
	_add_node("Cards", "Control", units + "/Bottom",
		"anchor_right = 1.0\nanchor_bottom = 1.0\nmouse_filter = 2\n", uid)
	uid += 1
	var card_h: float = _L.CARD["h"]
	for i in 4:
		var n := str(i)
		var card_parent := units + "/Bottom/Cards/Card_" + n
		_add_node("Card_" + n, "Control", units + "/Bottom/Cards",
			"anchor_left = 0.0\nanchor_top = %s\nanchor_right = 1.0\nanchor_bottom = %s\n" % [
				_f(i * _L.CARD["pitch"] / _L.BLOCKS["CardScroll"].size.y),
				_f((i * _L.CARD["pitch"] + card_h) / _L.BLOCKS["CardScroll"].size.y)]
			+ "mouse_filter = 2\n", uid)
		uid += 1
		# Дочерние узлы карточки anch'ируются локально карточке: её ширина —
		# ширина колонки, высота — CARD["h"].
		var card_size := Vector2(_L.BLOCKS["Units"].size.x, card_h)
		_add_node("ArmySlot_" + n, "TextureRect", card_parent,
			_anchor_rect(_L.CARD["portrait"], Rect2(Vector2.ZERO, card_size))
			+ "texture = " + _kit("frame_card") + "\nstretch_mode = 5\nmouse_filter = 2\n", uid)
		uid += 1
		_add_node("ArmyIcon_" + n, "TextureRect", card_parent,
			_anchor_rect(_L.CARD["portrait"].grow(-14.0), Rect2(Vector2.ZERO, card_size))
			+ "stretch_mode = 5\nmouse_filter = 2\nvisible = false\n", uid)
		uid += 1
		_add_node("CardName_" + n, "Label", card_parent,
			_anchor_rect(_L.CARD["name"], Rect2(Vector2.ZERO, card_size))
			+ "clip_text = true\nvertical_alignment = 1\n", uid)
		uid += 1
		_add_node("ArmyCount_" + n, "Label", card_parent,
			_anchor_rect(_L.CARD["lv_label"], Rect2(Vector2.ZERO, card_size))
			# Число прижато к правому краю поля и растёт влево: четырёхзначное
			# в кегле роли шире макетного бокса, а левый край — граница слота.
			+ "theme_type_variation = &\"LabelNumber\"\n"
			+ "horizontal_alignment = 2\nsize_flags_horizontal = 4\n", uid)
		uid += 1
		for pair2 in [["CardLv_", "lv_label", ""], ["CardHp_", "hp_bar", "bar_track"],
				["CardMp_", "mp_bar", "bar_track"]]:
			var key: String = pair2[1]
			_add_node(
				pair2[0] + n,
				"Label" if pair2[2] == "" else "TextureRect",
				card_parent,
				_anchor_rect(_L.CARD[key], Rect2(Vector2.ZERO, card_size))
				+ ("horizontal_alignment = 1\n" if pair2[2] == ""
					else "texture = " + _kit(pair2[2]) + "\nstretch_mode = 1\nmouse_filter = 2\n"), uid)
			uid += 1
	_add_node("Close", "Button", units,
		_anchor_within("Close", _L.BLOCKS["Units"])
		+ "text = \"×\"\ntheme_type_variation = &\"Button\"\n", uid)
	uid += 1
	_add_node("Quests", "Button", units,
		_anchor_within("Quests", _L.BLOCKS["Units"]) + "text = \"?\"\n", uid)
	uid += 1

	# — панель предмета (макет: всплывающая подсказка поверх сумки) ---------
	_add_node("ItemTip", "PanelContainer", "Sheet",
		_anch(_L.BLOCKS["ItemTip"], "Sheet")
		+ "theme_type_variation = &\"ArtifactOutline\"\nvisible = false\n", uid)
	uid += 1
	var tip := "Sheet/ItemTip"
	_add_node("TipBox", "VBoxContainer", tip, "mouse_filter = 2\n", uid)
	uid += 1
	_add_node("TipName", "Label", tip + "/TipBox", "autowrap_mode = 3\n", uid)
	uid += 1
	_add_node("TipDesc", "Label", tip + "/TipBox",
		"autowrap_mode = 3\n", uid)
	uid += 1
	# Desc_lbl/Desc — перенесённые узлы старой подписи (макет их не рисует):
	# остаются под подсказкой, чтобы тесты действий предмета читали то же место.
	_add_node("Desc_lbl", "Label", tip + "/TipBox", "visible = false\n", uid)
	uid += 1
	_add_node("Desc", "Label", tip + "/TipBox", "visible = false\n", uid)
	uid += 1
	_add_node("TipButtons", "HBoxContainer", tip + "/TipBox", "", uid)
	uid += 1
	for nm in ["Equip", "Remove", "Dispose"]:
		_add_node(nm, "Button", tip + "/TipBox/TipButtons", "text = \"\"\n", uid)
		uid += 1
	_add_node("TipIcon", "TextureRect", tip,
		"anchor_left = 0.82\nanchor_top = 0.04\nanchor_right = 0.98\nanchor_bottom = 0.34\n"
		+ "stretch_mode = 5\nmouse_filter = 2\n", uid)

## Якорные доли блока из таблицы внутри блока-родителя `parent`.
func _anchor_within(block: String, parent: Rect2) -> String:
	return _anchor_rect(_L.BLOCKS[block], parent)

func _anchor_rect(r: Rect2, parent: Rect2) -> String:
	return "anchor_left = %s\nanchor_top = %s\nanchor_right = %s\nanchor_bottom = %s\n" % [
		_f(r.position.x / parent.size.x), _f(r.position.y / parent.size.y),
		_f((r.position.x + r.size.x) / parent.size.x),
		_f((r.position.y + r.size.y) / parent.size.y)]

func _emit() -> void:
	var out := "[gd_scene load_steps=" + str(_ext.size() + 1) + " format=3]\n"
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
