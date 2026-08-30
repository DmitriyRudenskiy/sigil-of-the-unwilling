extends SceneTree
## Headless-компиляция всех .gd: ловит parse-ошибки и битые preload.
## Запуск: godot --headless -s tools/compile_all.gd
## ВАЖНО: скан запускается в _process (после инстанцирования autoloads),
## иначе autoload-идентификаторы (Units, Resources, ...) ещё не
## зарегистрированы в компиляторе и ложно падает ~45 файлов.
var _bad: int = 0
var _ok: int = 0
var _started := false

func _process(_delta: float) -> bool:
    if _started:
        return false
    _started = true
    _scan("res://")
    print("=== compile check: %d ok, %d errors ===" % [_ok, _bad])
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
            # tests/ не компилируем тут: у dev-тулзов нет tools/ в portable-проекте
            # (их parse-валидация — в run_tests.gd с осознанным skip'ом)
            if f != ".git" and f != ".godot" and f != "addons" and f != "tools" and f != "tests":
                _scan(full)
        elif f.ends_with(".gd"):
            var res = ResourceLoader.load(full, "GDScript")
            # Godot 4.7: load() возвращает GDScript даже при parse-ошибке;
            # can_instantiate() == false — надёжный маркер битой компиляции.
            if res == null or not (res is GDScript) or not res.can_instantiate():
                print("❌ %s" % full)
                _bad += 1
            else:
                _ok += 1
        f = dir.get_next()
    dir.list_dir_end()
