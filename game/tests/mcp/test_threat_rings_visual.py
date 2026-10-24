"""world-map-art-variety 8.3: носители тиров на живом снимке карты.

Что проверяется (spec `world-threat-rings` → «Визуальный носитель тира»): на
отрисованном кадре мира три кольца угрозы дают измеримо разные пиксели, а смена
тира меняет носитель того же стэка.

Почему мера считается в движке, а не в pytest: в MCP-venv намеренно нет
PNG-декоратора (`capture.py` читает только IHDR), а сравнение трёх колец
выполняется внутри одного кадра — канонический размер для него не нужен (он введён
для «до/после»). PNG снимка при этом пишется в резерв с манифестом: кадр остаётся
доказательством, а не строкой в отчёте. `verify_frame` здесь сознательно не
вызывается: run_tests.sh поднимает Xvfb 1024×768, где канон 1920×1080 недостижим,
а сравниваются не два прогона, а три окна одного кадра.
"""

from __future__ import annotations

import hashlib

import capture
import pytest

pytestmark = pytest.mark.timeout(900)

RESERVE = "threat-rings"

## Порог вклада носителя в окно (средний тон кадра с носителем минус тот же кадр
## без него), единицы RGB 0..255. Без этой проверки «различие колец» можно померить
## на ландшафте: окно тогда просто накрывает другую траву.
##
## Калибровка 2026-10-23 (seed фикстуры, стэки `goblins`, три клетки в одном кадре):
## вклад колец 16.6 / 5.4 / 9.9 — худшее кольцо 2 даёт 5.4 (его силуэт заполнен на
## 0.16, остальное прозрачность листа); окно, целиком лежащее на траве, давало не
## больше 1.9. Порог 3.0 — между этими двумя наблюдениями.
MIN_CARRIER_PRESENCE = 3.0

## Порог различия вкладов смежных колец, единицы RGB 0..255. Ниже листного порога
## юнит-теста (20.0 по чистым пикселям листа), потому что окно кадра содержит ещё
## портрет и ландшафт: калибровка 2026-10-23 дала 11.9 (1↔2), 13.5 (2↔3), 25.3
## (1↔3) и 22.8 на смене тира того же стэка. Порог 6.0 — половина худшей пары.
MIN_SCREEN_DELTA = 6.0

## Три стэка набираются одним юнитом: портрет во всех трёх окнах одинаков, и
## различие средних тонов остаётся свойством носителя, а не картинки отряда.
UNIT_KEY = "goblins"

