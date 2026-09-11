extends BaseTest

var _ext_path_regexp: RegEx = RegEx.new()
var _bad: Array[String] = []
var _ok := 0

func _init() -> void:
	_ext_path_regexp.compile('path="(res://[^"]+)"')

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null or dir.list_dir_begin() != OK:
		return
	var f: String = dir.get_next()
	while f != "":
		var full: String = path.path_join(f)
		if dir.current_is_dir():
			if f != ".git" and f != ".godot" and f != "addons":
				_scan(full)
		elif f.ends_with(".tscn") or f.ends_with(".scn"):
			var missing: Array[String] = []
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null:
				for line in file.get_as_text().split("\n"):
					var m := _ext_path_regexp.search(line)
					if m != null:
						var p: String = m.get_string(1)
						if p.begins_with("res://") and not FileAccess.file_exists(p):
							missing.append(p)
			var scene = ResourceLoader.load(full, "PackedScene")
			if scene == null or missing.size() > 0:
				_bad.append(full + (": missing " + ", ".join(missing) if missing.size() > 0 else ""))
			else:
				_ok += 1
		f = dir.get_next()
	dir.list_dir_end()

func test_no_broken_scene_refs() -> void:
	_bad.clear()
	_ok = 0
	_scan("res://scenes")
	_scan("res://tools")
	assert_that(_bad.size()).is_equal(0)
