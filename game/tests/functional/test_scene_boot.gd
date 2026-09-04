extends "res://tests/gut_base.gd"
## 1.4 Порт tools/run_scene.gd: headless-boot четырёх игровых сцен и проверка,
## что каждая инстанцируется без SCRIPT ERROR / parse-ошибок.
##
## Ключевой инвариант (как в run_scene.gd): сцена должна загрузиться
## (ResourceLoader.load) и инстанцироваться (instantiate != null). Если у
## сцены/её скрипта есть parse-ошибка или неверный ext_resource — instantiate()
## вернёт null, и тест падает. Это детерминированная проверка «сцена ботается».
##
## Сцены простые (single-node), поэтому _ready/_process не должны падать в
## headless; прокачиваем несколько кадров для sanity.

const _SCENES := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/CityArena.tscn",
	"res://scenes/World.tscn",
	"res://scenes/Battle.tscn",
]

func _pump(node: Node, frames: int) -> void:
	# _ready уже вызвался при add_child (add_child триггерит _ready). Повторный
	# вызов _ready вручную привёл бы к двойному _new_game / повторному
	# get_viewport().size_changed.connect(...), что для глобального viewport
	# («already connected») считается Unexpected Error в GUT. Поэтому здесь —
	# только прокачка кадров (_process), без повторного _ready.
	if node != null and node.is_inside_tree():
		var delta := 1.0 / 60.0
		for _i in frames:
			if node.has_method("_process"):
				node._process(delta)
			if node.has_method("_process_delta"):
				node._process_delta(delta)

func test_all_scenes_instantiate() -> void:
	for path in _SCENES:
		var res: Resource = ResourceLoader.load(path)
		assert_not_null(res, "load scene %s" % path)
		var node: Node = res.instantiate()
		assert_not_null(node, "instantiate scene %s" % path)
		# Прокачиваем кадры: _ready/_process не должны падать в headless.
		_boot_and_pump(path, node)

func _boot_and_pump(path: String, node: Node) -> void:
	var root: Node = get_tree().get_root()
	if root != null:
		root.add_child(node)
	_pump(node, 3)
	if node != null and node.is_inside_tree():
		node.queue_free()