_SETUP = """
var world = get_tree().current_scene
var map = world.get_map_gen()
var spawner = world.get_node("WorldSpawner")
var mov = world.get_hero().get_component("Movement")
var raw: Dictionary = mov.serialize()["cell"]
var hero_cell: Vector2i = Vector2i(int(raw["x"]), int(raw["y"]))
var cities = world.get_cities()
var fog = world.get_fog()
# Кандидаты ищутся вокруг текущего взгляда камеры, а не вокруг героя: камера мира
# прижата к границе карты (`_clamp_position`), и клетки у её левого края просто не
# попадают в кадр (замер 2026-10-23: герой в (0,0), окно носителя (-78,-79)).
var cam: Camera2D = world.get_camera()
var h: Vector2i = map.local_to_map(cam.get_screen_center_position())
var picked: Array[Vector2i] = []
for radius in [1, 2, 3, 4, 5, 6]:
    if picked.size() >= 3:
        break
    for c in HexUtils.ring(h, radius):
        if picked.size() >= 3:
            break
        if not map.is_walkable(c) or map.resource_cells.has(c) \\
                or map.enemy_stacks.has(c) or cities.city_at(c) != null:
            continue
        var busy := false
        for v in map.village_cells:
            if v == c:
                busy = true
        for p in picked:
            if HexUtils.hex_distance(c, p) < 3:
                busy = true
        if not busy:
            picked.append(c)
if picked.size() < 3:
    return {"ready": false, "reason": "свободных клеток в поле зрения камеры: " + str(picked.size())}
var reg: Node = Services.resolve(&"units")
var rng := RandomNumberGenerator.new()
rng.seed = 11
var tiers: Array = [MapThreat.RING_WILD, MapThreat.RING_RAIDERS, MapThreat.RING_MONSTERS]
for i in picked.size():
    var c: Vector2i = picked[i]
    map.model.enemy_stacks[c] = [reg.make_stack("__UNIT__", rng, 1.0)]
    map.model.enemy_tiers[c] = int(tiers[i])
# Туман пересчитывается вызовом, а не прикосновением к клеткам. Прежний
# `fog.visible[c] = fog.explored[c] = 1` рисовал клетку-одиночку среди серого
# фона — состояние, которого игра производить не умеет (обзор это диск), и кадр
# «носитель рядом с пустотой» был доказательством несуществующей ситуации.
# Теперь легальный recompute: радиус считается до дальнего стэка, чтобы все три
# окна попали в исследованное, города — те же источники, что у бутстрапа.
var fog_legal := true
var fog_state := [0, 0]
if fog != null:
    var need := 0
    for pc in picked:
        need = maxi(need, HexUtils.hex_distance(hero_cell, pc))
    var sources: Array = []
    for city in cities.cities:
        if city != null and city.owner == &"player" and city.center is Vector2i:
            sources.append(city.center)
    fog.recompute(hero_cell, sources, need + 2, GameNumbers.FOG_CITY_SIGHT)
    if map.has_valid_tilemap():
        map.apply_fog(fog)
    for pc in picked:
        for n in HexUtils.core_cells(pc):
            if not fog.is_explored(n):
                fog_legal = false
    fog_state = [fog.explored.size(), fog.visible.size()]
spawner.respawn_enemies()
# Кадр обязан быть неподвижным: замеры «с носителем» и «без носителя» вычитаются,
# и сдвиг камеры между ними обнуляет вычитание. Движут камеру мира два независимых
# механизма: скролл от курсора у края экрана (под Xvfb курсор стоит в (0,0)) и
# сглаживание позиции камеры — за 30 кадров `get_canvas_transform()` ушёл на 4.6 px
# при НЕПОДВИЖНОЙ `position` (замер 2026-10-23), поэтому `set_process(false)`
# недостаточно. Отсюда: поставить камеру на средний стэк, выключить её `_process`
# (тест меряет пиксели, а не управление камерой) и сбросить сглаживание.
world.center_camera_on(picked[1])
cam.set_process(false)
cam.reset_smoothing()
cam.force_update_scroll()
var cells: Array = []
for c in picked:
    cells.append({"x": c.x, "y": c.y})
return {"ready": true, "hero": {"x": hero_cell.x, "y": hero_cell.y}, "cells": cells, \\
    "tiers": tiers, "fog": fog != null, "fog_legal": fog_legal, "fog_state": fog_state, \\
    "camera": [cam.position.x, cam.position.y], \\
    "viewport": [world.get_viewport().get_visible_rect().size.x, \\
        world.get_viewport().get_visible_rect().size.y]}
""".replace("__UNIT__", UNIT_KEY)

