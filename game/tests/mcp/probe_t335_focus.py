"""ЗОНД T-335 (не тест): что именно снимает подсказку и что возвращает её обратно.

Имя файла намеренно не `test_*`: уровень (`pytest tests/mcp/`) его не собирает — он
запускается руками и только по запросу, иначе в каждом прогоне прогона появлялся бы
лишний скип:

    DISPLAY=:97 MCP_PORT=9477 pytest tests/mcp/probe_t335_focus.py -q -s --timeout=900

Симптом (T-335): `hovered` — наша кнопка, а подпись причины (`tooltip_labels`) пуста.
В трекере он числился «многофайловой сессией pytest» и объяснялся неактивным окном.
Ни то ни другое замером не подтвердилось; здесь измерено по фазам, за один запуск:

1. покой — наведение есть, подсказка есть;
2. `WARP` (настоящее `XWarpPointer` по видимой подсказке) + хвост старого теста
   (переведение наведения и два кадра до зонда) — подсказки нет, `hovered` по-прежнему
   наш: **это и есть T-335**, воспроизведённый по требованию, без многофайловой сессии.
   Причина механическая: реальное движение снимает показанную подсказку, а таймер после
   перевыпуска ENTER требует ~1 с, которых в двух кадрах нет;
3. то же движение, то же переведение, но с полным ожиданием (1.6 с) — подсказка есть:
   лечение подтверждено в тех же условиях, что и поломка;
4. чужое окно + `set_input_focus` + настоящее нажатие (XTEST) — X-фокус уходит на чужое
   окно (`X-фокус→0x…`), а `DisplayServer.window_is_focused(0)` продолжает отвечать
   `true`. Гипотеза «неактивное окно» на Xvfb не проверяема и потому мертва, а скип по
   `focused` в тесте — разрыватель только для хоста с настоящим WM.

Кроме фаз, зонд умеет режим «шума» (`--hostile СЕК`): бесконечные настоящие движения
указателя с заданным периодом — тем же X-клиентом, каким фазы 2–4 снимают одно событие.
Им проверяются вердикты «указателем владеет не кто-то другой» (замер 2026-11-04, см.
`capture.pointer_is_moving`).

Почему X-средства, а не внутриигровые: `Input.warp_mouse` ломает наведение (замер
2026-10-25 в докстринге соседа), а `XWarpPointer`/XTEST из отдельного X-клиента — ровно
то, что производит физическая мышь на уровне протокола X, на том же DISPLAY, где живёт
окно Godot. Именно поэтому второй компьютер с настоящим курсором для этого замера не
нужен.

Зависимость — `python-xlib` в venv прогона; без неё зонд скипается с причиной.
"""

from __future__ import annotations

import time
from typing import Any

import pytest

import capture
from test_disabled_reason_tooltip import (
    HOVER_CODE,
    PROBE_CODE,
    REHOVER_CODE,
    SCENE,
)

pytest.importorskip("Xlib", reason="нет python-xlib в venv прогона (зонд T-335)")

# Старое (с HEAD на момент замера) переведение наведения: одно движение на ту же кнопку,
# на которой наведение уже стоит. `NOTIFICATION_MOUSE_ENTER` при этом не перевыпускается.
OLD_REHOVER_CODE = """
var scene: Node = get_tree().current_scene
var button: Button = scene.get_node_or_null("RightColumn/ContinueButton") as Button
if button == null:
	return {"ok": false}
var center: Vector2 = button.get_global_rect().get_center()
var motion := InputEventMouseMotion.new()
motion.position = center
motion.global_position = center
Input.parse_input_event(motion)
return {"ok": true, "at": str(center)}
"""


class _X:
    """Настоящий указатель и чужое окно на том же DISPLAY, где живёт окно Godot."""

    def __init__(self) -> None:
        from Xlib import X, display  # local import: зависимость только у зонда

        self.X = X
        self.d = display.Display()
        self.root = self.d.screen().root
        self.step = 0

    def warp(self) -> str:
        """Одно настоящее перемещение указателя внутри окна — не на кнопку."""
        self.step += 1
        x, y = 480 + 60 * self.step, 380 + 40 * (self.step % 2)
        self.d.warp_pointer(x, y)
        self.d.sync()
        return f"warp#{self.step}→({x},{y})"

    def steal_focus(self) -> str:
        """Чужое окно, `set_input_focus` и настоящее нажатие в него (XTEST).

        Окно живёт до конца процесса: `unmap` вернул бы фокус, и чтение ниже измеряло бы
        возврат, а не потерю.
        """
        X = self.X
        win = self.root.create_window(
            8, 8, 240, 160, 0, self.d.screen().root_depth, X.InputOutput, 0
        )
        win.map()
        self.d.set_input_focus(win, X.RevertToParent, X.CurrentTime)
        self.d.sync()
        self.d.xtest_fake_input(X.ButtonPress, 1)
        self.d.xtest_fake_input(X.ButtonRelease, 1)
        self.d.sync()
        fid = getattr(self.d.get_input_focus().focus, "id", 0)
        return (f"чужое окно {win.id:#x} на {self.d.get_display_name()}, "
                f"X-фокус→{fid:#x} {'OK' if fid == win.id else '!! НЕ наш'}")


def _wait_for_popup(mcp: Any) -> None:
    """Столько же, сколько живой тест отводит на таймер подсказки (1 с) с запасом."""
    time.sleep(1.6)
    mcp.wait_frames(30)
    mcp.wait_frames(2)


