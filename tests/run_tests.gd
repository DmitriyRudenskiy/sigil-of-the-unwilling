extends SceneTree
## Simple headless test runner.

const ServiceContainer = preload("res://core/ServiceContainer.gd")

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


func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=== Test Runner ===")

	# Инициализация ServiceContainer для headless-тестов
	var services := ServiceContainer.new()
	var root := get_root()
	services.units = root.get_node_or_null("Units")
	services.resources = root.get_node_or_null("Resources")
	services.spells = root.get_node_or_null("Spells")
	services.artifacts = root.get_node_or_null("Artifacts")
	services.card_spells = root.get_node_or_null("CardSpells")
	ServiceContainer.setup_global(services)

	var dir := DirAccess.open("res://tests")
	# Рекурсивный скан: tests/ + подпапки (tests/unit/ и т.д.)
	var total: Array[int] = [0, 0]
	_run_dir("res://tests", total)

	# Финальная очистка: 2 кадра для завершения всех queue_free()
	await process_frame
	await process_frame

	print("=== Total: %d passed, %d failed ===" % [total[0], total[1]])
	if total[1] > 0:
		printerr("SOME TESTS FAILED")
		call_deferred("quit", 1)
	else:
		print("ALL TESTS PASSED")
		call_deferred("quit", 0)

func _run_dir(dir_path: String, total: Array[int]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != ".git" and entry != ".godot":
				_run_dir(full_path, total)
		elif entry.begins_with("test_") and entry.ends_with(".gd") and not _should_skip(entry):
			var script: Script = load(full_path)
			if script == null or not script.can_instantiate():
				print("[SKIP] %s (uninstantiable)" % full_path)
				print("---")
			else:
				var instance: Object = script.new()
				if instance == null:
					print("[SKIP] %s (instantiation failed)" % full_path)
					print("---")
				else:
					print("[RUN] %s" % full_path)
					if instance.has_method("before_each"):
						instance.call("before_each")
					var had_internal_counters: bool = instance.get("_failed") != null

					# Collect unique test method names
					var test_methods: Array[String] = []
					var seen: Dictionary = {}
					var info: Array = instance.get_method_list()
					for method_info in info:
						if method_info.name.begins_with("test_") and not seen.has(method_info.name):
							seen[method_info.name] = true
							test_methods.append(method_info.name)

					var method_exceptions: int = 0
					for method_name in test_methods:
						var err = instance.call(method_name)
						if err is int and err != OK:
							printerr("[ERROR] Exception in %s.%s" % [full_path, method_name])
							method_exceptions += 1
						if instance.has_method("before_each"):
							instance.call("before_each")

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

					# Очистка после теста
					_cleanup_instance(instance)
					print("---")
		entry = dir.get_next()
	dir.list_dir_end()

func _cleanup_instance(instance: Object) -> void:
	if instance == null:
		return
	if instance is Node:
		if instance.is_inside_tree():
			instance.queue_free()
		else:
			instance.free()
