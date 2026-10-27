extends SceneTree

# Съёмщик ОДНОЙ сцены для шага разработки (scene-first-dev-loop).
#
# Канальный съёмщик (`game/tests/mcp/capture.py`) поднимает кадр через MCP-сервер:
# порт 9090, живой Godot, X-дисплей, обвязка `conftest`. На шарящей машине это спор
# с чужой сессией за порт и дисплей, а шагу правки нужен один кадр одной сцены.
# Этот инструмент снимает напрямую: `Godot --path game -s tools/shot_scene.gd`,
# без сервера и без порта.
#
# Граница ответственности (зафиксирована в docs/mvp/CAPTURE-HELPER.md): кадр отсюда
# — инструмент разработки. Он не входит в манифест съёмки и не доказывает канон
# 1920×1080: на этой машине окно клампится (~1836×1025), и вердикт «кадр канонный»
# здесь не выносится — это делает pytest-путь.
#
# Запуск (НЕ headless — dummy-рендер даёт чёрный кадр, и это отказ, а не результат):
#   Godot --path game -s tools/shot_scene.gd -- \
#       --scene=res://scenes/ui/artifact_inventory_screen.tscn \
#       --state=inventory_grid --out=tmp/shots/inventory.png
#   --state — имя фикстуры из `tools/capture/` или путь к `.gd`; код состояния —
#   тот же, что исполняет `CAPTURE_SETUP` (файлы двусторонние по построению).
#
# Выход: 0 — кадр есть, 1 — аргументы/сцена, 2 — headless, 3 — сцена в дереве не та,
#        4 — кадр пустой (средняя яркость < 3), 5 — код состояния не исполнился.

const CANON := Vector2i(1920, 1080)
const DARK_LIMIT := 3.0

var _args: Dictionary = {}
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_args = _parse_args(OS.get_cmdline_user_args())
	_run()


func _parse_args(uargs: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for u in uargs:
		if u.begins_with("--"):
			var body: String = u.substr(2)
			var eq: int = body.find("=")
			out[body.substr(0, eq) if eq != -1 else body] = (
				"true" if eq == -1 else body.substr(eq + 1)
			)
	return out


func _fail(code: int, msg: String) -> void:
	print("[shot_scene] ERROR: " + msg)
	quit(code)


func _pin_window(width: int, height: int) -> void:
	root.mode = Window.MODE_WINDOWED
	if Vector2i(width, height) == DisplayServer.screen_get_size():
		# Строка меню macOS съедает 53 px высоты; безрамовое окно даёт ровно канон.
		root.borderless = true
	root.size = Vector2i(width, height)


## Кадр по запросу. `Window.get_texture()` живёт только при настоящем рендере.
func _grab(out_path: String) -> Image:
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		_fail(4, "рендер не вернул изображение")
		return null
	var dir := out_path.get_base_dir()
	if not dir.is_empty() and DirAccess.make_dir_recursive_absolute(dir) != OK:
		_fail(1, "каталог кадра не создаётся: " + dir)
		return null
	if img.save_png(out_path) != OK:
		_fail(1, "кадр не записан: " + out_path)
		return null
	print("[shot_scene] CAPTURED %s — %d×%d" % [out_path, img.get_width(), img.get_height()])
	return img


## Средняя яркость кадра: пустой (чёрный) кадр — отказ, а не «снимено успешно».
func _mean_brightness(img: Image) -> float:
	var copy: Image = img.duplicate()
	if copy.get_format() != Image.FORMAT_RGB8 and copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGB8)
	copy.resize(64, 36)
	var total := 0.0
	for y in copy.get_height():
		for x in copy.get_width():
			var c := copy.get_pixel(x, y)
			total += (c.r + c.g + c.b) / 3.0 * 255.0
	return total / float(copy.get_width() * copy.get_height())


