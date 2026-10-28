"""Кадр-ловушка T-228: пластина подсказки К-6 дорисовывается живым наведением.

Гарды `tests/unit/ui/test_kitchen_sink_theme_carrier.gd` и
`tests/unit/ui/test_theme_source_scan.gd` доказывают модель: секция `TooltipPanel`
читается движком, витрина §4.8 надевает пластину и подпись подсказки, мёртвых
литералов `theme_type_variation` в источниках нет. Модель — ещё не кадр: срез
начинался с правки, которая «по модели» была гигиеной, а на кадре снимала золотую
рамку с единственного места, где К-6 виден (замер до/после — 7330 отличающихся
пикселей). Этот тест закрывает ровно дыру модели: подсказка §4.8 вызывается
**настоящим событием мыши** в живом Godot, и в кадре ищется подпись, которую нарисовал
движок.

Три заимствованных урока (обе — замеры, не гипотезы):

1. `Input.warp_mouse` не использовать: он идёт в оконную систему, а Xvfb гейта может
   быть 1024×768 при окне 1920×1080 (координата уходит за экран, настоящее событие
   мыши снимает наведение). `Input.parse_input_event` живёт в движке (D-252).
2. Состояние hover читается только следующим кадром, поэтому «наведён» проверяется
   отдельным зондом после ожидания, а не в том же вызове.
3. Таймер показа подсказки не ускоряется (синглтона `GUI` в этой сборке нет): между
   наведением и кадром — 1.6 с реального времени и 30 кадров, иначе кадр был бы
   зелёным враньём.

Текст подсказки выбран так, чтобы не совпадать с подписью на самой пластине
(«Значение: 60 (TooltipLabel)») — точное совпадение с `tooltip_text` оставляет ровно
один кандидат: подпись, нарисованную подсказкой.

Пиксели в git не идут (D-185): PNG и MANIFEST.md пишутся в
`~/.local/share/sigil-reserve/theme-t228/`.
"""

from __future__ import annotations

import time
from typing import Any

import capture

SCENE = "res://scenes/ui/kitchen_sink.tscn"
OUT_NAME = "theme-t228"
FRAME_NAME = "tooltip_hover"

TOOLTIP_TEXT = "Значение: 60"

# Наведение на панель §4.8 — единственную, у которой в витрине стоит и пластина
# TooltipPanel, и настоящий tooltip_text (подпись «TooltipLabel» сидит внутри неё).
HOVER_CODE = f"""
var scene: Node = get_tree().current_scene
if scene == null:
    return {{"ok": false, "reason": "нет текущей сцены"}}
var plate: Control = null
var stack: Array = [scene]
while not stack.is_empty():
    var n: Node = stack.pop_back()
    for c in n.get_children():
        stack.append(c)
        if c is Control and (c as Control).tooltip_text == "{TOOLTIP_TEXT}":
            plate = c as Control
if plate == null:
    return {{"ok": false, "reason": "узла с tooltip_text=\\u00ab{TOOLTIP_TEXT}\\u00bb в витрине нет"}}
var center: Vector2 = plate.get_global_rect().get_center()
var motion := InputEventMouseMotion.new()
motion.position = center
motion.global_position = center
Input.parse_input_event(motion)
return {{
    "ok": true,
    "at": str(center),
    "screen": str(DisplayServer.screen_get_size()),
    "plate_path": str(plate.get_path()),
    "plate_variation": String(plate.theme_type_variation),
    "viewport_rect": str(plate.get_global_rect()),
}}
"""

