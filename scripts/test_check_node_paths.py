"""Самопроверка measure-гейта путей узлов (T-296).

Зачем тесты у теста: гейт красит сборку, и его главная опасность — не ложный
RED, а ложный GREEN молча сломанного сканера (первая версия замера T-296
объявляла нерезолвленным всё подряд, и это выглядело как «много ошибок», а не
как «измеритель сломался»). Поэтому здесь есть и красный кейс (сломанный путь
обязан быть красным), и кейс нижней границы (пустой скан красит).

Запуск: /home/user/.venv/godot-mcp-tests/bin/python -m pytest scripts/test_check_node_paths.py -q
"""

import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_node_paths as cn  # noqa: E402


def _repo(tmp_path, scenes: dict, scripts: dict, allowlist=None):
    """Собирает уменьшенное дерево репозитория и переключает модуль на него."""
    game = tmp_path / "game"
    for rel, body in scenes.items():
        p = game / "scenes" / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body, encoding="utf-8")
    for rel, body in scripts.items():
        p = game / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body, encoding="utf-8")
    allow = tmp_path / "allow.txt"
    if allowlist is not None:
        allow.write_text(allowlist, encoding="utf-8")
    cn.GAME = str(game)
    cn.REPO = str(tmp_path)
    cn.SCRIPTS_FLOOR = 1
    cn.LITERALS_FLOOR = 1
    return str(allow)


SCENE_OK = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/screen.gd" id="1"]

[node name="Screen" type="Control"]
script = ExtResource("1")

[node name="Panel" type="PanelContainer" parent="."]