# Замер по кадру вьюпорта. Окно = фактический прямоугольник носителя, приведённый
# к пикселям кадра: мировая трансформация узла → `Camera2D.get_canvas_transform()`
# (координаты вьюпорта) → масштаб контента `кадр / visible_rect`.
#
# Калибровки, каждая из которых стоила тесту красного прогона (T-160):
#   1. `Camera2D.get_screen_transform()` даёт координаты ОКНА, а снимок — кадр
#      вьюпорта (замер 2026-10-23: при окне 1024×768 и вьюпорте 1920×1080 окна
#      уезжали, а «различие колец» оказывалось различием травы);
#   2. `get_global_transform_with_canvas()` учитывает сдвиг камеры ЗАДВОЙНО
#      (замер 2026-10-23: окно уехало на 188 px, вклад носителя стал 0);
#   3. координаты вьюпорта ≠ пиксели кадра, когда проекция `window/stretch/mode =
#      canvas_items` даёт content_scale ≠ 1 (замер 2026-10-24, T-160): при базовом
#      вьюпорте 960×540 и кадре 1920×1080 окно без поправки попадало в траву, а
#      вклад носителя был ровно 0.0; при чужом окне 1900×1007 (k ≈ 0.99, сдвиг
#      ~10 px при носителе 82 px) вклад кольца 2 падал 5.4 → 2.91 при пороге 3.0.
#      На машине, где окно равно базовому вьюпорту, k = 1 и тест зелёный — этим
#      он и врал.
_MEASURE = """
var world = get_tree().current_scene
var spawner = world.get_node("WorldSpawner")
var img: Image = world.get_viewport().get_texture().get_image()
var cam: Camera2D = world.get_viewport().get_camera_2d()
if cam == null:
    return {"error": "камеры мира нет"}
# Пиксели кадра = координаты вьюпорта × content-scale. `get_visible_rect().size` —
# логический вьюпорт, `img` — снимок окна; при stretch=canvas_items они различаются.
var vp_size: Vector2 = world.get_viewport().get_visible_rect().size
var scale := Vector2(float(img.get_width()) / vp_size.x, float(img.get_height()) / vp_size.y)
var cam_xform: Transform2D = cam.get_canvas_transform()
var out: Array = []
var want: Array = __WANT__
for entry in want:
    var cell := Vector2i(int(entry["x"]), int(entry["y"]))
    var node = spawner._enemy_nodes.get(cell)
    if node == null:
        return {"error": "узла стэка нет: " + str(cell), "want": str(want)}
    var back = node.get_node_or_null("Backing")
    if back == null:
        return {"error": "носителя нет: " + str(cell)}
    var g: Transform2D = back.get_global_transform()
    var lr: Rect2 = back.get_rect()
    var p0: Vector2 = (cam_xform * (g * lr.position)) * scale
    var p1: Vector2 = (cam_xform * (g * lr.end)) * scale
    var r := Rect2i(int(p0.x), int(p0.y), int(p1.x - p0.x), int(p1.y - p0.y))
    # Окно отсекается по кадру, а не отбрасывается: оба замера («с носителем» и
    # «без») берут ОДНО и то же окно, поэтому частичное попадание в кадр не портит
    # вычитание фона — важен только пересек с кадром.
    var frame_rect := Rect2i(0, 0, img.get_width(), img.get_height())
    var clip: Rect2i = r.intersection(frame_rect)
    if clip.size.x < 16 or clip.size.y < 16:
        return {"error": "окно носителя почти целиком за кадром " + str(r) + " при кадре " \\
            + str(img.get_width()) + "x" + str(img.get_height())}
    var crop: Image = img.get_region(clip)
    var sum := Vector3.ZERO
    for y in crop.get_height():
        for x in crop.get_width():
            var p: Color = crop.get_pixel(x, y)
            sum += Vector3(p.r, p.g, p.b) * 255.0
    var n := float(clip.size.x * clip.size.y)
    out.append({
        "cell": [cell.x, cell.y], "ring": int(entry["ring"]),
        "rect": [clip.position.x, clip.position.y, clip.size.x, clip.size.y],
        "world": [g.origin.x, g.origin.y],
        "shown": back.is_visible_in_tree(),
        "mean": [sum.x / n, sum.y / n, sum.z / n],
    })
return {"frame": [img.get_width(), img.get_height()], "samples": out, \\
    "viewport": [vp_size.x, vp_size.y], "scale": [scale.x, scale.y], \\
    "camera": [cam.position.x, cam.position.y]}
"""

# Вкл/выкл самих носителей: та же сцена, тот же кадр, минус один слой. Разница
# средних «с носителем» и «без носителя» — вклад носителя в окно; без неё мера
# различия колец не отличалась бы от различия клеток ландшафта под стэками.
_SET_BACKS = """
var world = get_tree().current_scene
var spawner = world.get_node("WorldSpawner")
var want: Array = __WANT__
for entry in want:
    var cell := Vector2i(int(entry["x"]), int(entry["y"]))
    var node = spawner._enemy_nodes.get(cell)
    if node == null:
        return {"error": "узла стэка нет: " + str(cell)}
    var back = node.get_node_or_null("Backing")
    if back == null:
        return {"error": "носителя нет: " + str(cell)}
    back.visible = __ON__
return {"ok": true}
"""