def test_t335_probe_tooltip_motion_and_focus(mcp: Any) -> None:
    """Печатает подсказку по фазам: покой / движение + старое наведение / новое / фокус.

    `hovered` во всех фазах обязан остаться нашим — иначе замер уезжает в семейство
    T-281 (наведение потеряно), а не в T-335 (наведение есть, подсказки нет).
    """
    size = capture.canonical_size()
    mcp.run_scene(SCENE)
    mcp.wait_ready()
    mcp.wait_frames(20)
    mcp.execute_code(capture.pin_window_code(size))
    mcp.wait_frames(30)

    hover = mcp.execute_code(HOVER_CODE)
    assert hover.get("ok") is True, f"наведение не удалось: {hover}"
    _wait_for_popup(mcp)
    quiet = mcp.execute_code(PROBE_CODE) or {}

    x = _X()
    moves = []
    # 2: движение по видимой подсказке, затем хвост СТАРОГО теста — переведение
    #    наведения и два кадра до зонда. Таймер подсказки требует ~1 с после ENTER,
    #    поэтому подсказка физически не успевает вернуться: `hovered` наш, подписи нет.
    moves.append(x.warp())
    mcp.execute_code(OLD_REHOVER_CODE)
    mcp.wait_frames(2)
    old = mcp.execute_code(PROBE_CODE) or {}
    # 3: то же движение и то же переведение, но с полным ожиданием таймера — как в
    #    лечении: повтор попытки не «ещё кадрик», а ещё 1.6 с.
    moves.append(x.warp())
    mcp.execute_code(REHOVER_CODE)
    _wait_for_popup(mcp)
    new = mcp.execute_code(PROBE_CODE) or {}
    # 4: чужой X-фокус — проверяем, что поле `focused` его не замечает.
    how_focus = x.steal_focus()
    _wait_for_popup(mcp)
    focus = mcp.execute_code(PROBE_CODE) or {}

    def labels(p: dict) -> str:
        got = p.get("tooltip_labels") or []
        return f"подсказка={'есть' if got else 'НЕТ'} hovered={'наш' if p.get('hovered') == hover['button_path'] else p.get('hovered')} мышь={p.get('mouse')} focused={p.get('focused')}"

    print("T335 PROBE: " + "; ".join(moves) + f"\nT335 PROBE: {how_focus}\n"
          f"T335 PROBE: 1 покой                    {labels(quiet)}\n"
          f"T335 PROBE: 2 движение + старое нав.   {labels(old)}\n"
          f"T335 PROBE: 3 движение + новое нав.    {labels(new)}\n"
          f"T335 PROBE: 4 чужой X-фокус            {labels(focus)}", flush=True)

    assert str(quiet.get("focused")) == "true", (
        f"окно было не в фокусе до зонда ({labels(quiet)}) — переход измерить нельзя"
    )
    assert quiet.get("tooltip_labels"), "в покое подсказки нет — базовая фаза сломана"
    assert not old.get("tooltip_labels"), (
        f"хвост старого теста НЕ потерял подсказку ({labels(old)}) — симптом T-335 здесь "
        "не воспроизведён, вывод о причине менять рано"
    )
    assert old.get("hovered") == hover["button_path"], (
        f"в фазе симптома наведение не наше ({labels(old)}) — это T-281, а не T-335"
    )
    assert new.get("tooltip_labels"), (
        f"двухшаговое наведение НЕ вернуло подсказку ({labels(new)}) — лечение "
        "T-335 не подтверждено"
    )
    assert "!! НЕ наш" not in how_focus, f"X-фокус не перехвачен: {how_focus}"
    assert str(focus.get("focused")) == "true", (
        f"`window_is_focused` всё-таки заметил чужой X-фокус ({labels(focus)}): "
        "на этом DISPLAY скип по фокусу жив, гипотезу T-335 надо перепроверять"
    )


def hostile_loop(period: float) -> None:
    """Бесконечные настоящие движения указателя, раз в `period` секунд. Остановка — Ctrl-C.

    Тот же X-клиент и тот же DISPLAY, что у окна Godot — ровно то, что производит
    физическая мышь на уровне протокола.

        cd game && DISPLAY=:94 python3 tests/mcp/probe_t335_focus.py --hostile 0.7 &
        pytest tests/mcp/test_disabled_reason_tooltip.py -q -s   # ждём skipped, не failed

    Позиция ставится **абсолютно** (`root.warp_pointer`), а не через `_X.warp`: тот зовёт
    `Display.warp_pointer`, которая смещает текущую координату (замер на X-контуре,
    2026-11-04: (960,540) + (300,300) → (1260,840)), и на третьем-четвёртом шаге указатель
    намертво встаёт в угол (1919,1079), где дальнейшие смещения события не производят —
    шум выключался бы сам через ~3 с. Одиночным фазам 2–4 это безразлично (им нужно одно
    движение), генератору шума — нет.

    Период выбирается по симптому: 0.7 с — замеры пользователя (медленные чередования),
    0.3 с — часто (проверка окна выборки `capture.pointer_is_moving`).
    """
    x = _X()
    i = 0
    while True:
        ax, ay = (480, 380) if i % 2 == 0 else (900, 620)
        x.root.warp_pointer(ax, ay)
        x.d.sync()
        i += 1
        print(f"warp#{i}→({ax},{ay})", flush=True)
        time.sleep(period)


if __name__ == "__main__":
    import argparse
    import sys

    ap = argparse.ArgumentParser(description="зонд T-335: фазы — pytest'ом, шум — отсюда")
    ap.add_argument("--hostile", type=float, metavar="СЕК",
                    help="режим шума: двигать чужой указатель раз в СЕК секунд")
    args = ap.parse_args()
    if args.hostile:
        hostile_loop(args.hostile)
    else:
        sys.exit(
            "фазы снимает pytest (`pytest tests/mcp/probe_t335_focus.py -q -s --timeout=900`); "
            "здесь только `--hostile СЕК`"
        )
