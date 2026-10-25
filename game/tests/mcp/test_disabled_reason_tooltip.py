"""Визуальный гейт D-252: подсказка-причина выключенного пункта дорисовывается до пикселей.

GdUnit-тест `tests/functional/ui/test_disabled_controls_explain.gd` сверяет текст в
`tooltip_text` — это доказательство только модели: Godot вправе не показывать подсказку
у **выключенной** кнопки (у `disabled` свои правила мыши), и тогда вся конструкция
«причина на месте» осталась бы строкой в свойстве, а игрок видел бы по-прежнему серую
плиту. Кадр здесь — из живого Godot через MCP: наведение настоящее
(`Input.parse_input_event`, одно синтетическое движение мыши), подсказка ищется в дереве
как видимая `Label` с текстом причины и попадает в PNG.

Задержка показа тултипа в этой сборке Godot из GDScript не регулируется (синглтона `GUI`
в `Engine.get_singleton_list()` нет — только OS/IP/Input/DisplayServer), поэтому между
наведением и кадром живёт реальное ожидание в 1.6 с + 30 кадров, а не `capture_scene` с
его праймом в 5 кадров: за 5 кадров таймер подсказки (1 с по умолчанию) не срабатывает,
и кадр был бы зелёным враньём.

Пиксели в git не идут (D-185): PNG и MANIFEST.md пишутся в
`~/.local/share/sigil-reserve/menu-tooltip-d252/`.

Три мины этой сборки Godot, на которые наткнулся зонд (все — не гипотезы, а замеры
2026-10-25 на двух Xvfb: :96 1920×1080 и :94 1024×768):

1. `Input.warp_mouse` ломает наведение, а не чинит его. Он идёт в оконную систему,
   Xvfb гейта — 1024×768 (run_tests.sh) при окне 1920×1080, координата кнопки (1592, 632)
   за экраном; курсор прижимается к (1023, 632), настоящее событие мыши прилетает после
   синтетического и наводит на `Background`. Замер: parse → hovered=ContinueButton,
   parse+warp → hovered=Background. Отсюда красные 2 теста в первом же прогоне гейта.
2. Состояние hover нельзя читать в том же вызове, что и событие: `parse_input_event`
   ставит его только следующим кадром. Проверка «наведён» переехала в зонд, который
   идёт после ожидания, и красной строкой называет экран — иначе «мышь не там»
   неотличимо от «подсказки нет».
3. `CanvasItem.is_on_screen()` на подписи внутри тултипа роняет процесс
   (`eval failed: Connection closed`, 2/2 падения; тот же обход с `.visible` — 3/3
   зелёных). Поэтому здесь `.visible`, а «попало на экран» доказывает кадр (T-203).
   Заодно в 4.7 нет `Viewport.gui_get_hovered` и `Input.get_mouse_position` —
   есть `gui_get_hovered_control()`.
"""

from __future__ import annotations

import time
from typing import Any

import capture

SCENE = "res://scenes/main_menu.tscn"
OUT_NAME = "menu-tooltip-d252"
FRAME_NAME = "menu_continue_hover"

# Наведение на «Продолжить» — выключенный пункт (сейва нет) с причиной из D-252.
#
# `Input.warp_mouse` здесь НЕЛЬЗЯ: он идёт в оконную систему, а гейт поднимает Xvfb
# 1024×768 (run_tests.sh) при кадре 1920×1080 — координата кнопки (1592, 632) за экраном,
# Xvfb её прижимает, настоящее событие мыши прилетает ПОСЛЕ синтетического и снимает
# наведение. Замер 2026-10-25: на :96 (1920×1080) тест зелёный, на :94 (1024×768) —
# краснеет с пустым списком подсказок. `parse_input_event` живёт в самом движке и
# координат окна не касается, поэтому hover ставится только им.
HOVER_CODE = """
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var button: Button = scene.get_node_or_null("RightColumn/ContinueButton") as Button
if button == null:
	return {"ok": false, "reason": "кнопки «Продолжить» на меню нет"}
var center: Vector2 = button.get_global_rect().get_center()
var motion := InputEventMouseMotion.new()
motion.position = center
motion.global_position = center
Input.parse_input_event(motion)
# Намеренно НЕ читаем hover здесь: `parse_input_event` ставит его только на следующем
# кадре, а мышиные API в этой сборкене дают прочесть состояние в этом же вызове (замер: «ничего» при живом наведении кадром позже)
return {
	"ok": true,
	"disabled": button.disabled,
	"reason_text": button.tooltip_text,
	"canon_text": GameText.menu_continue_unavailable(),
	"at": str(center),
	"screen": str(DisplayServer.screen_get_size()),
	"viewport_mouse": str(get_tree().root.get_mouse_position()),
	"button_path": str(button.get_path()),
}
"""