def _setup(mcp) -> dict:
    r = mcp.execute_code(_SETUP)
    assert r.get("ready") is True, f"мир не готов к съёмке колец: {r}"
    # Кадр-доказательство обязан снимать состояние, которое игра умеет
    # производить: вокруг каждого стэка исследовано всё соседство, а не одна
    # клетка (иначе «носитель рядом с пустотой» — артефакт фикстуры, T-165).
    assert r.get("fog_legal") is True, (
        f"фикстура нарисовала нелегальный туман: исследовано {r.get('fog_state')}, "
        "у какого-то стэка есть неисследованный сосед"
    )
    return r


def _measure(mcp, cells: list[dict]) -> dict:
    r = mcp.execute_code(_MEASURE.replace("__WANT__", repr(cells)))
    assert "error" not in r, f"замер по кадру не удался: {r}"
    assert len(r["samples"]) == len(cells), r
    return r


def _camera_of(frame: dict) -> list:
    return frame.get("camera", [])


def _set_backs(mcp, cells: list[dict], on: bool) -> None:
    r = mcp.execute_code(
        _SET_BACKS.replace("__WANT__", repr(cells)).replace("__ON__", "true" if on else "false")
    )
    assert r.get("ok") is True, r


def _measure_with_background(mcp, cells: list[dict]) -> tuple[dict, dict]:
    """Замер «с носителями» и тот же кадр без них; носители включаются обратно.

    Кадр обязан быть неподвижным: вычитание фона имеет смысл только если два замера
    отличаются слоем носителя, а не позицией камеры (скролл от курсора у края).
    """
    with_carriers = _measure(mcp, cells)
    assert all(s["shown"] for s in with_carriers["samples"]), with_carriers
    _set_backs(mcp, cells, False)
    mcp.wait_frames(6)
    without = _measure(mcp, cells)
    assert not any(s["shown"] for s in without["samples"]), without
    assert _camera_of(without) == _camera_of(with_carriers), (
        f"камера сдвинулась между замерами: {_camera_of(with_carriers)} → "
        f"{_camera_of(without)} — кадр нестатичен, вычитание фона недействительно"
    )
    # Окна обязаны совпасть с точностью растра: иначе вычитание сравнивает разные
    # пиксели. Допуск в 2 px — субпиксельный дрейф сглаживания, а не движение мира.
    for a, b in zip(with_carriers["samples"], without["samples"]):
        drift = max(abs(a["rect"][0] - b["rect"][0]), abs(a["rect"][1] - b["rect"][1]))
        assert drift <= 2, (
            f"окно носителя уехало между замерами на {drift} px "
            f"({a['rect']} → {b['rect']}) — кадр нестатичен, вычитание фона "
            "недействительно"
        )
    _set_backs(mcp, cells, True)
    mcp.wait_frames(6)
    return with_carriers, without


def _sample(frame: dict, ring: int) -> dict:
    for s in frame["samples"]:
        if int(s["ring"]) == ring:
            return s
    raise AssertionError(f"кольца {ring} нет в замере: {frame}")


def _distance(a: list, b: list) -> float:
    return sum((float(a[i]) - float(b[i])) ** 2 for i in range(3)) ** 0.5


def _contribution(with_carriers: dict, without: dict, ring: int) -> list[float]:
    """Вклад носителя в окно: средний тон кадра минус тот же кадр без носителя."""
    a = _sample(with_carriers, ring)["mean"]
    b = _sample(without, ring)["mean"]
    return [float(a[i]) - float(b[i]) for i in range(3)]


def _reserve(tag: str) -> Path:
    """Резервный каталог теста: `threat-rings/<тест>`. Один каталог = один
    `MANIFEST.md`, иначе второй тест этого файла молча перезаписал бы манифест
    первого, и под снимком лежал бы чужой протокол замера."""
    return capture.reserve_dir(f"{RESERVE}/{tag}")


