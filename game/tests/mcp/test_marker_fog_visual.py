"""T-165: маркеры `MarkerLayer` не имеют права светиться сквозь туман.

Что проверяется (канон `docs/02g` §2.1: неисследованная клетка пуста, «без ресурсов
и маркеров»): на живом кадре мира ни один пиксель маркера (шахта `⛏`/`✗`, название
города, дуга угрозы) не нарисован поверх пустого фона, то есть поверх клетки,
которая никогда не была в поле зрения.

Почему кадр читается в движке, а не в pytest: в MCP-venv намеренно нет
PNG-декоратора (`capture.py` читает только IHDR), а сравнение идёт по четырём
кадрам одного раннера — пиксели снимаются `get_texture().get_image()` и сравниваются
`PackedByteArray`-буферами. Та же причина, что у `test_threat_rings_visual.py`.

Почему проверка дифференциальная, а не «найди пиксели цвета кирки»: глиф рисуется
`draw_string(ThemeDB.fallback_font, …)`, и его цвет приносит шрифт эмодзи машины.
Поэтому кадр-фон (слой выключен целиком) отвечает на вопрос «что вообще нарисовано
маркерным слоем», а пустой фон — на вопрос «где под ним не было карты». Отдельно
меряется чувствительность: сколько пикселей слой рисует только потому, что туман
о нём забыли (до правки — весь дефект, после — 0 на пустом фоне).
"""

from __future__ import annotations

import pytest

import test_threat_rings_visual as tr

pytestmark = pytest.mark.timeout(900)

# Подготовка: слой получает туман от хоста так, как его получает в игре, и
# сообщает, сколько маркеров ресурсов на карте и сколько клеток исследовано.
_PREPARE = """
var world = get_tree().current_scene
var markers: Node = world.get_node("WorldUI/MarkerLayer")
var fog = world.get_fog()
if fog == null:
    return {"ok": false, "reason": "нет карты видимости"}
markers.set_fog(fog)
return {"ok": true, "terrain_markers": markers._terrain_pos.size(),
    "cities": markers._city_marks.size(), "explored": fog.explored.size(),
    "void": [ProjectSettings.get_setting(
        "rendering/environment/defaults/default_clear_color").r,
        ProjectSettings.get_setting(
            "rendering/environment/defaults/default_clear_color").g,
        ProjectSettings.get_setting(
            "rendering/environment/defaults/default_clear_color").b]}
"""

# Слой рисует всё, что знает: туман ему снят. Эквивалент до-состояния (T-165).
_UNFOG = """
var world = get_tree().current_scene
world.get_node("WorldUI/MarkerLayer").set_fog(null)
return true
"""

_FOG_BACK = """
var world = get_tree().current_scene
var markers: Node = world.get_node("WorldUI/MarkerLayer")
markers.set_fog(world.get_fog())
return true
"""

_SET_VISIBLE = """
var world = get_tree().current_scene
world.get_node("WorldUI/MarkerLayer").visible = {on}
return true
"""

# Кадр в буфер под мета-полем мира: мета живёт между вызовами eval, поэтому четыре
# кадра снимаются в одной сессии, а сравниваются одним проходом по байтам.
_GRAB = """
var world = get_tree().current_scene
var img: Image = world.get_viewport().get_texture().get_image()
world.set_meta("{key}", img)
return [img.get_width(), img.get_height()]
"""

