extends SceneTree

# Дамп прямоугольников Control для ux-review: какой узел владеет ячейкой кадра.
#
# Кадр говорит «иконка в D5», а править надо коробку в сцене. Между этими двумя
# утверждениями — генератор раскладки (`scripts/build/gen_*.gd`), и угадать в нём
# владельца прямоугольника по описанию нельзя. Инструмент отвечает TSV-строкой на
# узел: путь, тип, глобальный прямоугольник, якоря, текст, трогал ли его theme.
#
# Запуск (НЕ headless — нужен живой рендер, см. AGENTS.md «UX-review машинным
# зрением»; дисплей — тот же X-дисплей, что поднимает run_tests.sh):
#   Godot --path game --script tools/ui_dump.gd -- \
#       --scene=res://scenes/ui/artifact_inventory_screen.tscn --width=1920 --height=1080
#   ... --cell=D5 --cols=10 --rows=10      # только узлы, чей прямоугольник пересекает D5
#
# Колонки (таб): path type x y w h anchors(L,T,R,B)×100 visible extras
#   path — путь от окна (рядом с экраном на кадре лежат autoload-слои);
#   `--all` — печатать и невидимые/нулевые узлы (и вне запрошенной ячейки):
#   «пустой дамп» и «узел есть в дереве, но его не видно» — тот класс молчаливых
#   поломок, который иначе ищут вслепую (D-228 п.7: текст в модели есть, на экране нет);
#   extras — `;`-список: text=…, font=…, sep=…, columns=…, margin_l/t/r/b=…,
#            hflags=…, vflags=…, theme=…, scroll=…
#
# Размер окна пинится рамкой без полей: у обычного окна высоту зажимает менюбар
# (1920×1080 превращается в 1920×1027 — замер на macOS), и прямоугольники перестают
# соответствовать кадру. В MODE_FULLSCREEN не уходим: на macOS такое окно уезжает в
# свой Space, и дерево продолжает жить, а кадр — нет (урок 2026-10-20, capture.py).
#
# Выход: 0 — дамп есть, 1 — аргументы/сцена, 2 — headless (кадр был бы чёрным),
#        3 — дамп пуст (сцену надо поднимать состоянием, не голым --scene).

var _args: Dictionary = {}


func _initialize() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_run()


