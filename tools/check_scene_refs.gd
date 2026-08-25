extends SceneTree
## Headless-проверка ссылок в сценах: ловит битые preload/ext_resource.
## Запуск: godot --headless -s tools/check_scene_refs.gd
var _bad: int = 0
var _ok: int = 0

func _init() -> void:
    _scan("res://scenes")
    _scan("res://scripts")
    # Добавьте другие папки с ресурсами при необходимости
    print("=== scene refs check: %d ok, %d errors ===" % [_ok, _bad])
    quit(1 if _bad > 0 else 0)

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
            var scene = ResourceLoader.load(full, "PackedScene")
            if scene == null:
                print("❌ %s" % full)
                _bad += 1
            else:
                _ok += 1
        f = dir.get_next()
    dir.list_dir_end()
