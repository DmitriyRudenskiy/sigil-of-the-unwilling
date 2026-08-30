extends SceneTree
## Simple headless test runner.

const ServiceContainer = preload("res://core/ServiceContainer.gd")

## Параметры из командной строки (заполняются в _run_tests).
var FILTER := ""          # подстрока по имени файла и/или метода
var TAGS: Array[String] = []  # теги для отбора (--tag, может быть несколько)
var LIST_ONLY := false

const SKIP_FILES := [
	"test_base.gd",
	"run_tests.gd",
	# Автономные SceneTree-раннеры: запускаются сами через `godot -s`,
	# а не как тестовые файлы в главном раннере.
	# (test_runtime_integration асинхронен: ждёт 4с инициализации мира —
	#  главный раннер не умеет await-ить тесты, а Timer в его контексте не стартует)
	"test_runtime_integration.gd",
	# Корутинный smoke-тест UI арены (ждёт кадры/таймеры) — только через `godot -s`.
	"test_city_arena_view.gd",
	"test_validation_runner.gd",
	"debug_load.gd",
]

func _should_skip(file: String) -> bool:
	for skip in SKIP_FILES:
		if file == skip:
			return true
	return false


## Разбор флагов: --filter <substring>, --tag <name> (многократно), --list.
func _parse_args() -> void:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--filter" and i + 1 < args.size():
			FILTER = args[i + 1]
		elif args[i] == "--tag" and i + 1 < args.size():
			if not TAGS.has(args[i + 1]):
				TAGS.append(args[i + 1])
		elif args[i] == "--list":
			LIST_ONLY = true


## Совпадает ли имя/путь файла с подстрокой фильтра (уровень файла).
func _filter_matches(file_name: String, file_path: String) -> bool:
	if FILTER.is_empty():
		return true
	return file_name.find(FILTER) >= 0 or file_path.find(FILTER) >= 0


## Теги: если --tag задан, у экземпляра должен быть хотя бы один из нужных тегов
## (теги ставятся через tag(...) в test_base.gd). Файлы без _tags не отбираются.
func _instance_matches_tags(instance: Object) -> bool:
	if TAGS.is_empty():
		return true
	var tags: Variant = instance.get("_tags")
	if not (tags is Array):
		return false
	for t in TAGS:
		for tg in tags:
			if tg == t:
				return true
	return false