def _save_frame(mcp, tag: str, name: str, state: str, rows: list[dict]) -> tuple[int, int]:
    raw = mcp.screenshot()
    out = _reserve(tag) / f"{name}.png"
    out.write_bytes(raw)
    size = capture.png_size(raw)
    rows.append({
        "file": out.name, "state": state, "size": size,
        "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
    })
    return size


def _write_manifest(tag: str, fixture: str, size: tuple[int, int],
                    rows: list[dict], notes: list[str]) -> Path:
    meta = capture.manifest_meta(
        "Носители тиров угрозы — живой кадр карты",
        fixture,
        size,
        "game/run_tests.sh (MCP e2e) · pytest game/tests/mcp/test_threat_rings_visual.py",
        notes=notes,
        comparison_valid="да (три окна одного кадра; канон размера для этого не нужен)",
    )
    path = _reserve(tag) / "MANIFEST.md"
    path.write_text(capture.render_manifest(meta, rows), encoding="utf-8")
    return path


def test_three_rings_differ_on_map_screenshot(full_game):
    """Снимок карты с тремя кольцами: вклад носителя в кадр различим по парам."""
    mcp = full_game
    setup = _setup(mcp)
    mcp.wait_frames(40)  # кадр после бутстрапа и respawn обязан успеть отрисоваться
    cells = [{"x": c["x"], "y": c["y"], "ring": t}
             for c, t in zip(setup["cells"], setup["tiers"])]
    rows: list[dict] = []
    size = _save_frame(mcp, "three", "threat_rings_three", "три кольца на карте", rows)
    frame, bare = _measure_with_background(mcp, cells)
    _write_manifest("three", f"world.tscn (fixture full_game), стэки {UNIT_KEY} с тирами 1/2/3",
                    size, rows, [
        "окно замера = прямоугольник носителя в пикселях кадра (координаты вьюпорта "
        f"× content-scale; кадр {frame['frame']}, вьюпорт {frame.get('viewport')}, "
        f"scale {[round(float(v), 4) for v in frame.get('scale', [])]})",
        "вклад носителя = окно с носителем минус тот же кадр без носителя",
        f"портрет отряда во всех окнах одинаков ({UNIT_KEY}), различие даёт носитель",
    ])

    zero = [0.0, 0.0, 0.0]
    contributions: dict[int, list[float]] = {}
    for ring in (1, 2, 3):
        contributions[ring] = _contribution(frame, bare, ring)
        own = _distance(contributions[ring], zero)
        assert own >= MIN_CARRIER_PRESENCE, (
            f"кольцо {ring}: окно {_sample(frame, ring)['rect']} кадра "
            f"{frame['frame']} не накрывает носитель — вклад {own:.1f} < "
            f"{MIN_CARRIER_PRESENCE}. Геометрия: вьюпорт {frame.get('viewport')}, "
            f"content-scale {[round(v, 4) for v in frame.get('scale', [])]} "
            f"(окно без поправки на него = уехавшее окно). Окно меряет ландшафт, "
            "и любое «различие колец» под таким окном — ложь."
        )

    for pair in [(1, 2), (2, 3)]:
        ci, cj = contributions[pair[0]], contributions[pair[1]]
        delta = _distance(ci, cj)
        assert delta >= MIN_SCREEN_DELTA, (
            f"кольца {pair[0]}→{pair[1]} на кадре {frame['frame']} неразличимы: "
            f"вклады {[round(v, 1) for v in ci]} vs {[round(v, 1) for v in cj]}, "
            f"мера {delta:.1f} < {MIN_SCREEN_DELTA} (окна "
            f"{_sample(frame, pair[0])['rect']} и {_sample(frame, pair[1])['rect']}, "
            f"герой {setup['hero']})"
        )


_SET_SCALE = """
var win: Window = get_tree().root.get_window()
win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
win.content_scale_size = Vector2i(__W__, __H__)
await Engine.get_main_loop().process_frame
var vp: Vector2 = get_tree().root.get_visible_rect().size
return {"viewport": [vp.x, vp.y]}
"""