[node name="Title" type="Label" parent="Panel"]
"""

SCRIPT_OK = '''extends Control

func _ready() -> void:
	var t := get_node("Panel/Title") as Label
	print(t.text)
'''


def test_green_path_passes(tmp_path):
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": SCRIPT_OK}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, lines
    assert "PATH-GATE: OK" in "\n".join(lines)


def test_broken_path_is_red(tmp_path):
    """Главный кейс: узла нет — гейт обязан краснеть, иначе он декорация."""
    script = SCRIPT_OK.replace('"Panel/Title"', '"Panel/Moved"')
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": script}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    out = "\n".join(lines)
    assert code == 1, out
    assert "Panel/Moved" in out


def test_rename_of_parent_breaks_chain(tmp_path):
    """Класс D-280/T-294: блок переехал — цепочка рвётся, гейт красит."""
    moved = SCENE_OK.replace('parent="Panel"', 'parent="Other"').replace(
        '[node name="Panel" type="PanelContainer" parent="."]',
        '[node name="Other" type="PanelContainer" parent="."]')
    allow = _repo(tmp_path, {"ui/screen.tscn": moved},
                  {"scripts/ui/screen.gd": SCRIPT_OK}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 1, "\n".join(lines)


def test_numeric_suffix_template(tmp_path):
    """`Slot%d` резолвится по реальным Slot0/Slot1 и краснеет, если их сняли."""
    scene = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/grid.gd" id="1"]

[node name="Grid" type="GridContainer"]
script = ExtResource("1")

[node name="Slot0" type="Panel" parent="."]

[node name="Slot1" type="Panel" parent="."]
"""
    script = '''extends GridContainer

func _ready() -> void:
	for i in 2:
		var s := get_node("Slot%d" % i) as Panel
		print(s.name)
'''
    allow = _repo(tmp_path, {"ui/grid.tscn": scene}, {"scripts/ui/grid.gd": script},
                  allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)

    empty = scene.replace('[node name="Slot0" type="Panel" parent="."]\n', "") \
                 .replace('[node name="Slot1" type="Panel" parent="."]\n', "")
    allow = _repo(tmp_path, {"ui/grid.tscn": empty}, {"scripts/ui/grid.gd": script},
                  allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 1, "\n".join(lines)


def test_instanced_subtree_counts(tmp_path):
    """Вложенные сцены — слепая зона замера, поэтому они разворачиваются."""
    child = """[gd_scene format=3]

[node name="Visuals" type="Node2D"]

[node name="Figure" type="Sprite2D" parent="."]
"""
    parent = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/ui/visuals.tscn" id="1"]
[ext_resource type="Script" path="res://scripts/ui/view.gd" id="2"]

[node name="Field" type="Control"]
script = ExtResource("2")

[node name="Unit" parent="." instance=ExtResource("1")]
"""
    script = '''extends Control

func _ready() -> void:
	var f := get_node("Unit/Figure") as Sprite2D
	print(f)
'''
    allow = _repo(tmp_path, {"ui/visuals.tscn": child, "ui/field.tscn": parent},
                  {"scripts/ui/view.gd": script}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)


def test_dollar_and_const_forms_are_scanned(tmp_path):
    """`$Path` и `const ПУТЬ` как аргумент — те же литералы, сканер обязан их видеть."""
    scene = SCENE_OK.replace('path="res://scripts/ui/screen.gd"',
                             'path="res://scripts/ui/screen.gd"')
    script = '''extends Control

const TITLE := "Panel/Title"

func _ready() -> void:
	var a := $Panel/Title as Label
	var b := get_node(TITLE) as Label
	print(a, b)
'''
    allow = _repo(tmp_path, {"ui/screen.tscn": scene}, {"scripts/ui/screen.gd": script},
                  allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)
    assert "литералов пути: 1" in "\n".join(lines)  # оба пути — одна и та же цепочка


def test_exclusion_needs_reason(tmp_path):
    script = SCRIPT_OK.replace('"Panel/Title"', '"Runtime/Thing"')
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": script},
                  allowlist="game/scripts/ui/screen.gd\tRuntime/Thing\n")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    out = "\n".join(lines)
    assert code == 1 and "нет причины" in out, out


def test_exclusion_with_reason_passes(tmp_path):
    script = SCRIPT_OK.replace('"Panel/Title"', '"Runtime/Thing"')
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": script},
                  allowlist="game/scripts/ui/screen.gd\tRuntime/Thing\tсоздаёт этот же скрипт в _ready\n")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)


def test_stale_exclusion_is_red(tmp_path):
    """Устаревшая запись красная: иначе список превращается в корзину."""
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": SCRIPT_OK},
                  allowlist="game/scripts/ui/screen.gd\tPanel/Gone\tкогда-то создавался кодом\n")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    out = "\n".join(lines)
    assert code == 1 and "устаревших" in out, out


def test_missing_allowlist_is_red(tmp_path):
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": SCRIPT_OK}, allowlist=None)
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    out = "\n".join(lines)
    assert code == 1 and "нет файла" in out, out


def test_runtime_assigned_names_are_exempt(tmp_path):
    """Имя, которое скрипт присваивает сам (константа и цикл по списку), — не дефект."""
    script = '''extends Control

const DATE := "CampaignDate"

func _ready() -> void:
	var d := get_node_or_null(DATE) as Label
	var f := get_node_or_null("BuildFarm") as Button
	d.name = DATE
	for action_name in ["BuildFarm", "Hire"]:
		var b := Button.new()
		b.name = action_name
'''
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": script}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)
    # CampaignDate (через константу) и BuildFarm (через цикл по списку) — оба
    # имена, которые скрипт присваивает сам; на проверку они не идут.
    assert "рантайм-имена 2" in "\n".join(lines), "\n".join(lines)


def test_broken_meter_is_red(tmp_path):
    """Нижняя граница: «чисто» от «ничего не вижу» отличается только счётчиком."""
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": SCRIPT_OK}, allowlist="")
    cn.SCRIPTS_FLOOR = 999
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    out = "\n".join(lines)
    assert code == 1 and "измеритель сломан" in out, out


def test_global_root_paths_skipped(tmp_path):
    script = '''extends Control

func _ready() -> void:
	var s := get_tree().root.get_node_or_null("/root/Services")
	print(s)
'''
    allow = _repo(tmp_path, {"ui/screen.tscn": SCENE_OK},
                  {"scripts/ui/screen.gd": script}, allowlist="")
    code, lines = cn.check(scenes_root=str(tmp_path / "game/scenes"), allowlist=allow)
    assert code == 0, "\n".join(lines)
    assert "глобальные /root/… 1" in "\n".join(lines)