## True, если тест preload'ит dev-тулзы (res://tools/...), а tools/ в проекте нет
## (portable-проект game/ их не включает). Проверяем по тексту файла до load().
func _skips_for_missing_dev_tools(full_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://tools")):
		var source := FileAccess.get_file_as_string(full_path)
		return source.contains("res://tools/")
	return false


func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== Test Runner ===")

	_parse_args()

	# Режим перечисления: без запуска, просто показываем, что было бы проверено.
	if LIST_ONLY:
		_list_dir("res://tests")
		call_deferred("quit", 0)
		return

	# Инициализация ServiceContainer для headless-тестов
	var services := ServiceContainer.new()
	var root := get_root()
	services.units = root.get_node_or_null("Units")
	services.resources = root.get_node_or_null("Resources")
	services.spells = root.get_node_or_null("Spells")
	services.artifacts = root.get_node_or_null("Artifacts")
	services.spellbook = root.get_node_or_null("Spellbook")
	ServiceContainer.setup_global(services)

	var dir := DirAccess.open("res://tests")
	# Рекурсивный скан: tests/ + подпапки (tests/unit/ и т.д.)
	var total: Array[int] = [0, 0]
	var files_run: Array[int] = []
	_run_dir("res://tests", total, files_run)

	# Финальная очистка: 2 кадра для завершения всех queue_free()
	await process_frame
	await process_frame

	print("=== Total: %d passed, %d failed (of %d files) ===" % [total[0], total[1], files_run.size()])
	if total[1] > 0:
		printerr("SOME TESTS FAILED")
		call_deferred("quit", 1)
	else:
		print("ALL TESTS PASSED")
		call_deferred("quit", 0)

## Режим --list: рекурсивно показываем файлы, их test_*-методы и теги.
func _list_dir(dir_path: String) -> void:
	# Режим перечисления без инстанцирования: парсим исходник regexp-ом,
	# чтобы не гонить _init() само跑-файлов (SceneTree.quit) и не тормозить.
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != ".git" and entry != ".godot":
				_list_dir(full_path)
		elif entry.begins_with("test_") and entry.ends_with(".gd") and not _should_skip(entry):
			if _skips_for_missing_dev_tools(full_path):
				entry = dir.get_next()
				continue
			if not _filter_matches(entry, full_path):
				entry = dir.get_next()
				continue
			print(full_path)
			var source := FileAccess.get_file_as_string(full_path)
			var tags_str := _extract_tags(source)
			for line in source.split("\n"):
				var t := line.strip_edges()
				var prefix := "func " if t.begins_with("func ") else ("func\t" if t.begins_with("func\t") else "")
				if prefix != "" and t.substr(prefix.length()).begins_with("test_"):
					var name: String = t.substr(prefix.length()).split("(")[0].strip_edges()
					print("  - " + name + tags_str)
		entry = dir.get_next()
	dir.list_dir_end()


## Извлекает теги из вызовов tag("a") / tag(['a', 'b']) в исходнике.
func _extract_tags(source: String) -> String:
	var parts: Array[String] = []
	for line in source.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("tag(") or t.begins_with("tag\t(") or t.contains("tag("):
			var idx := t.find("tag(")
			if idx >= 0:
				# берём текст до первой закрывающей скобки этого вызова
				var rest := t.substr(idx + 4)
				var depth := 1
				var end := -1
				for c in range(0, rest.length()):
					if rest[c] == "(":
						depth += 1
					elif rest[c] == ")":
						depth -= 1
						if depth == 0:
							end = c
							break
				var call := rest if end < 0 else rest.substr(0, end)
				if not parts.has(call):
					parts.append(call)
		if parts.is_empty():
			return ""
	return "  tags: " + ", ".join(parts)


func _run_dir(dir_path: String, total: Array[int], files_run: Array[int]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != ".git" and entry != ".godot":
				_run_dir(full_path, total, files_run)
		elif entry.begins_with("test_") and entry.ends_with(".gd") and not _should_skip(entry):
			# Тесты dev-тулзов: tools/ не входит в portable-проект game/ —
			# пропускаем до load(), чтобы не ловить Parse Error на preload'ах.
			if _skips_for_missing_dev_tools(full_path):
				print("[SKIP] %s (dev-tools недоступны в проекте)" % full_path)
				print("---")
				entry = dir.get_next()
				continue
			# Уровень файла: если --filter задан, имя/путь должны совпадать.
			if not _filter_matches(entry, full_path):
				entry = dir.get_next()
				continue
			var script: Script = load(full_path)
			if script == null or not script.can_instantiate():
				print("[SKIP] %s (uninstantiable)" % full_path)
				print("---")
			else:
				var instance: Object = script.new()
				if instance == null:
					print("[SKIP] %s (instantiation failed)" % full_path)
					print("---")
				elif not _instance_matches_tags(instance):
					print("[SKIP] %s (no matching tag)" % full_path)
					print("---")
				else:
					print("[RUN] %s" % full_path)
					var had_internal_counters: bool = instance.get("_failed") != null

					# Collect unique test method names. При --filter отбираем только
					# методы, имя которых совпало с подстрокой (внутри подходящих файлов).
					var test_methods: Array[String] = []
					var seen: Dictionary = {}
					var info: Array = instance.get_method_list()
					for method_info in info:
						if method_info.name.begins_with("test_") and not seen.has(method_info.name):
							seen[method_info.name] = true
							if FILTER.is_empty() or _filter_matches(method_info.name, full_path):
								test_methods.append(method_info.name)

					var method_exceptions: int = 0
					for method_name in test_methods:
						if instance.has_method("before_each"):
							instance.call("before_each")
						var err = instance.call(method_name)
						if err is int and err != OK:
							printerr("[ERROR] Exception in %s.%s" % [full_path, method_name])
							method_exceptions += 1
						if instance.has_method("after_each"):
							instance.call("after_each")

					if instance.has_method("get_results"):
						var results: String = instance.get_results()
						print(results)

					# Источники истины: внутренние счётчики test_base (_passed/_failed);
					# fallback — количество исключений методов (для файлов без test_base).
					if had_internal_counters:
						total[0] += int(instance.get("_passed"))
						total[1] += int(instance.get("_failed")) + method_exceptions
					else:
						total[0] += test_methods.size() - method_exceptions
						total[1] += method_exceptions

					files_run.append(1)

					# Очистка после теста
					_cleanup_instance(instance)
					print("---")
		entry = dir.get_next()
	dir.list_dir_end()

func _cleanup_instance(instance: Object) -> void:
	if instance == null:
		return
	# Каждый тестовый файл — detached SceneTree (test_base extends SceneTree,
	# инстанс никогда не добавляется в дерево). free() на самом SceneTree
	# освобождает всё: root Window, RID Viewport/Scenario/Canvas и сам
	# объект дерева. Без этого каждый файл утаскивал ~400 объектов в ObjectDB
	# и по одному Viewport/Scenario/Canvas RID (проверено экспериментально).
	if instance is SceneTree:
		instance.free()
		return
	if instance is Node:
		if instance.is_inside_tree():
			instance.queue_free()
		else:
			instance.free()
