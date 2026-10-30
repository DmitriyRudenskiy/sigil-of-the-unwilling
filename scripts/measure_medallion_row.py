#!/usr/bin/env python3
"""T-315: яркость пластин командного ряда на канонном кадре 1920×1080.

Зачем. Критерий закрытия T-315 сформулирован пикселями: «кадр ряда не содержит
медальона, светлее соседних ×1.5». Прежний замер билкадром по всему нижнему бару
и давал «α 1.0 и α 2.9 совпали» — потому что брал прямоугольник `bottom_bar`
(фон под рядом), а не сами пластины: различие состояний в него не попадало.

Прямоугольники пластин (ниже) сняты `game_eval`'ом с живого боя
(`res://scenes/battle.tscn`, фикстура `battle_hud_full`) канонным кадром: все
восемь медальонов — 100×100 при y=943, x = 20/140/260/380 (левая группа) и
1430/1550/1670/1790 (правая), трансформация — единичная, то есть канвас-пиксель
равен пикселю снимка. `--print-eval` печатает тот же код, которым прямоугольники
были получены, — ряд можно перемерить, если макет уедет.

Яркость — относительная линейная (ITU-R BT.709 по sRGB-каналах), а не «средний
серый»: именно так сравнивают пластины над светлым полем, где глаз читает
освещённость, а не 8-битный код.

Запуск:
    python3 scripts/measure_medallion_row.py <кадр.png>            # все восемь
    python3 scripts/measure_medallion_row.py <кадр.png> --disabled retreat
    python3 scripts/measure_medallion_row.py --print-eval
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

CANVAS = (1920, 1080)
# (имя медальона, x, y, ширина, высота) — замер `game_eval` на канонном кадре.
PLATES: list[tuple[str, int, int, int, int]] = [
    ("attack", 20, 943, 100, 100),
    ("defend", 140, 943, 100, 100),
    ("retreat", 260, 943, 100, 100),
    ("auto", 380, 943, 100, 100),
    ("spellbook", 1430, 943, 100, 100),
    ("cancel", 1550, 943, 100, 100),
    ("wait", 1670, 943, 100, 100),
    ("skip", 1790, 943, 100, 100),
]
# Критерий T-315: отключённый медальон не обязан быть темнее всех до единого —
# он не имеет права быть СВЕТЛЕЕ соседней группы в полтора раза.
CRITERION = 1.5

EVAL_SNIPPET = """var s = get_tree().current_scene
var ui = s.get_node_or_null('BattleUI')
var out = []
for p in ['bottom_bar/bar_box/left_box/auto_btn', 'bottom_bar/bar_box/left_box/defend_btn', 'bottom_bar/bar_box/left_box/retreat_btn', 'bottom_bar/bar_box/left_box/attack_btn', 'bottom_bar/bar_box/right_box/spellbook_btn', 'bottom_bar/bar_box/right_box/wait_btn', 'bottom_bar/bar_box/right_box/skip_btn', 'bottom_bar/bar_box/right_box/cancel_btn']:
	var b = ui.get_node_or_null(p)
	var r = b.get_global_rect()
	out.append([p, b.disabled, str(b.self_modulate), int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)])
return out
"""


def _linear(channel8: int) -> float:
    c = channel8 / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(px: tuple[int, int, int]) -> float:
    """Относительная линейная яркость пикселя (BT.709 по sRGB)."""
    return 0.2126 * _linear(px[0]) + 0.7152 * _linear(px[1]) + 0.0722 * _linear(px[2])


def plate_luminance(frame: Image.Image, rect: tuple[int, int, int, int]) -> float:
    x, y, w, h = rect
    px = frame.crop((x, y, x + w, y + h)).load()
    total = 0.0
    for j in range(h):
        for i in range(w):
            total += luminance(px[i, j])
    return total / (w * h)


def measure(path: Path, disabled: str | None) -> tuple[dict[str, float], float, float]:
    frame = Image.open(path).convert("RGB")
    if frame.size != CANVAS:
        raise SystemExit(
            f"{path}: кадр {frame.size[0]}×{frame.size[1]}, а прямоугольники пластин "
            f"снимались на каноне {CANVAS[0]}×{CANVAS[1]} — замер будет враньём"
        )
    values = {name: plate_luminance(frame, (x, y, w, h)) for name, x, y, w, h in PLATES}
    on = [v for name, v in values.items() if name != disabled]
    baseline = sum(on) / len(on)
    target = values[disabled] if disabled in values else max(values.values())
    return values, target, baseline


def main(argv: list[str]) -> int:
    if "--print-eval" in argv:
        print(EVAL_SNIPPET, end="")
        return 0
    rest = [a for a in argv if not a.startswith("--")]
    if not rest:
        raise SystemExit("нужен путь к кадру (или --print-eval)")
    disabled = None
    if "--disabled" in argv:
        disabled = argv[argv.index("--disabled") + 1]
    values, target, baseline = measure(Path(rest[0]), disabled)
    print(f"кадр: {rest[0]}")
    for name, value in values.items():
        mark = "  ← проверяемый" if disabled and name == disabled else ""
        print(f"  {name:10s} {value:.4f}{mark}")
    print(f"  среднее включённых: {baseline:.4f}")
    ratio = target / baseline
    print(f"  отношение: {ratio:.2f}× (критерий ≤ {CRITERION})")
    ok = ratio <= CRITERION
    print(f"  ВЕРДИКТ: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