## Код состояния (`--state=`) — файл из `tools/capture/`, написанный для
## `CAPTURE_SETUP`: это тело функции, обращающейся к `get_tree()`. Отсюда обёртка,
## которая даёт ему то же окружение, что песочница `execute_code`.
func _apply_state(state: String) -> Variant:
	var path := state
	if not path.ends_with(".gd"):
		path = "res://tools/capture/%s.gd" % state
	if not FileAccess.file_exists(path):
		_fail(
			5,
			(
				"фикстура не найдена: %s (ни путь, ни tools/capture/%s.gd)"
				% [state, state.get_basename()]
			)
		)
		return null
	var fragment := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = (
		"extends RefCounted\n"
		+ "var _tree: SceneTree\n"
		+ "func get_tree() -> SceneTree: return _tree\n"
		+ "func _fragment() -> Variant:\n"
		+ "".join(Array(fragment.split("\n")).map(func(l): return "\t" + l + "\n"))
		+ "func exec(tree: SceneTree) -> Variant:\n\t_tree = tree\n\treturn _fragment()\n"
	)
	var err := script.reload()
	if err != OK:
		_fail(5, "фикстура не компилируется: " + path)
		return null
	var result: Variant = script.new().exec(self)
	print("[shot_scene] фикстура %s вернула: %s" % [state, result])
	if typeof(result) == TYPE_DICTIONARY and not bool(result.get("ok", true)):
		_fail(5, "фикстура отказала: " + str(result))
		return null
	return result


func _run() -> void:
	var scene_path := str(_args.get("scene", ""))
	var out_path := str(_args.get("out", ""))
	if scene_path.is_empty() or out_path.is_empty():
		_fail(1, "нужны --scene=res://путь.tscn и --out=путь.png")
		return
	# Относительный --out Godot понимает от каталога проекта (game/), а не от cwd;
	# молчаливая разница «запустил из корня, кадр лежит в game/tmp» уже стоила времени.
	if not (out_path.is_absolute_path() or out_path.begins_with("res://")):
		out_path = ProjectSettings.globalize_path("res://").path_join(out_path)
	if DisplayServer.get_name() == "headless":
		_fail(
			2,
			(
				"headless — рендера нет, кадр был бы чёрным. Запускай с дисплеем "
				+ "(X-дисплей поднимает run_tests.sh)."
			)
		)
		return
	if not ResourceLoader.exists(scene_path):
		_fail(1, "сцены нет: " + scene_path)
		return
	var width := int(str(_args.get("width", str(CANON.x))))
	var height := int(str(_args.get("height", str(CANON.y))))
	_pin_window(width, height)
	await process_frame
	var frame := root.size
	if frame != Vector2i(width, height):
		print(
			(
				(
					"[shot_scene] ВНИМАНИЕ: окно вышло %d×%d при запрошенном %d×%d — канон на этом "
					% [frame.x, frame.y, width, height]
				)
				+ "дисплее недостижим; кадр пишется, но вердикт о размере здесь не выносится "
				+ "(для канонного кадра — pytest-путь tests/mcp/test_capture.py)."
			)
		)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		_fail(1, "сцена не загрузилась: " + scene_path)
		return
	# Повтор по кадрам: в первые кадры root ещё раскладывает autoload'ы, и
	# change_scene падает «Parent node is busy setting up children» молча
	# (тот же урок, что учтён в tools/ui_dump.gd).
	var loaded := false
	for i in range(30):
		var cur := get_current_scene()
		if cur != null and cur.is_inside_tree():
			loaded = true
			break
		change_scene_to_packed(packed)
		await process_frame
	if not loaded:
		_fail(1, "сцена не встала в дерево за 30 кадров: " + scene_path)
		return
	# Гард от «кадра предыдущей сцены»: байт-в-байт совпадающие снимки меню вместо
	# запрошенного экрана были замером 2026-10-27 в capture.py.
	var mounted := get_current_scene()
	if mounted.scene_file_path != scene_path:
		_fail(3, "в дереве не та сцена: %s вместо %s" % [mounted.scene_file_path, scene_path])
		return

	if _args.has("state"):
		if _apply_state(str(_args["state"])) == null:
			return
	for i in range(int(str(_args.get("frames", "20")))):
		await process_frame

	var img := await _grab(out_path)
	if img == null:
		return
	var brightness := _mean_brightness(img)
	print("[shot_scene] яркость %.1f, цикл %d мс" % [brightness, Time.get_ticks_msec() - _started])
	if brightness < DARK_LIMIT:
		_fail(
			4,
			(
				(
					"кадр пустой (яркость %.1f < %.1f) — сцена без состояния рисует заглушку; "
					% [brightness, DARK_LIMIT]
				)
				+ "подними её через --state="
			)
		)
		return
	quit(0)
