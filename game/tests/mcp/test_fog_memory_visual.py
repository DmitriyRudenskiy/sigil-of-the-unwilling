"""T-168: «открыто и не видно» обязано быть затемнённым, а не пустым.

Что проверяется (канон тумана войны, `docs/02g` §2.1 и комментарий-правило в
`map_renderer.gd:267`: «не открыта — пусто, открыта и не видима — затемнено той же
кратности, что база»): клетка, которую игрок уже видел, но которая сейчас вне поля
зрения, обязана оставаться на кадре тёмной версией себя. Пустой фон под таким
местом означает, что память тумана невидима, и отступивший туман неотличим от
никогда не открытой земли.

Механизм дефекта: `MapRenderer.apply_fog` кладёт такие клетки в
`TileAtlas.FOG_SOURCE_ID` (1) — затемнённый побратим листа. Гексовый тайлсет карта
получает из `TileAtlas.build_hex()`, а он объявляет **только** `SOURCE_ID`
(побратима добавляет квадратный `build()`), то есть ссылка ведёт в источник,
которого в тайлсете нет, и `TileMapLayer` такой тайл не рисует.

Мера дифференциальная, три кадра одного раннера и одной камеры:
`N` — туман без памяти (свежая `VisibilityMap`, открыт только дальний диск);
`M` — живой туман с памятью (тот же дальний диск, но `explored` содержит диск героя);
`B` — герой на месте (диск героя виден ярко, памяти нет).
Одинаковый `visible` в N и M означает, что единственное их различие — клетки памяти;
сравнивается, что они нарисованы (`diff`) и что нарисованы темнее яркого кадра
(`darker`) — иначе «починка» могла бы рисовать память яркой.

Слои переходов, дорог, растительности и её теней снимаются: у них свои туманные
источники (`MapObjects.FOG_SOURCE_ID`, `SHADOW_FOG_SOURCE_ID`), они в тайлсетах
есть, и их пиксели приписали бы дефекту базового слоя то, что к нему не относится.

Почему кадр читается в движке: в MCP-venv намеренно нет PIL, пиксели снимаются
`get_texture().get_image()` и сравниваются `PackedByteArray`-буферами — тот же
порядок, что у `test_threat_rings_visual.py` и `test_marker_fog_visual.py`.
"""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.timeout(900)

# Доля пустого фона в кадре «памяти нет» — sanity фикстуры: если кадр почти целиком
# карта, тумана в кадре нет и сравнивать нечего.
MIN_VOID_SHARE = 0.3

# Минимум пикселей памяти в кадре. Диск радиуса 3 — 37 клеток гекса 82 px, то есть
# десятки тысяч пикселей; порог на два порядка ниже, чтобы не падать на компоновке
# кадра, но не пройти на «проскочило несколько пикселей».
MIN_MEMORY_PIXELS = 1000

# Доля потемневших пикселей среди пикселей памяти.
MIN_DARKENED_SHARE = 0.8

