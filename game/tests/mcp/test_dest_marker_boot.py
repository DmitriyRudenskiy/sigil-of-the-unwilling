"""T-275: оверлей точки назначения обязано видно в живом потоке, а не только в юните.

Что проверяется: после ботстрэпа мира (fixture `full_game`) под `root` сцены живёт
ровно один `DestMarker`, и держатель (`HeroVisualController._marker`) указывает на
него же; после `teardown_path_visual()` маркер уходит из дерева.

Механизм дефекта: `setup_path_visual()` монтирует маркер прямым
`get_tree().root.add_child(_marker)` в тот момент, когда `root` **уже** добавляет
детей — мир ставится под `root` тем же вызовом (`change_scene_to_file`), и его
`_ready` → `WorldBootstrap.run` → `_init_hero` → `setup_path_visual` происходит
внутри окна «Parent node is busy setting up children». Godot печатает ERROR и
**продолжает работу**: `add_child` не выполняется, `_marker` остаётся созданным
вне дерева, повторной попытки код не делал. Юнит-тесты T-214 (`test_dest_marker_
ownership.gd`) этого не видели: там герой собирается не внутри чужого `add_child`
для `root`, и прямой монтаж проходит.

Почему мёртвый код опасен: до T-214 маркер мог осиротеть под `root`; после T-214
он не попадал под `root` никогда — слой «куда идёт отряд» отсутствовал в игре целиком,
и ни один headless-тест это не заметил.

Съёмка без GUI обязательна: проверка читает дерево узлов через `game_eval`, пиксели
для вердикта не нужны (кадр — в ux-review тикета).
"""

from __future__ import annotations

import time

import pytest

pytestmark = pytest.mark.timeout(900)

# Поиск держателя ищется по пути скрипта, а не по имени узла: держатель — компонент,
# его имя — деталь реализации.
FIND_CTRL = """
var found = null
var stack = [get_tree().root]
while not stack.is_empty():
	var n = stack.pop_back()
	if n.get_script() != null and String(n.get_script().resource_path).contains("hero_visual_controller.gd"):
		found = n
		break
	for c in n.get_children():
		stack.append(c)
return {"found": found != null}
"""

COUNT = """
var under_root = 0
var stack = [get_tree().root]
while not stack.is_empty():
	var n = stack.pop_back()
	if n is DestMarker and n.get_parent() == get_tree().root:
		under_root += 1
	for c in n.get_children():
		stack.append(c)
return {"under_root": under_root}
"""

# Состояние держателя: маркер существует и он в дереве. `in_tree == false` при
# `marker_null == false` — ровно та сигнатура дефекта, что дала живой прогон.
HOLDER = """
var found = null
var stack = [get_tree().root]
while not stack.is_empty():
	var n = stack.pop_back()
	if n.get_script() != null and String(n.get_script().resource_path).contains("hero_visual_controller.gd"):
		found = n
		break
	for c in n.get_children():
		stack.append(c)
if found == null:
	return {"found": false}
var m = found.get("_marker")
var is_null = (m == null)
var in_tree = false
if m != null:
	in_tree = m.is_inside_tree()
return {"found": true, "marker_null": is_null, "in_tree": in_tree}
"""

TEARDOWN = """
var found = null
var stack = [get_tree().root]
while not stack.is_empty():
	var n = stack.pop_back()
	if n.get_script() != null and String(n.get_script().resource_path).contains("hero_visual_controller.gd"):
		found = n
		break
	for c in n.get_children():
		stack.append(c)
if found == null:
	return {"found": false}
found.teardown_path_visual()
var under_root = 0
var stack2 = [get_tree().root]
while not stack2.is_empty():
	var n2 = stack2.pop_back()
	if n2 is DestMarker and n2.get_parent() == get_tree().root:
		under_root += 1
	for c in n2.get_children():
		stack2.append(c)
return {"found": true, "under_root": under_root}
"""


def test_dest_marker_is_mounted_after_world_boot(full_game):
    assert full_game.execute_code(FIND_CTRL).get("found"), (
        "HeroVisualController не найден в дереве — fixture не дошла до ботстрэпа"
    )
    holder = full_game.execute_code(HOLDER)
    assert not holder.get("marker_null"), (
        "маркер вообще не создан — setup_path_visual не вызывался"
    )
    assert holder.get("in_tree"), (
        "_marker создан, но вне дерева: add_child под root не прошёл «busy "
        "setting up children» — оверлей точки назначения в игре не виден"
    )
    assert full_game.execute_code(COUNT).get("under_root") == 1


def test_dest_marker_leaves_on_teardown(full_game):
    # Обязательство T-214 («снят держателем») проверяется на живом дереве: после
    # teardown под root не должно остаться сирот. Счётчик снимается после кадра
    # ожидания: `Node.free()` внутри дерева ведёт себя как `queue_free()`, узел
    # уходит из `get_children()` в конце кадра, а не в строке вызова.
    assert full_game.execute_code(COUNT).get("under_root") == 1
    assert full_game.execute_code(TEARDOWN).get("found")
    time.sleep(1.0)
    assert full_game.execute_code(COUNT).get("under_root") == 0, (
        "после teardown_path_visual под root остался сирота-маркер"
    )
