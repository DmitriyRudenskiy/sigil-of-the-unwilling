extends GdUnitTestSuite

const _SCENES := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/CityArena.tscn",
	"res://scenes/World.tscn",
	"res://scenes/Battle.tscn",
]

func _pump(node: Node, frames: int) -> void:
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
		assert_that(res).is_not_null()
		var node: Node = res.instantiate()
		assert_that(node).is_not_null()
		_boot_and_pump(path, node)

func _boot_and_pump(path: String, node: Node) -> void:
	var root: Node = get_tree().get_root()
	if root != null:
		root.add_child(node)
	_pump(node, 3)
	if node != null and node.is_inside_tree():
		node.queue_free()