# Только базовый слой + подготовка: дальняя клетка (противоположный угол карты),
# городские источники и живой туман, который к этому моменту уже содержит память о
# стартовой клетке героя (её нарисовал bootstrap).
_PREPARE = """
var world = get_tree().current_scene
var map = world.get_map_gen()
var hero = world.get_hero()
var fog = world.get_fog()
if map == null or hero == null or fog == null:
    return {"ok": false, "reason": "мир не собран"}
if not (hero.current_cell is Vector2i):
    return {"ok": false, "reason": "у героя нет клетки"}
var hero_cell: Vector2i = hero.current_cell
var far: Vector2i = Vector2i.ZERO
var best := -1
for cand in [Vector2i.ZERO, Vector2i(map.map_width - 1, 0),
        Vector2i(0, map.map_height - 1), Vector2i(map.map_width - 1, map.map_height - 1)]:
    var d: int = HexUtils.hex_distance(hero_cell, cand)
    if d > best:
        best = d
        far = cand
if best < GameNumbers.FOG_HERO_SIGHT * 3:
    return {"ok": false, "reason": "карта мала: дальний угол в %d клетках" % best}
var cities: Array = []
for city in world.get_cities().cities:
    if city != null and city.owner == &"player" and city.center is Vector2i:
        cities.append(city.center)
world.set_meta("t_far", far)
world.set_meta("t_hero", hero_cell)
world.set_meta("t_cities", cities)
world.set_meta("t_shift", map.hex_shift_right)
for layer in ["transitions", "roads", "vegetation"]:
    map.set_layer_enabled(layer, false)
# Тени растительности нет в `render_layers` (у слоя нет имени для отладки), а туман
# красит её своим `MapObjects.SHADOW_FOG_SOURCE_ID`, который существует: не сними её,
# в дифф попали бы тени деревьев вместо базового слоя.
var shadow: Node = map.get_node_or_null("TileMapShadow")
if shadow != null:
    shadow.visible = false
# Маркерный слой держит ссылку на живой туман и потому меняет картинку между
# состоями сам (городские имена и глифы ресурсов в 12 клетках памяти), а цикл дня
# (3 c) двигал бы его же между двумя кадрами. Проверяется базовый слой — маркеры в
# диффе только шумели бы. Корень WorldUI не гасится: он роняет Godot под MCP (T-167).
var markers: Node = world.get_node_or_null("WorldUI/MarkerLayer")
if markers != null:
    markers.visible = false
# Камера фиксируется руками: с включённым сглаживанием каждый захват ловит середину
# lerp'а и кадры расходятся сдвигом всей карты (замер 2026-10-24: 350 тыс. пикселей
# различия N↔M при одинаковом тумане — это был именно сдвиг, а не туман).
var cam: Camera2D = world.get_camera()
cam.position_smoothing_enabled = false
cam.offset = Vector2.ZERO
cam.center_on(map.map_to_local(hero_cell))
return {"ok": true, "hero": [hero_cell.x, hero_cell.y], "far": [far.x, far.y],
    "distance": best, "cities": cities.size(),
    "explored_live": fog.explored.size(), "visible_live": fog.visible.size()}
"""

# state = never | memory | bright — три состояния тумана (см. docstring).
# Память получается живым объектом тумана: `explored` в нём накапливается и не
# стирается (`visibility_map.gd:_explore`), поэтому `recompute` на дальнюю клетку
# оставляет диск героя исследованным и одновременно убирает его из видимого.
_APPLY = """
var world = get_tree().current_scene
var map = world.get_map_gen()
var far: Vector2i = world.get_meta("t_far")
var hero_cell: Vector2i = world.get_meta("t_hero")
var cities: Array = world.get_meta("t_cities")
var shift_right: bool = world.get_meta("t_shift")
var state := "{state}"
var at: Vector2i = far
if state == "bright":
    at = hero_cell
var sources: Array = [at]
for c in cities:
    if c != at:
        sources.append(c)
var vm = world.get_fog() if state == "memory" else VisibilityMap.new()
vm.set_map_size(map.map_width, map.map_height)
vm.recompute(at, sources, GameNumbers.FOG_HERO_SIGHT, GameNumbers.FOG_CITY_SIGHT,
        shift_right)
map.apply_fog(vm)
var hidden_by_memory := 0
for cell in vm.explored:
    if not vm.visible.has(cell):
        hidden_by_memory += 1
return {"ok": true, "explored": vm.explored.size(), "visible": vm.visible.size(),
    "memory_cells": hidden_by_memory}
"""

_GRAB = """
var world = get_tree().current_scene
var map = world.get_map_gen()
var cam: Camera2D = world.get_camera()
cam.center_on(map.map_to_local(world.get_meta("t_hero")))
var img: Image = world.get_viewport().get_texture().get_image()
world.set_meta("{key}", img)
return [img.get_width(), img.get_height()]
"""

