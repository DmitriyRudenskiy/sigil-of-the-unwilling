extends SceneTree
## Headless operability runner для одной сцены.
## Запуск: SCENE_PATH=scenes/World.tscn MAX_FRAMES=60 godot --headless -s tools/run_scene.gd
## Инстансирует сцену (с глобальными autoloads), прогоняет MAX_FRAMES кадров,
## затем quit(0). Если сцена не загрузилась/инстанцировалась — push_error + quit(2).
## Ошибки контроллера (_ready/_process) всплывают в консоль как SCRIPT ERROR —
## их ловит обёртка run_operability.sh и циклом run-and-fix чинит.
##
## Работаем в _process (не в _init): autoloads регистрируются к _process, а не к
## старту скрипта — иначе false-positive «Could not find type».
var _done := false
var _frames := 0
var _target := ""
var _max := 60
var _root_node: Node = null

func _process(_delta: float) -> bool:
    if _done:
        return false
    if _target == "":
        _target = OS.get_environment("SCENE_PATH")
        var raw_max: String = OS.get_environment("MAX_FRAMES")
        _max = int(raw_max) if raw_max.is_valid_int() and int(raw_max) > 0 else 60
        if _target == "":
            push_error("run_scene.gd: SCENE_PATH не задан (env)")
            quit(2)
            return false
        var res: Resource = ResourceLoader.load(_target)
        if res == null:
            push_error("run_scene.gd: не загрузилась сцена " + _target)
            quit(2)
            return false
        _root_node = res.instantiate()
        if _root_node == null:
            push_error("run_scene.gd: не инстанцировалась сцена " + _target)
            quit(2)
            return false
        var root: Node = get_root()
        if root != null:
            root.add_child(_root_node)
        print("run_scene: instanced " + _target + " (" + str(_max) + " frames)")
    _frames += 1
    if _frames >= _max:
        print("run_scene: done " + str(_frames) + " frames on " + _target)
        _done = true
        quit(0)
    return false