# Подсказка ищется в дереве как видимая и попавшая на экран подпись с текстом причины.
# Формулировка без `continue` и без локальных `var` внутри цикла: код состояния
# компилируется как сниппет, а ошибка компиляции здесь молча отдаёт None (замер).
PROBE_CODE = """
var scene: Node = get_tree().current_scene
var want: String = GameText.menu_continue_unavailable()
var hovered: Control = get_tree().root.gui_get_hovered_control()
var nodes: Array = []
var stack: Array = [get_tree().root]
while not stack.is_empty():
	var n: Node = stack.pop_back()
	for c in n.get_children():
		stack.append(c)
		if c is Label and (c as Label).text == want and (c as CanvasItem).visible:
			nodes.append(str(c.get_path()))
return {"want": want, "tooltip_labels": nodes, "hovered": str(hovered.get_path()) if hovered != null else "ничего"}
"""


def test_disabled_button_tooltip_reaches_the_screen(mcp: Any) -> None:
    size = capture.canonical_size()
    mcp.run_scene(SCENE)
    mcp.wait_ready()
    mcp.wait_frames(20)
    mcp.execute_code(capture.pin_window_code(size))
    mcp.wait_frames(30)

    hover = mcp.execute_code(HOVER_CODE)
    assert hover.get("ok") is True, f"наведение не удалось: {hover}"
    assert hover["disabled"] is True, (
        "«Продолжить» ожидаемо выключена (сейва нет): без выключенного пункта кадр "
        "доказывал бы только то, что подсказки умеют показываться у живых кнопок"
    )
    assert hover["reason_text"] != "", "у выключенного пункта нет причины в tooltip_text"
    assert hover["reason_text"] == hover["canon_text"], (
        f"текст причины разошёс с GameText: {hover['reason_text']!r} ≠ {hover['canon_text']!r}"
    )

    # Реальное ожидание: таймер подсказки не ускоряем (см. докстринг), иначе кадр
    # снимался бы до появления подсказки и оставался зелёным.
    time.sleep(1.6)
    mcp.wait_frames(30)

    probe = mcp.execute_code(PROBE_CODE) or {}
    assert probe.get("hovered") == hover["button_path"], (
        f"событие мыши не попало на кнопку (наведён: {probe.get('hovered')!r}, ждали "
        f"{hover['button_path']!r}, экран {hover['screen']}) — без настоящего наведения "
        "кадр ничего не доказывает"
    )
    labels = probe.get("tooltip_labels", [])
    assert len(labels) == 1, (
        f"подсказка-причина не дорисовалась до экрана (ожидась 1 видимая подпись, "
        f"найдено {labels}); наведён в момент зонда: {probe.get('hovered')!r}, "
        f"текст: {probe.get('want')!r}, зонд вернул: {probe}"
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
        "state": "наведение на выключенное «Продолжить»",
        "size": actual,
        "bytes": len(raw),
        "sha256": capture.sha256_hex(raw),
        "path": path,
    }
    meta = capture.manifest_meta(
        title="Причина выключенного пункта на экране (D-252)",
        fixture=SCENE,
        size=size,
        command=(
            f"DISPLAY=:97 MCP_PORT=9477 pytest tests/mcp/test_disabled_reason_tooltip.py "
            f"-q --timeout=900 (порт X-дисплея и порт воркера берутся из окружения гейта)"
        ),
        notes=[
            "Наведение — настоящее событие мыши (Input.parse_input_event), "
            "не нарисованная подсказка и не notification() изнутри движка.",
            f"Подсказка найдена в дереве как видимая подпись: {labels[0]}",
            f"Отчёт наведения: {hover}",
            "Задержка показа тултипа не уменьшалась: синглтона GUI в этой сборке нет, "
            "между наведением и кадром — 1.6 с реального времени и 30 кадров.",
        ],
    )
    with (out_dir / "MANIFEST.md").open("a", encoding="utf-8") as fh:
        fh.write(capture.render_manifest(meta, [row]) + "\n")
    print(f"CAPTURED {row['path']} {row['size']} {row['sha256']}", flush=True)