def test_carrier_measure_survives_content_scale(full_game):
    """Мера окна не зависит от content-scale (T-160).

    На машине, где окно равно базовому вьюпорту, `кадр / visible_rect` = 1, и
    забытый масштаб не виден: тест зелёный, а на чужом окне 1900×1007 вклад
    кольца падает 5.4 → 2.91 при пороге 3.0. Поэтому окно специально делается
    не-единичным: вклад носителя обязан остаться выше порога.
    """
    mcp = full_game
    setup = _setup(mcp)
    mcp.wait_frames(40)
    cells = [{"x": c["x"], "y": c["y"], "ring": t}
             for c, t in zip(setup["cells"], setup["tiers"])]
    try:
        geo = mcp.execute_code(_SET_SCALE.replace("__W__", "960").replace("__H__", "540"))
        mcp.wait_frames(40)
        frame, bare = _measure_with_background(mcp, cells)
        vw, vh = frame.get("viewport", [0, 0])
        fw, fh = frame["frame"]
        real = (fw / float(vw)) if vw else 1.0
        assert abs(real - 1.0) > 0.5, (
            f"content-scale не сдвинулся: кадр {frame['frame']} / вьюпорт "
            f"{frame.get('viewport')} = {real:.3f} ({geo}) — проверка ничего не "
            "проверяет"
        )
        for ring in (1, 2, 3):
            own = _distance(_contribution(frame, bare, ring), [0.0, 0.0, 0.0])
            assert own >= MIN_CARRIER_PRESENCE, (
                f"кольцо {ring} при content-scale {real:.3f} (кадр {frame['frame']}, "
                f"вьюпорт {frame.get('viewport')}) не накрыто окном: вклад "
                f"{own:.1f} < {MIN_CARRIER_PRESENCE} — окно считается без поправки "
                "на масштаб контента"
            )
    finally:
        mcp.execute_code(_SET_SCALE.replace("__W__", "1920").replace("__H__", "1080"))
        mcp.wait_frames(20)


def test_tier_change_changes_carrier(full_game):
    """Смена тира того же стэка меняет носитель на кадре (портрет не меняется)."""
    mcp = full_game
    setup = _setup(mcp)
    mcp.wait_frames(40)
    cell = setup["cells"][0]
    one = [{"x": cell["x"], "y": cell["y"], "ring": 1}]
    before_with, before_bare = _measure_with_background(mcp, one)

    r = mcp.execute_code(
        "var world = get_tree().current_scene\n"
        "var map = world.get_map_gen()\n"
        f"var cell := Vector2i({cell['x']}, {cell['y']})\n"
        "map.model.enemy_tiers[cell] = MapThreat.RING_MONSTERS\n"
        'world.get_node("WorldSpawner").respawn_enemies()\n'
        "return int(map.model.enemy_tiers[cell])\n"
    )
    assert r == 3, r
    mcp.wait_frames(40)
    three = [{"x": cell["x"], "y": cell["y"], "ring": 3}]
    after_with, after_bare = _measure_with_background(mcp, three)

    rows: list[dict] = []
    size = _save_frame(mcp, "retier", "threat_rings_retier", "тот же стэк, тир 1 → 3", rows)
    _write_manifest("retier", f"world.tscn (fixture full_game), стэк {UNIT_KEY}, тир 1 → 3",
                    size, rows,
                    ["один и тот же стэк и юнит, изменён только записанный тир"])

    before = _contribution(before_with, before_bare, 1)
    after = _contribution(after_with, after_bare, 3)
    own = _distance(after, [0.0, 0.0, 0.0])
    assert own >= MIN_CARRIER_PRESENCE, (
        f"после смены тира окно не накрывает носитель (вклад {own:.1f})"
    )
    delta = _distance(before, after)
    assert delta >= MIN_SCREEN_DELTA, (
        f"носитель не последовал за тиром: вклад {[round(v, 1) for v in before]} → "
        f"{[round(v, 1) for v in after]}, мера {delta:.1f} < {MIN_SCREEN_DELTA}"
    )