# Сравнение: hidden — пиксели, которые слой дорисовывает без тумана (чувствительность);
# leaks — пиксели, нарисованные слоем там, где фон пустой (сам дефект).
_COMPARE = """
var world = get_tree().current_scene
var a: Image = world.get_meta("A")
var b: Image = world.get_meta("B")
var bg: Image = world.get_meta("BG")
var fg: Image = world.get_meta("FG")
var dims := [a.get_width(), a.get_height(), b.get_width(), b.get_height(),
    bg.get_width(), bg.get_height(), fg.get_width(), fg.get_height()]
for d in dims:
    if d <= 0:
        return {"ok": false, "reason": "кадр не снят: %s" % dims}
if a.get_size() != b.get_size() or a.get_size() != bg.get_size() \\
        or a.get_size() != fg.get_size():
    return {"ok": false, "reason": "размеры кадров разошлись: %s" % dims}
var clear: Color = ProjectSettings.get_setting(
    "rendering/environment/defaults/default_clear_color")
var vr: int = int(round(clear.r * 255.0))
var vg: int = int(round(clear.g * 255.0))
var vb: int = int(round(clear.b * 255.0))
var da: PackedByteArray = a.get_data()
var db: PackedByteArray = b.get_data()
var dg: PackedByteArray = bg.get_data()
var df: PackedByteArray = fg.get_data()
var hidden := 0
var leaks := 0
var first := ""
var n: int = da.size()
var i := 0
while i < n:
    if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]:
        hidden += 1
    if (dg[i] != df[i] or dg[i + 1] != df[i + 1] or dg[i + 2] != df[i + 2]) \\
            and dg[i] == vr and dg[i + 1] == vg and dg[i + 2] == vb:
        leaks += 1
        if first == "":
            var px: int = int(i / 4.0)
            first = "%d,%d" % [px % a.get_width(), int(px / a.get_width())]
    i += 4
return {"ok": true, "hidden": hidden, "leaks": leaks, "first": first,
    "void": [vr, vg, vb], "frame": [a.get_width(), a.get_height()]}
"""


def test_markers_do_not_shine_through_fog(full_game):
    mcp = full_game
    info = mcp.execute_code(_PREPARE)
    assert info.get("ok") is True, f"маркерный слой недоступен: {info}"
    assert info["terrain_markers"] > 0, \
        "на карте нет маркеров ресурсов — проверять нечего"

    # Неподвижная камера: кадры обязаны совпасть пиксель в пиксель, иначе разница
    # «слой включён / слой выключен» посчитает шумом каждый кадр.
    tr._setup(mcp)
    mcp.execute_code(_PREPARE)
    mcp.wait_frames(30)

    with_fog = mcp.execute_code(_GRAB.format(key="A"))
    mcp.execute_code(_UNFOG)
    mcp.wait_frames(3)
    all_markers = mcp.execute_code(_GRAB.format(key="B"))
    mcp.execute_code(_FOG_BACK)

    # Кадр-фон: слой выключен целиком. Пиксель, отличающийся от фона, нарисован
    # слоем; если под ним пустой фон — маркер стоит на неисследованной клетке.
    mcp.execute_code(_SET_VISIBLE.format(on="false"))
    mcp.wait_frames(3)
    background = mcp.execute_code(_GRAB.format(key="BG"))
    mcp.execute_code(_SET_VISIBLE.format(on="true"))
    mcp.wait_frames(3)
    shown = mcp.execute_code(_GRAB.format(key="FG"))

    for name, frame in (("A", with_fog), ("B", all_markers), ("bg", background),
                        ("fg", shown)):
        assert isinstance(frame, list) and len(frame) == 2 and frame[0] > 0, \
            f"кадр {name} не снят: {frame}"

    res = mcp.execute_code(_COMPARE)
    assert res.get("ok") is True, f"кадры не сравнились: {res}"
    print(f"маркеров ресурсов: {info['terrain_markers']}, исследовано клеток: "
          f"{info['explored']}, кадр {res['frame']}, фон {res['void']}; "
          f"скрыто туманом: {res['hidden']} px, нарисовано поверх пустого фона: "
          f"{res['leaks']} px")

    # Чувствительность: за туманом обязаны быть маркеры. Если их нет, проверка
    # ниже тривиальна и ничего не доказывает (карта без ресурсов, тумана нет).
    assert res["hidden"] > 0, (
        "снятие тумана не добавило ни пикселя: за туманом маркеров нет — проверка "
        "была бы тривиальной"
    )
    assert res["leaks"] == 0, (
        f"{res['leaks']} пикселей маркеров нарисованы поверх пустого "
        f"(неисследованного) фона {res['void']}, первая точка: {res['first']} — "
        "маркерный слой раскрывает скрытую карту (T-165)"
    )