_COMPARE = """
var world = get_tree().current_scene
var n: Image = world.get_meta("N")
var m: Image = world.get_meta("M")
var b: Image = world.get_meta("B")
if n == null or m == null or b == null:
    return {"ok": false, "reason": "кадр не снят"}
if n.get_size() != m.get_size() or n.get_size() != b.get_size():
    return {"ok": false, "reason": "размеры кадров разошлись"}
var clear: Color = ProjectSettings.get_setting(
    "rendering/environment/defaults/default_clear_color")
var vr: int = int(round(clear.r * 255.0))
var vg: int = int(round(clear.g * 255.0))
var vb: int = int(round(clear.b * 255.0))
var dn: PackedByteArray = n.get_data()
var dm: PackedByteArray = m.get_data()
var db: PackedByteArray = b.get_data()
var diff := 0
var darker := 0
var void_never := 0
var i := 0
while i < dn.size():
    if dn[i] == vr and dn[i + 1] == vg and dn[i + 2] == vb:
        void_never += 1
    if dn[i] != dm[i] or dn[i + 1] != dm[i + 1] or dn[i + 2] != dm[i + 2]:
        diff += 1
        if dm[i] < db[i] and dm[i + 1] < db[i + 1] and dm[i + 2] < db[i + 2]:
            darker += 1
    i += 4
return {"ok": true, "pixels": dn.size() / 4, "diff": diff, "darker": darker,
    "void_never": void_never, "void": [vr, vg, vb],
    "frame": [n.get_width(), n.get_height()]}
"""


def _grab(mcp, key: str) -> None:
    mcp.wait_frames(6)
    frame = mcp.execute_code(_GRAB.replace("{key}", key))
    assert isinstance(frame, list) and len(frame) == 2 and frame[0] > 0, \
        f"кадр {key} не снят: {frame}"


def test_explored_but_unseen_terrain_stays_drawn_dimmed(full_game):
    mcp = full_game
    info = mcp.execute_code(_PREPARE)
    assert info.get("ok") is True, f"фикстура тумана не собралась: {info}"
    mcp.wait_frames(10)

    never = mcp.execute_code(_APPLY.replace("{state}", "never"))
    assert never.get("ok") is True, f"туман без памяти не применился: {never}"
    _grab(mcp, "N")

    memory = mcp.execute_code(_APPLY.replace("{state}", "memory"))
    assert memory.get("ok") is True, f"туман с памятью не применился: {memory}"
    _grab(mcp, "M")

    bright = mcp.execute_code(_APPLY.replace("{state}", "bright"))
    assert bright.get("ok") is True, f"яркий кадр не применился: {bright}"
    _grab(mcp, "B")

    # Клетки памяти обязаны быть: иначе сравнение тривиально (например, стартовый
    # диск целиком накрёван городским обзором и «исследовано, но не видно» не
    # возникает ни в одном состоянии).
    assert memory["memory_cells"] > 0, (
        f"в состоянии «память» нет ни одной исследованной невидимой клетки "
        f"(explored {memory['explored']} == visible {memory['visible']}): фикстура "
        "не создаёт слой памяти тумана, проверять нечего"
    )

    res = mcp.execute_code(_COMPARE)
    assert res.get("ok") is True, f"кадры не сравнились: {res}"
    void_share = res["void_never"] / float(res["pixels"])
    print(f"размеры: never exp/vis {never['explored']}/{never['visible']}, "
          f"memory {memory['explored']}/{memory['visible']}, "
          f"bright {bright['explored']}/{bright['visible']}")
    print(f"кадр {res['frame']}, фон {res['void']}; пустого в N {void_share:.2f}; "
          f"клеток памяти {memory['memory_cells']}; пикселей различия N↔M "
          f"{res['diff']}, из них темнее яркого кадра {res['darker']}")

    assert void_share >= MIN_VOID_SHARE, (
        f"в кадре «памяти нет» лишь {void_share:.2f} пустого фона: кадр заполнен "
        "картой, тумана в кадре нет и проверка ничего не утверждает"
    )
    assert res["diff"] >= MIN_MEMORY_PIXELS, (
        f"кадры «памяти нет» и «память есть» совпали ({res['diff']} пикселей "
        f"различия при {memory['memory_cells']} клетках памяти): исследованная и "
        "одновременно невидимая земля не нарисована — туман отступил в пустоту, "
        "и память о ней не видна (T-168)"
    )
    dark_share = res["darker"] / float(res["diff"])
    assert dark_share >= MIN_DARKENED_SHARE, (
        f"из {res['diff']} пикселей памяти только {res['darker']} темнее яркого "
        f"кадра ({dark_share:.2f}): память рисуется, но не затемнением "
        "`GameNumbers.MAP_FOG_DIM`, а чем-то ещё (T-168)"
    )