func _parse_args(uargs: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for u in uargs:
		if u.begins_with("--"):
			var body: String = u.substr(2)
			var eq: int = body.find("=")
			out[body.substr(0, eq) if eq != -1 else body] = "true" if eq == -1 else body.substr(eq + 1)
	return out


func _fail(msg: String) -> void:
	print("[ui_dump] ERROR: ", msg)
	quit(1)


func _pin_window(width: int, height: int) -> void:
	if width <= 0 or height <= 0:
		return
	var target := Vector2i(width, height)
	root.mode = Window.MODE_WINDOWED
	if target == DisplayServer.screen_get_size():
		root.borderless = true
	root.size = target


func _extras(c: Control) -> String:
	var parts := PackedStringArray()
	var text: Variant = c.get("text")
	if text != null and str(text) != "":
		var one_line := String(str(text)).replace("\n", " ⏎ ")
		if one_line.length() > 48:
			one_line = one_line.substr(0, 45) + "…"
		parts.append("text=%s" % one_line)
	var font_size: Variant = c.get("theme_override_font_sizes/font_size")
	if font_size != null:
		parts.append("font=%s" % font_size)
	if c is BoxContainer or c is GridContainer:
		var sep: Variant = c.get("theme_override_constants/separation")
		if sep != null:
			parts.append("sep=%s" % sep)
	if c is GridContainer:
		parts.append("columns=%d" % (c as GridContainer).columns)
	if c is MarginContainer:
		for side in ["left", "top", "right", "bottom"]:
			var m: Variant = c.get("theme_override_constants/margin_%s" % side)
			if m != null:
				parts.append("margin_%s=%s" % [side[0], m])
	if c is ScrollContainer:
		parts.append("scroll=%s" % (c as ScrollContainer).get_v_scroll_bar().value)
	if c.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		parts.append("hflags=%d" % c.size_flags_horizontal)
	if c.size_flags_vertical != Control.SIZE_SHRINK_BEGIN:
		parts.append("vflags=%d" % c.size_flags_vertical)
	if c.theme_type_variation != &"":
		parts.append("theme=%s" % c.theme_type_variation)
	return ";".join(parts)


func _anchors(c: Control) -> String:
	# Доли родителя ×100: GDScript не знает %g, а якоря — числа 0..1.
	return "%d,%d,%d,%d" % [
		round(c.anchor_left * 100), round(c.anchor_top * 100),
		round(c.anchor_right * 100), round(c.anchor_bottom * 100)]


func _emit(c: Control, path: String, rows: Array, cell: Dictionary) -> void:
	var r := c.get_global_rect()
	var keep := bool(_args.get("all", false))
	if not keep and (not c.visible or r.size.x <= 0.0 or r.size.y <= 0.0):
		return
	# Пересечение, а не «центр внутри»: вопрос «кто нарисован в D5» обязан находить
	# и те узлы, у которых в ячейке только край (полоса армии, окно целиком).
	if not keep and not cell.is_empty() and not r.intersects(
			Rect2(float(cell["x"]), float(cell["y"]), float(cell["w"]), float(cell["h"])), true):
		return
	rows.append({
		"rect": r,
		"line": "%s\t%s\t%d\t%d\t%d\t%d\t%s\t%d\t%s" % [
			path, c.get_class(), round(r.position.x), round(r.position.y),
			round(r.size.x), round(r.size.y), _anchors(c), int(c.visible), _extras(c)],
	})


func _print_tree(node: Node, depth: int, budget: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1
	print("[ui_dump]   %s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1, budget)


func _collect(node: Node, root_path: String, rows: Array, cell: Dictionary) -> void:
	for child in node.get_children():
		var path := root_path + "/" + String(child.name)
		if child is Control:
			_emit(child as Control, path, rows, cell)
		# Рекурсия идёт и сквозь не-Control (CanvasLayer, Node): наши экраны лежат
		# внутри CanvasLayer, и ветвь «только Control» отрезала бы их целиком.
		_collect(child, path, rows, cell)


func _cell_rect(cols: int, rows_count: int, name: String, size: Vector2i) -> Dictionary:
	var body := name.to_upper()
	var i := 0
	while i < body.length() and body[i] >= "A" and body[i] <= "Z":
		i += 1
	if i == 0 or i == body.length():
		return {}
	var col := 0
	for k in range(i):
		col = col * 26 + (body.unicode_at(k) - 64)
	col -= 1
	var row := body.substr(i).to_int() - 1
	if col < 0 or col >= cols or row < 0 or row >= rows_count:
		return {}
	return {
		"x": round(float(col) * size.x / cols), "y": round(float(row) * size.y / rows_count),
		"w": round(float(col + 1) * size.x / cols) - round(float(col) * size.x / cols),
		"h": round(float(row + 1) * size.y / rows_count) - round(float(row) * size.y / rows_count),
	}


func _run() -> void:
	var scene_path: String = str(_args.get("scene", ""))
	if scene_path.is_empty():
		_fail("нужен --scene=res://путь/к/сцене.tscn")
		return
	if DisplayServer.get_name() == "headless":
		print("[ui_dump] ERROR: headless — рендера нет, прямоугольники контейнеров ещё не посчитаны.")
		print("[ui_dump] Запускайте с дисплеем (X-дисплей поднимает run_tests.sh, см. AGENTS.md).")
		quit(2)
		return

	var cols := int(str(_args.get("cols", "10")))
	var rows_count := int(str(_args.get("rows", "10")))
	var cell: Dictionary = {}

	# Пин + смена сцены — только после кадра ожидания: в _initialize root ещё
	# настраивает детей, и add_child/change_scene падают «Parent node is busy
	# setting up children» (вендорский ui_shot.gd так и молча снимал пустое окно).
	var width := int(str(_args.get("width", "0")))
	var height := int(str(_args.get("height", "0")))
	_pin_window(width, height)
	await process_frame
	# Размер окна на macOS между кадрами плавает (менюбар, Retina-масштаб), поэтому
	# он фиксируется один раз и по нему же считаются ячейки и итоговая строка.
	var frame_size := root.size
	if width > 0 and height > 0 and frame_size != Vector2i(width, height):
		print("[ui_dump] ВНИМАНИЕ: окно вышло %d×%d, запрошено %d×%d — канон на этом дисплее "
				% [frame_size.x, frame_size.y, width, height]
				+ "недостижим (обычное окно зажимает менюбар). Прямоугольники не совпадут "
				+ "с кадрами канона 1920×1080; сравнение «до/после» валидно только при равном "
				+ "размере — verify_frame в game/tests/mcp/capture.py.")
	# Ячейка считается ПОСЛЕ пина: это доля фактического размера окна, а не того, с каким
	# окно стартовало (иначе фильтр ячейки молча берёт прямоугольник от другого кадра).
	if _args.has("cell"):
		cell = _cell_rect(cols, rows_count, str(_args["cell"]), frame_size)
		if cell.is_empty():
			_fail("ячейка вне сетки %d×%d: %s" % [cols, rows_count, str(_args["cell"])])
			return
		print("[ui_dump] ячейка %s = %d,%d %d×%d при окне %d×%d" % [
			str(_args["cell"]), int(cell["x"]), int(cell["y"]), int(cell["w"]), int(cell["h"]),
			frame_size.x, frame_size.y])
	if not ResourceLoader.exists(scene_path):
		_fail("сцена не найдена: " + scene_path)
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_fail("сцена не загрузилась: " + scene_path)
		return
	# Смена сцены — методом самой SceneTree (этот скрипт и есть дерево); у Window
	# такого метода нет, `root.change_scene_to_packed` падает runtime-ошибкой.
	#
	# Повтор по кадрам обязателен: в первые кадры root ещё раскладывает autoload'ы,
	# и add_child внутри change_scene падает «Parent node is busy setting up
	# children» — молча, без ненулевого кода возврата. Симптом: пустой дамп и
	# чёрный кадр вместо экрана (на этом вендорский ui_shot снимал пустое окно и
	# рапортовал SAVED). Пока дерево не приняло сцену и не посадило её в себя, — пробуем.
	var loaded := false
	for i in range(30):
		var cur := get_current_scene()
		if cur != null and cur.is_inside_tree():
			loaded = true
			break
		change_scene_to_packed(packed)
		await process_frame
	if not loaded:
		_fail("сцена не встала в дерево за 30 кадров: " + scene_path)
		return
	for i in range(int(str(_args.get("frames", "20")))):
		await process_frame

	var rows: Array = []
	# Обходим всё окно: после смены сцены её корень — один из детей, рядом живут
	# autoload-слои (HUD, панели), и на кадре они тоже рисуются.
	_collect(root, "", rows, cell)
	rows.sort_custom(func(a, b): return a["rect"].get_area() > b["rect"].get_area())
	if rows.is_empty():
		if not cell.is_empty():
			print("[ui_dump] В ЯЧЕЙКЕ " + str(_args.get("cell", "")) + " не пересекается ни один Control "
					+ "— там пусто на кадре. Соседние ячейки и --all (весь список с прямоугольниками) "
					+ "покажут, где граница.")
		else:
			print("[ui_dump] ПУСТО: видимых Control нет — сцена без состояния рисует заглушку "
					+ "(экран снаряжения без героя, каталог без города). Канонический путь — "
					+ "CAPTURE_SETUP поверх живого хоста, docs/mvp/CAPTURE-HELPER.md; "
					+ "для отладки дерева здесь есть --all.")
		print("[ui_dump] дерево окна (классы, чтобы видеть, куда делся экран):")
		_print_tree(root, 0, [60])
		quit(3)
		return
	print("path\ttype\tx\ty\tw\th\tanchors\tvisible\textras")
	for row in rows:
		print(row["line"])
	print("[ui_dump] узлов: %d (сетка %d×%d%s, окно %d×%d)" % [
		rows.size(), cols, rows_count,
		", ячейка " + str(_args.get("cell", "")) if not cell.is_empty() else "",
		frame_size.x, frame_size.y])
	quit(0)
