extends Node
## Headless test runner: discovers and runs all test_*.gd in tests/.

func _ready() -> void:
	print("=== Test Runner ===")
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("Cannot open tests/ directory")
		get_tree().quit()
		return

	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_base.gd" and file != "test_runner.gd":
			var path: String = "res://tests/%s" % file
			var script: Script = load(path)
			if script != null:
				var instance: Object = script.new()
				if instance is SceneTree and instance.has_method("before_each"):
					# Test-base pattern: SceneTree subclass with test_ methods
					var info: Array = instance.get_method_list()
					for method_info in info:
						if method_info.name.begins_with("test_"):
							if instance.has_method("before_each"):
								instance.call("before_each")
							var err: int = instance.call(method_info.name)
							if err != OK:
								printerr("[ERROR] Exception in %s.%s" % [file, method_info.name])
					if instance.has_method("get_results"):
						var results: String = instance.get_results()
						print(results)
				elif instance.has_method("run_tests"):
					instance.run_tests()
				else:
					var info: Array = instance.get_method_list()
					for method_info in info:
						if method_info.name.begins_with("test_"):
							var err: int = instance.call(method_info.name)
							if err != OK:
								printerr("[ERROR] Exception in %s.%s" % [file, method_info.name])

					if instance.has_method("get_results"):
						var results: String = instance.get_results()
						print(results)

				print("---")
		file = dir.get_next()
	dir.list_dir_end()

	print("=== Done ===")
	get_tree().quit()
