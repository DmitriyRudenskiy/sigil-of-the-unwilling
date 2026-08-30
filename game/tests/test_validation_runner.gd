extends SceneTree
## Standalone runner for validation tests.

const _TestSpellbook = preload("res://tests/test_spells_json.gd")

func _init() -> void:
	print("=== Spellbook Validation Tests ===")
	var test = _TestSpellbook.new()

	var methods = test.get_method_list()
	for info in methods:
		if info.name.begins_with("test_"):
			print("  Running %s..." % info.name)
			var err = test.call(info.name)
			if err != OK:
				printerr("[ERROR] Exception in %s" % info.name)

	var results = test.get_results()
	print(results)
	var passed = test._passed
	var failed = test._failed
	quit(0 if failed == 0 else 1)
