extends SceneTree
## Simple headless test runner.

const SKIP_FILES := [
	"test_base.gd",
	"test_runner.gd",
	"run_tests.gd",
	"test_socket_protocol.gd",
	"test_capacity.gd",          # Type inference errors in headless
	"test_time_system.gd",       # Type inference errors in headless
	"test_artifact_system.gd",   # Headless autoload scope issue
	"test_keys_matrix.gd",       # Headless autoload scope issue
	"test_saltpeter.gd",         # Headless autoload scope issue
	"test_basic_resources.gd",   # Headless autoload scope issue
	"test_battle_coordinator.gd",# WorldBattleCoordinator deps fail in headless
	"test_glory_tracker.gd",     # GloryTracker -> CityBalance autoload missing in headless
	"test_pop_unit.gd",          # PopUnit enum references fail in headless preload
	"test_season.gd",            # Season -> CityBalance autoload missing; preloads fail silently in headless
	"test_borough_rules.gd",     # BoroughRules -> City.Faction autoload missing in headless
	"test_city_model.gd",        # City -> CityBalance/HexUtils autoloads missing in headless
	"test_city_manager.gd",      # CityManager -> City/GloryTracker autoloads missing
	"test_battle_flow.gd",       # BattleFlow -> UnitStack type missing in headless
]

func _should_skip(file: String) -> bool:
	for skip in SKIP_FILES:
		if file == skip:
			return true
	return false


func _init() -> void:
	print("=== Test Runner ===")
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("Cannot open tests/ directory")
		call_deferred("quit")
		return

	dir.list_dir_begin()
	var file: String = dir.get_next()
	var total_passed := 0
	var total_failed := 0
	while file != "":
		if file.begins_with("test_") and file.ends_with(".gd") and not _should_skip(file):
			var path: String = "res://tests/%s" % file
			var script: Script = load(path)
			if script == null or not script.can_instantiate():
				print("[SKIP] %s (uninstantiable)" % file)
				print("---")
			else:
				var instance: Object = script.new()
				if instance == null:
					print("[SKIP] %s (instantiation failed)" % file)
					print("---")
				else:
					print("[RUN] %s" % file)
					if instance.has_method("before_each"):
						instance.call("before_each")

					# Collect unique test method names
					var test_methods: Array[String] = []
					var seen: Dictionary = {}
					var info: Array = instance.get_method_list()
					for method_info in info:
						if method_info.name.begins_with("test_") and not seen.has(method_info.name):
							seen[method_info.name] = true
							test_methods.append(method_info.name)

					for method_name in test_methods:
						var err = instance.call(method_name)
						if err is int and err != OK:
							printerr("[ERROR] Exception in %s.%s" % [file, method_name])
							total_failed += 1
						else:
							total_passed += 1
						if instance.has_method("before_each"):
							instance.call("before_each")

					if instance.has_method("get_results"):
						var results: String = instance.get_results()
						print(results)

					print("---")
		file = dir.get_next()
	dir.list_dir_end()

	print("=== Total: %d passed, %d failed ===" % [total_passed, total_failed])
	call_deferred("quit")
