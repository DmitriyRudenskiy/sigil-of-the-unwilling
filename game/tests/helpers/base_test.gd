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

## Изоляция сезона (T-322, Q-M130 → (а+в), D-308). `WorldSeasons._turn_count` —
## статика процесса: кампанийный ход (`world_event_router.gd`), поднятие мира из
## сейва и `set_turns()` оставляют счётчик чужим, и сезон следующего теста
## оказывается суммой всех ранее прогнанных сюит. Сброс в `before_test` был бы
## буквой решения (а) дословно, но 94 сюит объявляют собственный `before_test` и
## ни одна не зовёт `super.before_test()` (замер 2026-11-08: `grep -rl
## 'func before_test(' tests` = 94, `super.before_test` = 0) — то есть четверть
## набора сброс бы молча пропустила. Отсюда два носителя: `_init` срабатывает по
## одному разу на сюиту и переопределить его нечем (сюитных `_init` в наборе
## нет), `before_test` докрывает кейс-к-кейсу там, где сюита себя не переопределила.
## Дыра остаётся: кейсы внутри 94 сюжет по-прежнему читают то, что оставил
## предыдущий кейс; это фиксирует гард, а не молчание.
static func _season_reset() -> void:
	WorldSeasons.reset()

func _init() -> void:
	_season_reset()

func before_test() -> void:
	_season_reset()
