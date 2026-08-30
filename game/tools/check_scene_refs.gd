extends SceneTree
## Headless-проверка ссылок в сценах: ловит битые preload/ext_resource.
## Запуск: godot --headless -s tools/check_scene_refs.gd
var _bad: int = 0
var _ok: int = 0
var _started: bool = false
var _ext_path_regexp: RegEx = RegEx.new()

func _init() -> void:
    _ext_path_regexp.compile('path="(res://[^"]+)"')

# ВАЖНО: сканируем в _process, а не в _init — в режиме -s главный скрипт
# компилируется до инициализации autoload'ов, и ссылки на autoload-идентификаторы
# в сценариях сцен дают ложные ошибки компиляции.
func _process(_delta: float) -> bool:
    if _started:
        return false
    _started = true
    _scan("res://scenes")
    _scan("res://tools")
    # Добавьте другие папки с ресурсами при необходимости
    print("=== scene refs check: %d ok, %d errors ===" % [_ok, _bad])
    quit(1 if _bad > 0 else 0)
    return false

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
            # 1) Текстовая проверка ext_resource-путей (битые ссылки могут
            #    не мешать загрузке PackedScene, но ломают сцену при открытии).
            var missing: Array[String] = []
            var file := FileAccess.open(full, FileAccess.READ)
            if file != null:
                for line in file.get_as_text().split("\n"):
                    var m := _ext_path_regexp.search(line)
                    if m != null:
                        var p: String = m.get_string(1)
                        if p.begins_with("res://") and not FileAccess.file_exists(p):
                            missing.append(p)
            # 2) Полная загрузка сцены (ловит битые preload'ы в скриптах).
            var scene = ResourceLoader.load(full, "PackedScene")
            if scene == null or missing.size() > 0:
                print("❌ %s%s" % [full, ": missing " + ", ".join(missing) if missing.size() > 0 else ""])
                _bad += 1
            else:
                _ok += 1
        f = dir.get_next()
    dir.list_dir_end()
