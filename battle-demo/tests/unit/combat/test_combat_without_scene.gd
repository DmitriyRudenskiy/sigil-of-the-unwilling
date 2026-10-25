#extends GdUnitTestSuite
# tests/unit/combat/test_combat_without_scene.gd
# [AI]: сгенерировано по задаче 4.9 tasks.md.
# Модель не зависит от отображения: бой прогоняется без единого узла, и в слоях
# scripts/combat нет ни одной ссылки на Node, сцены или дерево.

extends GdUnitTestSuite

const FORBIDDEN := [
	"extends Node",
	"get_tree(",
	"add_child(",
	"@onready",
	"res://scenes",
	"await ",
]


func _count_nodes(node: Node, total: int = 0) -> int:
	total += 1
	for child in node.get_children():
		total = _count_nodes(child, total)
	return total


func test_battle_runs_without_touching_scene_tree() -> void:
	var root := get_tree().root
	var before := _count_nodes(root)
	var combat := BattleFactory.state(
		BattleFactory.roster([BattleFactory.stats(&"hero", 200, 30, 5, 20)]),
		[BattleFactory.stats(&"foe", 100, 10, 5, 5)],
		11
	)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_int(_count_nodes(root)).is_equal(before)
	assert_str(combat.get_class()).is_equal("RefCounted")


func test_combat_layer_has_no_display_references() -> void:
	var dir := DirAccess.open("res://scripts/combat")
	assert_object(dir).is_not_null()
	dir.list_dir_begin()
	var checked := 0
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".gd"):
			checked += 1
			var source := FileAccess.get_file_as_string("res://scripts/combat/" + name)
			for pattern in FORBIDDEN:
				assert_bool(source.contains(pattern)).is_false()
		name = dir.get_next()
	assert_int(checked).is_greater_equal(6)
