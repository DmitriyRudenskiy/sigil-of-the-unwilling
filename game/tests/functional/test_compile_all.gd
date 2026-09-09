extends GdUnitTestSuite

var _bad: Array[String] = []
var _ok := 0

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null or dir.list_dir_begin() != OK:
		return
	var f: String = dir.get_next()
	while f != "":
		var full: String = path.path_join(f)
		if dir.current_is_dir():
			if f != ".git" and f != ".godot" and f != "addons" and f != "tools" and f != "tests":
				_scan(full)
		elif f.ends_with(".gd"):
			var res = ResourceLoader.load(full, "GDScript")
			if res == null or not (res is GDScript) or not res.can_instantiate():
				_bad.append(full)
			else:
				_ok += 1
		f = dir.get_next()
	dir.list_dir_end()

func test_all_gd_compiles() -> void:
	_bad.clear()
	_ok = 0
	_scan("res://")
	assert_that(_bad.size()).is_equal(0)