# Зонд идёт ПОСЛЕ ожидания: hover читается только следующим кадром. Подсказка ищется
# как видимая подпись с точным текстом tooltip_text; `is_on_screen()` на подписи внутри
# тултипа роняет процесс (замер D-252), поэтому только `.visible`, а «попало на экран»
# доказывает кадр.
PROBE_CODE = f"""
var want: String = "{TOOLTIP_TEXT}"
var hovered: Control = get_tree().root.gui_get_hovered_control()
var labels: Array = []
var plates: Array = []
var stack: Array = [get_tree().root]
while not stack.is_empty():
    var n: Node = stack.pop_back()
    for c in n.get_children():
        stack.append(c)
        if c is Label and (c as Label).text == want and (c as CanvasItem).visible:
            labels.append(str(c.get_path()))
        if c is Control and (c as Control).tooltip_text == want:
            plates.append(str(c.get_path()))
return {{
    "tooltip_labels": labels,
    "tooltip_owners": plates,
    "hovered": str(hovered.get_path()) if hovered != null else "ничего",
}}
"""


def test_tooltip_plate_is_drawn_by_real_hover(mcp: Any) -> None:
    size = capture.canonical_size()
    mcp.run_scene(SCENE)
    mcp.wait_ready()
    mcp.wait_frames(20)
    mcp.execute_code(capture.pin_window_code(size))
    mcp.wait_frames(30)

    hover = mcp.execute_code(HOVER_CODE)
    assert hover.get("ok") is True, f"наведение не удалось: {hover}"
    assert hover["plate_variation"] == "TooltipPanel", (
        f"у узла подсказки снят носитель пластины (§4.8, К-6): "
        f"theme_type_variation = {hover['plate_variation']!r}"
    )

    time.sleep(1.6)
    mcp.wait_frames(30)

    probe = mcp.execute_code(PROBE_CODE) or {}
    assert probe.get("hovered") == hover["plate_path"], (
        f"событие мыши не попало на пластину (наведён: {probe.get('hovered')!r}, ждали "
        f"{hover['plate_path']!r}, экран {hover['screen']}, геометрия "
        f"{hover['viewport_rect']}) — без настоящего наведения кадр ничего не доказывает"
    )
    labels = probe.get("tooltip_labels", [])
    assert len(labels) == 1, (
        f"подсказка не дорисовалась до кадра (ожидась 1 видимая подпись с текстом "
        f"{TOOLTIP_TEXT!r}, найдено {labels}); наведён: {probe.get('hovered')!r}, "
        f"зонд вернул: {probe}"
    )

    mcp.screenshot()  # прайм: первый после пина снимок отдаёт устаревшую текстуру
    mcp.wait_frames(5)
    raw = mcp.screenshot()
    actual = capture.verify_frame(raw, size)
    out_dir = capture.reserve_dir(OUT_NAME)
    path = out_dir / f"{FRAME_NAME}.png"
    path.write_bytes(raw)

    row = {
        "file": path.name,
        "state": "наведение на пластину §4.8 (TooltipPanel + tooltip_text)",
        "size": actual,
        "bytes": len(raw),
        "sha256": capture.sha256_hex(raw),
        "path": path,
    }
    meta = capture.manifest_meta(
        title="Пластина подсказки К-6 на живом наведении (T-228)",
        fixture=SCENE,
        size=size,
        command=(
            "DISPLAY=:96 MCP_PORT=9477 pytest tests/mcp/test_tooltip_plate_hover.py "
            "-q --timeout=900 (номер дисплея и порт воркера берутся из окружения гейта)"
        ),
        notes=[
            "Наведение — настоящее событие мыши (Input.parse_input_event), не "
            "нарисованная вручную пластина и не notification() изнутри движка.",
            f"Подсказка найдена в дереве как видимая подпись: {labels[0]}",
            f"Отчёт наведения: {hover}",
            "Таймер показа подсказки не ускорялся: между наведением и кадром 1.6 с "
            "реального времени и 30 кадров.",
        ],
    )
    with (out_dir / "MANIFEST.md").open("a", encoding="utf-8") as fh:
        fh.write(capture.render_manifest(meta, [row]) + "\n")
    print(f"CAPTURED {row['path']} {row['size']} {row['sha256']}", flush=True)
