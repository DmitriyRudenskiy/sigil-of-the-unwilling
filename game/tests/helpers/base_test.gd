class_name BaseTest
extends GdUnitTestSuite

## Shared test-suite helpers (TASK_18 B1.5).
##
## Node creation goes through make_node(): the node is added to the suite and
## registered for auto-free, so tests no longer leak scene nodes between cases.
## Plain RefCounted objects need none of this — GDScript frees them.

func make_node(scene_or_script: Resource) -> Node:
	var node: Node
	if scene_or_script is PackedScene:
		node = (scene_or_script as PackedScene).instantiate()
	elif scene_or_script is GDScript:
		node = (scene_or_script as GDScript).new()
	else:
		push_error("make_node: expected PackedScene or GDScript, got %s" % scene_or_script)
		return null
	add_child(node)
	return auto_free(node)

## Safety net: drop everything still attached to the suite (e.g. nodes created
## without make_node). Call at the end of a test when in doubt.
func free_all() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	await get_tree().process_frame

## Test isolation: a test that pauses the tree (BattleTurnExecutor / DecisionPanel
## via PauseController) and doesn't resume would leave tree.paused=true, which
## breaks frame-dependent tests and hangs final disposal. Reset the pause state
## after every test so cases stay independent.
func after_test() -> void:
	get_tree().paused = false
	var pc := get_node_or_null("/root/PauseController")
	if pc != null and pc.has_method("force_release_all"):
		pc.force_release_all()
